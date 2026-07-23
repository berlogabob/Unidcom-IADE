"""Populate person_roles from the raw `Papel` column of the Researchers CSV.

`Papel` is comma-separated and encodes two layers, e.g.
"Coordenação Científica, Investigador Integrado" = membership Integrated + role
Scientific Coordination. This matches each raw row to a DB person (by email, else
normalized name), then:
  - adds any missing Layer-2 role (Scientific Coordination, Science Management,
    Executive Direction, Advisory Board, Other),
  - reports (does not change) membership-base disagreements.

Output is a SQL file wrapped in disable/enable of the pending-forcing trigger, so
rows land `approved`. Review the dry-run, then apply the SQL via the DB.

    uv run scripts/import_roles.py            # dry run + write scripts/out/roles.sql
"""

from __future__ import annotations

import csv
import datetime
import os
import sys
import unicodedata
from collections import Counter
from pathlib import Path

CSV_PATH = (
    Path(__file__).resolve().parent.parent
    / "RAW_DATA"
    / "exportsfromnotoin"
    / "UNIDCOM Researchers 082bff569c094748a845cf95464d85ab_all.csv"
)
OUT_SQL = Path(__file__).resolve().parent / "out" / "roles.sql"
YEAR = datetime.date.today().year

# Papel token (accent-stripped, lowercased) -> membership base.
MEMBERSHIP = {
    "investigador integrado": "integrated",
    "investigador colaborador": "collaborator",
    "externo": "external",
}
# Papel token -> Layer-2 role label.
ROLE = {
    "coordenacao cientifica": "Scientific Coordination",
    "gestao de ciencia": "Science Management",
    "direcao executiva": "Executive Direction",
    "advisory board": "Advisory Board",
    "outro": "Other",
}


def clean(value: str | None) -> str:
    return " ".join((value or "").strip().split())


def key(value: str | None) -> str:
    text = unicodedata.normalize("NFKD", clean(value).lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def parse_papel(papel: str) -> tuple[str | None, list[str]]:
    base: str | None = None
    roles: list[str] = []
    for token in papel.split(","):
        k = key(token)
        if k in MEMBERSHIP:
            base = MEMBERSHIP[k]
        elif k in ROLE:
            roles.append(ROLE[k])
    # Advisory-board-only rows have no membership token -> external base.
    if base is None and "Advisory Board" in roles:
        base = "external"
    return base, roles


def sql_str(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def main() -> None:
    try:
        from dotenv import load_dotenv

        load_dotenv(Path(__file__).with_name(".env"))
    except ImportError:
        pass
    url, service_key = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not service_key:
        print("Missing SUPABASE_URL / SUPABASE_SERVICE_KEY", file=sys.stderr)
        raise SystemExit(1)

    from supabase import create_client

    client = create_client(url, service_key)
    people = client.table("people").select("id,preferred_name,email,membership_type").execute().data or []
    by_email = {key(p["email"]): p for p in people if clean(p.get("email"))}
    by_name = {key(p["preferred_name"]): p for p in people if clean(p.get("preferred_name"))}

    existing = client.table("person_roles").select("person_id,kind,label,year").execute().data or []
    have: set[tuple[str, str, str]] = {(r["person_id"], r["kind"], r["label"]) for r in existing}
    # Current-year membership row per person (to update vs insert).
    membership_row = {
        r["person_id"]: r
        for r in existing
        if r["kind"] == "membership" and r["year"] == YEAR
    }

    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))

    role_inserts: list[tuple[str, str]] = []          # (person_id, role_label)
    mem_updates: list[tuple[str, str]] = []           # (person_id, base) — has a row
    mem_inserts: list[tuple[str, str]] = []           # (person_id, base) — no row yet
    changed: list[tuple[str, str, str]] = []          # (name, from, to) genuine changes
    unmatched: list[str] = []
    matched = 0

    for row in rows:
        name = clean(row.get("Pessoa"))
        person = by_email.get(key(row.get("Email"))) or by_name.get(key(name))
        if not person:
            if name:
                unmatched.append(name)
            continue
        matched += 1
        base, roles = parse_papel(row.get("Papel") or "")
        pid = person["id"]
        for role in roles:
            if (pid, "role", role) not in have:
                role_inserts.append((pid, role))
                have.add((pid, "role", role))
        if base:  # raw is authoritative for the membership base
            current = membership_row.get(pid)
            if current is None:
                mem_inserts.append((pid, base))
                changed.append((name, "—", base))
            elif current["label"] != base:
                mem_updates.append((pid, base))
                changed.append((name, current["label"], base))

    # ---- report ----
    print(f"CSV rows: {len(rows)}  matched: {matched}  unmatched: {len(unmatched)}")
    if unmatched:
        print("  unmatched:", ", ".join(unmatched))
    print("\nRole entries to ADD (kind=role, year=%d):" % YEAR)
    for label, n in Counter(r[1] for r in role_inserts).most_common():
        print(f"  {label}: {n}")
    print(f"  total: {len(role_inserts)}")
    print(f"\nMembership base set from raw — changes: {len(changed)} "
          f"(update {len(mem_updates)}, insert {len(mem_inserts)})")
    for nm, frm, to in changed[:25]:
        print(f"  {nm}: {frm} -> {to}")
    if len(changed) > 25:
        print(f"  ... and {len(changed) - 25} more")

    # ---- emit SQL (both triggers disabled so rows stay approved / cache sticks) ----
    OUT_SQL.parent.mkdir(exist_ok=True)
    lines = [
        "-- generated by import_roles.py — roles + membership base from raw Papel",
        "alter table public.person_roles disable trigger trg_protect_person_roles;",
        "alter table public.people disable trigger trg_protect_people;",
    ]
    for pid, label in role_inserts:
        lines.append(
            f"insert into public.person_roles (person_id, kind, label, year, status) "
            f"values ({sql_str(pid)}, 'role', {sql_str(label)}, {YEAR}, 'approved');"
        )
    for pid, base in mem_updates:
        lines.append(
            f"update public.person_roles set label={sql_str(base)} "
            f"where person_id={sql_str(pid)} and kind='membership' and year={YEAR};"
        )
    for pid, base in mem_inserts:
        lines.append(
            f"insert into public.person_roles (person_id, kind, label, year, status) "
            f"values ({sql_str(pid)}, 'membership', {sql_str(base)}, {YEAR}, 'approved');"
        )
    # Align the people.membership_type cache to each person's current-year membership.
    lines.append(
        "update public.people p set membership_type = pr.label "
        "from public.person_roles pr "
        f"where pr.person_id = p.id and pr.kind='membership' and pr.year={YEAR} "
        "and p.membership_type is distinct from pr.label;"
    )
    lines.append("alter table public.people enable trigger trg_protect_people;")
    lines.append("alter table public.person_roles enable trigger trg_protect_person_roles;")
    OUT_SQL.write_text("\n".join(lines) + "\n")
    print(f"\nSQL written -> {OUT_SQL}  "
          f"({len(role_inserts)} roles, {len(mem_updates)+len(mem_inserts)} membership)")
    assert parse_papel("Coordenação Científica, Investigador Integrado") == ("integrated", ["Scientific Coordination"])
    print("SELF-CHECK: PASS")


if __name__ == "__main__":
    main()

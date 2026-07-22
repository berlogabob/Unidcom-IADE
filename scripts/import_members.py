"""Reconcile the UNIDCOM membership rosters (xlsx) into Supabase.

The 2026 membership workbook has three roster sheets — Integrated Members,
Colaboradores, PhD Students — that carry the authoritative membership category,
emails, join/exit dates, and (for integrated) ORCID / CienciaID. import.py only
loaded the CSVs, so this fills the gaps:

  - membership_type from the roster (integrated > phd_student > collaborator)
  - status -> active for roster members
  - email / orcid / ciencia_id / join_date / exit_date, only where empty
  - creates roster people missing from the directory

Matches by cleaned email, then an order-independent name key. Dry-run by
default; pass --load to write.

NOTE: membership_type/status are guarded by the protect_people_cols() trigger,
which reverts them for non-admin writers (the service key is not is_admin()).
To let those two columns change, temporarily disable the trigger around --load:
  alter table people disable trigger trg_protect_people;  -- run --load
  alter table people enable  trigger trg_protect_people;
Other columns (email/orcid/ciencia_id/dates) are not guarded."""

from __future__ import annotations

import argparse
import datetime
import glob
import os
import re
import sys
import unicodedata
from pathlib import Path

import openpyxl

RAW_DIR = Path(__file__).resolve().parent.parent / "RAW_DATA" / "exportsfromnotoin"
XLSX_GLOB = "*membros integrados*2026*.xlsx"
RANK = {"collaborator": 1, "phd_student": 2, "integrated": 3}


def clean(value) -> str:
    return " ".join(str(value if value is not None else "").strip().split())


def normalize(value) -> str:
    text = unicodedata.normalize("NFKD", clean(value).lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def name_key(value) -> str:
    """Order-independent token set: 'Ayanoglu, Hande' == 'Hande Ayanoglu'."""
    return " ".join(sorted(re.sub(r"[^a-z0-9\s]", " ", normalize(value)).split()))


def email_key(value) -> str:
    return clean(value).rstrip(";").lower()


def bare_orcid(value) -> str | None:
    m = re.search(r"\d{4}-\d{4}-\d{4}-[\dX]{4}", str(value or ""), re.I)
    return m.group(0).upper() if m else None


def display_name(value: str) -> str:
    """'Last, First' -> 'First Last'; leave 'First Last' untouched."""
    if "," in value:
        last, first = value.split(",", 1)
        return clean(f"{first} {last}")
    return clean(value)


def parse_date(value) -> str | None:
    if isinstance(value, datetime.datetime):
        return value.date().isoformat()
    if isinstance(value, datetime.date):
        return value.isoformat()
    m = re.match(r"(\d{1,2})\.(\d{1,2})\.(\d{2,4})$", clean(value))
    if not m:
        return None
    day, month, year = (int(g) for g in m.groups())
    if year < 100:
        year += 2000
    try:
        return datetime.date(year, month, day).isoformat()
    except ValueError:
        return None


def read_rosters(path: Path) -> list[dict]:
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)

    def rows(sheet):
        return [r for r in wb[sheet].iter_rows(values_only=True)]

    recs: dict[str, dict] = {}

    def add(name, email, category, join=None, exit=None, orcid=None, ciencia=None):
        name = clean(name)
        if not name or name.lower().startswith(("colaboradores", "integrated members", "phd")):
            return
        key = name_key(name)
        rec = recs.setdefault(key, {
            "name": display_name(name), "name_key": key, "email": "",
            "category": category, "join": None, "exit": None,
            "orcid": None, "ciencia": None,
        })
        if RANK[category] > RANK[rec["category"]]:
            rec["category"] = category
        for field, value in (("email", email), ("join", join), ("exit", exit),
                             ("orcid", orcid), ("ciencia", ciencia)):
            if value and not rec[field]:
                rec[field] = value

    for r in rows("Integrated Members 2026")[3:]:
        g = lambda i: r[i] if len(r) > i else None
        add(g(3), email_key(g(6)), "integrated", parse_date(g(4)), parse_date(g(5)),
            bare_orcid(g(8)), clean(g(7)) or None)
    for r in rows("Colaboradores")[2:]:
        g = lambda i: r[i] if len(r) > i else None
        add(g(1), email_key(g(2)), "collaborator")
    for r in rows("PhD Students")[1:]:
        g = lambda i: r[i] if len(r) > i else None
        add(g(1), email_key(g(3)), "phd_student", parse_date(g(4)))

    return list(recs.values())


def load_client():
    from dotenv import load_dotenv
    from supabase import create_client

    load_dotenv(Path(__file__).with_name(".env"))
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY", file=sys.stderr)
        raise SystemExit(1)
    return create_client(url, key)


def self_check() -> None:
    assert name_key("Ayanoglu, Hande") == name_key("Hande Ayanoglu")
    assert email_key("juliana.duque@x.pt;") == "juliana.duque@x.pt"
    assert bare_orcid("0000-0003-0538-1685") == "0000-0003-0538-1685"
    assert display_name("Antunes, Raquel") == "Raquel Antunes"
    assert display_name("Raquel Antunes") == "Raquel Antunes"
    assert parse_date("04.03.2026") == "2026-03-04"
    assert parse_date("20.10.25") == "2025-10-20"
    assert parse_date(datetime.date(2026, 3, 4)) == "2026-03-04"
    assert parse_date("n/a") is None
    assert RANK["integrated"] > RANK["phd_student"] > RANK["collaborator"]
    print("SELF-CHECK: PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--load", action="store_true", help="write to the DB (default: dry-run)")
    parser.add_argument("--selfcheck", action="store_true")
    args = parser.parse_args()
    if args.selfcheck:
        self_check()
        return

    records = read_rosters(Path(glob.glob(str(RAW_DIR / XLSX_GLOB))[0]))
    db = load_client()
    people = (
        db.table("people")
        .select("id,preferred_name,email,membership_type,status,orcid,ciencia_id,join_date,exit_date")
        .filter("merged_into", "is", "null")
        .execute()
        .data
        or []
    )
    by_email = {email_key(p["email"]): p for p in people if p.get("email")}
    by_name = {name_key(p["preferred_name"]): p for p in people}

    created = type_changed = status_changed = email_filled = date_filled = id_filled = 0
    for r in records:
        person = (by_email.get(r["email"]) if r["email"] else None) or by_name.get(r["name_key"])
        if not person:
            new = {
                "preferred_name": r["name"], "email": r["email"] or None,
                "membership_type": r["category"], "status": "active",
                "orcid": r["orcid"], "ciencia_id": r["ciencia"],
                "join_date": r["join"], "exit_date": r["exit"],
                "profile_status": "draft", "public_visibility": False,
            }
            print(f"  CREATE {r['name']} [{r['category']}] {r['email']}")
            if args.load:
                db.table("people").insert(new).execute()
            created += 1
            continue

        fields = {}
        if person.get("membership_type") != r["category"]:
            fields["membership_type"] = r["category"]
            type_changed += 1
            print(f"  TYPE  {person['preferred_name']}: {person.get('membership_type')} -> {r['category']}")
        if person.get("status") != "active":
            fields["status"] = "active"
            status_changed += 1
        if r["email"] and not clean(person.get("email")):
            fields["email"] = r["email"]
            email_filled += 1
        if r["orcid"] and not clean(person.get("orcid")):
            fields["orcid"] = r["orcid"]
            id_filled += 1
        if r["ciencia"] and not clean(person.get("ciencia_id")):
            fields["ciencia_id"] = r["ciencia"]
            id_filled += 1
        if r["join"] and not person.get("join_date"):
            fields["join_date"] = r["join"]
            date_filled += 1
        if r["exit"] and not person.get("exit_date"):
            fields["exit_date"] = r["exit"]
        if fields and args.load:
            db.table("people").update(fields).eq("id", person["id"]).execute()

    print(
        f"\nroster records: {len(records)} | created: {created} | type changes: {type_changed} | "
        f"status->active: {status_changed} | emails: {email_filled} | ids: {id_filled} | dates: {date_filled}"
    )
    if not args.load:
        print("DRY-RUN — re-run with --load to write.")


if __name__ == "__main__":
    main()

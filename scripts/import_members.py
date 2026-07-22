"""Fill ORCID + Ciência ID from the Integrated Members xlsx.

The 'Integrated Members 2026' sheet carries authoritative ORCID / CienciaID
per member (name in 'Last, First' form, email, CienciaID, ORCID). Matches to
existing people by cleaned email, then by normalized name, and fills orcid /
ciencia_id ONLY where currently empty (never overwrites)."""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
import unicodedata
from pathlib import Path

import openpyxl

DEFAULT_XLSX = "*membros integrados*2026*.xlsx"
SHEET = "Integrated Members 2026"
RAW_DIR = Path(__file__).resolve().parent.parent / "RAW_DATA" / "exportsfromnotoin"


def clean(value: str | None) -> str:
    return " ".join(str(value or "").strip().split())


def normalize(value: str | None) -> str:
    text = unicodedata.normalize("NFKD", clean(value).lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def name_key(value: str | None) -> str:
    """Order-independent token set, so 'Ayanoglu, Hande' == 'Hande Ayanoglu'."""
    return " ".join(sorted(re.sub(r"[^a-z0-9\s]", " ", normalize(value)).split()))


def email_key(value: str | None) -> str:
    return clean(value).rstrip(";").lower()


def bare_orcid(value: str | None) -> str | None:
    m = re.search(r"\d{4}-\d{4}-\d{4}-[\dX]{4}", value or "", re.I)
    return m.group(0).upper() if m else None


def read_members(path: Path) -> list[dict[str, str]]:
    ws = openpyxl.load_workbook(path, read_only=True, data_only=True)[SHEET]
    rows = list(ws.iter_rows(values_only=True))[3:]  # data starts after the header rows
    members = []
    for r in rows:
        name = clean(r[3])
        if not name:
            continue
        members.append(
            {
                "name": name,
                "email": email_key(r[6]),
                "ciencia_id": clean(r[7]) or None,
                "orcid": bare_orcid(r[8]),
            }
        )
    return [m for m in members if m["orcid"] or m["ciencia_id"]]


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
    print("SELF-CHECK: PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--load", action="store_true", help="write to the DB (default: dry-run)")
    parser.add_argument("--selfcheck", action="store_true")
    args = parser.parse_args()
    if args.selfcheck:
        self_check()
        return

    path = Path(glob.glob(str(RAW_DIR / DEFAULT_XLSX))[0])
    members = read_members(path)
    db = load_client()
    people = (
        db.table("people")
        .select("id,preferred_name,email,orcid,ciencia_id")
        .filter("merged_into", "is", "null")
        .execute()
        .data
        or []
    )
    by_email = {email_key(p["email"]): p for p in people if p.get("email")}
    by_name = {name_key(p["preferred_name"]): p for p in people}

    updates = 0
    unmatched = []
    for m in members:
        person = by_email.get(m["email"]) or by_name.get(name_key(m["name"]))
        if not person:
            unmatched.append(m["name"])
            continue
        # Fill only empty fields — never overwrite curated data.
        fields = {}
        if m["orcid"] and not clean(person.get("orcid")):
            fields["orcid"] = m["orcid"]
        if m["ciencia_id"] and not clean(person.get("ciencia_id")):
            fields["ciencia_id"] = m["ciencia_id"]
        if not fields:
            continue
        print(f"  {person['preferred_name']}: {fields}")
        if args.load:
            db.table("people").update(fields).eq("id", person["id"]).execute()
        updates += 1

    print(f"\nmembers with ids: {len(members)} | people updated: {updates} | unmatched: {len(unmatched)}")
    for name in unmatched:
        print(f"  UNMATCHED: {name}")
    if not args.load:
        print("\nDRY-RUN — re-run with --load to write.")


if __name__ == "__main__":
    main()

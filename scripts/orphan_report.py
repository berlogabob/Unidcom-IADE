"""Read-only audit: people with no links (no outputs, no project/lab membership),
flagging likely duplicate name-splits so an admin can merge them.

A name is a "possible duplicate" of another when its normalized token set is a
subset/superset of the other's (same rule as groupMergeCandidates in the app),
e.g. 'Sara Gancho' <= 'Sara Patricia Martins Gancho'.

  uv run orphan_report.py
"""

from __future__ import annotations

import os
import re
import sys
import unicodedata
from pathlib import Path


def norm_tokens(name: str) -> frozenset[str]:
    text = unicodedata.normalize("NFKD", (name or "").lower())
    text = "".join(c for c in text if not unicodedata.combining(c))
    return frozenset(re.sub(r"[^a-z0-9\s]", " ", text).split())


def load_client():
    from dotenv import load_dotenv
    from supabase import create_client

    load_dotenv(Path(__file__).with_name(".env"))
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL / SUPABASE_SERVICE_KEY", file=sys.stderr)
        raise SystemExit(1)
    return create_client(url, key)


def main() -> None:
    db = load_client()
    people = (
        db.table("people")
        .select("id,preferred_name,email,membership_type,status")
        .filter("merged_into", "is", "null")
        .execute()
        .data
        or []
    )
    linked: set[str] = set()
    for table, col in (("output_authors", "person_id"),
                       ("project_members", "person_id"),
                       ("lab_members", "person_id")):
        for row in db.table(table).select(col).execute().data or []:
            linked.add(row[col])

    tokens = {p["id"]: norm_tokens(p["preferred_name"]) for p in people}
    orphans = [p for p in people if p["id"] not in linked]

    print(f"people (unmerged): {len(people)}  |  linked: {len(linked)}  |  "
          f"orphans (no outputs/projects/labs): {len(orphans)}\n")

    dup_count = 0
    for o in sorted(orphans, key=lambda p: p["preferred_name"]):
        ot = tokens[o["id"]]
        if len(ot) < 2:
            dups = []
        else:
            dups = [
                p["preferred_name"]
                for p in people
                if p["id"] != o["id"] and len(tokens[p["id"]]) >= 2
                and (ot <= tokens[p["id"]] or tokens[p["id"]] <= ot)
            ]
        flag = f"  ~= {dups}" if dups else ""
        if dups:
            dup_count += 1
        mt = o["membership_type"] or "—"
        print(f"  [{mt:12}] {o['preferred_name']}{flag}")

    print(f"\norphans with a possible duplicate to merge: {dup_count}")


if __name__ == "__main__":
    main()

"""Restore a JSON export (from export.py) back into Supabase — upsert by PK.

  uv run restore.py out/            # upsert every out/<table>.json, never deletes
  uv run restore.py out/ --wipe     # delete-all then reload (destructive, prompts)

Upsert is non-destructive: rows in the DB but absent from the files are left
alone. --wipe makes the DB mirror the files exactly.

people caveat: membership_type/status/profile_status/public_visibility/
auth_user_id/last_verified_at are reverted on UPDATE by trg_protect_people
(the service key is not is_admin()). So a plain upsert onto EXISTING people rows
won't restore those six columns — disable the trigger first if you need them:
    alter table people disable trigger trg_protect_people;   -- run restore
    alter table people enable  trigger trg_protect_people;
--wipe reloads via INSERT (trigger is before-UPDATE only), so it is unaffected.

Needs SUPABASE_URL + SUPABASE_SERVICE_KEY in scripts/.env."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from export import PKS, TABLES, load_env

SENTINEL = "00000000-0000-0000-0000-000000000000"  # all PKs are uuid; matches nothing real
GOVERNED = "people"


def chunked(rows: list[dict], size: int = 500):
    for i in range(0, len(rows), size):
        yield rows[i : i + size]


def load_table(src_dir: Path, name: str) -> list[dict]:
    path = src_dir / f"{name}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else []


def wipe_all(client, tables: dict[str, list[dict]]) -> None:
    for name in reversed(TABLES):  # links before the base rows they reference
        col = PKS[name].split(",")[0]
        client.table(name).delete().neq(col, SENTINEL).execute()
        print(f"  wiped {name}")


def restore(client, src_dir: Path, wipe: bool = False) -> None:
    tables = {name: load_table(src_dir, name) for name in TABLES}
    if wipe:
        wipe_all(client, tables)
    for name in TABLES:
        rows = tables[name]
        if not rows:
            continue
        if name == GOVERNED and not wipe:
            print("  NOTE: governance columns on existing people rows are guarded "
                  "by trg_protect_people — disable it first if they must change.")
        for chunk in chunked(rows):
            client.table(name).upsert(chunk, on_conflict=PKS[name]).execute()
        print(f"  {name}: {len(rows)} upserted")
    print("RESTORE: PASS")


def demo() -> None:
    # Order + chunking logic, no DB: reverse wipe undoes forward load, chunks cover all rows.
    assert list(reversed(TABLES))[0] == TABLES[-1]
    assert TABLES.index("people") < TABLES.index("output_authors")
    assert TABLES.index("outputs") < TABLES.index("output_authors")
    assert TABLES.index("projects") < TABLES.index("project_members")
    rows = [{"id": i} for i in range(1201)]
    chunks = list(chunked(rows))
    assert [r for c in chunks for r in c] == rows
    assert all(len(c) <= 500 for c in chunks) and len(chunks) == 3
    assert set(PKS) == set(TABLES)
    print("SELF-CHECK: PASS")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("src", nargs="?", type=Path, help="directory of <table>.json files")
    parser.add_argument("--wipe", action="store_true", help="delete all rows first (destructive)")
    parser.add_argument("--selfcheck", action="store_true")
    args = parser.parse_args()

    if args.selfcheck:
        demo()
        return
    if not args.src:
        parser.error("src directory is required (or pass --selfcheck)")

    if args.wipe and input(f"WIPE + reload {args.src}? This deletes all rows. Type 'yes': ") != "yes":
        raise SystemExit("aborted")

    env = load_env()
    if not env:
        raise SystemExit(1)
    from supabase import create_client

    restore(create_client(*env), args.src, wipe=args.wipe)


if __name__ == "__main__":
    main()

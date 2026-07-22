"""Export every Supabase table to JSON — full-DB backup / snapshot.

Writes scripts/out/<table>.json (same shape import.py produces), so exports are
diffable against what's committed and re-loadable with restore.py.

Needs SUPABASE_URL + SUPABASE_SERVICE_KEY in scripts/.env (see import.py)."""

from __future__ import annotations

import argparse
import importlib
from pathlib import Path

# import.py is a valid module file but "import import" is a syntax error.
_import = importlib.import_module("import")
load_env = _import.load_env
write_json = _import.write_json

# Load-order: base tables first, then link tables that FK into them.
# restore.py reads this (and PKS) as the single source of truth.
TABLES = [
    "people",
    "outputs",
    "projects",
    "tags",
    "output_authors",
    "project_members",
    "project_outputs",
    "person_tags",
    "enrichment_suggestions",
]

PKS = {
    "people": "id",
    "outputs": "id",
    "projects": "id",
    "tags": "id",
    "enrichment_suggestions": "id",
    "output_authors": "output_id,person_id",
    "project_members": "project_id,person_id",
    "project_outputs": "project_id,output_id",
    "person_tags": "person_id,tag_id",
}


def fetch_all(client, name: str) -> list[dict]:
    # ponytail: naive full-select, paginated past PostgREST's 1000-row cap.
    # Fine at lab scale (~185 people, ~371 outputs); add streaming only at 100k+.
    rows: list[dict] = []
    offset = 0
    while True:
        page = client.table(name).select("*").range(offset, offset + 999).execute().data or []
        rows += page
        if len(page) < 1000:
            return rows
        offset += 1000


def export(client, out_dir: Path) -> None:
    tables = {name: fetch_all(client, name) for name in TABLES}
    write_json(out_dir, tables)
    for name in TABLES:
        print(f"  {name}: {len(tables[name])}")
    print(f"EXPORT: PASS -> {out_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path(__file__).with_name("out"))
    args = parser.parse_args()

    env = load_env()
    if not env:
        raise SystemExit(1)
    from supabase import create_client

    export(create_client(*env), args.out)


if __name__ == "__main__":
    main()

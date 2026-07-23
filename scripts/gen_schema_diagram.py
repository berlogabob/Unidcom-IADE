"""Generate web/schema.mmd (mermaid erDiagram) from the live DB schema.

Introspects PostgREST's OpenAPI doc (GET /rest/v1/ with the secret key) — which
carries every table's columns, primary keys and foreign keys — so no Postgres
password is needed. Run this after any migration and commit web/schema.mmd:

    uv run scripts/gen_schema_diagram.py
    git add web/schema.mmd && git commit
"""

from __future__ import annotations

import datetime
import os
import re
import sys
from pathlib import Path

import httpx

OUT = Path(__file__).resolve().parent.parent / "web" / "schema.mmd"
SKIP = {"v_output_report"}  # views, not tables

# mermaid attribute types must be single tokens (no spaces).
TYPE = {
    "timestamp with time zone": "timestamptz",
    "character varying": "varchar",
    "double precision": "float8",
}


def load_env() -> tuple[str, str]:
    try:
        from dotenv import load_dotenv
        load_dotenv(Path(__file__).with_name(".env"))
    except ImportError:
        pass
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL / SUPABASE_SERVICE_KEY", file=sys.stderr)
        raise SystemExit(1)
    return url, key


def fetch_openapi(url: str, key: str) -> dict:
    r = httpx.get(f"{url}/rest/v1/", headers={"apikey": key, "Authorization": f"Bearer {key}"}, timeout=30)
    r.raise_for_status()
    return r.json()


def token(fmt: str) -> str:
    return TYPE.get(fmt, fmt.replace(" ", "_")) or "unknown"


def build_mmd(defs: dict) -> str:
    tables = {t: meta for t, meta in defs.items() if t not in SKIP}
    entities: list[str] = []
    edges: set[tuple[str, str, str]] = set()  # (parent, child, fk_col)

    for name in sorted(tables):
        props: dict = tables[name].get("properties", {})
        lines = [f"  {name} {{"]
        for col, meta in props.items():
            desc = meta.get("description", "") or ""
            fk = re.search(r"<fk table='([^']+)' column='([^']+)'/>", desc)
            marker = "PK" if "Primary Key" in desc else ("FK" if fk else "")
            lines.append(f"    {token(meta.get('format', ''))} {col} {marker}".rstrip())
            if fk and fk.group(1) in tables:
                edges.add((fk.group(1), name, col))
        lines.append("  }")
        entities.append("\n".join(lines))

    rels = [f'  {p} ||--o{{ {c} : "{col}"' for p, c, col in sorted(edges)]
    stamp = datetime.date.today().isoformat()
    body = "\n".join(entities) + "\n\n" + "\n".join(rels)
    return f"%% generated {stamp} by scripts/gen_schema_diagram.py — do not edit by hand\nerDiagram\n{body}\n"


def main() -> None:
    url, key = load_env()
    defs = fetch_openapi(url, key).get("definitions", {})
    mmd = build_mmd(defs)

    n_entities = mmd.count("{\n") if "{\n" in mmd else mmd.count("{")
    entity_count = sum(1 for line in mmd.splitlines() if re.match(r"  \w+ \{$", line))
    rel_count = sum(1 for line in mmd.splitlines() if "||--o{" in line)
    assert entity_count >= 21, f"only {entity_count} entities"
    assert rel_count >= 20, f"only {rel_count} relationships"
    assert "  collaborations {" in mmd, "collaborations table missing"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(mmd, encoding="utf-8")
    print(f"SELF-CHECK: PASS — {entity_count} entities, {rel_count} relationships -> {OUT}")


if __name__ == "__main__":
    main()

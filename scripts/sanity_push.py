"""Push one published RIMS profile to a Sanity `member` document.

    uv run python sanity_push.py <person uuid | exact preferred_name> [--dry-run]

Target project is SANITY_PROJECT (default: the test copy ld5jhf23); the agency's
vj0axykv is refused. Token: SANITY_TOKEN, else the `sanity login` token.
Only fields RIMS owns are set; photo, email, type etc. on an existing document
are left alone. The document is people.sanity_id when linked, else rims-<uuid>.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

import httpx

from common import load_client


AGENCY_PROJECT = "vj0axykv"
DATASET = os.environ.get("SANITY_DATASET", "production")
# memberType documents in the dump; collaborator/external have no counterpart.
MEMBER_TYPES = {"integrated": "bc4e4611-3a0b-4480-8f76-d85fb8eefa9d"}
COLUMNS = "id,preferred_name,bio,orcid,ciencia_id,membership_type,public_visibility,merged_into,sanity_id"


def slugify(value: str) -> str:
    # Same rule as unidcom-site/scripts/sync.py, so both sites agree on URLs.
    text = "".join(c for c in unicodedata.normalize("NFKD", value) if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:80].rstrip("-")


def published(row: dict[str, Any]) -> bool:
    # Same gate as sync.person_passes: publishing is public_visibility since 29 Sep.
    return row["merged_into"] is None and row["public_visibility"] is True


def mutations(row: dict[str, Any]) -> list[dict[str, Any]]:
    doc_id = row["sanity_id"] or f"rims-{row['id']}"
    created: dict[str, Any] = {
        "_id": doc_id,
        "_type": "member",
        "name": row["preferred_name"],
        "slug": {"_type": "slug", "current": slugify(row["preferred_name"])},
    }
    if row["membership_type"] in MEMBER_TYPES:
        created["type"] = {"_type": "reference", "_ref": MEMBER_TYPES[row["membership_type"]]}
    owned = {"name": row["preferred_name"], "shortBio": row["bio"], "orcid": row["orcid"], "cienciaId": row["ciencia_id"]}
    return [
        {"createIfNotExists": created},
        {"patch": {
            "id": doc_id,
            "set": {k: v for k, v in owned.items() if v},
            "unset": [k for k, v in owned.items() if not v],
        }},
    ]


def token() -> str:
    if os.environ.get("SANITY_TOKEN"):
        return os.environ["SANITY_TOKEN"]
    return json.loads((Path.home() / ".config/sanity/config.json").read_text())["authToken"]


def self_check() -> None:
    row = {"id": "u1", "preferred_name": "Zé Árvore", "bio": "b", "orcid": None, "ciencia_id": None,
           "membership_type": "integrated", "public_visibility": True, "merged_into": None, "sanity_id": None}
    create, patch = mutations(row)
    assert create["createIfNotExists"]["_id"] == "rims-u1"
    assert create["createIfNotExists"]["slug"]["current"] == "ze-arvore"
    assert patch["patch"]["set"] == {"name": "Zé Árvore", "shortBio": "b"}
    assert patch["patch"]["unset"] == ["orcid", "cienciaId"]
    assert mutations({**row, "sanity_id": "abc"})[0]["createIfNotExists"]["_id"] == "abc"
    assert published(row) and not published({**row, "public_visibility": False})
    assert not published({**row, "merged_into": "x"})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("person", nargs="?")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        self_check()
        print("ok")
        return
    if not args.person:
        parser.error("person is required")

    project = os.environ.get("SANITY_PROJECT", "ld5jhf23")
    if project == AGENCY_PROJECT:
        sys.exit("Refusing to write to the agency project vj0axykv.")

    table = load_client().table("people").select(COLUMNS)
    key = "id" if re.fullmatch(r"[0-9a-f-]{36}", args.person) else "preferred_name"
    rows = table.eq(key, args.person).execute().data
    if len(rows) != 1:
        sys.exit(f"Expected one person for {args.person!r}, found {len(rows)}.")
    row = rows[0]
    if not published(row):
        sys.exit(f"{row['preferred_name']} is not published (public_visibility off or merged).")

    body = {"mutations": mutations(row)}
    if args.dry_run:
        print(json.dumps(body, indent=1, ensure_ascii=False))
        return
    response = httpx.post(
        f"https://{project}.api.sanity.io/v2025-02-19/data/mutate/{DATASET}?returnIds=true",
        headers={"Authorization": f"Bearer {token()}"},
        json=body,
        timeout=30,
    )
    response.raise_for_status()
    print(f"{row['preferred_name']} -> {project}/{DATASET} {body['mutations'][1]['patch']['id']}")


if __name__ == "__main__":
    main()

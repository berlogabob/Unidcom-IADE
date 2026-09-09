"""Read-only Sanity snapshot and optional Supabase mirror."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

import httpx

from common import load_client


PAGE_SIZE = 1000
ASSET_TYPES = {"sanity.imageAsset", "sanity.fileAsset"}
REPO_ROOT = Path(__file__).resolve().parent.parent


def query_url(project: str, dataset: str, query: str) -> str:
    return f"https://{project}.api.sanity.io/v2025-02-19/data/query/{dataset}?{urlencode({'query': query})}"


def fetch(http: httpx.Client, project: str, dataset: str, query: str) -> Any:
    response = http.get(query_url(project, dataset, query))
    response.raise_for_status()
    return response.json()["result"]


def page_query(doc_type: str, start: int) -> str:
    projection = "{_id,_type,_updatedAt,url,originalFilename,size,mimeType}" if doc_type in ASSET_TYPES else ""
    return f'*[_type == {json.dumps(doc_type)}] | order(_id asc)[{start}...{start + PAGE_SIZE}]{projection}'


def fetch_documents(http: httpx.Client, project: str, dataset: str, doc_type: str) -> list[dict[str, Any]]:
    documents: list[dict[str, Any]] = []
    start = 0
    while True:
        page = fetch(http, project, dataset, page_query(doc_type, start))
        documents.extend(page)
        if len(page) < PAGE_SIZE:
            return documents
        start += PAGE_SIZE


def doc_to_row(doc: dict[str, Any], pulled_at: str) -> dict[str, Any]:
    return {
        "id": doc["_id"],
        "type": doc["_type"],
        "doc": doc,
        "sanity_updated_at": doc.get("_updatedAt"),
        "pulled_at": pulled_at,
    }


def dump_documents(directory: Path, project: str, dataset: str, documents: dict[str, list[dict[str, Any]]], pulled_at: str) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for doc_type, docs in documents.items():
        if Path(doc_type).name != doc_type:
            raise ValueError(f"unsafe Sanity type: {doc_type}")
        (directory / f"{doc_type}.json").write_text(json.dumps(docs, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
    (directory / "_meta.json").write_text(json.dumps({
        "project": project,
        "dataset": dataset,
        "pulled_at": pulled_at,
        "counts": {doc_type: len(docs) for doc_type, docs in documents.items()},
    }, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


def upsert_documents(client: Any, documents: dict[str, list[dict[str, Any]]], pulled_at: str) -> Any:
    rows = [doc_to_row(doc, pulled_at) for docs in documents.values() for doc in docs]
    for start in range(0, len(rows), 200):
        client.table("sanity_docs").upsert(rows[start:start + 200], on_conflict="id").execute()
    return client.rpc("sanity_link_by_code").execute()


def self_check() -> None:
    url = query_url("vj0axykv", "production", '*[_type == "member"]')
    assert "https://vj0axykv.api.sanity.io/v2025-02-19/data/query/production?" in url
    assert "%5B_type+%3D%3D+%22member%22%5D" in url
    doc = {"_id": "x", "_type": "member", "name": "Ada"}
    assert doc_to_row(doc, "now") == {
        "id": "x", "type": "member", "doc": doc,
        "sanity_updated_at": None, "pulled_at": "now",
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="vj0axykv")
    parser.add_argument("--dataset", default="production")
    parser.add_argument("--dump", type=Path, default=None)
    parser.add_argument("--no-db", action="store_true")
    parser.add_argument("--types", default=None)
    parser.add_argument("--self-check", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_check:
        self_check()
        return 0
    dump = args.dump or REPO_ROOT / "sanity-dump" / args.project
    pulled_at = datetime.now(timezone.utc).isoformat()
    try:
        with httpx.Client(timeout=30) as http:
            all_types = fetch(http, args.project, args.dataset, "array::unique(*[]._type)")
            types = [t.strip() for t in args.types.split(",") if t.strip()] if args.types else all_types
            documents = {doc_type: fetch_documents(http, args.project, args.dataset, doc_type) for doc_type in types}
    except (httpx.HTTPError, KeyError, TypeError, ValueError) as error:
        print(f"Sanity request failed: {error}", file=sys.stderr)
        return 1
    dump_documents(dump, args.project, args.dataset, documents, pulled_at)
    if not args.no_db:
        result = upsert_documents(load_client(), documents, pulled_at)
        print(result.data)
    for doc_type, docs in documents.items():
        print(f"{doc_type}\t{len(docs)}")
    print(f"total\t{sum(map(len, documents.values()))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

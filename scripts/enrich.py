"""Suggest Crossref/ORCID enrichments without changing canonical rows."""

from __future__ import annotations

import argparse
import os
import re
import sys
import time
import unicodedata
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx
from dotenv import load_dotenv
from supabase import Client, create_client


CROSSREF_UA = "UNIDCOM-Directory/1.0 (mailto:andre.berloga@gmail.com)"


def clean(value: str | None) -> str:
    return " ".join((value or "").strip().split())


def normalize(value: str | None) -> str:
    text = unicodedata.normalize("NFKD", clean(value).lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def family_key(value: str | None) -> str:
    parts = normalize(value).split()
    return parts[-1] if parts else ""


def clean_doi(value: str | None) -> str | None:
    match = re.search(r"10\.[^\s\"<>]+", value or "", re.I)
    return match.group(0).rstrip(").,;").lower() if match else None


def bare_orcid(value: str | None) -> str | None:
    match = re.search(r"\d{4}-\d{4}-\d{4}-[\dX]{4}", value or "", re.I)
    return match.group(0).upper() if match else None


def title_key(value: str | None) -> str:
    return re.sub(r"[^\w\s]", "", normalize(value))


def ciencia_id_from_orcid_person(profile: dict[str, Any]) -> str | None:
    """Mirror of enrich_client.dart: pull a Ciência ID from ORCID external ids."""
    ids = ((profile.get("external-identifiers") or {}).get("external-identifier")) or []
    for ident in ids:
        if not isinstance(ident, dict):
            continue
        id_type = normalize(ident.get("external-id-type"))
        url = normalize((ident.get("external-id-url") or {}).get("value"))
        if "ciencia" in id_type or "cienciavitae" in url:
            value = clean(ident.get("external-id-value"))
            if value:
                return value
    return None


def self_check() -> None:
    assert family_key("Hande Ayanoglu") == "ayanoglu"
    assert normalize("Ayanoglu") == "ayanoglu"
    assert normalize("João Dias") == "joao dias"
    assert clean_doi("https://doi.org/10.X") == "10.x"
    assert clean_doi("https://doi.org/10.1234/AbC).") == "10.1234/abc"
    assert ciencia_id_from_orcid_person(
        {"external-identifiers": {"external-identifier": [
            {"external-id-type": "CienciaID", "external-id-value": "5D19-A8B4-0000"},
        ]}}
    ) == "5D19-A8B4-0000"
    assert ciencia_id_from_orcid_person({}) is None
    print("SELF-CHECK: PASS")


def load_client() -> Client:
    load_dotenv(Path(__file__).with_name(".env"))
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in env or scripts/.env", file=sys.stderr)
        raise SystemExit(1)
    return create_client(url, key)


def get_json(client: httpx.Client, url: str, **kwargs: Any) -> dict[str, Any] | None:
    for attempt in range(2):
        try:
            response = client.get(url, timeout=20, **kwargs)
            if response.status_code == 404:
                return None
            if response.status_code == 429 or response.status_code >= 500:
                if attempt == 0:
                    time.sleep(1.0)
                    continue
                return None
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError:
            if attempt == 0:
                time.sleep(1.0)
                continue
            return None
    return None


def pending_exists(db: Client, row: dict[str, Any]) -> bool:
    rows = (
        db.table("enrichment_suggestions")
        .select("id")
        .eq("status", "pending")
        .eq("subject_type", row["subject_type"])
        .eq("subject_id", row["subject_id"])
        .eq("field", row["field"])
        .eq("suggested_value", row["suggested_value"])
        .limit(1)
        .execute()
        .data
        or []
    )
    return bool(rows)


def insert_suggestion(db: Client, row: dict[str, Any]) -> bool:
    if pending_exists(db, row):
        return False
    db.table("enrichment_suggestions").insert(row).execute()
    return True


def crossref_title(message: dict[str, Any]) -> str | None:
    titles = message.get("title") or []
    return clean(titles[0]) if titles else None


def output_authors(db: Client, output_id: str) -> list[dict[str, Any]]:
    rows = (
        db.table("output_authors")
        .select("people(id,preferred_name,orcid)")
        .eq("output_id", output_id)
        .execute()
        .data
        or []
    )
    return [row["people"] for row in rows if row.get("people")]


def run_crossref(db: Client, limit: int | None) -> tuple[int, int]:
    request = db.table("outputs").select("id,title,doi").not_.is_("doi", "null")
    if limit is not None:
        request = request.limit(limit)
    outputs = request.execute().data or []
    inserted = 0
    processed = 0
    with httpx.Client(headers={"User-Agent": CROSSREF_UA}) as http:
        for output in outputs:
            doi = clean_doi(output.get("doi"))
            if not doi:
                continue
            time.sleep(0.3)
            data = get_json(http, f"https://api.crossref.org/works/{quote(doi, safe='')}")
            message = (data or {}).get("message") or {}
            if not message:
                continue
            processed += 1

            suggested_title = crossref_title(message)
            stored_title = output.get("title")
            if suggested_title and title_key(suggested_title) != title_key(stored_title):
                inserted += insert_suggestion(
                    db,
                    {
                        "subject_type": "output",
                        "subject_id": output["id"],
                        "field": "title",
                        "current_value": stored_title,
                        "suggested_value": suggested_title,
                        "source": "crossref",
                        "confidence": 0.6,
                    },
                )

            people = output_authors(db, output["id"])
            by_family: dict[str, list[dict[str, Any]]] = {}
            for person in people:
                by_family.setdefault(family_key(person.get("preferred_name")), []).append(person)
            for author in message.get("author") or []:
                orcid = bare_orcid(author.get("ORCID"))
                matches = by_family.get(family_key(author.get("family")))
                if not orcid or not matches or len(matches) != 1 or matches[0].get("orcid"):
                    continue
                inserted += insert_suggestion(
                    db,
                    {
                        "subject_type": "person",
                        "subject_id": matches[0]["id"],
                        "field": "orcid",
                        "current_value": None,
                        "suggested_value": orcid,
                        "source": "crossref",
                        "confidence": 0.9,
                    },
                )
    return processed, inserted


def pending_orcid_subjects(db: Client) -> set[str]:
    rows = (
        db.table("enrichment_suggestions")
        .select("subject_id")
        .eq("status", "pending")
        .eq("subject_type", "person")
        .eq("field", "orcid")
        .execute()
        .data
        or []
    )
    return {row["subject_id"] for row in rows}


def run_orcid(db: Client, limit: int | None) -> int:
    request = db.table("people").select("id,preferred_name,orcid").or_("orcid.is.null,orcid.eq.")
    if limit is not None:
        request = request.limit(limit)
    skipped_ids = pending_orcid_subjects(db)
    people = [p for p in (request.execute().data or []) if p["id"] not in skipped_ids]
    inserted = 0
    with httpx.Client(headers={"Accept": "application/json"}) as http:
        for person in people:
            parts = clean(person.get("preferred_name")).split()
            if len(parts) < 2:
                continue
            query = f"given-names:{' '.join(parts[:-1])} AND family-name:{parts[-1]}"
            time.sleep(0.3)
            data = get_json(http, "https://pub.orcid.org/v3.0/expanded-search/", params={"q": query})
            results = (data or {}).get("expanded-result") or []
            if len(results) != 1:
                continue
            orcid = bare_orcid(results[0].get("orcid-id"))
            if not orcid:
                continue
            inserted += insert_suggestion(
                db,
                {
                    "subject_type": "person",
                    "subject_id": person["id"],
                    "field": "orcid",
                    "current_value": None,
                    "suggested_value": orcid,
                    "source": "orcid",
                    "confidence": 0.4,
                },
            )
    return inserted


def run_coverage(db: Client, limit: int | None) -> None:
    """Read-only: current ORCID/Ciência fill rates, and how many ORCID profiles
    already expose a Ciência ID / bio / email — the number that decides whether
    the CiênciaVitae API is worth adding."""
    people = (
        db.table("people")
        .select("id,preferred_name,orcid,ciencia_id")
        .filter("merged_into", "is", "null")
        .execute()
        .data
        or []
    )
    total = len(people)
    with_orcid = [p for p in people if clean(p.get("orcid"))]
    with_ciencia = [p for p in people if clean(p.get("ciencia_id"))]
    neither = [p for p in people if not clean(p.get("orcid")) and not clean(p.get("ciencia_id"))]

    print("=== current fill rates ===")
    print(f"people:            {total}")
    print(f"with ORCID:        {len(with_orcid)} ({_pct(len(with_orcid), total)})")
    print(f"with Ciência ID:   {len(with_ciencia)} ({_pct(len(with_ciencia), total)})")
    print(f"with neither:      {len(neither)} ({_pct(len(neither), total)})")

    probe = [p for p in with_orcid if not clean(p.get("ciencia_id"))]
    if limit is not None:
        probe = probe[:limit]
    print(f"\n=== probing {len(probe)} ORCID profiles (ORCID set, Ciência ID missing) ===")
    fetched = ciencia = bio = email = 0
    with httpx.Client(headers={"Accept": "application/json"}) as http:
        for person in probe:
            orcid = bare_orcid(person.get("orcid"))
            if not orcid:
                continue
            time.sleep(0.3)
            profile = get_json(http, f"https://pub.orcid.org/v3.0/{orcid}/person")
            if profile is None:
                continue
            fetched += 1
            if ciencia_id_from_orcid_person(profile):
                ciencia += 1
            if clean((profile.get("biography") or {}).get("content")):
                bio += 1
            if (profile.get("emails") or {}).get("email"):
                email += 1

    print(f"profiles fetched:          {fetched}")
    print(f"  expose a Ciência ID:     {ciencia} ({_pct(ciencia, fetched)})  <- key figure")
    print(f"  expose a biography:      {bio} ({_pct(bio, fetched)})")
    print(f"  expose a public email:   {email} ({_pct(email, fetched)})")


def _pct(part: int, whole: int) -> str:
    return f"{round(100 * part / whole)}%" if whole else "0%"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--crossref", action="store_true")
    parser.add_argument("--orcid", action="store_true")
    parser.add_argument("--coverage", action="store_true")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--selfcheck", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.selfcheck:
        self_check()
        return

    db = load_client()
    if args.coverage:
        run_coverage(db, args.limit)
        return

    run_crossref_pass = args.crossref or not args.orcid
    run_orcid_pass = args.orcid or not args.crossref
    crossref_processed = 0
    crossref_suggestions = 0
    orcid_suggestions = 0

    if run_crossref_pass:
        crossref_processed, crossref_suggestions = run_crossref(db, args.limit)
    if run_orcid_pass:
        orcid_suggestions = run_orcid(db, args.limit)

    total = crossref_suggestions + orcid_suggestions
    print(f"crossref DOIs processed: {crossref_processed}")
    print(f"crossref suggestions: {crossref_suggestions}")
    print(f"orcid suggestions: {orcid_suggestions}")
    print(f"total inserted: {total}")


if __name__ == "__main__":
    main()

"""Shared, pipeline-independent helpers for scripts."""

from __future__ import annotations

import os
import re
import sys
import time
import unicodedata
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv
from supabase import Client, create_client


CROSSREF_UA = "UNIDCOM-Directory/1.0 (mailto:andre.berloga@gmail.com)"

# Institution tokens used to disambiguate ORCID homonyms (normalized).
ORG_TOKENS = [
    "iade",
    "unidcom",
    "universidade europeia",
    # IADE's full legal name, which is how ORCID actually stores the employment.
    # Kept in sync with _orgTokens in lib/data/enrich_client.dart.
    "instituto de artes visuais",
]


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

"""Check DOI liveness for outputs and record doi_status/doi_checked_at."""

from __future__ import annotations

import argparse
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv
from supabase import Client, create_client


def clean_doi(value: str | None) -> str | None:
    match = re.search(r"10\.[^\s\"<>]+", value or "", re.I)
    return match.group(0).rstrip(").,;").lower() if match else None


def classify_status(status_code: int | None) -> str | None:
    """Map a doi.org response status to doi_status. None means: leave unchanged
    (transient blip, not evidence the DOI is actually dead)."""
    if status_code is None:
        return None
    if 200 <= status_code < 400:
        return "ok"
    if status_code in (404, 410):
        return "dead"
    return None


def self_check() -> None:
    assert clean_doi("https://doi.org/10.X") == "10.x"
    assert clean_doi("https://doi.org/10.1234/AbC).") == "10.1234/abc"
    assert classify_status(200) == "ok"
    assert classify_status(302) == "ok"
    assert classify_status(404) == "dead"
    assert classify_status(410) == "dead"
    assert classify_status(500) is None
    assert classify_status(429) is None
    assert classify_status(None) is None
    print("SELF-CHECK: PASS")


def load_client() -> Client:
    load_dotenv(Path(__file__).with_name(".env"))
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in env or scripts/.env", file=sys.stderr)
        raise SystemExit(1)
    return create_client(url, key)


def check_doi(http: httpx.Client, doi: str) -> int | None:
    """HEAD https://doi.org/<doi>, falling back to GET on 405. Returns the
    final status code, or None on timeout/error."""
    try:
        # ponytail: doi.org 404 catches unregistered/dead DOIs — the real case. A DOI that
        # 200s to a broken publisher "oops" landing page can't be caught without content
        # heuristics; out of scope.
        response = http.head(f"https://doi.org/{doi}")
        if response.status_code == 405:
            response = http.get(f"https://doi.org/{doi}")
        return response.status_code
    except httpx.HTTPError:
        return None


def run_check(db: Client, limit: int | None) -> None:
    request = db.table("outputs").select("id,title,doi").not_.is_("doi", "null")
    if limit is not None:
        request = request.limit(limit)
    outputs = request.execute().data or []

    checked = ok = dead = skipped = 0
    with httpx.Client(follow_redirects=True, timeout=20) as http:
        for output in outputs:
            doi = clean_doi(output.get("doi"))
            if not doi:
                skipped += 1
                continue
            checked += 1
            status_code = check_doi(http, doi)
            status = classify_status(status_code)
            if status is None:
                skipped += 1
            else:
                db.table("outputs").update({
                    "doi_status": status,
                    "doi_checked_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", output["id"]).execute()
                if status == "ok":
                    ok += 1
                else:
                    dead += 1
            time.sleep(0.3)

    print(f"checked: {checked}")
    print(f"ok: {ok}")
    print(f"dead: {dead}")
    print(f"skipped: {skipped}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int)
    parser.add_argument("--selfcheck", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.selfcheck:
        self_check()
        return

    db = load_client()
    run_check(db, args.limit)


if __name__ == "__main__":
    main()

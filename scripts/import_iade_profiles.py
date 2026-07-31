"""Review, then backfill profiles from the official IADE Gatsby site.

  uv run --project scripts scripts/import_iade_profiles.py --extract
  uv run --project scripts scripts/import_iade_profiles.py --apply
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import webbrowser
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from xml.etree import ElementTree

import httpx

from import_wp_profiles import (  # noqa: F401
    BUCKET,
    apply,
    clean,
    download_image,
    drop_shared_photos,
    ensure_bucket,
    image_extension,
    load_env,
    names_match,
    proposed_action,
    review_html,
    update_empty,
)

SITEMAP = "https://www.iade.europeia.pt/sitemap-staffdetail.xml"
STAFF_ROOT = "https://www.iade.europeia.pt/corpo-docente"
PAGE_DATA = "https://www.iade.europeia.pt/page-data/corpo-docente/{slug}/page-data.json"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0 Safari/537.36"
)
OUT = Path(__file__).with_name("out")
CACHE = OUT / "iade_pages.json"
REVIEW_JSON = OUT / "iade_profiles_review.json"
REVIEW_HTML = OUT / "iade_profiles_review.html"
UNMATCHED = OUT / "iade_profiles_unmatched.txt"
Row = dict[str, Any]


def slugs_from_sitemap(source: bytes) -> list[str]:
    root = ElementTree.fromstring(source)
    slugs = []
    for node in root.findall(".//{*}loc"):
        parts = urlparse(clean(node.text)).path.strip("/").split("/")
        if len(parts) == 2 and parts[0] == "corpo-docente" and parts[1]:
            slugs.append(parts[1])
    return list(dict.fromkeys(slugs))


def fetch_slugs(client: httpx.Client) -> list[str]:
    try:
        response = client.get(SITEMAP)
        response.raise_for_status()
        slugs = slugs_from_sitemap(response.content)
    except (httpx.HTTPError, ElementTree.ParseError) as error:
        raise SystemExit(f"Could not read IADE staff sitemap: {error}") from error
    if not slugs:
        raise SystemExit("IADE staff sitemap contained no staff pages")
    print(f"IADE sitemap: {len(slugs)} staff pages")
    return slugs


def profile_from_page(payload: Any, slug: str) -> Row:
    page = payload["result"]["pageContext"]["page"]
    template = page["template"]
    if not isinstance(page, dict) or not isinstance(template, dict):
        raise TypeError("unexpected page-data shape")
    name = clean(page.get("title"))
    if not name:
        raise ValueError("missing title")

    # template.image is the portrait. The hero background is one shared banner.
    image = template.get("image")
    photo_url = clean(image.get("url")) if isinstance(image, dict) else ""
    if "corpo-docente-" in photo_url.lower():
        photo_url = ""
    bio = clean(template.get("bio"))
    return {
        "name": name,
        "url": f"{STAFF_ROOT}/{slug}/",
        "photo_url": photo_url or None,
        "bio": bio if len(bio) >= 100 else None,
    }


def load_pages(refresh: bool) -> tuple[list[Row], int, int]:
    with httpx.Client(
        follow_redirects=True,
        timeout=30,
        headers={"User-Agent": USER_AGENT},
    ) as client:
        slugs = fetch_slugs(client)
        if CACHE.exists() and not refresh:
            pages = json.loads(CACHE.read_text(encoding="utf-8"))
            if not isinstance(pages, list) or not all(isinstance(row, dict) for row in pages):
                raise SystemExit(f"Invalid cache: {CACHE}; re-run with --refresh")
            failed = max(0, len(slugs) - len(pages))
            print(f"Using cached IADE pages: {CACHE} ({len(pages)} rows)")
            print(f"Page-data failures: {failed}")
            return pages, len(slugs), failed

        pages = []
        failed = 0
        for index, slug in enumerate(slugs, 1):
            if index > 1:
                time.sleep(0.2)
            try:
                response = client.get(PAGE_DATA.format(slug=slug))
                response.raise_for_status()
                pages.append(profile_from_page(response.json(), slug))
            except (httpx.HTTPError, KeyError, TypeError, ValueError) as error:
                failed += 1
                print(f"WARN {slug}: {error}", file=sys.stderr)
            if index % 25 == 0 or index == len(slugs):
                print(f"Fetched IADE page-data {index}/{len(slugs)}")

    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(pages, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Cached {len(pages)} extracted IADE pages: {CACHE}")
    print(f"Page-data failures: {failed}")
    return pages, len(slugs), failed


def match_people(people: list[Row], profiles: list[Row]) -> tuple[list[Row], list[Row], list[str]]:
    matched, ambiguous, unmatched = [], [], []
    for person in sorted(people, key=lambda item: clean(item.get("preferred_name"))):
        db_name = clean(person.get("preferred_name"))
        candidates = [profile for profile in profiles if names_match(db_name, profile["name"])]
        if len(candidates) == 1:
            profile = candidates[0]
            matched.append({
                "person_id": person["id"], "db_name": db_name,
                "old_name": profile["name"], "old_url": profile["url"],
                "photo_url": profile["photo_url"], "bio": profile["bio"],
                "photo_action": proposed_action(person.get("photo_url"), profile["photo_url"]),
                "bio_action": proposed_action(person.get("bio"), profile["bio"]),
            })
        elif candidates:
            ambiguous.append({
                "db_name": db_name,
                "candidates": [{"name": row["name"], "url": row["url"]} for row in candidates],
            })
        else:
            unmatched.append(db_name)
    return matched, ambiguous, unmatched


def extract(client: Any, refresh: bool) -> None:
    pages, total, failed = load_pages(refresh)
    profiles = drop_shared_photos(pages)
    people = (
        client.table("people")
        .select("id,preferred_name,photo_url,bio")
        .filter("merged_into", "is", "null")
        .execute()
        .data
        or []
    )
    pending = [
        row for row in people if not clean(row.get("photo_url")) or not clean(row.get("bio"))
    ]
    # proposed_action ensures Portuguese bios only ever fill empty fields.
    matched, ambiguous, unmatched = match_people(pending, profiles)
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW_JSON.write_text(
        json.dumps(matched, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    REVIEW_HTML.write_text(
        review_html(matched, ambiguous, unmatched, total, len(profiles)),
        encoding="utf-8",
    )
    unresolved = sorted([item["db_name"] for item in ambiguous] + unmatched)
    UNMATCHED.write_text("\n".join(unresolved) + "\n", encoding="utf-8")
    photos = sum(row["photo_action"] == "set" for row in matched)
    bios = sum(row["bio_action"] == "set" for row in matched)
    print(f"IADE pages {total}, extracted {len(profiles)}, failed {failed}, database people {len(people)}, pending {len(pending)}")
    print(
        f"MATCHED {len(matched)} | AMBIGUOUS {len(ambiguous)} | "
        f"UNMATCHED {len(unmatched)} | PHOTOS {photos} | BIOS {bios}"
    )
    if len(matched) < 35:
        print(
            "WARNING: MATCHED BELOW 35 — IADE PAGE-DATA SHAPE MAY HAVE CHANGED",
            file=sys.stderr,
        )
    print(
        f"Review JSON: {REVIEW_JSON}\nReview HTML: {REVIEW_HTML}\n"
        f"Unresolved names: {UNMATCHED}"
    )
    webbrowser.open(REVIEW_HTML.resolve().as_uri())


def self_check() -> None:
    source = b"<urlset><url><loc>https://www.iade.europeia.pt/corpo-docente/ana-silva/</loc></url></urlset>"
    assert slugs_from_sitemap(source) == ["ana-silva"]
    payload = {"result": {"pageContext": {"page": {
        "title": "Ana Silva",
        "template": {"image": {"url": "https://x/corpo-docente-banner"}, "bio": "x" * 100},
    }}}}
    profile = profile_from_page(payload, "ana-silva")
    assert profile["photo_url"] is None and profile["bio"] == "x" * 100


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--extract", action="store_true", help="write review files only")
    mode.add_argument("--apply", action="store_true", help="apply the reviewed proposal")
    parser.add_argument("--refresh", action="store_true", help="refresh the IADE cache")
    parser.add_argument("--dry-run", action="store_true", help="show apply writes without writing")
    args = parser.parse_args()
    self_check()
    if args.apply and not REVIEW_JSON.exists():
        raise SystemExit(f"{REVIEW_JSON} does not exist; run --extract and review it first")
    if args.refresh and not args.extract:
        parser.error("--refresh requires --extract")
    if args.dry_run and not args.apply:
        parser.error("--dry-run requires --apply")
    env = load_env()
    if not env:
        raise SystemExit(1)
    from supabase import create_client

    client = create_client(*env)
    if args.extract:
        extract(client, args.refresh)
    else:
        review = json.loads(REVIEW_JSON.read_text(encoding="utf-8"))
        valid = isinstance(review, list) and all(
            isinstance(row, dict) and row.get("person_id") for row in review
        )
        if not valid:
            raise SystemExit(f"Invalid review file: {REVIEW_JSON}")
        apply(client, review, args.dry_run)


if __name__ == "__main__":
    main()

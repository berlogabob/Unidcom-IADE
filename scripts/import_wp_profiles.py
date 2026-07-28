"""Review, then backfill profiles from the retired UNIDCOM WordPress site.

  uv run --project scripts scripts/import_wp_profiles.py --extract
  uv run --project scripts scripts/import_wp_profiles.py --apply
"""

from __future__ import annotations

import argparse
import html
import json
import mimetypes
import os
import re
import sys
import unicodedata
import webbrowser
from collections import Counter
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx

WP_API = "https://www.unidcom-iade.pt/wp-json/wp/v2/pages"
WP_FIELDS = "id,slug,link,title,content"
OUT = Path(__file__).with_name("out")
CACHE = OUT / "wp_pages.json"
REVIEW_JSON = OUT / "wp_profiles_review.json"
REVIEW_HTML = OUT / "wp_profiles_review.html"
UNMATCHED = OUT / "wp_profiles_unmatched.txt"
BUCKET = "people-photos"
PARTICLES = {"de", "da", "do", "dos", "das", "e", "di", "du", "van", "von"}
BAD_PHOTOS = ("generic-profile", "unidcom_black", "cropped-cropped", "footer_logos", "bg_blue")
HR = re.compile(r"""<hr\b[^>]*\bclass\s*=\s*["'][^"']*\bx-line\b[^"']*["'][^>]*>""", re.I)
NAV_TAIL = re.compile(r"\s*Back\s+to\s+People\s*\Z", re.I)
IMAGES = re.compile(r"""<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']""", re.I)
TAGS = re.compile(r"<[^>]+>")
Row = dict[str, Any]

def load_env() -> tuple[str, str] | None:
    try:
        from dotenv import load_dotenv
    except ImportError:
        load_dotenv = None
    if load_dotenv:
        load_dotenv(Path(__file__).with_name(".env"))
    url, key = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in env or scripts/.env", file=sys.stderr)
        return None
    return url, key

def clean(value: Any) -> str:
    return str(value or "").strip()

def name_tokens(value: str) -> list[str]:
    value = unicodedata.normalize("NFKD", value.lower())
    value = "".join(char for char in value if not unicodedata.combining(char))
    return [word for word in re.sub(r"[^a-z ]", " ", value).split() if word not in PARTICLES]

def names_match(db_name: str, old_name: str) -> bool:
    # A full old name matches a preferred name on first name plus one later name.
    left, right = name_tokens(db_name), name_tokens(old_name)
    return bool(len(left) > 1 and len(right) > 1 and left[0] == right[0] and set(left[1:]) & set(right[1:]))

def plain_text(source: str) -> str:
    source = html.unescape(source)
    source = re.sub(r"<br\s*/?>", "\n", source, flags=re.I)
    source = re.sub(r"</p\s*>", "\n", source, flags=re.I)
    lines = [re.sub(r"[ \t]+", " ", line).strip() for line in TAGS.sub("", source).replace("\xa0", " ").splitlines()]
    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()

def photo_from(source: str) -> str | None:
    for match in IMAGES.finditer(source):
        url = html.unescape(match.group(1)).strip()
        lowered = url.lower()
        # Generic-Profile is a shared placeholder, not a person's portrait.
        if "/wp-content/uploads/" in lowered and not any(part in lowered for part in BAD_PHOTOS):
            return url
    return None

def bio_from(source: str) -> str | None:
    divider = HR.search(source)
    if not divider:
        return None
    # Everything before the <hr> is metadata, including a private email address.
    bio = plain_text(source[divider.end() :])
    # Every page closes with a "Back to People" link back to the listing. It reads as
    # part of the biography once the tags are gone, so drop it before the length test.
    bio = NAV_TAIL.sub("", bio).strip()
    return bio if len(bio) >= 200 else None

def load_pages(refresh: bool) -> list[Row]:
    if CACHE.exists() and not refresh:
        pages = json.loads(CACHE.read_text(encoding="utf-8"))
        if not isinstance(pages, list):
            raise SystemExit(f"Invalid cache: {CACHE}; re-run with --refresh")
        print(f"Using cached WordPress pages: {CACHE} ({len(pages)} rows)")
        return pages

    pages: list[Row] = []
    with httpx.Client(follow_redirects=True, timeout=30, headers={"User-Agent": "UNIDCOM migration"}) as client:
        page, total_pages = 1, 1
        while page <= total_pages:
            response = client.get(WP_API, params={"per_page": 100, "page": page, "_fields": WP_FIELDS})
            response.raise_for_status()
            batch = response.json()
            if not isinstance(batch, list):
                raise SystemExit("Unexpected WordPress API response")
            pages.extend(batch)
            total_pages = int(response.headers.get("X-WP-TotalPages", total_pages))
            print(f"Fetched WordPress page {page}/{total_pages}: {len(batch)} rows")
            page += 1
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(pages, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Cached {len(pages)} WordPress pages: {CACHE}")
    return pages

def old_profiles(pages: list[Row]) -> list[Row]:
    profiles = []
    for page in pages:
        if "/centre/people/" in clean(page.get("link")):
            source = clean(page.get("content", {}).get("rendered"))
            profiles.append({
                "name": plain_text(clean(page.get("title", {}).get("rendered"))),
                "url": clean(page.get("link")), "photo_url": photo_from(source),
                "bio": bio_from(source),
            })
    return drop_shared_photos(profiles)

def drop_shared_photos(profiles: list[Row]) -> list[Row]:
    """Discard any portrait that two different old pages both point at.

    The old site has genuine mistakes of this kind — Paula Neves and Sandra Gomes
    share one photo, so at most one of them is the person in it. There is no way to
    tell which from the markup, and putting the wrong face on someone's public
    profile is worse than showing none, so neither gets it.
    """
    used = Counter(profile["photo_url"] for profile in profiles if profile["photo_url"])
    for profile in profiles:
        url = profile["photo_url"]
        if url and used[url] > 1:
            print(f"  shared photo dropped: {profile['name']} <- {url.rsplit('/', 1)[-1]}")
            profile["photo_url"] = None
    return profiles

def proposed_action(existing: Any, proposed: Any) -> str:
    return "skip-existing" if clean(existing) else "set" if proposed else "none"

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

def review_html(matched: list[Row], ambiguous: list[Row], unmatched: list[str], pages: int, profiles: int) -> str:
    table_rows = []
    for row in matched:
        photo = (
            f'<img src="{html.escape(row["photo_url"], quote=True)}" width="100" alt="">'
            if row["photo_url"]
            else '<span class="muted">No photo</span>'
        )
        bio, esc = clean(row["bio"]), html.escape
        preview = esc(bio[:400]) if bio else '<span class="muted">No bio</span>'
        rest = (
            f"<details><summary>Continue biography</summary><div class=bio>{esc(bio[400:])}</div></details>"
            if len(bio) > 400
            else ""
        )
        badges = "".join(
            f'<span class="badge {value}">{kind}: {value}</span>'
            for kind, value in (("photo", row["photo_action"]), ("bio", row["bio_action"]))
        )
        table_rows.append(
            f"<tr><td>{photo}</td><td>{esc(row['db_name'])}</td>"
            f'<td><a href="{esc(row["old_url"], quote=True)}">{esc(row["old_name"])}</a></td>'
            f"<td>{badges}</td><td><div class=bio>{preview}</div>{rest}</td></tr>"
        )
    ambiguous_rows = []
    for item in ambiguous:
        links = ", ".join(
            f'<a href="{html.escape(row["url"], quote=True)}">{html.escape(row["name"])}</a>'
            for row in item["candidates"]
        )
        ambiguous_rows.append(f"<li><b>{html.escape(item['db_name'])}</b>: {links}</li>")
    ambiguous_rows = "".join(ambiguous_rows)
    unmatched_rows = "".join(f"<li>{html.escape(name)}</li>" for name in unmatched)
    photos = sum(bool(row["photo_url"]) for row in matched)
    return f"""<!doctype html><html lang=en><head><meta charset=utf-8>
<title>WordPress profile migration review</title><style>
body{{font:15px/1.45 system-ui,sans-serif;margin:2rem;color:#18212b}} h1,h2{{color:#174e73}} .counts{{padding:1rem;background:#eef6fa;border-radius:8px}}
table{{width:100%;border-collapse:collapse;margin-top:1rem}} th,td{{padding:.7rem;border:1px solid #ccd7df;text-align:left;vertical-align:top}} th{{background:#174e73;color:white}}
tbody tr:nth-child(even){{background:#f7fafc}} img{{height:auto;border-radius:5px}} .bio{{white-space:pre-wrap;max-width:55rem}} .badge{{display:block;width:max-content;padding:.15rem .45rem;margin:.15rem;border-radius:1rem;font-size:.8rem}}
.set{{background:#d8f3dc;color:#155724}} .skip-existing{{background:#fff0c2;color:#6b5000}} .none{{background:#e9ecef}} .muted{{color:#687785}} section{{margin-top:2.5rem;padding-top:1rem;border-top:4px solid #d7e5ed}} a{{color:#075985}}
</style></head><body><h1>WordPress profile migration review</h1>
<div class=counts><b>Source pages:</b> {pages} total / {profiles} people · <b>Database people:</b> {len(matched) + len(ambiguous) + len(unmatched)} ·
<b>Matched:</b> {len(matched)} · <b>Ambiguous:</b> {len(ambiguous)} · <b>Unmatched:</b> {len(unmatched)} · <b>Real photos:</b> {photos}</div>
<p>Only <b>set</b> items will be written. Existing curated values are skipped.</p>
<table><thead><tr><th>Photo</th><th>DB name</th><th>Old name</th><th>Actions</th><th>Proposed biography</th></tr></thead>
<tbody>{''.join(table_rows)}</tbody></table>
<section><h2>Ambiguous ({len(ambiguous)})</h2><p>No candidate below will be applied.</p><ul>{ambiguous_rows or '<li>None</li>'}</ul></section>
<section><details><summary><b>Unmatched ({len(unmatched)})</b></summary><ul>{unmatched_rows}</ul></details></section>
</body></html>"""

def extract(client: Any, refresh: bool) -> None:
    pages = load_pages(refresh)
    profiles = old_profiles(pages)
    people = client.table("people").select("id,preferred_name,photo_url,bio").filter(
        "merged_into", "is", "null"
    ).execute().data or []
    matched, ambiguous, unmatched = match_people(people, profiles)
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW_JSON.write_text(json.dumps(matched, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    REVIEW_HTML.write_text(review_html(
        matched, ambiguous, unmatched, len(pages), len(profiles)
    ), encoding="utf-8")
    names = sorted([item["db_name"] for item in ambiguous] + unmatched)
    UNMATCHED.write_text("\n".join(names) + "\n", encoding="utf-8")
    photos = sum(bool(row["photo_url"]) for row in matched)
    print(f"WordPress pages {len(pages)}, people pages {len(profiles)}, database people {len(people)}")
    print(f"MATCHED {len(matched)} | AMBIGUOUS {len(ambiguous)} | UNMATCHED {len(unmatched)} | PHOTOS {photos}")
    if len(matched) < 40:
        print("WARNING: MATCHED BELOW 40 — WORDPRESS MARKUP MAY HAVE CHANGED")
    print(f"Review JSON: {REVIEW_JSON}\nReview HTML: {REVIEW_HTML}\nUnresolved names: {UNMATCHED}")
    webbrowser.open(REVIEW_HTML.resolve().as_uri())

def download_image(url: str) -> tuple[bytes, str] | None:
    reason = ""
    with httpx.Client(follow_redirects=True, timeout=20, headers={"User-Agent": "UNIDCOM migration"}) as client:
        for attempt in range(2):
            try:
                response = client.get(url)
                content_type = response.headers.get("content-type", "").split(";", 1)[0].lower()
                if response.status_code != 200:
                    reason = f"HTTP {response.status_code}"
                elif not content_type.startswith("image/"):
                    reason = f"content type {content_type or 'missing'}"
                elif not response.content:
                    reason = "empty response"
                else:
                    return response.content, content_type
            except httpx.RequestError as error:
                reason = str(error)
            if not attempt:
                print(f"  WARN image download failed ({reason}); retrying once")
    print(f"  WARN image skipped after retry: {url} ({reason})")
    return None

def image_extension(url: str, content_type: str) -> str:
    common = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif", "image/svg+xml": "svg", "image/avif": "avif"}
    extension = common.get(content_type) or (mimetypes.guess_extension(content_type) or "").lstrip(".")
    if not re.fullmatch(r"[a-z0-9]{1,5}", extension):
        extension = Path(urlparse(url).path).suffix.lower().lstrip(".")
    return extension if re.fullmatch(r"[a-z0-9]{1,5}", extension) else "img"

def ensure_bucket(client: Any) -> None:
    ids = [bucket.get("id") if isinstance(bucket, dict) else bucket.id for bucket in client.storage.list_buckets()]
    if BUCKET not in ids:
        client.storage.create_bucket(BUCKET, options={"public": True})
        print(f"Created public storage bucket: {BUCKET}")

def update_empty(client: Any, person: Row, field: str, value: str) -> bool:
    query = client.table("people").update({field: value}).eq("id", person["id"])
    existing = person.get(field)
    query = query.filter(field, "is", "null") if existing is None else query.eq(field, existing)
    if not (query.execute().data or []):
        print(f"  WARN {field} changed since it was read; skipped")
        return False
    person[field] = value
    return True

def apply(client: Any, review: list[Row], dry_run: bool) -> None:
    rows = client.table("people").select("id,preferred_name,photo_url,bio").filter(
        "merged_into", "is", "null"
    ).execute().data or []
    people = {row["id"]: row for row in rows}
    photos_set = bios_set = skipped = failed = 0
    bucket_ready = False
    for index, row in enumerate(review, 1):
        print(f"[{index}/{len(review)}] {clean(row.get('db_name'))}")
        photo_action, bio_action = row.get("photo_action"), row.get("bio_action")
        skipped += int(photo_action == "skip-existing") + int(bio_action == "skip-existing")
        invalid = [action for action in (photo_action, bio_action) if action not in {"set", "skip-existing", "none"}]
        if invalid:
            print(f"  WARN invalid review action: {invalid}")
            failed += len(invalid)
            continue
        person = people.get(row["person_id"])
        wanted = int(photo_action == "set") + int(bio_action == "set")
        if not person:
            print("  WARN person is no longer active or does not exist")
            failed += wanted
            continue
        do_photo = photo_action == "set" and not clean(person.get("photo_url"))
        do_bio = bio_action == "set" and not clean(person.get("bio"))
        if photo_action == "set" and not do_photo:
            print("  SKIP photo_url already has a value")
            skipped += 1
        if bio_action == "set" and not do_bio:
            print("  SKIP bio already has a value")
            skipped += 1
        if dry_run:
            if do_photo:
                print(f"  WOULD upload {row['photo_url']} and set photo_url")
                photos_set += 1
            if do_bio:
                print(f"  WOULD set bio ({len(clean(row.get('bio')))} characters)")
                bios_set += 1
            continue

        if do_photo:
            downloaded = download_image(clean(row.get("photo_url")))
            if not downloaded:
                failed += 1
            else:
                image_bytes, content_type = downloaded
                try:
                    if not bucket_ready:
                        ensure_bucket(client)
                        bucket_ready = True
                    path = f"{person['id']}.{image_extension(clean(row.get('photo_url')), content_type)}"
                    bucket = client.storage.from_(BUCKET)
                    bucket.upload(path, image_bytes, {"content-type": content_type, "upsert": "true"})
                    public_url = bucket.get_public_url(path)
                    if update_empty(client, person, "photo_url", public_url):
                        photos_set += 1
                        print(f"  SET photo_url -> {public_url}")
                    else:
                        skipped += 1
                except Exception as error:
                    print(f"  WARN photo failed: {error}")
                    failed += 1
        if do_bio:
            try:
                if update_empty(client, person, "bio", clean(row.get("bio"))):
                    bios_set += 1
                    print(f"  SET bio ({len(clean(row.get('bio')))} characters)")
                else:
                    skipped += 1
            except Exception as error:
                print(f"  WARN bio failed: {error}")
                failed += 1
    prefix = "DRY-RUN " if dry_run else ""
    print(f"{prefix}SUMMARY: photos set {photos_set}, bios set {bios_set}, skipped {skipped}, failed {failed}")

def self_check() -> None:
    assert name_tokens("João de Sousa") == ["joao", "sousa"]
    assert names_match("Amadeu Martins", "Amadeu Quelhas Martins")
    assert not names_match("Ana Silva", "Maria Silva")
    source = '<img src="/wp-content/uploads/Generic-Profile.jpg"><img src="https://x/wp-content/uploads/person.jpg">'
    assert photo_from(source) == "https://x/wp-content/uploads/person.jpg"
    assert plain_text("<p>A &amp; B<br>Next</p>") == "A & B\nNext"

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--extract", action="store_true", help="write review files only")
    mode.add_argument("--apply", action="store_true", help="apply the reviewed proposal")
    parser.add_argument("--refresh", action="store_true", help="refresh the WordPress cache")
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
        if not isinstance(review, list) or not all(isinstance(row, dict) and row.get("person_id") for row in review):
            raise SystemExit(f"Invalid review file: {REVIEW_JSON}")
        apply(client, review, args.dry_run)


if __name__ == "__main__":
    main()

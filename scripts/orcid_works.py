"""Stage ORCID works as output candidates, tagged by IADE/UNIDCOM affiliation.

Never writes to `outputs` — only to `output_candidates`, which an admin promotes
one row at a time from the review queue. That matters because outputs_read is
`using (true)` during the test period and report_data() ignores approval_status,
so a direct insert would be instantly public and in the next generated PDF.

ORCID is the only source on purpose: ResearchGate and Scopus already deposit into
ORCID, and Ciencia Vitae ids are scraped from ORCID profiles. One integration.

Usage:
    uv run scripts/orcid_works.py --selfcheck
    uv run scripts/orcid_works.py --person <uuid> --dry-run
    uv run scripts/orcid_works.py --limit 5
"""

from __future__ import annotations

import argparse
import sys
import time
from typing import Any

import httpx

from common import (
    CROSSREF_UA,
    ORG_TOKENS,
    clean,
    clean_doi,
    family_key,
    get_json,
    load_client,
    normalize,
)

ORCID_BASE = "https://pub.orcid.org/v3.0"
CROSSREF_WORK = "https://api.crossref.org/works/{doi}"

# Publication lags submission, and ORCID employment start months are unreliable,
# so a work may legitimately appear a year outside the recorded window.
WINDOW_GRACE = 1


# --- affiliation signals -----------------------------------------------------


def at_org(name: str | None) -> bool:
    """True when an institution name matches one of the IADE/UNIDCOM tokens."""
    text = normalize(name)
    return any(token in text for token in ORG_TOKENS)


def employment_windows(employments: dict[str, Any] | None) -> list[tuple[int | None, int | None]]:
    """(start_year, end_year) for each IADE/UNIDCOM employment on the ORCID record.

    None for end means "present". Walks the same shape as
    fetchOrcidSyncStatus in lib/data/enrich_client.dart.
    """
    windows: list[tuple[int | None, int | None]] = []
    for group in (employments or {}).get("affiliation-group") or []:
        for summary in group.get("summaries") or []:
            for value in summary.values():
                if not isinstance(value, dict):
                    continue
                org = (value.get("organization") or {}).get("name")
                if not at_org(org):
                    continue
                windows.append((_year(value.get("start-date")), _year(value.get("end-date"))))
    return windows


def _year(date: dict[str, Any] | None) -> int | None:
    raw = ((date or {}).get("year") or {}).get("value")
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def in_window(
    year: int | None,
    windows: list[tuple[int | None, int | None]],
    grace: int = WINDOW_GRACE,
) -> bool | None:
    """True/False if decidable, None when we simply do not know."""
    if year is None or not windows:
        return None
    return any(
        (start is None or year >= start - grace) and (end is None or year <= end + grace)
        for start, end in windows
    )


def crossref_affiliation(message: dict[str, Any] | None, family: str) -> str:
    """'match' | 'other' | 'none' for this author's affiliation on the work."""
    if not message:
        return "none"
    saw_any = False
    for author in message.get("author") or []:
        if family_key(author.get("family")) != family:
            continue
        for affiliation in author.get("affiliation") or []:
            name = clean(affiliation.get("name"))
            if not name:
                continue
            saw_any = True
            if at_org(name):
                return "match"
    return "other" if saw_any else "none"


def classify(win: bool | None, aff: str) -> tuple[str, float, str]:
    """Map the two signals onto (affiliation, score, reason).

    A ladder rather than a weighted sum: all nine cells are enumerable and the
    reason string stays honest about which evidence actually decided it.
    """
    if aff == "match":
        return ("unidcom", 0.95, "Crossref credits IADE/UNIDCOM for this author")
    if win is False:
        if aff == "other":
            return ("external", 0.02,
                    "published outside the IADE employment window; Crossref credits another institution")
        return ("external", 0.05, "published outside the IADE employment window on ORCID")
    if win is True:
        if aff == "other":
            return ("unknown", 0.45,
                    "inside the IADE employment window, but Crossref credits another institution")
        return ("unidcom", 0.70,
                "inside the IADE employment window; no affiliation data on Crossref")
    if aff == "other":
        return ("external", 0.10,
                "no IADE employment dates on ORCID; Crossref credits another institution")
    return ("unknown", 0.30, "no IADE employment dates and no Crossref affiliation")


# --- ORCID works -------------------------------------------------------------


def work_rows(works: dict[str, Any] | None) -> list[dict[str, Any]]:
    """Flatten /works into one row per group.

    The summary already carries put-code, title, year, type, journal and
    external-ids, so v1 never calls /work/{putcode} — that halves the requests.
    ORCID's `group` already collapses duplicate records of the same work.
    """
    rows: list[dict[str, Any]] = []
    for group in (works or {}).get("group") or []:
        summaries = group.get("work-summary") or []
        if not summaries:
            continue
        summary = summaries[0]
        ids = {
            e.get("external-id-type"): e.get("external-id-value")
            for e in (group.get("external-ids") or {}).get("external-id") or []
        }
        title = clean(((summary.get("title") or {}).get("title") or {}).get("value"))
        if not title:
            continue
        rows.append(
            {
                "put_code": str(summary.get("put-code")),
                "title": title,
                "year": _year(summary.get("publication-date")),
                "type": clean(summary.get("type")) or None,
                "doi": clean_doi(ids.get("doi")),
                "url": clean((summary.get("url") or {}).get("value")) or None,
            }
        )
    return rows


def full_reference(message: dict[str, Any] | None, row: dict[str, Any]) -> str | None:
    """Build an APA-ish reference from Crossref, pre-empting missing_reference."""
    if not message:
        return None
    names = [
        clean(f"{a.get('family', '')}, {(a.get('given') or '')[:1]}.".strip(", "))
        for a in (message.get("author") or [])
    ]
    authors = ", ".join(n for n in names if n)
    container = next(iter(message.get("container-title") or []), "")
    parts = [
        authors,
        f"({row['year']})." if row.get("year") else "",
        f"{row['title']}.",
        f"{clean(container)}." if container else "",
        f"https://doi.org/{row['doi']}" if row.get("doi") else "",
    ]
    reference = " ".join(p for p in parts if p).strip()
    return reference or None


# --- pipeline ----------------------------------------------------------------


def fetch_people(db, person: str | None, limit: int | None) -> list[dict[str, Any]]:
    query = (
        db.table("people")
        .select("id, preferred_name, orcid, join_date, exit_date, integration_year")
        .is_("merged_into", "null")
        .not_.is_("orcid", "null")
    )
    if person:
        query = query.eq("id", person)
    if limit:
        query = query.limit(limit)
    return query.execute().data or []


def fallback_windows(person: dict[str, Any]) -> list[tuple[int | None, int | None]]:
    """people.join_date/exit_date, then integration_year. Empty when unknown."""
    join = (person.get("join_date") or "")[:4]
    exit_ = (person.get("exit_date") or "")[:4]
    if join:
        return [(int(join), int(exit_) if exit_ else None)]
    if person.get("integration_year"):
        return [(int(person["integration_year"]), None)]
    return []


def settled_put_codes(db, person_id: str) -> set[str]:
    """Put-codes an admin already promoted or rejected — never resurrect those."""
    rows = (
        db.table("output_candidates")
        .select("source_put_code")
        .eq("person_id", person_id)
        .neq("status", "pending")
        .execute()
        .data
        or []
    )
    return {r["source_put_code"] for r in rows}


def run(db, client: httpx.Client, person: str | None, limit: int | None, dry_run: bool) -> None:
    people = fetch_people(db, person, limit)
    print(f"{len(people)} people with an ORCID")

    for entry in people:
        orcid = clean(entry.get("orcid"))
        if not orcid:
            continue
        name = entry.get("preferred_name") or entry["id"]

        employments = get_json(
            client, f"{ORCID_BASE}/{orcid}/employments", headers={"Accept": "application/json"}
        )
        time.sleep(0.3)
        windows = employment_windows(employments) or fallback_windows(entry)

        works = get_json(
            client, f"{ORCID_BASE}/{orcid}/works", headers={"Accept": "application/json"}
        )
        time.sleep(0.3)
        rows = work_rows(works)
        settled = settled_put_codes(db, entry["id"]) if not dry_run else set()

        family = family_key(entry.get("preferred_name"))
        staged = 0
        for row in rows:
            if row["put_code"] in settled:
                continue

            message = None
            if row["doi"]:
                payload = get_json(
                    client,
                    CROSSREF_WORK.format(doi=row["doi"]),
                    headers={"User-Agent": CROSSREF_UA},
                )
                time.sleep(0.3)
                message = (payload or {}).get("message")

            aff = crossref_affiliation(message, family)
            affiliation, score, reason = classify(in_window(row["year"], windows), aff)

            matched = db.rpc(
                "match_existing_output", {"p_doi": row["doi"], "p_title": row["title"]}
            ).execute().data

            candidate = {
                "person_id": entry["id"],
                "source": "orcid",
                "source_put_code": row["put_code"],
                "title": row["title"],
                "reporting_year": row["year"],
                "doi": row["doi"],
                "url": row["url"],
                "type": row["type"],
                "full_reference": full_reference(message, row),
                "affiliation": affiliation,
                "affiliation_score": score,
                "reason": reason,
                "matched_output_id": matched or None,
            }

            if dry_run:
                flag = " [already in directory]" if matched else ""
                print(f"  {affiliation:8} {score:.2f}  {row['year']}  {row['title'][:58]}{flag}")
                print(f"           {reason}")
            else:
                db.table("output_candidates").upsert(
                    candidate, on_conflict="person_id,source,source_put_code"
                ).execute()
            staged += 1

        print(f"{name}: {staged} candidate(s) from {len(rows)} ORCID work(s)")


# --- offline checks ----------------------------------------------------------


def self_check() -> None:
    assert at_org("Instituto de Artes Visuais, Design e Marketing")
    assert at_org("UNIDCOM/IADE") and not at_org("Kurchatov Institute")

    iade = [(2025, None)]
    assert in_window(2025, iade) is True
    assert in_window(2024, iade) is True, "grace year"
    assert in_window(2016, iade) is False
    assert in_window(2018, iade) is False
    assert in_window(None, iade) is None, "undated work"
    assert in_window(2018, []) is None, "no affiliation dates"
    assert in_window(2019, [(2015, 2020)]) is True
    assert in_window(2022, [(2015, 2020)]) is False

    # Andrey Dyakov, ORCID 0009-0009-8585-0074: IADE 2025->present, five works
    # from 2016-2018 credited to Kurchatov Institute. All must come out external.
    andrey = [(2018, "other"), (2018, "none"), (2017, "other"), (2017, "none"), (2016, "none")]
    for year, aff in andrey:
        affiliation, score, _ = classify(in_window(year, iade), aff)
        assert affiliation == "external", (year, aff, affiliation, score)

    # Positive controls, so the filter cannot degenerate into "external for everything".
    assert classify(True, "none")[0] == "unidcom"
    assert classify(True, "match")[0] == "unidcom"
    assert classify(False, "match")[0] == "unidcom", "Crossref naming IADE beats the window"
    assert classify(True, "other")[0] == "unknown"
    assert classify(None, "none")[0] == "unknown"
    assert classify(None, "other")[0] == "external"

    message = {
        "author": [
            {"family": "Dyakov", "given": "A", "affiliation": [{"name": "Kurchatov Institute"}]},
            {"family": "Gorin", "given": "A", "affiliation": [{"name": "Kurchatov Institute"}]},
        ]
    }
    assert crossref_affiliation(message, "dyakov") == "other"
    assert crossref_affiliation(message, "nobody") == "none"
    assert crossref_affiliation(None, "dyakov") == "none"
    assert (
        crossref_affiliation(
            {"author": [{"family": "Silva", "affiliation": [{"name": "IADE, Lisboa"}]}]}, "silva"
        )
        == "match"
    )
    assert (
        crossref_affiliation({"author": [{"family": "Silva", "affiliation": []}]}, "silva") == "none"
    )

    works = {
        "group": [
            {
                "external-ids": {"external-id": [{"external-id-type": "doi", "external-id-value": "10.1/AB"}]},
                "work-summary": [
                    {
                        "put-code": 12,
                        "title": {"title": {"value": " A Paper "}},
                        "publication-date": {"year": {"value": "2018"}},
                        "type": "journal-article",
                    }
                ],
            },
            {"work-summary": [{"put-code": 13, "title": {"title": {"value": ""}}}]},
        ]
    }
    rows = work_rows(works)
    assert len(rows) == 1, "untitled work dropped"
    assert rows[0] == {
        "put_code": "12",
        "title": "A Paper",
        "year": 2018,
        "type": "journal-article",
        "doi": "10.1/ab",
        "url": None,
    }, rows[0]

    employments = {
        "affiliation-group": [
            {
                "summaries": [
                    {
                        "employment-summary": {
                            "organization": {"name": "Instituto de Artes Visuais, Design e Marketing"},
                            "start-date": {"year": {"value": "2025"}},
                            "end-date": None,
                        }
                    }
                ]
            },
            {
                "summaries": [
                    {
                        "employment-summary": {
                            "organization": {"name": "Kurchatov Institute"},
                            "start-date": {"year": {"value": "2014"}},
                        }
                    }
                ]
            },
        ]
    }
    assert employment_windows(employments) == [(2025, None)], "only IADE windows count"
    assert employment_windows(None) == []

    assert fallback_windows({"join_date": "2021-09-01", "exit_date": None}) == [(2021, None)]
    assert fallback_windows({"integration_year": 2019}) == [(2019, None)]
    assert fallback_windows({}) == []

    print("selfcheck ok")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--selfcheck", action="store_true", help="offline checks, no network or DB")
    parser.add_argument("--person", help="limit to one person uuid")
    parser.add_argument("--limit", type=int, help="max people to process")
    parser.add_argument("--dry-run", action="store_true", help="print candidates, write nothing")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.selfcheck:
        self_check()
        return
    db = load_client()
    with httpx.Client(follow_redirects=True) as client:
        run(db, client, args.person, args.limit, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())

"""Find missing DOIs by searching Crossref backwards, from citation to DOI.

Every other Crossref call in this repo is forward (DOI -> metadata). This one
goes the other way, for outputs that have no DOI at all or whose DOI is broken.

Two signals decide a match, because neither alone is enough:
  * title similarity, computed locally — Crossref's own `score` does not
    discriminate (a true match scored 63, a false one 55 on another query);
  * author family-name overlap — one false positive reached 0.52 title
    similarity, above any threshold that still admits the 0.58 true match.
Measured on live data: 8/8 known DOIs recovered, 3/3 false positives rejected.

Writes only `enrichment_suggestions`, which an admin accepts in the review
queue — that path already dispatches output suggestions to updateOutput().

Usage:
    uv run scripts/find_dois.py --selfcheck
    uv run scripts/find_dois.py --dry-run
    uv run scripts/find_dois.py --output <uuid> --dry-run
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
import time
import unicodedata
from typing import Any

import httpx

from enrich import CROSSREF_UA, clean, clean_doi, get_json, insert_suggestion, load_client

CROSSREF_SEARCH = "https://api.crossref.org/works"

# Crossref indexes books and journal articles; exhibitions, seminars and
# supervision records have no DOI to find, which is why v_output_issues only
# raises missing_doi for these two macro-types.
DOI_BEARING = ("Livros", "Artigos em revistas")

STRONG_TITLE = 0.85
WEAK_TITLE = 0.50


def norm(value: str | None) -> str:
    """Lowercase, strip accents and punctuation, collapse whitespace."""
    text = unicodedata.normalize("NFKD", (value or "").lower())
    text = "".join(c for c in text if not unicodedata.combining(c))
    # Collapse whitespace last: punctuation becomes spaces, which would
    # otherwise leave doubles and drag every similarity ratio down.
    return " ".join(re.sub(r"[^a-z0-9 ]", " ", text).split())


def probe_of(reference: str | None) -> str:
    """Reduce a full citation to something comparable with a bare Crossref title.

    `full_reference` is a whole APA citation ("Author, A. (2025). Title. Journal,
    4(2), 1132-1151. https://doi.org/..."), so the leading author-year prefix and
    any trailing URL/DOI have to go before comparing against a bare title.
    """
    text = re.sub(r"https?://\S+", " ", reference or "")
    text = re.sub(r"\b10\.\d{4,9}/\S+", " ", text)
    text = re.sub(r"^.*?\(\s*\d{4}[a-z]?\s*\)\.?\s*", "", text)
    return norm(text)


def title_similarity(probe: str, title: str | None) -> float:
    """Best of whole-probe and leading-span ratios.

    The leading-span term is what lets a bare title match a citation that keeps
    going into journal name and page numbers.
    """
    target = norm(title)
    if not target or not probe:
        return 0.0
    head = difflib.SequenceMatcher(None, probe[: len(target) + 10], target).ratio()
    whole = difflib.SequenceMatcher(None, probe, target).ratio()
    return max(head, whole)


def reference_families(reference: str | None) -> set[str]:
    """Family names from the citation's author prefix (capitalised tokens)."""
    head = re.split(r"\(\s*\d{4}", reference or "")[0]
    return {norm(w) for w in re.findall(r"[A-ZÀ-Ý][a-zà-ÿ]{2,}", head)} - {""}


def author_overlap(reference: str | None, item: dict[str, Any]) -> int:
    theirs = {norm(a.get("family")) for a in (item.get("author") or []) if isinstance(a, dict)}
    return len(reference_families(reference) & (theirs - {""}))


def classify(similarity: float, overlap: int) -> tuple[float, str] | None:
    """(confidence, reason), or None to emit nothing.

    None is the common and correct outcome: most DOI-less outputs genuinely have
    no DOI, and a finder that always produces something is worse than useless.
    """
    if similarity >= STRONG_TITLE:
        return (0.90, f"title matches Crossref ({similarity:.0%})")
    if similarity >= WEAK_TITLE and overlap >= 1:
        plural = "s" if overlap > 1 else ""
        return (
            0.70,
            f"partial title match ({similarity:.0%}) confirmed by {overlap} shared author{plural}",
        )
    return None


def best_match(items: list[dict[str, Any]], reference: str) -> tuple[dict[str, Any], float, int] | None:
    probe = probe_of(reference)
    best: tuple[dict[str, Any], float, int] | None = None
    for item in items:
        titles = item.get("title") or []
        if not titles:
            continue
        similarity = title_similarity(probe, titles[0])
        if best is None or similarity > best[1]:
            best = (item, similarity, author_overlap(reference, item))
    return best


def search(client: httpx.Client, reference: str, year: int | None) -> list[dict[str, Any]]:
    params = {"query.bibliographic": reference[:250], "rows": 5}
    if year:
        params["filter"] = f"from-pub-date:{year - 1}-01-01,until-pub-date:{year + 1}-12-31"
    payload = get_json(
        client, CROSSREF_SEARCH, params=params, headers={"User-Agent": CROSSREF_UA}
    )
    return ((payload or {}).get("message") or {}).get("items") or []


def fetch_targets(db, output: str | None, limit: int | None) -> list[dict[str, Any]]:
    """Outputs whose DOI is missing (and plausibly exists), invalid, or dead."""
    rows = (
        db.table("outputs")
        .select("id, title, full_reference, reporting_year, doi, doi_status, macro_type")
        .is_("merged_into", "null")
        .eq("affiliation", "unidcom")
        .execute()
        .data
        or []
    )
    if output:
        return [r for r in rows if r["id"] == output]

    targets = [r for r in rows if needs_doi(r)]
    return targets[:limit] if limit else targets


def needs_doi(row: dict[str, Any]) -> bool:
    doi = clean(row.get("doi"))
    if not doi:
        return row.get("macro_type") in DOI_BEARING
    if not re.match(r"^10\.\d{4,9}/\S+$", doi):
        return True
    return row.get("doi_status") == "dead"


def run(db, client: httpx.Client, output: str | None, limit: int | None, dry_run: bool) -> None:
    targets = fetch_targets(db, output, limit)
    print(f"{len(targets)} output(s) needing a DOI")
    found = duplicates = 0

    for row in targets:
        reference = clean(row.get("full_reference")) or clean(row.get("title"))
        if not reference:
            continue

        items = search(client, reference, row.get("reporting_year"))
        time.sleep(0.3)
        best = best_match(items, reference)
        if not best:
            continue

        item, similarity, overlap = best
        verdict = classify(similarity, overlap)
        if not verdict:
            continue
        confidence, reason = verdict
        doi = clean_doi(item.get("DOI"))
        if not doi:
            continue

        # The DOI already belongs to another output. Two readings, and we cannot
        # tell them apart from here: the rows are duplicates, or Crossref matched
        # the wrong paper and returned a DOI we happen to hold already. Both mean
        # "do not write this DOI" — writing it would hit the unique constraint —
        # so flag it for a human instead of guessing.
        owner = db.rpc(
            "match_existing_output", {"p_doi": doi, "p_title": row["title"]}
        ).execute().data
        collision = owner and owner != row["id"]

        if collision:
            duplicates += 1
            suggestion = {
                "subject_type": "output",
                "subject_id": row["id"],
                "field": "duplicate_of",
                "current_value": clean(row.get("doi")) or None,
                "suggested_value": owner,
                "source": "crossref",
                "confidence": confidence,
            }
            label = f"CLASH with {owner} — duplicate row, or wrong Crossref match"
        else:
            found += 1
            suggestion = {
                "subject_type": "output",
                "subject_id": row["id"],
                "field": "doi",
                "current_value": clean(row.get("doi")) or None,
                "suggested_value": doi,
                "source": "crossref",
                "confidence": confidence,
            }
            label = doi

        if dry_run:
            print(f"  {confidence:.2f} {label}")
            print(f"        {reason}")
            print(f"        {clean(row.get('title'))[:70]}")
        else:
            insert_suggestion(db, suggestion)

    print(f"suggested: {found} doi, {duplicates} duplicate")


def self_check() -> None:
    assert probe_of("Rosario, A. T. (2025). Brand Loyalty and Generations X, Y, Z. Journal.") == (
        "brand loyalty and generations x y z journal"
    )
    assert "10" not in probe_of("Marques, A. (2025). Teaching. 10.54941/ahfe1005946.")
    assert "http" not in probe_of("Title. https://doi.org/10.1/x")

    assert title_similarity("brand loyalty and generations x y z", "Brand Loyalty and Generations X, Y, Z") > 0.95
    # Leading-span term: the citation continues past the title into the journal.
    assert title_similarity(
        "live music after covid 19 case studies of digital transformation in portugal the international journal",
        "Live Music After COVID-19: Case Studies of Digital Transformation in Portugal",
    ) > 0.85
    assert title_similarity("", "Anything") == 0.0
    assert title_similarity("something", None) == 0.0

    assert reference_families("Li Zhenyu, Gao Zhan / Oliveira, Fernando Sanches (2025). Title") >= {
        "gao",
        "oliveira",
    }
    item = {"author": [{"family": "Gao"}, {"family": "Li"}, {"family": "Oliveira"}]}
    assert author_overlap("Li Zhenyu, Gao Zhan / Oliveira, Fernando (2025). T", item) == 2
    assert author_overlap("Boechat, A. C. (2025). T", {"author": [{"family": "Koles"}]}) == 0
    assert author_overlap("X (2025). T", {}) == 0

    # Fixtures measured against live Crossref; see the module docstring.
    # Hard true positive: weak title, rescued by two shared surnames.
    assert classify(0.58, 2) == (0.70, "partial title match (58%) confirmed by 2 shared authors")
    # False positive that a title-only threshold would have admitted.
    assert classify(0.52, 0) is None
    assert classify(0.41, 0) is None
    assert classify(0.94, 0) is not None, "strong title needs no author confirmation"
    assert classify(0.90, 0)[0] == 0.90
    assert classify(0.60, 1)[0] == 0.70
    assert classify(0.49, 3) is None, "title floor is absolute"

    assert best_match([], "anything") is None
    assert best_match([{"DOI": "10.1/x"}], "anything") is None, "untitled item skipped"
    picked = best_match(
        [
            {"DOI": "10.1/a", "title": ["Something Else Entirely"]},
            {"DOI": "10.1/b", "title": ["Brand Loyalty and Generations X, Y, Z"]},
        ],
        "Rosario, A. (2025). Brand Loyalty and Generations X, Y, Z.",
    )
    assert picked[0]["DOI"] == "10.1/b", picked

    assert needs_doi({"doi": None, "macro_type": "Livros"})
    assert needs_doi({"doi": None, "macro_type": "Artigos em revistas"})
    assert not needs_doi({"doi": None, "macro_type": "Exposições"}), "no DOI to find"
    assert needs_doi({"doi": "not-a-doi", "macro_type": "Exposições"}), "invalid is fixable"
    assert needs_doi({"doi": "10.1/x", "macro_type": "Livros"}), "too few registrant digits"
    assert needs_doi({"doi": "10.1007/abc", "doi_status": "dead", "macro_type": "Livros"})
    assert not needs_doi({"doi": "10.1007/abc", "doi_status": "ok", "macro_type": "Livros"})
    assert not needs_doi({"doi": "10.1007/abc", "doi_status": None, "macro_type": "Livros"})

    print("selfcheck ok")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--selfcheck", action="store_true", help="offline checks, no network or DB")
    parser.add_argument("--output", help="limit to one output uuid")
    parser.add_argument("--limit", type=int, help="max outputs to process")
    parser.add_argument("--dry-run", action="store_true", help="print findings, write nothing")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.selfcheck:
        self_check()
        return
    db = load_client()
    with httpx.Client(follow_redirects=True) as client:
        run(db, client, args.output, args.limit, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())

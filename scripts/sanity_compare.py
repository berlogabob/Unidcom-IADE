"""Compare the Sanity snapshot with the current Supabase unit."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

from common import load_client, normalize


ROOT = Path(__file__).resolve().parent.parent
REPORT = ROOT / "docs/reports/2026-09-sanity-vs-supabase"
RESEARCH = {"member", "project", "researchOutput", "lab", "cluster", "externalResearcher"}
TAXONOMY = {"memberType", "projectType", "outputType", "labType", "funder", "scientificArea", "eventType", "sessionType", "proceedingType", "articleCategory"}
FIELDS = ("preferred_name", "email", "orcid", "ciencia_id", "bio", "photo")
EDITORIAL_NOTES = {
    "event": "events and event listings", "page": "site pages and landing copy", "openPosition": "open positions", "interestPosition": "open positions",
    "edicaoIade": "IADE editions", "proceeding": "conference proceedings", "iadePressItem": "IADE press items", "journal": "journal issues",
    "podcast": "podcast episodes", "testimonial": "testimonials", "form": "contact and signup forms", "redirectsConfig": "redirect rules",
    "website": "site configuration", "analytics": "analytics configuration", "selectList": "editorial select lists",
}


def rows(db: Any, table: str, columns: str = "*", filters: Iterable[tuple[str, str, Any]] = ()) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    offset = 0
    while True:
        query = db.table(table).select(columns)
        for op, column, value in filters:
            query = getattr(query, op)(column, value)
        page = query.range(offset, offset + 999).execute().data or []
        result.extend(page)
        if len(page) < 1000:
            return result
        offset += 1000


def bucket(doc_type: str) -> str:
    return "research directory" if doc_type in RESEARCH else "taxonomies" if doc_type in TAXONOMY else "site-editorial"


def count_map(items: Iterable[Any]) -> dict[str, int]:
    return dict(sorted(Counter(str(x) if x not in (None, "") else "—" for x in items).items()))


def fmt_map(values: dict[str, int], top: int = 6) -> str:
    # ponytail: long tails (11 macro types) blew the table cell; show the top entries and fold the rest.
    ordered = sorted(values.items(), key=lambda item: (-item[1], str(item[0])))
    text = "; ".join(f"{key}: {value:,}" for key, value in ordered[:top])
    rest = len(ordered) - top
    return (f"{text}; +{rest} more" if rest > 0 else text) or "—"


def years(items: Iterable[dict[str, Any]], key: str) -> str:
    values: list[int] = []
    for item in items:
        value = item.get(key)
        if isinstance(value, dict):
            value = value.get("year") or value.get("date", "")[:4]
        try:
            values.append(int(value))
        except (TypeError, ValueError):
            pass
    return f"{min(values)}–{max(values)}" if values else "—"


def field_value(row: dict[str, Any], field: str, side: str) -> Any:
    if side == "sanity":
        return row.get({"preferred_name": "sanity_name", "email": "sanity_email", "orcid": "sanity_orcid", "ciencia_id": "sanity_ciencia_id", "bio": "sanity_bio", "photo": "sanity_photo_url"}[field])
    return row.get({"preferred_name": "preferred_name", "email": "email", "orcid": "orcid", "ciencia_id": "ciencia_id", "bio": "bio", "photo": "photo_url"}[field])


def diff_counts(matches: list[dict[str, Any]]) -> dict[str, dict[str, int]]:
    result = {field: {"only_in_supabase": 0, "only_in_sanity": 0, "both_but_different": 0} for field in FIELDS}
    for match in matches:
        for field in FIELDS:
            sanity, supabase = field_value(match, field, "sanity"), field_value(match, field, "supabase")
            if supabase and not sanity:
                result[field]["only_in_supabase"] += 1
            elif sanity and not supabase:
                result[field]["only_in_sanity"] += 1
            elif sanity and supabase and (field == "photo" or sanity != supabase):
                # Photo URLs live on different hosts, so "both" means both present.
                result[field]["both_but_different"] += 1
    return result


def year_value(doc: dict[str, Any], key: str) -> Any:
    value = doc.get(key)
    return value.get("year") if isinstance(value, dict) else value


def member_type(doc: dict[str, Any], docs_by_id: dict[str, dict[str, Any]]) -> str:
    value = doc.get("type") or {}
    value = value[0] if isinstance(value, list) and value else value
    ref = value.get("_ref") if isinstance(value, dict) else None
    return (docs_by_id.get(ref) or {}).get("title") or "—"


def write_csv(path: Path, headers: list[str], data: list[dict[str, Any]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers)
        writer.writeheader()
        writer.writerows(data)


def conflict_text(value: Any) -> str:
    if not isinstance(value, dict):
        return ""
    return "; ".join(f"{key}: {item.get('sanity', '')} | {item.get('supabase', '')}" for key, item in value.items())


def stringify_numbers(value: Any) -> Any:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return f"{value:,}"
    if isinstance(value, dict):
        return {key: stringify_numbers(item) for key, item in value.items()}
    if isinstance(value, list):
        return [stringify_numbers(item) for item in value]
    return value


def self_check() -> None:
    assert [bucket(x) for x in ("member", "memberType", "page", "sanity.imageAsset")] == ["research directory", "taxonomies", "site-editorial", "site-editorial"]
    fixture = [{"sanity_name": "A", "preferred_name": "A", "sanity_email": "a@x", "email": None, "sanity_bio": "new", "bio": "old"}]
    assert diff_counts(fixture)["email"]["only_in_sanity"] == 1
    assert diff_counts(fixture)["bio"]["both_but_different"] == 1


def compare(db: Any) -> dict[str, Any]:
    docs = rows(db, "sanity_docs", "id,type,doc")
    docs_by_id = {row["id"]: row["doc"] for row in docs}
    members = [row["doc"] for row in docs if row["type"] == "member"]
    matches = rows(db, "sanity_member_matches")
    people = rows(db, "people", "id,preferred_name,email,orcid,ciencia_id,bio,photo_url,status,membership_type,merged_into,sanity_id")
    current_people = [row for row in people if row.get("merged_into") is None]
    people_by_id = {row["id"]: row for row in people}
    for match in matches:
        match.update({"bio": people_by_id.get(match["person_id"], {}).get("bio"), "photo_url": people_by_id.get(match["person_id"], {}).get("photo_url")})
    projects = [row["doc"] for row in docs if row["type"] == "project"]
    sanity_outputs = [row["doc"] for row in docs if row["type"] == "researchOutput"]
    supabase_projects = rows(db, "projects", "title,status,category,start_date,end_date")
    supabase_outputs = rows(db, "outputs", "title,macro_type,reporting_year,merged_into")
    current_outputs = [row for row in supabase_outputs if row.get("merged_into") is None]
    sanity_only = [doc for doc in members if doc.get("_id") not in {m["sanity_id"] for m in matches} and doc.get("_id") not in {p.get("sanity_id") for p in people}]
    supabase_only = [p for p in current_people if p["id"] not in {m["person_id"] for m in matches}]
    inventory = {name: {"sanity": sum(row["type"] == name for row in docs), "bucket": bucket(name)} for name in sorted({row["type"] for row in docs})}
    for name in inventory:
        inventory[name]["supabase"] = {"member": len(current_people), "project": len(supabase_projects), "researchOutput": len(current_outputs), "lab": len(rows(db, "labs", "id")), "cluster": len(rows(db, "clusters", "id"))}.get(name)
    type_counts = count_map(member_type(doc, docs_by_id) for doc in sanity_only)
    listed = [doc for doc in sanity_only if not doc.get("unlistedFromPeopleList", False)]
    unlisted = [doc for doc in sanity_only if doc.get("unlistedFromPeopleList", False)]
    fields_count = lambda items: {"count": len(items), "by_member_type": fmt_map(count_map(member_type(doc, docs_by_id) for doc in items)), "with_email": sum(bool(doc.get("email")) for doc in items), "with_photo": sum(bool(doc.get("photo")) for doc in items), "with_bio": sum(bool(doc.get("shortBio")) for doc in items)}
    research_supabase = {"people": len(current_people), "projects": len(supabase_projects), "outputs": len(current_outputs), "labs": len(rows(db, "labs", "id")), "clusters": len(rows(db, "clusters", "id"))}
    labs, clusters = rows(db, "labs", "code,sanity_id"), rows(db, "clusters", "code,sanity_id")
    data = {
        "inventory": {"types": inventory, "research_supabase": research_supabase, "research_sanity": sum(inventory[t]["sanity"] for t in inventory if bucket(t) == "research directory"), "taxonomy_sanity": sum(inventory[t]["sanity"] for t in inventory if bucket(t) == "taxonomies"), "editorial_sanity": sum(inventory[t]["sanity"] for t in inventory if bucket(t) == "site-editorial")},
        "people": {"sanity_count": len(members), "matches": len(matches), "match_kinds": count_map(m["match_kind"] for m in matches), "ambiguous": sum(bool(m.get("ambiguous")) for m in matches), "field_diffs": diff_counts(matches), "sanity_only": {"listed": fields_count(listed), "unlisted": fields_count(unlisted), "by_member_type": fmt_map(type_counts)}, "supabase_only": {"count": len(supabase_only), "by_status": fmt_map(count_map(p.get("status") for p in supabase_only)), "by_membership_type": fmt_map(count_map(p.get("membership_type") for p in supabase_only))}},
        "projects": {"sanity_count": len(projects), "sanity_status": fmt_map(count_map(p.get("status") for p in projects)), "sanity_years": years(projects, "startingDate"), "with_funder": sum(bool(p.get("funder")) for p in projects), "with_team": sum(bool(p.get("team")) for p in projects), "supabase_count": len(supabase_projects), "supabase_category": fmt_map(count_map(p.get("category") for p in supabase_projects)), "supabase_status": fmt_map(count_map(p.get("status") for p in supabase_projects)), "supabase_years": f"{min((p['start_date'] for p in supabase_projects if p.get('start_date')), default='—')}–{max((p['end_date'] for p in supabase_projects if p.get('end_date')), default='—')}", "title_overlap": len({normalize(p.get("title")) for p in projects} & {normalize(p.get("title")) for p in supabase_projects})},
        "outputs": {"sanity_count": len(sanity_outputs), "sanity_years": years(sanity_outputs, "year"), "with_link": sum(bool(o.get("link")) for o in sanity_outputs), "with_members": sum(bool(o.get("members")) for o in sanity_outputs), "supabase_count": len(current_outputs), "supabase_macro_type": fmt_map(count_map(o.get("macro_type") for o in current_outputs)), "supabase_reporting_year": fmt_map(count_map(o.get("reporting_year") for o in current_outputs)), "title_overlap": len({normalize(o.get("title")) for o in sanity_outputs} & {normalize(o.get("title")) for o in current_outputs})},
        "labs_clusters": {"labs_linked": sum(bool(x.get("sanity_id")) for x in labs), "labs_total": len(labs), "clusters_linked": sum(bool(x.get("sanity_id")) for x in clusters), "clusters_total": len(clusters), "legacy_clusters": sum(bool(d.get("isLegacy")) and d.get("_id") not in {x.get("sanity_id") for x in clusters} for d in (row["doc"] for row in docs if row["type"] == "cluster"))},
        "editorial": [{"type": t, "count": count, "note": EDITORIAL_NOTES.get(t, "site editorial content"), "supabase_counterpart": "none"} for t, count in sorted(Counter(row["type"] for row in docs if bucket(row["type"]) == "site-editorial").items())],
        "decisions": {"link_matched_people": len(matches), "review_ambiguous": sum(bool(m.get("ambiguous")) for m in matches), "import_listed_members": len(listed), "ignore_unlisted_members": len(unlisted), "legacy_projects": 43, "legacy_outputs": 1596},
    }
    return stringify_numbers(data), matches, sanity_only, supabase_only, docs_by_id


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        self_check()
        return 0
    data, matches, sanity_only, supabase_only, docs_by_id = compare(load_client())
    REPORT.mkdir(parents=True, exist_ok=True)
    (REPORT / "data.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_csv(REPORT / "matched_people.csv", ["sanity_id", "person_id", "match_kind", "ambiguous", "sanity_name", "preferred_name", "conflicts"], [{"sanity_id": m.get("sanity_id"), "person_id": m.get("person_id"), "match_kind": m.get("match_kind"), "ambiguous": m.get("ambiguous"), "sanity_name": m.get("sanity_name"), "preferred_name": m.get("preferred_name"), "conflicts": conflict_text(m.get("conflicts"))} for m in matches])
    write_csv(REPORT / "sanity_only_members.csv", ["sanity_id", "name", "member_type", "listed", "has_email", "has_photo", "has_bio"], [{"sanity_id": d.get("_id"), "name": d.get("name"), "member_type": member_type(d, docs_by_id), "listed": not d.get("unlistedFromPeopleList", False), "has_email": bool(d.get("email")), "has_photo": bool(d.get("photo")), "has_bio": bool(d.get("shortBio"))} for d in sanity_only])
    write_csv(REPORT / "supabase_only_people.csv", ["id", "preferred_name", "status", "membership_type"], [{key: p.get(key) for key in ("id", "preferred_name", "status", "membership_type")} for p in supabase_only])
    print(f"members {data['people']['sanity_count']} matched {data['people']['matches']} projects {data['projects']['sanity_count']} vs {data['projects']['supabase_count']} outputs {data['outputs']['sanity_count']} vs {data['outputs']['supabase_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

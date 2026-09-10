// Rui's RIMS spec (Doc 1 Researcher Portal, Doc 2 AI Agent Implementation
// Specification, received 10 Sep 2026) versus the portal on main + the
// Supabase schema (39 migrations). Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — Rui spec vs what exists",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · spec gap · 10 September 2026",
  lang: "en",
))
#set page(margin: (top: 1.6cm, bottom: 1.7cm, x: 1.9cm))

#title-block(
  "Rui's portal spec — gap and decision",
  subtitle: "Document 1 + 2 (10 Sep) against the portal on `main` and the live schema.",
  meta-line: [48 requirements checked against `lib/` and `supabase/migrations/` · 9 match · 17 partial · 19 gap · 3 conflicts. Nothing behind `v2` is deleted (Rui, 10 Aug).],
  standfirst: [#pill("DATA OK", tone: "ok") The schema already holds what the spec needs. #pill("UI WORK", tone: "warn") The portal shows it as 25 pages and a mixed timeline instead of 5 pages with filters. Supabase: #pill("4 additive columns/policies", tone: "info"), nothing renamed, ~40 lines of SQL. Redesign deferred until the pilot has real data.],
)

#kpi-row((
  ("9", "Match", "as specified"),
  ("17", "Partial", "data exists, UI half"),
  ("19", "Gap", "17 of them pure UI"),
  ("3", "Conflicts", "with his 14 Aug notes"),
))

= Rui wants vs we have

#data-table(
  ("Area", "Rui wants", "We have", "Fix"),
  (
    ([Navigation], [5 items: Overview · My Profile · Scientific Outputs · Resources & Guidance · Help & Contacts. No WIP, no sub-pages], [6 sections, 25 leaves, 8 "Work in progress" pages. 9 of our leaves are named as forbidden], [#pill("UI", tone: "warn")]),
    ([Overview], [Identity header, 3 status pills, "Needs Your Attention" with actions, "No action required", type counts, "N / 5 featured", "Recent Outputs"], [2 stat cards, one alert or literal "All good", "Recent papers", by-type WIP. All data present], [#pill("UI", tone: "warn")]),
    ([Profile], [One page; every edit is a proposed change (Save Draft / Submit)], [6 routes; owner Edit writes `people` directly. Staging exists for 4 signature fields (`enrichment_suggestions`)], [#pill("UI", tone: "warn")]),
    ([Biography], [UNIDCOM vs ORCID, Compare, Import → proposal → review], [Single `bio`; ORCID matrix exists, admin-only v2, applies directly], [#pill("UI", tone: "warn")]),
    ([Outputs page], [One page, views + filters; #strong[never] mix roles into outputs], [5 leaves; own timeline merges roles, tags, mentorships, labs and outputs], [#pill("UI", tone: "warn")]),
    ([Filters], [Search · Year · Type · Project · Activity · Review · ORCID · Website · Featured], [Taxonomy cascade + Kind, year groups. `project_outputs`, `matched_output_id`, `v_output_quality` exist unused], [#pill("UI", tone: "warn")]),
    ([Add output], [5-step wizard, conditional fields, Save Draft], [One dialog. DOI-first lookup + duplicate guard (good, unspec'd). No steps, no project step], [#pill("UI", tone: "warn")]),
    ([Statuses], [Review 5 · ORCID 5 · Website 4 · Quality 5, independent pills; "X / 5" featured], [Profile 3, output 3 + `rejection_reason`, ORCID yes/no, website none, quality admin-only; "Highlights · N"], [#pill("UI", tone: "warn")]),
    ([ORCID], [New · Matched · Differences · Duplicates · Not mine; "Add all unambiguous" + confirm], [Add / Not mine / Add all (everything, no confirm). `matched_output_id`, `find_similar_outputs` exist], [#pill("UI", tone: "warn")]),
    ([Edit own output], [Edit; approved → edit → "Changes Pending Review"], [No researcher write on `outputs`. Edit leaf is a stub], [#pill("DB", tone: "bad")]),
    ([Website state], [Separate from approval; "Approved · Not Published" valid], [Approval #emph[is] publication. No publish flag on `outputs`], [#pill("DB", tone: "bad")]),
  ),
  widths: (2.4cm, 1fr, 1fr, 1.5cm), right-from: 99,
)

= Supabase — now vs later

#data-table(
  ("Change", "Why not a UI hack", "When"),
  (
    ([`outputs.website_status`; `sync.py` reads it], [Approval ≠ publication is a fact the site build must read], [#pill("now", tone: "ok")]),
    ([`output_taxonomy.kind` (publication · activity) on the roots], [§K: no parallel taxonomy in the portal; hardcoded roots in Dart would be one], [#pill("now", tone: "ok")]),
    ([`enrichment_suggestions` policy: researcher may stage `subject_type='output'` on own outputs], [Reuses table + admin Accept. "Changes Pending Review" with no new table], [#pill("now", tone: "ok")]),
    ([`people.orcid_synced_at` stamped by `orcid_works.py`], ["Last synchronised" wanted in 3 places; candidates-derived fails for people with none], [#pill("now", tone: "ok")]),
    ([`output_identifiers` (DOI, ISBN, put-code)], [42 DOIs, 0 ISBNs. Add on second identifier type or two-way ORCID], [#pill("v1.1+", tone: "neutral")]),
    ([Provenance columns (`source_system`, `imported_at`, …)], [`change_log` already answers who/what/when/where], [#pill("v2.0", tone: "neutral")]),
    ([Rename review states (+ under_review, draft)], [Touches RLS, triggers, `sync.py`, `report_data()`, edge fn. A label map passes his tests], [#pill("v1.1+", tone: "neutral")]),
    ([Notifications table], [Derive from data], [#pill("no", tone: "neutral")]),
    ([Sanity merge layer (`feat/sanity-bridge`)], [§B.2 forbids it. Stays unmerged], [#pill("no", tone: "bad")]),
  ),
  widths: (5.8cm, 1fr, 1.6cm), right-from: 99,
)

= Confirm with Rui

#data-table(
  ("Topic", "14 Aug note", "10 Sep spec", "Assumed"),
  (
    (["Papers"], [N9 "render to papers" → "My papers", "Recent papers"], [Forbidden; acceptance test], [spec wins]),
    ([Profile Status page], [N8 "stays"], [§7 no separate page], [spec wins]),
    ([Sanity bridge], [—], [§B.2 no merge layer], [admin-only, unmerged; ask]),
  ),
  widths: (2.8cm, 1fr, 1fr, 3.2cm), right-from: 99,
)

= Build order (his Phase 1–9)

#data-table(
  ("Phase", "Work"),
  (
    ([1], [One additive migration (4 "now" rows); `sync.py` filter]),
    ([2], [Profile → one page; edits staged; bio compare reuses the ORCID matrix (`my_profile.dart`)]),
    ([3–5], [Outputs → one page, outputs only; counts, search, filters, views, "N / 5"; wizard DOI → Type → Subtype → Metadata → Project → Review; ORCID buckets as a view]),
    ([6–8], [Admin Publish action; `rejected` shown as "Changes requested"; Overview rebuilt from states; header bell]),
    ([9], [Nav → 5 items; WIP + Research Activity Reporting behind `v2`; tests, Maestro, docs (`nav_model.dart`)]),
  ),
  widths: (1.2cm, 1fr), right-from: 99,
)


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
  standfirst: [#pill("DATA OK", tone: "ok") The schema already held what the spec needs. #pill("BUILT", tone: "ok") Phase D closed the gap the same day: 10 waves, 17 PRs (#48–#64), 199 → 267 tests, 4 additive DB changes, nothing renamed, nothing behind `v2` deleted. Open: login landing, the live click-throughs, Rui's three answers.],
)

#kpi-row((
  ("9", "Match", "as specified"),
  ("17", "Partial", "data exists, UI half"),
  ("19", "Gap", "17 of them pure UI"),
  ("3", "Conflicts", "with his 14 Aug notes"),
))

= Rui wants vs we had — and what closed it

#data-table(
  ("Area", "Rui wants", "We had (10 Sep)", "Done"),
  (
    ([Navigation], [5 items: Overview · My Profile · Scientific Outputs · Resources & Guidance · Help & Contacts. No WIP, no sub-pages], [6 sections, 25 leaves, 8 "Work in progress" pages. 9 of our leaves are named as forbidden], [#pill("done", tone: "ok") D3 · #52 #53]),
    ([Overview], [Identity header, 3 status pills, "Needs Your Attention" with actions, "No action required", type counts, "N / 5 featured", "Recent Outputs"], [2 stat cards, one alert or literal "All good", "Recent papers", by-type WIP. All data present], [#pill("done", tone: "ok") D9 · #64]),
    ([Profile], [One page; every edit is a proposed change (Save Draft / Submit)], [6 routes; owner Edit writes `people` directly. Staging exists for 4 signature fields (`enrichment_suggestions`)], [#pill("done", tone: "ok") D4 · #54 #55]),
    ([Biography], [UNIDCOM vs ORCID, Compare, Import → proposal → review], [Single `bio`; ORCID matrix exists, admin-only v2, applies directly], [#pill("done", tone: "ok") D4 · #56]),
    ([Outputs page], [One page, views + filters; #strong[never] mix roles into outputs], [5 leaves; own timeline merges roles, tags, mentorships, labs and outputs], [#pill("done", tone: "ok") D5 · #60]),
    ([Filters], [Search · Year · Type · Project · Activity · Review · ORCID · Website · Featured], [Taxonomy cascade + Kind, year groups. `project_outputs`, `matched_output_id`, `v_output_quality` exist unused], [#pill("done", tone: "ok") D5 · #58 #60]),
    ([Add output], [5-step wizard, conditional fields, Save Draft], [One dialog. DOI-first lookup + duplicate guard (good, unspec'd). No steps, no project step], [#pill("done", tone: "ok") D6 · #61]),
    ([Statuses], [Review 5 · ORCID 5 · Website 4 · Quality 5, independent pills; "X / 5" featured], [Profile 3, output 3 + `rejection_reason`, ORCID yes/no, website none, quality admin-only; "Highlights · N"], [#pill("done", tone: "ok") D2 D4 · #50 #54]),
    ([ORCID], [New · Matched · Differences · Duplicates · Not mine; "Add all unambiguous" + confirm], [Add / Not mine / Add all (everything, no confirm). `matched_output_id`, `find_similar_outputs` exist], [#pill("done", tone: "ok") D7 · #63]),
    ([Edit own output], [Edit; approved → edit → "Changes Pending Review"], [No researcher write on `outputs`. Edit leaf is a stub], [#pill("done", tone: "ok") D1 D5 · #48 #59]),
    ([Website state], [Separate from approval; "Approved · Not Published" valid], [Approval #emph[is] publication. No publish flag on `outputs`], [#pill("done", tone: "ok") D1 D8 · #48 #62]),
  ),
  widths: (2.1cm, 1fr, 1fr, 2.6cm), right-from: 99,
)

= Supabase — now vs later

#data-table(
  ("Change", "Why not a UI hack", "When"),
  (
    ([`outputs.website_status`; `sync.py` reads it], [Approval ≠ publication is a fact the site build must read], [#pill("done", tone: "ok") D1 #48]),
    ([`output_taxonomy.kind` (publication · activity) on the roots], [§K: no parallel taxonomy in the portal; hardcoded roots in Dart would be one], [#pill("done", tone: "ok") D1 #48]),
    ([`enrichment_suggestions` policy: researcher may stage `subject_type='output'` on own outputs], [Reuses table + admin Accept. "Changes Pending Review" with no new table], [#pill("done", tone: "ok") D1 #48]),
    ([`people.orcid_synced_at` stamped by `orcid_works.py`], ["Last synchronised" wanted in 3 places; candidates-derived fails for people with none], [#pill("done", tone: "ok") D1 #48]),
    ([`output_identifiers` (DOI, ISBN, put-code)], [42 DOIs, 0 ISBNs. Add on second identifier type or two-way ORCID], [#pill("v1.1+", tone: "neutral")]),
    ([Provenance columns (`source_system`, `imported_at`, …)], [`change_log` already answers who/what/when/where], [#pill("v2.0", tone: "neutral")]),
    ([Rename review states (+ under_review, draft)], [Touches RLS, triggers, `sync.py`, `report_data()`, edge fn. A label map passes his tests], [#pill("v1.1+", tone: "neutral")]),
    ([Notifications table], [Derive from data], [#pill("no", tone: "neutral")]),
    ([Sanity merge layer (`feat/sanity-bridge`)], [§B.2 forbids it. Stays unmerged], [#pill("no", tone: "bad")]),
  ),
  widths: (5.8cm, 1fr, 1.6cm), right-from: 99,
)

#text(size: 8.5pt, fill: muted)[*Still to confirm with Rui:* "papers" wording (his 14 Aug note vs this spec — spec applied), the Profile Status page (removed as §7 says), the Sanity bridge (§B.2 forbids a merge layer — branch left unmerged), and the login landing (Getting Started today, Overview per §5).]

= Built — Phase D, 10 Sep 2026

#data-table(
  ("Wave", "What landed", "PRs"),
  (
    ([D1], [4 additive DB changes, live + rollback-tested; site filter], [#48, site #3]),
    ([D2–D3], [labels; sidebar 25 leaves → 5 items, 0 WIP pages], [#49–#53]),
    ([D4–D5], [profile one page, edits as proposals, bio compare; outputs page, filters, views, staged edit], [#54–#60]),
    ([D6–D9], [wizard; ORCID buckets; admin publish; Overview from real states + attention badge], [#61–#64]),
  ),
  widths: (1.4cm, 1fr, 2.6cm), right-from: 99,
)

#text(size: 8.5pt, fill: muted)[Tracker with every acceptance check: `PLAN.md` §Phase D. Rui's §V lines mapped to evidence: `audit/2026-09-rui-acceptance.md`. 199 → 267 tests; nothing behind `v2` deleted.]

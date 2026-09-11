// Phase D delivery — Rui's v1.0 Researcher Portal spec (10 Sep 2026) built the
// same day by Codex subagents under Claude orchestration. Numbers from PLAN.md
// §Phase D, GitHub PRs #48–#64, flutter test on main 3efb734. Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — Phase D delivery",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · Phase D delivery · 11 September 2026",
  lang: "en",
))
#set page(margin: (top: 1.6cm, bottom: 1.7cm, x: 1.9cm))

#title-block(
  "Researcher Portal v1.0 — what was built",
  subtitle: "Rui's specification (Documents 1 + 2, 10 Sep 2026) implemented on 10 Sep, live on 11 Sep.",
  meta-line: [Portal `main` 3efb734 · 17 PRs #48–#64 · one migration, applied live · 10 waves · 199 → 267 tests · `flutter analyze` 0 throughout],
  standfirst: [#pill("LIVE", tone: "ok") Every v1.0 item in the spec is on the deployed portal; nothing in the database was renamed or deleted, and every retired screen still exists behind `--dart-define=V2=true`. #pill("OPEN", tone: "warn") Live click-throughs by a researcher, Rui's three wording decisions, and the login landing page.],
)

#kpi-row((
  ("5", "Sidebar items", "was 25 leaves, 8 of them placeholders"),
  ("0", "Direct writes by researchers", "every edit is a reviewed proposal"),
  ("17", "Pull requests", "all CI-green, squash-merged"),
  ("267", "Automated tests", "from 199; 4 new pure logic modules"),
))

= Before and after — the spec's own measures

#data-table(
  ("Measure (Rui §4–§21)", "10 Sep morning", "11 Sep", "Where"),
  (
    ([Researcher navigation], [6 sections · 25 leaves · 8 "Work in progress"], [Overview · My Profile · Scientific Outputs · Resources & Guidance · Help & Contacts], [D3]),
    ([Profile], [6 pages; owner Edit wrote `people` directly], [1 page; "Propose changes" → admin Review queue; biography UNIDCOM vs ORCID with import-as-proposal], [D4]),
    ([Status shown to a researcher], [one badge], [ORCID · UNIDCOM · Website, text-labelled, on profile, Overview and every output row], [D2 D4]),
    ([Scientific Outputs], [5 pages; timeline mixing roles, labs, tags and outputs; 2 filters], [1 page, outputs only; type counts; search; Year · Type · Project · Activity · Review · Website · Featured; views All · Recent · Featured · Needs attention · ORCID reconciliation; group by Year · Type · Project], [D5]),
    ([Edit own output], [not possible (admin-only RLS)], [staged proposal, never a write], [D1 D5]),
    ([Add output], [one dialog], [wizard DOI → Type → Subtype → Metadata → Project → Review, fields conditional on type], [D6]),
    ([ORCID reconciliation], [flat list, "Add all" took everything], [New · Possible duplicates (with the recorded title) · Not mine; "Add all unambiguous (n)" behind a confirm], [D7]),
    ([Website publication], [approval = publication], [separate `website_status`, admin Publish / Unpublish, site publishes only approved ∧ published], [D1 D8]),
    ([Overview], [2 stat cards, "All good"], [identity + 3 pills, Needs Your Attention with actions, "No action required · Last checked", summary by type, Featured n / 5, Recent Outputs, sync line, badge in the sidebar], [D9]),
  ),
  widths: (3cm, 1fr, 1fr, 1.1cm), right-from: 99,
)

= Database — four additive changes, nothing renamed

#data-table(
  ("Change", "Why the UI could not fake it", "Check"),
  (
    ([`outputs.website_status` + audit trigger; `sync.py` filter], [approved ≠ published is a fact the site build must read], [365 rows backfilled `published`; 76 = 76 site publications before and after]),
    ([`output_taxonomy.kind` publication / activity], [§K: no parallel taxonomy in the portal], [38 / 36 leaves, 0 null]),
    ([`enrichment_suggestions` policy for own outputs], [reuses the admin Accept flow for output edits], [RLS test as researcher: own ok, other author 42501]),
    ([`people.orcid_synced_at`; `create_my_output(p_project_ids)`], ["Last synchronised" in 3 places; wizard links own projects only], [26 / 26 stamped; non-member project dropped]),
  ),
  widths: (5.6cm, 1fr, 5.2cm), right-from: 99,
)

Deferred with reasons in `PLAN.md`: identifier table (0 ISBNs today), provenance columns (`change_log` already answers), review-state rename (label map passes the acceptance tests), notifications table, Sanity merge layer (spec §B.2 forbids it).

= How it was built

#data-table(
  ("", ""),
  (
    ([Method], [Plan rows regrouped into tasks *by file*, one git worktree per task, a spec per task with allowed files, exact edits and acceptance commands with expected values. Orchestrator verified, committed, merged on CI, ticked the tracker.]),
    ([Agents], [Codex `gpt-5.6-luna` for ≤ 3-file tasks (11 runs), `gpt-5.6-sol` for page assembly (6 runs), ≈ 1.5 M tokens; three lines of code by the orchestrator.]),
    ([Quality], [Logic first as pure Dart with unit tests, widgets after; cross-task dependencies injected so every task compiled alone; no rework round after wave 3. Rollback-tested migration, CI on every PR, Playwright crawl of 81 screens, 4 / 4 read-only journeys, 36 acceptance lines mapped to evidence (22 automated · 13 code · 1 partial).]),
  ),
  widths: (2.2cm, 1fr), right-from: 99,
)

= Open

#data-table(
  ("Item", "Owner", "Effort"),
  (
    ([Live click-throughs: propose → Accept (profile, output); wizard; ORCID Add all], [André, test account], [30 min]),
    (["papers" vs "Outputs" and the Profile Status page — spec applied, confirm], [Rui], [—]),
    ([Login landing: Getting Started today, Overview per §5], [Rui], [1 h]),
    ([Sanity bridge branch: §B.2 forbids a merge layer; six RPCs `anon`-callable], [decision], [2 h]),
    ([Save draft for field edits (§14): not persisted in v1], [v1.1], [DB]),
    ([Audit flows `add_output` (old dialog), `featured_star` (no output on test account)], [dev], [1 h]),
  ),
  widths: (1fr, 2.6cm, 1.4cm), right-from: 99,
)

#text(size: 8.5pt, fill: muted)[Tracker: `PLAN.md` §Phase D (every row with its acceptance check and PR). Gap analysis: `docs/reports/2026-09-rui-spec-gap/`. Acceptance map: `audit/2026-09-rui-acceptance.md`. Crawl: `audit/2026-09-10-rui-phase-d/`.]

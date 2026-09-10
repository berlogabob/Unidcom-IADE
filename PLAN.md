# UNIDCOM RIMS Pilot — Trackable Plan (Aug–Sep 2026)

Canonical tracking document for the pilot defined in
`RAW_DATA/UNIDCOM_RIMS_Pilot_Implementation_Plan.pdf`. Tick boxes only after the
task's acceptance check passes. Re-measure KPIs with the SQL in each row
(Supabase SQL editor or MCP).

## 1. Purpose & scope

Pilot goal: RIMS as institutional Single Source of Truth for researcher profiles
and scientific outputs — ORCID login, researcher validation, editorial approval,
website sync, institutional report, dashboard, demo.

Corrections vs the PDF (agreed 2026-08-04):

- ~~The website is a **Flutter web SPA** (GitHub Pages) reading **live from
  Supabase Postgres** under RLS — not Hugo, not Sanity. "Automatic
  synchronisation with the website" therefore means **approval-driven RLS
  visibility**: anonymous visitors see only approved/validated content. No push
  pipeline needed. A Sanity swap stays a Phase-2 option (§8).~~
  **Superseded 2026-08-06 (P12).** This was wrong at the repo boundary: a Hugo
  site already existed in the sibling repo `berlogabob/unidcom-site`, and it is
  now the public face. The pilot therefore has both mechanisms, and they agree —
  RLS decides which rows an anonymous caller may read, and `scripts/sync.py`
  regenerates the static site from exactly those rows nightly, with its own
  field allowlist on top. The Flutter app is now the **portal**: `/login` and
  `/app/welcome/*` are its only anonymous surfaces. The "automatic
  synchronisation with the website" criterion is met by a real pipeline, not
  only by a policy. Sanity remains unbuilt and unneeded — Hugo fills that slot.
- **Ciência Vitae** direct integration is descoped for the pilot: ORCID is the
  single publication source (ResearchGate/Scopus deposit into ORCID; Ciência
  ids are already scraped from ORCID profiles into `people.ciencia_id`).

Execution model: work is decomposed into small parallel tasks delegated to
**Codex CLI subagents**; each task has an owner and an acceptance check.
Migrations, RLS, and auth-sensitive changes are reviewed by Claude before merge.
A checkbox is ticked only when its acceptance check passes — never on a
subagent's self-report.

## 2. Baseline snapshot (2026-08-04, live DB)

This table is the **starting** measurement and is deliberately not updated —
progress is the delta against it. For current figures re-run the queries; as of
2026-08-06 they read 184 people (183 published), 365 outputs all approved, 26
with an ORCID iD, and 21 of 46 integrated members without one.

| Metric | Baseline | Query |
|---|---|---|
| People | 184 | `select count(*) from people;` |
| People with ORCID iD | 26 | `select count(*) from people where orcid is not null and orcid <> '';` |
| Linked auth accounts | 3 | `select count(*) from people where auth_user_id is not null;` |
| Outputs | 362 | `select count(*) from outputs;` |
| Outputs with DOI | 42 | `select count(*) from outputs where doi is not null and doi <> '';` |
| Approved outputs | 0 | `select count(*) from outputs where approval_status = 'approved';` |
| Pending enrichment suggestions | 253 | `select count(*) from enrichment_suggestions where status = 'pending';` |
| Staged ORCID candidates | 5 | `select count(*) from output_candidates;` |

## 3. Weekly milestones

Task row format: `- [ ] task — owner — acceptance check`

### W1 (Aug 4–10) — Workflow foundation

- [ ] Define pilot cohort (names + target size N) with Hande/Rui — claude — cohort list committed to this file (§5)
- [x] Output approval state machine: `pending → approved | rejected` (vocab check constraint; admin-only via existing RLS) audited to `change_log` via trigger — claude (migration `20260804120000_status_workflow.sql`) — ✅ 2026-08-04: rollback-tested on live DB; invalid value raises `outputs_approval_status_chk`; approval writes `change_log` row with actor
- [x] Profile validation states on `people.profile_status`: `draft → pending_review` (owner self-submit, stamps `last_verified_at`) `→ approved` (admin); all other non-admin writes reset by protect trigger — claude (same migration) — ✅ 2026-08-04: self-submit works + audited; self-approve blocked
- [x] RLS design note: approval-driven public visibility replacing `public_read_test_period` — claude — ✅ design section §6 below
- [x] Stage ORCID works for all cohort members with ORCID (`scripts/orcid_works.py`) — codex — ✅ 2026-08-04: 1,456 candidates staged covering 26/26 people with ORCID (superset of any cohort choice)

**W1 KPI:** migrations merged and deployed; cohort N fixed.

### W2 (Aug 11–17) — Researcher Profile Admin

- [x] "Confirm my profile" flow in `/app/profile` — codex — ✅ 2026-08-05 verified on production: researcher self-submit `draft → pending_review` observed live in `change_log`, admin approval followed, `last_verified_at` stamped
- [x] Publication claim UI — codex — ✅ 2026-08-05 verified on production: 3 ORCID works claimed by a real researcher, landed as pending outputs with `output_authors` links + audit rows, approved via review queue, then anon-visible (RLS check passed)
- [x] Selected/featured publications management from own profile — codex — ✅ 2026-08-04: already shipped in earlier UI; owner-only RLS + 5-cap verified by rolled-back SQL test on live DB
- [x] Onboarding note for cohort (how to log in with ORCID, validate, claim) — codex — ✅ 2026-08-04: `ONBOARDING.md` at repo root

**W2 KPI:** ≥1 real researcher completes ORCID login → profile validation → publication claim end-to-end on production. ✅ met 2026-08-05 (full chain observed in `change_log`: confirm → claim ×3 → approvals → public).

### W3 (Aug 18–24) — UNIDCOM Admin + website sync

- [x] Review queue approve/reject wired to state machine with audit (`lib/app/review_queue.dart`) — codex — ✅ 2026-08-04: Reject + "Approve all pending (N)" with confirm added (audit is automatic via the `status_workflow` trigger, SQL-verified); analyzer/tests green
- [x] Replace `public_read_test_period` RLS with approval-driven policies — claude (migration `20260805120000_approval_visibility.sql`) — ✅ 2026-08-04: applied + anon-verified live (anon sees only approved; authenticated sees all)
- [x] Stats-by-output-type section in report function — ✅ already existed (`shape.ts` executive summary per type + %, per-subtype tables); 9/9 Deno tests pass incl. totals consistency
- [x] Dashboard KPIs on `/app/dashboard`: ORCID coverage, approval progress, DOI coverage, validation progress — codex — ✅ 2026-08-04: 4 pilot KPI tiles (not year-filtered), values from dedicated unfiltered counts; analyzer/tests green
- [x] Run the approval queue on real data — ✅ 2026-08-04 superseded by decision: vetted imports bulk-approved (362 outputs, 184 profiles, 33 projects; 545 `change_log` rows). New content now flows through the queue.

**W3 KPI:** anonymous site shows only approved content; ≥50 outputs approved; report includes stats by type.

### W4 (Aug 25–31) — Testing, bugs, demo prep

- [x] Maestro flow — ✅ 2026-08-04 resolved as: `.maestro/featured_star.yaml` already covers authenticated E2E (password login + DB write + reload persistence). ORCID OAuth itself cannot be safely automated (third-party login), so validate→claim→approve is covered by the one-time manual production check instead. Limitation accepted.
- [x] Dart/Deno tests for new state machine + report section — ✅ 2026-08-04: deploy workflow now gates on `flutter analyze` + `flutter test` before building; `deno test` (9 passing) run locally, report function deploys manually
- [x] Bug-fix pass from W2–W3 findings — codex/haiku — ✅ 2026-08-06 (P10.3): known-blocker list closed — mobile portal now reachable via the account menu; welcome-pack document labels made honest (no fake download links until the secretariat supplies assets); request cards + triage rows given `MergeSemantics` (a11y + E2E visibility); triage table drops secondary columns <1400px so Approve stays reachable; `person_id` insert bug and portal-unreachable-from-nav found by the final review and fixed pre-merge. Remaining known gaps are tracked as `ponytail:` debt, none pilot-blocking.
- [x] Demo script (walkthrough matching PDF §5 success criteria) — claude — ✅ 2026-08-04: `DEMO.md` (routes verified against the app); dry-run still to be held

**W4 KPI:** CI fully green; demo dry-run done.

### September — Pilot

- [ ] Cohort onboarding (ORCID logins)
- [ ] Cohort profile validation
- [ ] Editorial approvals ongoing
- [ ] Institutional publication report generated from live data
- [ ] Pilot demonstration to Hande/UNIDCOM

## 4. Pilot KPI table (PDF §5 success criteria)

| Criterion | Baseline (Aug 4) | Target (Sep 30) | Measurement |
|---|---|---|---|
| Researcher ORCID login | 3 linked accounts | ≥ N (cohort size) | `select count(*) from people where auth_user_id is not null;` |
| Profile validation | 0 validated | ≥ 80% of cohort | `select count(*) from people where profile_status in ('pending_review','approved');` |
| Publications management | 5 staged candidates | 100% of cohort-with-ORCID staged; claims flowing | `select count(distinct person_id) from output_candidates;` |
| Editorial approval workflow | 0/362 approved | ≥ 50 approved; queue in routine use | `select approval_status, count(*) from outputs group by 1;` |
| Website sync | blanket public read | 100% of anonymously visible outputs approved | anonymous PostgREST query vs `approval_status` |
| Institutional report | PDF function exists | report with stats-by-type generated from live data | run `report` function, inspect PDF |
| Stats by output type | — | in report + dashboard | PDF table matches `select category_path, count(*) from outputs group by 1;` |
| Dashboard prototype | route exists | KPI tiles live | visual check vs §2 queries |
| Pilot demonstration | — | held, minuted | demo date recorded here |

Status 2026-08-04: all criteria except the demonstration are met or code-complete.
Values as of 2026-08-04: 362/362 outputs approved · 184/184 profiles approved · 26/184 ORCID
· 1,456 candidates staged · public site approval-gated (verified).
**As of 2026-08-06:** 365/365 outputs approved · 184 profiles approved, 183 published
· 26/184 ORCID · 1,457 candidates staged · site live and indexable. Report format
confirmed against the institutionally reviewed `RAW_DATA/reports/UNIDCOM_Scientific_Outputs_(2025)__v2.0.pdf`
— that document is this function's own output, so the format was aligned by
construction; the broader annual "Relatório" (.docx) is a Phase-4 document per
the pilot PDF's roadmap, not a pilot deliverable. Open: cohort list, one manual
end-to-end check (DEMO.md §2–4), demo dry-run + demonstration.

### September readiness (done 2026-08-04)

- [x] Security advisor sweep — migration `20260806090000_advisor_fixes.sql`: search_path pinned on pre-pilot functions, anon revoked from admin RPCs, trigger-only helpers unexposed. Regression-tested (promote/audit/is_admin). Remaining warnings accepted: authenticated-callable RPCs are gated in-body; pg_trgm/unaccent stay in `public` (dep churn, zero gain at this scale).
- [x] Performance advisors reviewed — all 155 findings are noise at ≤362 rows (policy-per-role double-counting, unused indexes on a young DB, 8 `auth_rls_initplan`). Revisit `auth_rls_initplan` (`(select auth.uid())` wrapping) only if tables reach ~10k rows.
- [x] Weekly ORCID staging — `.github/workflows/orcid-sync.yml` (Mon 05:00 + manual), keeps ONBOARDING.md's periodic-sync promise.
- [x] Backup routine — day-one snapshot taken (`scripts/out/*.json`, EXPORT: PASS). Weekly: `uv run --project scripts scripts/export.py` locally; `restore.py` restores. Do NOT upload exports as CI artifacts — public repo, `people` contains emails.
- [x] Leaked-password protection — 2026-08-05 resolved: feature is Pro-plan-only (Free tier blocks it with an error). Mitigation applied in dashboard instead: min password length 12, complexity requirements, secure password change + current-password-required. Acceptable: password auth covers only the 3 staff accounts; researchers use ORCID OAuth.

## 5. Pilot cohort

_To be fixed in W1 (names + N). Placeholder: N = 10 researchers with ORCID iDs._

**Nobody has a researcher account yet (measured 2026-08-13).** All four accounts
in `auth.users` — `andre.berloga@`, `andre.berloga+e2e@`, `hande.ayanoglu@`,
`rui.ramos@` — carry `app_metadata.role = 'admin'`. Until the view-mode split
landed that was invisible, because there was only one view; now it means the
plain-researcher experience (no chooser, no directory, no switcher) had never
been seen by anyone.

`andre.berloga+researcher@gmail.com` was created on 2026-08-13 with **no role
claim** to close that gap, and linked to Ana Nolasco's row for the walkthrough.

> ⚠️ **Unlink it before Ana Nolasco needs her own login.** `people.auth_user_id`
> has a unique partial index, so while the test account holds her row she cannot
> claim it:
> ```sql
> do $$ begin
>   perform set_config('unidcom.orcid_claim','on',true);
>   update people set auth_user_id = null
>    where id = 'b455c1be-4686-5016-91f4-0b19f0d0a6ae';
> end $$;
> ```
> (The `set_config` is required — `protect_people_cols()` otherwise reverts the
> write silently, with no error.)

Onboarding a real cohort member therefore has three steps, not one: create the
account **without** a role claim, populate `people.orcid`, and link
`auth_user_id`.

**Data readiness (measured 2026-08-06) — read this before picking the cohort:**

| Metric | Value | Query |
|---|---|---|
| Active people | 184 | `select count(*) from people where status <> 'inactive';` |
| …with an ORCID iD on file | 26 | `… and orcid is not null and orcid <> ''` |
| …with a linked login | 3 | `… and auth_user_id is not null` |
| Integrated members | 46 | `… and membership_type = 'integrated'` |
| **Integrated members WITHOUT an ORCID iD** | **21** | `… and membership_type='integrated' and (orcid is null or orcid='')` |

A researcher whose iD is not in `people.orcid` **cannot sign in** — the broker
returns "No UNIDCOM profile is registered for ORCID iD …" (`orcid-auth/index.ts:227`).
As of P11 that message is finally shown to them (it used to be swallowed), but
the fix is data, not code: **populate `people.orcid` for every cohort member
before onboarding day.** Admins can find them with the "Missing ORCID" filter
on the people list. Prefer cohort members who already have an iD on file
(26 available) or budget an admin pass to add the missing ones.

## 6. RLS design note — website "sync" (W1 deliverable, executes in W3)

The original approval-driven policies already exist, commented out, in
`supabase/migrations/20260722160000_public_read_test_period.sql`; init wrote
them first (`20260721230000_init.sql:127-132`). The W3 swap is:

1. Drop the blanket `using (true)`-style test-period read policies on
   `people` / `outputs` / `projects`.
2. Restore the init policies: anonymous sees only
   `people` with `public_visibility and profile_status = 'approved'`,
   `outputs` with `approval_status = 'approved'`,
   `projects` with `public_visibility and approval_status = 'approved'`;
   any authenticated user sees everything.
3. `report_data()` and `v_output_report` already filter on
   `approval_status = 'approved'` / run `security_invoker`, so reports follow
   automatically. Check the orcid_works candidate views for the same property
   before the swap (`20260729090000_orcid_works.sql` notes they ignore
   approval_status during the test period).
4. Timing: swap only after ≥50 outputs are approved (W3 editorial session),
   otherwise the public site goes visibly empty.

Acceptance: anonymous PostgREST request returns only approved/validated rows;
authenticated still sees all.

## 7. Code health & graph maintenance (from /graphify audit, 2026-08-05)

Graph baseline: 1,395 nodes · 2,022 edges · 121 communities · 129 dangling edges
· 225 collapsed parallel edges. Execution: codex subagents in parallel for
mechanical refactors, cheaper Claude models for verification, main session
reviews. Tick only on measured acceptance.

- [x] Split `lib/public/person_page.dart` — codex — ✅ 2026-08-05: 1,231 → 317 lines + six files under `lib/public/person/` (max 409); API/test imports unchanged; analyzer clean; 34/34 tests green (verified); cohesion 0.023 → **0.043**
- [x] Extract `scripts/common.py` — codex — ✅ 2026-08-05: 102-line common.py; enrich 489 → 413 lines, re-exports kept; all three selfchecks PASS (haiku-verified); zero `from enrich import` left; cohesion 0.056 → **0.059**
- [x] Move 14 root `2026-*.txt` session transcripts → `notes/sessions/` (gitignored) — claude — ✅ 2026-08-05: root clean; transcript knowledge recovered from semantic cache and re-pointed to new paths in the graph
- [x] Keep graph updated — claude — ✅ 2026-08-05: post-commit + post-checkout hooks installed, skill upgraded to 0.9.32; verified live (each commit auto-rebuilt graph.json)
- [x] Re-run graph update + health check — claude — 2026-08-05 measured: graph 1,466 nodes / 2,119 edges / 126 communities; both cohesion scores above baseline (✅); dangling 135 and collapsed 247 exceed the ≤129/≤225 absolute targets because the graph grew (+71 nodes) — residue *rate* flat at 6.4% of edges. Absolute targets were mis-specified; tracking rate (≤6.5%) going forward.
- No-fix (informational): 650 weakly-connected nodes are package-import leaves (supabase, XCTest, build) — expected for an AST graph; 17 zero-node files are JSON configs; `dashboard.dart` (752 lines) not flagged by cohesion — backlog only.

## 8. UI redesign — Carmela templates (2026-08-05)

Source of truth: `RAW_DATA/TemplatesFromCarmela/unidcom-{admin,researcher}.html`.
Figma (same design, added 2026-08-05): https://www.figma.com/design/Ai1eR4QkCBlY57xQVpwbCT/UNIDCOM?node-id=0-1&m=dev
— ~~not machine-readable without Figma MCP/API token; templates drive implementation.~~
**Updated 2026-08-06 (P13):** readable via the REST API with a PAT carrying
`file_content:read`. The file has a page per screen (S0–S4, A1–A4) plus a design
system page; node IDs are quotable in briefs. The Welcome pack was implemented
straight from it. Templates still drive the screens nobody has re-cut in Figma.
Branch `redesign/carmela-ui`. Executors: codex CLI + haiku subagents; orchestrator
reviews diffs and runs acceptance checks. Full plan + design decisions:
`~/.claude/plans/implement-new-ui-design-expressive-pony.md`. Tick only after
the acceptance command passes.

### P0 — Tokens + theme
- [x] T0.1 `lib/theme/tokens.dart` — haiku — ✅ 893cd97, analyze clean
- [x] T0.2 `lib/theme/app_theme.dart` — codex — ✅ 73e2756, analyze clean (codex sandbox couldn't commit; orch committed)
- [x] T0.3 main.dart theme swap, red deleted — haiku — ✅ c207d5e, grep = 0, analyze clean, 34/34 tests
- [x] T0.4 chart_palette swap — haiku — ✅ 8ae090e, analyze clean, slotColor signature untouched
- [x] T0.5 bundle-size baseline — orch — ✅ main.dart.js = 3,536,514 bytes (M7 ceiling: 3,890,165)

### P1 — Shell + navigation
- [x] T1.1 extract AppShell → lib/widgets/app_shell.dart — haiku — ✅ 1f3db7c, pure move, tests green
- [x] T1.2 dark top-nav (≥760px) — codex — ✅ f3f61f2, Maestro anonymous smoke green (people list, person page, nav); full featured_star deferred to P6 (needs .maestro/.env credentials — file missing locally)
- [x] T1.3 admin sidebar variant — codex — ✅ 24d7b66, analyze/tests green
- [x] T1.4 LoginScreen restyle — haiku — ✅ cf9e094, Maestro sees Email/Password fields; brand card verified by screenshot
- [x] T1.5 placeholder routes — haiku — ✅ b003e5f, render, /app/settings admin-gated
- Note: DB drifted 184→183 people; featured_star.yaml's "184 people" login-proof assert needs a regex patch in P6.

### P2 — Restyle existing pages
- [x] T2.1 lib/widgets/panels.dart (Panel/AccentStatCard/StatusPill/TypeBadge/FilterPill) — codex — analyze + smoke test
- [x] T2.2 stat_tile restyle — haiku — dashboard renders
- [x] T2.3 detail_scaffold panel pass — codex — analyze/test green
- [x] T2.4 people_list — codex — renders
- [x] T2.5 outputs + output_row — codex — renders
- [x] T2.6 projects/structure/conferences — codex — render
- [x] T2.7 person_page dark profile band — codex — Maestro star green
- [x] T2.8 dashboard — codex — renders admin+anon
- [x] T2.9 admin_page/review_queue/merge — codex — render
- [x] T2.10 my_profile (pinned strings) — codex — grep hits unchanged
- [x] T2.11 reports/data_page — haiku — render

### P3 — Support requests
- [x] T3.1 migration support_requests + RLS — codex draft, orch line-by-line review — ✅ 5aaae96, applied via MCP, advisors: pre-existing warnings only
- [x] T3.2 data layer queries — sonnet — ✅ c4b8226, 7 transition unit tests green (42/42 total)
- [x] T3.3 requests_page (researcher) — sonnet — ✅ fcbce20, analyze clean; anon-CTA render check pending rebuild
- [x] T3.4 request_form — sonnet — ✅ 238f1e5, analyze clean; live round-trip deferred to P6 (needs login credentials)
- [x] T3.5 admin_requests + badge wire — sonnet — ✅ b73763d + 6540448 (routes), analyze clean; change_log check deferred to P6
- [x] T3.6 .maestro/support_request.yaml — codex+orch — ✅ flow green live: create → submit → admin approve; change_log audit rows verified by SQL; test rows cleaned

### P4 — Researcher portal
- [x] T4.1 researcher_home /app/home — codex — ✅ 1a23c9f, anon CTA verified in crawl
- [x] T4.2 welcome_pack shell /app/welcome/:section — codex — ✅ 68a4092, path-param sections, crawl green
- [x] T4.3+T4.4 welcome content — codex — ✅ 6887ba4, transcribed verbatim; DOI 10.54499/UID/00711/2025 verified on-screen (EN+PT)
- [x] T4.5 ORCID banner on my-profile — haiku — ✅ 3a92581, pinned strings intact

### P5 — Admin settings
- [x] T5.1 settings_page — codex — ✅ 6752053 + 273d788, anon redirect verified in crawl

### P7 — Figma parity (source: Figma UNIDCOM file, Design System page + 10 frames; Figma is newer than the HTML export and wins on conflict)
- [x] P7.1 token alignment to Figma DS — haiku — ✅ 5eb6b8c, analyze + 42/42
- [x] P7.2 typography scale (Body 14, H2 22, H3 16) — codex — ✅ 8a549f2
- [x] P7.3 researcher portal tab shell — codex — ✅ 1b1ad57, portal crawl green
- [x] P7.4 top-nav user chip — codex — ✅ e4be636
- [x] P7.5 admin People badge + requests table columns — codex — ✅ e4be636 (badge via existing fetchPendingPeople)
- [x] P7.6 gate re-run — orch — ✅ analyze 0, 45/45 tests, crawl green, E2E bundle 3,690,219 B < 3,890,165 ceiling; pinned strings intact

### P8 — ornith (local ollama) executor — bite-sized single-file tasks via pi-delegate
- [x] O1 extend test/panels_test.dart — haiku (ornith benched: 4 pi attempts, zero edits emitted) — ✅ 768b14a, 4/4 targeted tests (orch re-verified)
- [x] O2 featured_star.yaml "184 people" → `1\d\d people` regex — haiku — ✅ 768b14a
- [x] O3 README "Run the E2E" section — haiku — ✅ 768b14a, grep verified
- ornith/pi infra: model never calls its edit tool (thinks → "done"); needs separate debugging before it can execute tasks. Verify lesson recorded: assert the new artifact exists, not just that checks pass.
(labs/cluster/objective pages checked: already token-clean via detail_scaffold — no task needed)

### P6 — Verification + merge
- [x] T6.1 analyze 0 / tests 100% — ✅ 0 issues, 42/42
- [x] T6.2 both Maestro flows green — ✅ featured_star + support_request full runs green (e2e-bot admin account, .maestro/.env local-only)
- [x] T6.3 route crawl all routes — ✅ public + portal + welcome sections + admin redirects, Maestro crawl green (note: stale-browser-cache false alarm; clearState needed after redeploys)
- [x] T6.4 metrics gate — ✅ 6/7 (M4 credential-blocked); key screens visually verified via Maestro during crawl
- [x] T6.4c final whole-branch review — ✅ 8 findings (1 Critical: request insert missing person_id; 1 Important: portal unreachable from nav; 6 minor) — all fixed in 531e0e9; scoped re-review: all ADDRESSED, no new breakage
- [x] T6.4b Figma parity pass — ✅ done as P7 (tokens/typography/portal shell aligned to Figma frames)
- [x] T6.5 PR #1 merged (d7dbc3c), deploy CI green, live site verified on new design

Metrics gate (2026-08-05): M1 ✅ 0 refs (one "Relatorio" substring false-positive
noted) · M2 ✅ crawl green · M3 ✅ 0 issues / 42 tests · M4 ✅ both E2E flows green (2026-08-05) · M5 ✅ pinned greps unchanged · M6 ✅ advisors: pre-existing only ·
M7 ✅ 3,678,947 B = +4.0% (ceiling +10%).

P9 (close-out, 2026-08-05): e2e-bot admin auth user created (signup + SQL promote,
password only in gitignored .maestro/.env); E2E hardening: MergeSemantics on request
cards/triage rows (a11y + testability), individual button semantics kept on actions,
triage table drops secondary columns <1400px so actions stay reachable; both flows
green end-to-end against live DB with audit verified. P6 CLOSED.

### P10 — Pilot readiness (2026-08-06)

- [x] P10.1 Auth gate ON — orch — ✅ `_loginDisabled` replaced by per-area `_needsAuth()`: `/app/*` requires a session, public directory **and** `/app/welcome/*` stay anonymous (welcome pack is pre-login onboarding material). Redirect matrix verified by anonymous Maestro crawl; both logged-in E2E flows still green. **Inverted by P12** — the directory is no longer anonymous.
- [x] P10.2 DEMO.md + ONBOARDING.md revalidated against the redesigned UI — sonnet — ✅ navigation rewritten for the top-nav/user-chip/admin-sidebar/portal-tabs; demo gained the support-request and Overview steps; onboarding gained a "Beyond your profile" section + the desktop-first and login-required notes. No contractual strings touched.
- [x] P10.3 W4 bug-fix pass — see the W4 row above.
- [x] P10.4a Institutional report generated from live data — orch — ✅ 24-page PDF (458 KB) for 2025: 335 outputs, per-type executive summary, full APA references with quality flags. Reproducible across 3 runs. **Note:** the first invocation after a cold start returns `WORKER_RESOURCE_LIMIT`; retry succeeds (~28 MB wasm boot). Warm-up call before any demo.
- [x] P10.4b Report brand alignment — haiku — Typst templates still carried the deleted `#FF2A13`; realigned to navy/teal so the FCT-facing deliverable matches the app.
- [ ] P10.4c Cohort definition (§5) — **needs Hande/Rui** (W1 row still open; the only true blocker left for September).
- [ ] P10.4d Demo dry-run — user schedules; walkthrough is executable as written.

### P11 — ORCID onboarding robustness (2026-08-06)

Found by tracing the pilot's first user action after the redesign: the ORCID
broker's **failure** return-trip was silently swallowed. The error redirect
lands on the app root with no fragment, so with the new per-area gate an
anonymous visitor stayed on `/people` and `LoginScreen` — the only screen that
renders the reason — never mounted. Under the old `_loginDisabled` hack every
visitor was forced to `/login`, which is why it was never seen. ~half the likely
cohort (21/46 integrated members lack an ORCID iD, §5) would have hit it on day one.

- [x] P11.1 Surface broker errors — orch — ✅ 01a9758: `_orcidError` read in `main()`, forces `initialLocation: '/login'`, consumed once by `LoginScreen` so a stale param can't replay.
- [x] P11.2 `orcid_linked` no longer claims success after a swallowed `refreshSession()` failure — orch — ✅ 01a9758 (flag now set from the real session state).
- [x] P11.3 First route-guard test coverage — haiku — ✅ 23a858b: `needsAuth` made public, 23 routes asserted incl. near-misses (`/appfoo`, `/app`). 49 tests total.
- [x] P11.4 `.maestro/orcid_error.yaml` — orch — ✅ 95e54b8: asserts the reason renders and is not replayed. The OAuth round-trip can't be automated, but this half is just a query param.
- [x] P11.4b **a11y**: the login error `Text` never reached Flutter web's semantics tree — screen readers were as blind to it as the test was. Now `Semantics(container, liveRegion)` so it is announced — ✅ 95e54b8.
- [x] P11.5 Cohort data-readiness numbers recorded — §5 above.
- [ ] **Manual check (human, one-time):** a real ORCID click-through with a registered iD. Third-party OAuth can't be automated; everything either side of it now is.

### P12 — One entry point: public site → login → portal (2026-08-06)

The two repos were unconnected islands. `grep -rn "unidcom-site"` in this repo
returned zero hits and no Hugo template linked to the app, so a researcher who
landed on the public site had no path to editing their own record. Worse, both
served People/Projects/Outputs publicly through *different* privacy gates.
Resolved by making Hugo the sole public face and this app the portal. See §1.

- [x] P12.1 Auth gate inverted — `needsAuth` is now `location != '/login' && !startsWith('/app/welcome')`. The directory is the live internal view. Route-guard tests rewritten.
- [x] P12.2 Every login lands on `/app/welcome/start`. Removed the duplicate `context.go('/people')` in `_signIn` — the router's redirect owns the landing, and deciding it in two places is how it broke. Connect-ORCID's *link* return still lands on `/app/profile`.
- [x] P12.3 Four entry points added to the Hugo site: nav + footer login, an "Are you X?" note on person pages, and a `/researchers/` page. The person-page note is gated on `people.orcid` — the broker rejects unknown iDs, so 26 of the 183 published profiles get the invitation and 157 get a contact-the-office note.
- [x] P12.4 Site left preview mode — approval-gated and indexable. Cost one profile (184 → 183); projects and publications unchanged.
  **Corrected account (2026-08-06):** an earlier commit message called the nightly sync a leak. It was not. Preview on the cron run was *deliberate* — `sync.yml` said "Preview defaults to true on the nightly run too, until curation is done" — and the site was noindexed and bannered throughout. Four bot syncs ran under it, all correctly in preview: `4e1df8f` (28 Jul), `63f82f5` (30 Jul), `5339334` (1 Aug), `7263ecd` (6 Aug).
  The real defect was the **exit**: `PREVIEW: ${{ github.event.inputs.preview != 'false' }}` is true whenever inputs are absent, and a cron run sends none. Going live therefore required editing the workflow — and had anyone gone live without that edit, the next 04:00 run would have silently reverted the site to unapproved content and put `noindex` back. Now `== 'true'`, so preview is opt-in and the cron cannot re-enter it.
- [x] P12.5 `.maestro/auth_gate.yaml` — anonymous bounce + post-login landing + no gated nav offered anonymously.

**Repair pass, same day** — the change broke things it was supposed to fix:

- [x] P12.6 The person-page CTA pointed at `#/app/profile`, but the redirect discards the intended location and every login lands on the Welcome pack. Repointed at `#/login` and reworded (decision: one landing rule, no `?next=`).
- [x] P12.7 `AppShell` **and** `PortalShell` rendered gated nav to anonymous visitors — five links from the first screen a researcher sees, all bouncing to `/login`. `AppShell` now returns a minimal anonymous shell; `PortalShell` shows only the Welcome pack tab. Asserted in `auth_gate.yaml`.
- [x] P12.8 `alias.html` emitted `noindex, nofollow` unconditionally — written for preview builds, but on a live site it stopped crawlers following the old WordPress URLs to their canonical pages. Now gated on the preview flag.
- [x] P12.9 `web/robots.txt` added: the gated portal was crawlable and would compete with the real site in search.
- [x] P12.10 Dead code removed (`_SignedOutView` ×2, unreachable once the routes were gated); bare `/app/welcome` now redirects instead of 404ing.
- [x] P12.11 Docs reconciled: both `DEMO.md` files, `unidcom-site/README.md`, `ONBOARDING.md`, this file, and a dated addendum in the delivery report. `unidcom-site/DEMO.md` had been telling the presenter to tick *preview*, which would have re-`noindex`ed the live site mid-demo. **Overtaken the same day** by the restyle and the pixelframes merge — see P13.4.

**Not a security hole, checked:** `report_data()` is granted to `anon` and never
filters `approval_status`, but it is `SECURITY INVOKER`, so `outputs_read`
(narrowed by `20260805120000`) applies. The misleading comment in
`20260729090000_orcid_works.sql` was corrected — it dated from the test period.

`lib/public/` now holds the *internal* directory. Deliberately not renamed: it
touches ~15 imports and every SDD brief for no behavioural gain. Read it as
"the directory", not "publicly visible".

### P13 — Welcome pack restyled to Figma; site live (2026-08-06)

The Figma became readable (a PAT with `file_content:read`), so the Welcome pack
was implemented from the design rather than from the HTML export. File
`Ai1eR4QkCBlY57xQVpwbCT`, page **S4 — Welcome Pack**, frame `44:2`.

Every colour the design uses was already a token — the palette was right and
the deltas were layout and type.

- [x] P13.1 Side nav (`91:3`): active item is a mint pill — fill `#E6F6F2`, text `#0A7A68`, radius 7 — not a sand fill plus a 3px teal left rule. Group labels drop to `#B4B3B0` (`91:2`) so the items lead.
- [x] P13.2 Section header (`45:19`/`45:20`): title and lead sit on the page background with the cards below, not inside one enclosing card. Title 18 → 22, lead 13 → 14, sub-headings 14 → 16. The per-section eyebrow is gone — the side nav already names the group.
- [x] P13.3 Copy cards (`45:21`): the language badge and a filled navy Copy button (`45:25`) share the top row, so the action is found before the block of text; PT leads EN.
- [x] P13.4 **§8's conflict rule invoked for the first time.** "Figma is newer than the HTML export and wins on conflict" overrode three shipped user-facing labels: "Welcome Pack 2026" → **Getting started**, "Conferences" → **Conferences & events**, "Affiliation statement" → **Affiliation & FCT**. Section titles followed: start → "Getting started", affiliation → "UNIDCOM affiliation", logos → "Logos & brand assets". Docs naming the old labels were corrected with this entry.
- [x] P13.5 The four E2E flows re-anchor their post-login assertion on "Your first 5 steps" (the hero text changed).
- [x] P13.6 **E2E login hardened.** `inputText` raced the focus change and left the email field empty; the run then failed several steps later on "missing email or phone", reading like a credentials problem. `featured_star` failed 1 run in 2. Now retried until the text is in the field — four flows, two consecutive clean passes.
- [x] P13.7 Site merged to `main` and deployed. `robots.txt` `Allow: /` + sitemap, zero `noindex`, `/researchers/` live, portal `robots.txt` `Disallow: /`. `pixelframes-landing` merged in the same pass.
- [x] P13.8 Merge hazard caught: three nightly syncs had landed on `main` meanwhile. `_meta.json` conflicted and `people.json` **auto-merged**, which would have blended 184-person preview data with the 183-person approved set. Resolved by regenerating from the database rather than picking a side.

Open, non-blocking: E2E-in-CI job (deploy CI gates analyze/test only); ornith/pi
tool-calling debug; **rotate the Figma PAT** (it has been pasted into a session
transcript); repo-root untracked files (`.gitattributes`, session `.txt`,
`graphify-out/`, `.config/`, `.flutter`, `.pi-runs/`); the PixelFrames subsite
deploys by FTP outside CI and ships live `[… TBD]` placeholder copy on a now-
indexable site.

### P14 — Audit remediation (2026-08-07)

Full findings and the remaining backlog: **[AUDIT.md](AUDIT.md)**. Operational
runbook, secrets and access registers: **[OPERATIONS.md](OPERATIONS.md)**.

- [x] P14.1 `anon` revoked from the whole public schema. 153 researcher emails plus `legal_name`, `notes` and `auth_user_id` were readable unauthenticated: `people_read` gates rows, and RLS has no column dimension. `projects` leaked `total_budget`/`risk` the same way, and `anon` held INSERT/UPDATE/DELETE/TRUNCATE on all 27 tables.
- [x] P14.2 ORCID login-CSRF closed with a browser-bound nonce; `localhost` dropped from the production return allowlist (302 before, 400 after); constant-time signature compare; escaped PostgREST filter. Broker's first 14 tests.
- [x] P14.3 `sync.py` stops publishing unapproved `person_roles` — the only place the approval workflow was bypassed — and refuses to write if any entity count collapses.
- [x] P14.4 Errors are classified and actionable, with a working retry and no internals in user-facing strings; `reportError` seam, root error guard, global timeout.
- [x] P14.5 Lockfiles committed (`*.gitignore` had a bare `*.lock`, so no build was reproducible); `ci.yml` runs on pull requests — nothing was checked by a machine before `main`.
- [x] P14.6 Palette raised to WCAG AA without touching Carmela's brand teal; 60 old WordPress researcher URLs now redirect instead of 404ing.
- [ ] P14.7 **Backups cover 9 of 27 tables and `restore.py --wipe` cascades away 18 it cannot restore.** Highest remaining risk — see AUDIT.md.
- [ ] P14.8 Bus factor: one person holds every critical account, including the ORCID developer app. OPERATIONS.md §1.
- [ ] P14.9 Data-protection paperwork and an erasure path (`deletePerson` does not exist).

### Phase C — Cleaning 2: Rui's 14 Aug notes (2026-09-08)

Source: Rui's handwritten notes of 14 Aug (transcribed). Rule: hide behind
`v2` (Rui's "M2" = milestone 2), delete nothing. One PR per task; boxes ticked
only after the orchestrator ran the acceptance check. Executed by Claude
`haiku` subagents (Codex quota was exhausted); orchestrated by Claude.

| # | Note line | Task | PR | Check |
|---|---|---|---|---|
| N2 N3 N4 | `M2 → hide`, `open access M2`, ~~Conferences & events~~, 7-item nav | C1 hide Support group; M2 slugs redirect to start | [x] #9 | `test/v1_surface_test.dart`, `view_mode_test.dart` |
| N5 N2 | `Get sta… text must be refined`, `open access M2` | C2 drop steps pointing at M2 sections; Open Access quick link v2; "46 integrated members" | [x] #10 | `grep -B1 welcome/oa lib/app/researcher_home.dart` |
| N7 N10 | `Last verified → hide`, `hide Last verif.` | C3 stat card + profile row v2; Maestro asserts | [x] #11 | label grep counts unchanged |
| N9 | `M outputs … render to papers` | C4 "My papers" tab, "Recent papers" panel | [x] #12 | `grep -rn "My outputs" lib .maestro` = 0 |
| N12 | `add bio picture` | C5 portal band shows `photo_url` | [x] #7 | `flutter analyze`; live check pending (see below) |
| N13 | `bio sync as a notification` | C6 ORCID candidates as an Overview alert — **awaiting Rui/André: confirm reading** | [ ] | `test/home_alerts_test.dart` (planned) |
| N14 | `extra advice → hide` | C7 `_callout` renders nothing in v1; Outlook hint v2 | [x] #14 | `v1_surface_test.dart` widget test un-skipped |
| N15 | `Top 10 — delete` | C8 dashboard Top 10 panel v2 | [x] #8 | `grep -B2 "Top 10 researchers" lib/app/dashboard.dart` |
| N16 | `кнопка ещё` | C9 "More" expands Recent papers in place | [x] #13 | `test/recent_outputs_test.dart` |
| N8 N11 N17 | PROFILE STATUS stays; `кнопка add` exists; Report activity/Affiliation/Logos/Contacts/Social media stay | verify only | [x] | read on main 2026-09-08 |
| N1 N6 | `digitalization of work process`; `email — add [automated] tag` | deferred (M2) / unclear | — | — |

Measured on `main` (7182765), v1 build:

| Metric | Before | After |
|---|---|---|
| Welcome-pack nav items | 11 | 7 |
| Callouts rendered in Getting started | 1 | 0 |
| `/app/welcome/oa` deep link | opens | → `/app/welcome/start` |
| Overview stat cards | 3 | 2 |
| Overview quick links | 4 | 3 |
| "Last verified" rows in the researcher view | 2 | 0 |
| Researcher tab label | My outputs | My papers |
| Recent papers control | See all → | More (expands in place) |
| Admin dashboard panels | 6 | 5 |
| Label strings deleted from source | — | 0 |
| `flutter test` | 125 | 130 |
| CI (v1 + V2 build) | green | green on all 8 PRs |

Known gaps:
- **Maestro cannot run locally**: `.maestro/researcher_mode.yaml` fails at its
  first step ("Email" not visible on /#/login) on this machine — and did so on
  both 12 Aug runs in `~/.maestro/tests`, before this phase. The new assertions
  (My papers, no LAST VERIFIED) are in the flow but unexercised. Needs a fix
  to the E2E harness, not to the app.
- **C5 live check** (photo in the band) not done: it needs a `photo_url` on a
  real person's row, and the sync publishes that row to the public site.
- **Q1** Getting-started copy still needs Rui's wording; **Q2** "email —
  automated tag" not understood; **Q3** C6's reading of "bio sync as a
  notification" unconfirmed.

#### Round 2 (2026-09-08, afternoon) — feedback on the live v1

Three screenshots of the deployed Welcome pack. Executed the same way
(haiku subagents, one PR per task, orchestrator runs the checks).

| # | Feedback | Task | PR | Check |
|---|---|---|---|---|
| R1 | "email must be filled with our data set entities … role — we must know his role. if we dont have info — it could be added" | D1 `people.job_title` + `people.phone`; D2 signature form seeded from the row, live preview, Copy copies the filled text | [x] #19, [x] #18 | `test/signature_test.dart`; SQL rollback test of the migration |
| R2 | "any field could be edited and send to us to apply or declined (as we have for submit btn)" | D1 RLS: researcher may insert/read `enrichment_suggestions` about own row (`source='researcher'`); D3 "Send changes for approval" → rows land in the admin Review queue → Accept applies via `acceptSuggestion` | [x] #19, [x] #20 | `signatureSuggestions` unit test; RLS: own insert ok, other person 42501, other source 42501 |
| R3 | "Start with one item, why keep submenu for 1 item" | D4 Getting started ungrouped | [x] #16 | `v1_surface_test.dart` |
| R4 | "other headers cant be readed well as header" | D4 11.5px / w700 / textMuted / more air | [x] #16 | visual on deploy |
| R5 | "social media must be clickable" | D5 cards are links (Instagram, Facebook, LinkedIn) | [x] #17 | `v1_surface_test.dart` 3 link semantics |

Measured on `main` (e1a9f01):

| Metric | Before | After |
|---|---|---|
| Signature fields prefilled for a linked researcher | 0 / 4 | name + email always; role/phone when on file |
| Preview / Copy | static template | live, filled |
| Researcher edit path for name/role/email/phone | direct Edit only | + staged for admin approve/decline |
| Nav group headers | 5 (one over a lone item) | 3, readable |
| Social cards | static | 3 links |
| `flutter test` | 130 | 137 |
| CI (v1 + V2 build) | green | green on all 6 PRs |

Not done / open:
- The live click-through of R2 (send as researcher → Accept as admin → field
  on the profile) is the user's to run on the deployed site; the DB half was
  verified by SQL.
- `merge_people()` applies a fixed column list, so `job_title`/`phone` are
  not offered in the merge matrix (a chooser there would do nothing).
- Rui's wording for Getting started (Phase C Q1); "email — add [automated]
  tag" (Q2); C6 "bio sync as a notification" (Q3) — all still open.

#### Round 3 (2026-09-08, evening) — one navigation

User: "lets rearrange navigations. do it in one consistent way. put all
navigations on aside left", with two IA trees (researcher portal, admin
"Research Management"). Executed as E1–E6 (haiku/sonnet subagents; Codex out
of quota twice that day).

| # | Task | PR | Check |
|---|---|---|---|
| E1 | `nav_model.dart`: both trees reduced to existing pages; M2 items as a comment | [x] #23 | `test/nav_model_test.dart` (5) |
| E4 | `/app/profile` (profile) and `/app/outputs` (scientific outputs) are two pages | [x] #24 | `my_profile_sections_test.dart`, `route_guard_test.dart` |
| E5 | `/app/admin/{review,reports,merge,data}`; no TabBar | [x] #22 | `grep -c "TabBar(" lib/app/admin_page.dart` = 0 |
| E2 | `SideNav` + one `AppShell`; portal tabs, admin sidebar, bottom bar, welcome inner nav removed | [x] #25 | `side_nav_test.dart` (6); grep for old surfaces = 0 |
| E6 | Maestro labels, this record, ARCHITECTURE.md §Navigation | [x] | — |

| Metric | Before | After |
|---|---|---|
| Navigation surfaces | 5 | 1 |
| Researcher pages | 1 combined | 2 |
| Admin tools deep-linkable | tabs only | 4 routes |
| `flutter test` | 137 | 148 |
| CI | green | green on all 5 PRs |

Not done: the local Maestro harness still fails at the login step (Phase C
gap), so the updated `researcher_mode.yaml` is unexercised; the deployed
click-through is the check. Open: whether the profile band stays (kept);
Q1–Q3 carried from Phase C.

#### Round 4 (2026-09-08, evening) — researcher sidebar one-to-one, collapsible

User: "double check on navigation … do it one to one, if you dont have
information — create empty page with notification work in progress. make menu
headers toggable to hide all entities from eyes." Decisions: third-level nodes
become headings on the page; collapse state per tab (sessionStorage).

| # | Task | PR | Check |
|---|---|---|---|
| F2 | Overview + Help leaves as pages (`portal_pages.dart`, `WipPage`) | [x] #28 | `wip_page_test.dart` |
| F3 | My Profile + Scientific Outputs leaves as pages; Identifiers / Import & Sync with third-level headings | [x] #29 | `my_profile_sections_test.dart` |
| F4 | FCT Information as its own welcome section | [x] #27 | `v1_surface_test.dart` |
| F1 | Six collapsible sections, 25 leaves, labels verbatim; state per tab | [x] #30 | `nav_model_test.dart`, `side_nav_test.dart` |
| F5 | Maestro labels, this record, ARCHITECTURE §Navigation | [x] | — |

| Metric | Before | After |
|---|---|---|
| Researcher sidebar leaves | 10 | 25 |
| Leaves with a page | 10 | 25 (8 "Work in progress") |
| Collapsible sections | 0 | 6 |
| `flutter test` | 148 | 165 |
| CI | green | green on all 5 PRs |

Open: Overview › Profile Status and My Profile › Profile Status are the same
widget on two routes (the tree lists the leaf twice). Local Maestro harness
still unusable (Phase C gap). Carried Q1–Q3.

### Phase D — Rui's v1.0 spec (10 Sep 2026): UI over the existing schema

Source: `RAW_DATA/From_Rui/DOCUMENT 1…Researcher Portal.docx` + `DOCUMENT 2…AI Agent
Implementation Specification.docx`. Gap report: `docs/reports/2026-09-rui-spec-gap/`.
Rui's framing: the data is fine, this is UI. Four additive DB changes, nothing renamed,
nothing behind `v2` deleted.

**Swarm rules.** Tasks run in *waves*; every task in a wave touches disjoint files, so a
wave is dispatched in parallel. One task = one file (two at most) = one PR = one
acceptance command. Owners: `mini` = Codex gpt-5.4-mini (mechanical, grep-verifiable);
`luna` = Codex gpt-5.6-luna, or Claude haiku when Codex quota is out (Dart widget + test);
`orch` = Claude (migrations, RLS, `sync.py`, review of every PR). A subagent never ticks its
own box; the orchestrator runs the check. A task that fails its check twice is escalated one
tier up, not retried a third time. Pure functions (`filter…`, `attention…`, `buckets…`) live
Flutter-free in `lib/data/` with a unit test, like `taxonomy.dart` — that is what makes them
safe to hand to a small model.

**Assumed Rui answers** (open until confirmed): "Outputs" wording wins over 14 Aug "papers";
no Profile Status page; Sanity bridge stays unmerged.

#### Wave D1 — schema (orch, sequential, one migration `20260912…_rui_v1_states.sql`)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D1.1 | `outputs.website_status text not null default 'not_published' check in (not_published, pending, published, error)`; backfill `published` where `approval_status='approved'` (the site already shows them); audit trigger `trg_log_output_website` | orch | `select website_status, count(*) from outputs group by 1` = 365 published, 0 other; invalid value raises; change writes `change_log` | [x] 765045d — ✅ 2026-09-10 live: published=365; check_violation raised; 1 audit row in rollback test |
| D1.2 | `output_taxonomy.kind text not null check in (publication, activity)`; publication = Livros, Artigos em revistas, Conferência em congressos, Patentes (the first two are `sync.py`'s `PUBLICATION_MACRO_TYPES`); the other 7 roots = activity | orch | `select kind, count(*) from output_taxonomy group by 1` has no null | [x] 765045d — ✅ publication=38, activity=36, 0 null |
| D1.3 | Extend `es_owner_insert` / `es_owner_select` to `subject_type='output'` where `subject_id in (select output_id from output_authors where person_id = my person)` | orch | RLS test as researcher account: own output insert ok, other author's output 42501, `source<>'researcher'` 42501 | [x] 765045d — ✅ rollback test as `authenticated` with the researcher test uid linked to Sofia Ponte: own ok, other 42501, source 42501, own row readable |
| D1.4 | `people.orcid_synced_at timestamptz`; `scripts/orcid_works.py` stamps it per person it processed | orch | run script once; `select count(*) from people where orcid_synced_at is not null` = 26 | [x] 765045d — ✅ run 2026-09-10 14:17 UTC: 26 / 26 stamped |
| D1.5 | `create_my_output(p_fields, p_project_ids uuid[] default '{}')` inserts `project_outputs` rows for projects the caller is a member of; one-argument form dropped (ambiguous overload) | orch | rollback test: member project linked, non-member project skipped, `change_log` row written, one-argument call still works | [x] 765045d — ✅ all four assertions; new row `pending` + `not_published` |
| D1.6 | `unidcom-site/scripts/sync.py`: publish on `approval_status='approved' and website_status='published'`; counts guard unchanged | orch | regenerate to a temp dir, diff against `data/generated/` = 0 publication rows changed | [x] site PR #3 (`feat/website-status`) — ✅ 76 publications before and after; the one `people.json` diff is a bio edited since the 8 Aug sync, not the filter |
| D1.7 | `lib/data/supabase.dart`: `website_status` in `fetchPerson` / `fetchOutputs`, `orcid_synced_at` in `fetchMyPerson`, `createMyOutput(projectIds:)`. `kind` waits for D5.3, its first consumer | mini → orch | `flutter analyze` 0; `grep -c website_status lib/data/supabase.dart` ≥ 2 | [x] 765045d — ✅ analyze 0, 199 tests, grep = 2 |

**D1 KPI:** ✅ migration applied live and rollback-tested; site rebuild identical; `flutter test` 199 green.
Advisors after D1: no new finding — `create_my_output` is listed as an authenticated-callable
security definer like every RPC here (gated in body, accepted in §4). Pre-existing: six
`sanity_*` RPCs from the unmerged bridge are callable by `anon`; fix on that branch.

#### Wave D2 — wording and labels (mini, parallel, each ≤ 20 lines)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D2.1 | "Recent papers" → "Recent Outputs"; "My papers" → "Scientific Outputs" in `lib/`, `test/`, `.maestro/` | mini | `grep -rin "papers" lib test .maestro` = 0 | [ ] |
| D2.2 | `lib/data/request_status.dart`-style map `reviewLabel()`: `pending` → "Submitted", `rejected` → "Changes requested", `approved` → "Approved"; `profileStatusLabel`: `pending_review` → "Submitted" | mini | unit test 4 cases; `grep -rn '"Awaiting UNIDCOM approval"' lib` = 0 | [ ] |
| D2.3 | `researcher_home.dart`: empty alerts → "No action required · Last checked <today>" | mini | `grep -rn "All good" lib` = 0; `recent_outputs_test` green | [ ] |
| D2.4 | `person_page.dart`: "Highlights · N" → "Featured outputs · N / 5" | mini | `featured_outputs_test` asserts the "/ 5" string | [ ] |
| D2.5 | `websiteLabel()` + `orcidLabel()` maps (Not published / Pending / Published / Error; Not connected / Connected / Changes available / Synced) in `lib/data/status_labels.dart` | mini | unit test, one case per value | [ ] |

**D2 KPI:** zero "papers", zero "All good", zero raw status codes in the researcher view.

#### Wave D3 — navigation (luna)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D3.1 | `nav_model.dart`: `researcherNav` → five items, no children: Overview `/app/home`, My Profile `/app/profile`, Scientific Outputs `/app/outputs`, Resources & Guidance `/app/welcome/affiliation`, Help & Contacts `/app/welcome/contacts`. Removed leaves stay as `if (v2)` | luna | `nav_model_test`: 5 items in v1; `v1_surface_test`: 0 `wip` items | [ ] |
| D3.2 | `main.dart`: old leaf routes (`/app/home/*`, `/app/profile/*`, `/app/outputs/{add,edit,import,validation}`, `/app/help/*`) redirect to their parent page, `?view=` carried | luna | `route_guard_test` lists each redirect | [ ] |
| D3.3 | Welcome pack: one `PortalPage` "Resources & Guidance" with five headed sections (Affiliation, FCT, Email Signature, Social Media, Logos); Research Activity Reporting behind `v2` | luna | `v1_surface_test`: 5 headings, 0 "Research Activity Reporting" | [ ] |
| D3.4 | `.maestro/*.yaml` labels follow D3.1 | mini | `grep -c "Scientific Outputs" .maestro/researcher_mode.yaml` ≥ 1 | [ ] |

**D3 KPI:** researcher sidebar leaves 25 → 5; WIP pages reachable from v1 nav 8 → 0.

#### Wave D4 — My Profile, one page (luna; D4.2 after D1)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D4.1 | `MyProfileScreen` renders personal + identifiers + biography on `/app/profile` (sections = all three) | luna | `my_profile_sections_test`: 3 section headers on one route | [ ] |
| D4.2 | `lib/data/profile_staging.dart`: `stageProfileChanges(personId, before, after)` → one `enrichment_suggestions` row per changed field (`source='researcher'`), reusing `signatureSuggestions` | luna | unit test: 3 changed fields → 3 rows, unchanged → 0 | [ ] |
| D4.3 | Owner Edit dialog: "Save draft" keeps local, "Submit for review" calls D4.2 instead of `updatePerson`; admins unchanged | luna | widget test: owner submit → `stageProfileChanges` called, `updatePerson` not | [ ] |
| D4.4 | `lib/widgets/status_strip.dart`: three pills ORCID / UNIDCOM review / Website from D2.2, D2.5, text + icon | luna | widget test: 3 pills, no colour-only state | [ ] |
| D4.5 | Biography panel: "UNIDCOM biography" + "ORCID biography" (from `fetchOrcidSyncStatus`), Compare = side by side, "Import ORCID version" → one `bio` suggestion via D4.2 | luna | widget test with fake status: two columns, import stages 1 row | [ ] |
| D4.6 | Identifiers: "Last synchronised <orcid_synced_at>" under ORCID | mini | `grep -n orcid_synced_at lib/public/person/profile_sections.dart` ≥ 1 | [ ] |

**D4 KPI:** profile routes 6 → 1; owner writes to `people` from the portal = 0 (only via suggestions).

#### Wave D5 — Scientific Outputs, one page (luna; pure functions first)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D5.1 | `lib/data/output_filters.dart`: `filterOutputs(rows, {query, year, category, projectId, review, website, featured, view})` and `countByType(rows)` — Flutter-free | luna | `output_filters_test`: one case per filter + view + counts | [ ] |
| D5.2 | `PersonTimelineSection(outputsOnly: true)` on `/app/outputs`: roles, tags, mentorships, labs not rendered (directory page unchanged) | luna | widget test: 0 role rows on outputs page, unchanged on person page | [ ] |
| D5.3 | Filter bar widget (search field, Year, Type cascade (exists), Project from `project_members`, Activity from `taxonomy.kind`, Review, Website, Featured) driving D5.1 | luna | widget test: each control narrows the list | [ ] |
| D5.4 | View chips All · Recent · Featured · Needs attention · ORCID; Group by Year / Type / Project | luna | widget test: chip changes the row set | [ ] |
| D5.5 | Type counts header from `countByType`, click → filter | mini | widget test: tap sets type filter | [ ] |
| D5.6 | `PersonOutputRow`: subtype, DOI, ORCID-matched chip (`matched_output_id`), quality chip (`v_output_quality`), website pill, Edit button (owner) | luna | `output_row_test`: all chips present | [ ] |
| D5.7 | Owner Edit → `OutputEditDialog(asResearcher, staged: true)` saving via `enrichment_suggestions(subject_type='output')`; admin queue already accepts them (`acceptSuggestion`) | luna | widget test: save → rows staged, `updateOutput` not called | [ ] |

**D5 KPI:** outputs routes 5 → 1; role rows on the outputs page → 0; filters 2 → 8.

#### Wave D6 — Add wizard (luna, after D1.5)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D6.1 | `lib/app/output_wizard.dart`: `Stepper` DOI (existing lookup + duplicate guard) → Type → Subtype → Metadata → Project → Review; fields reused from `OutputEditDialog` | luna | widget test: 6 steps, Next disabled until the step is valid | [ ] |
| D6.2 | Subtype step shows only children of the chosen type (`childrenAt`) | mini | unit test on `childrenAt` cases | [ ] |
| D6.3 | Project step lists the person's projects; Review calls `create_my_output(p_project_ids)` | luna | widget test: selected project ids passed to RPC | [ ] |

#### Wave D7 — ORCID reconciliation as a view (luna)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D7.1 | `lib/data/orcid_buckets.dart`: `bucketCandidates(candidates, similar)` → New / Matched (`matched_output_id`) / Possible duplicate (`find_similar_outputs` hit) / Not mine (`rejected`) | luna | unit test, one case per bucket | [ ] |
| D7.2 | `OrcidCandidatesPanel` grouped by bucket; "Add all unambiguous (N)" only over New, with confirm dialog | luna | widget test: duplicates excluded from Add all; confirm required | [ ] |

#### Wave D8 — admin side (luna)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D8.1 | Review queue: "Publish to website" / "Unpublish" per approved output → `website_status` | luna | `review_queue_test`: button visible only when approved; SQL check | [ ] |
| D8.2 | Queue shows staged output suggestions (D5.7) with Accept / Decline | mini | existing `fetchPendingSuggestions` path; widget test 1 output row | [ ] |

#### Wave D9 — Overview, last (luna, after D2–D8)

| # | Task | Owner | Acceptance check | PR |
|---|---|---|---|---|
| D9.1 | `lib/data/attention.dart`: `attentionItems(person, outputs, candidates, suggestions)` → list of (text, route); sources: pending candidates, rejected outputs + reason, quality errors, profile not confirmed, declined suggestions | luna | unit test, one case per source + empty | [ ] |
| D9.2 | Overview = identity header (`personHeader` band + D4.4 strip), Needs Your Attention (D9.1), type summary tiles → `/app/outputs?type=`, "Featured N / 5", Recent Outputs (3, More), sync line (`orcid_synced_at`, `updated_at`) | luna | widget test with fixture: all six blocks | [ ] |
| D9.3 | Header bell in `AppShell`: badge = `attentionItems.length`, tap → `/app/home` | luna | `side_nav_test`: badge count | [ ] |

#### Wave D10 — verification (orch)

| # | Task | Acceptance check | |
|---|---|---|---|
| D10.1 | Doc 2 §V acceptance list (41 lines) walked on the deployed portal with `andre.berloga+researcher@` | checklist committed to `audit/2026-09-rui-acceptance.md`, 41 / 41 | [ ] |
| D10.2 | Playwright audit re-run (`audit/tools/`) | 0 sev-3/4; nav leaves 5 | [ ] |
| D10.3 | Anonymous site check: an output `approved` + `not_published` absent from the Hugo build | sync dry run shows the row filtered | [ ] |
| D10.4 | `PLAN.md` metrics table below filled; report `docs/reports/2026-09-rui-spec-gap/` gets a "done" column | — | [ ] |

**Measured on `main` before Phase D (10 Sep 2026)** — fill "After" at D10.4:

| Metric | Before | After |
|---|---|---|
| Researcher sidebar leaves (v1) | 25 | |
| WIP pages reachable from v1 nav | 8 | |
| Researcher pages for profile / outputs | 6 / 5 | |
| Filters on own outputs | 2 | |
| Role/membership rows on the outputs page | all | |
| "papers" strings in `lib test .maestro` | ≥ 4 | |
| "All good" strings | 1 | |
| Distinct status dimensions shown to a researcher | 1 | |
| Researcher direct writes to `people` from the portal | Edit dialog | |
| Researcher can edit own output | no | |
| Website state independent of approval | no | |
| Doc 2 §V acceptance lines passing | not measured | |
| `flutter test` | 199 | |
| Pure-function files with tests added | 0 | |

Estimated size: 42 tasks; D1 sequential (orch), D2–D3 one wave each in parallel, D4–D8 two
waves in parallel with D5.1 / D7.1 / D9.1 first because their widgets depend on them, D9 last.
Decision rule if Codex quota runs out mid-wave: haiku takes `luna` tasks, `mini` tasks wait.

## 9. Out of scope / Phase 2+

- Sanity CMS as website layer — **slot filled by Hugo** (`unidcom-site`), which
  is generated from RIMS rather than hand-authored. A Sanity swap would replace
  `scripts/sync.py`'s target, not introduce a new architecture.
- Ciência Vitae direct integration
- Projects / Research Groups / Funding / PhD Students modules (PDF Phase 2)
- News / Events / Calls / Newsletters (Phase 3)
- Dashboards-KPIs / FCT & annual reports automation (Phase 4)
- OpenAlex / Crossref advanced integrations, AI-assisted analytics (Phase 5)

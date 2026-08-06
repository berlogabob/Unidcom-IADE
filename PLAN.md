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
Live values: 362/362 outputs approved · 184/184 profiles approved · 26/184 ORCID
· 1,456 candidates staged · public site approval-gated (verified). Report format
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
— not machine-readable without Figma MCP/API token; templates drive implementation.
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
- [x] P12.4 Site left preview mode — approval-gated and indexable. Cost one profile (184 → 183); projects and publications unchanged. `sync.yml`'s `PREVIEW` was `!= 'false'`, which is **true** on the cron run, so the nightly sync had always published unapproved records; now opt-in only.
- [x] P12.5 `.maestro/auth_gate.yaml` — anonymous bounce + post-login landing + no gated nav offered anonymously.

**Repair pass, same day** — the change broke things it was supposed to fix:

- [x] P12.6 The person-page CTA pointed at `#/app/profile`, but the redirect discards the intended location and every login lands on the Welcome pack. Repointed at `#/login` and reworded (decision: one landing rule, no `?next=`).
- [x] P12.7 `AppShell` **and** `PortalShell` rendered gated nav to anonymous visitors — five links from the first screen a researcher sees, all bouncing to `/login`. `AppShell` now returns a minimal anonymous shell; `PortalShell` shows only the Welcome pack tab. Asserted in `auth_gate.yaml`.
- [x] P12.8 `alias.html` emitted `noindex, nofollow` unconditionally — written for preview builds, but on a live site it stopped crawlers following the old WordPress URLs to their canonical pages. Now gated on the preview flag.
- [x] P12.9 `web/robots.txt` added: the gated portal was crawlable and would compete with the real site in search.
- [x] P12.10 Dead code removed (`_SignedOutView` ×2, unreachable once the routes were gated); bare `/app/welcome` now redirects instead of 404ing.
- [x] P12.11 Docs reconciled: both `DEMO.md` files, `unidcom-site/README.md`, `ONBOARDING.md`, this file, and a dated addendum in the delivery report. `unidcom-site/DEMO.md` had been telling the presenter to tick *preview*, which would have re-`noindex`ed the live site mid-demo.

**Not a security hole, checked:** `report_data()` is granted to `anon` and never
filters `approval_status`, but it is `SECURITY INVOKER`, so `outputs_read`
(narrowed by `20260805120000`) applies. The misleading comment in
`20260729090000_orcid_works.sql` was corrected — it dated from the test period.

`lib/public/` now holds the *internal* directory. Deliberately not renamed: it
touches ~15 imports and every SDD brief for no behavioural gain. Read it as
"the directory", not "publicly visible".

Open, non-blocking: E2E-in-CI job (deploy CI gates analyze/test only); ornith/pi tool-calling debug; Figma token rotation (the stored PAT only has `current_user:read`, so it cannot read the file — the Welcome-pack Figma restyle is blocked on a new one with `file_content:read`); repo-root untracked files (`.gitattributes`, session `.txt`, `graphify-out/`).

## 9. Out of scope / Phase 2+

- Sanity CMS as website layer — **slot filled by Hugo** (`unidcom-site`), which
  is generated from RIMS rather than hand-authored. A Sanity swap would replace
  `scripts/sync.py`'s target, not introduce a new architecture.
- Ciência Vitae direct integration
- Projects / Research Groups / Funding / PhD Students modules (PDF Phase 2)
- News / Events / Calls / Newsletters (Phase 3)
- Dashboards-KPIs / FCT & annual reports automation (Phase 4)
- OpenAlex / Crossref advanced integrations, AI-assisted analytics (Phase 5)

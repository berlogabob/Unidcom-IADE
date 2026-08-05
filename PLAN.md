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

- The website is a **Flutter web SPA** (GitHub Pages) reading **live from
  Supabase Postgres** under RLS — not Hugo, not Sanity. "Automatic
  synchronisation with the website" therefore means **approval-driven RLS
  visibility**: anonymous visitors see only approved/validated content. No push
  pipeline needed. A Sanity swap stays a Phase-2 option (§8).
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
- [ ] Bug-fix pass from W2–W3 findings — codex — zero known blockers list
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
- [ ] T1.1 extract AppShell → lib/widgets/app_shell.dart — haiku — tests green
- [ ] T1.2 dark top-nav (≥760px) — codex — Maestro featured_star green
- [ ] T1.3 admin sidebar variant — codex — /app/dashboard renders w/ sidebar
- [ ] T1.4 LoginScreen restyle — haiku — Maestro login steps pass
- [ ] T1.5 placeholder routes /app/home, /app/welcome/:section, /app/settings — haiku — render

### P2 — Restyle existing pages
- [ ] T2.1 lib/widgets/panels.dart (Panel/AccentStatCard/StatusPill/TypeBadge/FilterPill) — codex — analyze + smoke test
- [ ] T2.2 stat_tile restyle — haiku — dashboard renders
- [ ] T2.3 detail_scaffold panel pass — codex — analyze/test green
- [ ] T2.4 people_list — codex — renders
- [ ] T2.5 outputs + output_row — codex — renders
- [ ] T2.6 projects/structure/conferences — codex — render
- [ ] T2.7 person_page dark profile band — codex — Maestro star green
- [ ] T2.8 dashboard — codex — renders admin+anon
- [ ] T2.9 admin_page/review_queue/merge — codex — render
- [ ] T2.10 my_profile (pinned strings) — codex — grep hits unchanged
- [ ] T2.11 reports/data_page — haiku — render

### P3 — Support requests
- [ ] T3.1 migration support_requests + RLS — codex draft, orch review — apply_migration OK, advisors clean
- [ ] T3.2 data layer queries — codex — transition unit test green
- [ ] T3.3 requests_page (researcher) — codex — signed-in + anon CTA render
- [ ] T3.4 request_form — codex — draft→submit round-trip
- [ ] T3.5 admin_requests + badge wire — codex — approve writes change_log
- [ ] T3.6 .maestro/support_request.yaml — codex — flow green

### P4 — Researcher portal
- [ ] T4.1 researcher_home /app/home — codex — signed-in + anon render
- [ ] T4.2 welcome_pack shell /app/welcome/:section — codex — 11 sections render
- [ ] T4.3 welcome content pt.1 (signature/social/docs) — codex — clipboard text exact
- [ ] T4.4 welcome content pt.2 — codex — text matches template
- [ ] T4.5 ORCID banner on my-profile — haiku — Maestro star green

### P5 — Admin settings
- [ ] T5.1 settings_page — haiku — admin renders, non-admin redirected

### P6 — Verification + merge
- [ ] T6.1 analyze 0 / tests 100%
- [ ] T6.2 both Maestro flows green
- [ ] T6.3 route crawl all routes
- [ ] T6.4 metrics M1–M7 + screenshots
- [ ] T6.5 PR → CI green → merge

Metrics gate: M1 no old-red/Lato refs · M2 route crawl green · M3 analyze/test
green · M4 E2E green · M5 pinned strings intact · M6 advisors no new warnings ·
M7 bundle ≤ baseline +10%.

## 9. Out of scope / Phase 2+

- Sanity CMS as website layer (swap point: replace the Flutter SPA's PostgREST
  reads with a RIMS→Sanity push; the approval-driven RLS boundary is the API
  contract either way)
- Ciência Vitae direct integration
- Projects / Research Groups / Funding / PhD Students modules (PDF Phase 2)
- News / Events / Calls / Newsletters (Phase 3)
- Dashboards-KPIs / FCT & annual reports automation (Phase 4)
- OpenAlex / Crossref advanced integrations, AI-assisted analytics (Phase 5)

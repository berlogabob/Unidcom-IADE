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
  pipeline needed. A Sanity swap stays a Phase-2 option (§7).
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
- [ ] Stage ORCID works for all cohort members with ORCID (`scripts/orcid_works.py`) — codex — `output_candidates` has rows for 100% of cohort-with-ORCID

**W1 KPI:** migrations merged and deployed; cohort N fixed.

### W2 (Aug 11–17) — Researcher Profile Admin

- [ ] "Confirm my profile" flow in `/app/profile`: researcher reviews data, hits Validate → `profile_status = pending_review` — codex — Dart test + manual flow on production
- [ ] Publication claim UI: researcher selects from their `output_candidates` → promoted to `outputs` (pending approval) with authorship link — codex — claimed candidate appears in `outputs` linked via `output_authors`
- [ ] Selected/featured publications management from own profile — codex — featured flag settable by owning researcher only (RLS test)
- [ ] Onboarding note for cohort (how to log in with ORCID, validate, claim) — codex — one-page doc in repo

**W2 KPI:** ≥1 real researcher completes ORCID login → profile validation → publication claim end-to-end on production.

### W3 (Aug 18–24) — UNIDCOM Admin + website sync

- [ ] Review queue approve/reject wired to state machine with audit (`lib/app/review_queue.dart`) — codex — approve in UI flips status + writes `change_log`
- [ ] Replace `public_read_test_period` RLS with approval-driven policies (approved outputs; validated+public profiles) — claude (migration) — anonymous PostgREST query returns only approved/validated rows
- [ ] Stats-by-output-type section in report function (`supabase/functions/report/`) — codex — generated PDF contains per-type counts table matching SQL
- [ ] Dashboard KPIs on `/app/dashboard`: ORCID coverage, approval progress, DOI coverage, cohort validation progress — codex — tiles match §2 queries
- [ ] Run the approval queue on real data (editorial session with UNIDCOM) — claude+team — ≥50 outputs approved

**W3 KPI:** anonymous site shows only approved content; ≥50 outputs approved; report includes stats by type.

### W4 (Aug 25–31) — Testing, bugs, demo prep

- [ ] Maestro flow: login → validate profile → claim publication → admin approve → visible on public site — codex — flow green on CI/local run
- [ ] Dart/Deno tests for new state machine + report section — codex — `flutter test` and `deno test` green in CI
- [ ] Bug-fix pass from W2–W3 findings — codex — zero known blockers list
- [ ] Demo script (walkthrough matching PDF §5 success criteria) — claude — dry-run held

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

## 7. Out of scope / Phase 2+

- Sanity CMS as website layer (swap point: replace the Flutter SPA's PostgREST
  reads with a RIMS→Sanity push; the approval-driven RLS boundary is the API
  contract either way)
- Ciência Vitae direct integration
- Projects / Research Groups / Funding / PhD Students modules (PDF Phase 2)
- News / Events / Calls / Newsletters (Phase 3)
- Dashboards-KPIs / FCT & annual reports automation (Phase 4)
- OpenAlex / Crossref advanced integrations, AI-assisted analytics (Phase 5)

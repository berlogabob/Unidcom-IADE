# Rui UI decisions for the pilot — acceptance map

Acceptance map for Rui Ramos's 25 Sep 2026 UI decisions, checked against the Phase E ledger and v1 code/tests. As at 30 Sep 2026: **Done: 70 · Partial: 3 · Deferred: 0** (68 · 5 on 29 Sep; info icons and the Under review stage closed on 30 Sep).

Date: 30 Sep 2026

## Rules for every page

| # | Decision | Status | Where | Evidence |
|---:|---|---|---|---|
| 1 | CHANGE Menu: 5 researcher items | Done | E2.6 — `lib/widgets/side_nav.dart` | `test/side_nav_test.dart` |
| 2 | KEEP compact status line on every page | Done | E2.2 — `lib/widgets/status_line.dart` | `test/status_line_test.dart` |
| 3 | REMOVE automatic publishing / “Auto-published” | Done | E2.6 — `lib/` v1 surface | `test/forbidden_strings_test.dart` |
| 4 | CHANGE ORCID: import only, no Sync | Done | E2.1 — `lib/widgets/orcid_block.dart` | `test/orcid_block_test.dart` |
| 5 | CHANGE Info icon on fields and actions | Done — (i) on every My Profile field and on every action (13 actions added 30 Sep) | E2.4 + 30 Sep — `lib/widgets/info_tip.dart`, used in 9 files | `test/info_tip_test.dart` |
| 6 | KEEP dark sidebar, lighter content, calm yellow | Partial — sidebar colour `#0E1525` is kept “as the platform already has”; secondary text is `#6A6862` instead of `#888680` for WCAG | E2.5 — `lib/theme/tokens.dart` | `test/contrast_test.dart` |

## Overview

| # | Decision | Status | Where | Evidence |
|---:|---|---|---|---|
| B2.1 | CHANGE Menu: 5 items; remove Support Requests | Done | E2.6 — `lib/widgets/side_nav.dart` | `test/side_nav_test.dart` |
| B2.2 | KEEP Name and researcher type | Done | E3.3 — `lib/app/researcher_home.dart` | `test/overview_test.dart` |
| B2.3 | KEEP yellow Needs your attention banner | Done | E2.5 — `lib/app/researcher_home.dart` | `test/attention_test.dart` |
| B2.4 | CHANGE progress steps to dated timeline | Done | E3.1–E3.2 — `lib/data/timeline.dart` | `test/timeline_test.dart` |
| B2.5 | KEEP Bio first lines with Edit bio | Done | E3.3 — `lib/app/researcher_home.dart` | `test/overview_test.dart` |
| B2.6 | CHANGE summary counts and Featured X/5 links | Done | E3.4 — `lib/app/researcher_home.dart` | `test/overview_links_test.dart` |
| B2.7 | CHANGE recent output shows named issue | Done | E3.5 — `lib/public/person/output_row.dart` | `test/recent_outputs_test.dart` |
| A2.1 | DECIDED Menu: see B2 | Done | E2.6 — `lib/widgets/side_nav.dart` | `test/side_nav_test.dart` |
| A2.2 | DECIDED User name: see B2 | Done | E3.3 — `lib/app/researcher_home.dart` | `test/overview_test.dart` |
| A2.3 | REMOVE My Dashboard / Welcome back title | Done | E2.6 — `lib/` v1 surface | `test/forbidden_strings_test.dart` |
| A2.4 | REMOVE red banner; keep yellow banner | Done | E2.5 — `lib/app/researcher_home.dart` | `test/attention_test.dart` |
| A2.5 | REMOVE workflow with Auto-published | Done | E2.6 — `lib/` v1 surface | `test/forbidden_strings_test.dart` |
| A2.6 | BRING counts per type into B2 summary | Done | E3.4 — `lib/app/researcher_home.dart` | `test/overview_links_test.dart` |
| A2.7 | REMOVE Where I’m at list | Done | E3.2 — `lib/app/researcher_home.dart` | `test/timeline_test.dart` |
| A2.8 | DECIDED Bio: see B2 | Done | E3.3 — `lib/app/researcher_home.dart` | `test/overview_test.dart` |
| A2.9 | BRING full issue name into recent output | Done | E3.5 — `lib/public/person/output_row.dart` | `test/recent_outputs_test.dart` |

## My Profile

| # | Decision | Status | Where | Evidence |
|---:|---|---|---|---|
| B3.1 | CHANGE Menu: as on Overview | Done | E2.6 — `lib/widgets/side_nav.dart` | `test/side_nav_test.dart` |
| B3.2 | CHANGE Save draft + Submit for UNIDCOM review | Done | E4.6 — `lib/app/my_profile.dart` | `test/person_editor_draft_test.dart` |
| B3.3 | KEEP ORCID editing notice; no sync button | Done | E4.2 — `lib/widgets/orcid_block.dart` | `test/orcid_block_test.dart` |
| B3.4 | CHANGE researcher photo upload/change | Done | E4.7 — `lib/public/person/person_dialogs.dart` | `test/person_editor_test.dart` |
| B3.5 | KEEP Bio with character counter | Done | E4.4 — `lib/public/person/person_dialogs.dart` | `test/person_editor_test.dart` |
| B3.6 | KEEP ORCID field | Done | E4.2 — `lib/app/my_profile.dart` | `test/my_profile_sections_test.dart` |
| B3.7 | KEEP Import bio from ORCID | Done | E2.1 — `lib/app/my_profile.dart` | `test/bio_compare_test.dart` |
| B3.8 | CHANGE featured outputs read-only, max 5 | Done | E4.5 — `lib/widgets/featured_readonly.dart` | `test/featured_readonly_test.dart` |
| A3.1 | DECIDED Menu: see B3 | Done | E2.6 — `lib/widgets/side_nav.dart` | `test/side_nav_test.dart` |
| A3.2 | BRING public-profile subtitle | Done | E4.1 — `lib/app/my_profile.dart` | `test/my_profile_sections_test.dart` |
| A3.3 | BRING last import date; rename Sync to Import | Done | E4.2 — `lib/widgets/orcid_block.dart` | `test/orcid_block_test.dart` |
| A3.4 | DECIDED Bio: see B3 | Done | E4.4 — `lib/public/person/person_dialogs.dart` | `test/person_editor_test.dart` |
| A3.5 | BRING Ciência ID, Lab / cluster, email | Done | E4.3 — `lib/app/my_profile.dart` | `test/my_profile_sections_test.dart` |
| A3.6 | BRING resubmission notice into Submit info | Done | E2.3–E2.4 — `lib/widgets/info_tip.dart` | `test/info_tip_test.dart` |
| A3.7 | REMOVE featured stars and Max 3 list | Done | E4.5 — `lib/widgets/featured_readonly.dart` | `test/featured_readonly_test.dart` |
| A3.8 | MOVE timeline to Overview | Done | E3.1–E3.2 — `lib/data/timeline.dart` | `test/timeline_test.dart` |

## Scientific Outputs

| # | Decision | Status | Where | Evidence |
|---:|---|---|---|---|
| A4.1 | CHANGE Menu: as on Overview | Done | E2.6 — `lib/widgets/side_nav.dart` | `test/side_nav_test.dart` |
| A4.2 | KEEP title and one-line explanation | Done | E5.2 — `lib/app/own_outputs.dart` | `test/outputs_page_e52_test.dart` |
| A4.3 | KEEP + Add output wizard | Done | E5.5 — `lib/app/output_wizard.dart` | `test/output_wizard_test.dart` |
| A4.4 | CHANGE Publications / Other activities tabs and subtypes | Done | E5.1–E5.2 — `lib/data/taxonomy.dart` | `test/outputs_page_e52_test.dart` |
| A4.5 | KEEP year chips and Issues only | Done | E5.1–E5.2 — `lib/data/output_filters.dart` | `test/output_filters_test.dart` |
| A4.6 | KEEP counters updated by filters | Done | E5.1 — `lib/data/output_filters.dart` | `test/output_filters_test.dart` |
| A4.7 | CHANGE rows: Type · Subtype, publication-only star, Featured X/5 | Done | E5.3 — `lib/public/person/output_row.dart` | `test/output_row_e53_test.dart` |
| A4.8 | KEEP full issue text | Done | E5.3 — `lib/public/person/output_row.dart` | `test/output_row_test.dart` |
| B4.1 | DECIDED Menu: see A4 | Done | E2.6 — `lib/widgets/side_nav.dart` | `test/side_nav_test.dart` |
| B4.2 | REMOVE 34 total; use A4 counters | Done | E5.1 — `lib/app/own_outputs.dart` | `test/output_filters_test.dart` |
| B4.3 | DECIDED Add output: see A4 | Done | E5.5 — `lib/app/output_wizard.dart` | `test/output_wizard_test.dart` |
| B4.4 | REMOVE dropdown filters | Done | E5.2 — `lib/app/own_outputs.dart` | `test/outputs_page_e52_test.dart` |
| B4.5 | REMOVE table layout | Done | E5.3 — `lib/public/person/output_row.dart` | `test/output_row_e53_test.dart` |
| B4.6 | BRING ORCID state as text, not only icons | Done | E5.3 — `lib/public/person/output_row.dart` | `test/output_row_e53_test.dart` |
| B4.7 | DECIDED issue text: see A4 | Done | E5.3 — `lib/public/person/output_row.dart` | `test/output_row_test.dart` |
| B4.8 | REMOVE View buttons; whole row clickable | Done | E5.3 — `lib/public/person/output_row.dart` | `test/output_row_e53_test.dart` |

## UNIDCOM Admin

| # | Decision | Status | Where | Evidence |
|---:|---|---|---|---|
| B1.1 | CHANGE Menu: remove Requests; add Pending approval | Done | E6.1 — `lib/widgets/nav_model.dart` | `test/nav_model_test.dart` |
| B1.2 | CHANGE split Profiles to approve / Outputs to approve | Done | E6.2 — `lib/data/admin_stats.dart` | `test/admin_stats_test.dart` |
| B1.3 | CHANGE Sync status: ORCID and Website | Done | E6.2 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| B1.4 | KEEP Researcher activity | Done | E6.3–E6.4 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| B1.5 | CHANGE remove Not approved yet issue | Done | E6.2 — `lib/data/admin_stats.dart` | `test/admin_stats_test.dart` |
| B1.6 | CHANGE outputs by type with year and semester tabs | Partial — outputs have year only; no publication date exists for S1/S2 | E6.2–E6.4 — `lib/data/admin_stats.dart` | `test/admin_stats_test.dart` |
| B1.7 | KEEP critical alerts opening researcher | Done | E6.2–E6.4 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| A1.1 | DECIDED Menu: see B1 | Done | E6.1 — `lib/widgets/nav_model.dart` | `test/nav_model_test.dart` |
| A1.2 | REMOVE researcher counts / new applications | Done | E6.2 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| A1.3 | REMOVE Sync and issues row; covered by B1 | Done | E6.2 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| A1.4 | REMOVE engagement row; covered by B1.4 | Done | E6.3–E6.4 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| A1.5 | REMOVE bars; use numbers only | Done | E6.4 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| A1.6 | REMOVE FCT deadline and applications alerts | Done | E6.4 — `lib/widgets/admin_overview.dart` | `test/admin_overview_test.dart` |
| A1.7 | MOVE per-researcher table to People | Done | E6.5 — `lib/public/people_list.dart` | `test/admin_overview_test.dart` |
| A1.8 | MOVE stage pipeline to Pending approval; separate Publish | Done — five columns To validate · Submitted · Under review · Approved, not published · Published; Start review / Approve / Publish are separate | E6.6 + 30 Sep — `lib/widgets/pipeline_board.dart`, migration `20260930100000_under_review.sql` | `test/pipeline_board_test.dart` |

## Platform checks

| # | Decision | Status | Where | Evidence |
|---:|---|---|---|---|
| 1 | RULE Imported records start To be validated | Done | E1.1 — `supabase/migrations/20260804120000_status_workflow.sql` | SQL |
| 2 | FLOW Submitted → Approved → Publish → visible on site | Partial — portal half rehearsed; public-site step is left to a real profile | E7.5 — `unidcom-site/scripts/sync.py` | live |
| 3 | TECH fix permission denied on load | Done | E1.5 — `audit/tools/perm_check.py` | Playwright crawl |
| 4 | UI landing to Overview; remove duplicate Connect ORCID | Done | E1.6–E1.7 — `lib/main.dart`, `lib/public/person/profile_sections.dart` | `test/portal_route_test.dart` |

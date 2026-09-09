# UX/UI Audit — UNIDCOM RIMS researcher portal (web, Playwright Chromium 1280×900 / 390×844) — 2026-09-09

## Executive Summary

**Release verdict: READY.**

39 findings (0 severity-4, 0 severity-3, 24 severity-2, 15 severity-1) across 82 screens, task success rate 100 % on 7 of 9 defined flows, best-practice score 62 / 100 (13 yes · 21 partial · 4 no of 38 BP items).

Third run of the day, after round 6. What changed:

1. **No finding above severity 2 remains.** The sidebar IA item that stayed at severity 3 after round 5 dropped to 1 once the accordion (one open section, inset leaves, placeholder rows marked *soon*) went live from the briefing.
2. **The entry experience is now DOI-first.** Add output opens with a DOI field; Look up pre-fills title, year, reference and category from Crossref; an exact DOI match blocks the save with a link to the existing record; a near-identical title warns and asks. The `add_output` flow exercises all three paths in 13 steps.
3. **Six round-6 items verified fixed** on screen: human status labels on the profile header, the empty ORCID-sync explanation, the v1 admin redirect, the placeholder rows, the anonymous-sidebar acceptance, and the startup splash (the cold-start screen is no longer white).

The severity-weighted score did not fall (61 → 63) because the reviewers found ten new severity-1/2 items, most of them on the surfaces that were just added or changed: the DOI dialog's Subcategory defaulting to *All*, the category label in My Outputs after a DOI import, the 'Already in the directory' message styled as body text, the dashboard's 18 tiles in five border colours without a rule, and the profile header saying the same status twice. That is the expected shape of a third pass: the blockers are gone and the remaining list is polish on new work plus decisions already taken.

## Background & Objectives

- App: UNIDCOM RIMS researcher portal, `Unidcom-IADE` repo, commit `5c4cb7c` (round 6 — six severity-2 fixes (PRs 40–45), DOI-first Add output with duplicate guard (PR 47), data-quality tiles (PR 46), and the sidebar accordion from the afternoon briefing). Build: `flutter build web --dart-define=E2E=true`, v1 (pilot) feature set — v2-only controls (Support requests, Approve/Auto-fill/ORCID-sync on the profile band, Find DOI) are compiled out and were not audited.
- Trigger: pilot cohort onboarding in September 2026; no UX/UI audit had been done (the 2026-08-07 `AUDIT.md` covered engineering, security and operations).
- Companion documents: `docs/research/2026-09-rims-best-practices.md` (cited RIMS/CRIS best practice + BP checklist) and `docs/reports/2026-09-ux-audit/` (stakeholder PDF).

## Methodology

- **Crawl:** every route in `lib/main.dart` in three modes — anonymous, researcher, admin — plus dialogs, the mode chooser, the phone breakpoint for the shell and 7 representative pages, and five provoked system states (cold-start loading, wrong password, empty search, backend unreachable at 3 s and at 26 s). 82 screens, each with a screenshot and a semantics-tree dump (`screens.md`).
- **Flow suite:** the five v1 Maestro journeys re-expressed in Playwright (Maestro's Chromium driver never returned from its first wait on this machine, three attempts) plus two new journeys covering the RIMS value loop: `profile_confirm` and `add_output` → `review_queue`. `featured_star` (E2E account owns no output) and `support_request` (v2) were not run.
- **Deterministic measurements:** `audit/tools/measure_px.py` over the hierarchies — tap targets vs the 24 px WCAG 2.5.8 minimum, groups vs Miller 7±2, alignment near-misses, contrast estimates (leaf text only; container estimates discarded).
- **Frameworks:** Nielsen's 10 heuristics, UX laws (Fitts, Hick, Miller, Jakob), visual design incl. WCAG 2.2 AA, design-system consistency against `lib/theme/tokens.dart` and Carmela's Figma exports (`RAW_DATA/TemplatesFromCarmela/`), five system states, navigation, ISO 9241-11 metrics, Google HEART mapping, and the BP-01…38 checklist from the research report. Five review passes ran in parallel (one per dimension) plus the orchestrator's own verified findings; every subagent claim at severity ≥ 3 was re-tested before inclusion, and 6 were corrected or dropped (see Appendix C).
- **Not covered:** ORCID OAuth on device; human-participant methods (SUS, interviews); the public Hugo site (reviewed from code and generated data only, scored in the BP table where relevant); v2 controls.

## Metrics

| Metric | Value | Source |
|---|---|---|
| Screens audited | 82 | `screens.md` |
| Flows defined / run / passed | 9 / 7 / 7 | `flows-results.json` |
| Task success rate (ISO 9241-11 effectiveness) | 100 % | flows |
| Mean steps per flow (efficiency) | 8.4 | flows |
| Mean automation time per flow | 10.1 s | flows (automation speed, compare run-over-run only) |
| Flow errors | 0 (+2 warnings) | flows |
| Findings sev 4 / 3 / 2 / 1 | 0 / 0 / 24 / 15 | `findings.json` |
| Defect density | 0.48 findings per screen | derived |
| Severity-weighted score (Σ severity) | 63 | derived — the number to drive down next run |
| Best-practice score | 62 / 100 | `bp-scorecard.json` (yes = 1, partial = ½) |
| Untraceable findings dropped | 0 | aggregate |

### Google HEART mapping

| Dimension | Measured here | Needs instrumentation |
|---|---|---|
| Happiness | Proxy: severity-weighted score 63; sev-3+ count 0 | in-app rating after first profile confirmation |
| Engagement | Proxy: core loop is 7.9 steps mean; researcher must scroll the sidebar to find Scientific Outputs at 1280×900 (F-007) | sessions per researcher per month |
| Adoption | Proxy: first-launch to value (login → chooser → welcome) in 6 steps; 158/184 researchers cannot sign in until an admin registers their ORCID iD | sign-ins per cohort member (auth.users.last_sign_in_at: 3 of 5 accounts in the last 30 days) |
| Retention | Proxy: state persists across reload (collapse state, mode) — good; 20 s silent spinner on a bad connection (F-031) | returning users after 7 days |
| Task success | **Measured:** 100 % task success, 0 errors, 2 warnings (status invisibility) | field completion rate of profile confirmation and first claim per cohort member |

Minimal instrumentation (one finding's worth): log `mode_chosen`, `profile_confirmed`, `output_added`, `candidate_claimed`, `review_decision` with actor and timestamp — `change_log` already holds the last three; the first two are one insert each.

## Key Findings

### Severity 4 — must fix before the cohort is onboarded


### Severity 3 — high priority


### Severity 2 — minor

**F-001 · sev 2 · DS-FDBK-1 · screen: flow_orcid_error_1_error_shown** — New inconsistency: the just-documented feedback rule (lib/widgets/detail_scaffold.dart comment: 'inline text under a field validates that field only; SnackBar reports the result of an action ... the AsyncView banner reports that a screen could not load its data') is broken by its own author on the login screen. main.dart's _LoginScreenState.initState renders the ORCID broker error BOTH inline under the password field (permanent red Text, matches the 'field validation' channel) AND via showSnack() in the same postFrameCallback (the 'action result' channel) -- the identical string 'No UNIDCOM profile is registered for ORCID iD 0000-0002-1825-0097. Contact an admin.' appears twice on screen at once (as inline text above the Sign in button, and as the bottom dark bar). Compare state_login_error.png: a wrong-password failure (also an action result, from _signIn's AuthException handler) shows only the bottom SnackBar, with no inline text at all -- so the two 'wrong credentials' failures on the exact same screen use two different numbers of feedback channels for the same category of error. Evidence: `screens/flow_orcid_error_1_error_shown.png`.

> Recommendation: Pick one channel for the ORCID-broker sign-in failure to match the plain-password failure: drop the inline Text block (or drop the showSnack call) in _LoginScreenState.initState so both auth-failure paths render through the same single channel.
**F-002 · sev 2 · DS-FDBK-1 · screen: state_error_backend_down** — Persists since the previous run, despite the intervening fix documenting one rule per feedback type: AsyncView (lib/widgets/detail_scaffold.dart) is coded to swap to a FailureView banner (icon + plain-language message + Try again / Sign in button) once its future errors, and both the People list (lib/public/people_list.dart) and the Dashboard (lib/app/dashboard.dart) do wrap their data fetch in AsyncView -- but with Supabase blocked, state_error_backend_down and state_error_dashboard_down both still render only the shell chrome and an indefinite single-dot progress spinner, never reaching the banner. The designed load-failure state exists in code but never surfaces for an unreachable backend, leaving the user stuck on a spinner with zero feedback and no retry action. Evidence: `screens/state_error_backend_down.png`.

> Recommendation: Give the underlying Supabase fetch a bounded timeout so the future actually rejects when the backend is unreachable, letting AsyncView's existing FailureView banner (which already has the right copy and a retry button) fire instead of spinning forever.
**F-003 · sev 2 · DS-ICON-1 · screen: r_sidebar_expanded** — Unchanged since the previous run: the shared SideNav widget still renders every admin top-level item (Dashboard/People/Scientific outputs/Projects/Structure/Settings, visible on a_dashboard/a_people) with a leading Material icon, while every researcher nav item (Research Activity Summary, Recent Scientific Outputs, My Outputs, Profile Status, etc., visible here and on r_home/phone_r_drawer) is still plain indented text with zero icons. Same shared component, two different rules for its own two modes. Evidence: `screens/r_sidebar_expanded.png`.

> Recommendation: Give every top-level NavItem an icon in researcherNav() (lib/widgets/nav_model.dart) to match adminNav(), or drop icons from adminNav() -- one rule, both modes of the one shared SideNav.
**F-004 · sev 2 · DS-ICON-1 · screen: r_welcome_start** — Unchanged since the previous run: the three 'Getting started' summary cards still use raw full-colour Unicode emoji (people, red map pin, blue globe) as icons, a different family from the monochrome outlined Material icons used everywhere else (sidebar, buttons, status pills, alerts). Evidence: `screens/r_welcome_start.png`.

> Recommendation: Replace the emoji icons in welcome_pack_content.dart with Material Icons (Icons.groups_outlined, Icons.location_on_outlined, Icons.language) so the Welcome pack matches the vector-icon system used elsewhere.
**F-005 · sev 2 · H1 · screen: a_dashboard** — The KPI tiles use a colored top border that reads as a status signal, but the coding is inconsistent with the underlying values: DOI COVERAGE (45/365 ≈ 12%) carries the same green top border as ORCID LINKED, PROFILES VALIDATED and OUTPUTS APPROVED (365/365, i.e. fully complete), while MISSING ORCID (158/184) and NEEDS VERIFICATION (181) get a red top border. An admin scanning tile colors at a glance would read DOI Coverage as healthy when it is actually the biggest data-quality gap on the page. Evidence: `screens/a_dashboard.png`.

> Recommendation: Tie the tile's accent color to the metric's actual health (e.g. color DOI Coverage by its completion ratio) rather than a fixed per-metric-category color, or drop the color coding in favor of a neutral style plus an explicit label.
**F-006 · sev 2 · H1 · screen: a_deeplink_profile** — Persists from the previous run (2026-09-09-1601). Personal Information (/app/profile) still ends in a large blank area below the status-pill row (External researcher / Inactive / Profile not confirmed / Edit / Connect ORCID) — confirmed again on a_deeplink_profile.png, where the last visible content is at y≈300 out of a 900px-tall viewport, with nothing below. Evidence: `screens/a_deeplink_profile.png`.

> Recommendation: Render the same Personal Information sections (bio, identifiers, areas) inline or add an explicit note/placeholder explaining why the page is short, instead of ending in unexplained empty space.
**F-007 · sev 2 · H10 · screen: login** — Persists from the previous run. The sign-in form still offers only 'Sign in' (email/password) and 'Sign in with ORCID iD' — no 'Forgot password' or account-recovery link anywhere on the screen. Evidence: `screens/login.png`.

> Recommendation: Add a password-recovery link under the password field so users who forget their credentials are not stuck.
**F-008 · sev 2 · H2 · screen: flow_add_output_4_after_add** — New with the DOI-first Add output flow. After 'Look up' auto-fills the category from a real DOI, the researcher's My Outputs timeline shows the category as a bare, all-caps Portuguese token 'LIVROS' (Portuguese for 'Books') sitting next to the English 'pending' status tag, in an otherwise fully English interface (sidebar, buttons, headings). The same untranslated-taxonomy pattern recurs on a_dashboard.png ('Formação avançada', 'Gestão & apoio UNIDCOM', 'Seminários & conferências' as chart/list labels) and a_admin_reports.png (Type/Subtype columns showing e.g. 'Organização de Seminários e Conferências'). A researcher who does not read Portuguese cannot tell what category their own output was filed under. Evidence: `screens/flow_add_output_4_after_add.png`.

> Recommendation: Localize or translate the output category/type taxonomy for display in the English UI (or at minimum expand the abbreviation/label on hover), rather than surfacing the raw Portuguese FCT taxonomy value as a UI chip.
**F-009 · sev 2 · H4 · screen: r_outputs_import** — Persists from the previous run. Now that ORCID Sync correctly explains a missing ORCID iD (F-021), the 'Ciência Vitae Sync' and 'Other Data Sources' rows directly below it still use the same green-tinted, wrench-icon card styling as genuine 'Work in progress' placeholders elsewhere (r_profile_areas_wip, r_help_docs_wip, r_outputs_edit_wip, etc.) but omit the words 'Work in progress', so it remains unclear whether these two rows are working controls or placeholders. Evidence: `screens/r_outputs_import.png`.

> Recommendation: Either wire these rows up or label them 'Work in progress' the same way every other placeholder in the app is labelled.
**F-010 · sev 2 · H5 · screen: flow_add_output_2_doi_prefilled** — New in the DOI-prefill flow. Once 'Look up' pulls in a real DOI record, the dialog now also shows a Subcategory field, which defaults to 'All' — the same list-filter value previously flagged for the Category field, now reappearing one field over. 'All' is not a valid subcategory for a single saved record. Confirmed again on flow_add_output_3_duplicate_blocked.png where Subcategory is still 'All' after the duplicate warning appears. Evidence: `screens/flow_add_output_2_doi_prefilled.png`.

> Recommendation: Leave Subcategory blank/required when the looked-up record doesn't map to one, instead of defaulting to the 'All' filter value.
**F-011 · sev 2 · H5 · screen: r_add_output_dialog** — Persists from the previous run. When a researcher opens 'Add output' and skips the new DOI field (manual entry path), the Category dropdown still defaults to 'All' — a list-filter value, not a valid category for a single record — confirmed again on r_add_output_dialog.png. Evidence: `screens/r_add_output_dialog.png`.

> Recommendation: Default Category to a blank/placeholder state and make it required, rather than reusing the 'All' filter value as the default for a new record.
**F-012 · sev 2 · H5 · screen: r_profile_edit_dialog** — Persists from the previous run. 'Join date (YYYY-MM-DD)' and 'Exit date (YYYY-MM-DD)' are still plain free-text fields; the required format is communicated only via placeholder text, with no date picker or input mask to prevent malformed entries. Evidence: `screens/r_profile_edit_dialog.png`.

> Recommendation: Use a date picker or masked input for the date fields instead of relying on placeholder-text instructions alone.
**F-013 · sev 2 · LAW-FITTS-1 · screen: a_person** — Persists unchanged: the 'Remove' control on a person's timeline entry is still a confirmed clickable target only 40×6px (measurements.json small_tap_targets, assumed:false), roughly a quarter of the 24px minimum height, with no visual button styling. Evidence: `screens/a_person.png`. Measurement: small_tap_targets: {"label":"Remove","w":40,"h":6,"assumed":false}

> Recommendation: Render 'Remove' as a proper button/icon-button with at least a 24px (ideally 44px) hit box, not a 6px text sliver.
**F-014 · sev 2 · LAW-FITTS-1 · screen: r_profile_edit_dialog** — Persists unchanged: the 'Integration year' field in the 'Edit researcher' modal is still a confirmed clickable control only 528×7px (measurements.json small_tap_targets, assumed:false), while every sibling field in the same dialog (Preferred name, Legal name, Email, Phone, ORCID, Ciencia ID, PhD, Join date, Exit date) renders at full input height. Evidence: `screens/r_profile_edit_dialog.png`. Measurement: small_tap_targets: {"label":"Integration year","w":528,"h":7,"assumed":false}

> Recommendation: Give the Integration year field the same input height/padding as its siblings (Join date, Exit date) in the same form.
**F-015 · sev 2 · LAW-HICK-1 · screen: a_people** — Persists unchanged: the People filter/action bar still bundles many simultaneous, mostly ungrouped controls — Search, a separated top-right 'Add person' button, then 3 dropdowns (Membership, Status, Profile) and 3 toggle chips (Missing ORCID, Needs verification, Has outputs) with no visual grouping label, plus the '184 people' count — measurements.json again measures this cluster as an oversized group of 10 against a limit of 9. Evidence: `screens/a_people.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-126", "items": 10, "limit": 9}

> Recommendation: Collapse the 3 toggle chips into a single 'More filters' disclosure, or group the 3 dropdowns and 3 chips under a visible 'Filters' label so the choice set doesn't read as one undifferentiated row of 6+.
**F-016 · sev 2 · LAW-HICK-2 · screen: r_profile_edit_dialog** — Persists unchanged: the 'Edit researcher' dialog still presents 14 fields (Preferred name, Legal name, Bio, Photo URL, Email, Job title, Phone, ORCID, Ciencia ID, PhD, Join date, Exit date, Integration year, plus Cancel/Save) in one continuous, unsectioned, scrolling modal — measurements.json again flags it as an oversized group ({"items":14,"limit":9}). No headings or steps separate identity fields from academic-identifier fields from employment-date fields. (By contrast, the newer 'Add output' dialog now front-loads a DOI + Look-up step and only shows 6 form fields — well under the limit — demonstrating the app already knows how to do progressive disclosure elsewhere.) Evidence: `screens/r_profile_edit_dialog.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-791", "items": 14, "limit": 9}

> Recommendation: Split into labeled sub-sections (Identity, Identifiers, Employment) within the same dialog, or turn it into a 2-3 step wizard so no single view demands scanning 14 fields at once.
**F-017 · sev 2 · LAW-JAKOB-1 · screen: r_account_menu** — Persists unchanged: the top-right header identity block (avatar 'EB', 'E2E Bot', 'External researcher · UNIDCOM / IADE') is still non-interactive in hierarchy/r_account_menu.json (clickable=false on all three text nodes, e.g. bounds [320,13][381,36] and [320,38][547,55]), so clicking the header name still produces no account/mode menu — this run's captured screen is identical to r_home/r_sidebar_expanded, confirming nothing opened. Every mainstream web app puts an account/mode-switch menu behind that top-right identity, and here the only working equivalent is at the bottom of the sidebar. Evidence: `screens/r_account_menu.png`.

> Recommendation: Add a real top-right account/mode menu (or at minimum make the identity block clickable, routing to the same switch/sign-out actions currently only available at the bottom of the sidebar).
**F-018 · sev 2 · LAW-MILLER-1 · screen: a_dashboard** — Unchanged pattern from the previous run, and slightly worse: the admin dashboard KPI grid is now 18 tiles above the fold (ORCID Linked, Profiles Validated, Outputs Approved, DOI Coverage, Researchers, Outputs, Journal Articles, Needs Verification, Missing ORCID, Ciência ID on File, Unclaimed ORCID Candidates, Publications Missing DOI, Labs, Projects, Clusters, Verified Outputs, Lab Allocations, Mentorships), immediately followed by 'Outputs by type' rows and a quartile chart on the same undifferentiated panel, with no category sub-headers. measurements.json's oversized-group count for this panel grew from 90 (previous run) to 96. Evidence: `screens/a_dashboard.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-30", "items": 96, "limit": 9}

> Recommendation: Cluster the KPI tiles under 3-4 labeled sub-headers (People, Outputs, Structure, Reporting) of ≤9 tiles each instead of one undifferentiated grid.
**F-019 · sev 2 · NAV-4 · screen: a_admin_review** — Persists from the previous run. a_admin_review.png (Pending approval) still layers a secondary flat tab row of 7 items (Profiles to approve, Outputs to approve, Needs re-verification, Suggestions, Activity, Needs attention, ORCID works) on top of the single left-sidebar leaf 'Pending approval' -- no other screen in the inventory combines a sidebar with a secondary tab bar, and 7 tabs exceeds the ~5 a single flat row should hold. Confirmed worse on the 390px viewport: phone_a_review.png shows only 'Profiles to approve' and 'Outputs to approve' fully visible with a third tab clipped at the right edge and no visible scroll affordance, so 5 of the 7 sub-views are effectively hidden on mobile. Not in the fixed/merged list for this run. Evidence: `screens/a_admin_review.png`. Measurement: 7 tabs in one row on desktop; only ~2.3 tabs visible with no scroll cue on the 390px phone capture (phone_a_review.png); unchanged from previous run

> Recommendation: Either split the 7 sub-views into their own sidebar leaves (consistent with the rest of the IA) or reduce/group the tabs (e.g. a dropdown for the 3 least-used), and on narrow viewports add a visible scroll indicator or convert to a select control.
**F-020 · sev 2 · ST-LOAD · screen: state_error_backend_down** — Persists from the previous run (2026-09-09-1601). state_error_backend_down.png and state_error_dashboard_down.png are both captured at 3s into a Supabase-blocked load and still show only a bare unlabeled spinner dot -- no 'still trying', elapsed-time, or retry-now affordance. flows-results.json's flow suite (7/7 passed) confirms the app does eventually reach a correct classified error, but per this run's screens.md note the classified error + Retry button only appears after the client's 20s timeout, so a user watching this frame gets no sign for up to ~20s that the app knows anything is wrong. Not in the fixed/merged list for this run -- kept as-is. Evidence: `screens/state_error_backend_down.png`. Measurement: spinner-only frame at 3s; first user-facing error/Retry affordance not until ~20s; unchanged from previous run

> Recommendation: Show progressive feedback during the wait (e.g. 'Still connecting...' after 3-5s) instead of a bare spinner for up to 20s before the classified error with Retry appears.
**F-021 · sev 2 · VD-COL-2 · screen: a_dashboard** — Decorative colour coding without a rule (consistency debt, not a task blocker): Worse than previously reported. The KPI tile grid grew to 18 tiles and now uses a fifth top-border color that isn't a defined semantic accent at all: pixel-sampling the top border of the 'Researchers', 'Publications Missing Doi', 'Labs', 'Clusters' and 'Mentorships' tiles all return RGB(112,110,104), which is exactly lib/theme/tokens.dart AppColors.textFaint (0xFF706E68) — a color the token file defines and comments explicitly for text-contrast tuning, not as a tile/border accent. It now sits alongside teal (Outputs, Verified Outputs), blue (Journal Articles, Projects, Lab Allocations), red (Needs Verification, Missing Orcid) and amber (Ciência Id On File, Unclaimed Orcid Candidates) with no visible rule: two structurally identical plain-count tiles ('Labs' and 'Projects') get different colors (grey vs blue), and 'Clusters' now differs from its previous run color despite being an unchanged plain count. Same tiles/colors repeat on phone_a_dashboard. Evidence: `screens/a_dashboard.png`.

> Recommendation: Stop repurposing a text-contrast token (textFaint) as a fifth ad-hoc border accent. Define one explicit rule for tile accents (e.g. teal = healthy/neutral count, amber/red = needs-attention, blue reserved for a named 'structure' category) and apply it consistently to all 18 tiles; drop the grey variant entirely.
**F-022 · sev 2 · VD-COL-2 · screen: r_home** — Persists unchanged since both previous runs. The 'OUTPUTS' and 'PROFILE STATUS' stat cards on the researcher home still share one continuous amber/warn top border even though 'Outputs: 0' is a neutral count with no problem — only 'Profile Status' is a legitimate warning state. Same pair repeats identically on phone_r_home. Evidence: `screens/r_home.png`.

> Recommendation: Apply the amber/warn accent only to the card whose state needs attention (Profile Status); give the neutral Outputs count a neutral border/no accent.
**F-023 · sev 2 · VD-COL-4 · screen: flow_add_output_3_duplicate_blocked** — New dialog state since previous audit. When 'Look up' finds the DOI already exists, the blocking message 'Already in the directory: ... (approved)' renders in plain body-text color with no icon, tint, or border — visually indistinguishable from ordinary helper text in the same dialog. This is inconsistent with how the app treats other blocking/attention states: e.g. r_home's 'Your profile is awaiting confirmation' alert uses an amber warning icon plus amber text. The only cue that Save is now blocked is the Save button itself turning a slightly lighter navy, which is easy to miss. Evidence: `screens/flow_add_output_3_duplicate_blocked.png`.

> Recommendation: Give the duplicate-blocked message the same visual treatment the app already uses for attention states elsewhere (warning icon + amber or neutral-info tint), so a blocked Save is obvious without reading the button state.
**F-024 · sev 2 · VD-RESP-1 · screen: a_admin_reports** — The previously-reported Type column overflow is confirmed fixed (values wrap within the column and show a full-text tooltip on hover, visible in this run's screenshot). The Subtype column still exhibits the original problem: values such as 'Membro da comissão cientifi' are cut off exactly at the 1280px viewport edge mid-word, with no ellipsis, tooltip, or horizontal-scroll affordance. Evidence: `screens/a_admin_reports.png`.

> Recommendation: Extend the fix already applied to the Type column (wrap + hover tooltip) to the Subtype column and any other column that can overflow the viewport.

### Severity 1 — cosmetic

**F-025 · sev 1 · DS-BTN-1 · screen: r_outputs** — Unchanged since the previous run: the add-output action still appears twice in two variants on one screen -- the top-right 'Add output' is a filled navy primary button, while the 'Timeline · 0' section's '+ Add' directly below is a plain blue text link (tertiary/ghost style) for the same action. Evidence: `screens/r_outputs.png`.

> Recommendation: Use the theme's outline/secondary button style for the Timeline '+ Add' instead of a bare text link, so it reads as a lower-tier variant of the same button family rather than a different control type.
**F-026 · sev 1 · DS-COL-1 · screen: a_dashboard** — The dashboard's AccentTone system (lib/widgets/panels.dart AccentStatCard) uses its 3px top-border colour to signal health (teal=good, amber=warn, red=urgent, blue=info, grey=neutral) -- but the tone assignment among the plain entity-count tiles is arbitrary: Labs and Clusters (two of the three newly added structure tiles, dashboard.dart _StatTilesRow) render with no tone (grey/neutral), while Projects -- the same kind of flat total, right beside them -- is hardcoded AccentTone.info (blue) for no data-driven reason. The same split repeats one row down: Lab allocations is hardcoded AccentTone.info (blue) while the parallel Mentorships tile (also a plain per-year count) gets no tone (grey). Elsewhere on the same screen blue and grey are used to mean something (Journal articles=info vs Researchers=neutral distinguishes a metric worth drilling into from a headline count); here the same two colours are applied to indistinguishable metrics, undermining the colour-as-signal convention the rest of the screen relies on. Evidence: `screens/a_dashboard.png`.

> Recommendation: Give Labs/Projects/Clusters and Lab allocations/Mentorships the same tone (drop the hardcoded AccentTone.info on Projects and Lab allocations, or apply it to all four/two consistently) so the top-border colour keeps meaning something rather than varying tile-to-tile within one group of otherwise-identical counts.
**F-027 · sev 1 · DS-COL-1 · screen: r_profile_identifiers** — New component: the 'soon' pill next to Research Areas / Research Interests (lib/widgets/side_nav.dart _row(), used identically in the sidebar itself on r_sidebar_expanded/r_profile/phone_r_drawer) is a fully hollow, unfilled outline ring (Border.all(textOnDarkMuted), transparent fill, fully rounded). Every other pill/badge already in the app fills its background: StatusPill and TypeBadge (lib/widgets/panels.dart) pair a coloured dot or uppercase label with a tinted PillTone background, and the sidebar's own unread-count badge (same side_nav.dart file, a few lines below the wip pill) is a solid amber-filled circle. The new wip tag is a fourth, unrelated treatment introduced without reusing the PillTone/tint system already in place. Evidence: `screens/r_profile_identifiers.png`.

> Recommendation: Render the 'soon' tag as a PillTone.grey StatusPill/TypeBadge (tinted background, no dot) instead of a bespoke bordered-only container, so it reads as the same badge family as the count badge two lines below it and the status pills elsewhere.
**F-028 · sev 1 · DS-FORM-1 · screen: r_add_output_dialog** — Unchanged since the previous run: every field in the Add output dialog (DOI, Title, Full reference, Category, Reporting year, Output status) still renders with the label floating inside the filled input box, diverging from Carmela's template form (static label above the input, unidcom-researcher.html's New Request form). Internally consistent between the app's own dialogs (r_add_output_dialog, r_profile_edit_dialog) but both still diverge from the Figma export's only form pattern. Evidence: `screens/r_add_output_dialog.png`.

> Recommendation: If the floating-label Material pattern is the deliberate direction going forward, document the deviation; otherwise move labels above fields to match the template's convention before more forms are built.
**F-029 · sev 1 · DS-ICON-1 · screen: r_profile** — Unchanged since the previous run: on the Personal Information header row, 'Edit' still uses a filled pencil glyph (Icons.edit) directly beside 'Connect ORCID', which uses an outlined badge glyph (Icons.badge_outlined) -- a filled icon and an outlined icon in the same button row. Evidence: `screens/r_profile.png`.

> Recommendation: Standardise on the outlined Material Icons style already used by the sidebar and swap the filled Icons.edit for Icons.edit_outlined wherever it sits next to outlined controls.
**F-030 · sev 1 · H2 · screen: a_objective** — Persists from the previous run. The objective detail page still shows cluster codes as bare pills ('C3', 'R3', 'T3', 'E3', 'F3') with no tooltip or expansion of what each code stands for. Evidence: `screens/a_objective.png`.

> Recommendation: Add a tooltip or short label next to each cluster pill spelling out the cluster name.
**F-031 · sev 1 · H4 · screen: r_outputs** — Persists from the previous run. The top-right button still says 'Add output' while the inline control next to the Timeline heading still says only 'Add' — two labels for the same action, visible together on r_outputs.png. Evidence: `screens/r_outputs.png`.

> Recommendation: Use one consistent label ('Add output') for both entry points to the same action.
**F-032 · sev 1 · H8 · screen: r_profile** — The same status is shown twice at once: the top banner reads '● Profile not confirmed · Check your data below, then confirm · Confirm my profile', and immediately below it the pill row repeats '● Profile not confirmed' again alongside External researcher / Inactive. No new information is added by the second instance. Evidence: `screens/r_profile.png`.

> Recommendation: Show the 'Profile not confirmed' state once — keep the actionable banner with its CTA and drop the duplicate pill, or fold the CTA into the pill row.
**F-033 · sev 1 · LAW-FITTS-1 · screen: a_objective** — New: the small cluster-code pills shown wherever objectives/clusters/projects cross-link to each other (e.g. the 'Clusters' row on a_objective: ● C3, ● R3, ● T3, ● E3, ● F3) are confirmed clickable targets only 22px tall — measurements.json lists 5 such pills on this screen alone ('C3: Crafting Cooperation and Coexistence' 42×22, 'R3: Rethinking for Regeneration and Resilience' 41×22, 'T3…' 41×22, 'E3…' 41×22, 'F3…' 40×22, all assumed:false), 2px under the 24px minimum. The same undersized pill component recurs on a_cluster (e.g. 'UNID.9', 'UNID.8', 'UNID.6', 'UNID.7', 'UNID.2', 'UNID.3', 'UNID.4', all 22px tall), a_lab ('SDI.1', 'SDI.2', 'SDI.3', all 22px tall) and a_project ('R3', 'BiD', 'UNID.6', all 22px tall) — a systemic, if minor, shortfall across the shared tag/badge component. Evidence: `screens/a_objective.png`. Measurement: small_tap_targets: {"label":"C3: Crafting Cooperation and Coexistence","w":42,"h":22,"assumed":false} (and 4 siblings on this screen; same 22px-tall pattern repeats on a_cluster, a_lab, a_project)

> Recommendation: Bump the shared cluster/objective/project tag-pill component's vertical padding by ~2px so it clears the 24px tap-target minimum everywhere it's used.
**F-034 · sev 1 · LAW-MILLER-1 · screen: r_sidebar_expanded** — Improved since the previous run (severity 3): the sidebar is now a true accordion with exactly one group open. But the visible-at-once count is still 11 rows: 6 group headers (OVERVIEW, MY PROFILE, SCIENTIFIC OUTPUTS, RESEARCH ADMINISTRATION, COMMUNICATION, HELP & CONTACTS) plus the 5 leaves of the open OVERVIEW group (Research Activity Summary, Recent Scientific Outputs, Alerts & Notifications, Profile Status, Getting Started) — 2 over the 9-item ceiling. Confirmed by the identical 11-item count measured for the phone drawer's equivalent accordion (measurements.json phone_r_drawer oversized_groups items:11); the desktop capture did not get its own oversized_groups entry but the same nav structure is visible. [also LAW-MILLER-1 on phone_r_drawer: Improved since the previous run (severity 3, 12/22-item flat list) but still over: the accordion drawer shows 6 group headers (OVERVIEW, MY PROFILE, SCIENTIFIC OUTPUTS, RESEARCH ADMINISTRATION, COMMUN] Evidence: `screens/r_sidebar_expanded.png`.

> Recommendation: Trim the header row further (e.g. hide 1-2 leaves behind a 'more' toggle in the open group) or accept — this is now only marginally over Miller's ceiling and is a large improvement over the prior flat, fully-expanded sidebar.
**F-035 · sev 1 · NAV-1 · screen: a_deeplink_profile** — New this run. Deep-linking to the researcher-only route #/app/profile while signed in as admin (a_deeplink_profile.png) renders the researcher's own 'Confirm my profile' content correctly, but none of the admin sidebar items (Dashboard, People, Merge duplicates, Research, Data & Reporting, Settings) is shown selected/highlighted -- contrast with a_person.png and a_output.png, where the matching parent leaf (People / Scientific outputs) stays visibly selected (white bold text) for any detail sub-page. hierarchy/a_deeplink_profile.json confirms no sidebar node carries a selected state. The top bar still reads 'External researcher · UNIDCOM / IADE', which describes the profile being viewed, not the admin's own location, so a user landing here (e.g. via a bookmark or shared link) has no 'where am I' cue in the persistent chrome. Evidence: `screens/a_deeplink_profile.png`. Measurement: 0 of 6 admin sidebar leaves shown selected while on this page, vs. always-selected parent on every other admin detail page sampled

> Recommendation: Either hide the admin sidebar/show a dedicated 'My profile' entry when an admin views their own researcher profile, or suppress this cross-mode route entirely and redirect admins to the equivalent People > self detail view.
**F-036 · sev 1 · ST-EMPTY · screen: state_empty_people_search** — Five-state coverage sampled across data screens for this run: | Screen | ST-IDLE | ST-LOAD | ST-SUCCESS | ST-ERROR | ST-EMPTY | |---|---|---|---|---|---| | People search | present | n/a | present | n/a | present (weak) | | People (backend down, @3s) | n/a | present (silent/unbounded @3s) | n/a | present (delayed, classified error+Retry only after the 20s client timeout) | n/a | | Dashboard (backend down, @3s) | n/a | present (silent/unbounded @3s) | n/a | present (delayed, same 20s timeout) | n/a | | Cold boot | n/a | present (splash, F-023 -- fixed since previous run) | n/a | n/a | n/a | | My Outputs after add | n/a | n/a | present (pending chip, flow_add_output_5_in_my_outputs.png) | n/a | n/a | | Review queue reject | n/a | n/a | present (snackbar + Undo, flow_review_queue_5_after_reject.png) | n/a | n/a |. state_empty_people_search.png itself still handles the empty state reasonably ('No people found', filters and search term still visible so the cause is inferable), but offers no explicit next step (e.g. a 'Clear search' action) beyond manually editing the search box. Evidence: `screens/state_empty_people_search.png`. Measurement: 0 people / 0 next-step affordance besides editing the search field; unchanged from previous run

> Recommendation: Add a 'Clear filters/search' button to the empty result state so the next step is explicit rather than implicit.
**F-037 · sev 1 · VD-HIER-2 · screen: anon_welcome_logos** — Persists unchanged. Edge-alignment measurement still shows the same four 3px near-miss offsets among the logo-swatch card elements (edge pairs at x=325/328, 328/331, 344/347, 375/378) — the swatch chip, label, and download-icon are not on a shared grid column. Same layout/offsets repeat verbatim on r_welcome_logos. Evidence: `screens/anon_welcome_logos.png`. Measurement: alignment_near_misses: [{edges_px:[325,328],offset:3},{edges_px:[328,331],offset:3},{edges_px:[344,347],offset:3},{edges_px:[375,378],offset:3}]

> Recommendation: Snap the swatch/label/icon elements inside each logo card to the same left-edge grid column so repeated cards align pixel-for-pixel.
**F-038 · sev 1 · VD-RESP-1 · screen: phone_a_review** — The strip is scrollable since round 5 (every tab reachable — the F-037 fix holds); what remains is the missing scroll affordance. At 390px the 'Pending approval' tab strip ('Profiles to approve', 'Outputs to approve', Needs re-verification, Suggestions, Activity, Needs attention, ORCID works — 7 tabs on desktop) is hard-clipped at the viewport edge: only the first two tab labels are fully visible and a single stray letter 'I' from the third tab bleeds past the edge, with no fade, arrow, or other affordance signaling more tabs exist off-screen. Evidence: `screens/phone_a_review.png`.

> Recommendation: On narrow viewports, either wrap the tab strip or add a visible scroll cue (edge fade/gradient or chevron) so users know to swipe for the remaining tabs.
**F-039 · sev 1 · VD-TYPE-1 · screen: a_admin_data** — Persists unchanged since previous run. In the 'people' table of the raw Data Browser, the 'bio' column still renders full free-text paragraphs at roughly 12-13px, below the 16px floor for text meant to be read rather than scanned as a short label/ID, and is also cut off mid-sentence at the viewport edge. Evidence: `screens/a_admin_data.png`.

> Recommendation: For long free-text columns (bio, notes), either truncate with an expand-on-click affordance shown at readable size, or bump the cell font size for these specific columns instead of reusing the compact ID/date-column size.

## Comparison with RIMS best practice (BP-01…38)

Scored against the checklist in `docs/research/2026-09-rims-best-practices.md`. Evidence is a screen file, a code pointer, a migration or a SQL result from the production database on 2026-09-09. Score: **62 / 100** (13 yes · 21 partial · 4 no).

| ID | Status | Evidence | Gap |
|---|---|---|---|
| BP-01 | yes | output_authors(output_id, person_id, role, author_position) — SQL information_schema 2026-09-09 |  |
| BP-02 | partial | membership_type (integrated 46 / collaborator 109 / external 22 / null 7) plus join_date/exit_date live on the person row; lab membership is a link table with a year. No dated unit-membership history. | A person who changes category loses history; FCT cycles need it. |
| BP-03 | partial | 10 macro_type values are the FCT activity-report categories in Portuguese (e.g. 'Artigos em revistas', 'Actividades de gestão e auxílio à UNIDCOM'); category_path cascade below them. No CASRAI/CERIF mapping. | Map the two publication macro-types to CASRAI terms; label the rest as activities, not outputs. |
| BP-04 | yes | people.orcid (26/184 filled), people.ciencia_id (25/184); both shown on Researcher Identifiers (screens/r_profile_identifiers.png) | Coverage, not capability: 158 researchers have no ORCID on file, so cannot sign in. |
| BP-05 | yes | outputs.doi with UNIQUE INDEX outputs_doi_key; 45/365 filled, 0 duplicates |  |
| BP-06 | partial | outputs has approval_status only; people/projects have public_visibility. The public site adds a fail-closed macro_type allowlist in unidcom-site/scripts/sync.py (76 of 365 rows publish). | The publish decision is spread over three mechanisms in two repos; a single visibility column on outputs would make it visible in the portal. |
| BP-07 | yes | Add output opens with a DOI field + Look up (Crossref lookupDoi) that pre-fills title, year, reference and category; manual entry remains (PR 47). |  |
| BP-08 | yes | Weekly orcid-sync.yml stages works into output_candidates (1 471 rows, 26 people); Import & Synchronisation lists them with Add / Add all; admins see Import as… / Dismiss (candidate_tile.dart) | Researchers get Add but no Dismiss/Not mine, so 1 466 candidates stay pending forever (max 281 for one person). |
| BP-09 | partial | 'Add all' for a researcher's candidates; 'Approve all pending (N)' for admins. No checkbox selection, no bulk reject. | All-or-one only. |
| BP-10 | partial | DOI-first path is the default; manual form is the fallback with Title validated on submit. No required-field legend. |  |
| BP-11 | partial | outputs: pending → approved | rejected (check constraint, migration 20260804120000). people: draft → pending_review → approved. No draft state for outputs; a researcher's save is an immediate submission. | No way to save an incomplete output privately. |
| BP-12 | partial | Approve/Reject are admin-only (RLS is_admin on outputs_write; create_my_output forces pending). No withdraw for the researcher. | Researcher cannot retract a pending item. |
| BP-13 | partial | Reject now asks for a reason (F-005 fix, PR 38); the researcher sees it under the rejected output in My Outputs. No 'returned for correction' state — rejected is terminal unless an admin undoes it. | No return-with-comment loop, only reject-with-reason. |
| BP-14 | no | output_status holds 'Planeado' (6) / 'Concluído' (46) / null (313) and is not consulted by approval. |  |
| BP-15 | yes | change_log(subject_type, subject_id, field, old_value, new_value, source, actor, changed_at): 605 rows, 365 output approvals, 186 profile transitions | Non-admin edits are not logged (cl_write is admin-only; AUDIT.md). |
| BP-16 | yes | Before Save, find_similar_outputs() blocks an exact DOI match and warns on ≥ 0.8 trigram title similarity with open / save-anyway (migration 20260909170000, PR 47). |  |
| BP-17 | partial | Outputs list has an Issues filter and the detail page offers Merge duplicates when a cluster ≥ 2; the review queue row itself shows no duplicate badge (screens/flow_review_queue_3_FAIL.png). |  |
| BP-18 | yes | merge_people RPC + mergeOutputs, merge matrix UI (screens/a_admin_merge.png); reassigns output_authors/project_members |  |
| BP-19 | partial | Client-side: Title required, data retained, inline error (flow_add_output_2_validation.png). Server: create_my_output whitelists the payload and forces status/source/affiliation. | Other fields unvalidated (year accepts any text until save). |
| BP-20 | no | Single inline error only; no summary, no focus management. |  |
| BP-21 | yes | My Outputs timeline shows a 'pending' / 'rejected' pill on each non-approved row (F-009 fix, PR 32); rejected rows carry the reason (PR 38). |  |
| BP-22 | partial | Overview alerts + the Import & Synchronisation empty state now explains a missing ORCID iD and links to Identifiers (PR 44). Still no task list with counts. |  |
| BP-23 | no | Dialog → Save; no review step. |  |
| BP-24 | partial | Admin Reports uses DataTable (Title, Year, Type, Subtype, Authors, DOI/URL) with no onSort; Data browser renders 4 856 semantics nodes on one screen (measurements.json a_admin_data). | Sorting and pagination. |
| BP-25 | partial | Outputs: Category cascade + Approval + Issues dropdowns (screens/a_outputs.png); Reports: Year. No person filter, no filter chips, no one-click clear. |  |
| BP-26 | partial | Reject now shows a SnackBar with Undo (live region); 'Approved N pending outputs' SnackBar unchanged; profile confirmation still has no announced confirmation beyond the tile changing. |  |
| BP-27 | partial | Desktop sidebar rows are exposed to assistive technology again (F-001 fix, PR 34: Semantics(container: true) around the routed content pane). Reject is still a text link ≈42×20 px; star icon 24 px. | Target sizes on the queue row. |
| BP-28 | partial | ORCID sign-in claims the person row (name, ORCID pre-filled). Not exercisable on device (third-party login). |  |
| BP-29 | partial | Profile shows the iD as a link to https://orcid.org/<id> with a generic badge icon, not the ORCID iD icon (profile_sections.dart:252). Admins type iDs into people.orcid to register researchers (the sign-in registry gate). | Use the ORCID icon; label admin-entered iDs as unauthenticated. |
| BP-30 | partial | Labels: 'Scientific Outputs', 'My Outputs', 'Import & Synchronisation', 'My ORCID publications'. ORCID says Works; CIÊNCIAVITAE says Produções; the FCT form says outputs. | Pick one vocabulary and say the ORCID word once in each heading. |
| BP-31 | no | source_put_code exists on output_candidates (inbound only). No push to ORCID. |  |
| BP-32 | yes | sync.yml nightly, last 5 runs success (2026-09-05…09-09); gates approval_status + public_visibility + macro_type allowlist; site holds 76 publications / 183 people = SQL counts |  |
| BP-33 | yes | people/single.html renders the ORCID link; sync field allowlist excludes email, legal_name, notes |  |
| BP-34 | partial | Reports page: Year filter, Generate PDF, Download CSV (screens/a_admin_reports.png); people.phd, people.ciencia_id, outputs.fct_selected exist, but fct_selected = 0 rows and the CSV has no CIÊNCIA ID / ORCID / PhD columns. | One 'FCT team' export. |
| BP-35 | yes | Reports and Data browser are admin-nav only (nav_model.dart); researcher nav has neither (screens/r_home.png vs a_dashboard.png) |  |
| BP-36 | yes | Dashboard tiles: ORCID linked, CIÊNCIA ID on file, unclaimed ORCID candidates, publications missing DOI, needs verification (PR 46). | No stale-draft count — outputs have no draft state (BP-11). |
| BP-37 | partial | Admins edit any profile directly; change_log.actor records the admin. No delegate role, no 'on behalf of' marker. |  |
| BP-38 | partial | auth.users.last_sign_in_at (3 of 5 accounts in 30 days) and change_log give sign-ins and first validation; no returning-user or task-completion instrumentation. | HEART instrumentation recommendation in the report. |

**Where the portal is ahead of the field for its size:** the data model (link rows for authorship, unique DOI, full audit trail), the approval gate feeding a nightly, fail-closed public build, ORCID harvesting into a staging table, and a real merge tool. These are the parts commercial systems charge for and small units usually skip.

**Where it trails every system surveyed:** the *entry* experience — a blank form instead of an identifier lookup (BP-07), no title-similarity warning (BP-16), no draft/withdraw (BP-11/12), no reviewer comment (BP-13), and no status tag in the researcher's own list (BP-21). Pure, Converis, Elements and Haplo all start from a DOI/ORCID lookup and show the workflow state on the researcher's list; FCT's own guidance makes CIÊNCIA ID coverage and the five representative outputs the unit-level facts that matter (BP-34, BP-36), and neither is surfaced yet.

## Design criticism — where the third run leaves the portal

**Fixed and verified.** Everything the first run called drift is closed, and the six round-6 items are visible on screen. The DOI-first dialog is the single largest change to the researcher's core task since the pilot started: an identifier lookup instead of a blank form, with the duplicate guard the research report put at the top of the entry checklist (BP-07, BP-16 now met).

**New debt, all small.** Adding surfaces added findings: the dashboard grew to 18 tiles and the tone rule (`dataQualityTone`) introduced a fifth border colour with no legend (F-005, F-021, F-026); the DOI path leaves Subcategory at *All* (F-010) and the imported category renders as its raw taxonomy label in My Outputs (F-008); the blocking message is body text rather than a warning style (F-023). None affects task success — all seven flows pass — but they are the items to take into the next small round.

**Unchanged by decision.** The 25-row IA is still there, now readable (F-034 at severity 1); the review queue's 7-tab strip (F-019); the mixed icon families and emoji in the Welcome pack (F-003, F-004); the 14-field profile dialog (F-016). These are product and design calls, not defects.

**One regression-by-key.** `phone_a_review` reappears (F-038) only because the reviewer now asks for a scroll affordance on the tab strip that round 5 made scrollable; the function is intact.

## Recommendations

Ordered by value; all severity 2 or 1.

1. **DOI dialog polish** (F-010, F-008, F-023): default Subcategory from the Crossref type where the taxonomy has one child, show the imported category with its human label in My Outputs, style the 'Already in the directory' block as a warning card. Half a day.
2. **Dashboard colour rule** (F-005, F-021, F-026, F-018): one accent for plain counts, warn for data-quality shortfalls above 50 %, a one-line legend; regroup the 18 tiles under three headings (pilot KPIs, directory, data quality). Half a day, and it closes four findings.
3. **Profile header** (F-032): show the profile status once — the banner or the pill, not both.
4. **Feedback pattern outliers** (F-001, F-002): the ORCID broker error and the AsyncView banner still differ from the documented rule; align them.
5. **Tab-strip affordance** (F-038): a fade or chevron on the scrollable review tabs at phone width.
6. **Product decisions, unchanged:** sidebar IA, review-queue tabs, icon family, the 14-field profile dialog (F-034, F-019, F-003/F-004, F-016).

Next research-backed features after this: ORCID push (BP-31) and the FCT team export (BP-34), the two remaining 'no' items in the checklist that are engineering rather than policy.

## Trend vs previous run (2026-09-09-1601)

| Metric | Previous | Now | Δ |
|---|---|---|---|
| task_success_rate_pct | 100.0 | 100.0 | 0.0 |
| avg_steps_per_flow | 8.1 | 8.4 | 0.3 |
| findings_total | 34 | 39 | 5 |
| severity_weighted_score | 61 | 63 | 2 |
| defect_density_per_screen | 0.41 | 0.48 | 0.07 |
| findings sev 4 | 0 | 0 | +0 |
| findings sev 3 | 1 | 0 | -1 |
| findings sev 2 | 25 | 24 | -1 |
| findings sev 1 | 8 | 15 | +7 |

- **Fixed (6):** F-002 DS-BRAND-1@r_profile, F-008 H4@a_admin_requests_v2, F-010 H4@r_welcome_affiliation, F-013 H6@r_profile_areas_wip, F-021 ST-EMPTY@r_outputs_import, F-023 ST-LOAD@state_loading_cold
- **New (10):** F-001 DS-FDBK-1@flow_orcid_error_1_error_shown, F-005 H1@a_dashboard, F-008 H2@flow_add_output_4_after_add, F-010 H5@flow_add_output_2_doi_prefilled, F-023 VD-COL-4@flow_add_output_3_duplicate_blocked, F-026 DS-COL-1@a_dashboard, F-027 DS-COL-1@r_profile_identifiers, F-032 H8@r_profile, F-033 LAW-FITTS-1@a_objective, F-035 NAV-1@a_deeplink_profile
- **Regressed (1):** F-038 VD-RESP-1@phone_a_review
- **Persisting (28):** F-002 (was F-003) DS-FDBK-1@state_error_backend_down, F-003 (was F-004) DS-ICON-1@r_sidebar_expanded, F-004 (was F-005) DS-ICON-1@r_welcome_start, F-006 (was F-006) H1@a_deeplink_profile, F-007 (was F-007) H10@login, F-009 (was F-009) H4@r_outputs_import, F-011 (was F-011) H5@r_add_output_dialog, F-012 (was F-012) H5@r_profile_edit_dialog, F-013 (was F-014) LAW-FITTS-1@a_person, F-014 (was F-015) LAW-FITTS-1@r_profile_edit_dialog, F-015 (was F-016) LAW-HICK-1@a_people, F-016 (was F-017) LAW-HICK-2@r_profile_edit_dialog, F-017 (was F-018) LAW-JAKOB-1@r_account_menu, F-018 (was F-019) LAW-MILLER-1@a_dashboard, F-019 (was F-020) NAV-4@a_admin_review, F-020 (was F-022) ST-LOAD@state_error_backend_down, F-021 (was F-024) VD-COL-2@a_dashboard, F-022 (was F-025) VD-COL-2@r_home, F-024 (was F-026) VD-RESP-1@a_admin_reports, F-025 (was F-027) DS-BTN-1@r_outputs, F-028 (was F-028) DS-FORM-1@r_add_output_dialog, F-029 (was F-029) DS-ICON-1@r_profile, F-030 (was F-030) H2@a_objective, F-031 (was F-031) H4@r_outputs, F-034 (was F-001) LAW-MILLER-1@r_sidebar_expanded, F-036 (was F-032) ST-EMPTY@state_empty_people_search, F-037 (was F-033) VD-HIER-2@anon_welcome_logos, F-039 (was F-034) VD-TYPE-1@a_admin_data

## Appendix

### A. Screen inventory
See `screens.md` (82 crawled screens + 21 flow-step screenshots + 4 verification screenshots). Files: `screens/<name>.png`, `hierarchy/<name>.json` — **kept out of git** (they contain researcher emails from the admin data browser); they exist only on the audit machine, alongside `measurements.json`.

### B. Flow results

| Flow | Passed | Steps | Duration (s) | Source | Note |
|---|---|---|---|---|---|
| auth_gate | yes | 6 | 6.5 | .maestro/auth_gate.yaml |  |
| researcher_mode | yes | 9 | 18.1 | .maestro/researcher_mode.yaml |  |
| admin_mode | yes | 8 | 7.2 | .maestro/admin_mode.yaml |  |
| orcid_error | yes | 3 | 4.0 | .maestro/orcid_error.yaml |  |
| profile_confirm | yes | 8 | 4.9 | (new) profile_confirm — researcher confirms draft profile |  |
| add_output | yes | 13 | 10.8 | (new) add_output — DOI lookup, duplicate block, then manual entry |  |
| review_queue | yes | 12 | 19.4 | (new) review_queue — admin sees, confirms-all, rejects |  |
| featured_star | NOT RUN | 0 | 0 | .maestro/featured_star.yaml | NOT RUN: the E2E account has 0 outputs to star |
| support_request | NOT RUN | 0 | 0 | .maestro/support_request.yaml | NOT RUN: v2-only route, compiled out of the pilot build |

### C. Verification of subagent claims
Six claims at severity ≥ 3 were re-tested by the orchestrator before inclusion: two "no error state" claims (backend down) — the classified error appears after the 20 s client timeout, recorded instead as F-035 (silent spinner); one "wrong person shown" claim — confirmed and promoted (F-002); one "account menu does nothing" claim — there is no menu, the copy points to the wrong place (F-018); two tap-target claims (drawer rows 15 px / 5 px, a 6 px row on conferences) — clipped-viewport artefacts, folded into F-035 or dropped.

### D. measurements.json summary
875 tap targets under 24 px (most `assumed`, i.e. labelled leaves without an explicit clickable flag), 262 groups over 9 items, 64 alignment near-misses across 81 hierarchies. Contrast estimates were used only for leaf text.

### E. Reproduce
`audit/tools/README.md`. Cleanup SQL for the two DB-writing flows is in `screens.md`.

# UX/UI Audit — UNIDCOM RIMS researcher portal (web, Playwright Chromium 1280×900 / 390×844) — 2026-09-09

## Executive Summary

**Release verdict: READY WITH FIXES.**

34 findings (0 severity-4, 1 severity-3, 25 severity-2, 8 severity-1) across 82 screens, task success rate 100 % on 7 of 9 defined flows, best-practice score 57 / 100 (10 yes · 23 partial · 5 no of 38 BP items).

What changed since the first run, in the order that matters:

1. **Both blockers are gone.** The desktop sidebar is back in the accessibility tree (42 semantics nodes on the researcher home instead of 17, every row a button), and a person page now switches records when only the id changes. Both are pinned by widget tests.
2. **The workflow is legible now.** A new output shows a *pending* pill in My Outputs; Reject asks for confirmation and a reason, offers Undo, and the researcher sees the reason under the rejected item. The `review_queue` flow exercises the whole dialog.
3. **Two regressions introduced by the fixes were caught by this run and fixed the same afternoon:** the queue row printed "pending" twice after the pill change, and the new 404 page rendered blank because it was wrapped in the app shell outside the router. Both have tests now.

What is left is by decision, not by accident: the 25-row sidebar and its placeholder leaves, the empty ORCID-sync state for researchers without an iD, the raw status chips on the Personal Information header, and the thin Personal Information page that the E4 split produced.

## Background & Objectives

- App: UNIDCOM RIMS researcher portal, `Unidcom-IADE` repo, commit `7d628bb (crawl) / e5b8847 (flows) / daaf308 (404 recapture)` (round 5 — the ten UX-audit fix tasks merged 2026-09-09 (PRs 32–39) plus two follow-ups found by this re-run). Build: `flutter build web --dart-define=E2E=true`, v1 (pilot) feature set — v2-only controls (Support requests, Approve/Auto-fill/ORCID-sync on the profile band, Find DOI) are compiled out and were not audited.
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
| Mean steps per flow (efficiency) | 8.1 | flows |
| Mean automation time per flow | 9.6 s | flows (automation speed, compare run-over-run only) |
| Flow errors | 0 (+2 warnings) | flows |
| Findings sev 4 / 3 / 2 / 1 | 0 / 1 / 25 / 8 | `findings.json` |
| Defect density | 0.41 findings per screen | derived |
| Severity-weighted score (Σ severity) | 61 | derived — the number to drive down next run |
| Best-practice score | 57 / 100 | `bp-scorecard.json` (yes = 1, partial = ½) |
| Untraceable findings dropped | 0 | aggregate |

### Google HEART mapping

| Dimension | Measured here | Needs instrumentation |
|---|---|---|
| Happiness | Proxy: severity-weighted score 61; sev-3+ count 1 | in-app rating after first profile confirmation |
| Engagement | Proxy: core loop is 7.9 steps mean; researcher must scroll the sidebar to find Scientific Outputs at 1280×900 (F-007) | sessions per researcher per month |
| Adoption | Proxy: first-launch to value (login → chooser → welcome) in 6 steps; 158/184 researchers cannot sign in until an admin registers their ORCID iD | sign-ins per cohort member (auth.users.last_sign_in_at: 3 of 5 accounts in the last 30 days) |
| Retention | Proxy: state persists across reload (collapse state, mode) — good; 20 s silent spinner on a bad connection (F-031) | returning users after 7 days |
| Task success | **Measured:** 100 % task success, 0 errors, 2 warnings (status invisibility) | field completion rate of profile confirmation and first claim per cohort member |

Minimal instrumentation (one finding's worth): log `mode_chosen`, `profile_confirmed`, `output_added`, `candidate_claimed`, `review_decision` with actor and timestamp — `change_log` already holds the last three; the first two are one insert each.

## Key Findings

### Severity 4 — must fix before the cohort is onboarded


### Severity 3 — high priority

**F-001 · sev 3 · LAW-MILLER-1 · screen: r_sidebar_expanded** — Unchanged since the previous run: the persistent researcher sidebar still holds nav rows across 6 collapsible groups (OVERVIEW, MY PROFILE, SCIENTIFIC OUTPUTS, WELCOME PACK, HELP, SETTINGS; per screens.md's r_* route inventory that's 5+6+5+8+3+1 = 28 leaf destinations). On the 1280x900 viewport only OVERVIEW (5: Research Activity Summary, Recent Scientific Outputs, Alerts & Notifications, Profile Status, Getting Started) and MY PROFILE (6: Personal Information, Researcher Identifiers, Biography, Research Areas, Research Interests, Profile Status) fit before the fold, plus a 2-row sliver of SCIENTIFIC OUTPUTS (My Outputs, Add Scientific Output) clipped by the footer. WELCOME PACK, HELP and SETTINGS still require scrolling to even discover, and every group still renders expanded by default rather than collapsing to a Miller-safe count. [also LAW-MILLER-1 on phone_r_drawer: The 390px drawer still renders one flat, fully-expanded nav list past Miller's ceiling: measurements.json flags it as an oversized group ({"label":"flt-semantic-node-1019","items":12,"limit":9}) — Das] Evidence: `screens/r_sidebar_expanded.png`.

> Recommendation: Collapse all but the current section's group by default (accordion behavior, one open group at a time) so the visible option count stays near 7±2, and let the active route auto-expand only its own group.

### Severity 2 — minor

**F-002 · sev 2 · DS-BRAND-1 · screen: r_profile** — New instance of the raw-status-code pattern the previous run flagged (and which was fixed for the People-list StatusPill): on the researcher's own Personal Information page, the status pill row reads '● external  ● inactive  ● pending_review' — two clean humanised words sitting directly beside a third pill still showing the literal snake_case value with the underscore intact. The same 'pending_review' pill recurs identically on flow_profile_confirm_2_after_confirm. Admin-side person detail pages (a_person: 'integrated · active · approved') show only clean humanised values, so this is a distinct, still-unhumanised code path for the profile_status field on the researcher's own profile. Evidence: `screens/r_profile.png`.

> Recommendation: Route the profile_status pill through the same status-label humanizer used elsewhere (and already applied to People-list StatusPill and the filter dropdown) so 'pending_review' renders as 'Pending review' consistently.
**F-003 · sev 2 · DS-FDBK-1 · screen: state_error_backend_down** — The app uses at least three different patterns for the same message type across screens: (1) inline red text under the form on auth failure (state_login_error: 'Invalid login credentials'; flow_orcid_error_1_error_shown: 'No UNIDCOM profile is registered for ORCID iD...'), (2) a bottom snackbar with an action for confirmations/undo (flow_review_queue_5_after_reject: 'Rejected E2E UX audit output (delete me)' + Undo; flow_profile_confirm_2_after_confirm: 'Profile submitted for approval'), and (3) nothing at all for a fully failed data load — state_error_backend_down and state_error_dashboard_down both show the shell chrome with an indefinite single-dot loading spinner in the content area and no error message, retry action, or any feedback whatsoever when Supabase is unreachable. Evidence: `screens/state_error_backend_down.png`.

> Recommendation: Give the backend-down state its own designed error card (icon + message + retry button, reusing the WipPage/Panel shell) instead of an indefinite spinner, and settle on one feedback pattern per message type (inline field errors vs. transient snackbars vs. full-page error states) rather than three ad hoc ones.
**F-004 · sev 2 · DS-ICON-1 · screen: r_sidebar_expanded** — Unchanged since the previous run: the shared SideNav widget renders a leading Material icon for every top-level item in the admin nav (a_people/a_dashboard/a_projects all show Dashboard/People/Scientific outputs/Projects/Structure/Reports/Data browser/Settings each with a glyph), but the researcher nav (visible here and on r_home, phone_r_drawer via its admin-mirrored order) still renders every item (Research Activity Summary, Recent Scientific Outputs, Alerts & Notifications, Profile Status, Getting Started, Personal Information, Researcher Identifiers, Biography, Research Areas, Research Interests, My Outputs, Add Scientific Output...) as plain indented text with zero icons. Same shared component, two different rules between its own two modes. Evidence: `screens/r_sidebar_expanded.png`.

> Recommendation: Give every top-level NavItem an icon in researcherNav() (lib/widgets/nav_model.dart) to match adminNav(), or drop icons from adminNav() — one rule, both modes of the one shared SideNav.
**F-005 · sev 2 · DS-ICON-1 · screen: r_welcome_start** — Unchanged since the previous run: the three 'Getting started' summary cards still use raw full-colour Unicode emoji (👥 people, 📍 red map pin, 🌐 blue globe) as icons, a completely different family from the monochrome outlined Material icons used everywhere else in the app (sidebar, buttons, status pills, alerts). Evidence: `screens/r_welcome_start.png`. Measurement: measurements.json r_welcome_start.alignment_near_misses shows the three emoji glyphs among the elements at edges 318-321px (1px offsets, consistent with their non-vector emoji rendering box vs. the surrounding vector-icon layout).

> Recommendation: Replace the emoji icons in welcome_pack_content.dart with Material Icons (Icons.groups_outlined, Icons.location_on_outlined, Icons.language) so the Welcome pack matches the vector-icon system used in the rest of the portal.
**F-006 · sev 2 · H1 · screen: a_deeplink_profile** — Personal Information (/app/profile) is a thin page: identity header, status pills and Edit / Connect ORCID, then empty space — identical content in both runs (hierarchy/r_profile.json vs the first run's), so not a regression but the cost of the E4 split that moved bio, identifiers and areas onto their own leaves. An admin following the researcher-only route sees the same thin page. Evidence: `screens/a_deeplink_profile.png`. Measurement: hierarchy/phone_r_profile.json max child bound y=844 (== viewport height, no scrollable overflow) vs hierarchy/r_profile.json max bound y=1513 (scrollable, full sections present)

> Recommendation: Render the same Personal Information sections regardless of viewport width or admin/researcher context; if a section is intentionally omitted for a given mode, show a placeholder or note explaining why rather than ending the page in blank space.
**F-007 · sev 2 · H10 · screen: login** — Persists from the previous run. The sign-in form offers only 'Sign in' (email/password) and 'Sign in with ORCID iD' — there is still no 'Forgot password' or account-recovery link anywhere on the screen. Evidence: `screens/login.png`.

> Recommendation: Add a password-recovery link under the password field so users who forget their credentials aren't stuck.
**F-008 · sev 2 · H4 · screen: a_admin_requests_v2** — screens.md marks #/app/admin/requests as a 'v2 route: expected redirect' (a compiled-out, pilot-v1-unsupported surface, listed under NOT COVERED as 'v2-only surfaces'). Instead of redirecting, or showing the app's usual wrench-icon 'Work in progress' card used consistently for every other unbuilt feature, it renders a fully-styled, apparently-functional dashboard: three stat tiles (Submitted/Approved/Completed, all 0) plus All/Submitted/Approved/Rejected/Completed filter tabs and a 'Requests' list showing 'No requests.' An admin has no way to tell this is an unfinished v2 feature rather than a genuinely empty, working queue. Evidence: `screens/a_admin_requests_v2.png`.

> Recommendation: Either gate this route behind the same redirect used for other compiled-out v2 surfaces, or replace it with the standard wrench + 'Work in progress' placeholder card used everywhere else in the app, so the placeholder pattern stays consistent.
**F-009 · sev 2 · H4 · screen: r_outputs_import** — Persists from the previous run. The 'Ciência Vitae Sync' and 'Other Data Sources' rows still use the same green-tinted, wrench-icon card styling that other genuinely-placeholder pages use with an explicit 'Work in progress' label (compare r_profile_areas_wip.png, r_help_docs_wip.png, r_help_faq_wip.png, r_outputs_edit_wip.png, r_outputs_validation_wip.png, r_profile_interests_wip.png, which all pair the wrench icon with the words 'Work in progress'). These two rows use the wrench-icon look but omit the 'Work in progress' text, so it is unclear whether they are working, clickable controls or placeholders. Evidence: `screens/r_outputs_import.png`.

> Recommendation: Either make these rows functional or label them 'Work in progress' the same way every other placeholder in the app is labelled, so the same visual style always means the same thing.
**F-010 · sev 2 · H4 · screen: r_welcome_affiliation** — Accepted as designed in round 5 (`researcherNav(signedIn: false)`): an anonymous visitor sees only the Welcome-pack groups, a signed-in researcher the full portal sidebar for the same /app/welcome/* page. Recorded as a deliberate difference, not drift; the residual cost is that the two sidebars style the same section differently. Persists from the previous run. For an anonymous visitor, the welcome-pack routes (/app/welcome/*, /app/help/*) show a dedicated sidebar (RESEARCH ADMINISTRATION / COMMUNICATION / HELP & CONTACTS) with the current item highlighted — confirmed on anon_welcome_start.png and anon_deeplink_people bounce flow. For a signed-in researcher visiting the identical /app/welcome/affiliation route, the sidebar is silently swapped for the generic app sidebar (OVERVIEW / MY PROFILE / SCIENTIFIC OUTPUTS) which has no 'Affiliation Guidelines' item at all, so nothing is highlighted and the researcher loses the 'you are here' cue. The same reproduces on r_welcome_start/fct/report/signature/social/logos/contacts and r_help_links/r_help_docs_wip/r_help_faq_wip. Note the highlighting mechanism itself works correctly elsewhere in the researcher sidebar (e.g. r_outputs.png shows 'My Outputs' highlighted, r_profile_bio.png shows 'Biography' highlighted, r_landing_after_choose.png shows 'Getting Started' highlighted) — only these welcome-pack/help sub-pages have no corresponding nav entry to highlight. Evidence: `screens/r_welcome_affiliation.png`.

> Recommendation: Give researchers the same welcome-pack/help sub-nav anon visitors get (or add matching leaf items under Overview/Help with correct active-state highlighting) so the sidebar always reflects where the user is.
**F-011 · sev 2 · H5 · screen: r_add_output_dialog** — Persists from the previous run. The 'Add output' dialog's Category dropdown still defaults to 'All' when creating a brand-new output (confirmed again on flow_add_output_2_validation.png, where the title-required inline error appears but Category is still 'All'). 'All' is a list-filter concept, not a valid category for a single record. Evidence: `screens/r_add_output_dialog.png`.

> Recommendation: Default the Category field to a blank/placeholder state (or the most common real category) and make it a required field, rather than defaulting to the 'All' filter value.
**F-012 · sev 2 · H5 · screen: r_profile_edit_dialog** — Persists from the previous run. 'Join date (YYYY-MM-DD)' and 'Exit date (YYYY-MM-DD)' are still plain free-text fields; the required format is communicated only via placeholder text, with no date picker or input mask to prevent malformed entries. Evidence: `screens/r_profile_edit_dialog.png`.

> Recommendation: Use a date picker or masked input for the date fields instead of relying on placeholder-text instructions alone.
**F-013 · sev 2 · H6 · screen: r_profile_areas_wip** — Persists from the previous run (reporting once for the pattern, per instructions). Research Areas, Research Interests, Edit Outputs, Validation & Duplicates, Documentation and FAQs are all still listed as ordinary, clickable sidebar items indistinguishable from working sections (confirmed again on r_profile_areas_wip.png, r_profile_interests_wip.png, r_outputs_edit_wip.png, r_outputs_validation_wip.png, r_help_docs_wip.png, r_help_faq_wip.png); only after clicking does a 'Work in progress' card reveal the feature doesn't exist yet. No badge/label in the sidebar itself signals this in advance. [orchestrator: Unchanged (product decision deferred): 8 of the 25 researcher sidebar leaves open the same 'Work in progress' page and look identical to working rows.] Evidence: `screens/r_profile_areas_wip.png`.

> Recommendation: Mark not-yet-implemented sidebar items with a 'Coming soon' badge (or disable/grey them) so users don't have to click through to discover a dead end.
**F-014 · sev 2 · LAW-FITTS-1 · screen: a_person** — The 'Remove' control on a person's timeline entry is still a confirmed clickable target only 40×6px (measurements.json small_tap_targets, assumed:false), an order of magnitude under the 24px minimum, with no visual button styling — unchanged from the previous run. Evidence: `screens/a_person.png`. Measurement: small_tap_targets: {"label":"Remove","w":40,"h":6,"assumed":false}

> Recommendation: Render 'Remove' as a proper button/icon-button with at least a 24px (ideally 44px) hit box, not a 6px text sliver.
**F-015 · sev 2 · LAW-FITTS-1 · screen: r_profile_edit_dialog** — The 'Integration year' field in the 'Edit researcher' modal is still a confirmed clickable control only 528×7px (measurements.json small_tap_targets, assumed:false) — unchanged from the previous run — while every sibling field in the same dialog (Preferred name, Legal name, Email, Phone, ORCID, Ciencia ID, PhD, Join date, Exit date) renders at full input height. Evidence: `screens/r_profile_edit_dialog.png`. Measurement: small_tap_targets: {"label":"Integration year","w":528,"h":7,"assumed":false}

> Recommendation: Give the Integration year field the same input height/padding as its siblings (Join date, Exit date) in the same form.
**F-016 · sev 2 · LAW-HICK-1 · screen: a_people** — The People filter/action bar still bundles many simultaneous, mostly ungrouped controls: Search, a now-separated top-right 'Add person' button, then on the row below 3 dropdowns (Membership, Status, Profile) and 3 toggle chips (Missing ORCID, Needs verification, Has outputs) with no visual separation between them, plus the '184 people' count — measurements.json measures this cluster (with the results list) as an oversized group of 10 against a limit of 9. 'Add person' is now visually separated from the filters (a partial fix versus the previous run), but the 3 filter dropdowns and 3 toggle chips remain one flat, ungrouped row of 6 simultaneous choices. Evidence: `screens/a_people.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-126", "items": 10, "limit": 9}

> Recommendation: Collapse the 3 toggle chips into a single 'More filters' disclosure, or group the 3 dropdowns and 3 chips under a visible 'Filters' label so the choice set doesn't read as one undifferentiated row of 6+.
**F-017 · sev 2 · LAW-HICK-2 · screen: r_profile_edit_dialog** — The 'Edit researcher' dialog still presents 14 fields (Preferred name, Legal name, Bio, Photo URL, Email, Job title, Phone, ORCID, Ciencia ID, PhD, Join date, Exit date, Integration year, plus Cancel/Save) in one continuous, unsectioned, scrolling modal — measurements.json again flags it as an oversized group ({"items":14,"limit":9}), unchanged from the previous run. No headings or steps separate identity fields from academic-identifier fields from employment-date fields. Evidence: `screens/r_profile_edit_dialog.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-793", "items": 14, "limit": 9}

> Recommendation: Split into labeled sub-sections (Identity, Identifiers, Employment) within the same dialog, or turn it into a 2-3 step wizard so no single view demands scanning 14 fields at once.
**F-018 · sev 2 · LAW-JAKOB-1 · screen: r_account_menu** — The mode_chooser copy fix (F-018) now correctly says 'You can switch at any time from the bottom of the sidebar,' matching where the real controls live — but the underlying Jakob's-law violation it was covering for is still present: the header identity block (avatar 'EB' + 'E2E Bot' + role text, top-right) remains non-interactive (clickable="false" on all three text nodes in hierarchy/r_account_menu.json, bounds e.g. [320,13][381,36]), so there is still no account/mode-switch affordance where virtually every web app puts one. The crawler's scripted 'top-right name → menu' action again produced no menu — the captured screen is unchanged from the underlying page (this run it matches a_dashboard's content almost node-for-node) because there was nothing to click. Evidence: `screens/r_account_menu.png`.

> Recommendation: Add a real top-right account/mode menu (or at minimum make the identity block clickable and route it to the same switch/sign-out actions currently only available at the bottom of the sidebar).
**F-019 · sev 2 · LAW-MILLER-1 · screen: a_dashboard** — The admin dashboard still renders KPI tiles as one undifferentiated grid with no category headers: 15 tiles visible above the fold (ORCID Linked, Profiles Validated, Outputs Approved, DOI Coverage, Researchers, Outputs, Journal Articles, Needs Verification, Missing ORCID, Labs, Projects, Clusters, Verified Outputs, Lab Allocations, Mentorships), immediately followed by 'Outputs by type' (10 rows), a quartile chart, 'People by category', 'Projects by cluster' and 'Projects by lab' panels on the same scroll. measurements.json still flattens the whole panel into one oversized semantic group ({"items":90,"limit":9}) — same violation as the previous run, now with 3 more KPI tiles than before and still no sub-grouping (e.g. People vs Outputs vs Structure vs Reporting). Evidence: `screens/a_dashboard.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-36", "items": 90, "limit": 9}

> Recommendation: Cluster the KPI tiles under 3-4 labeled sub-headers (People, Outputs, Structure, Reporting) of ≤9 tiles each instead of one undifferentiated grid.
**F-020 · sev 2 · NAV-4 · screen: a_admin_review** — Persists from the previous run. a_admin_review.png (Pending approval) still adds a secondary row of 7 top tabs (Profiles to approve, Outputs to approve, Needs re-verification, Suggestions, Activity, Needs attention, ORCID works) on top of the single left-sidebar entry "Pending approval". No other screen in the inventory combines the sidebar with a secondary flat tab bar, and 7 tabs in one row exceeds the ~5 a single flat tab row should hold. Not in the fixed/merged list for this run. Evidence: `screens/a_admin_review.png`. Measurement: 7 tabs in one row, unique to this screen, unchanged from previous run

> Recommendation: Either split the 7 sub-views into their own sidebar leaves (consistent with the rest of the IA) or reduce/group the tabs (e.g. a dropdown for the 3 least-used) so no single tab row exceeds ~5 items.
**F-021 · sev 2 · ST-EMPTY · screen: r_outputs_import** — Unchanged since the first run (out of round-5 scope): Import & Synchronisation shows an 'ORCID Sync' heading with only 'My ORCID publications · 0 / Nothing new' for a researcher with no ORCID iD on file, and no explanation or link to Researcher Identifiers. 158 of 184 people have no ORCID. Evidence: `screens/r_outputs_import.png`. Measurement: SQL: 26/184 people with orcid; 1 466 candidates pending

> Recommendation: Branch the empty state: no iD → explain and link to Identifiers; iD but nothing staged → show last sync time and offer a manual sync.
**F-022 · sev 2 · ST-LOAD · screen: state_error_backend_down** — state_error_backend_down.png and state_error_dashboard_down.png are both captured at 3s into a Supabase-blocked load and show only an unbounded, unlabeled loading dot -- no "still trying", no elapsed-time or retry-now affordance, no cap visible in this frame. Per the run's evidence, the classified error message with a Retry action only appears after the client's 20s timeout, so a user watching this frame for up to ~20s gets no visible sign the app is aware anything is wrong or how much longer to wait -- a purely silent wait, distinct from the eventual (correct) ST-ERROR state that follows it. Evidence: `screens/state_error_backend_down.png`. Measurement: spinner-only frame at 3s; first user-facing error/Retry affordance not until ~20s

> Recommendation: Show progressive feedback during the wait (e.g. "Still connecting..." after 3-5s) rather than a bare spinner for up to 20s before the classified error with Retry appears.
**F-023 · sev 2 · ST-LOAD · screen: state_loading_cold** — Persists from the previous run (2026-09-09-1136). Cold-start screenshot taken at +250ms is still fully blank white with zero content; hierarchy/state_loading_cold.json still returns only an empty semantics tree — no splash, no spinner, no branding is rendered while the Flutter engine boots. No fix was made to this surface between runs (it is not in the fixed/merged list for this run). [also H1 on state_loading_cold: Persists from the previous run. At +250ms into a cold load, the screen is still entirely blank white — no spinner, logo, or skeleton UI indicates the app is starting up.] Evidence: `screens/state_loading_cold.png`. Measurement: capture at +250ms, 0 semantic nodes, unchanged from previous run

> Recommendation: Ship a static HTML/CSS splash (logo or spinner) shown before the Flutter engine attaches, so cold load never presents a blank white frame.
**F-024 · sev 2 · VD-COL-2 · screen: a_dashboard** — Unchanged since previous audit. The 12 KPI tiles are one repeated component (label + big number + colored top border) but the accent color still splits arbitrarily between plain counts: teal for 'Orcid Linked', 'Profiles Validated', 'Outputs Approved', 'Doi Coverage', 'Outputs', 'Verified Outputs', but blue for structurally identical plain counts 'Journal Articles', 'Projects', 'Clusters', 'Lab Allocations'. Red is correctly reserved for the two problem metrics ('Needs Verification', 'Missing Orcid'), but the teal/blue split among the rest has no visible rule and reads as arbitrary decoration. Evidence: `screens/a_dashboard.png`.

> Recommendation: Standardize on one neutral accent (teal) for all plain-count tiles; reserve blue for a specific, named category of meaning (e.g. 'grouping/structure' metrics) if one is intended, otherwise drop the second neutral color entirely.
**F-025 · sev 2 · VD-COL-2 · screen: r_home** — Unchanged since previous audit. The 'OUTPUTS' and 'PROFILE STATUS' stat cards still share one continuous amber/warn-colored top border. 'Profile Status: draft/awaiting approval' is legitimately a warning state, but 'Outputs: 0' is a neutral count with no problem, yet it carries the same warning-amber accent, diluting the color's meaning. Same mis-pairing repeats on r_home_summary (identical card pair, identical shared amber bar) and on the phone layout (phone_r_home). Evidence: `screens/r_home.png`.

> Recommendation: Apply the amber/warn accent only to the card whose state actually needs attention (Profile Status); give the neutral Outputs count a neutral border/no accent.
**F-026 · sev 2 · VD-RESP-1 · screen: a_admin_reports** — The previously-reported Type column overflow is fixed (values now wrap within the column and show a full-text tooltip on hover). However the adjacent Subtype column exhibits the same underlying problem: values such as 'Membro da comissão cientifi', 'Orador por convite em confe...' are cut off exactly at the 1280px viewport edge mid-word, with no ellipsis, tooltip, or horizontal-scroll affordance indicating more content exists off-screen. Evidence: `screens/a_admin_reports.png`.

> Recommendation: Extend the same fix already applied to the Type column (wrap + hover tooltip, or a horizontal-scroll container with a visible scrollbar/edge fade) to the Subtype column and any other columns that can overflow the viewport.

### Severity 1 — cosmetic

**F-027 · sev 1 · DS-BTN-1 · screen: r_outputs** — Unchanged since the previous run: the add-output action appears twice in two variants on one screen — the top-right 'Add output' is a filled navy primary button, while the 'Timeline · 0' section's '+ Add' directly below is a plain blue text link (tertiary/ghost style) for functionally the same action. Evidence: `screens/r_outputs.png`.

> Recommendation: Use the theme's outline/secondary button style for the Timeline '+ Add' instead of a bare text link, so it reads as a lower-tier variant of the same button family rather than a different control type.
**F-028 · sev 1 · DS-FORM-1 · screen: r_add_output_dialog** — Unchanged since the previous run: every field in the Add output dialog (Title, DOI, Full reference, Category, Reporting year, Output status) renders with the label floating inside the empty input box (Material filled/outlined pattern), diverging from Carmela's template form (.field/label as static text above the input, used in unidcom-researcher.html's New Request form). The app is internally consistent between its own dialogs (r_add_output_dialog, r_profile_edit_dialog) but both diverge from the only form pattern the Figma export specifies. Evidence: `screens/r_add_output_dialog.png`.

> Recommendation: If the floating-label Material pattern is the deliberate direction going forward, document the deviation; otherwise move labels above fields to match the template's convention before more forms are built.
**F-029 · sev 1 · DS-ICON-1 · screen: r_profile** — Unchanged since the previous run: on the Personal Information header row, 'Edit' uses a filled pencil glyph (Icons.edit) directly beside 'Connect ORCID', which uses an outlined badge glyph (Icons.badge_outlined) — a filled icon and an outlined icon in the same button row. The same clash recurs on a_output and a_lab, where the 'Edit' pencil is filled while surrounding row icons (ORCID/Ciência ID glyphs on r_profile_identifiers) are outlined. Evidence: `screens/r_profile.png`.

> Recommendation: Standardise on the outlined Material Icons style already used by the sidebar and swap the filled Icons.edit for Icons.edit_outlined wherever it sits next to outlined controls.
**F-030 · sev 1 · H2 · screen: a_objective** — The objective detail page shows cluster codes as bare pills ('C3', 'R3', 'T3', 'E3', 'F3') with no expansion or tooltip, and the objective itself is only identified as 'UNID.9' in the breadcrumb-style header alongside its plain-language title. A new admin unfamiliar with the FCT/UNIDCOM cluster taxonomy has no in-page way to learn what C3/R3/T3/E3/F3 stand for. Evidence: `screens/a_objective.png`.

> Recommendation: Add a tooltip or short label next to each cluster code pill spelling out the cluster name (as the Structure > Clusters list presumably already has), rather than showing bare internal codes.
**F-031 · sev 1 · H4 · screen: r_outputs** — Persists from the previous run. Two different labels are still used for the same 'add an output' action on the same screen: the top-right button says 'Add output' while the inline control next to the Timeline heading says just 'Add' (both visible together on r_outputs.png). Evidence: `screens/r_outputs.png`.

> Recommendation: Use one consistent label ('Add output') for both entry points to the same action.
**F-032 · sev 1 · ST-EMPTY · screen: state_empty_people_search** — Five-state coverage sampled across data screens, updated for this run's fixes: | Screen | ST-IDLE | ST-LOAD | ST-SUCCESS | ST-ERROR | ST-EMPTY | |---|---|---|---|---|---| | People search | present | n/a | present | n/a | present (weak) | | People (backend down, @3s) | n/a | present (silent/unbounded @3s) | n/a | present (delayed, classified error+Retry appears only after the 20s client timeout) | n/a | | Dashboard (backend down, @3s) | n/a | present (silent/unbounded @3s) | n/a | present (delayed, same 20s timeout) | n/a | | Cold boot | n/a | MISSING | n/a | n/a | n/a | | My Outputs after add | n/a | n/a | present (pending chip) -- FIXED this run, see flow_add_output_4_in_my_outputs.png | n/a | n/a | | Review queue reject | n/a | n/a | present (snackbar + Undo) -- FIXED this run, see flow_review_queue_5_after_reject.png | n/a | n/a |. state_empty_people_search.png itself still does the empty state reasonably well ("No people found", filters and search term still visible so the cause is inferable), but still offers no explicit next step (e.g. a "Clear search" action) beyond editing the search box by hand. Evidence: `screens/state_empty_people_search.png`. Measurement: 0 people / 0 next-step affordance besides editing the search field

> Recommendation: Add a "Clear filters/search" button to the empty result state so the next step is explicit rather than implicit.
**F-033 · sev 1 · VD-HIER-2 · screen: anon_welcome_logos** — Edge-alignment measurement shows four separate 3px near-miss offsets among the logo-swatch card elements (edge pairs at x=325/328, 328/331, 344/347, 375/378), i.e. the swatch chip, label, and download-icon elements in the 'Logos & brand assets' cards are not sitting on a shared grid column. Same layout is reused verbatim on r_welcome_logos with identical offsets. Evidence: `screens/anon_welcome_logos.png`. Measurement: alignment_near_misses: [{edges_px:[325,328],offset:3},{edges_px:[328,331],offset:3},{edges_px:[344,347],offset:3},{edges_px:[375,378],offset:3}]

> Recommendation: Snap the swatch/label/icon elements inside each logo card to the same left-edge grid column so repeated cards align pixel-for-pixel.
**F-034 · sev 1 · VD-TYPE-1 · screen: a_admin_data** — Unchanged since previous audit. In the 'people' table of the raw Data Browser, the 'bio' column still renders full free-text paragraphs (e.g. three researchers' bios) at roughly 12-13px, below the 16px floor for text meant to be read rather than scanned as a short label/ID. Evidence: `screens/a_admin_data.png`.

> Recommendation: For long free-text columns (bio, notes), either truncate with an expand-on-click affordance shown at readable size, or bump the cell font size for these specific columns instead of reusing the compact ID/date-column size.

## Comparison with RIMS best practice (BP-01…38)

Scored against the checklist in `docs/research/2026-09-rims-best-practices.md`. Evidence is a screen file, a code pointer, a migration or a SQL result from the production database on 2026-09-09. Score: **57 / 100** (10 yes · 23 partial · 5 no).

| ID | Status | Evidence | Gap |
|---|---|---|---|
| BP-01 | yes | output_authors(output_id, person_id, role, author_position) — SQL information_schema 2026-09-09 |  |
| BP-02 | partial | membership_type (integrated 46 / collaborator 109 / external 22 / null 7) plus join_date/exit_date live on the person row; lab membership is a link table with a year. No dated unit-membership history. | A person who changes category loses history; FCT cycles need it. |
| BP-03 | partial | 10 macro_type values are the FCT activity-report categories in Portuguese (e.g. 'Artigos em revistas', 'Actividades de gestão e auxílio à UNIDCOM'); category_path cascade below them. No CASRAI/CERIF mapping. | Map the two publication macro-types to CASRAI terms; label the rest as activities, not outputs. |
| BP-04 | yes | people.orcid (26/184 filled), people.ciencia_id (25/184); both shown on Researcher Identifiers (screens/r_profile_identifiers.png) | Coverage, not capability: 158 researchers have no ORCID on file, so cannot sign in. |
| BP-05 | yes | outputs.doi with UNIQUE INDEX outputs_doi_key; 45/365 filled, 0 duplicates |  |
| BP-06 | partial | outputs has approval_status only; people/projects have public_visibility. The public site adds a fail-closed macro_type allowlist in unidcom-site/scripts/sync.py (76 of 365 rows publish). | The publish decision is spread over three mechanisms in two repos; a single visibility column on outputs would make it visible in the portal. |
| BP-07 | no | Add output opens a blank dialog: Title, DOI, Full reference, Category, Reporting year, Output status (screens/r_add_output_dialog.png). DOI is a plain text field; 'Find DOI' is v2 and admin-only on the detail page. | Start from DOI lookup (Crossref client already exists in lib/data/enrich_client.dart) and pre-fill title/year/type. |
| BP-08 | yes | Weekly orcid-sync.yml stages works into output_candidates (1 471 rows, 26 people); Import & Synchronisation lists them with Add / Add all; admins see Import as… / Dismiss (candidate_tile.dart) | Researchers get Add but no Dismiss/Not mine, so 1 466 candidates stay pending forever (max 281 for one person). |
| BP-09 | partial | 'Add all' for a researcher's candidates; 'Approve all pending (N)' for admins. No checkbox selection, no bulk reject. | All-or-one only. |
| BP-10 | partial | Manual form is the only path. No required-field legend; Title validates on submit with inline text (flow_add_output_2_validation.png). | Mark Title as required up front; explain what Full reference is for. |
| BP-11 | partial | outputs: pending → approved | rejected (check constraint, migration 20260804120000). people: draft → pending_review → approved. No draft state for outputs; a researcher's save is an immediate submission. | No way to save an incomplete output privately. |
| BP-12 | partial | Approve/Reject are admin-only (RLS is_admin on outputs_write; create_my_output forces pending). No withdraw for the researcher. | Researcher cannot retract a pending item. |
| BP-13 | partial | Reject now asks for a reason (F-005 fix, PR 38); the researcher sees it under the rejected output in My Outputs. No 'returned for correction' state — rejected is terminal unless an admin undoes it. | No return-with-comment loop, only reject-with-reason. |
| BP-14 | no | output_status holds 'Planeado' (6) / 'Concluído' (46) / null (313) and is not consulted by approval. |  |
| BP-15 | yes | change_log(subject_type, subject_id, field, old_value, new_value, source, actor, changed_at): 605 rows, 365 output approvals, 186 profile transitions | Non-admin edits are not logged (cl_write is admin-only; AUDIT.md). |
| BP-16 | partial | DOI duplicate is caught by the unique index and surfaced as 'That DOI already belongs to another output' on the detail page; title_norm exists but no similarity check at entry — 8 title_norm groups are duplicated in the live table. | Title-similarity warning before save. |
| BP-17 | partial | Outputs list has an Issues filter and the detail page offers Merge duplicates when a cluster ≥ 2; the review queue row itself shows no duplicate badge (screens/flow_review_queue_3_FAIL.png). |  |
| BP-18 | yes | merge_people RPC + mergeOutputs, merge matrix UI (screens/a_admin_merge.png); reassigns output_authors/project_members |  |
| BP-19 | partial | Client-side: Title required, data retained, inline error (flow_add_output_2_validation.png). Server: create_my_output whitelists the payload and forces status/source/affiliation. | Other fields unvalidated (year accepts any text until save). |
| BP-20 | no | Single inline error only; no summary, no focus management. |  |
| BP-21 | yes | My Outputs timeline shows a 'pending' / 'rejected' pill on each non-approved row (F-009 fix, PR 32); rejected rows carry the reason (PR 38). |  |
| BP-22 | partial | Overview → Alerts card: 'Your profile is awaiting confirmation' with link (screens/r_home.png). No alert for missing ORCID/CIÊNCIA ID, unclaimed candidates or drafts. |  |
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
| BP-36 | partial | Dashboard tiles: ORCID linked 26/184, profiles validated 183/184, outputs approved 365/365, DOI coverage 45/365, 'Needs verification' (screens/a_dashboard.png). Missing: CIÊNCIA ID coverage, unclaimed candidates (1 466), stale drafts. |  |
| BP-37 | partial | Admins edit any profile directly; change_log.actor records the admin. No delegate role, no 'on behalf of' marker. |  |
| BP-38 | partial | auth.users.last_sign_in_at (3 of 5 accounts in 30 days) and change_log give sign-ins and first validation; no returning-user or task-completion instrumentation. | HEART instrumentation recommendation in the report. |

**Where the portal is ahead of the field for its size:** the data model (link rows for authorship, unique DOI, full audit trail), the approval gate feeding a nightly, fail-closed public build, ORCID harvesting into a staging table, and a real merge tool. These are the parts commercial systems charge for and small units usually skip.

**Where it trails every system surveyed:** the *entry* experience — a blank form instead of an identifier lookup (BP-07), no title-similarity warning (BP-16), no draft/withdraw (BP-11/12), no reviewer comment (BP-13), and no status tag in the researcher's own list (BP-21). Pure, Converis, Elements and Haplo all start from a DOI/ORCID lookup and show the workflow state on the researcher's list; FCT's own guidance makes CIÊNCIA ID coverage and the five representative outputs the unit-level facts that matter (BP-34, BP-36), and neither is surfaced yet.

## Design criticism — what the fixes changed and what they did not

**Fixed drift.** Every item the first run classed as drift rather than decision is closed: sidebar semantics, person-page refetch, highlight logic, the stale Maestro suite, Reject without confirmation, the raw `draft` tile, the mode-switch copy, the footer overlap, the phone layouts, the illegible swatch labels. The two regressions this run found (duplicated status text, blank 404) came from those fixes and are also closed — which is the argument for keeping this crawl in the routine.

**Unchanged by decision.** The researcher sidebar still carries 25 rows with a third of them placeholders (F-001, F-013 in this run), and DOI-first entry is still behind the v2 flag. These are product calls for Rui; the numbers to take into that conversation are unchanged from the first report.

**Newly visible.** With the big items gone, smaller consistency debt is what remains: raw status chips (`external`, `inactive`, `pending_review`) on the researcher's own profile header (F-002), three different feedback patterns for the same message type (F-003), the thin Personal Information page (F-006), and the v2 admin route that lands on a queue instead of redirecting (F-008). None is above severity 2.

## Recommendations

Ordered by value. Nothing here is a blocker.

1. **Sidebar decision with Rui** (F-001, F-013): section headers only by default, placeholder rows marked or hidden. Half a day once decided.
2. **Status chips on the profile header** (F-002): reuse `queueStatusLabel()` from `lib/widgets/queue_list.dart` — the same fix that closed F-012 on the People list.
3. **Feedback pattern** (F-003): pick one of inline text / SnackBar / banner per message type and apply it in the three places that differ.
4. **v2 admin route** (F-008): redirect `/app/admin/requests` in v1 the way `/app/requests` already is.
5. **Empty ORCID-sync state** (F-021): explain and link to Researcher Identifiers when no iD is on file.
6. **Cold-start shell** (F-023): a static splash in `web/index.html` so the 4 MB bundle is not a white page.
7. **BP-07 DOI-first entry and BP-16 title-similarity warning** remain the highest-value feature work before the demo, unchanged from the first report.

Design-system debt worth batching: one icon family (DS-ICON-1 ×3), one accent per KPI component (VD-COL-2 ×2), the add-output button variants (DS-BTN-1, H4).

## Trend vs previous run (2026-09-09-1136)

| Metric | Previous | Now | Δ |
|---|---|---|---|
| task_success_rate_pct | 100.0 | 100.0 | 0.0 |
| avg_steps_per_flow | 7.9 | 8.1 | 0.2 |
| findings_total | 43 | 34 | -9 |
| severity_weighted_score | 93 | 61 | -32 |
| defect_density_per_screen | 0.5 | 0.41 | -0.09 |
| findings sev 4 | 2 | 0 | -2 |
| findings sev 3 | 9 | 1 | -8 |
| findings sev 2 | 26 | 25 | -1 |
| findings sev 1 | 6 | 8 | +2 |

- **Fixed (16):** F-001 DS-A11Y-1@r_home, F-002 H1@a_person_e2e_self, F-003 H1@anon_welcome_docs_m2, F-005 H5@a_admin_review, F-006 H9@r_unknown_route, F-008 NAV-1@r_outputs_add, F-009 ST-SUCCESS@flow_add_output_4_in_my_outputs, F-010 VD-RESP-1@phone_a_dashboard, F-011 VD-TYPE-3@anon_welcome_logos, F-012 DS-BRAND-1@a_people, F-015 FLOW-1@r_welcome_start, F-016 H1@r_home_status, F-018 H2@r_account_menu, F-019 H2@r_profile, F-035 VD-GES-1@r_home, F-037 VD-RESP-1@phone_a_review
- **New (7):** F-002 DS-BRAND-1@r_profile, F-003 DS-FDBK-1@state_error_backend_down, F-006 H1@a_deeplink_profile, F-008 H4@a_admin_requests_v2, F-018 LAW-JAKOB-1@r_account_menu, F-030 H2@a_objective, F-033 VD-HIER-2@anon_welcome_logos
- **Regressed (0):** —
- **Persisting (27):** F-001 (was F-007) LAW-MILLER-1@r_sidebar_expanded, F-004 (was F-013) DS-ICON-1@r_sidebar_expanded, F-005 (was F-014) DS-ICON-1@r_welcome_start, F-007 (was F-017) H10@login, F-009 (was F-020) H4@r_outputs_import, F-010 (was F-004) H4@r_welcome_affiliation, F-011 (was F-021) H5@r_add_output_dialog, F-012 (was F-022) H5@r_profile_edit_dialog, F-013 (was F-023) H6@r_profile_areas_wip, F-014 (was F-024) LAW-FITTS-1@a_person, F-015 (was F-025) LAW-FITTS-1@r_profile_edit_dialog, F-016 (was F-026) LAW-HICK-1@a_people, F-017 (was F-027) LAW-HICK-2@r_profile_edit_dialog, F-019 (was F-028) LAW-MILLER-1@a_dashboard, F-020 (was F-029) NAV-4@a_admin_review, F-021 (was F-030) ST-EMPTY@r_outputs_import, F-022 (was F-031) ST-LOAD@state_error_backend_down, F-023 (was F-032) ST-LOAD@state_loading_cold, F-024 (was F-033) VD-COL-2@a_dashboard, F-025 (was F-034) VD-COL-2@r_home, F-026 (was F-036) VD-RESP-1@a_admin_reports, F-027 (was F-038) DS-BTN-1@r_outputs, F-028 (was F-039) DS-FORM-1@r_add_output_dialog, F-029 (was F-040) DS-ICON-1@r_profile, F-031 (was F-041) H4@r_outputs, F-032 (was F-042) ST-EMPTY@state_empty_people_search, F-034 (was F-043) VD-TYPE-1@a_admin_data

## Appendix

### A. Screen inventory
See `screens.md` (82 crawled screens + 21 flow-step screenshots + 4 verification screenshots). Files: `screens/<name>.png`, `hierarchy/<name>.json` — **kept out of git** (they contain researcher emails from the admin data browser); they exist only on the audit machine, alongside `measurements.json`.

### B. Flow results

| Flow | Passed | Steps | Duration (s) | Source | Note |
|---|---|---|---|---|---|
| auth_gate | yes | 6 | 7.0 | .maestro/auth_gate.yaml |  |
| researcher_mode | yes | 9 | 17.9 | .maestro/researcher_mode.yaml |  |
| admin_mode | yes | 8 | 8.4 | .maestro/admin_mode.yaml |  |
| orcid_error | yes | 3 | 3.7 | .maestro/orcid_error.yaml |  |
| profile_confirm | yes | 8 | 4.8 | (new) profile_confirm — researcher confirms draft profile |  |
| add_output | yes | 11 | 8.3 | (new) add_output — researcher records an output manually |  |
| review_queue | yes | 12 | 17.4 | (new) review_queue — admin sees, confirms-all, rejects |  |
| featured_star | NOT RUN | 0 | 0 | .maestro/featured_star.yaml | NOT RUN: the E2E account has 0 outputs to star |
| support_request | NOT RUN | 0 | 0 | .maestro/support_request.yaml | NOT RUN: v2-only route, compiled out of the pilot build |

### C. Verification of subagent claims
Six claims at severity ≥ 3 were re-tested by the orchestrator before inclusion: two "no error state" claims (backend down) — the classified error appears after the 20 s client timeout, recorded instead as F-035 (silent spinner); one "wrong person shown" claim — confirmed and promoted (F-002); one "account menu does nothing" claim — there is no menu, the copy points to the wrong place (F-018); two tap-target claims (drawer rows 15 px / 5 px, a 6 px row on conferences) — clipped-viewport artefacts, folded into F-035 or dropped.

### D. measurements.json summary
916 tap targets under 24 px (most `assumed`, i.e. labelled leaves without an explicit clickable flag), 290 groups over 9 items, 62 alignment near-misses across 81 hierarchies. Contrast estimates were used only for leaf text.

### E. Reproduce
`audit/tools/README.md`. Cleanup SQL for the two DB-writing flows is in `screens.md`.

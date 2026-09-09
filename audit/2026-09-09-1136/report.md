# UX/UI Audit — UNIDCOM RIMS researcher portal (web, Playwright Chromium 1280×900 / 390×844) — 2026-09-09

## Executive Summary

**Release verdict: NOT READY.**

43 findings (2 severity-4, 9 severity-3, 26 severity-2, 6 severity-1) across 86 screens, task success rate 100 % on 7 of 9 defined flows, best-practice score 51 / 100 (9 yes · 21 partial · 8 no of 38 BP items).

The three findings that matter most:

1. **The desktop navigation is invisible to assistive technology (F-001).** At ≥900 px the whole sidebar — 25 rows, the mode switch, sign-out — has no accessibility nodes. Keyboard and screen-reader users cannot move between sections. The phone drawer exposes the same rows correctly, so this is a layout-branch defect, not a design choice.
2. **A person page keeps showing the previous researcher when only the id changes (F-002).** Verified twice: the page under Celia's URL and under the E2E account's URL were byte-identical, and a hash change after a fresh load still showed the old record. An admin can edit the wrong researcher.
3. **Workflow state is silent where the researcher looks (F-005, F-009).** A newly added output shows no "pending" tag in My Outputs, and an admin's Reject fires with no confirmation, no reason and no feedback — the researcher never learns that or why their item vanished.

Every flow that could be run passed: the pilot's core loop (sign in → choose mode → confirm profile → add an output → admin queue → decision) works end to end. The findings are about *legibility* of that loop, not its existence.

## Background & Objectives

- App: UNIDCOM RIMS researcher portal, `Unidcom-IADE` repo, commit `73259d4` (round 4, one-to-one sidebar, merged 2026-09-08). Build: `flutter build web --dart-define=E2E=true`, v1 (pilot) feature set — v2-only controls (Support requests, Approve/Auto-fill/ORCID-sync on the profile band, Find DOI) are compiled out and were not audited.
- Trigger: pilot cohort onboarding in September 2026; no UX/UI audit had been done (the 2026-08-07 `AUDIT.md` covered engineering, security and operations).
- Companion documents: `docs/research/2026-09-rims-best-practices.md` (cited RIMS/CRIS best practice + BP checklist) and `docs/reports/2026-09-ux-audit/` (stakeholder PDF).

## Methodology

- **Crawl:** every route in `lib/main.dart` in three modes — anonymous, researcher, admin — plus dialogs, the mode chooser, the phone breakpoint for the shell and 7 representative pages, and five provoked system states (cold-start loading, wrong password, empty search, backend unreachable at 3 s and at 26 s). 86 screens, each with a screenshot and a semantics-tree dump (`screens.md`).
- **Flow suite:** the five v1 Maestro journeys re-expressed in Playwright (Maestro's Chromium driver never returned from its first wait on this machine, three attempts) plus two new journeys covering the RIMS value loop: `profile_confirm` and `add_output` → `review_queue`. `featured_star` (E2E account owns no output) and `support_request` (v2) were not run.
- **Deterministic measurements:** `audit/tools/measure_px.py` over the hierarchies — tap targets vs the 24 px WCAG 2.5.8 minimum, groups vs Miller 7±2, alignment near-misses, contrast estimates (leaf text only; container estimates discarded).
- **Frameworks:** Nielsen's 10 heuristics, UX laws (Fitts, Hick, Miller, Jakob), visual design incl. WCAG 2.2 AA, design-system consistency against `lib/theme/tokens.dart` and Carmela's Figma exports (`RAW_DATA/TemplatesFromCarmela/`), five system states, navigation, ISO 9241-11 metrics, Google HEART mapping, and the BP-01…38 checklist from the research report. Five review passes ran in parallel (one per dimension) plus the orchestrator's own verified findings; every subagent claim at severity ≥ 3 was re-tested before inclusion, and 6 were corrected or dropped (see Appendix C).
- **Not covered:** ORCID OAuth on device; human-participant methods (SUS, interviews); the public Hugo site (reviewed from code and generated data only, scored in the BP table where relevant); v2 controls.

## Metrics

| Metric | Value | Source |
|---|---|---|
| Screens audited | 86 | `screens.md` |
| Flows defined / run / passed | 9 / 7 / 7 | `flows-results.json` |
| Task success rate (ISO 9241-11 effectiveness) | 100 % | flows |
| Mean steps per flow (efficiency) | 7.9 | flows |
| Mean automation time per flow | 9.0 s | flows (automation speed, compare run-over-run only) |
| Flow errors | 0 (+2 warnings) | flows |
| Findings sev 4 / 3 / 2 / 1 | 2 / 9 / 26 / 6 | `findings.json` |
| Defect density | 0.5 findings per screen | derived |
| Severity-weighted score (Σ severity) | 93 | derived — the number to drive down next run |
| Best-practice score | 51 / 100 | `bp-scorecard.json` (yes = 1, partial = ½) |
| Untraceable findings dropped | 0 | aggregate |

### Google HEART mapping

| Dimension | Measured here | Needs instrumentation |
|---|---|---|
| Happiness | Proxy: severity-weighted score 93; sev-3+ count 11 | in-app rating after first profile confirmation |
| Engagement | Proxy: core loop is 7.9 steps mean; researcher must scroll the sidebar to find Scientific Outputs at 1280×900 (F-007) | sessions per researcher per month |
| Adoption | Proxy: first-launch to value (login → chooser → welcome) in 6 steps; 158/184 researchers cannot sign in until an admin registers their ORCID iD | sign-ins per cohort member (auth.users.last_sign_in_at: 3 of 5 accounts in the last 30 days) |
| Retention | Proxy: state persists across reload (collapse state, mode) — good; 20 s silent spinner on a bad connection (F-031) | returning users after 7 days |
| Task success | **Measured:** 100 % task success, 0 errors, 2 warnings (status invisibility) | field completion rate of profile confirmation and first claim per cohort member |

Minimal instrumentation (one finding's worth): log `mode_chosen`, `profile_confirmed`, `output_added`, `candidate_claimed`, `review_decision` with actor and timestamp — `change_log` already holds the last three; the first two are one insert each.

## Key Findings

### Severity 4 — must fix before the cohort is onboarded

**F-001 · sev 4 · DS-A11Y-1 · screen: r_home** — At the desktop breakpoint (≥900 px) the left navigation is absent from the accessibility tree: the DOM holds 17 flt-semantics nodes on /app/home and none is a sidebar row, group header, 'Switch to admin', 'Public site' or 'Sign out'. Verified after hover, 5×Tab, wheel scroll, resize to 1000 px and reload (probe 2026-09-09). The same SideNav widget inside the phone Drawer exposes every row as role=button (hierarchy/phone_r_drawer.json). Admin mode identical (hierarchy/a_dashboard.json has no 'People', 'Structure' or 'Reports' node). Evidence: `screens/r_home.png`. Measurement: hierarchy/r_home.json: 9 labelled nodes, 0 navigation nodes; hierarchy/phone_r_drawer.json: 31 navigation nodes

> Recommendation: Treat as a release blocker for keyboard and screen-reader users: the only way to move between sections on desktop is the mouse. Reproduce with `flutter build web --dart-define=E2E=true` and inspect flt-semantics; suspect the Row/SizedBox desktop branch in lib/widgets/app_shell.dart:66-75 vs the Drawer branch. Add a widget test asserting the SideNav rows are present in the semantics tree at 1280 px; add a Maestro assert on a sidebar label at desktop width so the regression is caught.
**F-002 · sev 4 · H1 · screen: a_person_e2e_self** — Verified: /people/<E2E id> captured after /people/<Celia id> is byte-identical to Celia's page (md5 459cc8a2 both). After a hard reload on the E2E URL the correct record shows; then changing the hash to Celia's id keeps showing E2E Bot (md5 5acaf5fd for both a_person_e2e_self_reload.png and a_person_hash_switch.png). The person page does not refetch when only the :id parameter changes, so an admin following a person→person link or editing the URL sees, and can edit, the previous researcher's record under the new researcher's URL. Root cause: lib/public/person_page.dart:71-74 initialises `late Future … = fetchPerson(widget.id)` once and has no didUpdateWidget, so a new :id on the same route reuses the old State. Evidence: `screens/a_person_e2e_self.png`. Measurement: screens/a_person.png == screens/a_person_e2e_self.png; screens/a_person_e2e_self_reload.png == screens/a_person_hash_switch.png

> Recommendation: Key the page widget by id (ValueKey(id)) in the GoRoute builder or refetch in didUpdateWidget when widget.id changes; add a widget test that navigates A→B and asserts B's name.

### Severity 3 — high priority

**F-003 · sev 3 · H1 · screen: anon_welcome_docs_m2** — screens.md notes this M2 slug (/app/welcome/docs) is 'expected redirect to start' for an anonymous visitor. Instead the screenshot is a full Sign-in screen — an anonymous user browsing the public welcome pack unexpectedly lands on a login wall for one specific sub-page, with no message explaining why, breaking the otherwise-consistent anonymous welcome flow (anon_welcome_start/affiliation/fct/report/... all render without login). Evidence: `screens/anon_welcome_docs_m2.png`.

> Recommendation: Route unknown/compiled-out welcome slugs to /app/welcome/start like the other anon-accessible welcome pages, instead of falling through to the sign-in gate.
**F-004 · sev 3 · H4 · screen: r_welcome_affiliation** — For an anonymous visitor, /app/welcome/affiliation shows a dedicated sidebar with the full welcome-pack sub-nav (Getting Started, Affiliation Guidelines, FCT Information, Research Activity Reporting, Email Signature, Social Media, Logos & Brand, Key Contacts) and highlights the current item. For a signed-in researcher visiting the identical route, the sidebar is replaced by the full app sidebar (Overview / My Profile / Scientific Outputs...) with none of those welcome-pack sub-items present and nothing highlighted as active — the researcher loses the in-page sub-navigation and any 'you are here' cue. The same regression reproduces on r_welcome_start/fct/report/signature/social/logos/contacts and r_help_links (Key Contacts content under a generic sidebar with no active state). Evidence: `screens/r_welcome_affiliation.png`.

> Recommendation: Render the same welcome-pack/help sub-nav for researchers that anonymous visitors get (or link the equivalent items under Overview/Help with correct active-state highlighting) so researchers always see where they are.
**F-005 · sev 3 · H5 · screen: a_admin_review** — Reject on a pending output fires immediately: lib/app/review_queue.dart `_rejectOutput(id)` calls rejectOutput() with no dialog, no reason field and no undo, while 'Approve all pending' on the same page does confirm. The row disappears with no feedback (flow review_queue, screenshot flow_review_queue after_reject). [also ST-SUCCESS on flow_review_queue_4_after_reject: flows-results.json `review_queue`: passed true, duration_s 13.7, steps 10, warnings: ["no feedback after Reject (finding)"]; note: "Reject has no confirmation dialog in code (review_queue.dart _reject] Evidence: `screens/a_admin_review.png`.

> Recommendation: Mirror the Approve-all pattern: confirm with the title in the dialog, capture an optional reason (which also closes the BP-13 gap: the researcher never learns why), and show a snackbar with Undo.
**F-006 · sev 3 · H9 · screen: r_unknown_route** — Visiting an unknown route (#/nope/404) in researcher mode shows 'Page Not Found' plus the raw developer exception text 'GoException: no routes for location: /nope/404' directly to the end user, alongside a 'Home' recovery link. [also DS-BRAND-1 on r_unknown_route: The 404 page abandons the app's visual system entirely: no sidebar, no card shell, no branded wordmark styling — just a bare navy title bar reading 'Page Not Found' over the sand background, with the ] [also ST-ERROR on r_unknown_route: The unknown-route screen (#/nope/404) shows the raw framework exception string "GoException: no routes for location: /nope/404" as the user-facing error message, instead of plain language. A "Home" re] Evidence: `screens/r_unknown_route.png`.

> Recommendation: Replace the raw exception string with a plain-language message ('This page doesn't exist') and keep the Home link; log the exception detail server-side/console only.
**F-007 · sev 3 · LAW-MILLER-1 · screen: r_sidebar_expanded** — The persistent researcher sidebar holds 25 leaf nav rows across 6 collapsible groups (OVERVIEW, MY PROFILE, SCIENTIFIC OUTPUTS, WELCOME PACK, HELP, SETTINGS). On the 1280x900 viewport, only 2 groups plus a sliver of the 3rd (11 items: 5 under OVERVIEW, 6 under MY PROFILE) fit before the fold; SCIENTIFIC OUTPUTS, the welcome pack, HELP and SETTINGS groups require scrolling to even discover. The group chevrons imply collapsibility, but all groups render expanded by default, so the app never actually chunks the list down to a Miller-safe size at first paint. [also LAW-MILLER-1 on phone_r_drawer: measurements.json flags the drawer nav as one flat oversized group: {"label":"flt-semantic-node-738","items":22,"limit":9} — 22 leaf items exposed as a single list on a 390px viewport, 2.4x Miller's c] Evidence: `screens/r_sidebar_expanded.png`.

> Recommendation: Collapse all but the current section's group by default (accordion behavior, one open group at a time) so the visible option count stays near 7±2, and let the active route auto-expand only its own group.
**F-008 · sev 3 · NAV-1 · screen: r_outputs_add** — On /app/outputs/add the sidebar highlights 'My Outputs', not 'Add Scientific Output'. navSelected() in lib/widgets/nav_model.dart returns the first item whose prefix matches, and '/app/outputs' matches before the exact '/app/outputs/add' row. Same for /app/profile/* leaves vs 'Personal Information'. Reproduced by the heuristics reviewer on r_profile_identifiers, r_profile_bio, r_profile_areas_wip, r_profile_interests_wip (all highlight 'Personal Information'). Evidence: `screens/r_add_output_dialog.png`.

> Recommendation: Prefer the longest matching route in navSelected() (exact match, then longest prefix).
**F-009 · sev 3 · ST-SUCCESS · screen: flow_add_output_4_in_my_outputs** — flows-results.json `add_output`: passed true, duration_s 12.6, steps 11, warnings: ["no status tag on the new pending output in My Outputs (finding, not a task failure)"]. flow_add_output_4_in_my_outputs.png and flow_add_output_5_FAIL.png both show the newly created row "E2E UX audit output (delete me)" with no status badge at all, whereas the same output shows a clear "● pending" tag on the admin review queue (flow_review_queue_3_confirm_dialog.png). The researcher who just submitted an output has no way to tell it succeeded or what state it is in. Evidence: `screens/flow_add_output_4_in_my_outputs.png`. Measurement: 12.6s / 11 steps, 0 status indicators rendered on the new row

> Recommendation: Render the same pending/approved/rejected status chip in My Outputs that already exists in the admin review queue UI.
**F-010 · sev 3 · VD-RESP-1 · screen: phone_a_dashboard** — On the 390px admin dashboard, the KPI card rows overflow the viewport: the third card in row 1 ('OUTPUTS APPROVED') shows only 'OU…/API/3/3', and the third card in row 2 ('JOURNAL ARTICLES') shows only 'JOU…/2' before being clipped by the screen edge, with no scroll indicator. Key metrics are unreadable at this width. Evidence: `screens/phone_a_dashboard.png`.

> Recommendation: Reflow the KPI grid to a single column (or a horizontally-scrollable row with visible affordance) below a defined breakpoint instead of letting a fixed multi-column grid clip against the viewport.
**F-011 · sev 3 · VD-TYPE-3 · screen: anon_welcome_logos** — In the 'Logos & brand assets' list, the 'IADE — Universidade Europeia / Positive' swatch renders as pale mint text on a pale mint chip (near-identical lightness to its background), and the 'FCT — Fundação para a Ciência e a Tecnologia / Positive · Horizontal' swatch renders as pale pink/red text on a pale pink chip. Both labels are barely legible against their own swatch background, unlike the adjacent 'Negative' and 'UNIDCOM/IADE' swatches which use dark navy chips with white text and read clearly. The identical bug repeats on r_welcome_logos (same page, researcher-mode route) — same design tokens, same low-contrast pairing. Evidence: `screens/anon_welcome_logos.png`.

> Recommendation: Give the 'Positive' logo-preview chips a dark or neutral card background (or a visible border) so the light-on-light brand mark is distinguishable, or render the identifying label ('IADE', 'FCT') outside the swatch in standard textPrimary instead of matching the swatch's own light tint.

### Severity 2 — minor

**F-012 · sev 2 · DS-BRAND-1 · screen: a_people** — The Status filter dropdown ('a_confirmar' -> displayed as 'a confirmar', via widgets/queue_list.dart's replaceAll('_',' ') humanizer) presents the value with a space, but the identical status rendered as a row pill (public/people_list.dart line ~175: StatusPill(status, tone: ...) passes the raw string straight through with no humanization) shows the literal snake_case 'a_confirmar' with the underscore intact, next to sibling pills reading the clean word 'active'. Same value, two different presentations on one screen; the raw form also leaves an unlocalized Portuguese admin-status code sitting in an otherwise English UI. Evidence: `screens/a_people.png`.

> Recommendation: Route the person-list StatusPill's label through the same humanizer used for the filter dropdown (or a shared status-label map), so 'a_confirmar' renders as 'To confirm' / 'a confirmar' consistently everywhere the value appears.
**F-013 · sev 2 · DS-ICON-1 · screen: r_sidebar_expanded** — The shared SideNav widget (lib/widgets/side_nav.dart, comment: 'The one dark left-hand navigation every shell renders now... one list, one look, everywhere') renders a leading icon for every top-level item in adminNav() (lib/widgets/nav_model.dart: Dashboard=Icons.dashboard_outlined, People=Icons.people_outline, Scientific outputs=Icons.article_outlined, Projects=Icons.work_outline, Structure=Icons.account_tree_outlined, Reports=Icons.summarize_outlined, Data browser=Icons.table_chart_outlined, Settings=Icons.settings_outlined), but researcherNav() sets icon: on none of its items (Research Activity Summary, Personal Information, My Outputs, etc.). Visually confirmed: r_sidebar_expanded/r_home/phone_r_drawer show plain indented text with zero icons, while a_dashboard/a_people/a_projects show a Material icon before every top-level label. Neither template defines this shared component (researcher template used a top-nav+tabs, admin template's own sidebar markup also has no icons at all), so this is an inconsistency introduced by the app itself between its two modes of one nominally shared component. Evidence: `screens/r_sidebar_expanded.png`.

> Recommendation: Give every top-level NavItem an icon in researcherNav() (lib/widgets/nav_model.dart) to match adminNav(), or remove icons from adminNav() — pick one rule and apply it in both modes of the one shared SideNav.
**F-014 · sev 2 · DS-ICON-1 · screen: r_welcome_start** — The three 'Getting started' summary cards use raw Unicode emoji as icons (lib/app/welcome_pack_content.dart lines 48/54/60: icon: '👥', '📍', '🌐'), rendering as full-colour platform emoji (blue people glyph, red map pin, blue globe) next to plain white cards — a completely different icon family from the monochrome Material Icons vector glyphs used everywhere else in the app (sidebar nav, buttons, alerts, status chips). The same three emoji recur on anon_welcome_start (public/anonymous variant) and the download cards on r_welcome_docs/logos use 📄/📕/📊 similarly. Carmela's template used the same emoji as icon placeholders in the Figma export, so the app inherited rather than resolved this inconsistency. Evidence: `screens/r_welcome_start.png`.

> Recommendation: Replace the emoji icons in welcome_pack_content.dart (people/pin/globe/doc/pdf/spreadsheet) with Material Icons (e.g. Icons.groups_outlined, Icons.location_on_outlined, Icons.language, Icons.description_outlined) so the Welcome pack matches the vector-icon system used in the rest of the portal.
**F-015 · sev 2 · FLOW-1 · screen: r_welcome_start** — The committed Maestro regression suite no longer matches the build: 7 assertions across 6 flows wait for 'Your first 5 steps', which the Welcome pack now renders as 'Your first steps' (hierarchy/r_welcome_start.json). auth_gate, researcher_mode, admin_mode, featured_star, orcid_error and support_request would all time out at that step. README still says 'Six flows … the regression suite'. Evidence: `screens/r_welcome_start.png`. Measurement: grep -c 'Your first 5 steps' .maestro/*.yaml → 7

> Recommendation: Update the six YAMLs and run them in CI (they are not in ci.yml), or the suite stops being a suite.
**F-016 · sev 2 · H1 · screen: r_home_status** — Profile Status shows 'draft' as a raw lower-case enum value in the stat tile ('PROFILE STATUS / draft') while the same state is rendered as 'Awaiting UNIDCOM approval' elsewhere (lib/app/my_profile.dart profileStatusLabel). The tile also gives no next action, although the page exists to answer 'what do I do now?'. Evidence: `screens/r_home.png`.

> Recommendation: Use profileStatusLabel() in the tile and add the next step ('Confirm my profile →').
**F-017 · sev 2 · H10 · screen: login** — The sign-in form offers only 'Sign in' (email/password) and 'Sign in with ORCID iD' — there is no 'Forgot password' or account-recovery link anywhere on the screen. Evidence: `screens/login.png`.

> Recommendation: Add a password-recovery link under the password field so users who forget their credentials aren't stuck.
**F-018 · sev 2 · H2 · screen: r_account_menu** — The mode chooser says 'You can switch at any time from your name, top right', but there is no control top right: the profile band (avatar, name, role) is not clickable (hierarchy/r_account_menu.json: clickable=false) and the actual controls are three text links at the bottom of the sidebar ('Switch to admin', 'Public site', 'Sign out'). The instruction points to the wrong place. [also LAW-JAKOB-1 on r_account_menu: mode_chooser explicitly tells the user 'You can switch at any time from your name, top right.' But there is no account control top-right anywhere in researcher or admin mode — the header's identity bl] Evidence: `screens/r_account_menu.png`.

> Recommendation: Fix the sentence to 'from the bottom of the sidebar' or make the top-right identity block open the same menu.
**F-019 · sev 2 · H2 · screen: r_profile** — The profile header shows raw status chips 'external', 'inactive', 'draft' with no tooltip or explanation. 'inactive' in red reads as an account-disabled warning to a researcher self-managing their own profile, but nothing on the page says what it means or how to change it. Evidence: `screens/r_profile.png`.

> Recommendation: Replace raw status codes with plain-language labels (e.g. 'Not yet an active member') and add a tooltip/help link explaining each chip and how it changes.
**F-020 · sev 2 · H4 · screen: r_outputs_import** — The 'Ciência Vitae Sync' and 'Other Data Sources' rows use the same green-tinted, wrench-icon styling as the explicit 'work in progress' hint banner seen on r_home_summary ('Outputs by year, by type and quality indicators — work in progress'), but omit the 'work in progress' label, leaving it unclear whether they are working, clickable controls or placeholders. Evidence: `screens/r_outputs_import.png`.

> Recommendation: Either make these rows functional or label them 'Work in progress' the same way the other placeholder banners in the app are labeled, so the styling means the same thing everywhere.
**F-021 · sev 2 · H5 · screen: r_add_output_dialog** — The 'Add output' dialog's Category dropdown defaults to 'All' when creating a brand-new output. 'All' is a list-filter concept, not a valid category for a single record, so a researcher who doesn't touch the field submits an output with a nonsensical category value. Evidence: `screens/r_add_output_dialog.png`.

> Recommendation: Default the Category field to a blank/placeholder state (or the most common real category) and make it required, rather than defaulting to the 'All' filter value.
**F-022 · sev 2 · H5 · screen: r_profile_edit_dialog** — 'Join date (YYYY-MM-DD)' and 'Exit date (YYYY-MM-DD)' are plain free-text fields; the required format is communicated only via placeholder text, with no date picker or input mask to prevent malformed entries. Evidence: `screens/r_profile_edit_dialog.png`.

> Recommendation: Use a date picker or masked input for the date fields instead of relying on placeholder-text instructions alone.
**F-023 · sev 2 · H6 · screen: r_profile_areas_wip** — Research Areas, Research Interests, Edit Outputs, Validation & Duplicates, Documentation, and FAQs are all listed as ordinary, clickable sidebar items indistinguishable from working sections; only after clicking does a placeholder 'Work in progress' card reveal the feature doesn't exist yet. No badge/label in the sidebar itself signals this in advance. [orchestrator: 8 of the 25 researcher sidebar leaves open the same 'Work in progress' page (Research Areas, Research Interests, Edit Scientific Outputs, Validation & Duplicate] Evidence: `screens/r_profile_areas_wip.png`.

> Recommendation: Mark not-yet-implemented sidebar items with a 'Coming soon' badge (or disable/grey them) so users don't have to click through to discover a dead end.
**F-024 · sev 2 · LAW-FITTS-1 · screen: a_person** — The 'Remove' control on a person's timeline entry is a confirmed clickable target only 40×6px (hierarchy bounds [1084,894]-[1124,900]), an order of magnitude under the 24px minimum. It sits directly beneath the 'Highlights' block with no visual button styling to compensate for the tiny hit area. Evidence: `screens/a_person.png`. Measurement: small_tap_targets: {"label":"Remove","w":40,"h":6,"assumed":false}

> Recommendation: Render 'Remove' as a proper button/icon-button with at least a 24px (ideally 44px) hit box, not a 6px text sliver.
**F-025 · sev 2 · LAW-FITTS-1 · screen: r_profile_edit_dialog** — The 'Integration year' field in the 'Edit researcher' modal is a confirmed clickable control only 528×7px (hierarchy bounds [380,795]-[908,802]), squeezed at the bottom of a 14-field unsectioned form. It is essentially a sliver compared to every other input in the same dialog. Evidence: `screens/r_profile_edit_dialog.png`. Measurement: small_tap_targets: {"label":"Integration year","w":528,"h":7,"assumed":false}

> Recommendation: Give the Integration year field the same input height/padding as its siblings (Join date, Exit date) in the same form.
**F-026 · sev 2 · LAW-HICK-1 · screen: a_people** — The People filter/action bar bundles 9 simultaneous, ungrouped controls in one row: Search box, 'Add person' button, 3 dropdowns (Membership, Status, Profile) and 3 toggle chips (Missing ORCID, Needs verification, Has outputs), plus the '184 people' count — measured as one oversized group of 10 against a limit of 9, with no visual separation between 'find' controls and the 'create' action. Evidence: `screens/a_people.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-104", "items": 10, "limit": 9}

> Recommendation: Separate the primary action ('Add person') from the filter cluster visually (e.g. right-aligned in the header, not inline with filters), and collapse the 3 toggle chips into a single 'More filters' disclosure.
**F-027 · sev 2 · LAW-HICK-2 · screen: r_profile_edit_dialog** — The 'Edit researcher' dialog presents 14 fields (Preferred name, Legal name, Bio, Photo URL, Email, Job title, Phone, ORCID, Ciencia ID, PhD, Join date, Exit date, Integration year, plus Cancel/Save) in one continuous, unsectioned, scrolling modal — flagged by measurements.json as an oversized group of 14 items against a limit of 9. There are no headings or steps to break identity fields from academic-identifier fields from employment-dates fields. Evidence: `screens/r_profile_edit_dialog.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-609", "items": 14, "limit": 9}

> Recommendation: Split into labeled sub-sections (Identity, Identifiers, Employment) within the same dialog, or turn it into a 2-3 step wizard so no single view demands scanning 14 fields at once.
**F-028 · sev 2 · LAW-MILLER-1 · screen: a_dashboard** — The admin dashboard renders 12 ungrouped KPI tiles (ORCID Linked, Profiles Validated, Outputs Approved, DOI Coverage, Researchers, Outputs, Journal Articles, Needs Verification, Missing ORCID, Labs, Projects, Clusters, Verified Outputs, Lab Allocations, Mentorships) with no category headers, immediately followed by an 8-row 'Outputs by type' breakdown and a quartile chart on the same screen. measurements.json flattens the whole panel into one oversized semantic group ({"items":90,"limit":9}), and visually the top KPI grid alone already exceeds the 7±2 ceiling with no sub-grouping (e.g. 'People' vs 'Outputs' vs 'Structure' metrics). Evidence: `screens/a_dashboard.png`. Measurement: oversized_groups: {"label": "flt-semantic-node-13", "items": 90, "limit": 9}

> Recommendation: Cluster the KPI tiles under 3-4 labeled sub-headers (People, Outputs, Structure, Reporting) of ≤9 tiles each instead of one undifferentiated grid.
**F-029 · sev 2 · NAV-4 · screen: a_admin_review** — a_admin_review.png (Pending approval) adds a secondary row of 7 top tabs — Profiles to approve, Outputs to approve, Needs re-verification, Suggestions, Activity, Needs attention, ORCID works — layered on top of the single left-sidebar entry "Pending approval". No other screen in the inventory combines the sidebar with a secondary flat tab bar, and 7 tabs in one row exceeds the ~5 that a single flat tab row can hold without strain, so this screen's navigation depth/pattern is inconsistent with the rest of the app. Evidence: `screens/a_admin_review.png`. Measurement: 7 tabs in one row, unique to this screen

> Recommendation: Either split the 7 sub-views into their own sidebar leaves (consistent with the rest of the IA) or reduce/group the tabs (e.g. a dropdown for the 3 least-used) so no single tab row exceeds ~5 items.
**F-030 · sev 2 · ST-EMPTY · screen: r_outputs_import** — Import & Synchronisation shows an 'ORCID Sync' heading with only 'My ORCID publications · 0 / Nothing new' beneath it for a researcher with no ORCID iD on file, and no explanation that nothing can sync until an iD is registered, nor a link to Researcher Identifiers. DB: 158 of 184 people have no ORCID, so this is the majority case. Evidence: `screens/r_outputs_import.png`. Measurement: SQL: 26/184 people with orcid; 1 466 candidates pending for the 26 who have one (max 281 for one person)

> Recommendation: Branch the empty state: no iD → explain and link to Identifiers; iD but nothing staged → say when the weekly sync last ran and offer a manual sync.
**F-031 · sev 2 · ST-LOAD · screen: state_error_backend_down** — With the backend unreachable, /people shows the toolbar and a single pulsing dot for the full 20 s TimeoutClient window (screens/state_error_backend_down.png at 3 s) with no skeleton, no 'still loading' text and no cancel; only after the timeout does the classified error appear: "Can't reach UNIDCOM. Check your connection and try again" with Retry (screens/state_error_backend_down_26s.png). Same on /app/dashboard (state_error_dashboard_down_26s.png). The error state itself is good; the 20 s of silence before it is the finding. Evidence: `screens/state_error_backend_down.png`. Measurement: TimeoutClient timeout = 20 s (lib/data/timeout_client.dart:10)

> Recommendation: Show a skeleton or 'Still loading… (slow connection)' hint after ~3 s and a cancel/retry after ~8 s; consider a shorter timeout for list reads.
**F-032 · sev 2 · ST-LOAD · screen: state_loading_cold** — Cold-start screenshot taken at +250ms is fully blank white with zero content; hierarchy/state_loading_cold.json returns only {"bounds":"[0,0][0,0]","text":"NO SEMANTICS HOST"} — no splash, no spinner, no branding is rendered while the Flutter engine boots. No other cold-start frame exists in the evidence set showing any loading indicator between this blank frame and the first painted screen (login), so there is no designed loading state for app boot, only an unindicated wait. [also H1 on state_loading_cold: At +250ms into a cold load, the screen is entirely blank white — no spinner, logo, or skeleton UI is visible to indicate the app is starting up.] Evidence: `screens/state_loading_cold.png`. Measurement: capture at +250ms, 0 semantic nodes

> Recommendation: Ship a static HTML/CSS splash (logo or spinner) shown before the Flutter engine attaches, so cold load never presents a blank white frame.
**F-033 · sev 2 · VD-COL-2 · screen: a_dashboard** — The 12 KPI tiles are one repeated component (label + big number + colored top border) but use three different accent colors — teal, blue, and red — without a visible rule: plain counts are teal for some tiles (Outputs, Researchers, Verified Outputs) but blue for structurally identical plain counts on other tiles (Projects, Clusters, Journal Articles, Lab Allocations). Red is reserved for the two genuinely problematic metrics (Needs Verification 181, Missing ORCID 158), which is correct, but the teal/blue split among the rest reads as arbitrary categorical decoration rather than meaning. Evidence: `screens/a_dashboard.png`.

> Recommendation: Pick one neutral accent (teal) for all plain-count tiles and reserve blue/red for tiles that carry an actual status (attention-needed, informational grouping, etc.), so the same visual treatment always maps to the same meaning.
**F-034 · sev 2 · VD-COL-2 · screen: r_home** — The 'OUTPUTS' and 'PROFILE STATUS' stat cards share one continuous amber/warn-colored top border. 'Profile Status: draft' is legitimately a warning state, but 'Outputs: 0' is a neutral count with no problem — yet it gets the same warning-amber accent, borrowing meaning it doesn't have. The identical mis-pairing appears again on r_home_summary and r_settings (same widget, same amber bar spanning both cards). Evidence: `screens/r_home.png`.

> Recommendation: Apply the amber/warn accent only to the card(s) whose state actually needs attention (Profile Status here); give the neutral Outputs count a neutral/no accent so the warning color keeps a single meaning across the app.
**F-035 · sev 2 · VD-GES-1 · screen: r_home** — The sidebar footer (avatar, 'Switch to admin', 'Public site', 'Sign out') is painted over the scrolling nav list with no separator: 'Add Scientific Output' is cut off behind the footer at 1280×900 in every researcher screenshot, and the 5 rows below it are unreachable until the user discovers the list scrolls. [also LAW-FITTS-1 on phone_r_drawer: Rows near the bottom of the drawer report 280×15 px ('My Outputs', bounds [0,688][280,703]) and 280×5 px ('Affiliation Guidelines') because the drawer footer (avatar + Switch/Public site/Sign out) is ] [also VD-RESP-1 on phone_r_drawer: In the mobile navigation drawer, after the 'SCIENTIFIC OUTPUTS' section header the expected items ('My Outputs', 'Add Scientific Output') are missing; in their place is a single thin teal horizontal l] Evidence: `screens/r_add_output_dialog.png`. Measurement: hierarchy/phone_r_drawer.json: list rows extend past the 844 px viewport; desktop list clipped at y≈760 by the footer

> Recommendation: Give the footer a top border and background, and add bottom padding to the ListView equal to the footer height; or pin the footer below the list instead of over it.
**F-036 · sev 2 · VD-RESP-1 · screen: a_admin_reports** — In the Scientific Outputs report table, the 'Type' column's long category labels (e.g. 'Valorizações de atividades ou outros outputs no âmbito de projetos c…') are cut off exactly at the 1280px viewport edge with no horizontal scrollbar, fade, or other affordance indicating more content exists off-screen. Evidence: `screens/a_admin_reports.png`.

> Recommendation: Wrap the table in its own horizontal-scroll container (with a visible scrollbar or edge shadow) or truncate long Type values with an ellipsis and full text on hover/tap, instead of letting them run off the viewport unindicated.
**F-037 · sev 2 · VD-RESP-1 · screen: phone_a_review** — The 'Pending approval' section tab bar ('Profiles to approve', 'Outputs to approve', …) overflows the 390px viewport — only a sliver of a letter from the next tab is visible at the right edge, with no scroll affordance (arrow, fade, or dots) hinting that additional tabs (Needs re-verification, Suggestions, Activity, Needs attention, ORCID works) exist off-screen. [also LAW-FITTS-1 on phone_a_review: The 'Pending approval' tab bar on the 390px viewport can't fit its tabs: 'Needs re-verification' is a confirmed clickable target only 19px wide (h=48, so width is the failure) and a further tab is vis] Evidence: `screens/phone_a_review.png`.

> Recommendation: Give the tab bar a visible scroll cue on phone widths (edge fade/gradient, partial next-tab peek with clear spacing, or a collapsed 'more' menu) so users know there are more tabs than fit on screen.

### Severity 1 — cosmetic

**F-038 · sev 1 · DS-BTN-1 · screen: r_outputs** — The same 'add an output' action appears twice on this screen in two different button variants: the top-right 'Add output' is a filled navy primary button (matches template .btn-primary), while 'Timeline · 0' has its own '+ Add' rendered as a plain blue text link (tertiary/ghost style) directly below it. Evidence: `screens/r_outputs.png`.

> Recommendation: Pick one variant for the add-output affordance per screen region — if the Timeline's '+ Add' is meant to be secondary, use the outline button style already defined in the theme rather than a bare text link, so it isn't confused with a different action tier from the primary 'Add output' button above it.
**F-039 · sev 1 · DS-FORM-1 · screen: r_add_output_dialog** — Both app dialogs (r_add_output_dialog and r_profile_edit_dialog) render every field with the label floating inside the empty input box (Material 'filled/outlined' label-as-placeholder pattern) rather than Carmela's template form, whose .field label sits as static 11.5px muted text above each input (unidcom-researcher.html .field/.field label rules, used in the New Request form). The app is internally consistent between its own two dialogs, but both diverge from the only form pattern the template actually specifies. Evidence: `screens/r_add_output_dialog.png`.

> Recommendation: If the Material floating-label style is the intended direction going forward, note it as a deliberate deviation from the Figma form pattern; otherwise move labels above the fields to match the template's .field/label convention before any more admin/researcher forms are built.
**F-040 · sev 1 · DS-ICON-1 · screen: r_profile** — On the same detail header row, the 'Edit' button uses Icons.edit (default/filled glyph, lib/widgets/detail_scaffold.dart line 422) directly beside the 'Connect ORCID' button which uses Icons.badge_outlined (lib/app/my_profile.dart line 482) — a filled-style icon and an outlined-style icon side by side in the same button row. A broader grep of lib/ confirms this isn't isolated: filled icons (Icons.star, Icons.close, Icons.check, Icons.event, Icons.merge, Icons.sync, Icons.construction, Icons.error, Icons.download...) and _outlined icons (Icons.info_outline, Icons.people_outline, Icons.verified_outlined, Icons.check_circle_outline, Icons.mail_outline...) are mixed throughout with no consistent rule for which family a given control gets. The same clash (Edit filled + Connect ORCID/identifier outlined icons) is visible again on a_person. Evidence: `screens/r_profile.png`.

> Recommendation: Standardise on one Material Icons style (the sidebar already commits to _outlined) and swap the filled variants (Icons.edit -> Icons.edit_outlined, Icons.star -> Icons.star_outline where not a toggle state, etc.) so stroke weight is uniform across a given screen.
**F-041 · sev 1 · H4 · screen: r_outputs** — Two different labels are used for the same 'add an output' action on the same screen: the top-right button says 'Add output' while the inline control next to the Timeline heading says just 'Add'. Evidence: `screens/r_outputs.png`.

> Recommendation: Use one consistent label ('Add output') for both entry points to the same action.
**F-042 · sev 1 · ST-EMPTY · screen: state_empty_people_search** — Five-state coverage sampled across data screens: | Screen | ST-IDLE | ST-LOAD | ST-SUCCESS | ST-ERROR | ST-EMPTY | |---|---|---|---|---|---| | People search | present | n/a | present | n/a | present (weak) | | People (backend down) | n/a | present (unbounded) | n/a | MISSING | n/a | | Dashboard (backend down) | n/a | present (unbounded) | n/a | MISSING | n/a | | Cold boot | n/a | MISSING | n/a | n/a | n/a | | My Outputs after add | n/a | n/a | MISSING (no status) | n/a | n/a |. state_empty_people_search.png itself does the empty state reasonably well ("No people found", filters and search term still visible so the cause is inferable), but offers no explicit next step (e.g. a "Clear search" action) beyond editing the search box by hand. Evidence: `screens/state_empty_people_search.png`. Measurement: 0 people / 0 next-step affordance besides editing the search field

> Recommendation: Add a "Clear filters/search" button to the empty result state so the next step is explicit rather than implicit.
**F-043 · sev 1 · VD-TYPE-1 · screen: a_admin_data** — The 'people' table in the raw Data Browser renders full-sentence bio paragraphs (a full bio paragraph) as regular table-cell text at roughly 12-13px — below the 16px floor for text a person is expected to actually read, not just scan as a short label. Evidence: `screens/a_admin_data.png`.

> Recommendation: For long free-text columns (bio, notes) either truncate with an expand-on-click affordance shown at readable size, or bump the cell font size for these specific columns rather than reusing the compact ID/date-column size.

## Comparison with RIMS best practice (BP-01…38)

Scored against the checklist in `docs/research/2026-09-rims-best-practices.md`. Evidence is a screen file, a code pointer, a migration or a SQL result from the production database on 2026-09-09. Score: **51 / 100** (9 yes · 21 partial · 8 no).

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
| BP-13 | no | rejectOutput(id) takes no reason; the row simply disappears (flow review_queue). | Researcher never learns why. |
| BP-14 | no | output_status holds 'Planeado' (6) / 'Concluído' (46) / null (313) and is not consulted by approval. |  |
| BP-15 | yes | change_log(subject_type, subject_id, field, old_value, new_value, source, actor, changed_at): 605 rows, 365 output approvals, 186 profile transitions | Non-admin edits are not logged (cl_write is admin-only; AUDIT.md). |
| BP-16 | partial | DOI duplicate is caught by the unique index and surfaced as 'That DOI already belongs to another output' on the detail page; title_norm exists but no similarity check at entry — 8 title_norm groups are duplicated in the live table. | Title-similarity warning before save. |
| BP-17 | partial | Outputs list has an Issues filter and the detail page offers Merge duplicates when a cluster ≥ 2; the review queue row itself shows no duplicate badge (screens/flow_review_queue_3_FAIL.png). |  |
| BP-18 | yes | merge_people RPC + mergeOutputs, merge matrix UI (screens/a_admin_merge.png); reassigns output_authors/project_members |  |
| BP-19 | partial | Client-side: Title required, data retained, inline error (flow_add_output_2_validation.png). Server: create_my_output whitelists the payload and forces status/source/affiliation. | Other fields unvalidated (year accepts any text until save). |
| BP-20 | no | Single inline error only; no summary, no focus management. |  |
| BP-21 | no | My Outputs timeline shows the new pending output with no status tag (flow_add_output_4_in_my_outputs.png) although output_row.dart has a pending pill used elsewhere. | Researcher cannot tell approved from pending in their own list. |
| BP-22 | partial | Overview → Alerts card: 'Your profile is awaiting confirmation' with link (screens/r_home.png). No alert for missing ORCID/CIÊNCIA ID, unclaimed candidates or drafts. |  |
| BP-23 | no | Dialog → Save; no review step. |  |
| BP-24 | partial | Admin Reports uses DataTable (Title, Year, Type, Subtype, Authors, DOI/URL) with no onSort; Data browser renders 4 856 semantics nodes on one screen (measurements.json a_admin_data). | Sorting and pagination. |
| BP-25 | partial | Outputs: Category cascade + Approval + Issues dropdowns (screens/a_outputs.png); Reports: Year. No person filter, no filter chips, no one-click clear. |  |
| BP-26 | partial | Flutter SnackBar (used for 'Approved N pending outputs', 'Profile linked') is a live region; two error banners declare liveRegion in main.dart. Reject gives no message at all. |  |
| BP-27 | no | Desktop sidebar has no accessibility nodes (F-001); Reject is a 42×20 px text link; star icon 24 px. | Keyboard users cannot navigate on desktop. |
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

## Design criticism — what was built vs what was designed vs what the research says

**Against Carmela's templates.** The tokens are faithful (navy sidebar, sand page, teal accent, 10 px radius) and the 2026-08-07 palette correction kept the brand teal while moving load-bearing text to the darker teal — the right call. Divergence is in the components, not the colours: the template's row pills and status tags are replaced by raw enum strings in several places (`draft`, `pending_review`, `a_confirmar` — F-016, F-012, F-019); the template's icon system is mixed with emoji in the Welcome pack (F-014); the dashboard tiles use three accent colours where the template uses one (F-037); and the 404 page drops the shell entirely (F-006).

**Against the research.** Two deliberate decisions carry a usability bill that this audit prices: (1) the one-to-one sidebar (8 Sep) puts 25 rows in the researcher's primary navigation, a third of them placeholders, and the whole thing lives in a scrolling column whose lower half is under a footer (F-007, F-023, F-035) — Miller and Hick both argue for the six section headers as the visible menu and leaves on the landing pages; (2) the v1/v2 split (10 Aug, Rui: 'fewer controls, all of them working') removed Find DOI from the researcher path, so the one control every surveyed system leads with is behind the flag (BP-07). Both are documented choices, not drift — the recommendation is to revisit them with these numbers rather than to undo them silently.

**Drift rather than decision:** the desktop sidebar losing its semantics (F-001), the person page not re-fetching on id change (F-002), the highlight following the wrong row (F-008), the Maestro suite asserting text that no longer exists (F-015), and Reject without confirm or feedback (F-005). None of these was chosen; each is a regression or an omission a test would have caught.

**The public site** (Hugo) is the stronger surface: fail-closed allowlists, ORCID links per person, nightly sync green for the last five days, 76 publications and 183 people published from the same rows the portal manages. Its open items are content (bios in Portuguese under `lang="en"`, photos) rather than UX.

## Recommendations

Ordered by severity, then by cost. The first four are a day's work together.

1. **F-001 sidebar semantics** — reproduce with the E2E build, fix the desktop branch, and pin it with a widget test that asserts the SideNav rows exist in the semantics tree at 1280 px.
2. **F-002 person page refetch** — `ValueKey(id)` on the page in the route builder (one line) or `didUpdateWidget`; add a test that navigates A→B.
3. **F-005 Reject** — confirm + optional reason + snackbar with Undo; store the reason on the output so the researcher sees it (closes BP-13).
4. **F-009 status tag in My Outputs** — reuse the pill from `lib/widgets/output_row.dart` in the timeline row (closes BP-21).
5. **F-008 highlight** — longest-prefix match in `navSelected()`.
6. **F-007 / F-023 / F-035 sidebar** — show section headers only by default, mark WIP rows, fix the footer overlap. Revisit with Rui with the Miller/Hick numbers.
7. **F-003 / F-004** — make the anonymous Welcome pack consistent (same sidebar signed in or out; M2 slugs redirect instead of a login wall).
8. **F-006** — friendly 404 inside the shell, no exception text.
9. **F-010 / F-037 / F-036** — phone: wrap KPI tiles, scrollable tab strip, truncate the Type column.
10. **F-015** — fix the six Maestro YAMLs and run them in CI, or adopt `audit/tools/flows.py` as the suite.
11. **BP-07** — DOI-first Add output for researchers (the Crossref client exists); **BP-16** title-similarity warning; **BP-36** add CIÊNCIA ID coverage and unclaimed-candidate counts to the dashboard.
12. **HEART instrumentation** — the five events above; report them in the pilot demo.

Design-system debt worth batching: enum-to-label helper used everywhere a status is shown (F-012, F-016, F-019), one icon family (F-013, F-014, F-040), one accent on KPI tiles (F-033, F-034), consistent button variant for the same action (F-038, F-041).

## Appendix

### A. Screen inventory
See `screens.md` ({M['screens_audited']} crawled screens + 21 flow-step screenshots + 4 verification screenshots). Files: `screens/<name>.png`, `hierarchy/<name>.json` — **kept out of git** (they contain researcher emails from the admin data browser); they exist only on the audit machine, alongside `measurements.json`.

### B. Flow results

| Flow | Passed | Steps | Duration (s) | Source | Note |
|---|---|---|---|---|---|
| auth_gate | yes | 6 | 6.0 | .maestro/auth_gate.yaml |  |
| researcher_mode | yes | 9 | 17.6 | .maestro/researcher_mode.yaml |  |
| admin_mode | yes | 8 | 6.6 | .maestro/admin_mode.yaml |  |
| orcid_error | yes | 3 | 3.4 | .maestro/orcid_error.yaml |  |
| profile_confirm | yes | 8 | 3.4 | (new) profile_confirm — researcher confirms draft profile |  |
| add_output | yes | 11 | 12.6 | (new) add_output — researcher records an output manually | no status tag on the new pending output in My Outputs (finding, not a task failure) |
| review_queue | yes | 10 | 13.7 | (new) review_queue — admin sees, confirms-all, rejects | no feedback after Reject (finding) |
| featured_star | NOT RUN | 0 | 0 | .maestro/featured_star.yaml | NOT RUN: the E2E account has 0 outputs to star |
| support_request | NOT RUN | 0 | 0 | .maestro/support_request.yaml | NOT RUN: v2-only route, compiled out of the pilot build |

### C. Verification of subagent claims
Six claims at severity ≥ 3 were re-tested by the orchestrator before inclusion: two "no error state" claims (backend down) — the classified error appears after the 20 s client timeout, recorded instead as F-035 (silent spinner); one "wrong person shown" claim — confirmed and promoted (F-002); one "account menu does nothing" claim — there is no menu, the copy points to the wrong place (F-018); two tap-target claims (drawer rows 15 px / 5 px, a 6 px row on conferences) — clipped-viewport artefacts, folded into F-035 or dropped.

### D. measurements.json summary
713 tap targets under 24 px (most `assumed`, i.e. labelled leaves without an explicit clickable flag), 226 groups over 9 items, 52 alignment near-misses across 81 hierarchies. Contrast estimates were used only for leaf text.

### E. Reproduce
`audit/tools/README.md`. Cleanup SQL for the two DB-writing flows is in `screens.md`.

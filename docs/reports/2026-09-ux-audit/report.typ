// UNIDCOM RIMS — UX/UI Audit, September 2026.
// Build: ./build.sh   (typst --root ../../.. so the audit screenshots can be embedded)
//
// Every figure here is read from audit/2026-09-09-1136/{findings,flows-results,bp-scorecard}.json
// or from the production database on 2026-09-09. The Markdown report with all 43 findings
// is audit/2026-09-09-1136/report.md; the cited research is docs/research/2026-09-rims-best-practices.md.
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — UX/UI Audit",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · UX/UI audit · September 2026",
  lang: "en",
))

#title-block(
  "UNIDCOM RIMS",
  subtitle: "UX/UI Audit — researcher portal, 9 September 2026 (with same-day re-run)",
  meta-line: [Portal build 73259d4 (round 4, 8 Sep) · v1 pilot feature set · 86 screens, 7 flows · Prepared 9 September 2026],
  standfirst: [The pilot's core loop works end to end — every journey that could be run
  passed. Two defects still block onboarding: the desktop navigation is invisible to
  keyboard and screen-reader users, and a person page can show, and let an admin edit,
  the wrong researcher. Neither is a design choice; both are a day's fix with a test.],
)

#block(above: 10pt, below: 8pt)[*Release verdict:* #pill("NOT READY", tone: "bad") at the first run — 2 blockers and 9 high-priority findings; #pill("READY WITH FIXES", tone: "warn") after the same-day fix round and re-run (§7). Sections 1–6 record the first run as found; §7 records what changed.]

#kpi-row((
  ("43", "Findings", "2 sev-4 · 9 sev-3 · 26 sev-2 · 6 sev-1"),
  ("100 %", "Task success", "7 of 7 runnable flows passed"),
  ("51 → 57", "Best-practice score", "first run → re-run, of 38 items"),
))

#callout(title: "The decision needed from you", tone: "warn")[
  Two deliberate August–September decisions carry a measurable usability bill:
  the one-to-one sidebar (25 rows, a third of them "Work in progress") and the v1/v2
  split that put DOI lookup behind the flag. Both are documented choices, not drift.
  This report prices them (§4, §5); revisiting them is a product call, not an engineering one.
]

= 1. What was audited, and how

The Flutter web portal at #link("https://berlogabob.github.io/Unidcom-IADE/")[berlogabob.github.io/Unidcom-IADE],
built from commit 73259d4 with the semantics tree on, in the three modes a
user can be in — anonymous visitor, researcher, administrator — at desktop
(1280 × 900) and phone (390 × 844) widths.

#data-table(
  ("What", "Source", "Count"),
  (
    ([Screens captured (screenshot + accessibility tree each)], [`audit/2026-09-09-1136/screens.md`], [86]),
    ([User journeys run end to end], [`flows-results.json` — 2 not runnable: star an output (test account owns none), support requests (v2 only)], [7 of 9]),
    ([Provoked system states], [cold start, wrong password, empty search, backend down at 3 s and 26 s], [5]),
    ([Review dimensions], [Nielsen heuristics, UX laws, visual design, design system vs Figma, flows & states — plus orchestrator-verified findings], [5 + 1]),
    ([Best-practice checklist items scored], [`docs/research/2026-09-rims-best-practices.md`, BP-01…38, each with a click-through or SQL test], [38]),
    ([Severity ≥ 3 claims re-tested before inclusion], [2 corrected, 1 confirmed and promoted, 3 folded or dropped], [6]),
  ),
  widths: (5.2cm, 1fr, 1.6cm), right-from: 2,
)

#text(size: 8.5pt, fill: muted)[Maestro, the repo's E2E tool, could not drive Chromium on
the audit machine (three attempts, driver never returned). The same journeys were
run with Playwright; the scripts are committed under `audit/tools/` so the run is
repeatable. The committed Maestro suite itself asserts text the build no longer
shows (finding F-015).]

= 2. The two blockers

#data-table(
  ("Finding", "Status", "Evidence and cause"),
  (
    ([*F-001* · Desktop navigation absent from the accessibility tree], [#pill("Blocker", tone: "bad")], [At ≥ 900 px none of the 25 sidebar rows, the mode switch or Sign out exists for assistive technology: 17 semantics nodes on the home page, 0 of them navigation. Verified after hover, keyboard focus, scroll, resize and reload. The phone drawer exposes every row correctly, so the defect is in the desktop layout branch.]),
    ([*F-002* · Person page keeps the previous researcher when only the id changes], [#pill("Blocker", tone: "bad")], [Two person URLs rendered byte-identical pages; after a hard reload the right person showed, and changing the id again kept the old one. Root cause: the page fetches once in `initState` and never on id change (`lib/public/person_page.dart:71`). An admin following a person-to-person link can edit the wrong record.]),
  ),
  widths: (4.6cm, 1.9cm, 1fr), right-from: 99,
)

Both have a one-line fix and a one-test guard. Neither was visible to the existing
tests, because no test renders the desktop shell at width or navigates person → person.

= 3. What a researcher will actually feel

Nine high-priority findings, in the order a researcher meets them.

#data-table(
  ("ID", "Where", "What happens", "Fix"),
  (
    ([F-007], [Sidebar], [25 rows in 6 groups; at 1280 × 900 only 11 fit before the fold, so _Scientific Outputs_ is below it], [Headers only by default; leaves on landing pages]),
    ([F-008], [Sidebar], [The highlighted row is the wrong one on 6 of 25 pages (prefix match wins over exact)], [Longest-match in `navSelected()`]),
    ([F-009], [My Outputs], [A newly added output shows no _pending_ tag — the researcher cannot tell what is approved], [Reuse the existing status pill]),
    ([F-005], [Review queue], [Reject fires with no confirmation, no reason, no feedback; Approve-all does confirm], [Confirm + reason + Undo]),
    ([F-003], [Welcome pack], [An anonymous visitor opening an M2 section hits a login wall instead of the promised redirect], [Redirect to Getting started]),
    ([F-004], [Welcome pack], [Signed-in and anonymous visitors get two different sidebars for the same page], [One sidebar]),
    ([F-006], [404 page], [Shows `GoException: no routes for location…` and drops the app shell], [Friendly page inside the shell]),
    ([F-010], [Phone dashboard], [KPI tiles clip at 390 px — key numbers unreadable], [Wrap tiles]),
    ([F-011], [Logos page], [Brand-colour swatch labels are illegible on their own swatch], [Label outside the swatch]),
  ),
  widths: (1.5cm, 2.4cm, 1fr, 3.6cm), right-from: 99,
)

The remaining 32 findings (severity 2 and 1) are in `report.md`; the largest
clusters are raw status enums shown to users (`draft`, `pending_review`,
`a_confirmar`), mixed icon families including emoji, three accent colours on one
KPI component, and a 20-second silent spinner before the (good) error message
when the backend is unreachable.

= 4. Against best practice

The 38-item checklist distils what Pure, Converis, Elements, DSpace-CRIS and Haplo
document, what CERIF, OpenAIRE and ORCID require, what FCT and CIÊNCIAVITAE ask of a
unit, and the WCAG 2.2, GOV.UK and USWDS pattern rules that apply to forms and
tables. Each item was tested by click-through or SQL on 9 September.

#bar-row("Met (9)", "24 %", 0.24, tone: "ok")
#bar-row("Partly met (21)", "55 %", 0.55, tone: "warn")
#bar-row("Not met (8)", "21 %", 0.21, tone: "bad")

#v(4pt)
*Ahead of the field for its size.* The data model — authorship as link rows
with role and order, a unique DOI index, a full audit trail of 605 status
changes — the approval gate that feeds a nightly, fail-closed public build
(76 publications and 183 people on the site, matching the database), ORCID
harvesting into a staging table for 26 researchers, and a real merge tool.
Small units usually skip exactly these.

*Behind every system surveyed.* The entry experience:

#data-table(
  ("Best practice", "Status", "What we have"),
  (
    ([*BP-07* · Add output starts from a DOI/ORCID lookup], [#pill("Not met", tone: "bad")], [A blank six-field dialog; the Crossref client exists but sits behind the v2 flag, admin-only]),
    ([*BP-13* · Returned items carry a reviewer comment], [#pill("Not met", tone: "bad")], [Reject takes no reason; the item simply disappears from the researcher's list]),
    ([*BP-21* · Own list shows the workflow state as a text tag], [#pill("Not met", tone: "bad")], [No tag in My Outputs, although the pill component exists]),
    ([*BP-27* · Keyboard reach and 24 px targets], [#pill("Not met", tone: "bad")], [F-001; Reject is a 42 × 20 px text link]),
    ([*BP-16* · Duplicate check at entry (DOI, then ≈ 80 % title)], [#pill("Partly", tone: "warn")], [DOI is caught by the unique index; 8 duplicated normalised titles sit in the live table]),
    ([*BP-11/12* · Draft → submitted → validated, with withdraw], [#pill("Partly", tone: "warn")], [Outputs have no draft; a researcher's save is an immediate submission with no way back]),
    ([*BP-34/36* · FCT team export and data-quality counts], [#pill("Partly", tone: "warn")], [0 outputs flagged as representative; 1 466 unclaimed ORCID candidates not surfaced; CIÊNCIA ID coverage (25 of 184) not on the dashboard]),
  ),
  widths: (5.2cm, 1.9cm, 1fr), right-from: 99,
)

= 5. Design criticism — built vs designed vs researched

*Against the designer's templates.* The tokens are faithful: navy sidebar, sand
page, teal accent, 10 px radius, and the August contrast fix kept the brand teal
while moving load-bearing text to the darker teal. The divergence is in
components: template pills replaced by raw enum strings in five places, the
template's icon set mixed with emoji in the Welcome pack, one KPI component in
three accent colours, and a 404 page that drops the shell.

*Against the research.* Miller and Hick both argue for the six section headers
as the visible menu, with leaves on the section landing pages — the model already
has those pages. FCT's own guidance makes CIÊNCIA ID coverage and the five
representative outputs the unit-level facts that matter; neither is on the
dashboard. ORCID's display rules ask for the iD icon and the full URL; the
profile shows a generic badge.

*Drift, not decision.* The sidebar semantics, the person-page refetch, the
highlight logic, the stale Maestro suite and Reject-without-confirm were not
chosen; each is a regression or omission that a test would have caught. That
is the engineering message of this audit: the pilot needs a shell-width widget
test and a navigate-A-to-B test more than it needs new features.

*The public site* is the stronger surface — fail-closed allowlists, ORCID links,
sync green every night this week. Its open items are content (Portuguese bios
under an English page, photos), not UX.

= 6. Recommended order of work

+ *F-001, F-002* — one day: fix both, pin each with a widget test.
+ *F-005, F-009, F-008* — one day: Reject confirm + reason + Undo; status pill in My Outputs; longest-match highlight.
+ *Sidebar* (F-007, F-023, F-035) — product decision with Rui, then half a day: headers-only default, mark WIP rows, fix the footer overlap.
+ *Welcome pack and 404* (F-003, F-004, F-006) — half a day.
+ *Phone* (F-010, F-036, F-037) — half a day.
+ *Regression suite* (F-015) — fix the six Maestro YAMLs and run them in CI, or adopt `audit/tools/flows.py`.
+ *BP-07 DOI-first entry, BP-16 title warning, BP-36 dashboard counts* — two days, the highest-value feature work before the demo.
+ *HEART instrumentation* — five events (`mode_chosen`, `profile_confirmed`, `output_added`, `candidate_claimed`, `review_decision`); three already exist in `change_log`.

= 7. Re-run after the fixes — same day

Round 5 fixed the two blockers and nine high-priority findings in ten
pull requests (#32–#39 plus two follow-ups), each pinned by a widget test;
the test suite went from 165 to 183. The audit tooling was then run again
on the merged build (`audit/2026-09-09-1601`), same 86 screens, same seven
flows, same five review passes, with the trend computed by (criterion, screen).

#kpi-row((
  ("0", "Blockers", "was 2"),
  ("61", "Severity-weighted score", "was 93 · target ≤ 60"),
  ("16 / 7 / 0", "Fixed / new / regressed", "27 persisting, mostly by decision"),
  ("57 / 100", "Best-practice score", "was 51 · BP-21 met, BP-13/27 partly"),
))

#data-table(
  ("Metric", "First run", "Re-run"),
  (
    ([Findings by severity 4 / 3 / 2 / 1], [2 / 9 / 26 / 6], [0 / 1 / 25 / 8]),
    ([Task success rate], [100 %], [100 %]),
    ([Mean steps per flow], [7.9], [8.1]),
    ([Defect density], [0.50 per screen], [0.41 per screen]),
    ([Automated tests], [165], [183]),
  ),
  widths: (1fr, 3cm, 3cm), right-from: 1,
)

#v(4pt)
*Verified fixed on the live build:* desktop sidebar exposed to assistive
technology (42 semantics nodes on the researcher home, was 17); person page
switches record on id change; anonymous M2 slug redirects; branded 404;
correct sidebar highlight; status pill in My Outputs; Reject with
confirmation, reason, Undo and the reason shown to the researcher; phone
dashboard, review tabs and report table; logo labels; humanised status
labels; chooser copy; sidebar footer; Maestro assertions.

*Found by the re-run and fixed the same afternoon:* the queue row printed
"pending" twice after the pill change; the new 404 page rendered blank
because it was wrapped in the app shell outside the router. Both now have
tests — the argument for keeping this crawl in the routine.

*Remaining severity 3 (one):* the 25-row researcher sidebar (Miller/Hick),
a product decision for Rui. The seven new findings are all severity 2 or 1:
raw status chips on the researcher's own profile header, three feedback
patterns for one message type, the thin Personal Information page left by
the E4 split, the v2 admin route landing on a queue instead of redirecting,
cluster codes without expansion, and small alignment offsets.

#callout(title: "Release verdict after the re-run", tone: "info")[
  #pill("READY WITH FIXES", tone: "warn") — no blocker open; the one
  high-priority item is a design decision, not a defect. The pilot cohort can
  be onboarded on this build.
]

= 8. Measurements for the next run

#data-table(
  ("Metric", "How measured", "9 Sep 2026"),
  (
    ([Task success rate], [7 runnable flows, all passed, 0 errors, 2 warnings], [100 %]),
    ([Mean steps per flow], [tap/input count per journey], [7.9]),
    ([Findings by severity 4 / 3 / 2 / 1], [`findings.json`], [2 / 9 / 26 / 6]),
    ([Severity-weighted score (Σ severity)], [the number to drive down], [93]),
    ([Defect density], [43 findings / 86 screens], [0.50 per screen]),
    ([Best-practice score], [yes = 1, partial = ½, over 38 items], [51 / 100]),
    ([Researchers who can sign in], [`people.orcid` filled — the adoption ceiling], [26 of 184]),
    ([Unclaimed ORCID candidates], [`output_candidates.status = 'pending'`], [1 466]),
  ),
  widths: (5.2cm, 1fr, 2.8cm), right-from: 2,
)

#text(size: 8.5pt, fill: muted)[Trend comparison is by (criterion, screen) pair between
`findings.json` files; §7 is the first such comparison. Rerun:
`audit/tools/README.md`. Screenshots and accessibility trees are kept out of git —
they contain researcher emails from the admin data browser — and live only in the
audit machine's `audit/2026-09-09-1136/screens` and `hierarchy` folders.]

#v(6pt)
#figure(
  image("/audit/2026-09-09-1136/screens/r_home.png", width: 100%),
  caption: [Researcher home at 1280 × 900. The sidebar shown here has no accessibility nodes (F-001); "Add Scientific Output" is cut off behind the footer (F-035); the status tile shows the raw value `draft` (F-016).],
)

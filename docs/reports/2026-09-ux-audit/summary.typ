// UNIDCOM RIMS — UX/UI audit, compact summary. Numbers from
// audit/2026-09-09-1136 (first run) and audit/2026-09-09-1601 (re-run after fixes).
// Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — UX/UI Audit Summary",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · UX/UI audit summary · 9 September 2026",
  lang: "en",
))

#title-block(
  "UX/UI audit — researcher portal",
  subtitle: "First run, fix round, re-run. All on 9 September 2026.",
  meta-line: [86 screens · 7 journeys · 5 review passes · 38-item best-practice checklist · first run on 73259d4, re-run on daaf308],
  standfirst: [Morning: #pill("NOT READY", tone: "bad") — two blockers. Afternoon: ten fixes merged, re-audited, #pill("READY WITH FIXES", tone: "warn"). No blocker open. The one high-priority item left is a design decision, not a defect.],
)

#kpi-row((
  ("2 → 0", "Blockers", "sidebar semantics · person page"),
  ("93 → 61", "Severity-weighted score", "target ≤ 60"),
  ("43 → 34", "Findings", "16 fixed · 7 new · 0 regressed"),
  ("51 → 57", "Best practice / 100", "38 items, click-through or SQL"),
))

= Before and after

#data-table(
  ("Metric", "First run", "Re-run", "How measured"),
  (
    ([Findings sev 4 / 3 / 2 / 1], [2 / 9 / 26 / 6], [0 / 1 / 25 / 8], [five review passes, deduplicated, every finding tied to a screenshot]),
    ([Task success rate], [100 %], [100 %], [7 of 7 runnable journeys, 0 errors]),
    ([Mean steps per journey], [7.9], [8.1], [tap/input count]),
    ([Defect density], [0.50], [0.41], [findings per screen]),
    ([Automated tests], [165], [183], [`flutter test`]),
    ([Researchers who can sign in], [26 / 184], [26 / 184], [`people.orcid` filled — unchanged, the adoption ceiling]),
  ),
  widths: (4.2cm, 2cm, 2cm, 1fr), right-from: 99,
)

= The eleven high-priority findings

#data-table(
  ("ID", "Finding", "Status"),
  (
    ([F-001], [Desktop sidebar absent from the accessibility tree], [#pill("fixed", tone: "ok") PR 34 + test]),
    ([F-002], [Person page keeps the previous researcher when only the id changes], [#pill("fixed", tone: "ok") PR 36 + test]),
    ([F-003], [Anonymous M2 welcome slug lands on the login wall], [#pill("fixed", tone: "ok") PR 36]),
    ([F-004], [Anonymous vs signed-in sidebars differ for the same page], [#pill("by design", tone: "neutral") recorded]),
    ([F-005], [Reject with no confirmation, reason or feedback], [#pill("fixed", tone: "ok") PR 38: dialog, reason, Undo, reason shown to researcher]),
    ([F-006], [404 page prints `GoException`], [#pill("fixed", tone: "ok") PR 36; blank-page regression fixed on daaf308]),
    ([F-007], [25-row researcher sidebar, a third placeholders], [#pill("open", tone: "warn") product decision (Rui)]),
    ([F-008], [Sidebar highlights the wrong row], [#pill("fixed", tone: "ok") PR 33]),
    ([F-009], [New output shows no _pending_ tag in My Outputs], [#pill("fixed", tone: "ok") PR 32; duplicate-text regression fixed on e5b8847]),
    ([F-010], [Phone dashboard tiles clip], [#pill("fixed", tone: "ok") PR 39]),
    ([F-011], [Logo swatch labels illegible], [#pill("fixed", tone: "ok") PR 35]),
  ),
  widths: (1.3cm, 1fr, 5.6cm), right-from: 99,
)

Also fixed in the round: sidebar footer overlap, humanised status labels, chooser copy, stale Maestro assertions, phone review tabs and report table.

= What is left

#data-table(
  ("Item", "Severity", "Owner"),
  (
    ([Sidebar: headers only by default, mark or hide the 8 placeholder leaves], [3], [Rui — decision, then half a day]),
    ([Raw status chips on the researcher's profile header (`external`, `pending_review`)], [2], [dev — reuse `queueStatusLabel()`]),
    ([Three feedback patterns for one message type], [2], [dev — pick one]),
    ([Empty ORCID-sync state for the 158 researchers without an iD], [2], [dev — explain + link]),
    ([Thin Personal Information page after the E4 split], [2], [design]),
    ([DOI-first Add output + title-similarity warning (BP-07, BP-16)], [—], [the highest-value feature before the demo]),
  ),
  widths: (1fr, 1.6cm, 4.4cm), right-from: 99,
)

= Best practice, 38 items

#bar-row("Met (10)", "26 %", 0.26, tone: "ok")
#bar-row("Partly met (23)", "61 %", 0.61, tone: "warn")
#bar-row("Not met (5)", "13 %", 0.13, tone: "bad")

#v(2pt)
Ahead of the field for its size: authorship link rows, unique DOI, full audit trail, approval-gated nightly public build, ORCID harvesting, merge tool. Behind: entry starts from a blank form, no draft or withdraw, no reviewer return loop, FCT team export and unclaimed-candidate counts not surfaced.

#v(4pt)
#text(size: 8.5pt, fill: muted)[Method: Playwright crawl of every route in anonymous, researcher and admin mode at 1280 × 900 and 390 × 844; five provoked system states; seven journeys; Nielsen, UX laws, WCAG 2.2, design system vs Figma, five states; ISO 9241-11 metrics; every severity ≥ 3 claim re-tested before inclusion. Full detail: `audit/2026-09-09-1601/report.md`, research: `docs/research/2026-09-rims-best-practices.md`, long report: `ux-audit-report.pdf`. Raw screenshots stay off git (researcher emails).]

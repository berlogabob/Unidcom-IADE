// UNIDCOM RIMS — Pilot Delivery Report, August 2026.
// Build: ./build.sh   (see that script for the exact typst invocation)
//
// Every figure in this document was measured from the live database, the git
// history, or a command run against the deployed system on 2026-08-06.
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — Pilot Delivery Report",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · Pilot delivery report · August 2026",
  lang: "en",
))

#title-block(
  "UNIDCOM RIMS",
  subtitle: "Pilot Delivery Report — August 2026",
  meta-line: [Delivered against the _Pilot Implementation Plan, August–September 2026_ · Backend & business logic: Andrey · Prepared 6 August 2026],
  standfirst: [Eight of the nine September success criteria are met. One —
  synchronisation with the website — was met by a different mechanism than the
  plan assumed, for the reason set out in §4. The ninth, the pilot
  demonstration, is waiting on the cohort list, not on engineering.],
)

#kpi-row((
  ("8 / 9", "Success criteria met", "1 pending, 0 failed"),
  ("365", "Outputs approved", "from 0 at baseline"),
  ("184", "Profiles approved", "574 audited changes"),
  ("49", "Automated tests", "plus 3 E2E flows"),
))

#callout(title: "The one thing needed from you", tone: "warn")[
  The pilot cohort has not been named. Everything downstream of that list is
  built, deployed and verified. Related: *21 of the 46 integrated members have
  no ORCID iD on file* — those researchers cannot sign in until an
  administrator adds it, so the cohort should either be drawn from the 26 who
  already have one, or budget an admin pass first.
]

= 1. Where the pilot stands

The system is live at #link("https://berlogabob.github.io/Unidcom-IADE/")[berlogabob.github.io/Unidcom-IADE].
A researcher can sign in with ORCID, confirm their profile, claim publications
and mark selected ones; UNIDCOM staff can approve or reject that work in a
review queue; every status change is audited; the institutional publication
report generates from live data as a 24-page PDF; and the public site shows
only approved content.

The database moved from a staging area to an institutional record during
August. The contrast with the 4 August baseline is the clearest single measure:

#data-table(
  ("Measure", "Baseline (4 Aug)", "Now (6 Aug)", "Change"),
  (
    ([Outputs approved and publicly visible], [0], [365], [+365]),
    ([Profiles approved], [0], [184], [+184]),
    ([ORCID works staged for claiming], [5], [1 457], [+1 452]),
    ([Outputs with a DOI], [42], [45], [+3]),
    ([People with an ORCID iD], [26], [26], [—]),
  ),
)

#text(size: 8.5pt, fill: muted)[Baseline figures from `PLAN.md` §2; current
figures queried from the production database on 6 August 2026. Every approval
above is individually audited — the change log now holds 574 entries recording
who changed what, and when.]

= 2. The nine success criteria

Taken verbatim from §5 of the implementation plan. Status vocabulary is
deliberate: _Met differently_ means the outcome was achieved by another
mechanism, explained in §4 — it is not a euphemism for incomplete.

#scorecard((
  (
    "Researcher authentication (ORCID)",
    "Met", "ok",
    "ORCID broker + claim RPC, live; failure path fixed and covered by a test",
  ),
  (
    "Researcher profile validation",
    "Met", "ok",
    "draft → pending_review → approved, verified on production; 186 transitions audited",
  ),
  (
    "Selected Publications management",
    "Met", "ok",
    "Owner-only, five-item cap, covered end-to-end (star → reload → unstar)",
  ),
  (
    "Editorial approval workflow",
    "Met", "ok",
    "Review queue, admin-only via RLS, 365 approvals recorded in the audit log",
  ),
  (
    "Automatic synchronisation with Sanity",
    "Met differently", "warn",
    "Approval-driven visibility instead of a push pipeline — see §4",
  ),
  (
    "Standard institutional publication report",
    "Met", "ok",
    "Typst → PDF from live data; 24 pages, reproducible",
  ),
  (
    "Publication statistics by output type",
    "Met", "ok",
    "Per-type summary with percentages in the report; KPIs on the dashboard",
  ),
  ("Dashboard prototype", "Met", "ok", "ORCID coverage, approval, DOI and validation progress"),
  (
    "Pilot demonstration",
    "Pending", "info",
    "Script written and revalidated; blocked on cohort and scheduling",
  ),
))

= 3. August deliverables, as assigned

The plan (§4) assigned four weeks of backend deliverables. All were completed;
the table records where each one lives.

#data-table(
  ("Week", "Assigned deliverable", "Delivered as"),
  (
    ([W1], [Database refinement, metadata model review], [30 migrations; vocabulary constraints on every status column]),
    ([W1], [Administration rules], [Row-Level Security policies + a protect trigger on privileged columns]),
    ([W1], [Integration planning], [ORCID chosen as the single publication source; Ciência Vitae descoped, see below]),
    ([W2], [Researcher Profile Admin], [Self-service profile with "Confirm my profile" submission]),
    ([W2], [Business rules, validation workflow], [Two state machines, admin-only transitions, full audit]),
    ([W3], [UNIDCOM Admin], [Review queue, merge tooling, data browser, dashboard, settings]),
    ([W3], [Synchronisation engine], [Approval-driven RLS visibility — §4]),
    ([W3], [Reporting engine], [Typst edge function producing the institutional PDF]),
    ([W4], [Testing], [49 automated tests + 3 end-to-end flows; CI gates every deploy]),
    ([W4], [Bug fixing], [Zero known blockers; the notable finds are in §6]),
    ([W4], [Demonstration], [Script ready; awaiting cohort]),
  ),
  widths: (1.4cm, 6cm, 1fr),
  right-from: none,
)

*Ciência Vitae* was listed in the plan as a backend integration and was
deliberately descoped for the pilot: ORCID is the single publication source,
and Ciência IDs are already captured from ORCID profiles into the researcher
record. Direct integration remains open for Phase 2.

= 4. The one deviation, stated plainly

The plan specifies that the RIMS "pushes validated information to the Sanity
website", and lists _Automatic synchronisation with Sanity_ as a success
criterion. That is not what was built, and the difference is worth
understanding rather than glossing.

#grid(
  columns: (1fr, 1fr),
  gutter: 10pt,
  callout(title: "What the plan assumed", tone: "info")[
    Two systems: the RIMS holds the truth, a separate Sanity CMS holds the
    website's copy, and a synchronisation engine keeps the second in step with
    the first.
  ],
  callout(title: "What exists", tone: "ok")[
    One system: the public website *is* the application, reading the RIMS
    database directly under Row-Level Security. Approval changes what is
    visible, immediately.
  ],
)

The reasoning: a push pipeline between two stores creates a second copy of the
truth and a new failure mode — the sync job — in exchange for nothing, while
the website reads the database directly. Instead, approval itself became the
visibility boundary: anonymous visitors see only approved and validated rows,
authenticated staff see everything. Publishing is now a database policy rather
than a job that can silently fall behind.

What this preserves matters more than what it replaces. The approval boundary
is the API contract either way, so adopting Sanity later is a change of
consumer, not a redesign of the workflow — it stays available as the Phase 2
option the plan's roadmap already anticipates.

#callout(title: "Net effect on the criterion", tone: "ok")[
  The outcome the criterion asks for — validated information reaching the
  public website automatically, with nothing unapproved leaking — is achieved
  and was verified anonymously against production. The named mechanism is not.
]

= 5. Delivered beyond the assigned scope

The following was not in the August backend deliverables. It was built because
the pilot needed it.

#data-table(
  ("Addition", "Why it exists"),
  (
    (
      [Redesigned interface, implemented],
      [Carmela's design system (Figma + templates) applied across every screen: tokens, adaptive navigation, restyled pages. *The design is Carmela's work; this is its implementation.*],
    ),
    (
      [Support-requests system],
      [New table with its own access rules and audit trail, a researcher form and an administrator triage queue, covering DPD, Open Access and mission requests.],
    ),
    (
      [Researcher portal and Welcome Pack],
      [An overview page plus an eleven-section guide — affiliation and FCT funding statements with copy-to-clipboard, obligations, resources — so onboarding does not depend on a person explaining it.],
    ),
    (
      [Per-area authentication gate],
      [The portal requires a session; the public directory and the Welcome Pack stay open, so a prospective member can read the onboarding material before they have an account.],
    ),
    (
      [Accessibility corrections],
      [Request cards, triage rows and the login error message were absent from the browser's accessibility tree — invisible to screen readers. Now exposed, with the error announced as a live region.],
    ),
  ),
  widths: (5cm, 1fr),
  right-from: none,
)

= 6. How the work was run

Three practices did most of the work, and are worth keeping for Phase 2.

*Every claim carries an acceptance check.* Tasks are tracked as checkbox rows
with an explicit command attached — a test, a SQL result, a flow run. A box is
ticked only when that command passes, never on a report that something is done.

*Implementation was delegated; judgement was not.* Routine changes went to
cheaper automated executors under written briefs naming exact files and
forbidden edits. Planning, review, and anything touching authentication or
access rules stayed central and were read line by line before being applied.

*Adversarial review before merge.* An independent pass over the whole branch,
told to look for defects rather than to confirm the work.

That last practice paid for itself:

#data-table(
  ("Defect", "Caught", "Consequence had it shipped"),
  (
    (
      [Support-request creation never sent the owner's identifier],
      [Before merge],
      [Every "New request" would have failed on first use],
    ),
    (
      [Researcher portal had no navigation entry point],
      [Before merge],
      [Reachable only by typing a URL],
    ),
    (
      [ORCID sign-in failures were silently swallowed],
      [Before pilot],
      [A researcher whose iD is not on file would land on the public list with no message — indistinguishable from a broken button],
    ),
  ),
  widths: (6cm, 2.4cm, 1fr),
  right-from: none,
)

The third was found by deliberately tracing the pilot's day-one path after the
redesign, rather than waiting for a researcher to hit it. It is now covered by
an automated test.

= 7. Evidence

#grid(
  columns: (1fr, 1fr),
  gutter: 14pt,
  [
    #fact("Automated tests", "49, all passing")
    #fact("End-to-end flows", "3, run against live data")
    #fact("Migrations", "30, each reviewed before applying")
    #fact("Routes", "24")
  ],
  [
    #fact("Commits since 4 Aug", "81")
    #fact("Application code", "60 files, ~16 000 lines")
    #fact("Edge functions", "ORCID broker, report generator")
    #fact("Deployment", "CI-gated on analysis + tests")
  ],
)

The three end-to-end flows exercise the journeys that matter: the publication
highlight round-trip (write, reload, undo), the full support-request lifecycle
through to administrator approval, and the ORCID failure path. Each runs
against the live database and cleans up after itself.

= 8. Risks and what is needed

#scorecard((
  (
    "Cohort not yet defined",
    "Blocking", "bad",
    "Hande and Rui to name the researchers — the only engineering-independent blocker",
  ),
  (
    "ORCID data readiness",
    "Action needed", "warn",
    "21 of 46 integrated members lack an iD; they cannot sign in until it is added",
  ),
  (
    "ORCID round-trip unverified by hand",
    "Minor", "warn",
    "Third-party login cannot be automated; one manual click-through remains",
  ),
  (
    "Report function cold start",
    "Known, mitigated", "info",
    "First call after idle fails on resource limits, retry succeeds — warm it before the demonstration",
  ),
))

#callout(title: "Looking to Phase 2", tone: "info")[
  New entity types (Projects, Funding, PhD Students) inherit publication control
  by adopting the same status column and policy as §4 — no new machinery. But
  the most valuable near-term investment is not a feature: at 26 of 184 people,
  a single source of truth is only as good as ORCID coverage.
]

= 9. Addendum — changes since 6 August

#callout(title: "Why this section exists", tone: "info")[
  Everything above was measured on 6 August and is left exactly as delivered.
  The architecture changed later the same day, in a way that turns §4's
  "deviation" into a plain "met". Rather than rewrite the record, the change is
  set out here with its own date.
]

== What changed

A Hugo static site already existed in a sibling repository,
#raw("berlogabob/unidcom-site"), generated from this same database. Section 4
argued against a push pipeline on the understanding that the Flutter application
_was_ the public website. That was wrong at the repository boundary, and the two
surfaces overlapped: both served People, Projects and Outputs publicly, through
two different privacy filters.

The two systems were joined into one flow, and their roles separated:

#scorecard((
  (
    "Public website",
    "Hugo", "ok",
    "Static site regenerated from RIMS nightly; approval-gated and indexable since 6 August",
  ),
  (
    "Researcher portal",
    "This app", "ok",
    "Login and the Welcome Pack are its only anonymous screens; the directory is now the live internal view",
  ),
  (
    "Entry point",
    "The website", "ok",
    "Nav, footer, every person page and a /researchers/ page link into the portal",
  ),
))

== Effect on the ninth criterion

Criterion 5, _automatic synchronisation with the website_, was scored *Met
differently* in §2 because publication was a database policy rather than a job.
Both mechanisms now exist and they agree: row-level security decides which rows
an unauthenticated caller may read at all, and the nightly synchronisation
regenerates the public site from exactly those rows, with its own field
allowlist on top. On the terms the plan set — RIMS as the source of truth
pushing validated information to a website — the criterion is now simply *Met*.

The §4 argument still holds where it was aimed: a second copy of the truth is a
real cost, and it is paid here in a synchronisation lag rather than in
divergence, because approval remains the single gate. The lag is bounded by the
nightly run, stated in the site footer, and can be collapsed on demand.

== Corrections to figures above

#fact("End-to-end flows", "4, not 3 — an auth-gate flow was added covering the anonymous bounce and the post-login landing")
#fact("People published", "183, not 184 — the approval gate excluded one merged duplicate record")
#fact("Automated tests", "49, unchanged")

== What did not change

The cohort is still unnamed, and it remains the only blocker on the September
checklist. ORCID coverage is still 26 of the active researchers, 21 of the 46
integrated members still lack an iD, and the portal's sign-in broker still
refuses an iD it does not know — so the admin pass described on page 1 is
needed before onboarding day whichever names are chosen.

// UNIDCOM portal — full status report: what the system does, how it got here,
// and the open questions that drive next steps. Numbers verified against the
// live database and git history on 2026-08-14.
// Regenerate: typst compile 2026-08-14-rui-update.typ
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM Portal — Status Report",
  footer: "UNIDCOM-IADE · Research Information Management",
))

#title-block(
  "Portal status report",
  subtitle: "What is built, how it got here, and what needs a decision",
  meta-line: "14 August 2026 · berlogabob.github.io/Unidcom-IADE · 181 commits since 21 July",
  standfirst: [The portal is live, secured, and rebuilt around the 10 August
    feedback. Everything below is running in production and checked on the
    real site. What blocks the first group test now is not code — it is the
    eight questions at the end of this report.],
)

#kpi-row((
  ("184", "active researchers", "imported and de-duplicated"),
  ("365", "outputs", "358 classified in the category tree"),
  ("1,469", "ORCID publications staged", "ready to claim, for 26 people"),
  ("26", "can log in with ORCID", "21 of 46 integrated members still lack an iD"),
))

= What the system does today

#scorecard((
  (
    "Data foundation",
    "Live",
    "ok",
    [All researchers and outputs imported from the spreadsheets,
      de-duplicated, and kept in one database. The category tree was repaired
      in production — 358 of 365 outputs now sit on a real branch.],
  ),
  (
    "Public site + portal",
    "Live",
    "ok",
    [The public website is the open face; the portal behind it requires
      login. Anonymous database access is fully revoked.],
  ),
  (
    "ORCID",
    "Live",
    "ok",
    [One-click sign-in, account linking, and publication claiming: staged
      publications appear on the researcher's profile with a single
      "Add all" button.],
  ),
  (
    "Two separate views",
    "Live",
    "ok",
    [Researchers see only their own work: profile, outputs, welcome pack.
      Admins get the full directory and review queues, choose their view
      after login, and can switch any time. The choice survives a page
      refresh.],
  ),
  (
    "Category filter",
    "Live",
    "ok",
    [One step-by-step combobox cascade drives the outputs list, the
      "+ Add output" form, and the researcher's own outputs. Levels appear
      only where the tree has them.],
  ),
  (
    "Researcher self-report",
    "Live",
    "ok",
    [Researchers record their own outputs. Entries appear in their list at
      once and wait in the admin review queue before going public.],
  ),
  (
    "Security",
    "Live",
    "ok",
    [Row-level permissions on every table, admin-only write paths, the ORCID
      login vulnerability closed, and a security-advisor sweep applied.],
  ),
  (
    "Design system",
    "Live",
    "ok",
    [The whole portal restyled to the Figma template system: tokens,
      typography, navigation, welcome pack.],
  ),
  (
    "Operations",
    "Live",
    "ok",
    [Architecture, operations and audit documents; CI builds and tests every
      change (both build variants); automated click-throughs of the deployed
      portal that have already caught three real defects.],
  ),
))

= Development path

#data-table(
  ("Period", "What happened"),
  (
    (
      "21–28 Jul",
      [Foundation: database schema, the importer that de-duplicated people
        and outputs, and the first read-only portal pages.],
    ),
    (
      "1–7 Aug",
      [Pilot buildout. The portal was restyled to the Figma templates,
        the welcome pack and support requests were built, login became
        mandatory for the app, anonymous database access was revoked, the
        ORCID login flaw was fixed, and the operations/architecture/audit
        documents were written. Busiest day: 60 commits on 5 August.],
    ),
    (
      "10 Aug",
      [Feedback session on the live portal. The annotated screenshots became
        the new spec: one page was doing two jobs, filters were a wall of
        pills, breadcrumbs showed doubled labels, "+ add" was missing.],
    ),
    (
      "13 Aug",
      [The rebuild that feedback asked for: researcher and admin views
        split; the doubled labels traced to a data defect and repaired in
        production (301 → 358 classified); researcher self-report added
        through one audited database function. An automated click-through of
        the deployed portal then found two layout defects no test had seen —
        both fixed and redeployed the same day.],
    ),
    (
      "14 Aug",
      [Follow-ups: the view choice now survives a page refresh, and the
        category filter works on a researcher's own outputs. The live
        re-check caught one more gap (the profile query didn't load the
        category field) — fixed and redeployed. All checks green: 125 tests,
        both build variants compile.],
    ),
  ),
  right-from: none,
  widths: (2.2cm, 1fr),
)

= Open questions

Answers to these — most take one sentence — become the September pilot
checklist. The first is the only true blocker.

+ *First test group.* Which researchers, and roughly how many? Once the names
  are in, accounts are set up the same day.
+ *The 21 integrated members without an ORCID iD.* They cannot use ORCID
  sign-in until an iD is on their profile. Who supplies the iDs — or do they
  get email + password accounts instead?
+ *The "Connect ORCID" button.* Flagged as noise in the 10 August feedback,
  but it is the first thing an unlinked researcher needs. Keep it visible on
  the profile, or move it inside Edit?
+ *One admin password was shared over a chat channel.* It should be rotated;
  a new one can be set in minutes. Now, or after the group test?
+ *A real ORCID login has never been done by a person.* The flow is tested
  automatically on both sides of the ORCID screen, but third-party login
  cannot be fully automated. Someone with a registered iD should click
  through it once — who, and when?
+ *Demo for UNIDCOM.* The walkthrough is written and executable. When should
  the dry-run happen?
+ *Support requests* are built but hidden for the group test, so testers see
  nothing half-connected. Confirm they stay hidden until after the test?
+ *Known operational risks.* Backups currently cover 9 of 27 tables, and one
  person holds every critical account. Accept for the pilot, or fix first?

= What happens next

+ The questions above get answered — most need one sentence.
+ Accounts are created for the selected group, and each person receives a
  short note explaining how to log in.
+ The group starts using the portal. Their questions and problems are
  collected and fixed before the wider rollout.

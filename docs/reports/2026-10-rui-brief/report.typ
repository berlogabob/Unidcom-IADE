// Rui's v1.0 brief against the portal on branch e/brief. Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "Rui's v1.0 brief — before and after",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · Rui's v1.0 brief · 1 October 2026",
  lang: "en",
))
#set page(margin: (top: 1.6cm, bottom: 1.7cm, x: 1.9cm))

#title-block(
  "Rui's v1.0 brief — before and after",
  subtitle: "The brief and four target layouts (30 Sep) against the portal on branch e/brief, 1 Oct 2026.",
  meta-line: [Result: 41 items. 36 done, 4 partial (each with a reason), 1 conflict to decide.],
  standfirst: [36 items are done; four remain partial for their stated reasons, and one conflict needs Rui's decision.],
)

#kpi-row((
  ("41", "Items"),
  ("36", "Done"),
  ("4", "Partial"),
  ("1", "Conflict"),
))

= What changed

#data-table(
  ("ID", "Before", "After", "Status"),
  (
    ([G-3], [UNIDCOM line without name], [Name · role · UNIDCOM · Website; reloads after Submit], [#pill("done", tone: "ok")]),
    ([G-5], [ORCID sync dialog; imported nothing], [Import fills form; read-only check; no push], [#pill("done", tone: "ok")]),
    ([G-6], [(i) on some profile fields/actions], [(i) across researcher and key admin surfaces], [#pill("partial", tone: "warn")]),
    ([OV-1], [Yellow banner; one link per item], [Adds requested-changes note], [#pill("done", tone: "ok")]),
    ([OV-2], [Four steps; current step bold], [Dot, status, date; teal current; grey future], [#pill("done", tone: "ok")]),
    ([OV-3], [Bio 4 lines; no pending count], [Bio 3 lines; approval count; numbers filter outputs], [#pill("done", tone: "ok")]),
    ([PR-2], [White ORCID box; sync dialog], [Light-teal box; account linking], [#pill("done", tone: "ok")]),
    ([PR-3], [Separate details and ORCID panels], [One Identity & bio card], [#pill("done", tone: "ok")]),
    ([PR-5], [Actions at bottom], [Actions top right in title card], [#pill("done", tone: "ok")]),
    ([SO-6], [Role · DOI; first issue +N; pills], [Year; full issues; no pills], [#pill("partial", tone: "warn")]),
    ([AD-1], [10 items in 4 groups], [Five items; rest under More], [#pill("done", tone: "ok")]),
    ([AD-2], [5 tiles; approve tiles same page], [4 tiles; each approve tile has its own tab], [#pill("done", tone: "ok")]),
    ([AD-5], [Numbers only; year chips], [unchanged], [#pill("conflict", tone: "bad")]),
    ([AD-6], [Only no-ORCID alerts], [Named proposal alerts; no-ORCID opens person], [#pill("done", tone: "ok")]),
    ([AD-7], [Visible low-priority label], [Removed], [#pill("done", tone: "ok")]),
    ([PE-1], [List of person fields and pills], [Table; row opens person], [#pill("done", tone: "ok")]),
    ([PA-1], [To validate; Approve only], [Draft; Approve · Request changes · Reject; Publish in Approved], [#pill("done", tone: "ok")]),
    ([PA-2], [8 tabs side by side], [Profiles · Outputs · More], [#pill("done", tone: "ok")]),
    ([CK-1], [Hugo; no Sanity], [Hugo live; Sanity test project + Studio], [#pill("partial", tone: "warn")]),
    ([CK-2], [Reported 401 on people], [RLS verified; one sign-in race], [#pill("partial", tone: "warn")]),
  ),
  widths: (1.2cm, 1fr, 1fr, 1.8cm),
  right-from: none,
)

= Already as the brief asked

The unchanged items that are done are G-1, G-2, G-4, G-7, G-8, OV-4, OV-5, PR-1, PR-4, PR-6, SO-1, SO-2, SO-3, SO-4, SO-5, SO-7, SO-9, AD-3, AD-4, and AD-8.

= Decisions for Rui

#callout([
  *AD-5 semester conflict.* Semester tabs need a date on outputs; RIMS has reporting year only.
], tone: "bad")

#callout([
  *Muted text.* Keep #raw("#6A6862"), not #raw("#888680"): #raw("#888680") fails WCAG AA on the page background.
], tone: "warn")

#callout([
  *CK-1 Sanity site.* Hugo is the site; Sanity test project #raw("ld5jhf23") and Studio exist, with push per person. There is no Sanity-backed website: the agency's site reads its own project.
], tone: "info")

#callout([
  *SO-6 venue.* There is no venue data because RIMS stores no venue field; this is out of scope.
], tone: "info")

= One look, one behaviour

Before, 3 of 29 signed-in routes used the design-system frame (DsPage), with competing DetailBody and PortalPage frames plus bare pages. After, every signed-in page uses the same sand-background, 1100-wide, 24-padding frame and opens with the same title card; PortalPage is DsPage, and the listed pages moved into it. The sidebar is navy #raw("#16213A"), with Inter and Segoe UI fallback.

= Target vs built

#let comparison(target, built, label) = {
  block(breakable: false, above: 0.7em, below: 1em)[
    #text(weight: 700, size: 10.5pt)[#label]
    #v(0.35em)
    #grid(
      columns: (1fr, 1fr),
      gutter: 10pt,
      align: horizon,
      figure(image(target, width: 100%), caption: [Rui's target]),
      figure(image(built, width: 100%), caption: [Built, 1 Oct]),
    )
  ]
}

#comparison(
  "img/target-overview.png",
  "img/r_home.png",
  "Overview",
)
#comparison(
  "img/target-my-profile.png",
  "img/r_profile.png",
  "My Profile",
)
#comparison(
  "img/target-sci--outputs.png",
  "img/r_outputs.png",
  "Scientific Outputs",
)
#comparison(
  "img/target-admin-dashboard.png",
  "img/a_dashboard.png",
  "Admin Dashboard",
)

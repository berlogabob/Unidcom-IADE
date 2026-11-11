#import "lib.typ": *

#show: report.with((
  title: "Portal to Sanity to website: status",
  author: ("UNIDCOM RIMS",),
  footer: "UNIDCOM RIMS · Sanity bridge · 23 Oct 2026",
  lang: "en",
))

#title-block(
  "Portal to Sanity to website",
  subtitle: "Internal status",
  meta-line: "Prepared 23 Oct 2026 · state of the repository, nothing deployed",
  standfirst: [The portal code to edit and push website content to Sanity is written and tested locally.
  It has not run against Sanity, because the migration is not applied, the function is not deployed and we have no Sanity token.
  The agency's site reads a different Sanity project from the one we write to.],
)

= The chain

#data-table(
  ("Link", "State", "Detail"),
  (
    ([Portal editors], [Built], [New fields in person, project, lab, cluster, output editors; funders, articles, events on More → Website]),
    ([Database], [Written, not applied], [Migration `20261022100000_sanity_fields.sql`]),
    ([Bridge `sanity-push`], [Written, not deployed], [One-way, portal wins on mapped fields; images as Sanity assets; writes `sanity_id` back]),
    ([Sanity project], [Blocked], [We target test `ld5jhf23`; the live site reads `vj0axykv`; no token for either]),
    ([Netlify website], [Not connected], [Reads `vj0axykv`; nothing of ours writes there]),
  ),
  widths: (3.2cm, 3.4cm, 1fr),
  right-from: none,
)

= What was done

#data-table(
  ("Sanity type", "Fed from portal", "Edited in"),
  (
    ([member], [name, bio, ORCID, Ciência ID, research interests, board roles, photo], [Person dialog]),
    ([project], [title, abstract, status, dates + precision, budget, keywords, location, reference, website, partners, results, cover, funder, clusters, team], [Project dialog]),
    ([lab], [name, slug, short intro, description, website, logo, cover, coordinators, members, projects], [Lab editor]),
    ([cluster], [name, code, concern, description], [Cluster editor]),
    ([researchOutput], [title, year, citation, link, keywords, members], [Output editor, admin]),
    ([funder, article, event], [new portal tables; articles and events only when published], [More → Website]),
  ),
  widths: (3cm, 1fr, 3.4cm),
  right-from: none,
)

Never touched by the push: `seo`, member CV arrays, page-builder pages, podcasts, proceedings, positions, testimonials.
Nothing is read back from Sanity.

= Gaps

#data-table(
  ("Item", "Status", "Note"),
  (
    ([Migration applied], [Pending], [Needs approval; additive; new editor fields error on save until applied]),
    ([Function deployed, token set], [Pending], [Editor token on `ld5jhf23` required]),
    ([Test Studio schema], [Blocked], [Current test Studio has 4 types; the agency schema has 37 document types]),
    ([Run and read back on ld5jhf23], [Not started], [References, dates, portable text, images, untouched fields]),
    ([Lookup references], [Not started], [scientificArea, memberType (only integrated mapped), labType, projectType]),
    ([Output type and category], [Not started], [Portal enums differ from researchOutput fields]),
    ([Project and lab team roles], [Partly], [Free-text role mapped to 5 keys; rest become members]),
    ([Researcher-side editing], [Partly], [Only research interests goes through review; the rest is admin-only]),
    ([Writing to vj0axykv], [Not started], [Needs the agency token and an explicit decision; guarded by `ALLOW_PROD`]),
    ([Browser click-through], [Not started], [Analyzer and unit tests only]),
  ),
  widths: (4.6cm, 2.6cm, 1fr),
  right-from: none,
)

#callout(title: "Data mismatch to settle", tone: "warn")[
  Sanity holds 249 members and 1,596 research outputs (dump of 9 Sep). The portal holds 185 people and 372 outputs.
  90 Sanity members have no portal match; 26 portal people have no Sanity member.
  `people.sanity_id` is empty for all published people, so matching is by slug today.
]

= Decision for UNIDCOM

#callout(title: "Before the call", tone: "info")[
  Apply the migration and deploy `sanity-push` now, so the test project can be shown working.
  Only the Editor token for `ld5jhf23` would then be missing.
]

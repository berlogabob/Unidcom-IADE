// Questions for the Sanity website agency. Send as PDF or paste the text.
// Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM — questions for the website agency",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM · Sanity website · questions for the agency · September 2026",
  lang: "en",
))

#title-block(
  "Sanity website — five questions before we connect our database",
  subtitle: "UNIDCOM Research Information Management System (RIMS) ↔ Sanity project vj0axykv",
  standfirst: [UNIDCOM keeps its research directory (people, projects, scientific outputs) in its own database and admin portal. We have read the public Sanity dataset of the new site and want to feed it from our database *without breaking the site or overwriting your editorial work*. Nothing will be written to `vj0axykv` before questions 2 and 5 are answered.],
)

#kpi-row((
  ("249", "Members in Sanity", "159 are also in our database"),
  ("1 596", "Outputs in Sanity", "2011–2023; ours start in 2024"),
  ("43", "Projects in Sanity", "2012–2021; ours are current"),
  ("0", "Writes made so far", "read-only comparison only"),
))

= Questions

#data-table(
  ("#", "Question", "Why we ask"),
  (
    ([1], [*Hosting.* Where is the Sanity-backed frontend deployed, and is it live anywhere yet? `unidcom-iade.pt` still serves the WordPress site.], [We need to see the rendered result of any change.]),
    ([2], [*Studio schema.* Can we get access to the Sanity Studio repository (`sanity/schemaTypes`), or an export of the schema and validation rules?], [Our documents must match your types exactly (e.g. `member.type`, `flexibleDate`, `team`).]),
    ([3], [*Publishing.* Does the site read Sanity live, or does it need a revalidate / rebuild hook after content changes? If so, which endpoint and secret?], [Writing a document is not the same as updating a page.]),
    ([4], [*Editorial ownership.* Who edits Sanity today, and which fields do you consider editorial (photos, short bios, cover images, page copy) versus data we may update (names, ORCID, emails, project dates, publications)?], [We will never overwrite an editorial field; we need the list.]),
    ([5], [*Access.* When we are ready, an Editor API token for `vj0axykv`, and whether a staging dataset exists or can be created.], [First runs go to a sandbox, never straight to production.]),
  ),
  widths: (0.7cm, 1fr, 5.2cm), right-from: 99,
)

= What we intend to do, in order

#scorecard((
  ("Read-only comparison of both datasets", "Done", "ok", "no writes to Sanity"),
  ("Link the 159 shared people inside our database", "In progress", "info", "admin-reviewed, logged, reversible"),
  ("Push new people, projects and publications to a sandbox dataset", "Pending (blocked on 2 and 5)", "warn", "new documents only; existing members untouched"),
  ("Push to the production dataset", "Not started", "neutral", "after your review of the sandbox"),
))

#callout(title: "Contact", tone: "info")[André Berloga · andre.berloga\@gmail.com · UNIDCOM/IADE, Universidade Europeia]

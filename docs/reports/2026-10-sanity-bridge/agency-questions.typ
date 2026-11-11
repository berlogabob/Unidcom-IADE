#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS and Sanity: questions for the agency",
  author: ("UNIDCOM RIMS",),
  footer: "UNIDCOM RIMS · Questions for the agency · 23 Oct 2026",
  lang: "en",
))

#title-block(
  "Questions for the agency",
  subtitle: "UNIDCOM research portal and the Sanity-driven website",
  meta-line: "23 Oct 2026",
  standfirst: [The portal will create and update members, projects, labs, clusters, research outputs, funders, articles and events in your Sanity project, one way.
  We need these nine points to finish the link.],
)

#data-table(
  ("No.", "Question", "Answer"),
  (
    ([1], [Is there a staging dataset we can write to first? If not, may we write to production directly?], []),
    ([2], [Can you provide an Editor token (or API user) for that project?], []),
    ([3], [Will anyone keep editing members, projects, labs, clusters or research outputs in Studio after go-live? Our pushes overwrite the fields we send.], []),
    ([4], [May we create new documents, or only update existing ones? If a slug changes, does the site redirect the old address?], []),
    ([5], [Which fields must be filled for a document to appear on the site (for example `member.type`)?], []),
    ([6], [Do you use drafts? Should our writes publish directly, or arrive as drafts for you to publish?], []),
    ([7], [What triggers a Netlify rebuild after a Sanity change: a webhook or a schedule? Should our sync call it?], []),
    ([8], [How is content taken off the site: delete the document, or set a flag such as `noPublicPage`?], []),
    ([9], [Who owns the Studio and the API tokens after handover, and who do we contact if a push breaks the site?], []),
  ),
  widths: (1.1cm, 1fr, 5.6cm),
  right-from: none,
)

# New UNIDCOM website — questions before we connect our database

UNIDCOM keeps its own database of researchers, projects and publications. We would like the new
website to show that information automatically, so that nobody has to type it twice. Before we
change anything on your side we need to understand how the site is built and who owns what.

| # | Question | What we need to know |
|---|---|---|
| 1 | Where does the new site live, and is it public yet? | The address of the new site (and of any preview or staging version). Today `unidcom-iade.pt` still shows the old WordPress site. |
| 2 | How is the content structured? | The definition of the content types in Sanity (the Studio project, or an export of its schema): which fields exist for a person, a project, a publication, and which values are allowed. |
| 3 | How does a change in Sanity reach the pages? | Whether the site reads Sanity live, or needs to be rebuilt after an edit. If it needs a rebuild, how that is triggered. |
| 4 | Who edits the content today, and what should we leave alone? | The people who maintain the site, and the fields they consider theirs: photos, biographies, cover images, page texts. We will only update factual data such as names, ORCID, emails, project dates and publication lists, and never the fields you name here. |
| 5 | How can our system be allowed to write, safely? | A separate test dataset (or a copy of the content) where we can try our updates first, and later an API token with write access to the real content. Nothing will be written to the real site before you have seen the test. |
| 6 | What is the plan for the old site and for launch? | When the new site goes live, what happens to `unidcom-iade.pt`, and whether the people pages of the old site are redirected. |
| 7 | Who is our technical contact? | One person on your side for these questions, and the channel you prefer. |

PDF version: `docs/reports/2026-09-sanity-howto/sanity-agency-questions.pdf`.

// Morning check with Rui, Wed 30 Sep 2026 — what Rui decided on 25 Sep
// versus what is live, and the step-by-step walk to confirm it.
// Facts verified 29 Sep 21:30 on main fa2046c (CI + deploy green, 330 tests,
// live DB counts). Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — Morning check with Rui",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · morning check · 30 September 2026",
  lang: "en",
))
#set page(margin: (top: 1.6cm, bottom: 1.7cm, x: 1.9cm))

#let tick = box(width: 8pt, height: 8pt, stroke: 0.6pt + luma(120), radius: 1.5pt)
#let steps(rows) = data-table(
  ("#", "Do", "You should see", ""),
  rows.enumerate().map(((i, r)) => ([#(i + 1)], r.at(0), r.at(1), tick)),
  widths: (auto, 1fr, 1.3fr, auto),
  right-from: 3,
)

#title-block(
  "Rui's UI decisions — ready to check",
  subtitle: "What Rui asked on 25 Sep, what is live today, and how to confirm it in about an hour.",
  meta-line: [Portal on `main` ff17ac5, deployed 30 Sep · CI and deploy green · 333 automated tests pass · 6 of 7 browser flows pass · every number below read from the live system on 29–30 Sep.],
  standfirst: [#pill("READY", tone: "ok") All 73 decisions in Rui's document were built. 70 are done exactly as asked. 3 are done differently or partly, each for a stated reason, and need Rui's yes or no. Nothing was deferred. The one step we did not do alone is putting a real profile on the public website: that needs a real person's record, and it is step C below.],
)

#kpi-row((
  ("70", "Done as asked", "of 73 decisions"),
  ("3", "Need Rui's call", "done differently or partly"),
  ("0", "Deferred", ""),
  ("333", "Automated tests", "all pass"),
))

= Rui asked vs we have

#scorecard((
  ("Rules for every page", "5 of 6", "warn", "Colours: sidebar and grey text kept for readability; (i) now on every field and action"),
  ("Overview", "16 of 16", "ok", "Timeline, yellow banner, bio, summary tiles, issues named in full"),
  ("My Profile", "16 of 16", "ok", "ORCID import only, photo upload, featured read only, Save draft / Submit"),
  ("Scientific Outputs", "16 of 16", "ok", "Tabs, chips, live counters, Featured N/5, stars only on publications"),
  ("UNIDCOM Admin", "14 of 15", "warn", "No semester tabs (no publication date); pipeline now has all 5 columns"),
  ("Platform checks", "3 of 4", "warn", "Public-site step needs a real profile — step C"),
))

#callout(title: "What we need from Rui this morning", tone: "info")[
  Walk parts A, B and C (about 55 minutes); E if there is time. Then go through the decision table in part D and write one word per line: *keep*, *change*, or *later*. Anything marked *change* becomes a task we build today.
]

#pagebreak()

= Before you start (10 minutes)

#fact("Portal", "berlogabob.github.io/Unidcom-IADE")
#fact("Public website", "berlogabob.github.io/unidcom-site")
#fact("Who logs in", "Andrey, with ORCID — his account is both researcher and admin, and has 5 outputs")
#fact("Full acceptance map", "audit/2026-10-rui-ui-decisions.md (every decision → task → test)")
#fact("Demo script", "DEMO.md (15 minutes, same order as below)")

#v(6pt)
#callout(title: "What is normal, not a bug", tone: "neutral")[
  - *Everything says "To be validated".* On 29 Sep all 365 imported outputs and 184 imported profiles were set back to "To be validated by the researcher", as Rui asked. The website still shows the same 76 publications and 183 people, because showing on the website is a separate decision now.
  - *Nothing changes on the website until the sync runs.* It runs every night at 04:00 UTC, or on demand (step C10).
  - *Researchers who have not logged in yet see nothing new.* Only 4 accounts are linked today.
]

#v(4pt)
#steps((
  ([Open the portal in a private browser window.], [The sign-in page. No red errors.]),
  ([Sign in with ORCID as Andrey.], [The chooser "How do you want to continue".]),
  ([Choose *As a researcher*.], [Overview opens (not Resources & Guidance).]),
))

= A · Researcher view (20 minutes)

== Overview

#steps((
  ([Look at the top line of the page.], ["UNIDCOM: To be validated by you · Website: Published". It stays on every page.]),
  ([Look at the attention banner.], [Calm yellow, not red. Each line ends with "→" and opens its action.]),
  ([Look under the banner.], [Timeline Draft · Submitted · Under review · Published, with a date on each step already reached.]),
  ([Look at the identity card.], [The first lines of the bio and "Edit bio →" (or "Add bio →").]),
  ([Click a type tile, for example *Livros*.], [Scientific Outputs opens filtered to that type.]),
  ([Go back; click *Featured outputs*.], [Scientific Outputs opens on featured.]),
  ([Look at Recent Outputs.], [Issues written in full, such as "Missing DOI", never just "Issue".]),
))

== My Profile

#steps((
  ([Open *My Profile*.], [Subtitle "Your public researcher profile on the UNIDCOM website. UNIDCOM reviews before publishing."]),
  ([Look at the ORCID block.], ["ORCID connected · Last imported …", button *Import from ORCID*, and "Editing here does not change your ORCID record." No "Sync" anywhere.]),
  ([Hover the (i) next to ORCID, Ciência ID, Email and Lab / cluster, and next to *Import from ORCID* and *Upload photo*.], [One short sentence each — on fields and on actions.]),
  ([Click *Upload photo*, pick a JPG under 5 MB.], ["Photo sent for UNIDCOM review". The photo on the page does not change yet.]),
  ([Look for featured outputs.], [A read-only list "Featured outputs (N/5)" and "Manage in Scientific Outputs →". No checkboxes or stars here.]),
  ([Click *Edit*, change the phone, click *Save draft*.], ["Draft saved — not sent to UNIDCOM yet".]),
  ([Open *Edit* again, click in Bio.], [A counter "N / 300". Over 300 it turns amber and says the website shows the first 300. It never blocks typing.]),
  ([Click *Submit for UNIDCOM review* on the page; hover its (i).], [(i) says "Saved changes will be re-submitted for UNIDCOM review". The top line changes to "UNIDCOM: Submitted".]),
))

== Scientific Outputs

#steps((
  ([Open *Scientific Outputs*.], [Tabs *Publications* · *Other activities*, and "Featured N/5" on the right. No dropdown filters.]),
  ([Click a type chip, then one of its subtypes.], [A second row of subtype chips; the list narrows.]),
  ([Click a year chip, then *Issues only*.], [The counter line ("N outputs · … · N with issues") changes with every click.]),
  ([Read one row.], ["Type · Subtype", the issue in full or "No issues", and "On ORCID" or "Not on ORCID" as text.]),
  ([Switch to *Other activities*.], [No stars on these rows. Stars only on publications, and a 6th star is refused.]),
  ([Look above the list.], ["N outputs to be validated by you" and *Submit for UNIDCOM review (N)*. Do not click yet — step C uses it.]),
))

#pagebreak()

= B · Admin view (10 minutes)

#steps((
  ([Bottom-left, click *Switch to admin*.], [The admin dashboard.]),
  ([Read the five tiles.], [Integrated researchers 46 · Collaborators 109 · Profiles to approve · Outputs to approve · Proposals to review.]),
  ([Read *Sync status*.], [Two lines: ORCID linked / not linked, and Website published / approved-not-published / not published. Numbers only, no bars.]),
  ([Read *Issues*.], [Missing DOI and Not on ORCID. No "Not approved yet" (that is a review state, not an issue).]),
  ([Click a year chip in *Outputs by type*.], [The numbers change. There is no semester chip — see part D.]),
  ([Click one *Critical alert*.], [That researcher's page opens.]),
  ([Open *People*.], [Each row has a Website pill: "Website · Published" or "Not published".]),
  ([Open *Pending approval*.], [First tab *Pipeline*: To validate · Submitted · Under review · Approved, not published · Published. Andrey is under Submitted (from My Profile step 8).]),
))

= C · A bio change, end to end (25 minutes)

The whole path of one real change: Andrey edits his biography where Portuguese researchers keep it, and we follow it to the portal, through UNIDCOM review, onto the website and into the Sanity test copy. RIMS sends no e-mail; each hand-over below is a person clicking, and UNIDCOM sees a count on its dashboard.

#steps((
  ([*Ciência Vitae*: edit the summary (Resumo) and save.], [Saved in Ciência Vitae. RIMS is not connected to Ciência Vitae — we only learn here whether it passes the text on to ORCID.]),
  ([*ORCID* (orcid.org, signed in): open Biography.], [If Ciência Vitae passed it on, the new text is there. If not, paste the same text into Biography and save.]),
  ([*Portal*: sign out, then sign in with ORCID again.], [Overview opens.]),
  ([*My Profile* → Biography.], [Two columns: *UNIDCOM* (old text) and *ORCID* (new text), and *Import bio from ORCID*. ORCID can take a few minutes to show a change to others.]),
  ([Click *Import bio from ORCID*.], [The ORCID text becomes a proposal for UNIDCOM review. The UNIDCOM text does not change yet.]),
  ([Switch to admin. Look at the dashboard.], [Tile *Proposals to review · 1*.]),
  ([Click the tile, then the tab *Suggestions*.], [A row "Proposed by researcher", field Bio, with the new text.]),
  ([Click *Accept*.], [The row leaves the queue. Andrey's portal bio shows the new text.]),
  ([Open the public website, Andrey's page.], [Still the old bio — the site changes on sync.]),
  ([GitHub → unidcom-site → Actions → *Sync content from Supabase* → Run workflow (preview off).], [Green in about 2 minutes, then the site redeploys.]),
  ([Reload Andrey's page on the website.], [The new bio.]),
  ([*Sanity test*: run the push for Andrey (we do this part).], [His `member` document in the test project shows the new text as `shortBio`. The agency's Sanity is not touched.]),
))

= D · Rui's decisions (15 minutes)

Each line was built differently from the document, or only partly, for the reason given. Write *keep*, *change* or *later* in the last column.

#data-table(
  ("Rui asked", "We built", "Why", "Rui"),
  (
    ([Sidebar \#16213A; grey text \#888680], [Sidebar \#0E1525 kept; grey text \#6A6862], [His note says "as the platform already has"; \#888680 fails contrast on the page background], []),
    ([Outputs by type with year and semester tabs], [Year chips only], [Outputs carry a reporting year, no publication date; a semester needs a new date field], []),
    ([Show one profile reach the website], [Portal half done; website step is C10–C11 (and E10–E11)], [Needs a real record; we would not publish a test profile], []),
  ),
  widths: (1.1fr, 1.1fr, 1.3fr, 0.5fr),
  right-from: none,
)

== Also decided by us — please confirm

#data-table(
  ("Topic", "What we did", "Rui"),
  (
    ([Bio 300 characters], [Soft counter: 109 of 112 live bios are longer (up to 20,627). Nothing is cut or blocked.], []),
    ([Admin menu], [Kept Projects, Structure, Data browser, Settings and Merge duplicates; added Pending approval; "Scientific outputs" renamed "Outputs".], []),
    ([Approve vs publish for profiles], [Approving a profile no longer publishes it; *Publish to website* is separate, as for outputs.], []),
    ([Imported profiles], [Profiles as well as outputs start "To be validated" (184 profiles).], []),
    ([Pipeline length], [Each column shows 10 people and "+N more".], []),
  ),
  widths: (0.8fr, 2.2fr, 0.5fr),
  right-from: none,
)

= E · Optional: a new publication, end to end (15 minutes)

This is the only way to show a real publication going from the researcher to the website: add a publication that is not on the site yet. Use one of Andrey's real recent journal articles or books, so nothing fake reaches the public site.

#steps((
  ([Switch to researcher. *Scientific Outputs* → *+ Add output*.], [A step-by-step form: DOI → type → subtype → details → project → review.]),
  ([Fill it for a real article or book and finish.], [The new output appears with status "Submitted".]),
  ([Switch to admin → *Pending approval* → *Outputs to approve*.], [The new output is listed.]),
  ([Click *Approve*.], [It is approved but not published — approving never publishes.]),
  ([Open the output's page.], [A Website panel with *Publish to website*.]),
  ([Click *Publish to website*.], [Website status becomes "Published".]),
  ([Pipeline tab: Andrey under Submitted; click *Start review*.], [Andrey moves to Under review; his timeline shows "Under review" with today's date.]),
  ([Under review: click *Approve*.], [Andrey moves to Published (his profile was already on the site from the import).]),
  ([Open the public website, find the article.], [Not there yet — the site updates on sync.]),
  ([GitHub → unidcom-site → Actions → *Sync content from Supabase* → Run workflow (preview off).], [The run finishes green in about 2 minutes, then the site redeploys.]),
  ([Reload the public website.], [The article is on Andrey's page. Done: Submitted → Approved → Publish → visible.]),
))


= Known limits

- *Rui's own account has no outputs linked*, so his researcher view is almost empty. Use Andrey's for parts A and C.
- *The website updates only on sync* (04:00 UTC nightly, or step C10).
- *Ciência Vitae is not connected to RIMS.* It was left out of the pilot on 4 Aug: ORCID is the one source. Researchers keep Ciência Vitae, but RIMS reads ORCID.
- *No e-mail notifications.* A change on ORCID reaches RIMS when the researcher opens My Profile and imports it; UNIDCOM then sees *Proposals to review* on the dashboard. Automatic detection is possible later (a daily job already exists in the code, unscheduled).
- *Undo after the check.* Andrey's record was saved on 29 Sep 22:25; `audit/snapshots/2026-09-30-before-walkthrough.sql` puts it back and lists anything the walk added.
- *Sanity:* the test copy lives in a separate test project; the agency's project is not touched.
- *Security:* checked 29 Sep — no privileged database function can be called without signing in.

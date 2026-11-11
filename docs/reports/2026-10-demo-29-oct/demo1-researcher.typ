#import "lib.typ": *
#let meta = (title: "Demo 1: researcher, bio and outputs", footer: "UNIDCOM RIMS · demo 29 Oct 2026")
#show: report.with(meta)
#title-block("Demo 1: researcher, bio and outputs", subtitle: "Change the bio on ORCID, import it into RIMS, publish to Sanity and the website", standfirst: "One click in RIMS sends only approved content to Sanity and to the website mirror. Approval stays a separate step.", meta-line: "Meeting Thu 29 Oct 2026, 14:00 · Hande, Sabino")


= Status
#scorecard((
  ("Publish sends researcher, bio and outputs to Sanity", "Verified", "ok", "Checked live with a test researcher; no duplicates after repeated pushes."),
  ("Researcher appears on the website mirror", "Verified", "ok", "Added a test researcher, appeared after one sync (about 3 min), removed after the next."),
  ("Target Sanity", "Configured", "ok", "Publish writes to the official Sanity project (already set up and token verified)."),
))

= Steps
#data-table(("#", "Do", "You should see"), (
  ("1", "On orcid.org, edit your biography (visibility Public) and save.", "New bio shows on your public ORCID page."),
  ("2", "Sidebar bottom: Switch to researcher. My Profile, Biography. Click Import bio from ORCID.", "UNIDCOM and ORCID biographies side by side; the import is proposed."),
  ("3", "Pending approval, To review: open your person and approve the bio.", "State Approved."),
  ("4", "Ready to publish, Publish selected.", "Result: Website and Sanity per person, with Undo."),
  ("5", "Open the Sanity Studio, search the name.", "Member with bio, output linked."),
  ("6", "Start the site sync (GitHub Actions, Run workflow) right after step 4.", "New bio on your page of the website mirror in about 3 min."),
), widths: (1cm, 9cm, 1fr), right-from: none)

#callout([Publish sends only what UNIDCOM approved. The decision for Hande: which parts of the website content may go online, and how often to publish approved researcher information.], title: "Spec check", tone: "info")

#callout([The site sync runs every 10 minutes; trigger it by hand to avoid waiting. The Retry button for the website sync does not work yet (a GitHub token is not set). Delete all demo data afterwards.], title: "Know before you start", tone: "warn")

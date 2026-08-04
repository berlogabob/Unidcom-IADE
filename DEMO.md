# UNIDCOM RIMS Pilot — Demonstration Script

## Framing

UNIDCOM RIMS is the institutional single source of truth for researcher profiles and scientific outputs. The public website is one consumer of that data: it reads live from Supabase rather than maintaining a separate copy. Editorial approval is the publication gate, so only approved profiles and outputs are visible to anonymous visitors while pending records remain available for review inside RIMS.

## Demo walkthrough

### 1. Tour the public site

**Say:** “We will start with the public experience. These pages are not static exports; they are live views of the RIMS database, filtered by access rules.”

1. Open the [live site](https://berlogabob.github.io/Unidcom-IADE/) and go to `/people`.
2. Open one researcher profile and point out the identity, affiliations, and selected outputs.
3. Click **Outputs** to open `/outputs`; show the filters and open one output record.
4. Click **Structure** to open `/structure`; show how people and research units connect.
5. Open `/conferences`, select a conference, and show its `/conferences/:key` page.

**Say:** “People, outputs, structure, and conference views all come from the same governed records. A correction in RIMS becomes a correction everywhere the record is consumed.”

### 2. Complete the researcher flow

**Say:** “Now I will act as a researcher taking responsibility for my own profile and publications.”

1. Click **Login**, then **Sign in with ORCID iD** and complete ORCID authentication.
2. Confirm that sign-in returns to `/app/profile`.
3. Point to the status chip: **Profile not confirmed**, **Awaiting UNIDCOM approval**, or **Approved**.
4. Review the profile, then click **Confirm my profile**.
5. Show that the chip changes to **Awaiting UNIDCOM approval**.
6. Expand **My ORCID publications**.
7. Choose a prepared publication and click **Add to my publications**.
8. Scroll to the publications list and click its star icon to feature it on the profile.

**Say:** “ORCID provides the identity and candidate works. The researcher confirms what is theirs, but that claim does not bypass UNIDCOM’s editorial approval.”

### 3. Complete the admin flow

**Say:** “I will now switch roles. Scientific coordination controls what becomes institutional and public.”

1. Sign out of the researcher account and sign in with the prepared admin account.
2. Open `/app/admin` and click the **Review** tab.
3. Open **Profiles to approve**, locate the researcher, and click **Approve**.
4. Open **Outputs to approve**, locate the claimed publication, and click **Approve**.
5. Open **Activity** and point out the recorded changes and their timestamps.

**Say:** “The queue separates self-service contribution from institutional approval, and the activity log leaves an audit trail of the decisions.”

### 4. Prove approval-driven visibility

**Say:** “Approval is also the website synchronisation mechanism: no manual copy, rebuild, or push is required.”

1. Return to a private or signed-out browser window so the check is genuinely anonymous.
2. Reload the researcher’s public `/people/:id` page.
3. Point out that the approved profile and approved claimed publication are now visible.
4. Open a prepared pending record and show that it is absent from the anonymous public view.

**Say:** “Row-level security enforces the rule at the database boundary: approved content is public; pending content is not.”

### 5. Generate a report and show the dashboard

> Route note: `lib/main.dart` has no `/app/reports` route. Reports is the first tab inside `/app/admin`.

1. Return to `/app/admin` and click **Reports**.
2. Select **Scientific Outputs**, choose the prepared year or **All**, and click **Generate PDF**.
3. Open the downloaded institutional PDF and point out the per-type statistics table.
4. Open `/app/dashboard` and point to the KPI tiles and outputs-by-type view.

**Say:** “The public site, review workflow, institutional report, and dashboard use the same governed data, so the numbers can be traced back to approved records.”

## Numbers to quote

Refresh from the live database immediately before the demonstration
(queries in PLAN.md §2). Values as of 2026-08-04:

- **184** researchers in RIMS
- **26** researchers linked to ORCID
- **362** scientific outputs — **362 approved** (100%, audit-trailed)
- **1,456** ORCID publication candidates staged for claiming

## Q&A preparation

**Why ORCID only in the pilot?** ORCID gives the pilot one durable researcher identity and publication source; services such as Scopus and ResearchGate can deposit works there, keeping the first workflow focused and testable.

**Where does Ciência Vitae fit?** Existing Ciência Vitae identifiers remain in researcher records, but direct integration is outside the pilot and can be added after the ORCID-led workflow is proven.

**What is Phase 2?** Phase 2 can add direct Ciência Vitae integration, a Sanity website layer, and modules for projects, research groups, funding, and PhD students.

**Why is there no separate website sync job?** The Flutter website reads Supabase live, and approval-driven row-level security is the shared publication boundary; a push pipeline would duplicate work without improving the pilot.

# UNIDCOM RIMS Pilot — Demonstration Script

## Framing

UNIDCOM RIMS is the institutional single source of truth for researcher profiles and scientific outputs. The public website is one consumer of that data, generated from it by a nightly sync. Editorial approval is the publication gate: only approved profiles and outputs reach the website, while pending records remain available for review inside RIMS.

Two surfaces, two URLs:

| | |
|---|---|
| Public website (Hugo) | https://berlogabob.github.io/unidcom-site/ |
| Researcher portal (RIMS) | https://berlogabob.github.io/Unidcom-IADE/ |

The portal is gated — `/login` and the Welcome Pack are its only anonymous screens.

## Demo walkthrough

### 1. Tour the public site

**Say:** “We will start with the public experience — the website UNIDCOM shows the world. Every record on it came out of the RIMS database, and nothing reaches it without editorial approval.”

1. Open the [public site](https://berlogabob.github.io/unidcom-site/) and go to **People**.
2. Open one researcher profile and point out the identity, ORCID and Ciência iDs, biography, publications and project affiliations.
3. Point at the “Are you …? Sign in with your ORCID iD” note — the researcher's own way into the portal from their public page.
4. Open **Publications** and show the bibliography grouped by year; open **Research** for clusters and labs.
5. Open **For researchers** — the public explanation of profile editing and the three support-request types.

**Say:** “These pages come from the same governed records the researchers themselves maintain. A correction in RIMS becomes a correction on the site at the next sync.”

### 2. Complete the researcher flow

**Say:** “Now I will act as a researcher taking responsibility for my own profile and publications. The portal sits behind a login — the Welcome Pack is the only thing open to anonymous visitors, because you should be able to read the onboarding material before you have an account.”

1. From the person page on the public site, click **Sign in with your ORCID iD** — it opens the portal's `/login`. Select **Sign in with ORCID iD** and complete ORCID authentication.
2. Confirm that sign-in lands on the **Welcome Pack** (`/app/welcome/start`) — the orientation screen every login opens on.
3. Open the user chip (avatar + name) at the top right and select **My profile** (`/app/profile`).
4. Point to the status chip: **Profile not confirmed**, **Awaiting UNIDCOM approval**, or **Approved**.
5. Review the profile, then click **Confirm my profile**.
6. Show that the chip changes to **Awaiting UNIDCOM approval**.
7. Expand **My ORCID publications**.
8. Choose a prepared publication and click **Add to my publications**.
9. Scroll to the publications list and click its star icon (**Highlight on profile** / **Remove highlight**) to feature it on the profile.
10. Open the user chip again and select **Overview** to open `/app/home` — point out the stats tiles, the profile/request alerts, recent outputs, and the quick links into the Welcome Pack.
11. From the same menu select **Support requests** (`/app/requests`), click **+ New request**, pick a type (DPD / Open Access / Mission), add a budget line and tick a checklist item, then click **Submit**.

**Say:** “ORCID provides the identity and candidate works. The researcher confirms what is theirs, but that claim does not bypass UNIDCOM’s editorial approval. Support requests follow the same pattern: researchers self-serve, coordination approves.”

### 3. Complete the admin flow

**Say:** “I will now switch roles. Scientific coordination controls what becomes institutional and public.”

> Shell note: on wide screens, admin routes (`/app/dashboard`, `/app/admin*`, `/app/settings`) show a dark left sidebar — Dashboard, People, Requests, Outputs, Structure, Settings — with amber badges on People and Requests for pending counts.

1. Sign out of the researcher account and sign in with the prepared admin account.
2. Open `/app/admin` and click the **Review** tab.
3. Open **Profiles to approve**, locate the researcher, and click **Approve**.
4. Open **Outputs to approve**, locate the claimed publication, and click **Approve**.
5. Open **Requests** in the sidebar (`/app/admin/requests`), locate the submitted support request, and click **Approve**.
6. Back in `/app/admin` → **Review**, open **Activity** and point out the recorded changes and their timestamps.

**Say:** “The queue separates self-service contribution from institutional approval, and the activity log leaves an audit trail of the decisions.”

### 4. Prove approval-driven visibility

**Say:** “Approval is what drives the website. Nobody copies anything by hand — the site is regenerated from whatever is approved at the time.”

1. Open **Actions → Sync content from Supabase → Run workflow** in the `unidcom-site` repository, leave *preview* **unticked**, and run it. It commits the changed data, which triggers the deploy.
2. While it runs, open a private or signed-out browser window so the check is genuinely anonymous.
3. Load the researcher's page on the public site and point out that the approved profile and the approved claimed publication are now there.
4. Point out that the prepared pending record is absent — it was never fetched.

**Say:** “There are two gates and they agree. Row-level security stops an unapproved row leaving the database, and the sync's own allowlist controls which fields are ever fetched — internal notes, emails and budgets are not in the query at all. Nightly, this runs itself at 04:00.”

> If the sync has not been touched, the site already reflects the last nightly run; say so rather than implying the change was instant. Approval is immediate in RIMS, visible on the site at the next sync.

### 5. Generate a report and show the dashboard

> Route note: `lib/main.dart` has no `/app/reports` route. Reports is the first tab inside `/app/admin`.

1. Return to `/app/admin` — **Reports** is already the first tab.
2. Select **Scientific Outputs**, choose the prepared year or **All**, and click **Generate PDF**.
3. Open the downloaded institutional PDF and point out the per-type statistics table.
4. Click **Dashboard** in the admin sidebar (or open `/app/dashboard`) and point to the KPI tiles and outputs-by-type view.

**Say:** “The public site, review workflow, institutional report, and dashboard use the same governed data, so the numbers can be traced back to approved records.”

## Numbers to quote

Refresh from the live database immediately before the demonstration
(queries in PLAN.md §2). Values as of 2026-08-06:

- **184** researchers in RIMS — **183** published on the website (one merged duplicate)
- **26** researchers linked to ORCID; **21 of the 46 integrated members** have no iD yet
- **365** scientific outputs — **365 approved** (100%, audit-trailed)
- **76** of those qualify as publications for the website; the other 289 are activity records
- **1,457** ORCID publication candidates staged for claiming

## Q&A preparation

**Why ORCID only in the pilot?** ORCID gives the pilot one durable researcher identity and publication source; services such as Scopus and ResearchGate can deposit works there, keeping the first workflow focused and testable.

**Where does Ciência Vitae fit?** Existing Ciência Vitae identifiers remain in researcher records, but direct integration is outside the pilot and can be added after the ORCID-led workflow is proven.

**What is Phase 2?** Phase 2 can add direct Ciência Vitae integration and modules for projects, research groups, funding, and PhD students.

**Why two systems instead of one?** The website and the portal answer to different requirements. A public site has to be fast, indexable and to survive the database being down, so it is a static Hugo build regenerated from RIMS nightly. The portal has to show live, unapproved, permission-dependent data, so it talks to Supabase directly. Approval is the boundary between them: a record reaches the site only once it passes the same gate that makes it publicly readable in the database.

**Doesn't a sync job risk the site falling behind?** It runs nightly and can be triggered on demand, and the footer states when the content was last updated, so any lag is visible rather than silent. The trade is deliberate: the site stays up and fast regardless of the database.

**What replaced Sanity?** Nothing was replaced — Sanity was the plan's suggested website layer and Hugo fills the same role, generated from RIMS instead of hand-authored. The architecture Rui's plan asked for — RIMS as the source of truth pushing validated information to a website — is what runs today.

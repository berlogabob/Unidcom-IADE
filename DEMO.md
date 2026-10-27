# UNIDCOM RIMS Pilot — Demonstration Script

## Framing

UNIDCOM RIMS is the institutional single source of truth for researcher profiles and scientific outputs. The public website is one consumer of that data, generated from it by a nightly sync. Editorial approval is the publication gate: only approved profiles and outputs reach the website, while pending records remain available for review inside RIMS.

This pilot demo takes place on Friday 2 October 2026.

Two surfaces, two URLs:

| | |
|---|---|
| Public website (Hugo) | https://berlogabob.github.io/unidcom-site/ |
| Researcher portal (RIMS) | https://berlogabob.github.io/Unidcom-IADE/ |

The portal is gated — `/login` and the Welcome Pack are its only anonymous screens.

## Demo walkthrough

### 1. Researcher: Overview (3 min)

1. Click **Overview** at `/app/home`; say: “This is where login lands: ‘UNIDCOM: To be validated by you · Website: Published’ stays at the top, and the calm banner links directly to what needs attention.”
2. Click a banner action and point at **Your record**; say: “The first line is what is live on the website and since when; the second is only the current round of changes, dated from when it started. Blue means it is UNIDCOM's turn, amber yours.”
3. Click **Edit bio**, a summary tile, and a recent output issue; say: “The overview gives the bio’s first lines, type totals, Featured N/5, and the exact issue such as ‘Missing DOI’.”

### 2. Researcher: My Profile (3 min)

1. Click **My Profile**; say: “The subtitle describes the public researcher profile, and the ORCID block shows ‘ORCID connected · Last imported …’ plus the warning that editing here does not change ORCID.”
2. Click **Import from ORCID**, the field `(i)`, **Lab / cluster**, and **Upload photo**; say: “ORCID import is explicit, every field has guidance, and photos go to UNIDCOM review.”
3. Click **Edit bio**, **Save draft**, then **Submit for UNIDCOM review**; say: “The bio shows a soft N / 300 counter, featured outputs are read-only with ‘Manage in Scientific Outputs →’, and submission is separate.”

### 3. Researcher: Scientific Outputs (3 min)

1. Click **Scientific Outputs** and **N new publications in ORCID → Review**; say: “New ORCID publications are a review queue, not automatic publication.”
2. Click **All**, **Publications**, **Other activities**, a type/subtype chip, a year chip, **Issues only** and **Not affiliated**; say: “The filtered counters, full issue text, and the Not affiliated pill on work from before UNIDCOM explain exactly what is being reviewed.”
3. Click a publication star and **Submit for UNIDCOM review (N)**; say: “Only publications can be featured, with a maximum of five, and imported outputs remain ‘To be validated by you’ until submitted.”

### 4. Admin: Approval pipeline (3 min)

1. Click **Admin** and show the dashboard; say: “Admin sees numbers only for integrated researchers, collaborators, profiles to approve, outputs to approve, ORCID and Website sync lines, researcher activity, issues, outputs by type with year chips, and critical alerts that open the researcher.”
2. Click **Pending approval**: **To review** lists who is waiting; open a researcher, decide each card (Accept / Reject / Request change) and click **Finish review**. Then **Ready to publish**: select researchers, **Publish selected to website**; finally **More → Website → Sync to website**. Say: “Accepting never publishes; publishing is a separate batch.” Older path: click **People**, then **Pending approval → More → Profiles**; say: “People carry a Website pill, and the pipeline separates To validate, Submitted, Approved, not published, and Published.”
3. Click **Approve**, then later **Publish to website** for one real profile; say: “Approval and website publication are deliberately two separate decisions.”

### 5. Website: Publish one profile (3 min)

1. Click the profile’s **Publish to website** action; say: “Nothing is published automatically: this profile is now approved and explicitly released.”
2. Run **Sync content from Supabase** in the `unidcom-site` workflow, or explain the nightly **04:00 UTC** run; say: “The sync puts published profiles on the UNIDCOM site.”
3. Open the [public site](https://berlogabob.github.io/unidcom-site/) and the same profile; say: “This is the end-to-end proof: Submitted, Approved, Publish to website, then visible on the public site.”

## Numbers to quote

- **365** outputs and **184** profiles imported; all have been **To be validated by the researcher** since 29 September.
- **76** publications and **183** profiles are on the website.
- **330** automated tests.
- Acceptance map: **68 done / 5 partial**.

## Q&A preparation

**Why two systems instead of one?** The website and the portal answer to different requirements. A public site has to be fast, indexable and to survive the database being down, so it is a static Hugo build regenerated from RIMS nightly. The portal has to show live, unapproved, permission-dependent data, so it talks to Supabase directly. Approval is the boundary between them: a record reaches the site only once it passes the same gate that makes it publicly readable in the database.

**Doesn't a sync job risk the site falling behind?** It runs nightly and can be triggered on demand, and the footer states when the content was last updated, so any lag is visible rather than silent. The trade is deliberate: the site stays up and fast regardless of the database.

**Why is coverage partial?** Coverage is not on every action.

**Why are the sidebar and secondary text unchanged?** The sidebar keeps `#0E1525` and secondary text `#6A6862` for contrast.

**Why are there no semester tabs?** Outputs have only a reporting year.

**Why is there no separate Under review column?** The pipeline has four columns, with review represented by its existing states.

**How is the public-site step demonstrated?** With one real profile followed from submission through publication.

# Architecture

How the UNIDCOM RIMS pieces fit together, across both repositories. Written for
someone who has just cloned either one and is wondering where anything is.

Accurate as of 30 Sep 2026 (Phase E).

## Two surfaces, two repositories

| | Public website | Researcher portal |
|---|---|---|
| Repo | [`unidcom-site`](https://github.com/berlogabob/unidcom-site) | `Unidcom-IADE` (this one) |
| Built with | Hugo, static HTML | Flutter web, single-page app |
| URL | `berlogabob.github.io/unidcom-site/` | `berlogabob.github.io/Unidcom-IADE/` |
| Audience | anyone | UNIDCOM researchers and administrators |
| Reads the database | never — it is generated from it | live, under row-level security |
| Anonymous access | the whole site | `/login` and `/app/welcome/*` only |

They are separate because they answer to different requirements. A public site
has to be fast, indexable, and to survive the database being down, so it is a
static build regenerated nightly. A portal has to show live, unapproved,
permission-dependent data, so it talks to Supabase directly.

The website is the entry point. It links into the portal from the navigation,
the footer, every person page, and a `/researchers/` page.

## Navigation

One left-hand `SideNav` (`lib/widgets/side_nav.dart`) is the whole navigation,
in every mode: a 240 px column at ≥ 900 px, a drawer behind a hamburger below.
What it lists comes from `lib/widgets/nav_model.dart` — `researcherNav(signedIn:)`
(anonymous visitors get only the Welcome-pack material and Sign in) and
`adminNav()`. The researcher nav is one-to-one with the 8 Sep 2026 tree:
six collapsible sections (collapse state in sessionStorage, per tab) and one
page per leaf — leaves not built yet render a "Work in progress" page
(`WipPage`) rather than being left out. The admin nav is reduced to the pages
that exist; its unbuilt IA items are a comment in the model. `navSelected()`
picks the highlighted row and the phone app-bar title. Until 8 Sep the portal
had five navigation surfaces (admin top bar, admin-only sidebar, phone bottom
bar, researcher tab strip, Welcome-pack inner nav); `test/nav_model_test.dart`
keeps every listed route real and the anonymous list anonymous. The sidebar is
ergonomics only — `modeRedirect` / `needsAuth` in `main.dart` and RLS decide
what anyone can reach. The pilot researcher surface keeps a compact status line
on every page; Overview contains **Your record**, bio and summary tiles. Your
record is two lines because the profile loops (approved, edited, reviewed
again): what is live on the website (dated by the last approval), then the
current round Draft → Submitted → Under review → Approved, dated from
`round_started_at`. Colour says whose turn it is: green done/live, amber the
researcher's, blue UNIDCOM's, red changes requested, grey not yet — always with
an icon and words. My Profile uses **Import from ORCID** (fills the form; not
sync), info icons, draft/submit actions, reviewed photo suggestions and a
**Your changes** panel listing the researcher's draft and sent changes.
Scientific Outputs uses All / Publications / Other activities, type chips in
English (the taxonomy stays Portuguese in the data, `rootLabelsEn`), year
chips, an affiliation filter and counters. Management/support activities and
international missions are not scientific outputs and are hidden
(`hiddenRoots`). Work outside UNIDCOM is listed with an amber **Not affiliated**
pill and never featured; only publications can be starred (up to five). The
larger legacy controls remain behind the v2 flag.

## Data flow

```
Supabase                    scripts/sync.py            Hugo              GitHub Pages
(source of truth)  ───────► data/generated/*.json ───► content adapters ─► static HTML
                            (committed to git)         + themes/unidcom

                   ───────► Flutter web app (this repo), reading live under RLS
```

The sync lives in the *site* repo (`unidcom-site/scripts/sync.py`) and runs
nightly at 04:00 UTC via `.github/workflows/sync.yml`, or on demand through the
**Sync content from Supabase** workflow, committing any change to
`data/generated/`. Content changes are therefore commits, visible in `git log`
and revertible. The site never holds credentials: a deploy builds from the
committed JSON alone.

## Review and publication are separate gates

Review states are separate from publication. Outputs use
`to_validate | pending | approved | rejected`; people use
`to_validate | draft | pending_review | under_review | approved`. All imported records were
moved to `to_validate` on 29 Sep 2026 (365 outputs and 184 profiles).
Researchers submit outputs with `submit_my_outputs()` and profiles to
`pending_review`; UNIDCOM approves them.

Profile edits travel as `enrichment_suggestions` rows (`source='researcher'`,
`draft` until submitted, then `pending`). A trigger keeps one open row per
subject and field: a newer edit marks older draft/pending rows `superseded`, so
Save draft followed by Submit never reaches UNIDCOM twice. Admins see each as
"Bio · Proposed by the researcher · date / Now / Proposed"; ORCID and Crossref
matches say "Found on ORCID · N% match".

Approval does not publish. An output is on the website when
`website_status = 'published'` and it is not rejected; a person is on the
website when `public_visibility = true`. Admins make that separate decision
with **Publish to website** in **Pending approval → Pipeline**. The sync follows
those flags, so approving a profile no longer publishes it.

### Review and publish (v1.1, 9 Oct 2026)

Pending approval has two tabs. **To review** lists researchers with open items;
a researcher review shows one card per change (profile fields from
`enrichment_suggestions`, new outputs from `outputs`) with Accept, Reject and
Request change. **Finish review** calls `finish_review()` (admin-only, atomic,
audited in `change_log`): accepted items become `ready`, the rest go back to the
researcher with the comment (`enrichment_suggestions.review_comment`,
`outputs.review_note`). Accepting does **not** write the value into `people`, so
the site keeps the published version. **Ready to publish** calls
`publish_researchers(ids[])`, which applies the accepted values, sets
`people.website_status/public_visibility/published_at` and
`outputs.website_status='published'`, and returns a result per researcher
(`error` + Retry). **More → Website** shows what the next sync will publish and
dispatches the site's sync workflow through the `website-sync` edge function
(secret `GITHUB_SYNC_TOKEN`; admin-only; always `preview=false`).

## Website content and the Sanity bridge

The UNIDCOM website's CMS is Sanity (schema in `RAW_DATA/unidcom-cms-schema`;
no localization). The portal holds the editable copy of everything the site
shows about people and research, and `sanity-push` sends it one way: **portal
wins on the fields the portal holds; every other field on the Sanity document
(`seo`, member CV arrays, page-builder pages, podcasts, proceedings, positions,
testimonials) is never touched.** Nothing is read back from Sanity.

| Sanity type | Portal source | Edited in |
|---|---|---|
| `member` | `people` (published, not merged): name, bio, ORCID, Ciência ID, `research_interests`, `board_role`, `photo_url` | person dialog |
| `project` | `projects` (`public_visibility`) + `project_members` (role → pi/coPi/supervisors/mentors/phdStudents/members), `project_clusters`, `funders` | project dialog |
| `lab` | `labs` + `lab_members` (`is_coordinator`), `project_labs` | lab editor |
| `cluster` | `clusters` (`description` is the website text; `notes` stays internal) | cluster editor |
| `researchOutput` | `outputs` (`website_status='published'`, not merged) + `output_authors`; `keywords` | output editor (admin) |
| `funder`, `article`, `event` | `funders`, `articles`, `events` (articles/events only when `published`) | More → Website → Website content |

Images (member photo, project cover, lab logo/cover, funder logo, article image,
event cover) are public URLs; admins upload to the `site-images` bucket
(researcher photos keep the `people-photos` review flow). `sanity-push` downloads
each and uploads it as a Sanity asset (Sanity dedupes identical files).

`sanity-push` (admin-only, secret `SANITY_TOKEN`) takes `{types?: [...]}`, pushes
in dependency order (funders, members, clusters, outputs, projects, labs,
articles, events), batches 100 mutations per request and writes each document id
back to `<table>.sanity_id` so the next push updates the same document. Existing
members are matched to their Sanity document by slug. Status mapping:
planned/active → `ongoing`, completed → `completed`. The target is the **test
project `ld5jhf23`**; `vj0axykv` (the agency's, which the live site reads) is
refused unless the secret `ALLOW_PROD=true` is set. Mapping lives in
`supabase/functions/sanity-push/mutations.ts` (tested in `mutations_test.ts`).

## Two privacy boundaries, and they are not the same filter

This is the part most worth understanding before changing anything.

**Row-level security decides which *rows* a signed-in caller may read.** The
public website is generated by the service-role sync and follows the explicit
publication flags above; it is not an anonymous Supabase table client.

**Grants decide which *tables* a role may touch at all.** Since
`20260806150100_revoke_anon_public_schema.sql`, `anon` has **none** — no
select, no write, on any table. Signing in uses GoTrue rather than PostgREST,
so the login screen is unaffected.

No `SECURITY DEFINER` function is callable by `anon` (checked 30 Sep). The
Sanity bridge RPCs are service-role-only for the bridge, with admin/service-role
access for the admin bridge operations.

**`sync.py`'s allowlist decides which *fields* ever leave the database.** Every
record is assembled by an explicit `pick()`, and `assert_whitelist()` fails the
run if a record carries a key outside its declared set. `email`, `legal_name`,
`auth_user_id`, `notes`, `total_budget` and `risk` are never even fetched.
This is load-bearing on its own: the nightly workflow authenticates with the
service key, which bypasses row-level security entirely.

> **Why all three.** An earlier version of this document described only the
> first and the third, and called them complementary. They are not: **RLS has
> no column dimension.** A policy says which rows come back, never which
> columns, so once the 2026-08-05 bulk approval made every `people` row
> readable, every `people` *column* was readable too — 153 researcher email
> addresses, `legal_name` and `notes`, to anyone holding the publishable key
> that ships in the public JS bundle. `sync.py`'s careful field allowlist was
> guarding one door while another stood open beside it. The grant layer is what
> actually closes it. If a public directory is ever restored to the app,
> re-grant **explicit columns** — never a bare `grant select on public.people`.

A third, separate gate exists on the website only — a fail-closed content-type
allowlist, because the database doubles as UNIDCOM's internal FCT reporting
tool and holds rows that must never be public whatever their approval state
(thesis-jury records naming students, internal governance planning). See
"Why isn't my record on the site?" in the site's README.

## Authentication

Sign-in is ORCID, brokered by a Supabase edge function
(`supabase/functions/orcid-auth/index.ts`). The broker exchanges the OAuth code,
then applies a **registry gate**: it looks the iD up in `people.orcid` and
refuses anyone it does not find —

> No UNIDCOM profile is registered for ORCID iD … Contact an admin.

So a researcher cannot sign in until an administrator has put their iD on file.
This is why the public site only offers the sign-in link on profiles that have
one, and shows a contact-the-office note on the rest.

On success the broker mints a magic link and redirects back with a
`token_hash`; `main()` verifies it and claims the matching person row. Hash
routing puts that parameter *before* the `#`, so it is read from `Uri.base`
rather than from the router — see the comments in `lib/main.dart`.

After authentication, a researcher lands on `/app/home` (Overview); an admin in
admin mode lands on `/app/dashboard`. The route gate itself is one function,
`needsAuth` in `lib/main.dart`:

```dart
bool needsAuth(String location) =>
    location != '/login' && !location.startsWith('/app/welcome');
```

The Welcome pack stays anonymous deliberately: a researcher arrives from the
public site and should be able to read the onboarding material before they have
an account.

## Where things live

| | |
|---|---|
| `lib/public/` | the directory — people, outputs, projects, structure. **Internal now**, despite the name; renaming it would touch every import and every historical brief for no behavioural gain |
| `lib/app/` | the portal proper — profile, requests, dashboard, admin, Welcome pack |
| `lib/data/supabase.dart` | every query in the app |
| `supabase/migrations/` | 30 migrations; schema, RLS and the audit triggers |
| `supabase/functions/` | `orcid-auth` (sign-in broker), `report` (Typst → PDF) |
| `scripts/` | Python batch jobs — import, enrich, ORCID works, DOI checks |
| `.maestro/` | four end-to-end flows |

## Further reading

- `README.md` — running, testing and deploying this repo
- `PLAN.md` — the pilot tracker, and the record of why each decision was taken
- [`unidcom-site/README.md`](https://github.com/berlogabob/unidcom-site) — the website runbook, the sync, and the two site-side gates in full
- `docs/reports/2026-08-pilot-delivery/` — the stakeholder-facing delivery report

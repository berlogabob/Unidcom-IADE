# Architecture

How the UNIDCOM RIMS pieces fit together, across both repositories. Written for
someone who has just cloned either one and is wondering where anything is.

Accurate as of 2026-08-06.

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

## Data flow

```
Supabase                    scripts/sync.py            Hugo              GitHub Pages
(source of truth)  ───────► data/generated/*.json ───► content adapters ─► static HTML
                            (committed to git)         + themes/unidcom

                   ───────► Flutter web app (this repo), reading live under RLS
```

The sync lives in the *site* repo (`unidcom-site/scripts/sync.py`) and runs
nightly at 04:00 UTC via `.github/workflows/sync.yml`, committing any change to
`data/generated/`. Content changes are therefore commits, visible in `git log`
and revertible. The site never holds credentials: a deploy builds from the
committed JSON alone.

## Approval is the publication gate

One flag, two consumers. A record becomes public when an administrator approves
it — `people.profile_status = 'approved'` plus `public_visibility`, or
`outputs.approval_status = 'approved'`. That single act both makes the row
readable by an anonymous caller *and* determines what the next sync publishes.

Approval is immediate in the portal and appears on the website at the next sync,
so there is a bounded lag, stated in the site footer.

## Two privacy boundaries, and they are not the same filter

This is the part most worth understanding before changing anything.

**Row-level security decides which *rows* an unauthenticated caller may read.**
See `supabase/migrations/20260805120000_approval_visibility.sql`: anonymous
callers see only approved, publicly visible people, projects and outputs.
Everything else in the portal requires a session.

**`sync.py`'s allowlist decides which *fields* ever leave the database.** Every
record is assembled by an explicit `pick()`, and `assert_whitelist()` fails the
run if a record carries a key outside its declared set. `email`, `legal_name`,
`auth_user_id`, `notes`, `total_budget` and `risk` are never even fetched.

The second is load-bearing on its own: the nightly workflow authenticates with
the service key, which bypasses row-level security entirely. RLS protects the
portal's anonymous surface; the allowlist protects the website's.

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

The route gate itself is one function, `needsAuth` in `lib/main.dart`:

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

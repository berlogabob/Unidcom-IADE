# UNIDCOM RIMS — researcher portal

The Flutter web app UNIDCOM researchers sign in to: confirm your profile and
manage your publications. Administrators approve that work here too, in a
separate view of the same app — see "Two builds" below for what the pilot
cohort actually sees.

**This is not the public website.** That is a separate repository,
[`unidcom-site`](https://github.com/berlogabob/unidcom-site) — a Hugo static
site generated from the same database. This app is gated: `/login` and the
Welcome pack (`/app/welcome/*`) are its only anonymous screens.

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the two fit together, where
approval sits, and why there are two different privacy boundaries.

| | |
|---|---|
| Portal | https://berlogabob.github.io/Unidcom-IADE/ |
| Public website | https://berlogabob.github.io/unidcom-site/ |

## Prerequisites

- Flutter **3.44.7** (the version CI pins)
- A Supabase project — URL and publishable key are passed as `--dart-define`s;
  the defaults in `lib/main.dart` point at the pilot project
- [uv](https://docs.astral.sh/uv/) for anything under `scripts/`
- [Maestro](https://maestro.dev) and a JDK for the end-to-end flows

## Run

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

## Two builds: v1 and v2

The pilot ships **v1** — deliberately fewer controls, all of them working. The
rest is compiled out behind one flag rather than deleted:

```sh
flutter run -d chrome                        # v1 — what the pilot cohort sees
flutter run -d chrome --dart-define=V2=true  # v2 — everything
```

Hidden in v1: Support requests (tab, routes and admin queue), the Approve
button, Auto-fill, ORCID sync, Find DOI. See `lib/data/features.dart` for why,
in the director's own words.

## Who can write what

A researcher has **no write grant on `outputs` or `output_authors`** — both
policies are `is_admin()` and stay that way. They record their own work through
`create_my_output()`, a `security definer` RPC that takes a whitelisted payload
and forces `approval_status='pending'`, `source='manual'` and
`affiliation='unidcom'` whatever the caller sends. It links the author row and
writes the `change_log` entry itself, which is the only way a non-admin action
gets audited at all: `cl_write` is admin-only, so the client's `logChanges()`
is silently discarded for everyone else.

Admins insert directly, through `createOutput`. Both routes open the same
dialog, so the taxonomy cascade is the only way a category is ever set.

Because `flutter analyze` and `flutter test` only ever see v1, CI carries a
`--dart-define=V2=true` build step — it is the only thing that catches a break
inside a `if (v2)` branch before someone flips the flag.

## Test

```sh
flutter analyze
flutter test            # 114 tests
```

### End-to-end

Flutter web draws to a canvas, so Maestro sees nothing until the semantics tree
exists. `--dart-define=E2E=true` turns it on; it is off in production, where an
always-on semantics tree is wasted work.

```sh
flutter build web --dart-define=E2E=true
python3 -m http.server 8123 --directory build/web
maestro test .maestro/auth_gate.yaml -e MAESTRO_EMAIL=... -e MAESTRO_PASSWORD=...
```

Six flows:

| Flow | Covers | Needs credentials |
|---|---|---|
| `auth_gate.yaml` | anonymous visitors are bounced to `/login`; login lands on the Welcome pack; no gated navigation is offered anonymously | yes |
| `researcher_mode.yaml` | researcher mode offers only the researcher's own things — no directory, no Support requests, no Approve on your own profile | yes |
| `admin_mode.yaml` | admin mode keeps the whole centre, and the switch works both ways without signing out | yes, admin |
| `support_request.yaml` | full request lifecycle — create, submit, admin approve. **v2 only** | yes |
| `featured_star.yaml` | star an output on a profile, survive a reload, unstar | yes |
| `orcid_error.yaml` | the ORCID broker's failure return-trip is shown, not swallowed | no |

`support_request.yaml` needs `--dart-define=V2=true` on the build as well as
`E2E=true`; under v1 the routes it drives do not exist.

Note that **every account in the database currently holds the admin role**, so
all of them meet the chooser after signing in. There is no non-admin account to
test the plain-researcher path with yet — see `PLAN.md` on the pilot cohort.

Credentials live in `.maestro/.env` (gitignored; see `.env.example`). Maestro's
CLI has no `--env-file`, so pass them with `-e`, or source the file first.

Two gotchas that will cost you an hour otherwise:

- If `JAVA_HOME` points at Android Studio's bundled JRE, Maestro refuses to
  start. Point it at a real JDK for the run.
- The browser caches `main.dart.js`. `clearState` usually handles it; if a
  rebuild silently isn't the app under test, add a cache-busting query
  (`?v=2#/route`).

`support_request.yaml` leaves an `E2E Test Request` row behind — delete it after
a run.

## Deploy

Push to `main`. `.github/workflows/deploy.yml` runs `flutter analyze` and
`flutter test` as a gate, then builds with `--base-href /Unidcom-IADE/` and
publishes to GitHub Pages. No secrets: the Supabase URL and publishable key are
compiled in, and both are public by design.

Two scheduled jobs also run here:

| Workflow | When | What |
|---|---|---|
| `orcid-sync.yml` | Mondays 05:00 UTC | stages new ORCID works into `output_candidates` |
| `doi-check.yml` | Mondays 06:00 UTC | checks recorded DOIs still resolve |

The website's nightly sync is **not** in this repo — it lives in `unidcom-site`.

## Supabase

`supabase/migrations/` holds 33 migrations: schema, row-level security, and the
audit triggers that write every status change to `change_log`. Two edge
functions live in `supabase/functions/` — `orcid-auth` (the sign-in broker) and
`report` (Typst → PDF). The report function has Deno tests:

```sh
deno test supabase/functions/report/
deno test supabase/functions/orcid-auth/
```

## Documentation

| | |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | how both repositories fit together |
| [OPERATIONS.md](OPERATIONS.md) | backups, secrets, access, incidents, supporting researchers |
| [AUDIT.md](AUDIT.md) | 2026-08-07 review: what was fixed, what is still open |
| [PLAN.md](PLAN.md) | pilot tracker, decisions and their rationale |
| [ONBOARDING.md](ONBOARDING.md) | what a researcher joining the pilot needs to do |
| [DEMO.md](DEMO.md) | demonstration script |
| `docs/reports/2026-08-pilot-delivery/` | stakeholder delivery report (Typst + PDF) |
| `docs/research/2026-09-rims-best-practices.md` | cited RIMS/CRIS best-practice research, framework matrix, BP-01…38 checklist |
| `audit/2026-09-09-1136/` | UX/UI audit run: screenshots, hierarchies, flow results, `findings.json`, `report.md` (`audit/tools/` reruns it) |
| `docs/reports/2026-09-ux-audit/` | stakeholder UX audit report (Typst + PDF); `ux-audit-summary.pdf` is the 2-page version |

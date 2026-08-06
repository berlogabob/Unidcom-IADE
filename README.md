# UNIDCOM RIMS — researcher portal

The Flutter web app UNIDCOM researchers sign in to: confirm your profile, manage
your selected publications, and file support requests. Administrators approve
that work here too.

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

## Test

```sh
flutter analyze
flutter test            # 49 tests
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

Four flows:

| Flow | Covers | Needs credentials |
|---|---|---|
| `auth_gate.yaml` | anonymous visitors are bounced to `/login`; login lands on the Welcome pack; no gated navigation is offered anonymously | yes |
| `support_request.yaml` | full request lifecycle — create, submit, admin approve | yes |
| `featured_star.yaml` | star an output on a profile, survive a reload, unstar | yes |
| `orcid_error.yaml` | the ORCID broker's failure return-trip is shown, not swallowed | no |

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

`supabase/migrations/` holds 30 migrations: schema, row-level security, and the
audit triggers that write every status change to `change_log`. Two edge
functions live in `supabase/functions/` — `orcid-auth` (the sign-in broker) and
`report` (Typst → PDF). The report function has Deno tests:

```sh
deno test supabase/functions/report/
```

## Documentation

| | |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | how both repositories fit together |
| [PLAN.md](PLAN.md) | pilot tracker, decisions and their rationale |
| [ONBOARDING.md](ONBOARDING.md) | what a researcher joining the pilot needs to do |
| [DEMO.md](DEMO.md) | demonstration script |
| `docs/reports/2026-08-pilot-delivery/` | stakeholder delivery report (Typst + PDF) |

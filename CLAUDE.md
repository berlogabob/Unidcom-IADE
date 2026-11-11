# CLAUDE.md

UNIDCOM RIMS researcher portal: Flutter web (`lib/`) on Supabase
(`supabase/migrations`, `supabase/functions` in Deno). Public website = Hugo
in the sibling repo `unidcom-site`, plus a Sanity CMS fed by `sanity-push`.

Read before changing anything: [CONTRIBUTING.md](CONTRIBUTING.md) (team flow,
migration rules), [ARCHITECTURE.md](ARCHITECTURE.md), and the end of
[PLAN.md](PLAN.md) (current phase and open items).

## Rules

- Work on a branch and open a PR. Never push to `main`, because `main` deploys.
- Check with `flutter analyze` (0 issues) and `flutter test`. For edge functions
  run `deno test -A supabase/functions/<name>/`.
- Python under `scripts/` runs with `uv` only (`uv run --project scripts ...`).
- The Supabase project is live production, and there is no staging DB. Ask
  before running any write or migration. After applying a migration, rename
  its file to the live version from `list_migrations`.
- Roles come from `public.user_roles` and `has_perm()`, not JWT claims. See
  OPERATIONS.md "Roles".
- Sanity: push only to the test project `ld5jhf23`. `vj0axykv` is the agency's
  live site and is refused unless `ALLOW_PROD=true` is set. Don't set it.
- The repo is public. Never commit emails, personal data, Sanity dumps or admin
  screenshots.
- All data access goes through `lib/data/supabase.dart`.
- v2-only UI hides behind `--dart-define=V2=true` (`lib/data/features.dart`).
  CI builds both.

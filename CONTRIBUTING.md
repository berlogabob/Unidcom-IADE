# Working on this repo as a team

From 11 Nov 2026 several people work here: some by hand, some with Claude
Code. The rules below are the same for both.

Snapshot before team work started: branch `backup/2026-11-11-pre-team` and tag
`backup-2026-11-11-pre-team`. Nobody pushes to them.

## Flow

1. `git pull` on `main`, then branch: `feat/<short-name>`, `fix/<short-name>`
   or `docs/<short-name>`. One task per branch.
2. Before pushing, run:
   ```sh
   flutter analyze          # must say "No issues found"
   flutter test             # 667 tests at 11 Nov 2026
   ```
   For edge functions also run `deno test -A supabase/functions/<name>/`.
3. Push the branch and open a PR to `main`. CI (`.github/workflows/ci.yml`)
   runs analyze, test, the v2 build, the Deno tests and the Python
   compile-check. Merge only on green.
4. **Merging to `main` deploys.** `deploy.yml` publishes the portal to GitHub
   Pages on every push to `main`. Don't push straight to `main`.

## Database (Supabase project `sbswpbsibvvfgnmdyxrg`, live)

There is no staging database: a migration applied there is applied to
production.

- A schema change is a file in `supabase/migrations/`. Additive changes only,
  unless the PR says why.
- **The file name must match the version recorded live.** Applying through the
  Supabase MCP or dashboard stamps the current time, not your file name. After
  applying, compare with `list_migrations` (MCP) or `supabase migration list`,
  and rename the file to the live version in the same PR. Local and live must
  stay 1:1 (52 / 52 at 11 Nov 2026), or `supabase db push` re-applies old
  migrations.
- One person applies migrations at a time. Say so in the team chat first.
- RLS, auth and `SECURITY DEFINER` changes need a second reviewer.

## Public repo: never commit personal data

This repository is public. Never commit researcher emails, auth exports, Sanity
dumps, admin screenshots (they show the signed-in email) or CSVs from the
database. `.gitignore` already covers `sanity-dump/`, `RAW_DATA/`, `notes/`,
audit `screens/`, report `*.csv` and `shots/`. Check `git status` before
`git add -A`.

Secrets live in Supabase secrets/Vault and `scripts/.env` (ignored). See
[OPERATIONS.md](OPERATIONS.md).

## Where to read first

[README.md](README.md) covers run, test and deploy.
[ARCHITECTURE.md](ARCHITECTURE.md) covers how the portal, website and Sanity
fit together. [OPERATIONS.md](OPERATIONS.md) covers backups, secrets and roles.
[PLAN.md](PLAN.md) is the tracker: open items are the unticked boxes at the end.

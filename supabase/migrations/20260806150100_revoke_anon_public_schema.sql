-- The people/report_data revoke closed two instances; this closes the class.
--
-- The default Supabase template grants ALL on every table in `public` to
-- `anon`, leaving RLS as the only thing between an unauthenticated request and
-- a write. Measured before this migration:
--
--   * projects exposed total_budget, risk and notes to anon — precisely the
--     fields scripts/sync.py's allowlist is written to withhold, so the
--     "field boundary" documented in ARCHITECTURE.md was being bypassed;
--   * anon held INSERT/UPDATE/DELETE/TRUNCATE on all 27 tables. RLS covered
--     the writes, but a single mistaken policy would then have been a
--     data-loss vector rather than a read leak — and TRUNCATE is not subject
--     to RLS at all.
--
-- This system has no anonymous consumer of the database:
--   * the Flutter app is gated — needsAuth() admits only /login and
--     /app/welcome/*. Sign-in talks to GoTrue, not PostgREST, so it is
--     unaffected by table grants (verified: /auth/v1/settings still 200).
--   * scripts/sync.py authenticates with the service key;
--   * the public website is static HTML built from committed JSON.
--
-- `authenticated` and `service_role` keep everything they had. Verified after
-- applying: all four Maestro flows green (anonymous bounce, login, signed-in
-- directory, admin approve, write round-trip) and the nightly sync run
-- produced its usual "people 183  projects 25  publications 76".
--
-- NOTE: this makes the service key genuinely required for scripts/sync.py.
-- It appeared to work with the publishable key before — that was this
-- vulnerability, not a feature.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- Stop the default reappearing on the next table someone creates.
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;

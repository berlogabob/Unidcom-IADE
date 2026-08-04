-- Security-advisor fixes (Supabase linter, 2026-08-04 sweep).
-- 1. Pin search_path on the three pre-pilot functions (newer ones already pin).
--    Note: on is_admin() this trades away SQL inlining in RLS policies —
--    irrelevant at this scale (~360 rows max).
alter function public.is_admin() set search_path = public;
alter function public.protect_people_cols() set search_path = public;
alter function public.protect_person_roles() set search_path = public;

-- 2. Shrink the anonymous RPC surface. In-body is_admin()/owner gates already
--    protect these, but anon has no business reaching them at all.
--    `authenticated` keeps merge/promote: admins are authenticated + JWT claim.
revoke execute on function public.merge_outputs(uuid, uuid[], jsonb) from public, anon;
revoke execute on function public.merge_people(uuid, uuid[], jsonb) from public, anon;
revoke execute on function public.promote_output_candidate(uuid, text) from public, anon;

-- 3. Trigger-only helpers are not an API: nobody calls these over PostgREST.
--    (Triggers keep firing — trigger execution rides on the owner, not these grants.)
revoke execute on function public.log_status_change() from public, anon, authenticated;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- Not fixed, recorded in PLAN.md: pg_trgm/unaccent live in schema public
-- (moving breaks index/generated-column deps for zero practical gain here);
-- leaked-password protection is a dashboard Auth toggle, not SQL.

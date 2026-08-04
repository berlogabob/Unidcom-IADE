-- Close the test period: the public site now shows only approved content.
-- This IS the pilot's "automatic synchronisation with the website" — the SPA
-- reads live under RLS, so approval is publication. Executed after the
-- 2026-08-05 bulk approval of the vetted imports (362 outputs, 184 profiles,
-- 33 projects — audited in change_log), so the site does not go empty.
-- Exactly the revert block promised in 20260722160000_public_read_test_period.sql.
alter policy people_read on public.people using (
  (public_visibility and profile_status = 'approved') or auth.uid() is not null);
alter policy outputs_read on public.outputs using (
  approval_status = 'approved' or auth.uid() is not null);
alter policy projects_read on public.projects using (
  (public_visibility and approval_status = 'approved') or auth.uid() is not null);

-- TEST PERIOD: open read to everyone (anon) so reviewers see all rows.
-- Writes stay admin-only (*_write / people_update policies unchanged).
-- Revert with the block at the bottom to close the test period.
alter policy people_read   on public.people   using (true);
alter policy outputs_read  on public.outputs  using (true);
alter policy projects_read on public.projects using (true);

-- REVERT (run to close the test period):
-- alter policy people_read on public.people using (
--   (public_visibility and profile_status = 'approved') or auth.uid() is not null);
-- alter policy outputs_read on public.outputs using (
--   approval_status = 'approved' or auth.uid() is not null);
-- alter policy projects_read on public.projects using (
--   (public_visibility and approval_status = 'approved') or auth.uid() is not null);

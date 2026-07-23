-- change_log: one flat row per field change, written at the app's write choke
-- points (updatePerson / updateOutput / acceptSuggestion / ORCID matrix apply).
-- The "what / how / when" substrate for the Activity view and future ORCID sync.
-- ponytail: one table, one insert per change — NOT an event-sourcing engine.

create table public.change_log (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null,               -- person | output | lab_member | mentorship
  subject_id uuid,
  field text,
  old_value text,
  new_value text,
  source text default 'manual',             -- manual | orcid | crossref | import | sync_out
  actor uuid references auth.users on delete set null,   -- who made the change (auth user)
  changed_at timestamptz default now()
);
create index change_log_subject_idx on public.change_log (subject_type, subject_id);
create index change_log_changed_idx on public.change_log (changed_at desc);

-- ============================================================ RLS
alter table public.change_log enable row level security;
-- Audit trail is admin-only (both read and write); matches the enrichment_suggestions convention.
create policy cl_read  on public.change_log for select using (public.is_admin());
create policy cl_write on public.change_log for all using (public.is_admin()) with check (public.is_admin());

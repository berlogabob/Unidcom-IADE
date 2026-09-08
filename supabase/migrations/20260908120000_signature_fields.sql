-- Email signature needs a job title and a phone; neither existed (2026-09-08).
alter table public.people add column if not exists job_title text;
alter table public.people add column if not exists phone text;

-- Researchers propose corrections to their own row through the same staging
-- table ORCID/Crossref use; an admin accepts or rejects in the Review queue.
-- They may only stage rows about themselves, only from source 'researcher'.
create policy es_owner_insert on public.enrichment_suggestions
  for insert to authenticated
  with check (
    subject_type = 'person' and source = 'researcher'
    and subject_id in (select id from public.people where auth_user_id = auth.uid())
  );
create policy es_owner_select on public.enrichment_suggestions
  for select to authenticated
  using (
    subject_type = 'person'
    and subject_id in (select id from public.people where auth_user_id = auth.uid())
  );

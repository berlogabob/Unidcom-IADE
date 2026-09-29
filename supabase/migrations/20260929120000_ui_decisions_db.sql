-- Rui, 25 Sep 2026 ("UI decisions for the pilot") — database half of Phase E Stage 2.

-- E3.1 Overview timeline. Publication of a person is its own event now
-- (approve != publish), so log it like profile_status.
drop trigger if exists trg_log_profile_visibility on public.people;
create trigger trg_log_profile_visibility after update on public.people
  for each row when (old.public_visibility is distinct from new.public_visibility)
  execute function public.log_status_change('person', 'public_visibility');

-- change_log is admin-read; the researcher gets their own dates through this.
create or replace function public.my_profile_timeline()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'profile_status',    p.profile_status,
    'public_visibility', p.public_visibility,
    'created_at',        p.created_at,
    'submitted_at', (select max(changed_at) from change_log c
                      where c.subject_type = 'person' and c.subject_id = p.id
                        and c.field = 'profile_status' and c.new_value = 'pending_review'),
    'approved_at',  (select max(changed_at) from change_log c
                      where c.subject_type = 'person' and c.subject_id = p.id
                        and c.field = 'profile_status' and c.new_value = 'approved'),
    'published_at', (select max(changed_at) from change_log c
                      where c.subject_type = 'person' and c.subject_id = p.id
                        and c.field = 'public_visibility' and c.new_value = 'true')
  )
  from people p
  where p.auth_user_id = auth.uid() and p.merged_into is null
  limit 1;
$$;
revoke all on function public.my_profile_timeline() from public, anon;
grant execute on function public.my_profile_timeline() to authenticated;

-- E4.6 "Save draft" on My Profile: a researcher's proposed change can be a
-- draft (invisible to the admin queue, which reads status = 'pending') until
-- "Submit for UNIDCOM review" flips it.
alter table public.enrichment_suggestions drop constraint enrichment_suggestions_status_check;
alter table public.enrichment_suggestions add constraint enrichment_suggestions_status_check
  check (status in ('draft','pending','accepted','rejected'));

drop policy if exists es_owner_update_draft on public.enrichment_suggestions;
create policy es_owner_update_draft on public.enrichment_suggestions
  for update to authenticated
  using (status = 'draft' and source = 'researcher'
         and subject_type = 'person'
         and subject_id in (select id from people where auth_user_id = auth.uid()))
  with check (status in ('draft','pending') and source = 'researcher'
              and subject_type = 'person'
              and subject_id in (select id from people where auth_user_id = auth.uid()));

drop policy if exists es_owner_delete_draft on public.enrichment_suggestions;
create policy es_owner_delete_draft on public.enrichment_suggestions
  for delete to authenticated
  using (status = 'draft' and source = 'researcher'
         and subject_type = 'person'
         and subject_id in (select id from people where auth_user_id = auth.uid()));

-- E6.3 Researcher activity (admin dashboard, low priority): last sign-in per person.
create or replace function public.admin_last_sign_ins()
returns table (person_id uuid, last_sign_in_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return query
    select p.id, u.last_sign_in_at
      from people p join auth.users u on u.id = p.auth_user_id
     where p.merged_into is null;
end;
$$;
revoke all on function public.admin_last_sign_ins() from public, anon;
grant execute on function public.admin_last_sign_ins() to authenticated;

-- E4.7 Researcher uploads their own photo. Uploads land under
-- proposed/<auth uid>/ so they never overwrite a published photo; the new URL
-- goes to UNIDCOM review as a photo_url suggestion (nothing auto-published).
update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg','image/png','image/webp']
 where id = 'people-photos';

drop policy if exists photos_owner_insert on storage.objects;
create policy photos_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'people-photos'
              and (storage.foldername(name))[1] = 'proposed'
              and (storage.foldername(name))[2] = auth.uid()::text);

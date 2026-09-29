-- Rui 25 Sep (A1·8): the pipeline has an "Under review" stage between
-- Submitted and Approved. An admin moves a submitted profile there with
-- "Start review"; approving still works from either state.
alter table public.people drop constraint people_profile_status_chk;
alter table public.people add constraint people_profile_status_chk
  check (profile_status in ('to_validate','draft','pending_review','under_review','approved'));

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
    'review_started_at', (select max(changed_at) from change_log c
                      where c.subject_type = 'person' and c.subject_id = p.id
                        and c.field = 'profile_status' and c.new_value = 'under_review'),
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

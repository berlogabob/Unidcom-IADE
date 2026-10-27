-- "Your record" shows the live version and the current round separately
-- (1 Oct). round_started_at: when the profile last went back to draft, so
-- dates from an older round never show on the current one.
create or replace function public.my_profile_timeline()
returns jsonb
language sql
stable security definer
set search_path to 'public'
as $function$
  select jsonb_build_object(
    'profile_status',    p.profile_status,
    'public_visibility', p.public_visibility,
    'created_at',        p.created_at,
    'round_started_at', coalesce(
                      (select max(changed_at) from change_log c
                        where c.subject_type = 'person' and c.subject_id = p.id
                          and c.field = 'profile_status'
                          and c.new_value in ('draft', 'to_validate')),
                      p.created_at),
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
$function$;

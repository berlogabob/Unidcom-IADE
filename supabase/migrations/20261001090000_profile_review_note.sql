-- Rui's v1.0 brief PA-1: Pending approval acts on Submitted / Under review
-- profiles with Approve · Request changes · Reject. Both non-approve actions
-- send the profile back to 'draft' with a note the researcher reads on
-- Overview. The note is UNIDCOM's: only admins write it.

alter table public.people add column if not exists review_note text;

create or replace function public.protect_people_cols()
 returns trigger
 language plpgsql
 set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    new.membership_type   := old.membership_type;
    new.status            := old.status;
    new.review_note       := old.review_note;
    if old.auth_user_id is not null and old.auth_user_id = auth.uid()
       and old.profile_status in ('draft','to_validate')
       and new.profile_status = 'pending_review' then
      new.last_verified_at := now();          -- sanctioned self-submit
    else
      new.profile_status   := old.profile_status;
      new.last_verified_at := old.last_verified_at;
    end if;
    new.public_visibility := old.public_visibility;
    if coalesce(current_setting('unidcom.orcid_claim', true), '') <> 'on' then
      new.auth_user_id := old.auth_user_id;
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$function$;

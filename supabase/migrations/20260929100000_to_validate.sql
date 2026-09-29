-- Rui, 25 Sep 2026 ("UI decisions for the pilot", platform checks):
-- imported records start as "To be validated by the researcher". Approval only
-- happens after the researcher submits and UNIDCOM reviews. Every record in the
-- DB today was imported (Notion form, CSV, BID.Lab plan, admin ORCID pulls) and
-- bulk-approved on 4 Aug, so all of them move back to to_validate.
--
-- Approval and publication are separate: an output is on the website iff
-- website_status = 'published' (and not rejected); a person iff
-- public_visibility. Neither is touched here, so the site does not change.

-- 1. New state on both tables.
alter table public.outputs drop constraint outputs_approval_status_chk;
alter table public.outputs add constraint outputs_approval_status_chk
  check (approval_status in ('to_validate','pending','approved','rejected'));

alter table public.people drop constraint people_profile_status_chk;
alter table public.people add constraint people_profile_status_chk
  check (profile_status in ('to_validate','draft','pending_review','approved'));

-- 2. Owner self-submit also from to_validate (was draft only).
create or replace function public.protect_people_cols() returns trigger
  language plpgsql
  set search_path = public
as $$
begin
  if not public.is_admin() then
    new.membership_type   := old.membership_type;
    new.status            := old.status;
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
$$;

-- 3. Researcher submits own outputs for review: to_validate/rejected -> pending.
-- All-or-nothing: one id the caller does not author raises 42501.
create or replace function public.submit_my_outputs(p_ids uuid[])
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_person uuid;
  v_count  int;
begin
  select p.id into v_person
    from public.people p
   where p.auth_user_id = auth.uid()
     and p.merged_into is null;
  if v_person is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if exists (
    select 1 from unnest(p_ids) as i(id)
     where not exists (
       select 1 from public.output_authors oa
        where oa.output_id = i.id and oa.person_id = v_person)
  ) then
    raise exception 'not an author of every output' using errcode = '42501';
  end if;

  update public.outputs
     set approval_status = 'pending'
   where id = any(p_ids)
     and approval_status in ('to_validate','rejected');
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.submit_my_outputs(uuid[]) from public, anon;
grant execute on function public.submit_my_outputs(uuid[]) to authenticated;

-- 4. Data: nothing imported counts as approved any more.
update public.outputs set approval_status = 'to_validate' where approval_status = 'approved';
-- protect_people_cols reverts profile_status for any non-admin caller, and the
-- migration runner has no auth.uid(); bypass it for this one statement.
alter table public.people disable trigger trg_protect_people;
update public.people  set profile_status  = 'to_validate' where profile_status  = 'approved';
alter table public.people enable trigger trg_protect_people;

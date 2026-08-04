-- Pilot W1: enforce the status vocabularies, open the one researcher
-- self-submit path, and audit every status change into change_log.
-- State machines stay tiny: profile draft → pending_review (owner) → approved
-- (admin, any transition — admins fix mistakes); output pending → approved |
-- rejected (admin-only via RLS, reversible for the same reason).
-- ponytail: no transition matrix table — two vocab checks + one trigger branch.

-- 1. Vocabulary constraints (live data verified clean on 2026-08-04).
alter table public.outputs
  add constraint outputs_approval_status_chk
  check (approval_status in ('pending','approved','rejected'));
alter table public.people
  add constraint people_profile_status_chk
  check (profile_status in ('draft','pending_review','approved'));
alter table public.projects
  add constraint projects_approval_status_chk
  check (approval_status in ('pending','approved','rejected'));

-- 2. Owner self-submit: a researcher may move their OWN profile
-- draft → pending_review; doing so stamps last_verified_at (they just
-- confirmed their data). Every other profile_status/last_verified_at write
-- stays admin-only. Same function as 20260731120000, one new branch.
create or replace function public.protect_people_cols() returns trigger
  language plpgsql as $$
begin
  if not public.is_admin() then
    new.membership_type   := old.membership_type;
    new.status            := old.status;
    if old.auth_user_id is not null and old.auth_user_id = auth.uid()
       and old.profile_status = 'draft' and new.profile_status = 'pending_review' then
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

-- 3. Audit: any status change lands in change_log, whoever makes it.
-- security definer because researchers (non-admin) can now change
-- profile_status but cl_write RLS is admin-only.
create or replace function public.log_status_change() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into change_log (subject_type, subject_id, field, old_value, new_value, actor)
  values (tg_argv[0], new.id, tg_argv[1],
          to_jsonb(old) ->> tg_argv[1], to_jsonb(new) ->> tg_argv[1], auth.uid());
  return null;
end;
$$;

create trigger trg_log_output_status after update on public.outputs
  for each row when (old.approval_status is distinct from new.approval_status)
  execute function public.log_status_change('output', 'approval_status');
create trigger trg_log_profile_status after update on public.people
  for each row when (old.profile_status is distinct from new.profile_status)
  execute function public.log_status_change('person', 'profile_status');

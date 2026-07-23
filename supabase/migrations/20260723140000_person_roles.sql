-- person_roles: the time-aware "logbook" of a person's standing roles/tags —
-- membership category (which changes year to year), free tags, and custom roles.
-- Editable by admins + the profile owner; owner edits await approval.
-- ponytail: ONE generic logbook table, not per-kind temporal tables. `person_tags`
-- (empty, no editor) is superseded by the `tag` kind and left in place.

create table public.person_roles (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people on delete cascade,
  kind text not null,                       -- membership | tag | role
  label text not null,                      -- enum value for membership, else free text
  year int,                                 -- nullable = standing/undated
  status text not null default 'approved',  -- approved | pending
  notes text,
  created_at timestamptz default now()
);
create index person_roles_person_idx on public.person_roles (person_id, year);

-- Seed history: one approved `membership` row per person for the current year.
insert into public.person_roles (person_id, kind, label, year, status)
select id, 'membership', membership_type, extract(year from now())::int, 'approved'
from public.people
where membership_type is not null;

-- ============================================================ RLS
alter table public.person_roles enable row level security;

-- Public sees only approved rows; admins and the profile owner see pending too.
create policy pr_read on public.person_roles for select using (
  status = 'approved'
  or public.is_admin()
  or exists (
    select 1 from public.people p
    where p.id = person_id and p.auth_user_id = auth.uid()
  )
);

-- Admins, or the profile owner, may write their own logbook rows.
create policy pr_write on public.person_roles for all
  using (
    public.is_admin()
    or exists (
      select 1 from public.people p
      where p.id = person_id and p.auth_user_id = auth.uid()
    )
  )
  with check (
    public.is_admin()
    or exists (
      select 1 from public.people p
      where p.id = person_id and p.auth_user_id = auth.uid()
    )
  );

-- Non-admins (profile owners) can only create pending rows and cannot self-approve.
create or replace function public.protect_person_roles() returns trigger
  language plpgsql as $$
begin
  if not public.is_admin() then
    new.status := 'pending';
  end if;
  return new;
end;
$$;
create trigger trg_protect_person_roles before insert or update on public.person_roles
  for each row execute function public.protect_person_roles();

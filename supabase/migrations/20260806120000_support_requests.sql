-- Support requests: researchers own drafts/submissions; admins handle review.
-- Status changes reuse the shared change_log audit trigger.

-- 1. Request data.
create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  type text not null check (type in ('dpd','open_access','mission')),
  title text not null,
  event_name text,
  event_url text,
  event_date date,
  location text,
  presentation_format text,
  budget jsonb not null default '{}'::jsonb, -- line items {label, amount}
  amount_total numeric(10,2),
  status text not null default 'draft'
    check (status in ('draft','submitted','approved','rejected','completed')),
  checklist jsonb not null default '[]'::jsonb, -- [{item, done}]
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index support_requests_person_idx on public.support_requests (person_id);
create index support_requests_status_idx on public.support_requests (status);

-- 2. Owners see and manage their requests; admins may manage every row.
-- Anonymous callers match neither branch and receive nothing.
alter table public.support_requests enable row level security;

create policy support_requests_read on public.support_requests for select using (
  public.is_admin()
  or exists (select 1 from public.people p
              where p.id = person_id and p.auth_user_id = auth.uid()));

create policy support_requests_insert on public.support_requests for insert with check (
  public.is_admin()
  or exists (select 1 from public.people p
              where p.id = person_id and p.auth_user_id = auth.uid()));

create policy support_requests_update on public.support_requests for update
  using (
    public.is_admin()
    or (status in ('draft','submitted') and exists (
      select 1 from public.people p
       where p.id = person_id and p.auth_user_id = auth.uid()))
  )
  with check (
    public.is_admin()
    or (status in ('draft','submitted') and exists (
      select 1 from public.people p
       where p.id = person_id and p.auth_user_id = auth.uid()))
  );

create policy support_requests_delete on public.support_requests for delete using (
  public.is_admin()
  or (status = 'draft' and exists (
    select 1 from public.people p
     where p.id = person_id and p.auth_user_id = auth.uid())));

-- 3. Owners may keep status or submit a draft; admin notes stay admin-only.
create or replace function public.protect_support_requests() returns trigger
  language plpgsql set search_path = public as $$
begin
  if not public.is_admin() then
    if new.status is distinct from old.status
       and not (old.status = 'draft' and new.status = 'submitted') then
      new.status := old.status;
    end if;
    new.admin_note := old.admin_note;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_protect_support_requests before update on public.support_requests
  for each row execute function public.protect_support_requests();

-- 4. Audit every request status change.
create trigger trg_log_request_status after update on public.support_requests
  for each row when (old.status is distinct from new.status)
  execute function public.log_status_change('support_request','status');

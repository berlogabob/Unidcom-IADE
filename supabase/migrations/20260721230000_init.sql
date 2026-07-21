-- UNIDCOM Research Directory — core schema, RLS, reporting view.
-- Scale is tiny (~185 people, ~371 outputs); kept deliberately minimal.
-- ponytail: no entities supertable / audit_log / change_proposals / snapshots — add when they hurt.

create extension if not exists pg_trgm;
create extension if not exists unaccent;

-- Admin = custom claim app_metadata.role = 'admin' (set on the Supabase auth user).
create or replace function public.is_admin() returns boolean
  language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;

-- ------------------------------------------------------------------ people
create table public.people (
  id uuid primary key default gen_random_uuid(),
  preferred_name text not null,
  legal_name text,
  bio text,
  photo_url text,
  membership_type text check (membership_type in
    ('integrated','collaborator','external','staff','advisory_board')),  -- required category, not a tag
  status text default 'a_confirmar',            -- a_confirmar | active | inactive
  email text,
  orcid text,
  ciencia_id text,
  profile_status text default 'draft',          -- draft | pending_review | approved
  public_visibility boolean default false,
  last_verified_at timestamptz,                 -- freshness = a date, no boolean flag / cron
  auth_user_id uuid references auth.users on delete set null,   -- links a researcher to a login (nullable)
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  search tsvector generated always as
    (to_tsvector('simple', unaccent(coalesce(preferred_name,'') || ' ' || coalesce(bio,'')))) stored
);
create index people_search_idx on public.people using gin (search);
create index people_name_trgm_idx on public.people using gin (preferred_name gin_trgm_ops);
create unique index people_auth_user_idx on public.people (auth_user_id) where auth_user_id is not null;

-- ------------------------------------------------------------------ outputs
create table public.outputs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  reporting_year int,                           -- report on this, not free-text
  type text,
  subtype text,
  category_path text,                           -- from the director's taxonomy
  doi text unique,
  url text,
  approval_status text default 'pending',       -- pending | approved | rejected
  created_at timestamptz default now()
);

-- The one mandatory join: a 3-author paper exists ONCE, reports never triple-count.
create table public.output_authors (
  output_id uuid references public.outputs on delete cascade,
  person_id uuid references public.people on delete cascade,
  role text,
  author_position int,
  primary key (output_id, person_id)
);
create index output_authors_person_idx on public.output_authors (person_id);

-- ------------------------------------------------------------------ projects
create table public.projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  acronym text,
  description text,
  total_budget numeric,
  currency text default 'EUR',
  start_date date,
  end_date date,
  status text default 'active',                 -- planned | active | completed | cancelled
  public_visibility boolean default false,
  approval_status text default 'pending',
  created_at timestamptz default now()
);
create table public.project_members (
  project_id uuid references public.projects on delete cascade,
  person_id uuid references public.people on delete cascade,
  role text,
  primary key (project_id, person_id)
);
create table public.project_outputs (
  project_id uuid references public.projects on delete cascade,
  output_id uuid references public.outputs on delete cascade,
  primary key (project_id, output_id)
);

-- ------------------------------------------------------------------ tags
create table public.tags (
  id uuid primary key default gen_random_uuid(),
  name text unique,
  category text
);
create table public.person_tags (
  person_id uuid references public.people on delete cascade,
  tag_id uuid references public.tags on delete cascade,
  primary key (person_id, tag_id)
);

-- ------------------------------------------------------------------ reporting view
-- security_invoker so the caller's RLS applies (only approved outputs leak to the public).
create view public.v_output_report with (security_invoker = on) as
  select o.*, count(distinct oa.person_id) as unidcom_authors
  from public.outputs o
  join public.output_authors oa on oa.output_id = o.id
  where o.approval_status = 'approved'
  group by o.id;
-- period report: select * from v_output_report where reporting_year=2025 and type='Artigos em revistas';
-- freshness:      select * from people where last_verified_at < now() - interval '6 months';

-- ============================================================ RLS
alter table public.people          enable row level security;
alter table public.outputs         enable row level security;
alter table public.output_authors  enable row level security;
alter table public.projects        enable row level security;
alter table public.project_members enable row level security;
alter table public.project_outputs enable row level security;
alter table public.tags            enable row level security;
alter table public.person_tags     enable row level security;

-- Public sees approved+public rows; any authenticated user sees everything.
create policy people_read on public.people for select using (
  (public_visibility and profile_status = 'approved') or auth.uid() is not null);
create policy outputs_read on public.outputs for select using (
  approval_status = 'approved' or auth.uid() is not null);
create policy projects_read on public.projects for select using (
  (public_visibility and approval_status = 'approved') or auth.uid() is not null);

-- Join/tag tables: readable to all (parent-row RLS already hides hidden entities from render).
-- ponytail: tighten to match parent visibility only if existence-leakage ever matters.
create policy oa_read  on public.output_authors  for select using (true);
create policy pm_read  on public.project_members for select using (true);
create policy po_read  on public.project_outputs for select using (true);
create policy tag_read on public.tags            for select using (true);
create policy pt_read  on public.person_tags     for select using (true);

-- A researcher may update their own person row; admin may update any.
-- Column-level protection (membership_type, status, etc.) is enforced by the trigger below.
create policy people_update on public.people for update
  using (public.is_admin() or auth_user_id = auth.uid())
  with check (public.is_admin() or auth_user_id = auth.uid());

-- Everything else (all inserts/deletes, and edits to outputs/projects/joins/tags) is admin-only.
create policy people_admin_write on public.people          for all using (public.is_admin()) with check (public.is_admin());
create policy outputs_write      on public.outputs         for all using (public.is_admin()) with check (public.is_admin());
create policy oa_write           on public.output_authors  for all using (public.is_admin()) with check (public.is_admin());
create policy projects_write     on public.projects        for all using (public.is_admin()) with check (public.is_admin());
create policy pm_write           on public.project_members for all using (public.is_admin()) with check (public.is_admin());
create policy po_write           on public.project_outputs for all using (public.is_admin()) with check (public.is_admin());
create policy tags_write         on public.tags            for all using (public.is_admin()) with check (public.is_admin());
create policy pt_write           on public.person_tags     for all using (public.is_admin()) with check (public.is_admin());

-- Non-admins editing their own profile cannot touch official/governance fields.
create or replace function public.protect_people_cols() returns trigger
  language plpgsql as $$
begin
  if not public.is_admin() then
    new.membership_type   := old.membership_type;
    new.status            := old.status;
    new.profile_status    := old.profile_status;
    new.public_visibility := old.public_visibility;
    new.auth_user_id      := old.auth_user_id;
    new.last_verified_at  := old.last_verified_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger trg_protect_people before update on public.people
  for each row execute function public.protect_people_cols();

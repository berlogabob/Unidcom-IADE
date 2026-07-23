-- part02: clusters, labs, objectives + their relationships, and richer projects.
-- Follows the minimal style + RLS convention of 20260721230000_init.sql.
-- Scale is tiny (5 clusters, 5 labs, 12 objectives, 33 projects).

-- ---------------------------------------------------------------- entities
create table public.clusters (
  id uuid primary key default gen_random_uuid(),
  code text unique,               -- E3, T3, C3, R3, F3
  name text not null,             -- "E3: Exploring Economic Ethos"
  concern text,
  notes text,
  created_at timestamptz default now()
);

create table public.labs (
  id uuid primary key default gen_random_uuid(),
  code text unique,               -- SDI, DTN, BiD, MADx, DFH
  name text not null,
  overview text,
  notes text,
  created_at timestamptz default now()
);

create table public.objectives (
  id uuid primary key default gen_random_uuid(),
  code text unique,               -- UNID.1 .. UNID.9
  name text not null,
  description text,
  kpis text,
  source text,
  created_at timestamptz default now()
);

-- Enrich projects (Abstract->description, dates->start/end, Estado->status already exist).
alter table public.projects add column funding text;   -- Financiamento (FCT | Interno | Outro ...)
alter table public.projects add column category text;   -- Categoria (Labs | Operação | Eventos ...)

-- ---------------------------------------------------------------- joins
create table public.lab_members (
  lab_id uuid references public.labs on delete cascade,
  person_id uuid references public.people on delete cascade,
  is_coordinator boolean default false,
  primary key (lab_id, person_id)
);
create index lab_members_person_idx on public.lab_members (person_id);

create table public.objective_clusters (
  objective_id uuid references public.objectives on delete cascade,
  cluster_id uuid references public.clusters on delete cascade,
  primary key (objective_id, cluster_id)
);
create table public.lab_objectives (
  lab_id uuid references public.labs on delete cascade,
  objective_id uuid references public.objectives on delete cascade,
  primary key (lab_id, objective_id)
);
create table public.project_clusters (
  project_id uuid references public.projects on delete cascade,
  cluster_id uuid references public.clusters on delete cascade,
  primary key (project_id, cluster_id)
);
create table public.project_labs (
  project_id uuid references public.projects on delete cascade,
  lab_id uuid references public.labs on delete cascade,
  primary key (project_id, lab_id)
);
create table public.project_objectives (
  project_id uuid references public.projects on delete cascade,
  objective_id uuid references public.objectives on delete cascade,
  primary key (project_id, objective_id)
);

-- ============================================================ RLS
alter table public.clusters           enable row level security;
alter table public.labs               enable row level security;
alter table public.objectives         enable row level security;
alter table public.lab_members        enable row level security;
alter table public.objective_clusters enable row level security;
alter table public.lab_objectives     enable row level security;
alter table public.project_clusters   enable row level security;
alter table public.project_labs       enable row level security;
alter table public.project_objectives enable row level security;

-- Org structure + join tables: readable to all, admin-only write (matches init.sql).
create policy clusters_read   on public.clusters           for select using (true);
create policy labs_read       on public.labs               for select using (true);
create policy objectives_read on public.objectives         for select using (true);
create policy lm_read on public.lab_members        for select using (true);
create policy oc_read on public.objective_clusters for select using (true);
create policy lo_read on public.lab_objectives     for select using (true);
create policy pc_read on public.project_clusters   for select using (true);
create policy pl_read on public.project_labs        for select using (true);
create policy pob_read on public.project_objectives for select using (true);

create policy clusters_write   on public.clusters           for all using (public.is_admin()) with check (public.is_admin());
create policy labs_write       on public.labs               for all using (public.is_admin()) with check (public.is_admin());
create policy objectives_write on public.objectives         for all using (public.is_admin()) with check (public.is_admin());
create policy lm_write  on public.lab_members        for all using (public.is_admin()) with check (public.is_admin());
create policy oc_write  on public.objective_clusters for all using (public.is_admin()) with check (public.is_admin());
create policy lo_write  on public.lab_objectives     for all using (public.is_admin()) with check (public.is_admin());
create policy pc_write  on public.project_clusters   for all using (public.is_admin()) with check (public.is_admin());
create policy pl_write  on public.project_labs        for all using (public.is_admin()) with check (public.is_admin());
create policy pob_write on public.project_objectives for all using (public.is_admin()) with check (public.is_admin());

-- D: external/internal collaboration partners for labs and projects.
-- Lab-to-lab "internal collaborations" are intentionally not modeled (derivable
-- via shared projects/objectives); only partner orgs + IADE internal units.
create table public.collaborations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text check (kind in ('external', 'internal')),
  notes text,
  created_at timestamptz default now()
);
create index collaborations_name_idx on public.collaborations (lower(name));

create table public.lab_collaborations (
  lab_id uuid references public.labs on delete cascade,
  collaboration_id uuid references public.collaborations on delete cascade,
  primary key (lab_id, collaboration_id)
);
create index lab_collaborations_collab_idx on public.lab_collaborations (collaboration_id);

create table public.project_collaborations (
  project_id uuid references public.projects on delete cascade,
  collaboration_id uuid references public.collaborations on delete cascade,
  primary key (project_id, collaboration_id)
);
create index project_collaborations_collab_idx on public.project_collaborations (collaboration_id);

alter table public.collaborations         enable row level security;
alter table public.lab_collaborations     enable row level security;
alter table public.project_collaborations enable row level security;

create policy collaborations_read on public.collaborations for select using (true);
create policy lc_read on public.lab_collaborations     for select using (true);
create policy pcol_read on public.project_collaborations for select using (true);
create policy collaborations_write on public.collaborations for all using (public.is_admin()) with check (public.is_admin());
create policy lc_write on public.lab_collaborations     for all using (public.is_admin()) with check (public.is_admin());
create policy pcol_write on public.project_collaborations for all using (public.is_admin()) with check (public.is_admin());

-- B: best-practice secondary indexes on the non-leading join-table FK columns,
-- plus clusters.source (parity with objectives.source).
create index if not exists project_clusters_cluster_idx on public.project_clusters (cluster_id);
create index if not exists project_labs_lab_idx on public.project_labs (lab_id);
create index if not exists project_objectives_objective_idx on public.project_objectives (objective_id);
create index if not exists objective_clusters_cluster_idx on public.objective_clusters (cluster_id);
create index if not exists lab_objectives_objective_idx on public.lab_objectives (objective_id);
create index if not exists project_members_person_idx on public.project_members (person_id);

alter table public.clusters add column source text;

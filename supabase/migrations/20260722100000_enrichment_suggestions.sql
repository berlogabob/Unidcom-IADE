-- Staging table for open-source enrichment (ORCID / Crossref).
-- Enrichment NEVER overwrites canonical data — it only writes suggestions here for admin review.
-- ponytail: one flat suggestions table, not a change_proposals engine. Add workflow when it hurts.

create table public.enrichment_suggestions (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check (subject_type in ('person','output')),
  subject_id uuid not null,
  field text not null,               -- e.g. orcid, ciencia_id, title
  current_value text,
  suggested_value text,
  source text,                       -- crossref | orcid
  confidence numeric,                -- 0..1
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz default now()
);
create index enrichment_suggestions_subject_idx on public.enrichment_suggestions (subject_type, subject_id);
create index enrichment_suggestions_status_idx  on public.enrichment_suggestions (status);

alter table public.enrichment_suggestions enable row level security;
-- Admin-only (the enrich.py loader uses the service key, which bypasses RLS anyway).
create policy es_admin_all on public.enrichment_suggestions
  for all using (public.is_admin()) with check (public.is_admin());

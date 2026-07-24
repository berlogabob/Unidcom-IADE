-- Output data-quality: rules computed as views + a waiver escape hatch.
-- Single source of truth for the "attention" mechanism (badges, Needs-attention queue).
-- ponytail: rules live in one view, not per-rule tables/triggers. Waivers kill false positives.

-- doi_status is a fact (does the DOI resolve?), written by scripts/check_dois.py — so it
-- lives on outputs, not in enrichment_suggestions (which stages *suggested* values).
alter table public.outputs
  add column doi_status text,          -- ok | dead | unchecked (null = never checked)
  add column doi_checked_at timestamptz;

-- Duplicate detection compares a normalized "core": the source `title` often holds a whole
-- citation ("Author (2024). Title. Journal. doi:..."), so we strip parenthetical asides and
-- the doi tail — the volatile bits that differ between two copies of the same work.
-- ponytail: immutable expr → generated column, so it's indexable and computed once, not per self-join pair.
alter table public.outputs
  add column title_norm text generated always as (
    lower(btrim(regexp_replace(
      regexp_replace(title, 'doi:.*$|\([^)]*\)', ' ', 'gi'),
      '\s+', ' ', 'g')))
  ) stored;

-- pg_trgm already enabled in init.sql; index keeps the duplicate self-join cheap as it grows.
create index outputs_title_norm_trgm_idx on public.outputs using gin (title_norm gin_trgm_ops);

-- ------------------------------------------------------------------ waivers
-- Admin marks a flagged issue as a legitimate exception; it stops re-appearing.
create table public.quality_waivers (
  id uuid primary key default gen_random_uuid(),
  output_id uuid not null references public.outputs on delete cascade,
  issue_code text not null,
  reason text,
  waived_by uuid references auth.users on delete set null,
  waived_at timestamptz default now(),
  unique (output_id, issue_code)
);
alter table public.quality_waivers enable row level security;
create policy qw_read  on public.quality_waivers for select using (auth.uid() is not null);
create policy qw_write on public.quality_waivers for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------------ issues
-- One row per (output, unresolved issue). Waived issues are filtered out.
create view public.v_output_issues with (security_invoker = on) as
with raw(output_id, issue_code, severity) as (
  select id, 'missing_doi',      'warning' from public.outputs where doi is null
  union all
  select id, 'invalid_doi',      'error'   from public.outputs
    where doi is not null and doi !~ '^10\.\d{4,9}/\S+$'
  union all
  select id, 'dead_doi',         'error'   from public.outputs
    where doi is not null and doi_status = 'dead'
  union all
  select id, 'missing_reference','warning' from public.outputs
    where full_reference is null or btrim(full_reference) = ''
  union all
  select id, 'missing_year',     'error'   from public.outputs where reporting_year is null
  union all
  select id, 'implausible_year', 'warning' from public.outputs
    where reporting_year is not null
      and (reporting_year < 1990 or reporting_year > extract(year from now())::int + 1)
  union all
  select id, 'missing_type',     'warning' from public.outputs
    where type is null or btrim(type) = ''
  union all
  select id, 'unverified',       'warning' from public.outputs where verified_online is not true
  union all
  select id, 'missing_authors',  'error'   from public.outputs o
    where not exists (select 1 from public.output_authors oa where oa.output_id = o.id)
  union all
  -- fuzzy duplicate: near-identical normalized title on another row (catches DOI-less shadows
  -- and cross-year copies too). 0.9 on the stripped core keeps false positives low; waive the rest.
  -- ponytail: O(n^2) trgm self-join, fine at ~371 rows; add a % prefilter past a few thousand.
  select a.id, 'duplicate',      'error'   from public.outputs a
    where exists (
      select 1 from public.outputs b
      where b.id <> a.id and similarity(a.title_norm, b.title_norm) > 0.9
    )
)
select r.output_id, r.issue_code, r.severity
from raw r
where not exists (
  select 1 from public.quality_waivers w
  where w.output_id = r.output_id and w.issue_code = r.issue_code
);

-- ------------------------------------------------------------------ per-output rollup
-- What the UI joins against: one row per output, empty array when clean.
create view public.v_output_quality with (security_invoker = on) as
select
  o.id as output_id,
  coalesce(
    array_agg(i.issue_code order by i.severity, i.issue_code)
      filter (where i.issue_code is not null),
    '{}'
  ) as issue_codes,
  count(*) filter (where i.severity = 'error')   as error_count,
  count(*) filter (where i.severity = 'warning') as warning_count
from public.outputs o
left join public.v_output_issues i on i.output_id = o.id
group by o.id;

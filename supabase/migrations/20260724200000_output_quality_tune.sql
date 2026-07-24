-- Tune the quality rules to cut false positives that made the attention view unusable:
--  * missing_doi only applies to DOI-bearing macro-types (Livros, Artigos em revistas).
--  * unverified dropped entirely — verified_online is a manual QA state, not a data defect.
-- Column list unchanged, so the dependent v_output_quality view is untouched.

create or replace view public.v_output_issues with (security_invoker = on) as
with raw(output_id, issue_code, severity) as (
  select id, 'missing_doi',      'warning' from public.outputs
    where doi is null and macro_type in ('Livros', 'Artigos em revistas')
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
  select id, 'missing_authors',  'error'   from public.outputs o
    where not exists (select 1 from public.output_authors oa where oa.output_id = o.id)
  union all
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

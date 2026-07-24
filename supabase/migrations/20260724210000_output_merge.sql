-- Output merge: soft-merge duplicate outputs (survivor + reversible loser tombstones).
-- Mirrors person-merge (20260722120000_person_merge.sql). Losers get merged_into set;
-- their relationships move to the survivor in ONE transaction. Nothing hard-deleted.

alter table public.outputs add column if not exists merged_into uuid references public.outputs(id);
create index if not exists outputs_merged_into_idx on public.outputs(merged_into);

create or replace function public.merge_outputs(
  p_survivor uuid,
  p_losers uuid[],
  p_fields jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  if p_survivor = any(p_losers) then
    raise exception 'survivor cannot also be a loser';
  end if;

  -- output_authors (PK output_id, person_id): move loser links unless survivor already has that author.
  update public.output_authors oa set output_id = p_survivor
   where oa.output_id = any(p_losers)
     and not exists (select 1 from public.output_authors s
                      where s.output_id = p_survivor and s.person_id = oa.person_id);
  delete from public.output_authors where output_id = any(p_losers);

  -- project_outputs (PK project_id, output_id)
  update public.project_outputs po set output_id = p_survivor
   where po.output_id = any(p_losers)
     and not exists (select 1 from public.project_outputs s
                      where s.project_id = po.project_id and s.output_id = p_survivor);
  delete from public.project_outputs where output_id = any(p_losers);

  -- loser waivers are moot once merged away
  delete from public.quality_waivers where output_id = any(p_losers);

  -- enrichment suggestions that point at a loser output
  update public.enrichment_suggestions
     set subject_id = p_survivor
   where subject_type = 'output' and subject_id = any(p_losers);

  -- free the unique DOI: a tombstoned loser still holding the same doi would violate the
  -- unique constraint when the survivor adopts it.
  -- ponytail: doi is the only unique col; null it on losers so the survivor can take it.
  update public.outputs set doi = null where id = any(p_losers);

  -- apply the chosen field values to the survivor (coalesce: only provided keys change)
  update public.outputs set
    title          = coalesce(p_fields->>'title', title),
    doi            = coalesce(p_fields->>'doi', doi),
    url            = coalesce(p_fields->>'url', url),
    type           = coalesce(p_fields->>'type', type),
    subtype        = coalesce(p_fields->>'subtype', subtype),
    macro_type     = coalesce(p_fields->>'macro_type', macro_type),
    output_status  = coalesce(p_fields->>'output_status', output_status),
    full_reference = coalesce(p_fields->>'full_reference', full_reference),
    reporting_year = coalesce((p_fields->>'reporting_year')::int, reporting_year)
  where id = p_survivor;

  -- soft-merge the losers (hidden tombstones)
  update public.outputs set merged_into = p_survivor where id = any(p_losers);
end;
$$;

grant execute on function public.merge_outputs(uuid, uuid[], jsonb) to authenticated;

-- Cluster source for the merge UI: pairs of live duplicates.
create view public.v_output_duplicate_pairs with (security_invoker = on) as
  select a.id as a_id, b.id as b_id
  from public.outputs a
  join public.outputs b
    on a.id < b.id and similarity(a.title_norm, b.title_norm) > 0.9
  where a.merged_into is null and b.merged_into is null;

-- Hide tombstones from the reporting view. Drop+recreate: adding outputs.merged_into shifts
-- this view's o.* columns, which create-or-replace can't do.
drop view if exists public.v_output_report;
create view public.v_output_report with (security_invoker = on) as
  select o.*, count(distinct oa.person_id) as unidcom_authors
  from public.outputs o
  join public.output_authors oa on oa.output_id = o.id
  where o.approval_status = 'approved' and o.merged_into is null
  group by o.id;

-- Hide tombstones from the quality rules (esp. the duplicate self-join must ignore losers).
create or replace view public.v_output_issues with (security_invoker = on) as
with raw(output_id, issue_code, severity) as (
  select id, 'missing_doi',      'warning' from public.outputs
    where doi is null and macro_type in ('Livros', 'Artigos em revistas') and merged_into is null
  union all
  select id, 'invalid_doi',      'error'   from public.outputs
    where doi is not null and doi !~ '^10\.\d{4,9}/\S+$' and merged_into is null
  union all
  select id, 'dead_doi',         'error'   from public.outputs
    where doi is not null and doi_status = 'dead' and merged_into is null
  union all
  select id, 'missing_reference','warning' from public.outputs
    where (full_reference is null or btrim(full_reference) = '') and merged_into is null
  union all
  select id, 'missing_year',     'error'   from public.outputs
    where reporting_year is null and merged_into is null
  union all
  select id, 'implausible_year', 'warning' from public.outputs
    where reporting_year is not null and merged_into is null
      and (reporting_year < 1990 or reporting_year > extract(year from now())::int + 1)
  union all
  select id, 'missing_type',     'warning' from public.outputs
    where (type is null or btrim(type) = '') and merged_into is null
  union all
  select id, 'missing_authors',  'error'   from public.outputs o
    where o.merged_into is null
      and not exists (select 1 from public.output_authors oa where oa.output_id = o.id)
  union all
  select a.id, 'duplicate',      'error'   from public.outputs a
    where a.merged_into is null and exists (
      select 1 from public.outputs b
      where b.id <> a.id and b.merged_into is null
        and similarity(a.title_norm, b.title_norm) > 0.9
    )
)
select r.output_id, r.issue_code, r.severity
from raw r
where not exists (
  select 1 from public.quality_waivers w
  where w.output_id = r.output_id and w.issue_code = r.issue_code
);

create or replace view public.v_output_quality with (security_invoker = on) as
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
where o.merged_into is null
group by o.id;

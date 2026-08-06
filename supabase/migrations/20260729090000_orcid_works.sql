-- Import published works from ORCID, tagged by whether they were produced under
-- an IADE/UNIDCOM affiliation.

-- Existing rows all came from UNIDCOM's own Notion export, so the default is
-- correct for them and no backfill is needed.
alter table public.outputs
  add column affiliation text not null default 'unidcom'
    check (affiliation in ('unidcom', 'external', 'unknown'));

comment on column public.outputs.affiliation is
  'unidcom = produced under IADE/UNIDCOM affiliation, counts in reports and stats; '
  'external = prior or other affiliation, shown on profiles only; '
  'unknown = evidence was inconclusive, treated as external for counting.';

create index outputs_affiliation_idx on public.outputs (affiliation);

-- Staging for works fetched from ORCID. The importer writes ONLY here, so an
-- unvetted work never lands in outputs.
-- NOTE (2026-08-06): the original rationale here said outputs_read was
-- `using (true)` during the test period and that report_data() ignores
-- approval_status. The test period is over — 20260805120000_approval_visibility
-- narrowed outputs_read to `approval_status = 'approved' or auth.uid() is not
-- null`. report_data() genuinely never filters on approval_status, but it is
-- SECURITY INVOKER, so that policy applies to it and an anonymous caller still
-- cannot read unapproved rows through it. Staging remains the right design;
-- the "instantly public" hazard it guarded against no longer exists.
-- Grain is (person, work) — two IADE co-authors on one paper legitimately produce two
-- candidates, which promote_output_candidate() collapses onto one output.
create table public.output_candidates (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people on delete cascade,
  source text not null default 'orcid',
  source_put_code text not null,

  title text not null,
  reporting_year int,
  doi text,
  url text,
  type text,
  full_reference text,

  affiliation text not null check (affiliation in ('unidcom', 'external', 'unknown')),
  affiliation_score numeric not null,
  reason text not null,

  matched_output_id uuid references public.outputs on delete set null,

  status text not null default 'pending'
    check (status in ('pending', 'promoted', 'rejected')),
  reviewed_by uuid references auth.users on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz default now(),

  unique (person_id, source, source_put_code)
);

create index output_candidates_queue_idx on public.output_candidates (status, affiliation);
create index output_candidates_person_idx on public.output_candidates (person_id);

alter table public.output_candidates enable row level security;
create policy oc_admin_all on public.output_candidates
  for all using (public.is_admin()) with check (public.is_admin());

-- Find the output a candidate already corresponds to, if any.
-- word_similarity, NOT similarity: stored titles are frequently whole citations with an
-- author prefix, and similarity() is symmetric, so a bare ORCID title never reaches the
-- 0.9 that v_output_duplicate_pairs uses. `<%` is the indexable operator form; the
-- explicit threshold pins it independent of the session's word_similarity_threshold.
create or replace function public.match_existing_output(p_doi text, p_title text)
returns uuid
language sql
stable
set search_path = public
as $$
  select id from (
    select o.id, 0 as rank
      from public.outputs o
     where p_doi is not null
       and o.merged_into is null
       and lower(o.doi) = lower(p_doi)
    union all
    select o.id, 1
      from public.outputs o
     where o.merged_into is null
       and lower(btrim(p_title)) <% o.title_norm
       and word_similarity(lower(btrim(p_title)), o.title_norm) > 0.75
  ) m
  order by rank
  limit 1;
$$;

-- Promote a reviewed candidate into the directory. An RPC because it spans outputs,
-- output_authors, change_log and the candidate row, and has to survive the
-- outputs.doi unique race atomically. Mirrors merge_outputs' admin-gated shape.
create or replace function public.promote_output_candidate(
  p_candidate uuid,
  p_affiliation text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.output_candidates;
  v_output uuid;
  v_aff text;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  select * into c from public.output_candidates where id = p_candidate for update;
  if not found then
    raise exception 'candidate not found';
  end if;
  if c.status <> 'pending' then
    raise exception 'candidate already %', c.status;
  end if;

  -- The reviewer may overrule the classifier.
  v_aff := coalesce(p_affiliation, c.affiliation);

  v_output := coalesce(c.matched_output_id, public.match_existing_output(c.doi, c.title));

  if v_output is null then
    insert into public.outputs (
      title, reporting_year, doi, url, type, full_reference,
      source, approval_status, affiliation
    )
    values (
      c.title, c.reporting_year, c.doi, c.url, c.type, c.full_reference,
      'orcid', 'pending', v_aff
    )
    on conflict (doi) do nothing
    returning id into v_output;

    -- NULL dois never conflict, which is exactly why the title pass above must exist.
    if v_output is null then
      select id into v_output
        from public.outputs
       where doi = c.doi and merged_into is null;
    end if;
  end if;

  -- Idempotent: two co-authors' candidates for one paper land two author rows on one output.
  insert into public.output_authors (output_id, person_id)
  values (v_output, c.person_id)
  on conflict (output_id, person_id) do nothing;

  insert into public.change_log
    (subject_type, subject_id, field, old_value, new_value, source, actor)
  values
    ('output', v_output, 'imported_from_orcid', null, c.source_put_code, 'orcid', auth.uid());

  update public.output_candidates
     set status = 'promoted',
         matched_output_id = v_output,
         reviewed_by = auth.uid(),
         reviewed_at = now()
   where id = p_candidate;

  return v_output;
end;
$$;

grant execute on function public.match_existing_output(text, text) to authenticated;
grant execute on function public.promote_output_candidate(uuid, text) to authenticated;

-- Counting paths must ignore non-UNIDCOM work. Profiles still show it.

-- Drop+recreate, not replace: adding outputs.affiliation shifts this view's o.* columns.
drop view if exists public.v_output_report;
create view public.v_output_report with (security_invoker = on) as
  select o.*, count(distinct oa.person_id) as unidcom_authors
  from public.outputs o
  join public.output_authors oa on oa.output_id = o.id
  where o.approval_status = 'approved'
    and o.merged_into is null
    and o.affiliation = 'unidcom'
  group by o.id;

-- One join filters all nine rules at once, so the rule arms stay untouched. A
-- prior-career paper with no reference or year is not a UNIDCOM data defect.
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
join public.outputs o on o.id = r.output_id and o.affiliation = 'unidcom'
where not exists (
  select 1 from public.quality_waivers w
  where w.output_id = r.output_id and w.issue_code = r.issue_code
);

-- Same one-line predicate on the PDF feed. This is the important one: report_data()
-- is granted to anon and ignores approval_status, so it is the path by which an
-- external paper would otherwise reach an FCT report.
create or replace function public.report_data(
  p_kind    text  default 'outputs',
  p_year    int   default null,
  p_filters jsonb default '{}'::jsonb
) returns jsonb
language sql
stable
set search_path = public
as $$
  select coalesce(
           jsonb_agg(to_jsonb(r) order by r.section, r.subsection, r.full_reference, r.title),
           '[]'::jsonb
         )
  from (
    select
      o.id,
      o.title,
      o.reporting_year,
      coalesce(nullif(btrim(o.macro_type), ''), 'Sem categoria')             as section,
      coalesce(nullif(btrim(o.subtype), ''), nullif(btrim(o.type), ''), '—') as subsection,
      o.type,
      o.category_path,
      o.full_reference,
      o.doi,
      o.url,
      o.output_status,
      o.approval_status,
      o.fct_selected,
      o.verified_online,
      o.doi_status,
      coalesce(
        (select array_agg(p.preferred_name order by oa.author_position, p.preferred_name)
           from output_authors oa
           join people p on p.id = oa.person_id
          where oa.output_id = o.id),
        '{}'::text[]
      ) as people,
      coalesce(q.issue_codes, '{}'::text[]) as issues
    from outputs o
    left join v_output_quality q on q.output_id = o.id
    where o.merged_into is null
      and o.affiliation = 'unidcom'
      and (p_year is null or o.reporting_year = p_year)
      and (p_filters->>'section' is null or o.macro_type = p_filters->>'section')
      and (p_filters->>'type'    is null or o.type      = p_filters->>'type')
      and p_kind is not null
  ) r;
$$;

grant execute on function public.report_data(text, int, jsonb) to anon, authenticated;

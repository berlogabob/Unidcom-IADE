-- Report payload for the Typst PDF generator.
--
-- Returns ONE jsonb array of flat rows; grouping into sections/subsections and all
-- PT-PT number formatting happen in the Edge Function. Deliberately a function and not
-- a view: config.toml sets `max_rows = 1000` on the Data API, which would silently
-- truncate a view query as the archive grows. A function returning a single jsonb value
-- is one row and never hits that cap.
--
-- Reads `outputs` directly rather than `v_output_report`: that view is
-- `approval_status = 'approved'` AND inner-joins output_authors, and today *nothing* is
-- approved, so it returns zero rows. Author-less outputs must also survive — the
-- approved 2025 report lists them.
--
-- ponytail: no join to output_taxonomy. It holds 74 rows and matches only 13 of the 51
-- distinct category_paths actually in use, so it cannot order anything. Section order is
-- the report's fixed editorial 1..11 list, which lives with the section titles and intro
-- paragraphs in the Edge Function; subsections sort alphabetically. Revisit if
-- output_taxonomy ever gets backfilled to full coverage.

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
      -- Section / subsection of the report. The taxonomy leaf is an authorship role
      -- ("Único autor" / "Co-autor"), never a subsection, so the subsection is the
      -- penultimate segment — which `outputs` already carries denormalised as `subtype`.
      coalesce(nullif(btrim(o.macro_type), ''), 'Sem categoria')             as section,
      coalesce(nullif(btrim(o.subtype), ''), nullif(btrim(o.type), ''), '—') as subsection,
      o.type,
      o.category_path,
      o.full_reference,
      o.doi,
      o.url,
      -- 'Planeado' / 'Submetido' are listed but excluded from the headline counts.
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
      and (p_year is null or o.reporting_year = p_year)
      and (p_filters->>'section' is null or o.macro_type = p_filters->>'section')
      and (p_filters->>'type'    is null or o.type      = p_filters->>'type')
      -- ponytail: p_kind selects the template, not the rows — all three report types
      -- render the same output set. Branch here only if a kind ever needs other tables.
      and p_kind is not null
  ) r;
$$;

comment on function public.report_data(text, int, jsonb) is
  'Flat jsonb rows backing the Typst PDF reports. Grouping/formatting live in the report Edge Function.';

grant execute on function public.report_data(text, int, jsonb) to anon, authenticated;

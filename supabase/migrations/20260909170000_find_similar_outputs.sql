-- BP-16 / DOI-first Add output: what the researcher is about to save, matched
-- against the directory BEFORE saving — exact DOI first, then trigram title
-- similarity (pg_trgm, same index as the merge candidates). Security invoker,
-- so a caller sees only rows outputs_read lets them see. Applied live 2026-09-09.
create or replace function public.find_similar_outputs(p_doi text, p_title text)
returns table (
  id uuid,
  title text,
  reporting_year int,
  approval_status text,
  doi text,
  score real,
  match text
)
language sql
stable
security invoker
set search_path = public
as $$
  select * from (
    select o.id, o.title, o.reporting_year, o.approval_status, o.doi,
           1.0::real as score, 'doi'::text as match
      from public.outputs o
     where nullif(btrim(p_doi), '') is not null
       and o.merged_into is null
       and lower(o.doi) = lower(btrim(p_doi))
    union all
    select o.id, o.title, o.reporting_year, o.approval_status, o.doi,
           similarity(lower(btrim(p_title)), o.title_norm) as score, 'title'
      from public.outputs o
     where nullif(btrim(p_title), '') is not null
       and o.merged_into is null
       and similarity(lower(btrim(p_title)), o.title_norm) >= 0.8
  ) m
  order by score desc
  limit 5;
$$;

revoke all on function public.find_similar_outputs(text, text) from public, anon;
grant execute on function public.find_similar_outputs(text, text) to authenticated;

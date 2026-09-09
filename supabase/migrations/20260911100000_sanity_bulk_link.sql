-- Sanity bridge, step 1: safe bulk linking and Sanity values as suggestions.
--
-- Rule kept from the enrichment pipeline: nothing here overwrites a canonical
-- people value. The bulk action only records the link (people.sanity_id) and
-- files every value Sanity has and we lack as an enrichment_suggestions row
-- with source 'sanity'. Admins accept per field on the person page, which logs
-- to change_log with that source — and change_log (admin-only RLS) is the
-- hidden provenance record. No new column on people, nothing new to leak.

-- ------------------------------------------------------------------ helper
-- One pending suggestion per (person, field, value); returns 1 when inserted.
create or replace function public.sanity_suggest(
  p_person uuid, p_field text, p_current text, p_suggested text, p_confidence numeric default 0.9
) returns int
language plpgsql security definer set search_path = public as $$
begin
  if p_suggested is null or btrim(p_suggested) = '' then return 0; end if;
  if p_current is not null and btrim(p_current) <> '' then return 0; end if;
  if exists (
    select 1 from public.enrichment_suggestions
     where subject_type = 'person' and subject_id = p_person and field = p_field
       and suggested_value = p_suggested and status = 'pending'
  ) then return 0; end if;
  insert into public.enrichment_suggestions
    (subject_type, subject_id, field, current_value, suggested_value, source, confidence, status)
  values ('person', p_person, p_field, p_current, p_suggested, 'sanity', p_confidence, 'pending');
  return 1;
end $$;

-- ------------------------------------------------------------------ bulk link
-- Links every unambiguous ORCID/email match that has no email conflict.
-- Name-token matches (human review) and email conflicts stay in the queue.
create or replace function public.bulk_link_sanity_matches()
returns table (linked int, suggestions int, skipped int)
language plpgsql security definer set search_path = public as $$
declare
  r record;
  p public.people%rowtype;
  v_linked int := 0; v_sugg int := 0; v_skipped int := 0;
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;

  -- The FOR cursor is opened once; rows linked below do not reshuffle it.
  for r in select * from public.sanity_member_matches loop
    select * into p from public.people where id = r.person_id;
    if r.match_kind = 'name' or r.ambiguous or (r.conflicts ? 'email') or p.sanity_id is not null then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    update public.people set sanity_id = r.sanity_id, updated_at = now() where id = r.person_id;
    insert into public.change_log (subject_type, subject_id, field, old_value, new_value, source, actor)
    values ('person', r.person_id, 'sanity_id', null, r.sanity_id, 'sanity', auth.uid());
    update public.sanity_docs set decision = 'linked', decided_at = now(), decided_by = auth.uid()
     where id = r.sanity_id;
    v_linked := v_linked + 1;

    v_sugg := v_sugg
      + public.sanity_suggest(r.person_id, 'orcid',      p.orcid,      r.sanity_orcid)
      + public.sanity_suggest(r.person_id, 'ciencia_id', p.ciencia_id, r.sanity_ciencia_id)
      + public.sanity_suggest(r.person_id, 'bio',        p.bio,        r.sanity_bio, 0.7)
      + public.sanity_suggest(r.person_id, 'photo_url',  p.photo_url,  r.sanity_photo_url, 0.7)
      + case when r.sanity_name is distinct from p.preferred_name
             then public.sanity_suggest(r.person_id, 'legal_name', p.legal_name, r.sanity_name, 0.5)
             else 0 end;
  end loop;

  return query select v_linked, v_sugg, v_skipped;
end $$;

-- ------------------------------------------------------------------ provenance
-- Latest recorded source per person field. Admin-only by change_log's RLS.
create or replace view public.person_field_sources
with (security_invoker = true) as
select distinct on (subject_id, field)
       subject_id as person_id, field, coalesce(source, 'manual') as source, changed_at
from public.change_log
where subject_type = 'person' and field is not null
order by subject_id, field, changed_at desc;

grant execute on function public.sanity_suggest(uuid, text, text, text, numeric) to authenticated;
grant execute on function public.bulk_link_sanity_matches() to authenticated;
grant select on public.person_field_sources to authenticated;

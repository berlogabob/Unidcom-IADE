-- Person merge: soft-merge duplicate people (e.g. "Sara Gancho" == "Sara Patrícia Martins Gancho").
-- Losers become hidden tombstones (merged_into set); all their relationships move to the survivor,
-- in ONE transaction. Nothing is hard-deleted → a bad merge is reversible.

alter table public.people add column if not exists merged_into uuid references public.people(id);
create index if not exists people_merged_into_idx on public.people(merged_into);

create or replace function public.merge_people(
  p_survivor uuid,
  p_losers uuid[],
  p_fields jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth uuid;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  if p_survivor = any(p_losers) then
    raise exception 'survivor cannot also be a loser';
  end if;

  -- output_authors (PK output_id, person_id): move loser links unless survivor already links it.
  update public.output_authors oa set person_id = p_survivor
   where oa.person_id = any(p_losers)
     and not exists (select 1 from public.output_authors s
                      where s.output_id = oa.output_id and s.person_id = p_survivor);
  delete from public.output_authors where person_id = any(p_losers);

  -- project_members (PK project_id, person_id)
  update public.project_members pm set person_id = p_survivor
   where pm.person_id = any(p_losers)
     and not exists (select 1 from public.project_members s
                      where s.project_id = pm.project_id and s.person_id = p_survivor);
  delete from public.project_members where person_id = any(p_losers);

  -- person_tags (PK person_id, tag_id)
  update public.person_tags pt set person_id = p_survivor
   where pt.person_id = any(p_losers)
     and not exists (select 1 from public.person_tags s
                      where s.tag_id = pt.tag_id and s.person_id = p_survivor);
  delete from public.person_tags where person_id = any(p_losers);

  -- enrichment suggestions that point at a loser person
  update public.enrichment_suggestions
     set subject_id = p_survivor
   where subject_type = 'person' and subject_id = any(p_losers);

  -- auth_user_id: null losers FIRST (unique index), then hand a freed login to survivor if it has none.
  select auth_user_id into v_auth
    from public.people where id = any(p_losers) and auth_user_id is not null limit 1;
  update public.people set auth_user_id = null where id = any(p_losers);
  if v_auth is not null then
    update public.people set auth_user_id = v_auth where id = p_survivor and auth_user_id is null;
  end if;

  -- apply the chosen field values to the survivor (coalesce: only provided keys change)
  update public.people set
    preferred_name  = coalesce(p_fields->>'preferred_name', preferred_name),
    legal_name      = coalesce(p_fields->>'legal_name', legal_name),
    bio             = coalesce(p_fields->>'bio', bio),
    photo_url       = coalesce(p_fields->>'photo_url', photo_url),
    email           = coalesce(p_fields->>'email', email),
    orcid           = coalesce(p_fields->>'orcid', orcid),
    ciencia_id      = coalesce(p_fields->>'ciencia_id', ciencia_id),
    membership_type = coalesce(p_fields->>'membership_type', membership_type),
    status          = coalesce(p_fields->>'status', status),
    updated_at      = now()
  where id = p_survivor;

  -- soft-merge the losers (hidden tombstones)
  update public.people
     set merged_into = p_survivor, public_visibility = false, updated_at = now()
   where id = any(p_losers);
end;
$$;

grant execute on function public.merge_people(uuid, uuid[], jsonb) to authenticated;

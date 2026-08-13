-- Researchers record their own outputs.
--
-- Rui asked for filters and an add form driven by the same cascading category
-- selector — "this works for both filtering my outputs as well as when i click
-- +add" (2026-08-10). There was no +add: `outputs_write` and `oa_write` are both
-- is_admin(), so a researcher could not create an output or link themselves as
-- its author. The only route in was the ORCID candidates list.
--
-- One audited doorway rather than a looser policy, the same trade this repo
-- already made for promote_output_candidate in 20260805090000. The RLS policies
-- are untouched: a researcher still cannot write `outputs` directly, and this
-- function decides exactly what they may set.
--
-- Like promotion, a self-reported output lands approval_status='pending', so
-- nothing reaches the public site without UNIDCOM approval.
create or replace function public.create_my_output(p_fields jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_person uuid;
  v_output uuid;
  v_title  text;
  v_doi    text;
begin
  -- The person comes from the session, never from an argument: an argument
  -- would let any signed-in caller file work under someone else's name.
  select p.id into v_person
    from public.people p
   where p.auth_user_id = auth.uid()
     and p.merged_into is null;
  if v_person is null then
    raise exception 'not authorized';
  end if;

  -- Whitelist. Everything the caller may set is named here; approval_status,
  -- affiliation, source, fct_selected and merged_into are deliberately absent
  -- and forced below, so no payload can talk its way past the approval gate.
  v_title := nullif(btrim(p_fields ->> 'title'), '');
  v_doi   := nullif(btrim(p_fields ->> 'doi'), '');
  if v_title is null then
    raise exception 'title is required';
  end if;

  -- Reuse rather than duplicate: DOI-exact, then trigram title match. Without
  -- this a researcher adding a paper a co-author already filed creates a twin
  -- that v_output_duplicate_pairs flags the moment it is saved.
  v_output := public.match_existing_output(v_doi, v_title);

  if v_output is null then
    insert into public.outputs (
      title, reporting_year, doi, url,
      full_reference, output_status,
      category_path, macro_type, type, subtype,
      source, approval_status, affiliation
    )
    values (
      v_title,
      (p_fields ->> 'reporting_year')::int,
      v_doi,
      nullif(btrim(p_fields ->> 'url'), ''),
      nullif(btrim(p_fields ->> 'full_reference'), ''),
      nullif(btrim(p_fields ->> 'output_status'), ''),
      nullif(btrim(p_fields ->> 'category_path'), ''),
      nullif(btrim(p_fields ->> 'macro_type'), ''),
      nullif(btrim(p_fields ->> 'type'), ''),
      nullif(btrim(p_fields ->> 'subtype'), ''),
      -- Forced, all three. 'unidcom' matters beyond bookkeeping: fetchOutputs
      -- filters on affiliation='unidcom' by default, so anything else would be
      -- invisible in the very admin list that has to review it.
      'manual', 'pending', 'unidcom'
    )
    on conflict (doi) do nothing
    returning id into v_output;

    -- NULL dois never conflict, which is why the title pass above must exist;
    -- this covers the race where two callers file the same DOI at once.
    if v_output is null and v_doi is not null then
      select id into v_output
        from public.outputs
       where doi = v_doi and merged_into is null;
    end if;
    if v_output is null then
      raise exception 'could not create output';
    end if;
  end if;

  -- Idempotent, and the reason this cannot be done from the client at all:
  -- oa_write is admin-only.
  insert into public.output_authors (output_id, person_id)
  values (v_output, v_person)
  on conflict (output_id, person_id) do nothing;

  -- Audited here, inside the definer body, because it cannot be audited
  -- anywhere else: cl_write is is_admin(), so the client's logChanges() insert
  -- is rejected and swallowed for every non-admin, and trg_log_output_status
  -- fires on UPDATE only. This is the first researcher action in the app that
  -- actually leaves a trail.
  insert into public.change_log
    (subject_type, subject_id, field, old_value, new_value, source, actor)
  values
    ('output', v_output, 'created', null, v_title, 'manual', auth.uid());

  return v_output;
end;
$$;

revoke execute on function public.create_my_output(jsonb) from public, anon;
grant execute on function public.create_my_output(jsonb) to authenticated;

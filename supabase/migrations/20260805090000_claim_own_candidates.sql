-- W2: researchers claim their own ORCID candidates from /app/profile.
-- Owner may read, promote and reject their OWN candidate rows; admin paths
-- unchanged. Promoted outputs still land approval_status='pending', so nothing
-- reaches the public site without UNIDCOM approval.

-- 1. Owners read their own candidates (oc_admin_all keeps covering admins).
create policy oc_own_read on public.output_candidates for select using (
  exists (select 1 from public.people p
           where p.id = person_id and p.auth_user_id = auth.uid()));

-- 2. Promote: admin OR candidate owner. Only the admin (reviewer) may overrule
-- the classifier's affiliation; the owner path keeps the candidate's own value.
-- Authorization needs the row, so the not-found check now precedes the gate —
-- ids are uuids, existence leakage is not a concern at this scale.
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
  select * into c from public.output_candidates where id = p_candidate for update;
  if not found then
    raise exception 'candidate not found';
  end if;
  if not (public.is_admin() or exists (
        select 1 from public.people p
         where p.id = c.person_id and p.auth_user_id = auth.uid())) then
    raise exception 'not authorized';
  end if;
  if c.status <> 'pending' then
    raise exception 'candidate already %', c.status;
  end if;

  v_aff := case when public.is_admin()
                then coalesce(p_affiliation, c.affiliation)
                else c.affiliation end;

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

-- 3. Reject via RPC (admin or owner) so researchers can dismiss "not mine"
-- without a column-writable RLS policy on the table.
create or replace function public.reject_output_candidate(p_candidate uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.output_candidates;
begin
  select * into c from public.output_candidates where id = p_candidate for update;
  if not found then
    raise exception 'candidate not found';
  end if;
  if not (public.is_admin() or exists (
        select 1 from public.people p
         where p.id = c.person_id and p.auth_user_id = auth.uid())) then
    raise exception 'not authorized';
  end if;
  if c.status <> 'pending' then
    raise exception 'candidate already %', c.status;
  end if;
  update public.output_candidates
     set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now()
   where id = p_candidate;
end;
$$;

revoke execute on function public.reject_output_candidate(uuid) from public, anon;
grant execute on function public.reject_output_candidate(uuid) to authenticated;

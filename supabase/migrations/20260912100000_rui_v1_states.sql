-- Rui's v1.0 spec (10 Sep 2026), wave D1: the four schema facts the UI cannot
-- fake. All additive; nothing renamed, no state machine touched. PLAN.md Phase D.

-- ------------------------------------------------------------ D1.1 website
-- "Approved does not necessarily mean published" (Doc 2 §P). Until now approval
-- WAS publication: sync.py published every approved row. Backfilled to
-- 'published' so the site does not change on the day this lands; from here on
-- an admin decides per output.
alter table public.outputs
  add column if not exists website_status text not null default 'not_published'
    check (website_status in ('not_published', 'pending', 'published', 'error'));
update public.outputs set website_status = 'published' where approval_status = 'approved';
comment on column public.outputs.website_status is
  'Public-site state, independent of approval_status. sync.py publishes only ''published''.';

-- Same audit trail approval already has (log_status_change, 20260804120000).
drop trigger if exists trg_log_output_website on public.outputs;
create trigger trg_log_output_website after update on public.outputs
  for each row when (old.website_status is distinct from new.website_status)
  execute function public.log_status_change('output', 'website_status');

-- ------------------------------------------------------------ D1.2 taxonomy kind
-- Doc 2 §K: not every RIMS category is a publication, and the portal must not
-- invent a parallel taxonomy — so the distinction lives on the taxonomy itself.
-- Publication roots are the ones sync.py already treats as publications
-- (PUBLICATION_MACRO_TYPES) plus conference contributions and patents; the rest
-- are research activities (organisation, training, projects, awards, missions,
-- valorisation, management).
alter table public.output_taxonomy
  add column if not exists kind text check (kind in ('publication', 'activity'));
update public.output_taxonomy
   set kind = case
     when segments[1] in (
       'Livros',
       'Artigos em revistas',
       'Conferência em congressos (sem publicação)',
       'Patentes e contratos industriais'
     ) then 'publication'
     else 'activity'
   end;
alter table public.output_taxonomy alter column kind set not null;

-- ------------------------------------------------------------ D1.3 staged output edits
-- Researchers have no write on outputs (outputs_write is is_admin()) and are
-- not getting one. They edit the way they already edit their signature fields
-- (20260908120000): a suggestion row per changed field, accepted in the admin
-- Review queue. Same two policies, now covering outputs they author.
drop policy if exists es_owner_insert on public.enrichment_suggestions;
create policy es_owner_insert on public.enrichment_suggestions
  for insert to authenticated
  with check (
    source = 'researcher'
    and (
      (subject_type = 'person'
        and subject_id in (select id from public.people where auth_user_id = auth.uid()))
      or
      (subject_type = 'output'
        and subject_id in (
          select oa.output_id
            from public.output_authors oa
            join public.people p on p.id = oa.person_id
           where p.auth_user_id = auth.uid()))
    )
  );

drop policy if exists es_owner_select on public.enrichment_suggestions;
create policy es_owner_select on public.enrichment_suggestions
  for select to authenticated
  using (
    (subject_type = 'person'
      and subject_id in (select id from public.people where auth_user_id = auth.uid()))
    or
    (subject_type = 'output'
      and subject_id in (
        select oa.output_id
          from public.output_authors oa
          join public.people p on p.id = oa.person_id
         where p.auth_user_id = auth.uid()))
  );

-- ------------------------------------------------------------ D1.4 last ORCID sync
-- "Last synchronised" (Doc 1 §6.2). Stamped by scripts/orcid_works.py per
-- person it processed. ponytail: not shielded in protect_people_cols() — the
-- script writes with the service key, and a researcher forging their own sync
-- timestamp harms nobody.
alter table public.people add column if not exists orcid_synced_at timestamptz;
comment on column public.people.orcid_synced_at is
  'Last time scripts/orcid_works.py staged this person''s ORCID works.';

-- ------------------------------------------------------------ D1.5 project relationship
-- Wizard step "Relationships" (Doc 2 §I): a researcher may link a new output to
-- projects they are a member of. po_write is admin-only, so the link is made
-- here, inside the definer body, and only for projects the caller belongs to.
-- The one-argument form is dropped: with a defaulted second parameter both
-- signatures would match a one-argument call and Postgres would refuse it.
drop function if exists public.create_my_output(jsonb);
create or replace function public.create_my_output(p_fields jsonb, p_project_ids uuid[] default '{}')
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
  select p.id into v_person
    from public.people p
   where p.auth_user_id = auth.uid()
     and p.merged_into is null;
  if v_person is null then
    raise exception 'not authorized';
  end if;

  v_title := nullif(btrim(p_fields ->> 'title'), '');
  v_doi   := nullif(btrim(p_fields ->> 'doi'), '');
  if v_title is null then
    raise exception 'title is required';
  end if;

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
      'manual', 'pending', 'unidcom'
    )
    on conflict (doi) do nothing
    returning id into v_output;

    if v_output is null and v_doi is not null then
      select id into v_output
        from public.outputs
       where doi = v_doi and merged_into is null;
    end if;
    if v_output is null then
      raise exception 'could not create output';
    end if;
  end if;

  insert into public.output_authors (output_id, person_id)
  values (v_output, v_person)
  on conflict (output_id, person_id) do nothing;

  -- Only projects the caller is a member of; anything else in the array is
  -- silently dropped rather than rejected, so a stale picker cannot block a save.
  insert into public.project_outputs (project_id, output_id)
  select pm.project_id, v_output
    from public.project_members pm
   where pm.person_id = v_person
     and pm.project_id = any (p_project_ids)
  on conflict do nothing;

  insert into public.change_log
    (subject_type, subject_id, field, old_value, new_value, source, actor)
  values
    ('output', v_output, 'created', null, v_title, 'manual', auth.uid());

  return v_output;
end;
$$;

revoke execute on function public.create_my_output(jsonb, uuid[]) from public, anon;
grant execute on function public.create_my_output(jsonb, uuid[]) to authenticated;

-- Sanity bridge, phases A/B: a read-only snapshot of the agency's Sanity dataset
-- (project vj0axykv) inside Supabase, plus admin-reviewed links from our rows to
-- Sanity documents. Nothing here writes to Sanity; the push is a later phase.
--
-- Not a mirror: Sanity holds the pre-2024 archive (1596 outputs, 43 projects,
-- 249 members), Supabase holds the current unit. The link column just records
-- "this row is that document" so the comparison and any later push are stable.

-- ------------------------------------------------------------------ snapshot
create table public.sanity_docs (
  id text primary key,                       -- Sanity _id (member-<md5>, uuid, ...)
  type text not null,                        -- Sanity _type
  doc jsonb not null,                        -- the whole document, verbatim
  sanity_updated_at timestamptz,             -- _updatedAt
  pulled_at timestamptz not null default now(),
  decision text check (decision in ('linked','imported','ignored')),
  decided_at timestamptz,
  decided_by uuid references auth.users on delete set null
);
create index sanity_docs_type_idx on public.sanity_docs (type);
create index sanity_docs_decision_idx on public.sanity_docs (type, decision);

alter table public.sanity_docs enable row level security;
-- Admin-only. sanity_pull.py loads with the service key, which bypasses RLS.
create policy sanity_docs_admin_all on public.sanity_docs
  for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------------ links
-- The pull only ever upserts, never deletes, so the FK cannot dangle.
alter table public.people   add column sanity_id text unique references public.sanity_docs(id);
alter table public.projects add column sanity_id text unique references public.sanity_docs(id);
alter table public.outputs  add column sanity_id text unique references public.sanity_docs(id);
alter table public.labs     add column sanity_id text unique references public.sanity_docs(id);
alter table public.clusters add column sanity_id text unique references public.sanity_docs(id);

-- ------------------------------------------------------------------ helpers
-- Sanity image asset ref "image-<sha1>-<w>x<h>-<ext>" -> public CDN URL.
create or replace function public.sanity_image_url(p_ref text, p_project text default 'vj0axykv', p_dataset text default 'production')
returns text language sql immutable as $$
  select case
    when p_ref ~ '^image-[0-9a-f]+-\d+x\d+-[a-z0-9]+$'
    then format('https://cdn.sanity.io/images/%s/%s/%s', p_project, p_dataset,
                regexp_replace(substr(p_ref, 7), '-([a-z0-9]+)$', '.\1'))
  end
$$;

-- Accent-insensitive lower-case word set, mirroring _normalizeName in
-- lib/data/supabase.dart. unaccent() is only STABLE, so this is too — fine for
-- a view, not for an index.
create or replace function public.name_tokens(p text)
returns text[] language sql stable as $$
  select coalesce(
    array(select t from regexp_split_to_table(lower(public.unaccent(coalesce(p, ''))), '[^a-z0-9]+') t where t <> ''),
    '{}'::text[])
$$;

-- Same rule as groupMergeCandidates(): one name's token set contains the other's,
-- both with at least two tokens. "Sara Gancho" ⊆ "Sara Patrícia Martins Gancho".
create or replace function public.name_tokens_contain(a text, b text)
returns boolean language sql stable as $$
  select cardinality(public.name_tokens(a)) >= 2
     and cardinality(public.name_tokens(b)) >= 2
     and (public.name_tokens(a) <@ public.name_tokens(b) or public.name_tokens(b) <@ public.name_tokens(a))
$$;

-- Sanity memberType title -> our membership_type. Many-to-one on purpose.
create or replace function public.sanity_membership_type(p_title text)
returns text language sql immutable as $$
  select case p_title
    when 'Integrated' then 'integrated'
    when 'Ph.D. Candidate' then 'phd_student'
    when 'Ph. D. Student in international mobility' then 'phd_student'
    when 'Doctorate Researcher' then 'collaborator'
    when 'Non-Doctorate Researcher' then 'collaborator'
    when 'Pos-Doc Researcher' then 'collaborator'
    when 'Research Fellow' then 'collaborator'
    when 'Scholarship Fellow' then 'collaborator'
    when 'External Advisory Board' then 'advisory_board'
    else 'external'   -- Visiting researcher, Mentor, Other, none
  end
$$;

-- ------------------------------------------------------------------ matches
-- One row per undecided Sanity member: the single best Supabase person by
-- ORCID (1), then email (2), then name tokens (3). `ambiguous` says another
-- person tied at the same rank, so the admin must look. `conflicts` lists the
-- fields both sides fill with different values.
create or replace view public.sanity_member_matches
with (security_invoker = true) as
with m as (
  select s.id as sanity_id,
         s.doc->>'name'  as sanity_name,
         s.doc->>'email' as sanity_email,
         s.doc->>'orcid' as sanity_orcid,
         s.doc->>'cienciaId' as sanity_ciencia_id,
         s.doc->>'shortBio'  as sanity_bio,
         public.sanity_image_url(s.doc->'photo'->'asset'->>'_ref') as sanity_photo_url,
         coalesce((s.doc->>'unlistedFromPeopleList')::boolean, false) as sanity_unlisted,
         (select t.doc->>'title' from public.sanity_docs t where t.id = s.doc->'type'->>'_ref') as sanity_member_type
  from public.sanity_docs s
  where s.type = 'member' and s.decision is null
    and not exists (select 1 from public.people p where p.sanity_id = s.id)
),
cand as (
  select m.*, p.id as person_id,
         case
           when m.sanity_orcid is not null and m.sanity_orcid = p.orcid then 1
           when m.sanity_email is not null and lower(m.sanity_email) = lower(p.email) then 2
           when public.name_tokens_contain(m.sanity_name, p.preferred_name)
             or public.name_tokens_contain(m.sanity_name, p.legal_name) then 3
         end as rank
  from m cross join public.people p
  where p.merged_into is null
),
ranked as (
  select *, count(*) over (partition by sanity_id, rank) as n_same_rank
  from cand where rank is not null
)
select distinct on (r.sanity_id)
       r.sanity_id, r.person_id,
       case r.rank when 1 then 'orcid' when 2 then 'email' else 'name' end as match_kind,
       r.n_same_rank > 1 as ambiguous,
       r.sanity_name, r.sanity_email, r.sanity_orcid, r.sanity_ciencia_id, r.sanity_bio,
       r.sanity_photo_url, r.sanity_unlisted, r.sanity_member_type,
       p.preferred_name, p.email, p.orcid, p.ciencia_id, p.status, p.membership_type,
       coalesce((
         select jsonb_object_agg(v.k, jsonb_build_object('supabase', v.sv, 'sanity', v.xv))
         from (values
           ('preferred_name', p.preferred_name, r.sanity_name),
           ('email',          p.email,          r.sanity_email),
           ('orcid',          p.orcid,          r.sanity_orcid),
           ('ciencia_id',     p.ciencia_id,     r.sanity_ciencia_id),
           ('bio',            p.bio,            r.sanity_bio)
         ) as v(k, sv, xv)
         where v.sv is not null and v.xv is not null and v.sv <> v.xv
       ), '{}'::jsonb) as conflicts
from ranked r
join public.people p on p.id = r.person_id
order by r.sanity_id, r.rank, p.preferred_name;

-- ------------------------------------------------------------------ deterministic links
-- Labs and the five current clusters correspond 1:1 by code. Called by
-- sanity_pull.py after each load; idempotent.
create or replace function public.sanity_link_by_code()
returns table (labs_linked int, clusters_linked int)
language plpgsql security definer set search_path = public as $$
declare v_labs int; v_clusters int;
begin
  if not public.is_admin() and auth.role() <> 'service_role' then
    raise exception 'not authorized';
  end if;
  update public.labs l set sanity_id = s.id
    from public.sanity_docs s
    join public.sanity_docs t on t.id = s.doc->'type'->>'_ref' and t.type = 'labType'
   where s.type = 'lab' and l.sanity_id is null
     and lower(t.doc->>'title') = lower(l.code);
  get diagnostics v_labs = row_count;
  update public.clusters c set sanity_id = s.id
    from public.sanity_docs s
   where s.type = 'cluster' and c.sanity_id is null
     and s.doc->>'code' is not null and s.doc->>'code' = c.code;
  get diagnostics v_clusters = row_count;
  return query select v_labs, v_clusters;
end $$;

-- ------------------------------------------------------------------ admin decisions
-- Link an existing person to a Sanity member and apply only the fields the
-- admin picked in the matrix. Every applied field lands in change_log.
create or replace function public.link_sanity_member(
  p_person uuid, p_sanity_id text, p_fields jsonb default '{}'::jsonb
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb; v_key text; v_val text;
  v_allowed text[] := array['preferred_name','legal_name','email','orcid','ciencia_id','bio','photo_url','membership_type','status'];
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  if not exists (select 1 from public.sanity_docs where id = p_sanity_id and type = 'member') then
    raise exception 'unknown sanity member %', p_sanity_id;
  end if;
  select to_jsonb(p) into v_old from public.people p where p.id = p_person and p.merged_into is null;
  if v_old is null then raise exception 'unknown or merged person %', p_person; end if;

  for v_key, v_val in select key, value from jsonb_each_text(p_fields) loop
    if not (v_key = any(v_allowed)) then
      raise exception 'field % cannot be set from Sanity', v_key;
    end if;
    if v_val is distinct from (v_old->>v_key) then
      insert into public.change_log (subject_type, subject_id, field, old_value, new_value, source, actor)
      values ('person', p_person, v_key, v_old->>v_key, v_val, 'sanity', auth.uid());
    end if;
  end loop;

  update public.people set
    preferred_name  = coalesce(p_fields->>'preferred_name', preferred_name),
    legal_name      = coalesce(p_fields->>'legal_name', legal_name),
    email           = coalesce(p_fields->>'email', email),
    orcid           = coalesce(p_fields->>'orcid', orcid),
    ciencia_id      = coalesce(p_fields->>'ciencia_id', ciencia_id),
    bio             = coalesce(p_fields->>'bio', bio),
    photo_url       = coalesce(p_fields->>'photo_url', photo_url),
    membership_type = coalesce(p_fields->>'membership_type', membership_type),
    status          = coalesce(p_fields->>'status', status),
    sanity_id       = p_sanity_id,
    updated_at      = now()
  where id = p_person;

  insert into public.change_log (subject_type, subject_id, field, old_value, new_value, source, actor)
  values ('person', p_person, 'sanity_id', v_old->>'sanity_id', p_sanity_id, 'sanity', auth.uid());

  update public.sanity_docs set decision = 'linked', decided_at = now(), decided_by = auth.uid()
   where id = p_sanity_id;
end $$;

-- Create a person from a Sanity-only member. Lands as an unconfirmed draft that
-- is not publicly visible, so importing never publishes anything by itself.
create or replace function public.import_sanity_member(p_sanity_id text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_doc jsonb; v_id uuid; v_type text;
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  select doc into v_doc from public.sanity_docs where id = p_sanity_id and type = 'member';
  if v_doc is null then raise exception 'unknown sanity member %', p_sanity_id; end if;
  if exists (select 1 from public.people where sanity_id = p_sanity_id) then
    raise exception 'sanity member % is already linked', p_sanity_id;
  end if;
  select t.doc->>'title' into v_type from public.sanity_docs t where t.id = v_doc->'type'->>'_ref';

  insert into public.people (preferred_name, email, orcid, ciencia_id, bio, photo_url,
                             membership_type, status, profile_status, public_visibility, sanity_id, notes)
  values (v_doc->>'name', v_doc->>'email', v_doc->>'orcid', v_doc->>'cienciaId', v_doc->>'shortBio',
          public.sanity_image_url(v_doc->'photo'->'asset'->>'_ref'),
          public.sanity_membership_type(v_type), 'a_confirmar', 'draft', false, p_sanity_id,
          'Imported from Sanity ' || p_sanity_id || ' (' || coalesce(v_type, 'no type') || ')')
  returning id into v_id;

  insert into public.change_log (subject_type, subject_id, field, old_value, new_value, source, actor)
  values ('person', v_id, 'sanity_id', null, p_sanity_id, 'sanity', auth.uid());
  update public.sanity_docs set decision = 'imported', decided_at = now(), decided_by = auth.uid()
   where id = p_sanity_id;
  return v_id;
end $$;

-- Mark a Sanity doc ignored (or clear the decision with null) so it leaves the queue.
create or replace function public.set_sanity_decision(p_sanity_id text, p_decision text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  if p_decision is not null and p_decision <> 'ignored' then
    raise exception 'only ignored or null can be set here';
  end if;
  update public.sanity_docs
     set decision = p_decision,
         decided_at = case when p_decision is null then null else now() end,
         decided_by = case when p_decision is null then null else auth.uid() end
   where id = p_sanity_id;
end $$;

grant execute on function public.sanity_link_by_code() to authenticated, service_role;
grant execute on function public.link_sanity_member(uuid, text, jsonb) to authenticated;
grant execute on function public.import_sanity_member(text) to authenticated;
grant execute on function public.set_sanity_decision(text, text) to authenticated;
grant select on public.sanity_member_matches to authenticated;

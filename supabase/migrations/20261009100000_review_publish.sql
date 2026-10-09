-- Rui v1.1 (8 Oct 2026) "Admin: review & publish".
-- Review is per item; publishing is a separate, batched admin step.
--   * A researcher's proposed change (enrichment_suggestions, source='researcher')
--     is Accepted -> 'ready' (value NOT applied: the site keeps the published
--     version, ST-3), Rejected, or sent back as 'change_requested'.
--   * New outputs follow the same path on outputs.approval_status; accepted ->
--     website_status 'ready'.
--   * publish_researchers() applies ready changes and flips the website flags;
--     the nightly unidcom-site sync then picks them up (it reads these flags).
-- Both RPCs are admin-only (JWT app_metadata.role = 'admin') and audit every
-- decision into change_log (CK-2).

-- ---------------------------------------------------------------- states
alter table public.enrichment_suggestions
  drop constraint enrichment_suggestions_status_check,
  add constraint enrichment_suggestions_status_check
    check (status in ('draft','pending','accepted','rejected','superseded','ready','change_requested'));
alter table public.enrichment_suggestions
  add column if not exists review_comment text,
  add column if not exists decided_by uuid references auth.users on delete set null,
  add column if not exists decided_at timestamptz;

alter table public.outputs drop constraint outputs_approval_status_chk;
alter table public.outputs add constraint outputs_approval_status_chk
  check (approval_status in ('to_validate','pending','approved','rejected','change_requested'));
alter table public.outputs add column if not exists review_note text;
alter table public.outputs drop constraint if exists outputs_website_status_check;
alter table public.outputs add constraint outputs_website_status_check
  check (website_status in ('not_published','pending','ready','published','error'));

alter table public.people
  add column if not exists website_status text not null default 'not_published'
    check (website_status in ('not_published','ready','published','error')),
  add column if not exists published_at timestamptz;
update public.people set website_status = 'published' where public_visibility;

-- A newer researcher edit also replaces a change request on the same field.
create or replace function public.supersede_researcher_suggestions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update enrichment_suggestions
     set status = 'superseded'
   where source = 'researcher'
     and subject_type = new.subject_type
     and subject_id = new.subject_id
     and field = new.field
     and status in ('draft', 'pending', 'change_requested');
  return new;
end;
$$;

-- ---------------------------------------------------------- finish_review
-- p_decisions: [{"kind":"field"|"output","id":uuid,"decision":"accepted"|
-- "rejected"|"change_requested","comment":text}, ...] — all-or-nothing.
create or replace function public.finish_review(p_person uuid, p_decisions jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  d          jsonb;
  v_kind     text;
  v_id       uuid;
  v_dec      text;
  v_comment  text;
  v_n        int;
  v_accepted int := 0;
  v_returned int := 0;
  v_note     text;
  v_person_field boolean := false;
begin
  if not public.is_admin() then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if not exists (select 1 from people where id = p_person and merged_into is null) then
    raise exception 'unknown researcher' using errcode = '22023';
  end if;

  for d in select * from jsonb_array_elements(p_decisions) loop
    v_kind    := d ->> 'kind';
    v_id      := (d ->> 'id')::uuid;
    v_dec     := d ->> 'decision';
    v_comment := nullif(btrim(coalesce(d ->> 'comment', '')), '');
    if v_dec not in ('accepted','rejected','change_requested') or v_kind not in ('field','output') then
      raise exception 'bad decision %', d using errcode = '22023';
    end if;
    if v_dec = 'change_requested' and v_comment is null then
      raise exception 'change request needs a comment' using errcode = '22023';
    end if;

    if v_kind = 'field' then
      update enrichment_suggestions s
         set status = case v_dec when 'accepted' then 'ready' else v_dec end,
             review_comment = v_comment, decided_by = auth.uid(), decided_at = now()
       where s.id = v_id and s.source = 'researcher' and s.status = 'pending'
         and ((s.subject_type = 'person' and s.subject_id = p_person)
           or (s.subject_type = 'output' and exists (
                 select 1 from output_authors oa
                  where oa.output_id = s.subject_id and oa.person_id = p_person)));
      get diagnostics v_n = row_count;
      insert into change_log (subject_type, subject_id, field, new_value, source, actor)
        select s.subject_type, s.subject_id, s.field,
               v_dec || coalesce(': ' || v_comment, ''), 'review', auth.uid()
          from enrichment_suggestions s where s.id = v_id;
      v_person_field := v_person_field
        or exists (select 1 from enrichment_suggestions s
                    where s.id = v_id and s.subject_type = 'person');
    else
      update outputs o
         set approval_status = case v_dec when 'accepted' then 'approved' else v_dec end,
             website_status  = case when v_dec = 'accepted' then 'ready' else o.website_status end,
             review_note     = case when v_dec = 'change_requested' then v_comment else null end,
             rejection_reason = case when v_dec = 'rejected' then v_comment else o.rejection_reason end
       where o.id = v_id and o.approval_status = 'pending'
         and exists (select 1 from output_authors oa
                      where oa.output_id = o.id and oa.person_id = p_person);
      get diagnostics v_n = row_count;
      insert into change_log (subject_type, subject_id, field, new_value, source, actor)
        values ('output', v_id, 'review_decision',
                v_dec || coalesce(': ' || v_comment, ''), 'review', auth.uid());
    end if;

    if v_n <> 1 then
      raise exception 'item % is not open for review for this researcher', v_id
        using errcode = '22023';
    end if;
    if v_dec = 'accepted' then v_accepted := v_accepted + 1;
    else
      v_returned := v_returned + 1;
      v_note := coalesce(v_note, case v_dec when 'rejected' then 'Not accepted: ' else '' end || coalesce(v_comment, ''));
    end if;
  end loop;

  if v_accepted > 0 then
    update people set website_status = 'ready' where id = p_person;
  end if;
  -- Profile status follows the profile-field decisions only.
  if v_person_field then
    update people
       set profile_status = case when v_returned > 0 then 'draft' else 'approved' end,
           review_note    = case when v_returned > 0 then v_note else null end,
           last_verified_at = case when v_returned = 0 then now() else last_verified_at end
     where id = p_person and profile_status in ('pending_review','under_review');
  end if;

  return jsonb_build_object('accepted', v_accepted, 'returned', v_returned);
end;
$$;

-- ------------------------------------------------------ publish_researchers
-- Per-researcher result so one failure never blocks the batch. Columns that
-- identify or protect a record cannot be written through a suggestion.
create or replace function public.publish_researchers(p_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id    uuid;
  s       record;
  v_type  text;
  v_out   jsonb := '[]'::jsonb;
  v_deny  text[] := array['id','profile_status','public_visibility','website_status',
    'approval_status','membership_type','status','auth_user_id','review_note',
    'merged_into','last_verified_at','published_at','rejection_reason','created_at','updated_at'];
begin
  if not public.is_admin() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  foreach v_id in array p_ids loop
    begin
      for s in
        select es.* from enrichment_suggestions es
         where es.source = 'researcher' and es.status = 'ready'
           and ((es.subject_type = 'person' and es.subject_id = v_id)
             or (es.subject_type = 'output' and exists (
                   select 1 from output_authors oa
                    where oa.output_id = es.subject_id and oa.person_id = v_id)))
         order by es.decided_at
      loop
        if s.field = any(v_deny) then
          raise exception 'field % cannot be published', s.field using errcode = '22023';
        end if;
        select format_type(a.atttypid, a.atttypmod) into v_type
          from pg_attribute a
         where a.attrelid = (case s.subject_type when 'person' then 'public.people'
                              else 'public.outputs' end)::regclass
           and a.attname = s.field and a.attnum > 0 and not a.attisdropped;
        if v_type is null then
          raise exception 'unknown field %', s.field using errcode = '22023';
        end if;
        execute format('update public.%s set %I = $1::%s where id = $2',
                       case s.subject_type when 'person' then 'people' else 'outputs' end,
                       s.field, v_type)
          using s.suggested_value, s.subject_id;
        insert into change_log (subject_type, subject_id, field, old_value, new_value, source, actor)
          values (s.subject_type, s.subject_id, s.field, s.current_value,
                  s.suggested_value, 'publish', auth.uid());
        update enrichment_suggestions set status = 'accepted' where id = s.id;
      end loop;

      update outputs o set website_status = 'published'
       where o.website_status in ('ready','error') and o.approval_status = 'approved'
         and exists (select 1 from output_authors oa
                      where oa.output_id = o.id and oa.person_id = v_id);

      update people
         set public_visibility = true, website_status = 'published', published_at = now()
       where id = v_id;
      insert into change_log (subject_type, subject_id, field, new_value, source, actor)
        values ('person', v_id, 'website_status', 'published', 'publish', auth.uid());
      v_out := v_out || jsonb_build_object('id', v_id, 'ok', true, 'published_at', now());
    exception when others then
      -- the block above rolled back; record the failure outside it
      update people set website_status = 'error' where id = v_id;
      insert into change_log (subject_type, subject_id, field, new_value, source, actor)
        values ('person', v_id, 'website_status', 'error: ' || sqlerrm, 'publish', auth.uid());
      v_out := v_out || jsonb_build_object('id', v_id, 'ok', false, 'error', sqlerrm);
    end;
  end loop;
  return v_out;
end;
$$;

revoke all on function public.finish_review(uuid, jsonb) from public, anon;
revoke all on function public.publish_researchers(uuid[]) from public, anon;
grant execute on function public.finish_review(uuid, jsonb) to authenticated;
grant execute on function public.publish_researchers(uuid[]) to authenticated;

-- ORCID identity resolution for the orcid-auth edge function (service_role only).
--
-- Sign-in must only ever match accounts that explicitly linked ORCID
-- (app_metadata.orcid, server-set). people.orcid is an admin-curated registry:
-- it gates WHO may get a session, never WHICH account they get.

-- PostgREST does not expose the auth schema; this is the sanctioned lookup.
create or replace function public.auth_user_for_orcid(p_orcid text)
returns table (id uuid, email text)
language sql
security definer
set search_path = ''
as $$
  select u.id, u.email::text
  from auth.users u
  where u.raw_app_meta_data ->> 'orcid' = p_orcid;
$$;

-- Server-side claim: points the person row at the account that just proved
-- (via OAuth) ownership of the ORCID iD. Uses the same trigger carve-out GUC
-- as claim_person_by_orcid(); audited in change_log.
create or replace function public.link_orcid_account(p_orcid text, p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_old uuid;
begin
  select id, auth_user_id into v_id, v_old
    from people where orcid = p_orcid;
  if v_id is null then return null; end if;
  if v_old is not null and v_old <> p_user_id then
    return null; -- claimed by another account; linking must not steal it
  end if;
  if v_old is null then
    perform set_config('unidcom.orcid_claim', 'on', true);
    update people set auth_user_id = p_user_id where id = v_id;
    insert into change_log (subject_type, subject_id, field, old_value, new_value, source)
    values ('person', v_id, 'auth_user_id', null, p_user_id::text, 'orcid');
  end if;
  return v_id;
end;
$$;

revoke all on function public.auth_user_for_orcid(text) from public, anon, authenticated;
revoke all on function public.link_orcid_account(text, uuid) from public, anon, authenticated;

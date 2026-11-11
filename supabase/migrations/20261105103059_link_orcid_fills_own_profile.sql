-- Connect ORCID on a profile that has no iD yet (account made by an admin,
-- e.g. password bootstrap) used to set app_metadata.orcid only: the person row
-- kept orcid = null, so My Profile showed "not connected" and import failed.
-- The iD is OAuth-verified and the row already belongs to this account, so
-- write it onto that row. Never overwrites an existing, different iD.
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
  if v_id is null then
    select id into v_id from people
     where auth_user_id = p_user_id and orcid is null;
    if v_id is null then return null; end if;
    update people set orcid = p_orcid where id = v_id;
    insert into change_log (subject_type, subject_id, field, old_value, new_value, source)
    values ('person', v_id, 'orcid', null, p_orcid, 'orcid');
    return v_id;
  end if;
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

revoke all on function public.link_orcid_account(text, uuid) from public, anon, authenticated;

-- Backfill accounts that already went through the old link flow.
select public.link_orcid_account(u.raw_app_meta_data ->> 'orcid', u.id)
  from auth.users u
  join people p on p.auth_user_id = u.id and p.orcid is null
 where u.raw_app_meta_data ->> 'orcid' is not null;

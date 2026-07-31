-- ORCID sign-in: unique iD, self-claim RPC, and the one trigger exception it needs.

-- Blank strings would collide under a unique index; normalize first (idempotent).
update public.people set orcid = null where orcid = '';

-- One person per ORCID iD. CAVEAT: fails if duplicates exist — check BEFORE pushing:
--   select orcid, count(*) from people where orcid is not null group by 1 having count(*) > 1;
-- and resolve via the existing merge tooling.
create unique index if not exists people_orcid_key
  on public.people (orcid) where orcid is not null;

-- protect_people_cols resets auth_user_id for every non-admin — including
-- service_role and security-definer paths (is_admin() reads JWT app_metadata).
-- Carve out exactly one sanctioned path: a transaction-local GUC that only
-- claim_person_by_orcid() sets. Everything else stays protected.
create or replace function public.protect_people_cols() returns trigger
  language plpgsql as $$
begin
  if not public.is_admin() then
    new.membership_type   := old.membership_type;
    new.status            := old.status;
    new.profile_status    := old.profile_status;
    new.public_visibility := old.public_visibility;
    if coalesce(current_setting('unidcom.orcid_claim', true), '') <> 'on' then
      new.auth_user_id := old.auth_user_id;
    end if;
    new.last_verified_at  := old.last_verified_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- Links the caller to the people row matching their ORCID-verified iD.
-- Safe to call on every login: no-ops when already linked or no match.
-- app_metadata.orcid is set server-side by the orcid-auth edge function, so
-- it is trusted; users cannot write their own app_metadata.
create or replace function public.claim_person_by_orcid()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_orcid text := auth.jwt() -> 'app_metadata' ->> 'orcid';
  v_id uuid;
begin
  if auth.uid() is null or v_orcid is null then return null; end if;
  select id into v_id from people where auth_user_id = auth.uid();
  if v_id is not null then return v_id; end if;               -- already linked
  perform set_config('unidcom.orcid_claim', 'on', true);      -- tx-local, auto-clears
  update people set auth_user_id = auth.uid()
   where orcid = v_orcid and auth_user_id is null
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.claim_person_by_orcid() from public, anon;
grant execute on function public.claim_person_by_orcid() to authenticated;

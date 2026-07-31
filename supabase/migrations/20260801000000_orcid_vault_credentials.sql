-- ORCID OAuth credentials live in Vault (set via vault.create_secret).
-- Only the service role (the orcid-auth edge function) may read them.
create or replace function public.orcid_credentials()
returns table (client_id text, client_secret text)
language sql
security definer
set search_path = ''
as $$
  select
    (select decrypted_secret from vault.decrypted_secrets where name = 'ORCID_CLIENT_ID'),
    (select decrypted_secret from vault.decrypted_secrets where name = 'ORCID_CLIENT_SECRET');
$$;

revoke all on function public.orcid_credentials() from public, anon, authenticated;

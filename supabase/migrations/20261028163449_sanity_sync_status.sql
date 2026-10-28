alter table public.people
  add column if not exists sanity_synced_at timestamptz,
  add column if not exists sanity_error text;

alter table public.outputs
  add column if not exists sanity_synced_at timestamptz,
  add column if not exists sanity_error text;

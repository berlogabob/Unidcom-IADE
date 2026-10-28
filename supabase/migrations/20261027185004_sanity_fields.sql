-- Fields the Sanity website renders, so the portal can edit them and sanity-push can send them.
-- sanity_id already exists on the live DB (from the unmerged feat/sanity-bridge branch); guard it
-- here so a fresh database matches. Images are public URLs (people keep photo_url).

alter table public.people   add column if not exists sanity_id text;
alter table public.projects add column if not exists sanity_id text;
alter table public.labs     add column if not exists sanity_id text;
alter table public.clusters add column if not exists sanity_id text;
alter table public.outputs  add column if not exists sanity_id text;

alter table public.people
  add column if not exists research_interests text,
  add column if not exists board_role text[];

alter table public.projects
  add column if not exists slug text,
  add column if not exists cover_image_url text,
  add column if not exists keywords text[],
  add column if not exists location text check (location in ('national','international')),
  add column if not exists reference_number text,
  add column if not exists website text,
  add column if not exists start_precision text not null default 'day' check (start_precision in ('year','month','day')),
  add column if not exists end_precision text not null default 'day' check (end_precision in ('year','month','day')),
  add column if not exists partners jsonb not null default '[]',
  add column if not exists results text,
  add column if not exists funder_id uuid;

alter table public.labs
  add column if not exists slug text,
  add column if not exists short_intro text check (char_length(short_intro) <= 300),
  add column if not exists logo_url text,
  add column if not exists cover_image_url text,
  add column if not exists website text;

alter table public.clusters add column if not exists description text;

alter table public.outputs
  add column if not exists keywords text[] check (cardinality(keywords) <= 6);

create table if not exists public.funders (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  logo_url text,
  sanity_id text unique,
  created_at timestamptz not null default now()
);
alter table public.projects
  add constraint projects_funder_fk foreign key (funder_id) references public.funders(id) on delete set null;

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  date date not null default current_date,
  category text,
  excerpt text check (char_length(excerpt) <= 150),
  body text,
  image_url text,
  published boolean not null default false,
  sanity_id text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  cover_image_url text,
  type text,
  format text,
  modality text,
  location text,
  start_date date,
  end_date date,
  start_time time,
  end_time time,
  external_link text,
  language text,
  cost text,
  registration_url text,
  about text,
  published boolean not null default false,
  sanity_id text unique,
  created_at timestamptz not null default now()
);

-- Admin-only edit (the portal's admin role); anyone signed in can read; nothing public via the API.
do $$
declare t text;
begin
  foreach t in array array['funders','articles','events'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select using (auth.uid() is not null)', t || '_read', t);
    execute format('create policy %I on public.%I for all using (public.is_admin()) with check (public.is_admin())', t || '_write', t);
  end loop;
end $$;

-- Logos and covers: admins upload, the bridge fetches by public URL.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-images', 'site-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/svg+xml'])
on conflict (id) do nothing;

drop policy if exists site_images_admin_write on storage.objects;
create policy site_images_admin_write on storage.objects
  for all to authenticated
  using (bucket_id = 'site-images' and public.is_admin())
  with check (bucket_id = 'site-images' and public.is_admin());

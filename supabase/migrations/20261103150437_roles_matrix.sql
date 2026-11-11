-- Roles as data: an editable role -> permission matrix plus one role per account.
-- Replaces the hard-coded JWT claim app_metadata.role = 'admin'. Changes take
-- effect on the next request (no token refresh), because nothing reads the JWT.
--
-- The permission CATALOG is fixed here, because each permission is a check this
-- database enforces. Admins create roles and tick permissions on /app/admin/roles;
-- a new kind of permission needs a migration that adds it and enforces it.

create table public.permissions (
  key text primary key,
  description text not null,
  sort int not null
);
insert into public.permissions (key, description, sort) values
  ('research.edit',   'Edit people, outputs, projects, structure, review queue, requests and website content', 1),
  ('research.delete', 'Delete records (outputs, people, labs, clusters, objectives, projects, tags, news, events, images, history)', 2),
  ('research.merge',  'Merge duplicate people and outputs', 3),
  ('website.publish', 'Push to the public website (publish researchers, Sanity push, sync)', 4),
  ('news.edit',       'Create and edit unpublished news and events, upload images', 5),
  ('roles.manage',    'Edit this matrix, assign roles and invite accounts', 6);

create table public.roles (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{1,30}$'),
  label text not null,
  builtin boolean not null default false
);
create table public.role_permissions (
  role_key text not null references public.roles on delete cascade on update cascade,
  permission text not null references public.permissions,
  primary key (role_key, permission)
);
create table public.user_roles (
  user_id uuid primary key references auth.users on delete cascade,
  role_key text not null references public.roles on update cascade
);

insert into public.roles (key, label, builtin) values
  ('admin', 'Admin', true), ('editor', 'Editor', false), ('news', 'News', false);
insert into public.role_permissions (role_key, permission)
select 'admin', key from public.permissions
union all select 'editor', unnest(array['research.edit','website.publish','news.edit'])
union all select 'news', 'news.edit';

-- Carry over everyone who holds the old JWT admin claim.
insert into public.user_roles (user_id, role_key)
select id, 'admin' from auth.users where raw_app_meta_data ->> 'role' = 'admin';

-- Readable by any signed-in user (the client draws its own UI from them);
-- written only through the roles.manage RPCs below.
do $$
declare t text;
begin
  foreach t in array array['permissions','roles','role_permissions','user_roles'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select to authenticated using (true)', t || '_read', t);
  end loop;
end $$;

create or replace function public.has_perm(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from user_roles ur
    join role_permissions rp on rp.role_key = ur.role_key
    where ur.user_id = auth.uid() and rp.permission = p);
$$;
revoke all on function public.has_perm(text) from public, anon;
grant execute on function public.has_perm(text) to authenticated;

-- "Staff" keeps its old name: ~60 policies and RPC gates read it.
create or replace function public.is_admin() returns boolean
language sql stable set search_path = public as $$
  select public.has_perm('research.edit');
$$;

-- ------------------------------------------------------------ delete / merge
-- Restrictive: ANDs with the existing permissive `for all using (is_admin())`.
-- Link tables (authors, members, roles) stay unrestricted so editors can unlink.
do $$
declare t text;
begin
  foreach t in array array['outputs','people','labs','clusters','objectives','projects',
                           'tags','funders','articles','events','change_log','output_taxonomy'] loop
    execute format('create policy %I on public.%I as restrictive for delete using (public.has_perm(%L))',
                   t || '_delete_perm', t, 'research.delete');
  end loop;
end $$;
create policy site_images_delete_perm on storage.objects as restrictive for delete
  using (bucket_id <> 'site-images' or public.has_perm('research.delete'));

-- Swap the gate in place rather than copying long function bodies.
do $$
declare f text; def text;
begin
  foreach f in array array['public.merge_people(uuid,uuid[],jsonb)',
                           'public.merge_outputs(uuid,uuid[],jsonb)',
                           'public.publish_researchers(uuid[])'] loop
    def := pg_get_functiondef(f::regprocedure);
    if position('if not public.is_admin() then' in def) = 0 then
      raise exception 'gate not found in %', f;
    end if;
    execute replace(def, 'if not public.is_admin() then',
      format('if not public.has_perm(%L) then',
             case when f like '%publish%' then 'website.publish' else 'research.merge' end));
  end loop;
end $$;

-- ------------------------------------------------------------ news role
-- Drafts only: a published row is invisible to these policies, and
-- with check stops anyone without research.edit from publishing.
create policy articles_news_insert on public.articles for insert
  with check (public.has_perm('news.edit') and not published);
create policy articles_news_update on public.articles for update
  using (public.has_perm('news.edit') and not published)
  with check (public.has_perm('news.edit') and not published);
create policy events_news_insert on public.events for insert
  with check (public.has_perm('news.edit') and not published);
create policy events_news_update on public.events for update
  using (public.has_perm('news.edit') and not published)
  with check (public.has_perm('news.edit') and not published);
create policy site_images_news_write on storage.objects for insert to authenticated
  with check (bucket_id = 'site-images' and public.has_perm('news.edit'));
create policy site_images_news_update on storage.objects for update to authenticated
  using (bucket_id = 'site-images' and public.has_perm('news.edit'))
  with check (bucket_id = 'site-images' and public.has_perm('news.edit'));

-- ------------------------------------------------------------ RPCs
create or replace function public.my_permissions() returns text[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(rp.permission), '{}')
  from user_roles ur join role_permissions rp on rp.role_key = ur.role_key
  where ur.user_id = auth.uid();
$$;

create or replace function public._require_roles_manage() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not has_perm('roles.manage') then
    raise exception 'not authorized' using errcode = '42501';
  end if;
end $$;

-- Somebody must always be able to reach this page again.
-- Volatile on purpose: it must see the caller's writes from the same call.
create or replace function public._assert_manager_exists() returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from user_roles ur join role_permissions rp using (role_key)
                 where rp.permission = 'roles.manage') then
    raise exception 'at least one account must keep roles.manage' using errcode = '23514';
  end if;
end $$;

create or replace function public.save_role(p_key text, p_label text, p_perms text[])
returns void language plpgsql security definer set search_path = public as $$
declare old text;
begin
  perform _require_roles_manage();
  if p_key = 'admin' and not ('roles.manage' = any(p_perms)) then
    raise exception 'admin always keeps roles.manage' using errcode = '23514';
  end if;
  select string_agg(permission, ',' order by permission) into old
    from role_permissions where role_key = p_key;
  insert into roles (key, label) values (p_key, p_label)
    on conflict (key) do update set label = excluded.label;
  delete from role_permissions where role_key = p_key;
  insert into role_permissions (role_key, permission) select p_key, unnest(p_perms);
  perform _assert_manager_exists();
  insert into change_log (subject_type, field, old_value, new_value, actor)
    values ('role', p_key, old, array_to_string(array(select unnest(p_perms) order by 1), ','), auth.uid());
end $$;

create or replace function public.delete_role(p_key text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform _require_roles_manage();
  if exists (select 1 from roles where key = p_key and builtin) then
    raise exception 'built-in role' using errcode = '23514';
  end if;
  if exists (select 1 from user_roles where role_key = p_key) then
    raise exception 'role is still assigned' using errcode = '23503';
  end if;
  delete from roles where key = p_key;
  insert into change_log (subject_type, field, old_value, actor)
    values ('role', p_key, 'deleted', auth.uid());
end $$;

-- p_role null removes the account's role (back to plain researcher).
create or replace function public.set_user_role(p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare old text;
begin
  perform _require_roles_manage();
  select role_key into old from user_roles where user_id = p_user;
  if p_role is null then
    delete from user_roles where user_id = p_user;
  else
    insert into user_roles (user_id, role_key) values (p_user, p_role)
      on conflict (user_id) do update set role_key = excluded.role_key;
  end if;
  perform _assert_manager_exists();
  insert into change_log (subject_type, subject_id, field, old_value, new_value, actor)
    values ('user_role', p_user, 'role', old, p_role, auth.uid());
end $$;

create or replace function public.list_accounts()
returns table (user_id uuid, email text, person_id uuid, person_name text,
               role_key text, last_sign_in_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_roles_manage();
  return query
    select u.id, u.email::text, p.id, p.preferred_name, ur.role_key, u.last_sign_in_at
    from auth.users u
    left join people p on p.auth_user_id = u.id
    left join user_roles ur on ur.user_id = u.id
    order by ur.role_key nulls last, coalesce(p.preferred_name, u.email);
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.my_permissions()','public._require_roles_manage()',
    'public._assert_manager_exists()','public.save_role(text,text,text[])',
    'public.delete_role(text)','public.set_user_role(uuid,text)','public.list_accounts()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

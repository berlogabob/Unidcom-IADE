-- Run AFTER the migration inside one transaction, then roll back:
--   begin; \i migrations/20261103150437_roles_matrix.sql; \i tests/roles.sql; rollback;
-- Any failed assert raises. Needs a role that can SET LOCAL role/claims.
do $t$
declare
  u_admin uuid := gen_random_uuid();
  u_editor uuid := gen_random_uuid();
  u_news uuid := gen_random_uuid();
  u_custom uuid := gen_random_uuid();
  o uuid := gen_random_uuid();
  o2 uuid := gen_random_uuid();
  p uuid := gen_random_uuid();
  a uuid;
  n int;
begin
  insert into auth.users (id, email) values
    (u_admin, 'roles-admin@test'), (u_editor, 'roles-editor@test'),
    (u_news, 'roles-news@test'), (u_custom, 'roles-custom@test');
  insert into user_roles values (u_admin, 'admin'), (u_editor, 'editor'), (u_news, 'news');
  insert into outputs (id, title) values (o, 'Roles test output'), (o2, 'Roles test dup');
  insert into people (id, preferred_name) values (p, 'Roles Test Person');

  perform set_config('role', 'authenticated', true);

  -- editor: edits, cannot delete or merge
  perform set_config('request.jwt.claims', json_build_object('sub', u_editor, 'role', 'authenticated')::text, true);
  update outputs set title = 'edited' where id = o;
  get diagnostics n = row_count;
  assert n = 1, 'FAIL: editor cannot edit output';
  delete from outputs where id = o;
  get diagnostics n = row_count;
  assert n = 0, 'FAIL: editor deleted an output';
  begin
    perform merge_outputs(o, array[o2]);
    raise exception 'FAIL: editor merged outputs';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  begin
    perform set_user_role(u_custom, 'admin');
    raise exception 'FAIL: editor assigned a role';
  exception when insufficient_privilege then null; end;

  -- news: draft article only
  perform set_config('request.jwt.claims', json_build_object('sub', u_news, 'role', 'authenticated')::text, true);
  insert into articles (title, slug) values ('Draft', 'roles-test-draft') returning id into a;
  begin
    update articles set published = true where id = a;
    raise exception 'FAIL: news published an article';
  exception when insufficient_privilege then null; end;
  update people set bio = 'x' where id = p;
  get diagnostics n = row_count;
  assert n = 0, 'FAIL: news edited a person';
  delete from articles where id = a;
  get diagnostics n = row_count;
  assert n = 0, 'FAIL: news deleted an article';

  -- admin: delete, build a custom role, cannot remove the last manager
  perform set_config('request.jwt.claims', json_build_object('sub', u_admin, 'role', 'authenticated')::text, true);
  perform save_role('tester', 'Tester', array['research.edit']);
  perform set_user_role(u_custom, 'tester');
  begin
    perform save_role('admin', 'Admin', array['research.edit']);
    raise exception 'FAIL: admin lost roles.manage';
  exception when check_violation then null; end;
  delete from outputs where id = o2;
  get diagnostics n = row_count;
  assert n = 1, 'FAIL: admin cannot delete';

  -- the custom role behaves like research.edit only
  perform set_config('request.jwt.claims', json_build_object('sub', u_custom, 'role', 'authenticated')::text, true);
  update outputs set title = 'custom' where id = o;
  get diagnostics n = row_count;
  assert n = 1, 'FAIL: custom role cannot edit';
  delete from outputs where id = o;
  get diagnostics n = row_count;
  assert n = 0, 'FAIL: custom role deleted';

  -- the only manager cannot drop themself (other real admins exist in prod, so
  -- strip them inside this rolled-back transaction first)
  perform set_config('role', 'postgres', true);
  delete from user_roles where role_key = 'admin' and user_id <> u_admin;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', u_admin, 'role', 'authenticated')::text, true);
  begin
    perform set_user_role(u_admin, null);
    raise exception 'FAIL: last manager removed';
  exception when check_violation then null; end;

  raise notice 'roles: all checks passed';
end $t$;

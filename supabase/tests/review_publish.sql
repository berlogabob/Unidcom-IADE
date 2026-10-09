-- Run AFTER the migration inside one transaction; it rolls itself back.
--   begin; \i migrations/20261009100000_review_publish.sql; \i tests/review_publish.sql
-- Any failed assert raises. Needs a role that can SET LOCAL role/claims.
do $t$
declare
  p uuid := gen_random_uuid();
  o_new uuid := gen_random_uuid();
  s_bio uuid; s_cid uuid; r jsonb;
begin
  insert into people (id, preferred_name, profile_status, bio)
    values (p, 'Test Researcher', 'pending_review', 'old bio');
  insert into outputs (id, title, approval_status) values (o_new, 'New paper', 'pending');
  insert into output_authors (output_id, person_id) values (o_new, p);
  insert into enrichment_suggestions (subject_type, subject_id, field, current_value, suggested_value, source, status)
    values ('person', p, 'bio', 'old bio', 'new bio', 'researcher', 'pending') returning id into s_bio;
  insert into enrichment_suggestions (subject_type, subject_id, field, suggested_value, source, status)
    values ('person', p, 'ciencia_id', '6414-x', 'researcher', 'pending') returning id into s_cid;

  -- non-admin is refused
  perform set_config('request.jwt.claims', '{"role":"authenticated","app_metadata":{}}', true);
  begin
    perform finish_review(p, '[]'::jsonb);
    raise exception 'FAIL: non-admin allowed';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claims', '{"role":"authenticated","app_metadata":{"role":"admin"}}', true);

  -- change request without comment is refused; nothing changes
  begin
    perform finish_review(p, jsonb_build_array(
      jsonb_build_object('kind','field','id',s_bio,'decision','change_requested')));
    raise exception 'FAIL: empty comment allowed';
  exception when invalid_parameter_value then null; end;

  r := finish_review(p, jsonb_build_array(
    jsonb_build_object('kind','field','id',s_bio,'decision','accepted'),
    jsonb_build_object('kind','field','id',s_cid,'decision','change_requested','comment','Check the id'),
    jsonb_build_object('kind','output','id',o_new,'decision','accepted')));
  assert (r->>'accepted')::int = 2 and (r->>'returned')::int = 1, 'counts';

  -- accept does NOT apply the value (ST-3) and does not publish
  assert (select bio from people where id = p) = 'old bio', 'bio applied too early';
  assert (select status from enrichment_suggestions where id = s_bio) = 'ready';
  assert (select status from enrichment_suggestions where id = s_cid) = 'change_requested';
  assert (select website_status from outputs where id = o_new) = 'ready';
  assert (select approval_status from outputs where id = o_new) = 'approved';
  assert (select website_status from people where id = p) = 'ready';
  assert (select profile_status from people where id = p) = 'draft', 'returned item -> draft';
  assert (select review_note from people where id = p) = 'Check the id';
  assert (select count(*) from change_log where source = 'review' and subject_id in (p, o_new)) = 3, 'audit';

  -- a decided item cannot be decided twice
  begin
    perform finish_review(p, jsonb_build_array(
      jsonb_build_object('kind','field','id',s_bio,'decision','rejected')));
    raise exception 'FAIL: double decision';
  exception when invalid_parameter_value then null; end;

  -- publish applies ready values and flips flags
  r := publish_researchers(array[p]);
  assert (r->0->>'ok')::boolean, 'publish ok';
  assert (select bio from people where id = p) = 'new bio', 'bio not applied on publish';
  assert (select website_status from people where id = p) = 'published';
  assert (select public_visibility from people where id = p);
  assert (select website_status from outputs where id = o_new) = 'published';
  assert (select status from enrichment_suggestions where id = s_bio) = 'accepted';
  assert (select status from enrichment_suggestions where id = s_cid) = 'change_requested', 'returned item untouched';

  -- protected columns cannot be written through a suggestion; failure is per-row
  insert into enrichment_suggestions (subject_type, subject_id, field, suggested_value, source, status)
    values ('person', p, 'profile_status', 'approved', 'researcher', 'ready');
  r := publish_researchers(array[p]);
  assert not (r->0->>'ok')::boolean, 'protected field published';
  assert (select website_status from people where id = p) = 'error';

  raise exception 'OK-ROLLBACK';  -- keeps the test side-effect free
exception when raise_exception then
  if sqlerrm <> 'OK-ROLLBACK' then raise; end if;
end $t$;

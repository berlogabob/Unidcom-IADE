-- The unmerged Sanity bridge left four functions executable by anon and
-- authenticated; two are SECURITY DEFINER (sanity_link_by_code,
-- sanity_suggest writes suggestions for any person). Only the bridge's
-- service-key scripts call them, so keep execute for service_role alone.
-- The bridge's admin RPCs gate on is_admin() in their bodies; anon has no
-- business reaching them at all (advisor 0028).
-- The bridge functions were created by hand, so a fresh project lacks them: each statement is guarded.
do $$
declare f text;
begin
  foreach f in array array[
    'public.sanity_image_url(text, text, text)', 'public.sanity_link_by_code()',
    'public.sanity_membership_type(text)', 'public.sanity_suggest(uuid, text, text, text, numeric)'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke execute on function %s from public, anon, authenticated', f);
      execute format('grant execute on function %s to service_role', f);
    end if;
  end loop;
  foreach f in array array[
    'public.bulk_link_sanity_matches()', 'public.import_sanity_member(text)',
    'public.link_sanity_member(uuid, text, jsonb)', 'public.set_sanity_decision(text, text)'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke execute on function %s from public, anon', f);
      execute format('grant execute on function %s to authenticated, service_role', f);
    end if;
  end loop;
end $$;

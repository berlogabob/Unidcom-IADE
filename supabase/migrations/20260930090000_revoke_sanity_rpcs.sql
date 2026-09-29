-- The unmerged Sanity bridge left four functions executable by anon and
-- authenticated; two are SECURITY DEFINER (sanity_link_by_code,
-- sanity_suggest writes suggestions for any person). Only the bridge's
-- service-key scripts call them, so keep execute for service_role alone.
revoke execute on function public.sanity_image_url(text, text, text) from public, anon, authenticated;
revoke execute on function public.sanity_link_by_code() from public, anon, authenticated;
revoke execute on function public.sanity_membership_type(text) from public, anon, authenticated;
revoke execute on function public.sanity_suggest(uuid, text, text, text, numeric) from public, anon, authenticated;
grant execute on function public.sanity_image_url(text, text, text) to service_role;
grant execute on function public.sanity_link_by_code() to service_role;
grant execute on function public.sanity_membership_type(text) to service_role;
grant execute on function public.sanity_suggest(uuid, text, text, text, numeric) to service_role;

-- The bridge's admin RPCs gate on is_admin() in their bodies; anon has no
-- business reaching them at all (advisor 0028).
revoke execute on function public.bulk_link_sanity_matches() from public, anon;
revoke execute on function public.import_sanity_member(text) from public, anon;
revoke execute on function public.link_sanity_member(uuid, text, jsonb) from public, anon;
revoke execute on function public.set_sanity_decision(text, text) from public, anon;
grant execute on function public.bulk_link_sanity_matches() to authenticated, service_role;
grant execute on function public.import_sanity_member(text) to authenticated, service_role;
grant execute on function public.link_sanity_member(uuid, text, jsonb) to authenticated, service_role;
grant execute on function public.set_sanity_decision(text, text) to authenticated, service_role;

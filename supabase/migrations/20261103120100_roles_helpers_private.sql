-- Internal helpers of the roles RPCs: called only from inside security definer
-- functions (which run as owner), so nobody needs them over the API.
revoke execute on function public._require_roles_manage() from authenticated;
revoke execute on function public._assert_manager_exists() from authenticated;

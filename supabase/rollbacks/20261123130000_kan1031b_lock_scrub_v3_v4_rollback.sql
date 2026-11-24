-- Restores the ACLs before KAN-1031b. Old proacl for both functions:
-- {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
GRANT EXECUTE ON FUNCTION public.admin_scrub_posts_body_v3() TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_scrub_posts_body_v4() TO PUBLIC, anon, authenticated, service_role;

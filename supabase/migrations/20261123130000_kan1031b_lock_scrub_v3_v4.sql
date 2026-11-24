-- KAN-1031 (reopen): lock admin_scrub_posts_body_v3/_v4, missed by the first pass.
-- No callers found: pg_proc bodies, cron.job, lib/, supabase/functions, 7 days of edge_logs.
-- Functions kept; only EXECUTE is revoked. service_role and postgres keep EXECUTE.
REVOKE EXECUTE ON FUNCTION public.admin_scrub_posts_body_v3() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_scrub_posts_body_v4() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_scrub_posts_body_v3() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_scrub_posts_body_v4() TO service_role;

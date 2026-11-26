-- Rollback for KAN-1051: restores SECURITY INVOKER and the pre-fix ACLs
-- (recompute_sport_user_counts: PUBLIC, anon, authenticated, service_role; trgfn_sport_profiles_sync: service_role).
-- Note: this brings the Manage Sports 42501 bug back.
BEGIN;
ALTER FUNCTION public.recompute_sport_user_counts() SECURITY INVOKER;
ALTER FUNCTION public.trgfn_sport_profiles_sync() SECURITY INVOKER;
GRANT EXECUTE ON FUNCTION public.recompute_sport_user_counts() TO PUBLIC, anon, authenticated;
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261126090000';
COMMIT;

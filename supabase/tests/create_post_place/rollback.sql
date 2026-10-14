-- KAN-524 rollback: bring the 15-argument create_post back under its original name and ACL.
--
-- STATUS: AUTHORED, NOT RUN. Rolling back is itself an APPLY: Memphis runs it, under the same CEO approval
-- (execute_sql only, test data only, nothing removed). Order: this file undoes the KAN-524 migration; if KAN-499 /
-- KAN-497 were also applied they are undone separately, newest first.
-- It RE-OPENS the bug: circle posts lose their place again. Posts already created with a place keep it.

-- 1. Move the new 20-argument function out of the way (nothing removed). The name is free of any overload clash.
ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) RENAME TO create_post_v2_rolledback;
REVOKE ALL ON FUNCTION public.create_post_v2_rolledback(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) FROM PUBLIC, anon, authenticated;

-- 2. Restore the original 15-argument function under its name.
ALTER FUNCTION public.create_post_legacy_v1(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[]) RENAME TO create_post;

-- 3. Baseline ACL: authenticated and service_role only.
REVOKE ALL ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[]) TO authenticated, service_role;

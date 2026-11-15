-- KAN-958 (CEO decision 2026-11-16, "make profiles visible by default"): public.is_profile_publicly_visible
-- treated a missing user_status row as hidden (coalesce(us.hide_in_search, true) = false). 165 personal
-- profiles had no row, so every profile was hidden from discovery (Active tab player_joined was empty).
-- New rule: a profile is hidden from discovery only when user_status.hide_in_search IS TRUE. A missing row,
-- or hide_in_search false, is visible. p.is_active and NOT is_benched(p.user_id) are unchanged; blocks are
-- applied by the callers (active_stream: NOT is_blocked(viewer, p.user_id)) and are unchanged.
-- Body re-authored from the live pg_get_functiondef (pre-image md5 guarded).
-- Two attribute changes, both required by the new default:
--   * SECURITY DEFINER (owner postgres). user_status RLS is select-own, so as SECURITY INVOKER a direct caller
--     cannot see another user's row; under "missing means hidden" that failed closed, under "missing means
--     visible" it would fail open and show a hidden-from-search user as visible. As definer the answer no
--     longer depends on the caller. search_path stays 'public, pg_temp'.
--   * EXECUTE revoked from PUBLIC and anon (a definer function; no anon caller exists). authenticated and
--     service_role keep EXECUTE.
-- user_status.hide_in_search column default true -> false: rpc_get_my_status inserts a row without the column,
-- which would otherwise opt a user out of discovery merely by reading their status. Existing rows untouched.
-- Callers: active_stream (SECURITY DEFINER) only. No view, matview, policy, lib/, workers/ or
-- supabase/functions/ caller. Other user_status readers (allow_social_visibility, allow_social_notifications,
-- can_receive_friend_requests) already treat a missing row as allowed.
-- Applied under G-002 by backend-1.

DO $pre$
DECLARE v_md5 text; v_acl text[]; v_def text;
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)), (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x)
    INTO v_md5, v_acl
    FROM pg_proc p WHERE p.oid = 'public.is_profile_publicly_visible(uuid)'::regprocedure;
  IF v_md5 IS DISTINCT FROM '31b095091ced40bde78eaba225b78ec0' THEN
    RAISE EXCEPTION 'KAN-958 pre-image md5 mismatch: %', v_md5;
  END IF;
  IF v_acl IS DISTINCT FROM ARRAY['=X/postgres','anon=X/postgres','authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres'] THEN
    RAISE EXCEPTION 'KAN-958 pre-image ACL mismatch: %', v_acl;
  END IF;
  SELECT column_default INTO v_def FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'user_status' AND column_name = 'hide_in_search';
  IF v_def IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'KAN-958 pre-image hide_in_search default mismatch: %', v_def;
  END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.is_profile_publicly_visible(p_profile_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select (p.is_active = true)
     and not public.is_benched(p.user_id)
     and us.hide_in_search is not true  -- KAN-958: hidden only on an explicit opt-out; no user_status row = visible
  from public.profiles p
  left join public.user_status us on us.user_id = p.user_id
  where p.id = p_profile_id
$function$;

ALTER FUNCTION public.is_profile_publicly_visible(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.is_profile_publicly_visible(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_profile_publicly_visible(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.is_profile_publicly_visible(uuid) IS
  'KAN-958: a profile is discoverable when active, not benched, and user_status.hide_in_search is not true (no row = visible). Blocks are applied by callers. SECURITY DEFINER so the answer does not depend on the caller''s user_status RLS.';

ALTER TABLE public.user_status ALTER COLUMN hide_in_search SET DEFAULT false;

DO $post$
DECLARE r record; v_def text;
BEGIN
  SELECT pg_get_userbyid(p.proowner) AS owner, p.prosecdef, p.proconfig,
         (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x) AS acl,
         pg_get_functiondef(p.oid) AS def
    INTO r
    FROM pg_proc p WHERE p.oid = 'public.is_profile_publicly_visible(uuid)'::regprocedure;
  IF r.owner <> 'postgres' OR NOT r.prosecdef
     OR r.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR r.acl IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres']
     OR has_function_privilege('anon', 'public.is_profile_publicly_visible(uuid)', 'EXECUTE')
     OR r.def NOT LIKE '%us.hide_in_search is not true%' THEN
    RAISE EXCEPTION 'KAN-958 post-image mismatch: owner=% secdef=% cfg=% acl=%', r.owner, r.prosecdef, r.proconfig, r.acl;
  END IF;
  SELECT column_default INTO v_def FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'user_status' AND column_name = 'hide_in_search';
  IF v_def IS DISTINCT FROM 'false' THEN
    RAISE EXCEPTION 'KAN-958 post-image hide_in_search default mismatch: %', v_def;
  END IF;
END
$post$;

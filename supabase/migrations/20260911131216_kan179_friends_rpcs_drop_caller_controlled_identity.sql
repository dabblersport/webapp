-- APPLIED 2026-09-11 via apply_migration. Ledger version 20260911131216.
--
-- KAN-179: rpc_get_friends(uuid) and rpc_get_friend_suggestions(uuid, integer)
-- accept a caller-supplied identity argument that overrides the authorization
-- subject (same class as KAN-174/T-070). public.friendships is absent today so
-- the feature is inert, but the defect is real: fixed now rather than waiting
-- for the feature to be revived.
--
-- rpc_get_friends(uuid): the vulnerable overload is DROPPED outright. A
-- separate, already-safe rpc_get_friends() (0-arg, auth.uid()-derived, no
-- caller override possible) already exists and is left untouched -- it is not
-- in scope and not part of this defect. No Dart caller references either
-- rpc_get_friends signature (lib/ uses the v_circle view instead), so the drop
-- is client-safe.
--
-- rpc_get_friend_suggestions(uuid, integer): p_user_id is removed from the
-- signature entirely and replaced internally with auth.uid(), never
-- caller-suppliable. p_limit is preserved -- lib/data/repositories/
-- friends_repository_impl.dart:552 already calls this RPC with only p_limit,
-- so this is client-compatible as-is. Body restated from the live catalogue
-- (pg_get_functiondef) per T-044/CONVENTIONS.md 6c; only p_user_id references
-- become a single auth.uid()-derived local, nothing else in the query logic
-- changes.
--
-- No change to public.friendships (absent) and no change to any of the other
-- 16 functions that reference it.
--
-- Post-apply verified live and over an actual PostgREST HTTP round-trip:
-- calling either RPC with p_user_id in the payload returns 404 PGRST202 (no
-- matching function signature -- the bypass path is unreachable, not merely
-- empty); calling rpc_get_friend_suggestions with only p_limit reaches the
-- function body (fails on the known-absent friendships relation, 42P01, not
-- on a signature mismatch), proving the auth-fix code path actually executes.

DROP FUNCTION public.rpc_get_friends(uuid);

DROP FUNCTION public.rpc_get_friend_suggestions(uuid, integer);

CREATE FUNCTION public.rpc_get_friend_suggestions(p_limit integer DEFAULT 20)
 RETURNS TABLE(user_id uuid, full_name text, username text, avatar_url text, bio text, mutual_friends_count integer, mutual_friend_ids uuid[])
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  RETURN QUERY
  WITH user_friends AS (
    SELECT
      CASE
        WHEN f.user_id = v_user_id THEN f.peer_user_id
        ELSE f.user_id
      END AS friend_id
    FROM friendships f
    WHERE (f.user_id = v_user_id OR f.peer_user_id = v_user_id)
      AND f.status = 'accepted'
  ),
  potential_friends AS (
    SELECT
      CASE
        WHEN f.user_id = uf.friend_id THEN f.peer_user_id
        ELSE f.user_id
      END AS suggested_user_id,
      uf.friend_id AS mutual_friend_id
    FROM friendships f
    INNER JOIN user_friends uf ON (f.user_id = uf.friend_id OR f.peer_user_id = uf.friend_id)
    WHERE f.status = 'accepted'
      AND CASE
        WHEN f.user_id = uf.friend_id THEN f.peer_user_id
        ELSE f.user_id
      END != v_user_id
      AND CASE
        WHEN f.user_id = uf.friend_id THEN f.peer_user_id
        ELSE f.user_id
      END NOT IN (SELECT friend_id FROM user_friends)
  ),
  suggestion_counts AS (
    SELECT
      pf.suggested_user_id,
      COUNT(DISTINCT pf.mutual_friend_id) AS mutual_count,
      ARRAY_AGG(DISTINCT pf.mutual_friend_id) AS mutual_ids
    FROM potential_friends pf
    WHERE NOT EXISTS (
      SELECT 1 FROM friendships f2
      WHERE ((f2.user_id = v_user_id AND f2.peer_user_id = pf.suggested_user_id)
         OR (f2.user_id = pf.suggested_user_id AND f2.peer_user_id = v_user_id))
        AND f2.status IN ('pending', 'blocked')
    )
    GROUP BY pf.suggested_user_id
  )
  SELECT
    p.id,
    -- Backward-compatible output column name.
    p.display_name,
    p.username,
    p.avatar_url,
    p.bio,
    sc.mutual_count::INTEGER,
    sc.mutual_ids
  FROM suggestion_counts sc
  INNER JOIN profiles p ON p.id = sc.suggested_user_id
  ORDER BY sc.mutual_count DESC, p.display_name ASC
  LIMIT p_limit;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_get_friend_suggestions(integer) TO anon, authenticated;

DO $$
BEGIN
  IF to_regprocedure('public.rpc_get_friends(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: vulnerable rpc_get_friends(uuid) still exists';
  END IF;
  IF to_regprocedure('public.rpc_get_friend_suggestions(uuid,integer)') IS NOT NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: vulnerable rpc_get_friend_suggestions(uuid,integer) still exists';
  END IF;
  IF to_regprocedure('public.rpc_get_friends()') IS NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: the untouched safe rpc_get_friends() overload is gone';
  END IF;
  IF to_regprocedure('public.rpc_get_friend_suggestions(integer)') IS NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: new rpc_get_friend_suggestions(integer) does not exist';
  END IF;
  IF to_regclass('public.friendships') IS NOT NULL THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: friendships exists -- must remain absent';
  END IF;
END $$;

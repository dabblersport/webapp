-- KAN-664 (Ratings B1): three additive READ functions for the player-rating client. AUTHORED, NOT APPLIED (Operations applies).
-- Additive only: no table, column, policy, grant or existing function is changed. rpc_rate_user / rpc_rate_game / rpc_rate_venue
-- keep their signatures and bodies.
--   rpc_get_unrated_coplayers(game)   -> co-players of a finished game the caller has not rated yet (client "who is left to rate")
--   rpc_get_user_rating_aggregate(u)  -> a user's aggregate, returned ONLY at or above the existing minimum-count threshold
--   rpc_list_rating_dimensions()      -> the fixed server-side tag/dimension list (reputation_dimensions is not client-readable since KAN-86)
-- Neither function can return rater identity: the first returns co-players (people the caller may rate), the second never reads
-- user_reputation_events columns other than a count by the aggregate table.
-- The threshold is the one already defined by public.v_reliable_teammate_candidates: badge_rules.params.min_count for badge_key
-- 'reliable_teammate', falling back to 8 (same coalesce expression as that view). The number is not changed here.

CREATE OR REPLACE FUNCTION public.rpc_get_unrated_coplayers(p_game_id uuid)
RETURNS TABLE(user_id uuid, profile_id uuid, is_host boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  me uuid := auth.uid();
  g  record;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  SELECT id, creator_user_id, creator_profile_id, end_at, is_cancelled INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;
  IF now() < g.end_at THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_finished'; END IF;
  IF now() > g.end_at + interval '7 days' THEN RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed'; END IF;

  -- same participant rule as rpc_rate_user: the rater must be an active roster member
  IF NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.user_id = me AND r.status = 'active') THEN
    RAISE EXCEPTION USING errcode='P0001', message='rater_not_in_game';
  END IF;

  RETURN QUERY
  WITH cands AS (
    SELECT DISTINCT ON (r.user_id) r.user_id AS cuser, r.profile_id AS cprofile, (r.user_id = g.creator_user_id) AS chost
    FROM public.game_roster r
    WHERE r.game_id = p_game_id AND r.status = 'active' AND r.user_id <> me
    ORDER BY r.user_id, r.joined_at
  ), host_c AS (
    SELECT g.creator_user_id AS cuser, g.creator_profile_id AS cprofile, true AS chost
    WHERE g.creator_user_id <> me AND NOT EXISTS (SELECT 1 FROM cands c WHERE c.cuser = g.creator_user_id)
  ), allc AS (
    SELECT cuser, cprofile, chost FROM cands
    UNION ALL
    SELECT cuser, cprofile, chost FROM host_c
  )
  SELECT a.cuser, a.cprofile, a.chost
  FROM allc a
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_reputation_events e
    WHERE e.game_id = p_game_id AND e.rater_user_id = me AND e.ratee_user_id = a.cuser
  )
  ORDER BY a.chost DESC, a.cuser;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_user_rating_aggregate(p_user_id uuid)
RETURNS TABLE(user_id uuid, composite_score numeric, event_count integer, dimension_means jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  thr integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  thr := COALESCE((SELECT (b.params ->> 'min_count')::integer FROM public.badge_rules b WHERE b.badge_key = 'reliable_teammate' LIMIT 1), 8);

  -- below the threshold: no row at all (never a partial average)
  RETURN QUERY
  SELECT a.user_id, a.composite_score, a.event_count,
         COALESCE((SELECT jsonb_object_agg(k.key, round((a.dim_sums ->> k.key)::numeric / NULLIF((a.dim_counts ->> k.key)::numeric, 0), 2))
                   FROM jsonb_each(a.dim_counts) AS k
                   WHERE (a.dim_counts ->> k.key)::numeric > 0), '{}'::jsonb)
  FROM public.user_reputation_aggregate a
  WHERE a.user_id = p_user_id AND a.event_count >= thr;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_list_rating_dimensions()
RETURNS TABLE(key text, label_en text, label_ar text, applicable_to text[], sort_order integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;
  RETURN QUERY
  SELECT d.key, d.label_en, d.label_ar, d.applicable_to, d.sort_order
  FROM public.reputation_dimensions d
  WHERE d.is_active
  ORDER BY d.sort_order, d.key;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_unrated_coplayers(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_get_user_rating_aggregate(uuid) FROM PUBLIC, anon;
GRANT execute ON FUNCTION public.rpc_get_unrated_coplayers(uuid) TO authenticated;
GRANT execute ON FUNCTION public.rpc_get_user_rating_aggregate(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.rpc_list_rating_dimensions() FROM PUBLIC, anon;
GRANT execute ON FUNCTION public.rpc_list_rating_dimensions() TO authenticated;

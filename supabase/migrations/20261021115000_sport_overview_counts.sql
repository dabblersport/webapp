-- KAN-621: public.rpc_sport_overview, the read-only aggregates behind the Sport Overview page.
--
-- STATUS: AUTHORED, NOT APPLIED. Nothing here was run against any database. Operations applies it
-- (execute_sql only, never apply_migration; probes in supabase/tests/sport_overview/probes.sql,
-- rollback in supabase/tests/sport_overview/rollback.sql). Additive only: ONE new function, no table,
-- column, policy or data change.
--
-- City key (decision dreq-d8a48630, policy-approved): there is no uuid city anywhere in the schema.
-- public.ref_cities is keyed by `code` text and public.areas.city_code references it. The function
-- therefore takes `p_city_code text` (a ref_cities.code), NOT a uuid. NULL = all cities.
--
-- Area-to-city join (the only one used):
--   <row>.area_id -> public.areas.id,  public.areas.city_code = p_city_code  (areas.city_code FK ref_cities.code)
--
-- Signature: rpc_sport_overview(p_sport_id uuid, p_city_code text default null).
-- Output, one row:
--   followers          global, all cities: distinct profiles whose interests contain p_sport_id,
--                      minus profiles the caller has a block with either way (user_blocks).
--   games_next7        public, not cancelled games of the sport starting in the next 7 days (city-scoped).
--   meetups_next7      public, not cancelled meetups of the sport starting in the next 7 days (city-scoped).
--   venues             active venues that offer the sport (an active space of the sport, or the sport key in
--                      venues.sports); one per venue (city-scoped).
--   spaces             active venue_spaces of the sport inside an active venue; counted separately, never
--                      summed with venues (city-scoped via the venue's area).
--   posts              public live original posts tagged with the sport. Posts are NOT city-scoped (see below):
--                      the value is the same whatever p_city_code is.
--   news               published, unexpired news of the sport (city-scoped; news with no area counts only
--                      when p_city_code is NULL).
--   mutual_followers   jsonb array, at most 3 of {display_name, avatar_url, username}: people the caller
--                      follows who also follow the sport. Excludes the caller and blocked users. '[]' if none.
--
-- Posts and city: the app does not treat a post as belonging to a city (KAN-592 records where the author posted
-- from in an unapplied column), so no post city is inferred. posts.area_id is the post's coordinate area, not a
-- city claim, and is deliberately not used.
--
-- Parameters kept as one constant, not hard rules: v_window (7 days) below. Change by CREATE OR REPLACE.
-- Visibility: only listing_visibility/visibility = 'public' rows are counted, and rows whose creator the
-- caller has a block with (either way) are left out, the same guard rpc_get_nearby_games uses.
-- Unknown sport id: zeros and '[]', no error. Anon: permission denied (EXECUTE granted to authenticated only).

CREATE OR REPLACE FUNCTION public.rpc_sport_overview(p_sport_id uuid, p_city_code text DEFAULT NULL)
 RETURNS TABLE(followers bigint, games_next7 bigint, meetups_next7 bigint, venues bigint, spaces bigint,
               posts bigint, news bigint, mutual_followers jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_window interval := interval '7 days';
  v_key    text;
  v_city   text := p_city_code;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'permission denied for function rpc_sport_overview' USING ERRCODE = '42501';
  END IF;

  SELECT s.sport_key INTO v_key FROM public.sports s WHERE s.id = p_sport_id;

  RETURN QUERY
  SELECT
    (SELECT count(DISTINCT p.id) FROM public.profiles p
      WHERE p.interests @> ARRAY[p_sport_id]
        AND NOT public.is_blocked(v_uid, p.user_id)),

    (SELECT count(DISTINCT g.id) FROM public.games g
       LEFT JOIN public.areas a ON a.id = g.area_id
      WHERE g.sport_id = p_sport_id AND g.is_cancelled = false
        AND g.listing_visibility = 'public'
        AND g.start_at >= now() AND g.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, g.creator_user_id)
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT m.id) FROM public.meetups m
       LEFT JOIN public.areas a ON a.id = m.area_id
      WHERE m.sport_id = p_sport_id AND m.is_cancelled = false
        AND m.listing_visibility = 'public'
        AND m.start_at >= now() AND m.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, m.creator_user_id)
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT v.id) FROM public.venues v
       LEFT JOIN public.areas a ON a.id = v.area_id
      WHERE v.is_active = true
        AND (v_city IS NULL OR a.city_code = v_city)
        AND ( (v_key IS NOT NULL AND v.sports @> ARRAY[v_key])
              OR EXISTS (SELECT 1 FROM public.venue_spaces vs
                          WHERE vs.venue_id = v.id AND vs.sport_id = p_sport_id AND vs.is_active = true) )),

    (SELECT count(DISTINCT vs.id) FROM public.venue_spaces vs
       JOIN public.venues v ON v.id = vs.venue_id AND v.is_active = true
       LEFT JOIN public.areas a ON a.id = v.area_id
      WHERE vs.sport_id = p_sport_id AND vs.is_active = true
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT po.id) FROM public.posts po
      WHERE po.sport_id = p_sport_id AND po.visibility = 'public'
        AND po.is_deleted = false AND po.is_hidden_admin = false
        AND coalesce(po.is_active, true) = true
        AND (po.expires_at IS NULL OR po.expires_at > now())
        AND NOT public.is_blocked(v_uid, po.author_user_id)),

    (SELECT count(DISTINCT n.id) FROM public.news n
       LEFT JOIN public.areas a ON a.id = n.area_id
      WHERE n.sport_id = p_sport_id AND n.status = 'published'
        AND n.published_at <= now() AND (n.expires_at IS NULL OR n.expires_at > now())
        AND (v_city IS NULL OR a.city_code = v_city)),

    coalesce((SELECT jsonb_agg(jsonb_build_object('display_name', x.display_name,
                                                  'avatar_url', x.avatar_url,
                                                  'username', x.username::text) ORDER BY x.username)
                FROM (SELECT DISTINCT ON (p.id) p.id, p.display_name, p.avatar_url, p.username
                        FROM public.profile_follows f
                        JOIN public.profiles me ON me.id = f.follower_profile_id AND me.user_id = v_uid
                        JOIN public.profiles p  ON p.id = f.following_profile_id
                       WHERE p.interests @> ARRAY[p_sport_id]
                         AND p.user_id <> v_uid
                         AND NOT public.is_blocked(v_uid, p.user_id)
                       ORDER BY p.id
                       LIMIT 3) x), '[]'::jsonb);
END;
$function$;

COMMENT ON FUNCTION public.rpc_sport_overview(uuid, text) IS 'KAN-621: Sport Overview aggregates (followers, city-scoped counts, <=3 mutual followers). Read-only. p_city_code = ref_cities.code, NULL = all cities. Authenticated only.';

REVOKE ALL ON FUNCTION public.rpc_sport_overview(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_sport_overview(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.rpc_sport_overview(uuid, text) TO authenticated;

-- Post-condition (read-only): fail the migration if the shape drifted.
DO $$
DECLARE f oid := 'public.rpc_sport_overview(uuid,text)'::regprocedure; d boolean; v char; cfg text[];
BEGIN
  SELECT prosecdef, provolatile, proconfig INTO d, v, cfg FROM pg_proc WHERE oid = f;
  IF NOT d OR v <> 's' OR cfg IS NULL THEN
    RAISE EXCEPTION 'KAN-621: rpc_sport_overview must be SECURITY DEFINER, STABLE with a pinned search_path';
  END IF;
  IF has_function_privilege('anon', f, 'EXECUTE') OR has_function_privilege('public', f, 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-621: anon/PUBLIC must not have EXECUTE';
  END IF;
  IF NOT has_function_privilege('authenticated', f, 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-621: authenticated must have EXECUTE';
  END IF;
END $$;

-- Games listing match 1 (team Luxor) + CTO ruling v2 (one favourites table).
--
-- This file is the record of what was applied to project wtncuzcskpigqpmnxwws
-- on 2026-10-08, step by step through execute_sql (apply_migration and DROP are
-- not usable in the operator session). NOTHING is dropped: every retired object
-- is renamed to *_legacy_vN and revoked.
--
-- Applied order:
--  1. v_game_card: card fields (host_verified, liked_by_me [kept: a view column
--     cannot be removed without DROP, the app does not read it], latitude,
--     longitude), roster_count follows game_slots_left (#26).
--  2. rpc_get_nearby_games renamed to rpc_get_nearby_games_legacy_v1 and a card
--     version created (that version was itself renamed in step 9).
--  3. public.favorites + RLS + toggle_favorite + favorite_count_of.
--  4. v_game_card / v_meetup_list / v_venues_with_sports gain favorite_count and
--     favourited_by_me. v_venues_with_sports keeps reloptions security_invoker=true
--     (CREATE OR REPLACE VIEW reset it; restored with ALTER VIEW).
--  5. rpc_get_nearby_games and rpc_get_nearby_venues renamed to *_legacy_v2 and
--     recreated with favorite_count + favourited_by_me.
--  6. venue_favorites, toggle_venue_favorite (both overloads), activity_favorites
--     and fn_activity_favorites_sync retired by RENAME + REVOKE.
-- toggle_favorite is SECURITY INVOKER (ruling v2; search_path='', auth.uid() only,
-- no user parameter). It was first applied as DEFINER and corrected afterwards
-- (CREATE OR REPLACE ... SECURITY INVOKER, no DROP): it returns the real total
-- through favorite_count_of(text, uuid), a STABLE definer helper that returns only
-- a number (RLS shows a caller only their own rows). The helper is also used where
-- the view / function runs as invoker (v_venues_with_sports, rpc_get_nearby_venues).
-- Correction applied after verification: rpc_get_nearby_games now joins the venue
-- as COALESCE(vs.venue_id, g.venue_id), like v_game_card, so venue_name matches
-- on both paths (before, a game with a venue but no space got a NULL venue_name).

-- (1) v_game_card ------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_game_card AS
 SELECT g.id,
    g.title,
    g.game_type,
    g.start_at,
    g.end_at,
    g.capacity,
    g.bench_slots,
    g.capacity + g.bench_slots AS total_slots,
    g.min_skill,
    g.max_skill,
    g.listing_visibility,
    g.join_policy,
    g.allow_spectators,
    g.allows_waitlist,
    g.is_cancelled,
    g.rules,
    g.created_at,
    g.updated_at,
    g.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en AS variant_name_en,
    sv.name_ar AS variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    g.creator_profile_id,
    cp.username AS creator_username,
    cp.display_name AS creator_display_name,
    cp.avatar_url AS creator_avatar_url,
    g.geo_location_id,
    g.area_id,
    a.name AS area_name,
    g.venue_space_id,
    g.venue_id,
    vs.name_en AS venue_space_name,
    v.name_en AS venue_name,
    g.joining_rule,
    g.cost_cover,
    ( SELECT count(*) AS count
           FROM game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text
            AND (gr.role = 'player'::text OR (gr.role = 'host'::text AND g.game_type = 'hosted'::text))) AS roster_count,
    g.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
    (COALESCE(( SELECT pv.verified FROM profile_verifications pv
          WHERE pv.profile_id = g.creator_profile_id), false)
     OR (EXISTS ( SELECT 1 FROM organiser o
          WHERE o.profile_id = g.creator_profile_id AND o.sport = s.sport_key
            AND o.is_verified AND o.is_active))) AS host_verified,
    (EXISTS ( SELECT 1 FROM likes lk
          WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
    st_y(gl.location::geometry) AS latitude,
    st_x(gl.location::geometry) AS longitude
   FROM games g
     LEFT JOIN sports s ON s.id = g.sport_id
     LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN profiles cp ON cp.id = g.creator_profile_id
     LEFT JOIN areas a ON a.id = g.area_id
     LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, g.venue_id)
     LEFT JOIN geo_locations gl ON gl.id = g.geo_location_id
  WHERE g.creator_user_id = auth.uid() OR is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id);

-- (2) first card-fields RPC version (renamed again in step 5) -----------------
ALTER FUNCTION public.rpc_get_nearby_games(double precision, double precision, integer, uuid, text) RENAME TO rpc_get_nearby_games_legacy_v1;
-- (the intermediate rpc_get_nearby_games with liked_by_me was created here and
--  renamed to rpc_get_nearby_games_legacy_v2 in step 5; its body is superseded
--  by the final definition below)

-- (3) favourites -------------------------------------------------------------
CREATE TABLE public.favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id uuid NULL REFERENCES public.games(id) ON DELETE CASCADE,
  meetup_id uuid NULL REFERENCES public.meetups(id) ON DELETE CASCADE,
  venue_id uuid NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT favorites_one_target CHECK (num_nonnulls(game_id, meetup_id, venue_id) = 1)
);
CREATE UNIQUE INDEX favorites_user_game_uidx ON public.favorites (user_id, game_id) WHERE game_id IS NOT NULL;
CREATE UNIQUE INDEX favorites_user_meetup_uidx ON public.favorites (user_id, meetup_id) WHERE meetup_id IS NOT NULL;
CREATE UNIQUE INDEX favorites_user_venue_uidx ON public.favorites (user_id, venue_id) WHERE venue_id IS NOT NULL;
CREATE INDEX favorites_game_idx ON public.favorites (game_id) WHERE game_id IS NOT NULL;
CREATE INDEX favorites_meetup_idx ON public.favorites (meetup_id) WHERE meetup_id IS NOT NULL;
CREATE INDEX favorites_venue_idx ON public.favorites (venue_id) WHERE venue_id IS NOT NULL;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.favorites FROM PUBLIC, anon;
GRANT SELECT, INSERT, DELETE ON public.favorites TO authenticated;
CREATE POLICY favorites_select ON public.favorites FOR SELECT TO authenticated USING (user_id = (select auth.uid()));
CREATE POLICY favorites_insert ON public.favorites FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));
CREATE POLICY favorites_delete ON public.favorites FOR DELETE TO authenticated USING (user_id = (select auth.uid()));

CREATE FUNCTION public.toggle_favorite(p_target_type text, p_target_id uuid)
RETURNS TABLE(favourited boolean, favorite_count integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $f$
DECLARE
  v_uid uuid := auth.uid();
  v_deleted integer;
  v_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_target_type IS NULL OR p_target_type NOT IN ('game','meetup','venue') THEN
    RAISE EXCEPTION 'invalid target type: %', p_target_type USING ERRCODE = '22023';
  END IF;

  IF p_target_type = 'game' THEN
    DELETE FROM public.favorites WHERE user_id = v_uid AND game_id = p_target_id;
  ELSIF p_target_type = 'meetup' THEN
    DELETE FROM public.favorites WHERE user_id = v_uid AND meetup_id = p_target_id;
  ELSE
    DELETE FROM public.favorites WHERE user_id = v_uid AND venue_id = p_target_id;
  END IF;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  IF v_deleted = 0 THEN
    IF p_target_type = 'game' THEN
      INSERT INTO public.favorites (user_id, game_id) VALUES (v_uid, p_target_id);
    ELSIF p_target_type = 'meetup' THEN
      INSERT INTO public.favorites (user_id, meetup_id) VALUES (v_uid, p_target_id);
    ELSE
      INSERT INTO public.favorites (user_id, venue_id) VALUES (v_uid, p_target_id);
    END IF;
  END IF;

  IF p_target_type = 'game' THEN
    SELECT count(*)::int INTO v_count FROM public.favorites WHERE game_id = p_target_id;
  ELSIF p_target_type = 'meetup' THEN
    SELECT count(*)::int INTO v_count FROM public.favorites WHERE meetup_id = p_target_id;
  ELSE
    SELECT count(*)::int INTO v_count FROM public.favorites WHERE venue_id = p_target_id;
  END IF;

  RETURN QUERY SELECT (v_deleted = 0), v_count;
END;
$f$;
REVOKE ALL ON FUNCTION public.toggle_favorite(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.toggle_favorite(text, uuid) TO authenticated;

CREATE FUNCTION public.favorite_count_of(p_target_type text, p_target_id uuid)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $f$
  SELECT count(*)::int FROM public.favorites f
  WHERE CASE p_target_type
          WHEN 'game' THEN f.game_id = p_target_id
          WHEN 'meetup' THEN f.meetup_id = p_target_id
          WHEN 'venue' THEN f.venue_id = p_target_id
          ELSE false END;
$f$;
REVOKE ALL ON FUNCTION public.favorite_count_of(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.favorite_count_of(text, uuid) TO anon, authenticated, service_role;

-- (4) views: favorite_count + favourited_by_me appended -----------------------
-- v_game_card: the step (1) definition plus, after longitude:
--     (SELECT count(*) FROM public.favorites f WHERE f.game_id = g.id)::int AS favorite_count,
--     EXISTS (SELECT 1 FROM public.favorites f WHERE f.game_id = g.id AND f.user_id = auth.uid()) AS favourited_by_me
-- v_meetup_list: the live definition plus, after venue_is_indoor:
--     (SELECT count(*) FROM public.favorites f WHERE f.meetup_id = m.id)::int AS favorite_count,
--     EXISTS (SELECT 1 FROM public.favorites f WHERE f.meetup_id = m.id AND f.user_id = auth.uid()) AS favourited_by_me
-- v_venues_with_sports: the live definition plus, after sports_ar:
--     public.favorite_count_of('venue', v.id) AS favorite_count,
--     EXISTS (SELECT 1 FROM public.favorites f WHERE f.venue_id = v.id AND f.user_id = auth.uid()) AS favourited_by_me
--   followed by: ALTER VIEW public.v_venues_with_sports SET (security_invoker = true);
-- (The full CREATE OR REPLACE VIEW statements were executed as separate steps;
--  they only append the two expressions above to the existing select lists.)

-- (5) RPCs: renamed to *_legacy_v2 and recreated ------------------------------
ALTER FUNCTION public.rpc_get_nearby_games(double precision, double precision, integer, uuid, text) RENAME TO rpc_get_nearby_games_legacy_v2;
ALTER FUNCTION public.rpc_get_nearby_venues(double precision, double precision, integer, uuid, text, boolean, numeric, numeric) RENAME TO rpc_get_nearby_venues_legacy_v2;
-- rpc_get_nearby_games(p_lat, p_lng, p_radius_meters, p_sport_id, p_sort) now
--   RETURNS TABLE(id, title, sport_name, scheduled_at, status, venue_name,
--     latitude, longitude, distance_meters, player_count, spots_remaining,
--     is_public, min_skill, max_skill, end_at, variant_name_en, variant_name_ar,
--     cost_cover, joining_rule, host_verified, favorite_count integer,
--     favourited_by_me boolean); SECURITY DEFINER, search_path public,pg_temp,
--     limit 50, OWNER postgres, EXECUTE to PUBLIC, anon, authenticated, service_role.
--     player_count follows game_slots_left (role='player' plus the host of a hosted game).
-- rpc_get_nearby_venues(... 8 args unchanged ...) now additionally returns
--     favorite_count integer, favourited_by_me boolean; SECURITY INVOKER,
--     EXECUTE to anon, authenticated, service_role (as before).

-- (6) retire the old favourites objects (RENAME + REVOKE, no DROP) ------------
ALTER TABLE public.venue_favorites RENAME TO venue_favorites_legacy_v1;
REVOKE ALL ON public.venue_favorites_legacy_v1 FROM anon, authenticated, PUBLIC;
ALTER FUNCTION public.toggle_venue_favorite(uuid, uuid) RENAME TO toggle_venue_favorite_legacy_v1;
ALTER FUNCTION public.toggle_venue_favorite(uuid) RENAME TO toggle_venue_favorite_legacy_v1;
REVOKE EXECUTE ON FUNCTION public.toggle_venue_favorite_legacy_v1(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.toggle_venue_favorite_legacy_v1(uuid) FROM PUBLIC, anon, authenticated;
ALTER TABLE public.activity_favorites DISABLE TRIGGER trg_activity_favorites_sync;
ALTER TABLE public.activity_favorites RENAME TO activity_favorites_legacy_v1;
REVOKE ALL ON public.activity_favorites_legacy_v1 FROM anon, authenticated, PUBLIC;
ALTER FUNCTION public.fn_activity_favorites_sync() RENAME TO fn_activity_favorites_sync_legacy_v1;
REVOKE EXECUTE ON FUNCTION public.fn_activity_favorites_sync_legacy_v1() FROM PUBLIC, anon, authenticated;
-- public.public_activities.favorite_count (added during the v1 attempt) stays,
-- unused, always 0.

-- KAN-717 F5: rpc_create_game_series fails P0001 persona_not_allowed for a unified-account (contributor) user.
--
-- Raising frame (reproduced live as user a3ba3271, role authenticated, BEGIN ... ROLLBACK):
--   rpc_create_game_legacy_v2 line 25 at RAISE (KAN-440 persona gate)
--   <- rpc_create_game line 6 <- fn_generate_game_series_occurrences_kan712_inner line 36
--   <- fn_generate_game_series_occurrences line 7 <- rpc_create_game_series line 26.
-- Cause: the generator passes profiles.persona_type to rpc_create_game as p_actor_type (introduced by KAN-693,
-- 20261030120000_kan693_rpc_create_game_series.sql lines 55/74, carried verbatim through 20261111122200 and
-- 20261113052438_kan718_writers_series.sql lines 177/200). Since KAN-646 (20261026120000) a unified account has
-- persona_type 'contributor'; choose_actor('contributor') finds the profile, but the legacy_v2 gate admits a
-- contributor only when p_actor_type is 'player' or 'organiser' with the matching extension row.
-- Fix: map a contributor persona to the actor type its extension rows grant (player first, else organiser) before
-- calling rpc_create_game. Non-contributor personas are passed as before. Nothing else in the body changes.
--
-- Re-authored from live pg_get_functiondef (2026-11-13). Signature, SECURITY DEFINER, search_path, owner and grants
-- unchanged (CREATE OR REPLACE keeps proacl {postgres=X/postgres}).

DO $guard$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure)
     IS DISTINCT FROM '43251ce46a33575705995b0cd1ec5d5a' THEN
    RAISE EXCEPTION 'KAN-717 F5: pre-image md5 of fn_generate_game_series_occurrences_kan712_inner differs; refusing';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.fn_generate_game_series_occurrences_kan712_inner(p_series_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_persona text; v_step int; v_n int; v_day date; v_start timestamptz; v_end timestamptz;
  v_future int; v_created int := 0; v_prev_sub text; v_gid uuid;
  v_g public.games;
BEGIN
  FOR s IN
    SELECT * FROM public.game_series
     WHERE status = 'active' AND (p_series_id IS NULL OR id = p_series_id)
     ORDER BY id
       FOR UPDATE   -- serialises two generators on the same series
  LOOP
    SELECT persona_type INTO v_persona FROM public.profiles WHERE id = s.creator_profile_id;
    -- KAN-717 F5: rpc_create_game takes an actor type, not a persona. A KAN-646 contributor acts as player
    -- (player row) or else organiser (organiser row); passing 'contributor' failed the KAN-440 gate.
    IF v_persona = 'contributor' THEN
      v_persona := CASE
        WHEN EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = s.creator_profile_id) THEN 'player'
        WHEN EXISTS (SELECT 1 FROM public.organiser x WHERE x.profile_id = s.creator_profile_id) THEN 'organiser'
        ELSE v_persona END;
    END IF;
    v_step := CASE WHEN s.rrule LIKE '%INTERVAL=2%' THEN 14 ELSE 7 END;

    SELECT count(*) INTO v_future FROM public.kan714_games_read g
     WHERE g.series_id = s.id AND g.start_at > now() AND NOT COALESCE(g.is_cancelled, false);

    v_n := 0;
    WHILE v_n < 52 AND v_future < s.occurrences_ahead LOOP   -- 52 = hard cap on occurrence slots per series
      v_day := s.starts_on + (v_n * v_step);
      EXIT WHEN s.ends_on IS NOT NULL AND v_day > s.ends_on;
      v_n := v_n + 1;   -- the slot is consumed even when its date is already held (counts once toward the cap)
      v_start := (v_day + s.start_time_local) AT TIME ZONE s.timezone;
      v_end := v_start + make_interval(mins => s.duration_minutes);
      CONTINUE WHEN v_start <= now();
      -- A kept row on this local date (any time) already counts in v_future; do not add a second one.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g
                             WHERE g.series_id = s.id AND NOT COALESCE(g.is_cancelled, false)
                               AND (g.start_at AT TIME ZONE s.timezone)::date = v_day);
      -- Cancelled rows keep their (series_id, start_at) slot in the unique index; never re-create them.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g WHERE g.series_id = s.id AND g.start_at = v_start);

      v_prev_sub := current_setting('request.jwt.claim.sub', true);
      PERFORM set_config('request.jwt.claim.sub', s.creator_user_id::text, true);
      v_gid := public.rpc_create_game(
        v_persona, s.sport_id, s.sport_variant_id, s.title, s.venue_space_id, v_start, v_end, 0,
        s.listing_visibility, s.join_policy, NULL, NULL, NULL, NULL, false, false, NULL, NULL,
        s.geo_location_id, s.area_id, NULL, NULL, NULL, s.capacity, 0::numeric, NULL);
      PERFORM set_config('request.jwt.claim.sub', COALESCE(v_prev_sub, ''), true);
      UPDATE public.games SET series_id = s.id WHERE id = v_gid
      RETURNING * INTO v_g;
      PERFORM public.kan718_game_event_sync(v_g);   -- KAN-718: the parent follows the row (updated_at)
      v_future := v_future + 1;
      v_created := v_created + 1;
    END LOOP;
  END LOOP;
  RETURN v_created;
END;
$function$;

DO $post$
BEGIN
  IF (SELECT proacl::text || '|' || prosecdef || '|' || array_to_string(proconfig, ',') || '|' || pg_get_userbyid(proowner)
        FROM pg_proc WHERE oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure)
     IS DISTINCT FROM '{postgres=X/postgres}|true|search_path=public, pg_temp|postgres' THEN
    RAISE EXCEPTION 'KAN-717 F5: post-image attributes or ACL changed; refusing';
  END IF;
END
$post$;

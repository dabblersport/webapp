-- KAN-939: a second account holding a valid join link (rpc_mint_join_link) can see and join a link-policy game.
-- 1. can_current_user_join_game: for join_policy = 'link', a valid, unexpired, not-exhausted token for that game
--    satisfies the visibility step (which only admits host/admin for private/link/invite). A block between viewer and
--    host still refuses. Every later refusal (cancelled, started, already, full -> waitlist) is unchanged, and
--    rpc_join_game (unchanged) still consumes one use on cta join_with_link.
-- 2. rpc_game_card_by_link(p_game_id, p_link_token): the v_game_card row for that game, only when the token is valid
--    for it (same predicate as the join), the game is link-policy and the caller is signed in and not blocked.
--    Otherwise no row, whatever the reason (no existence leak). Its select list is v_game_card's, copied verbatim;
--    a change to v_game_card's columns must re-author this function too (the guard pins the view text).
-- Re-authored from pg_get_functiondef on the live catalogue.

DO $guard$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure)
     <> '085495b09a90c68d2f009ffcdc5a46d5' THEN
    RAISE EXCEPTION 'KAN-939 pre-image guard: can_current_user_join_game changed';
  END IF;
  IF md5(pg_get_viewdef('public.v_game_card'::regclass)) <> 'b13dfbc501ce23fcad51af9bc6ad2df7' THEN
    RAISE EXCEPTION 'KAN-939 pre-image guard: v_game_card changed';
  END IF;
  IF to_regprocedure('public.rpc_game_card_by_link(uuid,uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-939 pre-image guard: rpc_game_card_by_link already exists';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.can_current_user_join_game(p_game_id uuid, p_actor_type text DEFAULT 'player'::text, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.games%rowtype; viewer uuid := auth.uid(); actor_id uuid;
  slots int; visible boolean; cta text;
  e public.events%rowtype;
BEGIN
  IF viewer IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'anon'); END IF;
  IF public.is_frozen(viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'frozen'); END IF;
  actor_id := public.choose_actor(p_actor_type);
  IF NOT public.actor_is_player(actor_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'actor_not_player'); END IF;
  -- KAN-834: games is read for its retained columns only (event_id, squad_id), through RLS. games has no policy, so
  -- a caller without events access (INVOKER client) stops here with not_found, as before. Every shared field is
  -- read from events; a caller that sees a games row but cannot read events raises 42501 below (fail closed).
  SELECT * INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  SELECT * INTO e FROM public.events WHERE id = g.event_id AND event_type = 'game';
  IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  IF e.creator_user_id = viewer THEN RETURN jsonb_build_object('allowed', false, 'cta', 'host', 'reason', 'host'); END IF;
  visible := public.can_view_with_scope(viewer, e.creator_user_id, e.listing_visibility, g.squad_id);
  -- KAN-939: a valid join link for this link-policy game satisfies visibility. A block still refuses.
  IF NOT visible AND e.join_policy = 'link' AND p_link_token IS NOT NULL
     AND NOT public.is_blocked(viewer, e.creator_user_id)
     AND public._link_token_valid(p_game_id, p_link_token) THEN
    visible := true;
  END IF;
  IF NOT visible THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_visible', 'reason', 'visibility_denied'); END IF;
  IF e.is_cancelled THEN RETURN jsonb_build_object('allowed', false, 'cta', 'cancelled', 'reason', 'cancelled'); END IF;
  IF e.start_at <= now() THEN RETURN jsonb_build_object('allowed', false, 'cta', 'started', 'reason', 'started'); END IF;
  IF EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.status = 'active' AND (r.user_id = viewer OR r.profile_id = actor_id)) THEN
    RETURN jsonb_build_object('allowed', false, 'cta', 'joined', 'reason', 'already');
  END IF;
  CASE e.join_policy
    WHEN 'open' THEN cta := 'join';
    WHEN 'request' THEN
      IF EXISTS (SELECT 1 FROM public.game_join_requests q WHERE q.game_id = p_game_id AND q.status = 'pending' AND (q.from_user_id = viewer OR q.from_profile_id = actor_id)) THEN
        RETURN jsonb_build_object('allowed', false, 'cta', 'requested', 'reason', 'pending_request');
      END IF;
      cta := 'request';
    WHEN 'invite' THEN
      IF EXISTS (SELECT 1 FROM public.game_invites i WHERE i.game_id = p_game_id AND i.status = 'pending' AND i.to_user_id = viewer) THEN   -- KAN-717 F1: rpc_invite_user writes to_user_id
        cta := 'accept_invite';
      ELSE
        RETURN jsonb_build_object('allowed', false, 'cta', 'invite_only', 'reason', 'invite_required');
      END IF;
    WHEN 'link' THEN
      IF p_link_token IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_required', 'reason', 'missing_link'); END IF;
      IF NOT public._link_token_valid(p_game_id, p_link_token) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_invalid', 'reason', 'invalid_link'); END IF;
      cta := 'join_with_link';
    WHEN 'circle' THEN
      IF NOT public.are_synced(viewer, e.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
      cta := 'join';
    WHEN 'squad' THEN
      IF g.squad_id IS NULL OR NOT public.is_in_squad(viewer, g.squad_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'squad_only', 'reason', 'not_in_squad'); END IF;
      cta := 'join';
    WHEN 'closed' THEN RETURN jsonb_build_object('allowed', false, 'cta', 'closed', 'reason', 'closed');
    ELSE RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'unknown_policy');
  END CASE;
  slots := public.game_slots_left(p_game_id);
  IF slots = 0 THEN
    RETURN jsonb_build_object('allowed', true,
      'cta', CASE WHEN e.join_policy = 'request' THEN 'request' ELSE 'waitlist' END,
      'reason', 'full');
  END IF;
  RETURN jsonb_build_object('allowed', true, 'cta', cta, 'reason', NULL);
END;
$function$;

CREATE FUNCTION public.rpc_game_card_by_link(p_game_id uuid, p_link_token uuid)
 RETURNS SETOF public.v_game_card
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-939: v_game_card's select list (verbatim); the row only for a valid join link on a link-policy game.
  SELECT g.id,
    e.title,
    g.game_type,
    e.start_at,
    e.end_at,
    e.capacity,
    g.bench_slots,
    e.capacity + g.bench_slots AS total_slots,
    e.min_skill::integer AS min_skill,
    e.max_skill::integer AS max_skill,
    e.listing_visibility,
    e.join_policy,
    g.allow_spectators,
    g.allows_waitlist,
    e.is_cancelled,
    g.rules,
    e.created_at,
    e.updated_at,
    e.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en AS variant_name_en,
    sv.name_ar AS variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    e.creator_profile_id,
    cp.username AS creator_username,
    cp.display_name AS creator_display_name,
    cp.avatar_url AS creator_avatar_url,
    e.geo_location_id,
    e.area_id,
    a.name AS area_name,
    g.venue_space_id,
    e.venue_id,
    vs.name_en AS venue_space_name,
    v.name_en AS venue_name,
    e.joining_rule,
    e.cost_cover,
    ( SELECT count(*) AS count
           FROM game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text AND (gr.role = 'player'::text OR gr.role = 'host'::text AND g.game_type = 'hosted'::text)) AS roster_count,
    e.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
    COALESCE(( SELECT pv.verified
           FROM profile_verifications pv
          WHERE pv.profile_id = e.creator_profile_id), false) OR (EXISTS ( SELECT 1
           FROM organiser o
          WHERE o.profile_id = e.creator_profile_id AND o.sport = s.sport_key AND o.is_verified AND o.is_active)) AS host_verified,
    (EXISTS ( SELECT 1
           FROM likes lk
          WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
    st_y(gl.location::geometry) AS latitude,
    st_x(gl.location::geometry) AS longitude,
    (( SELECT count(*) AS count
           FROM favorites f
          WHERE f.game_id = g.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM favorites f
          WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
    g.price_aed,
    g.series_id,
        CASE
            WHEN s2.id IS NULL THEN NULL::text
            WHEN s2.rrule ~~ '%INTERVAL=2%'::text THEN 'biweekly'::text
            ELSE 'weekly'::text
        END AS series_frequency,
    s2.ends_on AS series_ends_on
   FROM games g
     JOIN events e ON e.id = g.event_id AND e.event_type = 'game'::text
     LEFT JOIN sports s ON s.id = e.sport_id
     LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN profiles cp ON cp.id = e.creator_profile_id
     LEFT JOIN areas a ON a.id = e.area_id
     LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, e.venue_id)
     LEFT JOIN geo_locations gl ON gl.id = e.geo_location_id
     LEFT JOIN game_series s2 ON s2.id = g.series_id
  WHERE g.id = p_game_id
    AND p_link_token IS NOT NULL
    AND auth.uid() IS NOT NULL
    AND e.join_policy = 'link'
    AND NOT public.is_blocked(auth.uid(), e.creator_user_id)
    AND public._link_token_valid(p_game_id, p_link_token);
$function$;

ALTER FUNCTION public.rpc_game_card_by_link(uuid, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_game_card_by_link(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_game_card_by_link(uuid, uuid) TO authenticated, service_role;

DO $post$
DECLARE r record;
BEGIN
  SELECT p.prosecdef, p.proconfig::text cfg, p.proowner::regrole::text own,
         has_function_privilege('anon', p.oid, 'EXECUTE') anon_x,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') auth_x,
         COALESCE(p.proacl::text LIKE '%{=X%' OR p.proacl::text LIKE '%,=X%', true) public_x
    INTO r FROM pg_proc p WHERE p.oid = 'public.rpc_game_card_by_link(uuid,uuid)'::regprocedure;
  IF NOT r.prosecdef OR r.cfg <> '{"search_path=public, pg_temp"}' OR r.own <> 'postgres'
     OR r.anon_x OR NOT r.auth_x OR r.public_x THEN
    RAISE EXCEPTION 'KAN-939 post-assert rpc_game_card_by_link: %', row_to_json(r);
  END IF;
  SELECT p.prosecdef, p.proconfig::text cfg, p.proowner::regrole::text own, p.proacl::text acl
    INTO r FROM pg_proc p WHERE p.oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure;
  IF r.prosecdef OR r.cfg <> '{search_path=public}' OR r.own <> 'postgres'
     OR r.acl <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-939 post-assert can_current_user_join_game: %', row_to_json(r);
  END IF;
END
$post$;

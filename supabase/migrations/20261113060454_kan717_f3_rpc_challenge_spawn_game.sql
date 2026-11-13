-- KAN-717 F3: rpc_challenge_spawn_game could never succeed.
--   * listing_visibility 'hidden' fails games_listing_visibility_check / events_game_visibility_check
--     (allowed: public, followers, private). Ruling: a spawned challenge game is 'private' (it is between
--     the two squads); join_policy stays 'invite' (earlier ruling).
--   * With no venue space the insert raised a NOT NULL on games.geo_location_id. Ruling: take the location
--     from the challenge; if the challenge carries none, refuse with P0001 'challenge_location_required'.
--     Live public.challenges / challenge_fixtures have no venue, space or geo column (and rules / preferences /
--     meta carry no location key; 0 rows on 2026-11-13), so the only location a spawn can have is the one
--     kan718_game_derive takes from p_venue_space_id. No space (or a space without geo) -> the new error.
-- Authored from live pg_get_functiondef (md5 713045d14f157999b63425c883d6936a). Signature, SECURITY DEFINER,
-- search_path, owner and ACL unchanged (CREATE OR REPLACE keeps proacl; asserted below). Still writes the events
-- parent through kan718_game_derive / kan718_game_event_sync (KAN-718).
-- Rollback: CREATE OR REPLACE with the pre-image (git show of 20261113052303_kan718_writers_create.sql).

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_challenge_spawn_game(uuid,timestamptz,uuid)'::regprocedure))
     <> '713045d14f157999b63425c883d6936a' THEN
    RAISE EXCEPTION 'KAN-717 F3: rpc_challenge_spawn_game is not the expected KAN-718 pre-image';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.rpc_challenge_spawn_game(p_fixture_id uuid, p_start_at timestamp with time zone, p_venue_space_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  f record; c record; gid uuid; title text;
  v_g public.games;
BEGIN
  SELECT * INTO f FROM public.challenge_fixtures WHERE id = p_fixture_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='fixture_not_found'; END IF;

  SELECT * INTO c FROM public.challenges WHERE id = f.challenge_id;
  IF c.owner_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_owner';
  END IF;

  title := COALESCE(c.title, 'Challenge') || ' — Fixture ' || f.id::text;

  -- KAN-718: location facts derived here, events parent written here (not by triggers on games).
  -- The five location columns take the values the table defaults gave the kan713 triggers.
  v_g.id := gen_random_uuid();
  v_g.game_type := 'hosted'; v_g.title := title;
  v_g.creator_profile_id := c.owner_profile_id; v_g.creator_user_id := c.owner_user_id;
  v_g.start_at := p_start_at; v_g.end_at := p_start_at + interval '90 minutes'; v_g.capacity := 22;
  v_g.listing_visibility := 'private'; v_g.join_policy := 'invite';   -- KAN-717 F3: 'hidden' / 'squad' fail the checks
  v_g.sport_id := c.sport_id;   -- KAN-717 F3: without it the insert raised sport_not_challenge
  v_g.venue_space_id := p_venue_space_id; v_g.squad_id := null;
  v_g.joining_rule := 'free'; v_g.cost_cover := 'free';
  v_g := public.kan718_game_derive(v_g, NULL);
  -- KAN-717 F3: the challenge row carries no location of its own, so the space is the only source.
  IF v_g.geo_location_id IS NULL OR v_g.area_id IS NULL THEN
    RAISE EXCEPTION USING errcode='P0001', message='challenge_location_required';
  END IF;
  INSERT INTO public.games(
    id, game_type, title, sport_id,
    creator_profile_id, creator_user_id,
    start_at, end_at, capacity,
    listing_visibility, join_policy,
    venue_space_id, squad_id,
    venue_id, geo_location_id, area_id, joining_rule, cost_cover
  )
  VALUES (
    v_g.id, 'hosted', title, v_g.sport_id,
    c.owner_profile_id, c.owner_user_id,
    p_start_at, p_start_at + interval '90 minutes', 22,
    'private', 'invite',
    p_venue_space_id, null,
    v_g.venue_id, v_g.geo_location_id, v_g.area_id, v_g.joining_rule, v_g.cost_cover
  )
  RETURNING * INTO v_g;
  PERFORM public.kan718_game_event_sync(v_g, true);
  gid := v_g.id;

  UPDATE public.challenge_fixtures
  SET game_id = gid, scheduled_at = p_start_at
  WHERE id = p_fixture_id;

  PERFORM public.emit_event('challenge.fixture_spawned', 'challenge', f.challenge_id, auth.uid(),
    jsonb_build_object('fixture_id', p_fixture_id, 'game_id', gid));

  RETURN gid;
END;
$function$;

DO $post$
DECLARE p pg_proc;
BEGIN
  SELECT * INTO p FROM pg_proc WHERE oid = 'public.rpc_challenge_spawn_game(uuid,timestamptz,uuid)'::regprocedure;
  IF NOT p.prosecdef OR p.proowner <> 'postgres'::regrole OR p.proconfig IS DISTINCT FROM '{search_path=public}'::text[]
     OR p.proacl::text <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
     OR p.prosrc !~ 'kan718_game_derive' OR p.prosrc !~ 'kan718_game_event_sync' THEN
    RAISE EXCEPTION 'KAN-717 F3: rpc_challenge_spawn_game attributes / ACL changed';
  END IF;
END
$post$;

-- KAN-947 P-d: the last two game writers go events-first, can_current_user_join_game stops naming the games row
-- type, and with no games-first writer left the games-typed helpers and the games BEFORE triggers whose behaviour
-- now lives in the writers (kan947_game_derive) are retired. After this, nothing writes or derives a shared column
-- on public.games except the P-a mirror (kan947_games_from_events / kan947_events_game_mirror), which KAN-866
-- drops together with the 22 columns.
--
-- Authored from the live pg_get_functiondef, 2026-11-14, project wtncuzcskpigqpmnxwws. Pre-image (functiondef md5):
--   rpc_booking_hold_for_game_kan712_inner(uuid,uuid,tstz,tstz)  fcea6b14aa1374b8bc70142d0110544a
--   rpc_challenge_spawn_game(uuid,tstz,uuid)                       0e36bff20f3e11741ba7ddd848dfc972
--   can_current_user_join_game(uuid,text,uuid)                     110b9a2abdbb115d43e845599ecde78c
--   kan718_game_event_sync(games,boolean)                          aba2d03ed3ee12dc5df3214be39c43ba
--   kan718_game_derive(games,games)                                9f5389d964a495d394b37360fc5acaf9
--   kan711_events_map_game(games)                                  13c7dca7b23baaa0bf731b6d5a5b33c6
--   kan947_games_from_events()                                     69b4ecd03afba9e9f19624be93693e88
-- CREATE OR REPLACE keeps owner, ACL, SECURITY, volatility and search_path; all are re-asserted below.
--
-- 1. rpc_booking_hold_for_game_kan712_inner: same checks and booking insert; games gets venue_space_id, the events
--    parent gets the location facts (kan947_game_derive(old events, new space, -, old events, old space)).
-- 2. rpc_challenge_spawn_game: same checks, title and values; the events parent is inserted first (derive on the
--    events row; challenge_location_required unchanged), then games with id, event_id, game_type, venue_space_id,
--    squad_id. The request_id unique translation is the one kan718_game_event_sync used.
-- 3. can_current_user_join_game: reads games.event_id and games.squad_id into a record instead of a
--    games%rowtype (the row type loses 22 fields at KAN-866). Body otherwise byte-identical.
-- 4. DROP FUNCTION kan718_game_event_sync(games,boolean), kan718_game_derive(games,games),
--    kan711_events_map_game(games): EXECUTE postgres only, and no function body names them (asserted in pre).
-- 4b. kan947_games_from_events (P-a): only its INSERT comment changes; it named kan718_game_event_sync, which no
--    longer exists (a games INSERT with no parent is now an orphan, refused at commit by trg_games_event_link_check).
-- 5. DROP TRIGGER on games, behaviour now in every writer through kan947_game_derive or on events:
--      trg_games_set_host (creator_user_id), trg_games_block_frozen (frozen creator),
--      trg_games_stamp_request_id (thebes.create_request_id), trg_games_require_challenge_sport,
--      trg_games_inherit_sport_from_space (sport_id / capacity from the space or variant),
--      trg_games_sync_geo (fn_sync_geo_fields writes only for profile_locations: a no-op on games),
--      trg_games_touch (games.updated_at is now copied from events by the mirror).
--    The trigger functions stay (other tables use touch_updated_at / fn_sync_geo_fields / kan611_stamp_request_id).
--    Kept: trg_kan718_games_series_occurrence (reads games.series_id/event_id and events.start_at only),
--    trg_kan711_games_assign_event_id, the two constraint triggers, and the four already-disabled triggers
--    (trg_game_created, trg_games_inherit_geo, trg_games_inherit_venue_geo, trg_games_sync_joining_rule), which
--    KAN-866 must drop with the columns (two have column lists on venue_id / venue_space_id).
-- Test: supabase/tests/events_p4/kan947_pd_game_hold_spawn_live_test.sql.

do $pre$
declare
  k record;
begin
  for k in select * from (values
    ('public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)', 'fcea6b14aa1374b8bc70142d0110544a'),
    ('public.rpc_challenge_spawn_game(uuid,timestamp with time zone,uuid)', '0e36bff20f3e11741ba7ddd848dfc972'),
    ('public.can_current_user_join_game(uuid,text,uuid)', '110b9a2abdbb115d43e845599ecde78c'),
    ('public.kan718_game_event_sync(public.games,boolean)', 'aba2d03ed3ee12dc5df3214be39c43ba'),
    ('public.kan718_game_derive(public.games,public.games)', '9f5389d964a495d394b37360fc5acaf9'),
    ('public.kan711_events_map_game(public.games)', '13c7dca7b23baaa0bf731b6d5a5b33c6'),
    ('public.kan947_games_from_events()', '69b4ecd03afba9e9f19624be93693e88')) v(fn, pre)
  loop
    if md5(pg_get_functiondef(to_regprocedure(k.fn))) is distinct from k.pre then
      raise exception 'KAN-947 P-d pre: % absent or drifted', k.fn;
    end if;
  end loop;
  -- every other caller of the three helpers was converted in P-a..P-c
  if exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace
              and p.prosrc ~ 'kan718_game_event_sync|kan718_game_derive|kan711_events_map_game'
              and p.proname not in ('rpc_booking_hold_for_game_kan712_inner', 'rpc_challenge_spawn_game',
                                    'kan718_game_event_sync', 'kan718_game_derive', 'kan711_events_map_game',
                                    'kan947_games_from_events')) then
    raise exception 'KAN-947 P-d pre: a games-typed helper still has an unconverted caller';
  end if;
  -- no games-first writer is left besides the two converted here
  if exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace
              and p.prosrc ~* 'insert\s+into\s+(public\.)?games\s*\(([^)]*\m(title|creator_profile_id|start_at|sport_id)\M)'
              and p.proname not in ('rpc_challenge_spawn_game')) then
    raise exception 'KAN-947 P-d pre: a games INSERT still names shared columns';
  end if;
  if (select count(*) from pg_trigger where tgrelid = 'public.games'::regclass and tgname in
        ('trg_games_set_host', 'trg_games_block_frozen', 'trg_games_stamp_request_id', 'trg_games_require_challenge_sport',
         'trg_games_inherit_sport_from_space', 'trg_games_sync_geo', 'trg_games_touch')) <> 7 then
    raise exception 'KAN-947 P-d pre: the seven games BEFORE triggers are not all present';
  end if;
end
$pre$;

CREATE OR REPLACE FUNCTION public.rpc_booking_hold_for_game_kan712_inner(p_game_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g   record;
  vid uuid;
  bid uuid;
  v_o public.events;
  v_d public.events;
  v_old_space uuid;
  v_variant uuid;
BEGIN
  SELECT * INTO g FROM public.kan714_games_read WHERE id = p_game_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_found'; END IF;

  SELECT s.venue_id INTO vid FROM public.venue_spaces s WHERE s.id = p_space_id;
  IF vid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='space_not_found'; END IF;

  IF NOT (g.creator_user_id = auth.uid()
          OR public.is_venue_admin(auth.uid(), vid)
          OR public.is_admin(auth.uid())) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_authorized';
  END IF;

  INSERT INTO public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  VALUES (p_space_id, p_start, p_end, 'game', p_game_id, 'confirmed', auth.uid())
  RETURNING id INTO bid;

  -- KAN-947: games gets the space (retained column) first, then the events parent gets the location facts from
  -- the KAN-718 derive on the events row; trg_zz_kan947_events_game_mirror copies them onto games.
  SELECT gm.venue_space_id, gm.sport_variant_id INTO v_old_space, v_variant FROM public.games gm WHERE gm.id = p_game_id FOR UPDATE;
  SELECT * INTO v_o FROM public.events e WHERE e.id = p_game_id AND e.event_type = 'game' FOR UPDATE;
  v_d := public.kan947_game_derive(v_o, p_space_id, v_variant, v_o, v_old_space);
  UPDATE public.games gm SET venue_space_id = p_space_id WHERE gm.id = p_game_id;
  UPDATE public.events e
     SET venue_id = v_d.venue_id, geo_location_id = v_d.geo_location_id, area_id = v_d.area_id,
         joining_rule = v_d.joining_rule, cost_cover = v_d.cost_cover
   WHERE e.id = v_o.id;

  RETURN bid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_challenge_spawn_game(p_fixture_id uuid, p_start_at timestamp with time zone, p_venue_space_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  f record; c record; gid uuid; title text;
  v_e public.events;
  v_con text;
BEGIN
  SELECT * INTO f FROM public.challenge_fixtures WHERE id = p_fixture_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='fixture_not_found'; END IF;

  SELECT * INTO c FROM public.challenges WHERE id = f.challenge_id;
  IF c.owner_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_owner';
  END IF;

  title := COALESCE(c.title, 'Challenge') || ' — Fixture ' || f.id::text;

  -- KAN-947: the events parent first (location facts from the KAN-718 derive on the events row), then games with
  -- its retained columns only. The five location columns take the values the table defaults gave the kan713 triggers.
  v_e.id := gen_random_uuid(); v_e.event_type := 'game'; v_e.title := title;
  v_e.creator_profile_id := c.owner_profile_id; v_e.creator_user_id := c.owner_user_id;
  v_e.start_at := p_start_at; v_e.end_at := p_start_at + interval '90 minutes'; v_e.capacity := 22;
  v_e.listing_visibility := 'private'; v_e.join_policy := 'invite';   -- KAN-717 F3: 'hidden' / 'squad' fail the checks
  v_e.sport_id := c.sport_id;   -- KAN-717 F3: without it the insert raised sport_not_challenge
  v_e.joining_rule := 'free'; v_e.cost_cover := 'free';
  v_e := public.kan947_game_derive(v_e, p_venue_space_id, NULL, NULL, NULL);
  -- KAN-717 F3: the challenge row carries no location of its own, so the space is the only source.
  IF v_e.geo_location_id IS NULL OR v_e.area_id IS NULL THEN
    RAISE EXCEPTION USING errcode='P0001', message='challenge_location_required';
  END IF;
  BEGIN
    INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at,
           capacity, listing_visibility, join_policy, sport_id, area_id, geo_location_id, venue_id,
           joining_rule, cost_cover, request_id)
    VALUES (v_e.id, 'game', v_e.creator_profile_id, v_e.creator_user_id, title, p_start_at, p_start_at + interval '90 minutes',
           22, 'private', 'invite', v_e.sport_id, v_e.area_id, v_e.geo_location_id, v_e.venue_id,
           v_e.joining_rule, v_e.cost_cover, v_e.request_id)
    RETURNING * INTO v_e;
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
    IF v_con = 'events_type_creator_request_id_key' THEN
      RAISE EXCEPTION USING ERRCODE = '23505',
        CONSTRAINT = 'games_creator_user_request_id_key',
        MESSAGE = 'duplicate key value violates unique constraint "games_creator_user_request_id_key"',
        DETAIL = format('kan712: events parent for request_id %s already exists', v_e.request_id);
    END IF;
    RAISE;
  END;
  INSERT INTO public.games (id, event_id, game_type, venue_space_id, squad_id)
  VALUES (v_e.id, v_e.id, 'hosted', p_venue_space_id, null);
  gid := v_e.id;

  UPDATE public.challenge_fixtures
  SET game_id = gid, scheduled_at = p_start_at
  WHERE id = p_fixture_id;

  PERFORM public.emit_event('challenge.fixture_spawned', 'challenge', f.challenge_id, auth.uid(),
    jsonb_build_object('fixture_id', p_fixture_id, 'game_id', gid));

  RETURN gid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.can_current_user_join_game(p_game_id uuid, p_actor_type text DEFAULT 'player'::text, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  g record; viewer uuid := auth.uid(); actor_id uuid;
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
  -- KAN-947: a record, not games%rowtype, so the 22 columns KAN-866 drops are never part of this function.
  SELECT g0.event_id, g0.squad_id INTO g FROM public.games g0 WHERE g0.id = p_game_id;
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

CREATE OR REPLACE FUNCTION public.kan947_games_from_events()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  e public.events;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF pg_trigger_depth() < 2 OR coalesce(current_setting('kan947.mirror', true), '') <> NEW.id::text THEN
      RETURN NEW;     -- not inside kan947_events_game_mirror: a retained-column write, leave its row alone
    END IF;
  END IF;
  SELECT * INTO e FROM public.events WHERE id = coalesce(NEW.event_id, NEW.id) AND event_type = 'game';
  IF NOT FOUND THEN
    RETURN NEW;       -- INSERT with no events parent: refused at commit by trg_games_event_link_check
  END IF;
  NEW.creator_profile_id := e.creator_profile_id; NEW.creator_user_id := e.creator_user_id;
  NEW.title := e.title; NEW.start_at := e.start_at; NEW.end_at := e.end_at; NEW.capacity := e.capacity;
  NEW.listing_visibility := e.listing_visibility; NEW.join_policy := e.join_policy;
  NEW.is_cancelled := e.is_cancelled; NEW.cancelled_at := e.cancelled_at; NEW.cancelled_reason := e.cancelled_reason;
  NEW.sport_id := e.sport_id; NEW.area_id := e.area_id; NEW.geo_location_id := e.geo_location_id;
  NEW.venue_id := e.venue_id; NEW.min_skill := e.min_skill; NEW.max_skill := e.max_skill;
  NEW.joining_rule := e.joining_rule; NEW.cost_cover := e.cost_cover; NEW.request_id := e.request_id;
  NEW.created_at := e.created_at; NEW.updated_at := e.updated_at;
  RETURN NEW;
END
$function$;

DROP FUNCTION public.kan718_game_event_sync(public.games, boolean);
DROP FUNCTION public.kan718_game_derive(public.games, public.games);
DROP FUNCTION public.kan711_events_map_game(public.games);

DROP TRIGGER trg_games_set_host ON public.games;
DROP TRIGGER trg_games_block_frozen ON public.games;
DROP TRIGGER trg_games_stamp_request_id ON public.games;
DROP TRIGGER trg_games_require_challenge_sport ON public.games;
DROP TRIGGER trg_games_inherit_sport_from_space ON public.games;
DROP TRIGGER trg_games_sync_geo ON public.games;
DROP TRIGGER trg_games_touch ON public.games;

do $post$
declare
  r record;
begin
  select p.proacl::text acl, p.prosecdef, p.provolatile::text vol, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
    into r from pg_proc p where p.oid = 'public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure;
  if r.acl <> '{postgres=X/postgres}' or r.prosecdef is not true or r.vol <> 'v' or r.cfg <> 'search_path=public' or r.own <> 'postgres' then
    raise exception 'KAN-947 P-d post: rpc_booking_hold_for_game_kan712_inner attributes drifted: %', r;
  end if;
  select p.proacl::text acl, p.prosecdef, p.provolatile::text vol, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
    into r from pg_proc p where p.oid = 'public.rpc_challenge_spawn_game(uuid,timestamp with time zone,uuid)'::regprocedure;
  if r.acl <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}' or r.prosecdef is not true
     or r.vol <> 'v' or r.cfg <> 'search_path=public' or r.own <> 'postgres' then
    raise exception 'KAN-947 P-d post: rpc_challenge_spawn_game attributes drifted: %', r;
  end if;
  select p.proacl::text acl, p.prosecdef, p.provolatile::text vol, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
    into r from pg_proc p where p.oid = 'public.can_current_user_join_game(uuid,text,uuid)'::regprocedure;
  if r.acl <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}' or r.prosecdef is not false
     or r.vol <> 's' or r.cfg <> 'search_path=public' or r.own <> 'postgres' then
    raise exception 'KAN-947 P-d post: can_current_user_join_game attributes drifted: %', r;
  end if;
  if to_regprocedure('public.kan718_game_event_sync(public.games,boolean)') is not null
     or to_regprocedure('public.kan718_game_derive(public.games,public.games)') is not null
     or to_regprocedure('public.kan711_events_map_game(public.games)') is not null then
    raise exception 'KAN-947 P-d post: a games-typed helper is still present';
  end if;
  if exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace
              and p.prosrc ~ 'kan718_game_event_sync|kan718_game_derive|kan711_events_map_game') then
    raise exception 'KAN-947 P-d post: a function body still names a dropped helper';
  end if;
  select p.proacl::text acl, p.prosecdef, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
    into r from pg_proc p where p.oid = 'public.kan947_games_from_events()'::regprocedure;
  if r.acl <> '{postgres=X/postgres}' or r.prosecdef is not false or r.cfg <> 'search_path=""' or r.own <> 'postgres' then
    raise exception 'KAN-947 P-d post: kan947_games_from_events attributes drifted: %', r;
  end if;
  if exists (select 1 from pg_trigger where tgrelid = 'public.games'::regclass and tgname in
        ('trg_games_set_host', 'trg_games_block_frozen', 'trg_games_stamp_request_id', 'trg_games_require_challenge_sport',
         'trg_games_inherit_sport_from_space', 'trg_games_sync_geo', 'trg_games_touch')) then
    raise exception 'KAN-947 P-d post: a retired games trigger is still attached';
  end if;
end
$post$;

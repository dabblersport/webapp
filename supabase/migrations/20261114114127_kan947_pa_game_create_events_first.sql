-- KAN-947 P-a (KAN-866 prerequisite, gate c comment 16316): the games write path goes events-first, modelled on
-- KAN-862 (71b5deda, 053fc08d, and the Z01 fix-forward 20261113202544: a trigger that only looks redundant can be
-- load-bearing, so every games trigger behaviour is moved before anything is dropped).
--
-- Authored from the live pg_get_functiondef, 2026-11-14, project wtncuzcskpigqpmnxwws. Pre-image (functiondef md5):
--   rpc_create_game_legacy_v1(24 args)   007929d0ab0f09e94ae415a33a2877e4
--   rpc_create_game_legacy_v2(25 args)   389b2724eaf777ab4e799f66c2bdcec9
--   fn_games_activity_sync()             4be74137f22e17c5a8efa3171aa80d3b  (re-attached to events, body unchanged)
--   trg_game_updated_notify()            45c97c575b8ad3887d61cecbb72e80bf  (re-attached to events, body unchanged)
--   msg_system_game_trg()                f97b4a6ddb3542ba282d53f8e4a5e92b  (re-attached to events, body unchanged)
--
-- 1. kan947_game_derive(events, venue_space_id, sport_variant_id, old events, old venue_space_id) RETURNS events:
--    kan718_game_derive, line for line, on the events row. The two games-only inputs it read (venue_space_id,
--    sport_variant_id) are parameters. Same checks, errors and order: frozen creator, sport/capacity from the space,
--    capacity from the variant, challenge sport, creator_user_id from the profile, request_id stamp, location,
--    joining rule, venue geo. kan718_game_derive stays (unconverted writers) until P-d retires it.
-- 2. One-way events -> games mirror for the 22 shared columns, until KAN-866 drops them:
--    a. kan947_games_from_events(), BEFORE trigger on games.
--       INSERT (trg_00_kan947_games_from_events, sorts first): when the events parent already exists (events-first
--       writer), its shared values are copied onto NEW, so the games BEFORE triggers that remain until P-d, the NOT
--       NULLs and the CHECKs see the same full row as before. A games-first writer (no parent yet) is untouched.
--       UPDATE (trg_zz_kan947_games_from_events, sorts last, after trg_games_touch): only inside the mirror below
--       (kan947.mirror = this id, trigger depth > 1); copies events onto NEW, updated_at included (exact parity).
--    b. kan947_events_game_mirror(), AFTER UPDATE on events for game rows (trg_zz_kan947_events_game_mirror):
--       touches the games row (SET bench_slots = bench_slots) only when its shared values differ from events. A
--       games-first writer has already written the same values (kan718_game_event_sync), so it is skipped there and
--       nothing is written twice. The games row update also keeps the KAN-755 Realtime nudge on games for now.
-- 3. The three AFTER behaviours move from games to events (WHEN event_type = 'game'), with the same functions:
--      tr_games_activity_sync     -> events tr_kan947_events_game_activity_sync    (AFTER INSERT OR UPDATE)
--      trg_game_updated_notify    -> events trg_kan947_events_game_updated_notify  (AFTER UPDATE, is_cancelled changed)
--      msg_system_game_cancelled  -> events msg_kan947_events_game_cancelled       (AFTER UPDATE OF is_cancelled, false->true)
--    Every writer, converted or not, writes events (directly, or via kan718_game_event_sync), so each fires exactly
--    once from events; the games triggers are dropped in the same transaction. Their bodies read only columns events
--    also has (id, creator_*, sport_id, area_id, geo_location_id, is_cancelled, created_at, updated_at).
--    The BEFORE behaviours (set host, block frozen, request_id stamp, challenge sport, sport from space) are in the
--    writers through the derive; their games triggers stay until P-d, when no games-first writer is left.
--    trg_games_sync_geo is a no-op for games (fn_sync_geo_fields only writes for profile_locations);
--    trg_kan718_games_series_occurrence reads games.series_id/event_id and events.start_at only (no dropped column);
--    trg_games_touch is overridden by 2a's UPDATE copy. P-d drops those three.
-- 4. rpc_create_game_legacy_v1 / _v2: validations unchanged and in the same order. The events parent is inserted
--    first with every shared field (derive output, request_id translated as kan718_game_event_sync did:
--    events_type_creator_request_id_key -> games_creator_user_request_id_key), then games names only retained
--    columns (id, event_id, game_type, sport_variant_id, venue_space_id, bench_slots, rules, squad_id,
--    allow_spectators, allows_waitlist, sport_specific_data[, price_aed]). Host roster row and return unchanged.
-- Test: supabase/tests/events_p4/kan947_pa_game_create_live_test.sql.

do $pre$
declare
  k record;
begin
  for k in select * from (values
    ('public.rpc_create_game_legacy_v1(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer)', '007929d0ab0f09e94ae415a33a2877e4'),
    ('public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric)', '389b2724eaf777ab4e799f66c2bdcec9'),
    ('public.fn_games_activity_sync()', '4be74137f22e17c5a8efa3171aa80d3b'),
    ('public.trg_game_updated_notify()', '45c97c575b8ad3887d61cecbb72e80bf'),
    ('public.msg_system_game_trg()', 'f97b4a6ddb3542ba282d53f8e4a5e92b')) v(fn, pre)
  loop
    if md5(pg_get_functiondef(to_regprocedure(k.fn))) is distinct from k.pre then
      raise exception 'KAN-947 P-a pre: % absent or drifted', k.fn;
    end if;
  end loop;
  if (select count(*) from pg_trigger where tgrelid = 'public.games'::regclass and tgenabled = 'O'
         and tgname in ('tr_games_activity_sync', 'trg_game_updated_notify', 'msg_system_game_cancelled')) <> 3 then
    raise exception 'KAN-947 P-a pre: the three games AFTER triggers are not all present and enabled';
  end if;
  if to_regprocedure('public.kan947_game_derive(public.events,uuid,uuid,public.events,uuid)') is not null
     or to_regprocedure('public.kan947_games_from_events()') is not null
     or to_regprocedure('public.kan947_events_game_mirror()') is not null then
    raise exception 'KAN-947 P-a pre: kan947 helpers already exist';
  end if;
end
$pre$;

-- 1. derive on the events row ---------------------------------------------------------------------------------------
CREATE FUNCTION public.kan947_game_derive(n public.events, p_venue_space_id uuid, p_sport_variant_id uuid,
                                          o public.events DEFAULT NULL::public.events, p_old_venue_space_id uuid DEFAULT NULL::uuid)
 RETURNS public.events
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_insert          boolean := (o).id IS NULL;
  v_uid             uuid;
  v_sport_id        uuid;
  v_capacity        integer;
  v_req             text;
  v_geo_location_id uuid;
  v_area_id         uuid;
  v_space_found     boolean;
  v_space_venue     uuid;
  v_space_changed   boolean;
  v_venue_changed   boolean;
  v_joining_rule    text;
  v_venue_id        uuid;
  v_geo_id          uuid;
BEGIN
  IF v_insert THEN
    -- trgfn_games_block_frozen
    SELECT user_id INTO v_uid FROM public.profiles WHERE id = n.creator_profile_id;
    PERFORM public.guard_user_not_frozen(v_uid);
    -- trg_fn_games_inherit_sport_from_space
    IF p_venue_space_id IS NOT NULL THEN
      SELECT vs.sport_id, vs.capacity INTO v_sport_id, v_capacity
        FROM public.venue_spaces vs WHERE vs.id = p_venue_space_id;
      n.sport_id := COALESCE(n.sport_id, v_sport_id);
      n.capacity := COALESCE(n.capacity, v_capacity);
    END IF;
    IF n.capacity IS NULL AND p_sport_variant_id IS NOT NULL THEN
      SELECT sv.required_players INTO v_capacity FROM public.sport_variants sv WHERE sv.id = p_sport_variant_id;
      n.capacity := v_capacity;
    END IF;
    -- trg_fn_games_require_challenge_sport
    IF NOT EXISTS (SELECT 1 FROM public.sports s
                    WHERE s.id = n.sport_id AND s.is_challenge_sport = true AND s.is_active = true) THEN
      RAISE EXCEPTION USING errcode = 'P0001', message = 'sport_not_challenge';
    END IF;
    -- trgfn_games_set_host_user
    SELECT user_id INTO v_uid FROM public.profiles WHERE id = n.creator_profile_id;
    IF v_uid IS NULL THEN
      RAISE EXCEPTION USING errcode = 'P0001', message = 'creator_profile_not_found';
    END IF;
    n.creator_user_id := v_uid;
    -- kan611_stamp_request_id
    v_req := nullif(current_setting('thebes.create_request_id', true), '');
    IF v_req IS NOT NULL AND n.request_id IS NULL THEN
      n.request_id := v_req::uuid;
    END IF;
  END IF;

  -- (a) kan713_games_location
  v_space_changed := v_insert OR p_venue_space_id IS DISTINCT FROM p_old_venue_space_id;
  v_venue_changed := v_insert OR n.venue_id IS DISTINCT FROM o.venue_id;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT true, vs.venue_id INTO v_space_found, v_space_venue
      FROM public.venue_spaces vs WHERE vs.id = p_venue_space_id;
    IF v_space_found IS NULL THEN
      IF v_space_changed THEN
        RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan713_space_not_found',
          DETAIL = format('games %s: venue_space_id %s does not exist', n.id, p_venue_space_id);
      END IF;
    ELSIF v_space_venue IS NOT NULL THEN
      IF n.venue_id IS NULL OR (v_space_changed AND NOT v_venue_changed) THEN
        n.venue_id := v_space_venue;
      ELSIF n.venue_id <> v_space_venue AND (v_space_changed OR v_venue_changed) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan713_space_venue_mismatch',
          DETAIL = format('games %s: venue %s is not the venue (%s) of space %s', n.id, n.venue_id, v_space_venue, p_venue_space_id);
      END IF;
    END IF;
  END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id INTO v_geo_location_id, v_area_id
      FROM public.venue_spaces  vs
      JOIN public.venues        v  ON v.id  = vs.venue_id
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE vs.id = p_venue_space_id;
  ELSIF n.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id INTO v_geo_location_id, v_area_id
      FROM public.venues        v
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE v.id = n.venue_id;
  END IF;
  IF v_geo_location_id IS NOT NULL THEN
    n.geo_location_id := v_geo_location_id;
    n.area_id         := v_area_id;
  END IF;

  -- (b) kan713_games_joining
  IF p_venue_space_id IS NOT NULL THEN
    SELECT vs.joining_rule INTO v_joining_rule FROM public.venue_spaces vs WHERE vs.id = p_venue_space_id;
    n.joining_rule := COALESCE(v_joining_rule, 'free');
    IF v_insert THEN
      n.cost_cover := n.joining_rule;
    ELSIF o.joining_rule <> n.joining_rule THEN
      n.cost_cover := n.joining_rule;
    END IF;
  ELSE
    n.joining_rule := 'free';
    IF v_insert THEN n.cost_cover := 'free'; END IF;
  END IF;

  -- (c) kan713_games_venue_geo
  IF p_venue_space_id IS NOT NULL THEN
    SELECT v.id, v.geo_location_id, v.area_id INTO v_venue_id, v_geo_id, v_area_id
      FROM public.venue_spaces vs
      JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = p_venue_space_id;
    n.venue_id        := COALESCE(n.venue_id,        v_venue_id);
    n.geo_location_id := COALESCE(n.geo_location_id, v_geo_id);
    n.area_id         := COALESCE(n.area_id,         v_area_id);
  END IF;

  RETURN n;
END
$function$;

-- 2a. games <- events copy (BEFORE) -------------------------------------------------------------------------------
CREATE FUNCTION public.kan947_games_from_events()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  e public.events;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF pg_trigger_depth() < 2 OR coalesce(current_setting('kan947.mirror', true), '') <> NEW.id::text THEN
      RETURN NEW;     -- not inside kan947_events_game_mirror: a games-first writer, leave its row alone
    END IF;
  END IF;
  SELECT * INTO e FROM public.events WHERE id = coalesce(NEW.event_id, NEW.id) AND event_type = 'game';
  IF NOT FOUND THEN
    RETURN NEW;       -- INSERT by a games-first writer: kan718_game_event_sync inserts the parent afterwards
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

-- 2b. events -> games mirror (AFTER UPDATE on events) ---------------------------------------------------------------
CREATE FUNCTION public.kan947_events_game_mirror()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  PERFORM set_config('kan947.mirror', NEW.id::text, true);
  UPDATE public.games g SET bench_slots = g.bench_slots
   WHERE g.event_id = NEW.id
     AND ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
             g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
             g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill, g.max_skill,
             g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at)
         IS DISTINCT FROM
         ROW(NEW.creator_profile_id, NEW.creator_user_id, NEW.title, NEW.start_at, NEW.end_at, NEW.capacity,
             NEW.listing_visibility, NEW.join_policy, NEW.is_cancelled, NEW.cancelled_at, NEW.cancelled_reason,
             NEW.sport_id, NEW.area_id, NEW.geo_location_id, NEW.venue_id, NEW.min_skill::integer, NEW.max_skill::integer,
             NEW.joining_rule, NEW.cost_cover, NEW.request_id, NEW.created_at, NEW.updated_at);
  PERFORM set_config('kan947.mirror', '', true);
  RETURN NULL;
END
$function$;

REVOKE ALL ON FUNCTION public.kan947_game_derive(public.events,uuid,uuid,public.events,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan947_games_from_events() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan947_events_game_mirror() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_00_kan947_games_from_events BEFORE INSERT ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan947_games_from_events();
CREATE TRIGGER trg_zz_kan947_games_from_events BEFORE UPDATE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan947_games_from_events();
CREATE TRIGGER trg_zz_kan947_events_game_mirror AFTER UPDATE ON public.events
  FOR EACH ROW WHEN (NEW.event_type = 'game') EXECUTE FUNCTION public.kan947_events_game_mirror();

-- 3. AFTER behaviours: games -> events ------------------------------------------------------------------------------
DROP TRIGGER tr_games_activity_sync ON public.games;
DROP TRIGGER trg_game_updated_notify ON public.games;
DROP TRIGGER msg_system_game_cancelled ON public.games;

CREATE TRIGGER tr_kan947_events_game_activity_sync AFTER INSERT OR UPDATE ON public.events
  FOR EACH ROW WHEN (NEW.event_type = 'game') EXECUTE FUNCTION public.fn_games_activity_sync();
CREATE TRIGGER trg_kan947_events_game_updated_notify AFTER UPDATE ON public.events
  FOR EACH ROW WHEN (NEW.event_type = 'game' AND OLD.is_cancelled IS DISTINCT FROM NEW.is_cancelled)
  EXECUTE FUNCTION public.trg_game_updated_notify();
CREATE TRIGGER msg_kan947_events_game_cancelled AFTER UPDATE OF is_cancelled ON public.events
  FOR EACH ROW WHEN (NEW.event_type = 'game' AND OLD.is_cancelled IS NOT TRUE AND NEW.is_cancelled IS TRUE)
  EXECUTE FUNCTION public.msg_system_game_trg();

-- 4. create writers -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_create_game_legacy_v1(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; uid uuid; gid uuid; gtype text;
  v_sport record; v_variant record;
  v_required integer; v_players_per_side integer;
  v_geo_id uuid; v_area_id uuid; v_venue_id uuid;
  v_joining_rule text; v_cost_cover text;
  v_capacity integer; v_rules jsonb;
  v_e public.events;
  v_con text;
BEGIN
  pid := public.choose_actor(p_actor_type);
  -- KAN-440 persona gate (CEO ruling 2026-10-06): player and organiser may create a game;
  -- socialiser and host may not. Also re-asserts that the caller owns the acting profile.
  -- Tests persona_type directly (the profile_type based organiser helper never matches).
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = pid
      AND persona_type IN ('player', 'organiser')
      AND is_active
      AND user_id = public.effective_actor_uid()
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='persona_not_allowed';
  END IF;
  IF p_end_at <= p_start_at THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range'; END IF;
  SELECT * INTO v_sport FROM public.sports WHERE id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport'; END IF;
  IF v_sport.is_challenge_sport IS DISTINCT FROM true THEN RAISE EXCEPTION USING errcode='P0001', message='sport_not_challenge_eligible'; END IF;
  SELECT * INTO v_variant FROM public.sport_variants WHERE id = p_sport_variant_id AND sport_id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport_variant'; END IF;
  v_required := v_variant.required_players;
  v_players_per_side := v_variant.players_per_side;
  IF p_bench_slots < 0 OR p_bench_slots > v_players_per_side THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_bench_slots'; END IF;

  -- Optional player-count overrides (UI-editable Min/Max players)
  IF p_max_players IS NOT NULL AND p_max_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_max_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_min_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_min_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_max_players IS NOT NULL AND p_min_players > p_max_players THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_player_range';
  END IF;
  v_capacity := COALESCE(p_max_players, v_required);
  v_rules := COALESCE(p_rules, '{}'::jsonb);
  IF p_min_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('min_players', p_min_players);
  END IF;
  IF p_max_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('max_players', p_max_players);
  END IF;

  SELECT user_id INTO uid FROM public.profiles WHERE id = pid;
  IF uid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found'; END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, v.area_id, v.id INTO v_geo_id, v_area_id, v_venue_id
      FROM public.venue_spaces vs JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = p_venue_space_id;
  END IF;
  IF v_geo_id IS NULL AND p_geo_location_id IS NOT NULL THEN
    v_geo_id := p_geo_location_id; v_area_id := p_area_id;
  END IF;
  IF v_geo_id IS NULL AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations
     ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)) LIMIT 1;
  END IF;
  IF v_geo_id IS NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations ORDER BY created_at LIMIT 1;
  END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT joining_rule INTO v_joining_rule FROM public.venue_spaces WHERE id = p_venue_space_id;
    v_cost_cover := COALESCE(p_cost_cover, v_joining_rule);
  ELSE
    v_joining_rule := 'free'; v_cost_cover := COALESCE(p_cost_cover, 'free');
  END IF;
  gtype := CASE WHEN p_actor_type = 'organiser' THEN 'hosted' ELSE 'casual' END;
  -- KAN-947: the events parent first, with every shared field; games names only its retained columns.
  v_e.id := gen_random_uuid(); v_e.event_type := 'game';
  v_e.sport_id := p_sport_id; v_e.creator_profile_id := pid; v_e.creator_user_id := uid;
  v_e.venue_id := v_venue_id; v_e.capacity := v_capacity; v_e.joining_rule := v_joining_rule;
  v_e.cost_cover := v_cost_cover; v_e.geo_location_id := v_geo_id; v_e.area_id := COALESCE(v_area_id, p_area_id);
  v_e := public.kan947_game_derive(v_e, p_venue_space_id, p_sport_variant_id, NULL, NULL);
  BEGIN
    INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at,
           capacity, listing_visibility, join_policy, sport_id, area_id, geo_location_id, venue_id,
           min_skill, max_skill, joining_rule, cost_cover, request_id)
    VALUES (v_e.id, 'game', v_e.creator_profile_id, v_e.creator_user_id, p_title, p_start_at, p_end_at,
           v_e.capacity, p_listing_visibility, p_join_policy, v_e.sport_id, v_e.area_id, v_e.geo_location_id,
           v_e.venue_id, p_min_skill::smallint, p_max_skill::smallint, v_e.joining_rule, v_e.cost_cover, v_e.request_id)
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
  INSERT INTO public.games (
    id, event_id, game_type, sport_variant_id, venue_space_id, bench_slots, rules,
    squad_id, allow_spectators, allows_waitlist, sport_specific_data
  ) VALUES (
    v_e.id, v_e.id, gtype, p_sport_variant_id, p_venue_space_id, p_bench_slots, v_rules,
    p_squad_id, p_allow_spectators, p_allows_waitlist, COALESCE(p_sport_specific_data, '{}')
  );
  gid := v_e.id;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (gid, pid, uid, 'host', 'active')
  ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
  RETURN gid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_create_game_legacy_v2(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; uid uuid; gid uuid; gtype text;
  v_sport record; v_variant record;
  v_required integer; v_players_per_side integer;
  v_geo_id uuid; v_area_id uuid; v_venue_id uuid;
  v_joining_rule text; v_cost_cover text;
  v_capacity integer; v_rules jsonb;
  v_e public.events;
  v_con text;
BEGIN
  pid := public.choose_actor(p_actor_type);
  -- KAN-440 persona gate (CEO ruling 2026-10-06): player and organiser may create a game;
  -- socialiser and host may not. Also re-asserts that the caller owns the acting profile.
  -- Tests persona_type directly (the profile_type based organiser helper never matches).
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = pid
      AND (persona_type IN ('player', 'organiser')
           OR (persona_type = 'contributor' AND (
                 (p_actor_type = 'player' AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pid))
              OR (p_actor_type = 'organiser' AND EXISTS (SELECT 1 FROM public.organiser x WHERE x.profile_id = pid)))))
      AND is_active
      AND user_id = public.effective_actor_uid()
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='persona_not_allowed';
  END IF;
  IF p_end_at <= p_start_at THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range'; END IF;
  -- CEO 2026-10-08: a game cannot be created without a price (0 is "Free").
  IF p_price_aed IS NULL OR p_price_aed < 0 THEN RAISE EXCEPTION USING errcode='P0001', message='price_required'; END IF;
  SELECT * INTO v_sport FROM public.sports WHERE id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport'; END IF;
  IF v_sport.is_challenge_sport IS DISTINCT FROM true THEN RAISE EXCEPTION USING errcode='P0001', message='sport_not_challenge_eligible'; END IF;
  SELECT * INTO v_variant FROM public.sport_variants WHERE id = p_sport_variant_id AND sport_id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport_variant'; END IF;
  v_required := v_variant.required_players;
  v_players_per_side := v_variant.players_per_side;
  IF p_bench_slots < 0 OR p_bench_slots > v_players_per_side THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_bench_slots'; END IF;

  -- Optional player-count overrides (UI-editable Min/Max players)
  IF p_max_players IS NOT NULL AND p_max_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_max_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_min_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_min_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_max_players IS NOT NULL AND p_min_players > p_max_players THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_player_range';
  END IF;
  v_capacity := COALESCE(p_max_players, v_required);
  v_rules := COALESCE(p_rules, '{}'::jsonb);
  IF p_min_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('min_players', p_min_players);
  END IF;
  IF p_max_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('max_players', p_max_players);
  END IF;

  SELECT user_id INTO uid FROM public.profiles WHERE id = pid;
  IF uid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found'; END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, v.area_id, v.id INTO v_geo_id, v_area_id, v_venue_id
      FROM public.venue_spaces vs JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = p_venue_space_id;
  END IF;
  IF v_geo_id IS NULL AND p_geo_location_id IS NOT NULL THEN
    v_geo_id := p_geo_location_id; v_area_id := p_area_id;
  END IF;
  IF v_geo_id IS NULL AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations
     ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)) LIMIT 1;
  END IF;
  IF v_geo_id IS NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations ORDER BY created_at LIMIT 1;
  END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT joining_rule INTO v_joining_rule FROM public.venue_spaces WHERE id = p_venue_space_id;
    v_cost_cover := COALESCE(p_cost_cover, v_joining_rule);
  ELSE
    v_joining_rule := 'free'; v_cost_cover := COALESCE(p_cost_cover, 'free');
  END IF;
  gtype := CASE WHEN p_actor_type = 'organiser' THEN 'hosted' ELSE 'casual' END;
  -- KAN-947: the events parent first, with every shared field; games names only its retained columns.
  v_e.id := gen_random_uuid(); v_e.event_type := 'game';
  v_e.sport_id := p_sport_id; v_e.creator_profile_id := pid; v_e.creator_user_id := uid;
  v_e.venue_id := v_venue_id; v_e.capacity := v_capacity; v_e.joining_rule := v_joining_rule;
  v_e.cost_cover := v_cost_cover; v_e.geo_location_id := v_geo_id; v_e.area_id := COALESCE(v_area_id, p_area_id);
  v_e := public.kan947_game_derive(v_e, p_venue_space_id, p_sport_variant_id, NULL, NULL);
  BEGIN
    INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at,
           capacity, listing_visibility, join_policy, sport_id, area_id, geo_location_id, venue_id,
           min_skill, max_skill, joining_rule, cost_cover, request_id)
    VALUES (v_e.id, 'game', v_e.creator_profile_id, v_e.creator_user_id, p_title, p_start_at, p_end_at,
           v_e.capacity, p_listing_visibility, p_join_policy, v_e.sport_id, v_e.area_id, v_e.geo_location_id,
           v_e.venue_id, p_min_skill::smallint, p_max_skill::smallint, v_e.joining_rule, v_e.cost_cover, v_e.request_id)
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
  INSERT INTO public.games (
    id, event_id, game_type, sport_variant_id, venue_space_id, bench_slots, rules,
    squad_id, allow_spectators, allows_waitlist, sport_specific_data, price_aed
  ) VALUES (
    v_e.id, v_e.id, gtype, p_sport_variant_id, p_venue_space_id, p_bench_slots, v_rules,
    p_squad_id, p_allow_spectators, p_allows_waitlist, COALESCE(p_sport_specific_data, '{}'), round(p_price_aed, 2)
  );
  gid := v_e.id;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (gid, pid, uid, 'host', 'active')
  ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
  RETURN gid;
END;
$function$;

do $post$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure::text fn, p.proacl::text acl, p.prosecdef, p.provolatile::text vol,
           array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
      from pg_proc p
     where p.oid in ('public.rpc_create_game_legacy_v1(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer)'::regprocedure,
                     'public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric)'::regprocedure)
  loop
    if r.acl <> '{postgres=X/postgres,service_role=X/postgres}' or r.prosecdef is not true or r.vol <> 'v'
       or r.cfg <> 'search_path=public, pg_temp' or r.own <> 'postgres' then
      raise exception 'KAN-947 P-a post: % attributes drifted: %', r.fn, r;
    end if;
  end loop;
  for r in
    select p.oid::regprocedure::text fn, p.proacl::text acl, p.prosecdef, array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own
      from pg_proc p
     where p.oid in ('public.kan947_game_derive(public.events,uuid,uuid,public.events,uuid)'::regprocedure,
                     'public.kan947_games_from_events()'::regprocedure, 'public.kan947_events_game_mirror()'::regprocedure)
  loop
    if r.acl <> '{postgres=X/postgres}' or r.prosecdef is not false or r.cfg <> 'search_path=""' or r.own <> 'postgres' then
      raise exception 'KAN-947 P-a post: % attributes wrong: %', r.fn, r;
    end if;
  end loop;
  if exists (select 1 from pg_trigger where tgrelid = 'public.games'::regclass
              and tgname in ('tr_games_activity_sync', 'trg_game_updated_notify', 'msg_system_game_cancelled')) then
    raise exception 'KAN-947 P-a post: a moved games trigger is still attached';
  end if;
  if (select count(*) from pg_trigger where tgenabled = 'O' and (
        (tgrelid = 'public.games'::regclass and tgname in ('trg_00_kan947_games_from_events', 'trg_zz_kan947_games_from_events'))
     or (tgrelid = 'public.events'::regclass and tgname in ('trg_zz_kan947_events_game_mirror', 'tr_kan947_events_game_activity_sync',
                                                           'trg_kan947_events_game_updated_notify', 'msg_kan947_events_game_cancelled')))) <> 6 then
    raise exception 'KAN-947 P-a post: the six kan947 triggers are not all attached and enabled';
  end if;
end
$post$;

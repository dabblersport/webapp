-- KAN-712 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Runs AFTER supabase/tests/events_p1/local_harness_kan711.sql and local_seed_kan711.sql, BEFORE KAN-710.
-- Adds the write paths KAN-712 converges, with their REAL signatures, owners (postgres, SECURITY DEFINER) and
-- the ACLs the repo migrations leave them with, so the cutover's generated wrappers and fail-closed scan run
-- against a realistic catalogue.
--
-- Bodies:
--   VERBATIM from the repo (only schema-qualified the same way):
--     rpc_create_game (KAN-611 wrapper, 20261021120200:35-67), rpc_create_meetup (20261021120300:33-65),
--     rpc_update_game (20261008140000:283-351), rpc_reschedule_game (baseline 14986), rpc_cancel_game (11246),
--     rpc_booking_hold_for_game (11148), rpc_challenge_spawn_game (11599), admin_cleanup_user_data (2223),
--     rpc_meetup_cancel (20260915120000:373), rpc_meetup_update (:534), rpc_edit_game_series_occurrence /
--     rpc_edit_game_series_future / rpc_cancel_game_series (20261030130000), fn_generate_game_series_occurrences
--     (20261030140000:33-84), rpc_create_game_series (20261030120000:93-131).
--   SIMPLIFIED stand-ins (no PostGIS, no persona limits, no sport_variants): rpc_create_game_legacy_v2,
--     rpc_create_game_legacy_v1, rpc_create_meetup_legacy_v2, rpc_create_meetup_legacy_v1, rpc_update_game_legacy_v1
--     (the last one IS the baseline body). Each inserts/updates the same legacy columns as the repo body.
--   Helpers stubbed: effective_actor_uid, choose_actor, is_admin(uuid)/is_admin(), is_venue_admin,
--     rpc_meetup_card.
--   trg_meetups_aaa_host_actor_stub: the repo rpc_create_meetup body does not set meetups.host_actor_id (NOT NULL,
--     no default in the repo). Live must fill it some other way that this seat cannot see; the stub fills it from
--     creator_profile_id so local creates run. Recorded in KAN712_CONTRACT.md.

-- Reference rows used by the KAN-712 scenarios. ---------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN persona_type text NOT NULL DEFAULT 'player',
                            ADD COLUMN is_active boolean NOT NULL DEFAULT true;
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-0000000000a3'), ('00000000-0000-0000-0000-0000000000a4');
INSERT INTO public.profiles(id, user_id) VALUES ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a3'),
                                                ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000a4');
CREATE TABLE public.harness_admins (admin_uid uuid PRIMARY KEY);   -- column deliberately not "user_id" (admin_cleanup loop)
INSERT INTO public.harness_admins VALUES ('00000000-0000-0000-0000-0000000000a3');
INSERT INTO public.venues(id, geo_location_id) VALUES ('00000000-0000-0000-0000-00000000ee01', '00000000-0000-0000-0000-0000000000d1');
INSERT INTO public.venue_spaces(id, venue_id, joining_rule) VALUES ('00000000-0000-0000-0000-00000000ee11', '00000000-0000-0000-0000-00000000ee01', 'free');

ALTER TABLE public.game_roster ADD COLUMN profile_id uuid, ADD COLUMN role text DEFAULT 'player',
                               ADD COLUMN status text DEFAULT 'active', ADD COLUMN left_at timestamptz;
CREATE UNIQUE INDEX game_roster_game_profile_key ON public.game_roster (game_id, profile_id);
ALTER TABLE public.meetup_rsvps ADD COLUMN profile_id uuid, ADD COLUMN updated_at timestamptz DEFAULT now();
CREATE UNIQUE INDEX meetup_rsvps_meetup_user_key ON public.meetup_rsvps (meetup_id, user_id);

ALTER TABLE public.game_series
  ADD COLUMN creator_user_id uuid, ADD COLUMN creator_profile_id uuid, ADD COLUMN sport_id uuid,
  ADD COLUMN sport_variant_id uuid, ADD COLUMN venue_id uuid, ADD COLUMN venue_space_id uuid,
  ADD COLUMN geo_location_id uuid, ADD COLUMN area_id uuid, ADD COLUMN title text, ADD COLUMN game_type text DEFAULT 'casual',
  ADD COLUMN capacity integer, ADD COLUMN listing_visibility text DEFAULT 'public', ADD COLUMN join_policy text DEFAULT 'open',
  ADD COLUMN start_time_local time, ADD COLUMN duration_minutes integer, ADD COLUMN rrule text, ADD COLUMN timezone text,
  ADD COLUMN starts_on date, ADD COLUMN ends_on date, ADD COLUMN occurrences_ahead integer DEFAULT 4,
  ADD COLUMN status text NOT NULL DEFAULT 'active', ADD COLUMN created_at timestamptz DEFAULT now(),
  ADD COLUMN updated_at timestamptz DEFAULT now();
-- The seeded series f1 (games 04/05, January 2026) is ended so the generator leaves it alone.
UPDATE public.game_series SET status = 'ended', creator_user_id = '00000000-0000-0000-0000-0000000000a2',
       creator_profile_id = '00000000-0000-0000-0000-0000000000b2' WHERE id = '00000000-0000-0000-0000-0000000000f1';

CREATE TABLE public.venue_bookings (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), venue_space_id uuid, starts_at timestamptz,
  ends_at timestamptz, source_type text, source_id uuid, status text, created_by uuid);
CREATE TABLE public.challenges (id uuid PRIMARY KEY, owner_user_id uuid, owner_profile_id uuid, title text);
CREATE TABLE public.challenge_fixtures (id uuid PRIMARY KEY, challenge_id uuid, game_id uuid, scheduled_at timestamptz);
INSERT INTO public.challenges VALUES ('00000000-0000-0000-0000-00000000cc01', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'Cup');
INSERT INTO public.challenge_fixtures VALUES ('00000000-0000-0000-0000-00000000cf01', '00000000-0000-0000-0000-00000000cc01', NULL, NULL);
CREATE TABLE public.posts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), author_profile_id uuid);
REVOKE ALL ON public.harness_admins, public.venue_bookings, public.challenges, public.challenge_fixtures, public.posts FROM anon, authenticated;

-- Helpers ------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.effective_actor_uid() RETURNS uuid LANGUAGE sql STABLE SET search_path TO 'public' AS $$ SELECT auth.uid() $$;
CREATE FUNCTION public.choose_actor(p_actor_type text) RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v uuid; BEGIN
  SELECT id INTO v FROM public.profiles WHERE user_id = public.effective_actor_uid() AND is_active
     AND (p_actor_type IS NULL OR persona_type = p_actor_type) ORDER BY id LIMIT 1;
  IF v IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'no_profile_of_requested_type'; END IF;
  RETURN v; END $$;
CREATE FUNCTION public.is_admin(p_uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS
$$ SELECT EXISTS (SELECT 1 FROM public.harness_admins WHERE admin_uid = p_uid) $$;
CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS
$$ SELECT public.is_admin(auth.uid()) $$;
CREATE FUNCTION public.is_venue_admin(p_uid uuid, p_venue uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
CREATE FUNCTION public.rpc_meetup_card(p_meetup_id uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS
$$ SELECT jsonb_build_object('id', m.id, 'title', m.title, 'start_at', m.start_at, 'capacity', m.capacity) FROM public.meetups m WHERE m.id = p_meetup_id $$;

CREATE FUNCTION public.harness_host_actor_stub() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.host_actor_id := coalesce(NEW.host_actor_id, NEW.creator_profile_id); RETURN NEW; END $$;
CREATE TRIGGER trg_meetups_aaa_host_actor_stub BEFORE INSERT ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.harness_host_actor_stub();

-- Create paths (stay UNWRAPPED; the guard routes their INSERT) --------------------------------------------------
CREATE FUNCTION public.rpc_create_game_legacy_v2(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := public.effective_actor_uid(); v_pid uuid; gid uuid; v_paid boolean := coalesce(p_price_aed, 0) > 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;
  v_pid := public.choose_actor(p_actor_type);
  IF p_start_at IS NULL OR p_end_at IS NULL OR p_end_at <= p_start_at THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'invalid_time_range';
  END IF;
  INSERT INTO public.games (game_type, title, creator_profile_id, creator_user_id, venue_space_id, start_at, end_at, capacity,
         listing_visibility, join_policy, allow_spectators, min_skill, max_skill, rules, squad_id, sport_specific_data,
         allows_waitlist, sport_id, geo_location_id, area_id, sport_variant_id, bench_slots, joining_rule, cost_cover, price_aed)
  VALUES ('casual', p_title, v_pid, v_uid, p_venue_space_id, p_start_at, p_end_at, coalesce(p_max_players, 10),
         p_listing_visibility, p_join_policy, p_allow_spectators, p_min_skill, p_max_skill, coalesce(p_rules, '{}'::jsonb),
         p_squad_id, coalesce(p_sport_specific_data, '{}'::jsonb), p_allows_waitlist, p_sport_id, p_geo_location_id, p_area_id,
         p_sport_variant_id, p_bench_slots, CASE WHEN v_paid THEN 'paid' ELSE 'free' END,
         CASE WHEN v_paid THEN coalesce(p_cost_cover, 'paid') ELSE 'free' END, p_price_aed)
  RETURNING id INTO gid;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (gid, v_pid, v_uid, 'host', 'active')
  ON CONFLICT (game_id, profile_id) DO NOTHING;
  RETURN gid;
END $function$;

CREATE FUNCTION public.rpc_create_game_legacy_v1(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE gid uuid;
BEGIN
  INSERT INTO public.games (title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
         sport_id, geo_location_id, area_id)
  VALUES (p_title, public.choose_actor(p_actor_type), public.effective_actor_uid(), p_start_at, p_end_at, coalesce(p_max_players, 10),
         p_listing_visibility, p_join_policy, p_sport_id, p_geo_location_id, p_area_id)
  RETURNING id INTO gid;
  RETURN gid;
END $function$;

-- VERBATIM 20261021120200:35-67
CREATE FUNCTION public.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; gid uuid; v_constraint text;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  END IF;
  -- Request-id lookup FIRST, before every guard and limit. Only the creator is ever served the row.
  v_uid := public.effective_actor_uid();
  IF v_uid IS NOT NULL THEN
    SELECT g.id INTO gid FROM public.games g WHERE g.creator_user_id = v_uid AND g.request_id = p_request_id;
    IF gid IS NOT NULL THEN RETURN gid; END IF;
  END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  BEGIN
    gid := public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM set_config('thebes.create_request_id', '', true);
    IF v_constraint IS DISTINCT FROM 'games_creator_user_request_id_key' THEN RAISE; END IF;
    SELECT g.id INTO gid FROM public.games g WHERE g.creator_user_id = v_uid AND g.request_id = p_request_id;
    IF gid IS NULL THEN RAISE; END IF;
    RETURN gid;
  END;
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN gid;
END;
$function$;

CREATE FUNCTION public.rpc_create_meetup_legacy_v2(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := public.effective_actor_uid(); v_pid uuid; mid uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'auth_required'; END IF;
  v_pid := public.choose_actor(p_actor_type);
  IF p_start_at IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'start_required'; END IF;
  INSERT INTO public.meetups (creator_profile_id, creator_user_id, title, description, vibe_key, listing_visibility, rsvp_policy,
         capacity, start_at, end_at, meta, geo_location_id, sport_id, area_id, venue_id, min_skill, max_skill, members_only,
         joining_rule, cost_cover, location_name, is_indoor)
  VALUES (v_pid, v_uid, p_title, p_description, p_vibe_key, p_listing_visibility, p_rsvp_policy, p_capacity, p_start_at, p_end_at,
         coalesce(p_meta, '{}'::jsonb), p_geo_location_id, p_sport_id, p_area_id, p_venue_id, p_min_skill, p_max_skill,
         p_members_only, CASE WHEN p_members_only THEN 'members_only' ELSE 'free' END,
         CASE WHEN p_members_only THEN 'members_only' ELSE 'free' END, p_location_name, p_is_indoor)
  RETURNING id INTO mid;
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (mid, v_uid, v_pid, 'going')
  ON CONFLICT (meetup_id, user_id) DO UPDATE SET status = 'going', updated_at = now();
  RETURN mid;
END $function$;

CREATE FUNCTION public.rpc_create_meetup_legacy_v1(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE mid uuid;
BEGIN
  INSERT INTO public.meetups (creator_profile_id, creator_user_id, title, start_at, end_at, capacity, listing_visibility, rsvp_policy)
  VALUES (public.choose_actor(p_actor_type), public.effective_actor_uid(), p_title, p_start_at, p_end_at, p_capacity,
         p_listing_visibility, p_rsvp_policy)
  RETURNING id INTO mid;
  RETURN mid;
END $function$;

-- VERBATIM 20261021120300:33-65
CREATE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; mid uuid; v_constraint text;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  END IF;
  -- Request-id lookup FIRST, before every guard and limit. Only the creator is ever served the row.
  v_uid := public.effective_actor_uid();
  IF v_uid IS NOT NULL THEN
    SELECT m.id INTO mid FROM public.meetups m WHERE m.creator_user_id = v_uid AND m.request_id = p_request_id;
    IF mid IS NOT NULL THEN RETURN mid; END IF;
  END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  BEGIN
    mid := public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM set_config('thebes.create_request_id', '', true);
    IF v_constraint IS DISTINCT FROM 'meetups_creator_user_request_id_key' THEN RAISE; END IF;
    SELECT m.id INTO mid FROM public.meetups m WHERE m.creator_user_id = v_uid AND m.request_id = p_request_id;
    IF mid IS NULL THEN RAISE; END IF;
    RETURN mid;
  END;
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN mid;
END;
$function$;

-- VERBATIM baseline 11599 (pre-existing defect: 'hidden'/'squad' and no sport/geo/area; it can never succeed)
CREATE FUNCTION public.rpc_challenge_spawn_game(p_fixture_id uuid, p_start_at timestamp with time zone, p_venue_space_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  f record; c record; gid uuid; title text;
BEGIN
  SELECT * INTO f FROM public.challenge_fixtures WHERE id = p_fixture_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='fixture_not_found'; END IF;

  SELECT * INTO c FROM public.challenges WHERE id = f.challenge_id;
  IF c.owner_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_owner';
  END IF;

  title := COALESCE(c.title, 'Challenge') || ' — Fixture ' || f.id::text;

  INSERT INTO public.games(
    game_type, title,
    creator_profile_id, creator_user_id,
    start_at, end_at, capacity,
    listing_visibility, join_policy,
    venue_space_id, squad_id
  )
  VALUES (
    'hosted', title,
    c.owner_profile_id, c.owner_user_id,
    p_start_at, p_start_at + interval '90 minutes', 22,
    'hidden', 'squad',
    p_venue_space_id, null
  )
  RETURNING id INTO gid;

  UPDATE public.challenge_fixtures
  SET game_id = gid, scheduled_at = p_start_at
  WHERE id = p_fixture_id;

  PERFORM public.emit_event('challenge.fixture_spawned', 'challenge', f.challenge_id, auth.uid(),
    jsonb_build_object('fixture_id', p_fixture_id, 'game_id', gid));

  RETURN gid;
END;
$$;

-- VERBATIM baseline 2223
CREATE FUNCTION public.admin_cleanup_user_data(p_user_id uuid, p_dry_run boolean DEFAULT true) RETURNS TABLE(affected_table text, affected_column text, rows_affected bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  r           record;
  v_profile_id uuid;
  v_sql       text;
  v_count     bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin privileges required';
  END IF;

  PERFORM set_config('app.admin_cleanup', 'on', true);

  SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id;

  IF v_profile_id IS NULL THEN
    affected_table := 'profiles'; affected_column := 'user_id'; rows_affected := 0;
    RETURN NEXT; RETURN;
  END IF;

  -- Games
  IF NOT p_dry_run THEN
    DELETE FROM public.games WHERE creator_profile_id = v_profile_id;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count > 0 THEN
    affected_table := 'games'; affected_column := 'creator_profile_id'; rows_affected := v_count;
    RETURN NEXT;
  END IF;

  -- Posts
  IF NOT p_dry_run THEN
    DELETE FROM public.posts WHERE author_profile_id = v_profile_id;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count > 0 THEN
    affected_table := 'posts'; affected_column := 'author_profile_id'; rows_affected := v_count;
    RETURN NEXT;
  END IF;

  FOR r IN
    SELECT c.table_schema, c.table_name, c.column_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE c.table_schema = 'public'
      AND c.column_name IN ('user_id', 'profile_id')
      AND t.table_type = 'BASE TABLE'
      AND c.table_name NOT IN ('profiles', 'games', 'posts')
  LOOP
    v_sql := format('SELECT count(*) FROM %I.%I WHERE %I = $1',
      r.table_schema, r.table_name, r.column_name);

    EXECUTE v_sql INTO v_count
      USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;

    IF v_count > 0 THEN
      IF NOT p_dry_run THEN
        v_sql := format('DELETE FROM %I.%I WHERE %I = $1',
          r.table_schema, r.table_name, r.column_name);
        EXECUTE v_sql
          USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;
      END IF;
      affected_table := r.table_name; affected_column := r.column_name; rows_affected := v_count;
      RETURN NEXT;
    END IF;
  END LOOP;

  IF NOT p_dry_run THEN
    DELETE FROM public.profiles WHERE id = v_profile_id;
  END IF;
  affected_table := 'profiles'; affected_column := 'id'; rows_affected := 1;
  RETURN NEXT;
END;
$_$;

-- Update paths (WRAPPED by the cutover) ---------------------------------------------------------------------
-- VERBATIM 20261008140000:283-351
CREATE FUNCTION public.rpc_update_game(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roster_count integer;
begin
  if p_end_at <= p_start_at then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;
  if p_price_aed is null or p_price_aed < 0 then
    raise exception using errcode='P0001', message='price_required';
  end if;
  if p_max_players is not null and p_max_players < 1 then
    raise exception using errcode='P0001', message='invalid_max_players';
  end if;
  if p_min_players is not null and p_min_players < 1 then
    raise exception using errcode='P0001', message='invalid_min_players';
  end if;
  if p_min_players is not null and p_max_players is not null
     and p_min_players > p_max_players then
    raise exception using errcode='P0001', message='invalid_player_range';
  end if;

  select count(*) into v_roster_count
  from public.game_roster
  where game_id = p_game_id and status = 'active';

  update public.games g
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), g.title),
      venue_space_id     = case
                             when p_clear_venue then null
                             else coalesce(p_venue_space_id, g.venue_space_id)
                           end,
      listing_visibility = coalesce(p_listing_visibility, g.listing_visibility),
      join_policy        = coalesce(p_join_policy, g.join_policy),
      allow_spectators   = coalesce(p_allow_spectators, g.allow_spectators),
      allows_waitlist    = coalesce(p_allows_waitlist, g.allows_waitlist),
      min_skill          = case when p_clear_skill then null
                                else coalesce(p_min_skill, g.min_skill) end,
      max_skill          = case when p_clear_skill then null
                                else coalesce(p_max_skill, g.max_skill) end,
      capacity           = greatest(
                             coalesce(p_max_players, g.capacity),
                             v_roster_count
                           ),
      rules              = coalesce(p_rules, g.rules, '{}'::jsonb)
                           || case when p_min_players is not null
                                then jsonb_build_object('min_players', p_min_players)
                                else '{}'::jsonb end
                           || case when p_max_players is not null
                                then jsonb_build_object('max_players', p_max_players)
                                else '{}'::jsonb end,
      price_aed          = round(p_price_aed, 2)
  where g.id = p_game_id
    and g.is_cancelled = false
    and g.end_at > now()
    and (g.creator_user_id = auth.uid() or public.is_admin(auth.uid()));

  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;

  return 'updated';
end$function$;

-- Baseline rpc_update_game body (renamed legacy_v1 by 20261008140000; service_role only).
CREATE FUNCTION public.rpc_update_game_legacy_v1(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer)
 RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
begin
  if p_end_at <= p_start_at then raise exception using errcode='P0001', message='invalid_time_range'; end if;
  update public.games g
     set start_at = p_start_at, end_at = p_end_at, title = coalesce(nullif(p_title, ''), g.title),
         listing_visibility = coalesce(p_listing_visibility, g.listing_visibility),
         join_policy = coalesce(p_join_policy, g.join_policy),
         capacity = coalesce(p_max_players, g.capacity)
   where g.id = p_game_id and (g.creator_user_id = auth.uid() or public.is_admin(auth.uid()));
  if not found then raise exception using errcode='P0001', message='not_host_or_not_found'; end if;
  return 'updated';
end$function$;

-- VERBATIM baseline 14986
CREATE FUNCTION public.rpc_reschedule_game(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF p_end_at <= p_start_at THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range';
  END IF;
  UPDATE public.games
  SET start_at = p_start_at, end_at = p_end_at
  WHERE id = p_game_id
    AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()));
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'rescheduled';
END$$;

-- VERBATIM baseline 11246
CREATE FUNCTION public.rpc_cancel_game(p_game_id uuid, p_reason text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  UPDATE public.games
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_game_id
    AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()));
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'cancelled';
END$$;

-- VERBATIM baseline 11148
CREATE FUNCTION public.rpc_booking_hold_for_game(p_game_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  g   record;
  vid uuid;
  bid uuid;
BEGIN
  SELECT * INTO g FROM public.games WHERE id = p_game_id;
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

  UPDATE public.games SET venue_space_id = p_space_id WHERE id = p_game_id;

  RETURN bid;
END;
$$;

-- VERBATIM 20260915120000:373-398
CREATE FUNCTION public.rpc_meetup_cancel(p_meetup_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  if not exists (
    select 1 from public.meetups m
    where m.id = p_meetup_id
      and (m.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
  ) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  update public.meetups
     set is_cancelled = true, updated_at = now()
   where id = p_meetup_id and is_cancelled = false;
  if found then
    perform public.emit_event('meetup.cancelled','meetup', p_meetup_id, auth.uid(), '{}');
  end if;
  return 'ok';
end;
$function$;

-- VERBATIM 20260915120000:534-615
CREATE FUNCTION public.rpc_meetup_update(p_meetup_id uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_location_name text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me        uuid := auth.uid();
  m         public.meetups%rowtype;
  v_start   timestamptz;
  v_end     timestamptz;
  v_going   integer;
  v_changed jsonb := '[]'::jsonb;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select * into m from public.meetups where id = p_meetup_id for update;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if m.creator_user_id <> me then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if m.is_cancelled then
    raise exception using errcode='P0001', message='meetup_cancelled';
  end if;

  if p_title is not null then
    if char_length(trim(p_title)) < 3 or char_length(trim(p_title)) > 80 then
      raise exception using errcode='P0001', message='title_invalid';
    end if;
  end if;

  if p_location_name is not null and trim(p_location_name) = '' then
    raise exception using errcode='P0001', message='location_name_required';
  end if;

  v_start := coalesce(p_start_at, m.start_at);
  v_end   := coalesce(p_end_at, m.end_at);
  if v_end is not null and v_end <= v_start then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;

  if p_capacity is not null then
    if p_capacity <= 0 then
      raise exception using errcode='P0001', message='invalid_capacity';
    end if;
    select count(*)::int into v_going
      from public.meetup_rsvps r
     where r.meetup_id = p_meetup_id and r.status = 'going';
    if p_capacity < v_going then
      raise exception using errcode='P0001', message='capacity_below_going_count';
    end if;
  end if;

  if p_title         is not null then v_changed := v_changed || to_jsonb('title'::text); end if;
  if p_description   is not null then v_changed := v_changed || to_jsonb('description'::text); end if;
  if p_start_at      is not null then v_changed := v_changed || to_jsonb('start_at'::text); end if;
  if p_end_at        is not null then v_changed := v_changed || to_jsonb('end_at'::text); end if;
  if p_location_name is not null then v_changed := v_changed || to_jsonb('location_name'::text); end if;
  if p_capacity      is not null then v_changed := v_changed || to_jsonb('capacity'::text); end if;

  update public.meetups
     set title         = coalesce(p_title, title),
         description   = coalesce(p_description, description),
         start_at      = v_start,
         end_at        = v_end,
         location_name = coalesce(p_location_name, location_name),
         capacity      = coalesce(p_capacity, capacity),
         updated_at    = now()
   where id = p_meetup_id;

  perform public.emit_event('meetup.updated','meetup', p_meetup_id, me,
                            jsonb_build_object('fields', v_changed));

  return public.rpc_meetup_card(p_meetup_id);
end;
$function$;

-- Series paths. VERBATIM 20261030140000:33-84 (generator), 20261030120000:93-131 (series create),
-- 20261030130000:35-200 (occurrence edit, future edit, series cancel).
CREATE OR REPLACE FUNCTION public.fn_generate_game_series_occurrences(p_series_id uuid DEFAULT NULL)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_persona text; v_step int; v_n int; v_day date; v_start timestamptz; v_end timestamptz;
  v_future int; v_created int := 0; v_prev_sub text; v_gid uuid;
BEGIN
  FOR s IN
    SELECT * FROM public.game_series
     WHERE status = 'active' AND (p_series_id IS NULL OR id = p_series_id)
     ORDER BY id
       FOR UPDATE   -- serialises two generators on the same series
  LOOP
    SELECT persona_type INTO v_persona FROM public.profiles WHERE id = s.creator_profile_id;
    v_step := CASE WHEN s.rrule LIKE '%INTERVAL=2%' THEN 14 ELSE 7 END;

    SELECT count(*) INTO v_future FROM public.games g
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
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.games g
                             WHERE g.series_id = s.id AND NOT COALESCE(g.is_cancelled, false)
                               AND (g.start_at AT TIME ZONE s.timezone)::date = v_day);
      -- Cancelled rows keep their (series_id, start_at) slot in the unique index; never re-create them.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.games g WHERE g.series_id = s.id AND g.start_at = v_start);

      v_prev_sub := current_setting('request.jwt.claim.sub', true);
      PERFORM set_config('request.jwt.claim.sub', s.creator_user_id::text, true);
      v_gid := public.rpc_create_game(
        v_persona, s.sport_id, s.sport_variant_id, s.title, s.venue_space_id, v_start, v_end, 0,
        s.listing_visibility, s.join_policy, NULL, NULL, NULL, NULL, false, false, NULL, NULL,
        s.geo_location_id, s.area_id, NULL, NULL, NULL, s.capacity, 0::numeric, NULL);
      PERFORM set_config('request.jwt.claim.sub', COALESCE(v_prev_sub, ''), true);
      UPDATE public.games SET series_id = s.id WHERE id = v_gid;
      v_future := v_future + 1;
      v_created := v_created + 1;
    END LOOP;
  END LOOP;
  RETURN v_created;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_create_game_series(
  p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_geo_location_id uuid, p_area_id uuid,
  p_starts_on date, p_start_time_local time, p_duration_minutes integer, p_timezone text, p_frequency text,
  p_capacity integer, p_title text DEFAULT NULL, p_venue_space_id uuid DEFAULT NULL, p_ends_on date DEFAULT NULL,
  p_listing_visibility text DEFAULT 'public', p_join_policy text DEFAULT 'open',
  p_occurrences_ahead integer DEFAULT 4, p_price_aed numeric DEFAULT 0)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; v_pid uuid; v_sid uuid; v_rrule text;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;
  v_pid := public.choose_actor(p_actor_type);   -- raises no_profile_of_requested_type
  IF COALESCE(p_price_aed, 0) <> 0 THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_paid_not_supported';
  END IF;
  v_rrule := CASE p_frequency WHEN 'weekly' THEN 'FREQ=WEEKLY' WHEN 'biweekly' THEN 'FREQ=WEEKLY;INTERVAL=2'
             ELSE NULL END;
  IF v_rrule IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'series_frequency_invalid'; END IF;
  IF p_starts_on IS NULL OR p_start_time_local IS NULL OR p_duration_minutes IS NULL OR p_timezone IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_required';
  END IF;

  INSERT INTO public.game_series (creator_user_id, creator_profile_id, sport_id, sport_variant_id, venue_space_id,
         geo_location_id, area_id, title, capacity, listing_visibility, join_policy, start_time_local,
         duration_minutes, rrule, timezone, starts_on, ends_on, occurrences_ahead)
  VALUES (v_uid, v_pid, p_sport_id, p_sport_variant_id, p_venue_space_id, p_geo_location_id, p_area_id, p_title,
          p_capacity, p_listing_visibility, p_join_policy, p_start_time_local, p_duration_minutes, v_rrule,
          p_timezone, p_starts_on, p_ends_on, p_occurrences_ahead)
  RETURNING id INTO v_sid;

  PERFORM public.fn_generate_game_series_occurrences(v_sid);
  RETURN v_sid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_occurrence(
  p_game_id uuid, p_title text DEFAULT NULL, p_start_at timestamptz DEFAULT NULL, p_end_at timestamptz DEFAULT NULL,
  p_capacity integer DEFAULT NULL, p_venue_space_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; g public.games%ROWTYPE; v_players int; v_start timestamptz; v_end timestamptz;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO g FROM public.games WHERE id = p_game_id AND series_id IS NOT NULL AND creator_user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;
  IF g.is_cancelled OR g.start_at <= now() THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_not_editable';
  END IF;

  v_start := COALESCE(p_start_at, g.start_at);
  v_end := COALESCE(p_end_at, v_start + (g.end_at - g.start_at));
  IF v_start <= now() OR v_end <= v_start THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_invalid';
  END IF;
  IF p_capacity IS NOT NULL THEN
    SELECT count(*) INTO v_players FROM public.game_roster r
     WHERE r.game_id = g.id AND r.status = 'active' AND r.role IN ('player', 'sub');
    IF p_capacity < 2 OR p_capacity > 64 OR p_capacity < v_players THEN
      RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_capacity_invalid';
    END IF;
  END IF;

  BEGIN
    UPDATE public.games
       SET title = COALESCE(p_title, title), start_at = v_start, end_at = v_end,
           capacity = COALESCE(p_capacity, capacity), venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
           updated_at = now()
     WHERE id = g.id;   -- series_id deliberately not in the SET list (T-099)
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_taken';
  END;

  RETURN jsonb_build_object('game_id', g.id, 'series_id', g.series_id);
END;
$function$;

-- 2. Edit ALL FUTURE occurrences: update the template, then apply it in place to future, non-cancelled, unjoined rows.
-- p_ends_on NULL = unchanged; p_clear_ends_on = true sets it to NULL (runs until ended). Unjoined future rows that now fall
-- after ends_on are cancelled through rpc_cancel_game (no player, so nobody is notified). Joined rows are listed, not changed.
CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_future(
  p_series_id uuid, p_title text DEFAULT NULL, p_capacity integer DEFAULT NULL, p_start_time_local time DEFAULT NULL,
  p_duration_minutes integer DEFAULT NULL, p_venue_space_id uuid DEFAULT NULL, p_ends_on date DEFAULT NULL,
  p_clear_ends_on boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_updated int := 0; v_cancelled int := 0;
  v_kept uuid[] := '{}'; v_time_changed boolean; v_topup int := 0; v_start timestamptz;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO s FROM public.game_series WHERE id = p_series_id AND creator_user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;
  IF s.status <> 'active' THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'series_not_active'; END IF;
  IF p_capacity IS NOT NULL AND (p_capacity < 2 OR p_capacity > 64) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_capacity_invalid';
  END IF;
  IF p_duration_minutes IS NOT NULL AND (p_duration_minutes <= 0 OR p_duration_minutes > 1440) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_invalid';
  END IF;
  IF p_ends_on IS NOT NULL AND p_ends_on < s.starts_on THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_invalid';
  END IF;

  v_time_changed := (p_start_time_local IS NOT NULL AND p_start_time_local <> s.start_time_local)
                 OR (p_duration_minutes IS NOT NULL AND p_duration_minutes <> s.duration_minutes);

  UPDATE public.game_series
     SET title = COALESCE(p_title, title), capacity = COALESCE(p_capacity, capacity),
         start_time_local = COALESCE(p_start_time_local, start_time_local),
         duration_minutes = COALESCE(p_duration_minutes, duration_minutes),
         venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
         ends_on = CASE WHEN p_clear_ends_on THEN NULL ELSE COALESCE(p_ends_on, ends_on) END,
         updated_at = now()
   WHERE id = s.id
   RETURNING * INTO s;

  FOR g IN
    SELECT id, start_at,
           EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS has_players
      FROM public.games
     WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false)
     ORDER BY start_at
       FOR UPDATE
  LOOP
    IF g.has_players THEN
      v_kept := v_kept || g.id;   -- never rewritten silently; returned to the client
    ELSIF s.ends_on IS NOT NULL AND (g.start_at AT TIME ZONE s.timezone)::date > s.ends_on THEN
      PERFORM public.rpc_cancel_game(g.id, 'series_ended_earlier');
      v_cancelled := v_cancelled + 1;
    ELSE
      v_start := ((g.start_at AT TIME ZONE s.timezone)::date + s.start_time_local) AT TIME ZONE s.timezone;
      UPDATE public.games
         SET title = s.title, capacity = s.capacity, venue_space_id = s.venue_space_id,
             start_at = v_start, end_at = v_start + make_interval(mins => s.duration_minutes), updated_at = now()
       WHERE id = g.id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  -- Top up the rolling window. Skipped when the time of day changed and a joined row kept its old time, because the
  -- generator matches existing rows by exact start_at and would add a second game on that day.
  IF NOT (v_time_changed AND cardinality(v_kept) > 0) THEN
    v_topup := public.fn_generate_game_series_occurrences(s.id);
  END IF;

  RETURN jsonb_build_object(
    'series_id', s.id, 'updated', v_updated, 'cancelled_after_end_date', v_cancelled, 'created', v_topup,
    'topup_skipped', (v_time_changed AND cardinality(v_kept) > 0),
    'kept_with_players', to_jsonb(v_kept));
END;
$function$;

-- 3. Cancel the whole series. status -> 'ended' FIRST (so the generator stops), then each future non-cancelled
-- occurrence goes through rpc_cancel_game, whose AFTER UPDATE trigger notifies every joined player. Past rows untouched.
CREATE OR REPLACE FUNCTION public.rpc_cancel_game_series(p_series_id uuid, p_reason text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_cancelled int := 0; v_players int := 0; v_past int;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO s FROM public.game_series WHERE id = p_series_id AND creator_user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;

  UPDATE public.game_series SET status = 'ended', updated_at = now() WHERE id = s.id;

  FOR g IN
    SELECT id, (SELECT count(DISTINCT r.user_id) FROM public.game_roster r
                 WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS players
      FROM public.games
     WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false)
     ORDER BY start_at
       FOR UPDATE
  LOOP
    PERFORM public.rpc_cancel_game(g.id, COALESCE(p_reason, 'series_cancelled'));
    v_cancelled := v_cancelled + 1;
    v_players := v_players + g.players;
  END LOOP;

  SELECT count(*) INTO v_past FROM public.games WHERE series_id = s.id AND start_at <= now();

  RETURN jsonb_build_object('series_id', s.id, 'status', 'ended', 'cancelled', v_cancelled,
                            'player_notifications', v_players, 'past_kept', v_past);
END;
$function$;

-- ACLs as the repo leaves them (the harness default privileges grant EXECUTE to anon/authenticated/
-- service_role and PUBLIC keeps its default, so every function is reset first). ---------------------------
DO $$
DECLARE f record;
BEGIN
  FOR f IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
            WHERE p.pronamespace = 'public'::regnamespace
              AND p.proname IN ('effective_actor_uid','choose_actor','is_admin','is_venue_admin','rpc_meetup_card',
                'harness_host_actor_stub','rpc_create_game_legacy_v2','rpc_create_game_legacy_v1','rpc_create_game',
                'rpc_create_meetup_legacy_v2','rpc_create_meetup_legacy_v1','rpc_create_meetup','rpc_challenge_spawn_game',
                'admin_cleanup_user_data','rpc_update_game','rpc_update_game_legacy_v1','rpc_reschedule_game',
                'rpc_cancel_game','rpc_booking_hold_for_game','rpc_meetup_cancel','rpc_meetup_update',
                'fn_generate_game_series_occurrences','rpc_create_game_series','rpc_edit_game_series_occurrence',
                'rpc_edit_game_series_future','rpc_cancel_game_series') LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO postgres', f.sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role', f.sig);
  END LOOP;
END $$;
-- helpers: callable by the API roles
GRANT EXECUTE ON FUNCTION public.effective_actor_uid(), public.choose_actor(text), public.is_admin(uuid), public.is_admin(),
  public.is_venue_admin(uuid, uuid), public.rpc_meetup_card(uuid) TO anon, authenticated, service_role;
-- authenticated + service_role (KAN-611 wrappers, 20261008140000 rpc_update_game, hardening meetup RPCs, series RPCs)
GRANT EXECUTE ON FUNCTION
  public.rpc_create_game(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid),
  public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid),
  public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric),
  public.rpc_meetup_cancel(uuid),
  public.rpc_meetup_update(uuid,text,text,timestamptz,timestamptz,text,integer),
  public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time,integer,text,text,integer,text,uuid,date,text,text,integer,numeric),
  public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid),
  public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean),
  public.rpc_cancel_game_series(uuid,text)
  TO authenticated, service_role;
-- baseline grants never narrowed: anon, authenticated, service_role
GRANT EXECUTE ON FUNCTION public.rpc_reschedule_game(uuid,timestamptz,timestamptz), public.rpc_cancel_game(uuid,text),
  public.rpc_booking_hold_for_game(uuid,uuid,timestamptz,timestamptz), public.rpc_challenge_spawn_game(uuid,timestamptz,uuid),
  public.admin_cleanup_user_data(uuid,boolean) TO anon, authenticated, service_role;
-- service_role only: legacy_v1/v2 bodies, rpc_update_game_legacy_v1 (20261008180000), generator (20261030140000)
GRANT EXECUTE ON FUNCTION
  public.rpc_create_game_legacy_v1(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer),
  public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamptz,timestamptz,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric),
  public.rpc_create_meetup_legacy_v1(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb),
  public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamptz,timestamptz,integer,text,text,boolean,integer,integer,text,jsonb,boolean),
  public.rpc_update_game_legacy_v1(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer),
  public.fn_generate_game_series_occurrences(uuid)
  TO service_role;

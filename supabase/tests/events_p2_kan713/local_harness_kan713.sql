-- KAN-713 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Load order (supabase/tests/events_p2_kan713/KAN713_CONTRACT.md, "Local run"):
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   THIS FILE, KAN-710, KAN-711 (+ CALL kan711_events_backfill_run + kan711_events_validate_links),
--   KAN-712 stage A + B, then (new database only) the two KAN-713 migrations.
--
-- What it adds, so the access helpers, policies and location triggers KAN-713 converts actually execute:
--   * the reference tables those helpers read, with the columns from baseline 20260829080500
--     (game_invites 22735, game_join_requests 22750, game_link_tokens 22765, game_waitlist 22851,
--     meetup_attendees 23019, meetup_invites 23036, meetup_link_tokens 23051, profile_follows 23723,
--     sport_variants 24444, squad_members 24588, user_blocks 24744, user_freezes 24774);
--   * public.friendships (user_id, peer_user_id, status): read by are_synced (baseline 3107) but its DDL is
--     not in the repo migrations. HARNESS ASSUMPTION: shape inferred from are_synced; SELECT granted to the
--     API roles so the unchanged invoker helper can run. Identical before and after KAN-713.
--   * EVERY helper / trigger function KAN-713 reads, replaces or disables, VERBATIM (byte for byte, extracted
--     by script) from the file:line printed above each one, owned by postgres, with the ACL the repo leaves.
--     md5(prosrc) of the replaced ones is what the KAN-713 precondition pins.
--   * the baseline policies on game_roster / game_waitlist / game_join_requests / meetup_attendees, verbatim.
--   * the 8 legacy location / sport triggers on games and meetups (baseline trigger list), verbatim.
--   * the permission-matrix population (2030-dated, so "started" never masks a visibility answer).
-- Reference tables are RLS-off with SELECT to the API roles: they are invoker-read by helpers KAN-713 does
-- not change, so their own policies are out of scope and identical before/after.

SET check_function_bodies = off;

-- Columns the verbatim trigger bodies read -----------------------------------------------------------------
ALTER TABLE public.venues ADD COLUMN area_id uuid, ADD COLUMN lat double precision, ADD COLUMN lng double precision;
ALTER TABLE public.venue_spaces ADD COLUMN sport_id uuid, ADD COLUMN capacity integer;

-- Reference tables (baseline columns) ----------------------------------------------------------------------
CREATE TABLE public.game_invites (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, game_id uuid NOT NULL, to_user_id uuid NOT NULL,
  invited_by_profile_id uuid, status text DEFAULT 'pending' NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, responded_at timestamptz,
  CONSTRAINT game_invites_status_check CHECK (status = ANY (ARRAY['pending','accepted','declined','expired'])));
CREATE TABLE public.game_join_requests (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, game_id uuid NOT NULL, from_profile_id uuid NOT NULL,
  from_user_id uuid NOT NULL, status text DEFAULT 'pending' NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, decided_at timestamptz,
  CONSTRAINT game_join_requests_status_check CHECK (status = ANY (ARRAY['pending','approved','denied','cancelled'])));
CREATE TABLE public.game_link_tokens (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, game_id uuid NOT NULL, token uuid NOT NULL,
  created_by uuid NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, expires_at timestamptz, max_uses integer,
  used_count integer DEFAULT 0 NOT NULL, active boolean DEFAULT true NOT NULL);
CREATE TABLE public.game_waitlist (game_id uuid NOT NULL, profile_id uuid NOT NULL, user_id uuid NOT NULL, position integer NOT NULL,
  joined_at timestamptz DEFAULT now() NOT NULL);
CREATE TABLE public.meetup_attendees (meetup_id uuid NOT NULL, actor_profile_id uuid NOT NULL, user_id uuid NOT NULL, status text NOT NULL,
  joined_at timestamptz DEFAULT now() NOT NULL, updated_at timestamptz DEFAULT now() NOT NULL, created_at timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT meetup_attendees_status_check CHECK (status = ANY (ARRAY['going','interested','declined'])));
CREATE TABLE public.meetup_invites (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, meetup_id uuid NOT NULL, to_user_id uuid NOT NULL,
  created_by uuid NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, status text DEFAULT 'pending' NOT NULL, expires_at timestamptz);
CREATE TABLE public.meetup_link_tokens (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, meetup_id uuid NOT NULL, token uuid NOT NULL,
  created_by uuid NOT NULL, created_at timestamptz DEFAULT now() NOT NULL, expires_at timestamptz, max_uses integer,
  used_count integer DEFAULT 0 NOT NULL, active boolean DEFAULT true NOT NULL);
CREATE TABLE public.profile_follows (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, follower_profile_id uuid NOT NULL,
  following_profile_id uuid NOT NULL, created_at timestamptz DEFAULT now(), CONSTRAINT no_self_follow CHECK (follower_profile_id <> following_profile_id));
CREATE TABLE public.sport_variants (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, sport_id uuid NOT NULL, variant_key text NOT NULL,
  name_en text NOT NULL, required_players integer NOT NULL, players_per_side integer NOT NULL, is_active boolean DEFAULT true NOT NULL);
CREATE TABLE public.squad_members (squad_id uuid NOT NULL, profile_id uuid NOT NULL, user_id uuid NOT NULL, role text NOT NULL,
  joined_at timestamptz DEFAULT now() NOT NULL, left_at timestamptz, status text DEFAULT 'active' NOT NULL);
CREATE TABLE public.user_blocks (id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY, blocker_user_id uuid NOT NULL, blocked_user_id uuid NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL, CONSTRAINT user_blocks_no_self CHECK (blocker_user_id <> blocked_user_id));
CREATE TABLE public.user_freezes (user_id uuid NOT NULL, is_frozen boolean DEFAULT true NOT NULL, reason text, frozen_at timestamptz DEFAULT now() NOT NULL,
  until timestamptz, created_by uuid, lifted_at timestamptz, is_active boolean DEFAULT true NOT NULL, scope text DEFAULT 'all' NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL);
CREATE TABLE public.friendships (user_id uuid NOT NULL, peer_user_id uuid NOT NULL, status text NOT NULL);   -- HARNESS ASSUMPTION (see header)
GRANT SELECT ON public.game_invites, public.game_link_tokens, public.meetup_invites, public.meetup_link_tokens, public.profile_follows,
  public.sport_variants, public.squad_members, public.user_blocks, public.user_freezes, public.friendships TO anon, authenticated;

-- Helper and trigger functions, VERBATIM ------------------------------------------------------------------

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:784-810
CREATE OR REPLACE FUNCTION "public"."_can_view_game"("p_game_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.games g
    where g.id = p_game_id
      and (
        g.creator_user_id = auth.uid()
        or public.is_admin(auth.uid())
        or exists (
             select 1 from public.game_roster gr
             where gr.game_id = g.id
               and gr.user_id = auth.uid()
               and gr.status = 'active'
           )
        or exists (
             select 1 from public.game_waitlist gw
             where gw.game_id = g.id
               and gw.user_id = auth.uid()
           )
        or public.can_view_with_scope(
             auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
           )
      )
  );
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:816-829
CREATE OR REPLACE FUNCTION "public"."_can_view_game_for_join"("p_game" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.games g
    WHERE g.id = p_game
      AND (
        public.is_admin(auth.uid())
        OR g.creator_user_id = auth.uid()
        OR public.can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, NULL::uuid)
      )
  )
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:1139-1148
CREATE OR REPLACE FUNCTION "public"."_is_game_host"("p_game_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.games g
    where g.id = p_game_id
      and g.creator_user_id = auth.uid()
  );
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:1201-1211
CREATE OR REPLACE FUNCTION "public"."_link_token_valid"("p_game" "uuid", "p_token" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.game_link_tokens
    WHERE game_id = p_game AND token = p_token AND active = true
      AND (expires_at IS NULL OR now() < expires_at)
      AND (max_uses IS NULL OR used_count < max_uses)
  )
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:1237-1247
CREATE OR REPLACE FUNCTION "public"."_meetup_link_valid"("p_meetup" "uuid", "p_token" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select exists (
    select 1 from public.meetup_link_tokens
    where meetup_id = p_meetup and token = p_token and active = true
      and (expires_at is null or now() < expires_at)
      and (max_uses is null or used_count < max_uses)
  )
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:2058-2068
CREATE OR REPLACE FUNCTION "public"."actor_is_player"("p_profile_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.profiles
    WHERE id = p_profile_id
      AND persona_type = 'player'
      AND is_active = true
  )
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:2506-2509
CREATE OR REPLACE FUNCTION "public"."admin_override"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$ select public.is_admin(auth.uid()) $$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:3107-3118
CREATE OR REPLACE FUNCTION "public"."are_synced"("a" "uuid", "b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  with ordered as (
    select least(a,b) as u1, greatest(a,b) as u2
  )
  select exists(
    select 1 from public.friendships f, ordered o
    where f.user_id = o.u1 and f.peer_user_id = o.u2 and f.status = 'accepted'
  )
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:3630-3686
CREATE OR REPLACE FUNCTION "public"."can_current_user_join_game"("p_game_id" "uuid", "p_actor_type" "text" DEFAULT 'player'::"text", "p_link_token" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  g public.games%rowtype; viewer uuid := auth.uid(); actor_id uuid;
  slots int; visible boolean; cta text;
BEGIN
  IF viewer IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'anon'); END IF;
  IF public.is_frozen(viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'frozen'); END IF;
  actor_id := public.choose_actor(p_actor_type);
  IF NOT public.actor_is_player(actor_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'actor_not_player'); END IF;
  SELECT * INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  IF g.creator_user_id = viewer THEN RETURN jsonb_build_object('allowed', false, 'cta', 'host', 'reason', 'host'); END IF;
  visible := public.can_view_with_scope(viewer, g.creator_user_id, g.listing_visibility, g.squad_id);
  IF NOT visible THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_visible', 'reason', 'visibility_denied'); END IF;
  IF g.is_cancelled THEN RETURN jsonb_build_object('allowed', false, 'cta', 'cancelled', 'reason', 'cancelled'); END IF;
  IF g.start_at <= now() THEN RETURN jsonb_build_object('allowed', false, 'cta', 'started', 'reason', 'started'); END IF;
  IF EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.status = 'active' AND (r.user_id = viewer OR r.profile_id = actor_id)) THEN
    RETURN jsonb_build_object('allowed', false, 'cta', 'joined', 'reason', 'already');
  END IF;
  CASE g.join_policy
    WHEN 'open' THEN cta := 'join';
    WHEN 'request' THEN
      IF EXISTS (SELECT 1 FROM public.game_join_requests q WHERE q.game_id = p_game_id AND q.status = 'pending' AND (q.from_user_id = viewer OR q.from_profile_id = actor_id)) THEN
        RETURN jsonb_build_object('allowed', false, 'cta', 'requested', 'reason', 'pending_request');
      END IF;
      cta := 'request';
    WHEN 'invite' THEN
      IF EXISTS (SELECT 1 FROM public.game_invites i WHERE i.game_id = p_game_id AND i.status = 'pending' AND (i.to_user_id = viewer OR i.to_profile_id = actor_id)) THEN
        cta := 'accept_invite';
      ELSE
        RETURN jsonb_build_object('allowed', false, 'cta', 'invite_only', 'reason', 'invite_required');
      END IF;
    WHEN 'link' THEN
      IF p_link_token IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_required', 'reason', 'missing_link'); END IF;
      IF NOT public._link_token_valid(p_game_id, p_link_token) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_invalid', 'reason', 'invalid_link'); END IF;
      cta := 'join_with_link';
    WHEN 'circle' THEN
      IF NOT public.are_synced(viewer, g.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
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
      'cta', CASE WHEN g.join_policy = 'request' THEN 'request' ELSE 'waitlist' END,
      'reason', 'full');
  END IF;
  RETURN jsonb_build_object('allowed', true, 'cta', cta, 'reason', NULL);
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:3928-3935
CREATE OR REPLACE FUNCTION "public"."can_read_row"("owner_user_id" "uuid", "visibility" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select public.is_owner(owner_user_id)
         or public.admin_override()
         or public.can_view_owner(owner_user_id, visibility)
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:4117-4122
CREATE OR REPLACE FUNCTION "public"."can_view_owner"("owner_user_id" "uuid", "scope" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select public.can_view_with_scope(auth.uid(), owner_user_id, scope, null::uuid)
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:4321-4361
CREATE OR REPLACE FUNCTION "public"."can_view_with_scope"("viewer_user_id" "uuid", "owner_user_id" "uuid", "scope" "text", "p_squad_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  if viewer_user_id is not null and public.is_blocked(viewer_user_id, owner_user_id) then return false; end if;
  case scope
    when 'public' then return true;
    when 'followers' then
      if viewer_user_id is null then return false; end if;
      if viewer_user_id = owner_user_id then return true; end if;
      return exists (
        select 1
        from public.profile_follows pf
        join public.profiles fp on fp.id = pf.follower_profile_id
        join public.profiles op on op.id = pf.following_profile_id
        where fp.user_id = viewer_user_id
          and op.user_id = owner_user_id
      );
    when 'private' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id;
    when 'circle' then
      if viewer_user_id is null then return false; end if;
      return public.are_synced(viewer_user_id, owner_user_id);
    when 'hidden' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id;
    when 'invite' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id or public.is_admin(viewer_user_id);
    when 'link' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id or public.is_admin(viewer_user_id);
    when 'squad' then
      if viewer_user_id is null or p_squad_id is null then return false; end if;
      return public.is_in_squad(viewer_user_id, p_squad_id);
    else return false;
  end case;
end;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:4406-4411
CREATE OR REPLACE FUNCTION "public"."can_write_row"("owner_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select public.is_owner(owner_user_id) or public.admin_override()
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:6014-6047
CREATE OR REPLACE FUNCTION "public"."fn_games_inherit_geo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_geo_location_id uuid;
  v_area_id         uuid;
BEGIN
  -- Priority 1: venue_space_id
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id
      INTO v_geo_location_id, v_area_id
      FROM venue_spaces  vs
      JOIN venues        v  ON v.id  = vs.venue_id
      JOIN geo_locations gl ON gl.id = v.geo_location_id
     WHERE vs.id = NEW.venue_space_id;

  -- Priority 2: venue_id
  ELSIF NEW.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id
      INTO v_geo_location_id, v_area_id
      FROM venues        v
      JOIN geo_locations gl ON gl.id = v.geo_location_id
     WHERE v.id = NEW.venue_id;
  END IF;

  IF v_geo_location_id IS NOT NULL THEN
    NEW.geo_location_id := v_geo_location_id;
    NEW.area_id         := v_area_id;
  END IF;

  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:6053-6075
CREATE OR REPLACE FUNCTION "public"."fn_games_sync_joining_rule"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_joining_rule text;
BEGIN
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT vs.joining_rule INTO v_joining_rule
      FROM public.venue_spaces vs WHERE vs.id = NEW.venue_space_id;
    NEW.joining_rule := COALESCE(v_joining_rule, 'free');
    IF TG_OP = 'INSERT' THEN
      NEW.cost_cover := NEW.joining_rule;
    ELSIF TG_OP = 'UPDATE' AND OLD.joining_rule <> NEW.joining_rule THEN
      NEW.cost_cover := NEW.joining_rule;
    END IF;
  ELSE
    NEW.joining_rule := 'free';
    IF TG_OP = 'INSERT' THEN NEW.cost_cover := 'free'; END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:6286-6306
CREATE OR REPLACE FUNCTION "public"."fn_meetups_enforce_solo_sport"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_can_solo boolean;
BEGIN
  IF NEW.sport_id IS NOT NULL THEN
    SELECT can_solo INTO v_can_solo
      FROM sports
     WHERE id = NEW.sport_id;

    IF v_can_solo IS DISTINCT FROM true THEN
      RAISE EXCEPTION
        'Meetups can only be created for solo-friendly sports (can_solo = true). sport_id: %',
        NEW.sport_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:6312-6334
CREATE OR REPLACE FUNCTION "public"."fn_meetups_inherit_geo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_geo_location_id uuid;
  v_area_id         uuid;
BEGIN
  IF NEW.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id
      INTO v_geo_location_id, v_area_id
      FROM venues        v
      JOIN geo_locations gl ON gl.id = v.geo_location_id
     WHERE v.id = NEW.venue_id;

    IF v_geo_location_id IS NOT NULL THEN
      NEW.geo_location_id := v_geo_location_id;
      NEW.area_id         := v_area_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:6340-6367
CREATE OR REPLACE FUNCTION "public"."fn_meetups_sync_joining_rule"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_venue_space_id uuid;
  v_joining_rule   text;
BEGIN
  v_venue_space_id := COALESCE(
    NEW.venue_id,
    (NEW.meta->>'venue_space_id')::uuid
  );
  IF v_venue_space_id IS NOT NULL THEN
    SELECT vs.joining_rule INTO v_joining_rule
      FROM public.venue_spaces vs WHERE vs.id = v_venue_space_id;
    NEW.joining_rule := COALESCE(v_joining_rule, 'free');
    IF TG_OP = 'INSERT' THEN
      NEW.cost_cover := NEW.joining_rule;
    ELSIF TG_OP = 'UPDATE' AND OLD.joining_rule <> NEW.joining_rule THEN
      NEW.cost_cover := NEW.joining_rule;
    END IF;
  ELSE
    NEW.joining_rule := 'free';
    IF TG_OP = 'INSERT' THEN NEW.cost_cover := 'free'; END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:6904-6917
CREATE OR REPLACE FUNCTION "public"."game_slots_left"("p_game" "uuid") RETURNS integer
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  WITH g AS (SELECT capacity, game_type FROM public.games WHERE id = p_game),
  active AS (
    SELECT count(*)::int AS c
    FROM public.game_roster r
    JOIN g ON true
    WHERE r.game_id = p_game AND r.status = 'active'
      AND (r.role = 'player' OR (r.role = 'host' AND g.game_type = 'hosted'))
  )
  SELECT GREATEST((SELECT capacity FROM g) - (SELECT c FROM active), 0)
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:8250-8260
CREATE OR REPLACE FUNCTION "public"."is_frozen"("p_user" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_freezes f
    WHERE f.user_id = p_user AND f.is_frozen = true
      AND (f.until IS NULL OR now() < f.until) AND f.lifted_at IS NULL
  );
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:8356-8361
CREATE OR REPLACE FUNCTION "public"."is_in_squad"("p_user" "uuid", "p_squad" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS(SELECT 1 FROM public.squad_members WHERE squad_id = p_squad AND user_id = p_user AND status = 'active')
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:8386-8389
CREATE OR REPLACE FUNCTION "public"."is_owner"("p_owner" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$ select auth.uid() = p_owner $$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:11183-11209
CREATE OR REPLACE FUNCTION "public"."rpc_booking_hold_for_meetup"("p_meetup_id" "uuid", "p_space_id" "uuid", "p_start" timestamp with time zone, "p_end" timestamp with time zone) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  m record;
  vid uuid;
  bid uuid;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then raise exception using errcode='P0001', message='meetup_not_found'; end if;

  select s.venue_id into vid from public.venue_spaces s where s.id = p_space_id;
  if vid is null then raise exception using errcode='P0001', message='space_not_found'; end if;

  if not (m.owner_user_id = auth.uid() or public.is_venue_admin(auth.uid(), vid) or public.is_admin(auth.uid())) then
    raise exception using errcode='P0001', message='not_authorized';
  end if;

  insert into public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  values (p_space_id, p_start, p_end, 'meetup', p_meetup_id, 'confirmed', auth.uid())
  returning id into bid;

  -- (optional) store human location on meetup side already; no FK change here.
  return bid;
end;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:17581-17610
CREATE OR REPLACE FUNCTION "public"."trg_fn_games_inherit_sport_from_space"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_sport_id  uuid;
  v_capacity  integer;
BEGIN
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT vs.sport_id, vs.capacity
      INTO v_sport_id, v_capacity
      FROM public.venue_spaces vs
     WHERE vs.id = NEW.venue_space_id;

    NEW.sport_id := COALESCE(NEW.sport_id, v_sport_id);
    NEW.capacity := COALESCE(NEW.capacity, v_capacity);
  END IF;

  -- Fallback: derive capacity from game's own sport_variant_id
  IF NEW.capacity IS NULL AND NEW.sport_variant_id IS NOT NULL THEN
    SELECT sv.required_players
      INTO v_capacity
      FROM public.sport_variants sv
     WHERE sv.id = NEW.sport_variant_id;
    NEW.capacity := v_capacity;
  END IF;

  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:17616-17645
CREATE OR REPLACE FUNCTION "public"."trg_fn_games_inherit_venue_geo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_venue_id     uuid;
  v_geo_id       uuid;
  v_area_id      uuid;
  v_lat          double precision;
  v_lng          double precision;
BEGIN
  IF NEW.venue_space_id IS NOT NULL THEN
    SELECT
      v.id,
      v.geo_location_id,
      v.area_id,
      v.lat,
      v.lng
    INTO v_venue_id, v_geo_id, v_area_id, v_lat, v_lng
    FROM public.venue_spaces vs
    JOIN public.venues v ON v.id = vs.venue_id
    WHERE vs.id = NEW.venue_space_id;

    NEW.venue_id        := COALESCE(NEW.venue_id,        v_venue_id);
    NEW.geo_location_id := COALESCE(NEW.geo_location_id, v_geo_id);
    NEW.area_id         := COALESCE(NEW.area_id,         v_area_id);
  END IF;
  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:17651-17669
CREATE OR REPLACE FUNCTION "public"."trg_fn_games_require_challenge_sport"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.sports s
    WHERE s.id = NEW.sport_id
      AND s.is_challenge_sport = true
      AND s.is_active = true
  ) THEN
    RAISE EXCEPTION
      USING errcode = 'P0001',
            message = 'sport_not_challenge';
  END IF;
  RETURN NEW;
END;
$$;

-- verbatim: supabase/migrations/20261013100000_kan497_is_blocked_narrow_to_caller.sql:36-52
CREATE OR REPLACE FUNCTION public.is_blocked(user_a uuid, user_b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN auth.uid() IS NULL THEN false
    WHEN auth.uid() IS DISTINCT FROM user_a
     AND auth.uid() IS DISTINCT FROM user_b THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.user_blocks
      WHERE (blocker_user_id = user_a AND blocked_user_id = user_b)
         OR (blocker_user_id = user_b AND blocked_user_id = user_a)
    )
  END;
$function$;

-- verbatim: supabase/migrations/20260912190747_kan180_finding_b_meetup_rsvp_identity_and_profile_derivation.sql:33-109
CREATE OR REPLACE FUNCTION public.can_current_user_rsvp_meetup(p_meetup_id uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  u uuid := auth.uid();
  m public.meetups%rowtype;
  visible boolean;
begin
  if u is null then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','anon');
  end if;
  if public.is_frozen(u) then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','frozen');
  end if;

  select * into m from public.meetups where id = p_meetup_id;
  if not found then
    return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','not_found');
  end if;

  visible := public.can_view_with_scope(u, m.creator_user_id, m.listing_visibility, null);
  if not visible then
    return jsonb_build_object('allowed', false, 'cta','not_visible','reason','visibility_denied');
  end if;

  if m.is_cancelled then
    return jsonb_build_object('allowed', false, 'cta','cancelled','reason','cancelled');
  end if;
  if m.start_at <= now() then
    return jsonb_build_object('allowed', false, 'cta','started','reason','started');
  end if;

  if exists (select 1 from public.meetup_rsvps r where r.meetup_id=m.id and r.user_id=u and r.status in ('going','interested','pending')) then
    return jsonb_build_object('allowed', false, 'cta','already','reason','already');
  end if;

  case m.rsvp_policy
    when 'open' then
      return jsonb_build_object('allowed', true, 'cta','rsvp_going');

    when 'request' then
      return jsonb_build_object('allowed', true, 'cta','request');

    when 'invite' then
      if exists (select 1 from public.meetup_invites i where i.meetup_id=m.id and i.to_user_id=u and i.status='pending') then
        return jsonb_build_object('allowed', true, 'cta','accept_invite');
      else
        return jsonb_build_object('allowed', false, 'cta','invite_only','reason','invite_required');
      end if;

    when 'link' then
      if p_link_token is null then
        return jsonb_build_object('allowed', false, 'cta','link_required','reason','missing_link');
      end if;
      if not public._meetup_link_valid(m.id, p_link_token) then
        return jsonb_build_object('allowed', false, 'cta','link_required','reason','invalid_link');
      end if;
      return jsonb_build_object('allowed', true, 'cta','rsvp_going');

    when 'closed' then
      return jsonb_build_object('allowed', false, 'cta','closed','reason','closed');

    when 'circle' then
      if public.are_synced(u, m.creator_user_id) then
        return jsonb_build_object('allowed', true, 'cta','rsvp_going');
      else
        return jsonb_build_object('allowed', false, 'cta','circle_only','reason','not_in_circle');
      end if;

    else
      return jsonb_build_object('allowed', false, 'cta','not_allowed','reason','unknown_policy');
  end case;
end;
$function$;



-- 20260915120000_meetups_hardening.sql:78-79
ALTER FUNCTION public.can_current_user_rsvp_meetup(uuid, uuid) SECURITY DEFINER;
ALTER FUNCTION public.can_current_user_rsvp_meetup(uuid, uuid) SET search_path = public;

-- Owners and ACLs as the repo leaves them. The harness default privileges already give every new function
-- EXECUTE to anon/authenticated/service_role with PUBLIC's default kept (baseline GRANT ALL ... TO anon,
-- authenticated, service_role at 34164-36130). Narrowings applied by later migrations:
DO $$
DECLARE f record;
BEGIN
  FOR f IN SELECT p.oid::regprocedure AS sig FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
            AND p.proname IN ('_can_view_game','_can_view_game_for_join','_is_game_host','_link_token_valid','_meetup_link_valid',
              'actor_is_player','admin_override','are_synced','can_current_user_join_game','can_read_row','can_view_owner',
              'can_view_with_scope','can_write_row','fn_games_inherit_geo','fn_games_sync_joining_rule','fn_meetups_enforce_solo_sport',
              'fn_meetups_inherit_geo','fn_meetups_sync_joining_rule','game_slots_left','is_frozen','is_in_squad','is_owner',
              'rpc_booking_hold_for_meetup','trg_fn_games_inherit_sport_from_space','trg_fn_games_inherit_venue_geo',
              'trg_fn_games_require_challenge_sport','is_blocked','can_current_user_rsvp_meetup') LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO postgres', f.sig);
  END LOOP;
END $$;
-- 20261013135000_revoke_public_anon_trigger_functions.sql
REVOKE EXECUTE ON FUNCTION public.fn_games_inherit_geo(), public.fn_games_sync_joining_rule(), public.fn_meetups_enforce_solo_sport(),
  public.fn_meetups_inherit_geo(), public.fn_meetups_sync_joining_rule(), public.trg_fn_games_inherit_sport_from_space(),
  public.trg_fn_games_inherit_venue_geo(), public.trg_fn_games_require_challenge_sport() FROM PUBLIC, anon;
-- 20260915120000_meetups_hardening.sql:767-768
REVOKE ALL ON FUNCTION public.rpc_booking_hold_for_meetup(uuid, uuid, timestamp with time zone, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_booking_hold_for_meetup(uuid, uuid, timestamp with time zone, timestamp with time zone) TO authenticated, service_role;

-- Legacy location / sport triggers, verbatim (baseline 29843-29955) ------------------------------------------
CREATE OR REPLACE TRIGGER "trg_games_inherit_geo" BEFORE INSERT OR UPDATE OF "venue_id", "venue_space_id" ON "public"."games" FOR EACH ROW EXECUTE FUNCTION "public"."fn_games_inherit_geo"();
CREATE OR REPLACE TRIGGER "trg_games_inherit_sport_from_space" BEFORE INSERT OR UPDATE OF "venue_space_id", "sport_variant_id" ON "public"."games" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_games_inherit_sport_from_space"();
CREATE OR REPLACE TRIGGER "trg_games_inherit_venue_geo" BEFORE INSERT OR UPDATE OF "venue_space_id" ON "public"."games" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_games_inherit_venue_geo"();
CREATE OR REPLACE TRIGGER "trg_games_require_challenge_sport" BEFORE INSERT OR UPDATE OF "sport_id" ON "public"."games" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_games_require_challenge_sport"();
CREATE OR REPLACE TRIGGER "trg_games_sync_joining_rule" BEFORE INSERT OR UPDATE OF "venue_space_id" ON "public"."games" FOR EACH ROW EXECUTE FUNCTION "public"."fn_games_sync_joining_rule"();
CREATE OR REPLACE TRIGGER "trg_meetups_enforce_solo_sport" BEFORE INSERT OR UPDATE OF "sport_id" ON "public"."meetups" FOR EACH ROW EXECUTE FUNCTION "public"."fn_meetups_enforce_solo_sport"();
CREATE OR REPLACE TRIGGER "trg_meetups_inherit_geo" BEFORE INSERT OR UPDATE OF "venue_id" ON "public"."meetups" FOR EACH ROW EXECUTE FUNCTION "public"."fn_meetups_inherit_geo"();
CREATE OR REPLACE TRIGGER "trg_meetups_sync_joining_rule" BEFORE INSERT OR UPDATE OF "venue_id", "meta" ON "public"."meetups" FOR EACH ROW EXECUTE FUNCTION "public"."fn_meetups_sync_joining_rule"();

-- RLS + baseline policies on the tables whose policies call the converted helpers -------------------------------
ALTER TABLE public.game_roster ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_waitlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetup_attendees ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.game_roster, public.game_waitlist, public.game_join_requests, public.meetup_attendees TO anon, authenticated;
-- 20260901190000_kan86: the write verbs authenticated keeps on these two
GRANT INSERT, DELETE ON public.game_roster TO authenticated;
GRANT INSERT, UPDATE ON public.game_join_requests TO authenticated;
-- HARNESS ASSUMPTION: authenticated keeps UPDATE on meetup_attendees (baseline GRANT ALL), so the
-- meetup_attendees_write policy KAN-713 converts is exercised by a real write in the matrix.
GRANT UPDATE ON public.meetup_attendees TO authenticated;
-- HARNESS ASSUMPTION: the reference tables the invoker helpers read (actor_is_player -> profiles, the
-- location triggers -> venues/venue_spaces/geo_locations, sport guards -> sports) are SELECT-able by the
-- API roles, as the baseline GRANT ALL leaves them. Without it every invoker join check stops at 42501.
GRANT SELECT ON public.profiles, public.sports, public.venues, public.venue_spaces, public.geo_locations TO anon, authenticated;


-- Baseline policies on the four tables, VERBATIM (no later migration redefines them) ------------------
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32446-32446
CREATE POLICY "joinreq_insert_requester" ON "public"."game_join_requests" FOR INSERT WITH CHECK (("from_user_id" = "auth"."uid"()));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32450-32450
CREATE POLICY "joinreq_select_requester_or_host" ON "public"."game_join_requests" FOR SELECT USING ((("from_user_id" = "auth"."uid"()) OR "public"."_is_game_host"("game_id") OR "public"."is_admin"("auth"."uid"())));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32454-32454
CREATE POLICY "joinreq_update_requester_cancel" ON "public"."game_join_requests" FOR UPDATE USING (("from_user_id" = "auth"."uid"())) WITH CHECK (("status" = 'cancelled'::"text"));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32522-32522
CREATE POLICY "meetup_attendees_no_direct_delete" ON "public"."meetup_attendees" FOR DELETE USING (false);
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32526-32526
CREATE POLICY "meetup_attendees_no_direct_insert" ON "public"."meetup_attendees" FOR INSERT WITH CHECK (false);
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32530-32530
CREATE POLICY "meetup_attendees_no_direct_update" ON "public"."meetup_attendees" FOR UPDATE USING (false) WITH CHECK (false);
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32534-32536
CREATE POLICY "meetup_attendees_select" ON "public"."meetup_attendees" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."meetups" "m"
  WHERE (("m"."id" = "meetup_attendees"."meetup_id") AND "public"."can_read_row"("m"."creator_user_id", "m"."listing_visibility")))));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32540-32542
CREATE POLICY "meetup_attendees_select_visible" ON "public"."meetup_attendees" FOR SELECT USING ((("auth"."uid"() = "user_id") OR (EXISTS ( SELECT 1
   FROM "public"."meetups" "m"
  WHERE (("m"."id" = "meetup_attendees"."meetup_id") AND (("m"."listing_visibility" = 'public'::"text") OR (("m"."listing_visibility" = 'circle'::"text") AND "public"."are_synced"("auth"."uid"(), "m"."creator_user_id")) OR (("m"."listing_visibility" = 'hidden'::"text") AND ("auth"."uid"() = "m"."creator_user_id"))))))));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:32546-32550
CREATE POLICY "meetup_attendees_write" ON "public"."meetup_attendees" USING ((EXISTS ( SELECT 1
   FROM "public"."meetups" "m"
  WHERE (("m"."id" = "meetup_attendees"."meetup_id") AND ("public"."can_write_row"("m"."creator_user_id") OR ("auth"."uid"() = "meetup_attendees"."user_id")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."meetups" "m"
  WHERE (("m"."id" = "meetup_attendees"."meetup_id") AND ("public"."can_write_row"("m"."creator_user_id") OR ("auth"."uid"() = "meetup_attendees"."user_id"))))));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:33318-33318
CREATE POLICY "roster_insert_via_fn" ON "public"."game_roster" FOR INSERT WITH CHECK ((CURRENT_USER <> SESSION_USER));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:33322-33322
CREATE POLICY "roster_select_visible" ON "public"."game_roster" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."_can_view_game"("game_id")));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:33326-33326
CREATE POLICY "roster_update_self_leave" ON "public"."game_roster" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("status" = 'left'::"text"));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:33330-33330
CREATE POLICY "roster_update_via_fn" ON "public"."game_roster" FOR UPDATE USING ((CURRENT_USER <> SESSION_USER)) WITH CHECK (true);
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:33981-33981
CREATE POLICY "waitlist_delete_via_fn" ON "public"."game_waitlist" FOR DELETE USING ((CURRENT_USER <> SESSION_USER));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:33985-33985
CREATE POLICY "waitlist_insert_via_fn" ON "public"."game_waitlist" FOR INSERT WITH CHECK ((CURRENT_USER <> SESSION_USER));
-- verbatim: supabase/migrations/20260829080500_baseline_schema.sql:33989-33989
CREATE POLICY "waitlist_select_visible" ON "public"."game_waitlist" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."_can_view_game"("game_id")));


-- Permission-matrix population ---------------------------------------------------------------------------------
-- Actors: a1 owner (profile b1), a2 non-member with a pending join request on G-fol, a3 admin (harness_admins),
-- a4 member (active roster on every game, 'going' on every meetup), a5 follower AND friend of a1,
-- a6 follows a1 but is BLOCKED by a1, a7 invitee / link-holder / waitlisted.
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-0000000000a5'), ('00000000-0000-0000-0000-0000000000a6'), ('00000000-0000-0000-0000-0000000000a7');
INSERT INTO public.profiles(id, user_id) VALUES ('00000000-0000-0000-0000-0000000000b5', '00000000-0000-0000-0000-0000000000a5'),
  ('00000000-0000-0000-0000-0000000000b6', '00000000-0000-0000-0000-0000000000a6'), ('00000000-0000-0000-0000-0000000000b7', '00000000-0000-0000-0000-0000000000a7');
-- Second location pair for the trigger probes: area c2 / geo d2 / venue ee02, spaces with non-free rules.
INSERT INTO public.areas(id) VALUES ('00000000-0000-0000-0000-0000000000c2');
INSERT INTO public.geo_locations(id, area_id) VALUES ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c2');
UPDATE public.venues SET area_id = '00000000-0000-0000-0000-0000000000c1' WHERE id = '00000000-0000-0000-0000-00000000ee01';
INSERT INTO public.venues(id, geo_location_id, area_id) VALUES ('00000000-0000-0000-0000-00000000ee02', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c2');
INSERT INTO public.venue_spaces(id, venue_id, joining_rule) VALUES
  ('00000000-0000-0000-0000-00000000ee12', '00000000-0000-0000-0000-00000000ee01', 'paid'),
  ('00000000-0000-0000-0000-00000000ee21', '00000000-0000-0000-0000-00000000ee02', 'members_only');

-- Games (creator a1/b1): every games listing_visibility (public, followers, private) + a link game.
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id) VALUES
  ('71300000-0000-0000-0000-000000000001', 'G-pub',  '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
   '2030-06-01 18:00+00', '2030-06-01 19:00+00', 10, 'public', 'open', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1'),
  ('71300000-0000-0000-0000-000000000002', 'G-fol',  '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
   '2030-06-02 18:00+00', '2030-06-02 19:00+00', 10, 'followers', 'request', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1'),
  ('71300000-0000-0000-0000-000000000003', 'G-pri',  '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
   '2030-06-03 18:00+00', '2030-06-03 19:00+00', 10, 'private', 'invite', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1'),
  ('71300000-0000-0000-0000-000000000004', 'G-link', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
   '2030-06-04 18:00+00', '2030-06-04 19:00+00', 10, 'public', 'link', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
-- Meetups (creator a1/b1): every meetups listing_visibility (public, circle, invite, link, hidden).
INSERT INTO public.meetups (id, title, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at, listing_visibility, rsvp_policy,
                            sport_id, geo_location_id, area_id) VALUES
  ('71300000-0000-0000-0000-000000000101', 'M-public', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '2030-07-01 18:00+00', '2030-07-01 19:00+00', 'public', 'open', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1'),
  ('71300000-0000-0000-0000-000000000102', 'M-circle', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '2030-07-02 18:00+00', '2030-07-02 19:00+00', 'circle', 'request', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1'),
  ('71300000-0000-0000-0000-000000000103', 'M-invite', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '2030-07-03 18:00+00', '2030-07-03 19:00+00', 'invite', 'invite', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1'),
  ('71300000-0000-0000-0000-000000000104', 'M-link',   '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '2030-07-04 18:00+00', '2030-07-04 19:00+00', 'link', 'link', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1'),
  ('71300000-0000-0000-0000-000000000105', 'M-hidden', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '2030-07-05 18:00+00', '2030-07-05 19:00+00', 'hidden', 'closed', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');

-- Relationships.
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
  SELECT g, '00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000b4', 'player', 'active'
    FROM unnest(ARRAY['71300000-0000-0000-0000-000000000001','71300000-0000-0000-0000-000000000002',
                      '71300000-0000-0000-0000-000000000003','71300000-0000-0000-0000-000000000004']::uuid[]) g;
INSERT INTO public.meetup_attendees (meetup_id, actor_profile_id, user_id, status)
  SELECT m, '00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000a4', 'going'
    FROM unnest(ARRAY['71300000-0000-0000-0000-000000000101','71300000-0000-0000-0000-000000000102','71300000-0000-0000-0000-000000000103',
                      '71300000-0000-0000-0000-000000000104','71300000-0000-0000-0000-000000000105']::uuid[]) m;
INSERT INTO public.game_join_requests (game_id, from_profile_id, from_user_id, status) VALUES
  ('71300000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', 'pending');
INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) VALUES
  ('71300000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b7', '00000000-0000-0000-0000-0000000000a7', 1);
INSERT INTO public.game_invites (game_id, to_user_id, status) VALUES
  ('71300000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a7', 'pending');
INSERT INTO public.meetup_invites (meetup_id, to_user_id, created_by, status) VALUES
  ('71300000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000a1', 'pending');
INSERT INTO public.game_link_tokens (game_id, token, created_by) VALUES
  ('71300000-0000-0000-0000-000000000004', '71300000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1');
INSERT INTO public.meetup_link_tokens (meetup_id, token, created_by) VALUES
  ('71300000-0000-0000-0000-000000000104', '71300000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000a1');
INSERT INTO public.profile_follows (follower_profile_id, following_profile_id) VALUES
  ('00000000-0000-0000-0000-0000000000b5', '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000b6', '00000000-0000-0000-0000-0000000000b1');
INSERT INTO public.friendships (user_id, peer_user_id, status) VALUES
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a5', 'accepted'),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a6', 'accepted');
INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a6');


RESET check_function_bodies;

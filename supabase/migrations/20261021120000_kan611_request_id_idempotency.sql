-- KAN-611: request-id idempotency for create post / game / meetup, and one-transaction post creation (G3).
--
-- STATUS: AUTHORED, NOT APPLIED. Nothing in this file was run against any database. Memphis applies it after
-- approval (execute_sql only, never apply_migration, test data only; rollback in
-- supabase/tests/idempotency/rollback.sql; SQL tests in supabase/tests/idempotency/idempotency_tests.sql).
-- Project wtncuzcskpigqpmnxwws only.
--
-- Why. A create call whose response is lost is retried by the app, and today the retry creates a second post /
-- game / meetup. A client request id (uuid) makes the retry return the row the first call created. create_post also
-- used to leave hashtags to separate client calls (post_repository_impl.dart): a failure between them left a post
-- with no hashtags.
--
-- What it does (additive; nothing is dropped; RLS is not touched):
--   1. posts / games / meetups get a nullable request_id uuid and a PARTIAL unique index on
--      (<author or creator profile id>, request_id) WHERE request_id IS NOT NULL. Rows written without a request id
--      (all existing rows, every 1.7.9 build) are not in the index and behave exactly as before.
--   2. create_post gets one new trailing defaulted parameter p_request_id. The 20-argument function is renamed to
--      create_post_legacy_v2 (revoked from PUBLIC, anon, authenticated) and the new 21-argument function keeps its body
--      verbatim, plus: replay lookup, request_id on the INSERT, and the hashtag links (hashtags + post_hashtags) in the
--      SAME transaction as the post, circles, squads and mentions. Any failure rolls the whole call back: no partial post.
--   3. rpc_create_game and rpc_create_meetup get one new trailing defaulted parameter p_request_id. The current function
--      is renamed to *_legacy_v2 (revoked) and the new function is a thin wrapper: without a request id it
--      calls the legacy body unchanged; with one it returns the existing row's id (same uuid shape as the first success)
--      or calls the legacy body and stamps the new row, all inside one function call = one transaction.
--   4. Every create path takes a transaction-scoped advisory lock on (profile, request id) first, so two concurrent
--      calls with one id cannot both create; the unique index is the backstop.
--
-- Limits and guards. A replay returns BEFORE any guard or insert, so it adds no row and therefore cannot consume any
-- count-based allowance twice. A first call (with or without an id) runs the unchanged guards: persona gate, frozen
-- user, free_meetups_only, price_required, and so on. No numeric daily create limit for posts / games / meetups exists in
-- supabase/migrations today (the only daily cap is msg_dm_daily_cap, KAN-560); this file adds none and removes none.
--
-- Onboarding RPC idempotency is excluded (ticket decision); sending messages already has Idempotency-Key and is untouched.
-- The app does not send a request id yet (follow-up client ticket), so TC5 (create normally) must still work.
-- Order: sorts after 20261021110000 (KAN-592).

-- 1. Columns and partial unique indexes ---------------------------------------------------------------------

ALTER TABLE public.posts   ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE public.games   ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE public.meetups ADD COLUMN IF NOT EXISTS request_id uuid;

COMMENT ON COLUMN public.posts.request_id   IS 'KAN-611: client request id; (author_profile_id, request_id) is unique. NULL = created without one.';
COMMENT ON COLUMN public.games.request_id   IS 'KAN-611: client request id; (creator_profile_id, request_id) is unique. NULL = created without one.';
COMMENT ON COLUMN public.meetups.request_id IS 'KAN-611: client request id; (creator_profile_id, request_id) is unique. NULL = created without one.';

CREATE UNIQUE INDEX IF NOT EXISTS posts_author_request_id_key
  ON public.posts (author_profile_id, request_id) WHERE request_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS games_creator_request_id_key
  ON public.games (creator_profile_id, request_id) WHERE request_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS meetups_creator_request_id_key
  ON public.meetups (creator_profile_id, request_id) WHERE request_id IS NOT NULL;

-- 2. Stamping trigger for the two wrapped RPCs --------------------------------------------------------------
-- The wrapped legacy bodies INSERT without a request id. The wrapper sets the transaction-local setting
-- thebes.create_request_id just before calling them; this trigger copies it onto the row being inserted (no UPDATE,
-- so no AFTER UPDATE trigger such as tr_games_activity_sync fires a second time). The wrapper clears the setting
-- right after the call. A direct INSERT never sets it, so request_id stays NULL.

CREATE OR REPLACE FUNCTION public.kan611_stamp_request_id() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE v text := nullif(current_setting('thebes.create_request_id', true), '');
BEGIN
  IF v IS NOT NULL AND NEW.request_id IS NULL THEN
    NEW.request_id := v::uuid;
  END IF;
  RETURN NEW;
END;
$$;
ALTER FUNCTION public.kan611_stamp_request_id() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.kan611_stamp_request_id() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_games_stamp_request_id   BEFORE INSERT ON public.games   FOR EACH ROW EXECUTE FUNCTION public.kan611_stamp_request_id();
CREATE TRIGGER trg_meetups_stamp_request_id BEFORE INSERT ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.kan611_stamp_request_id();

-- 3. rpc_create_game ----------------------------------------------------------------------------------------

ALTER FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) RENAME TO rpc_create_game_legacy_v2;

REVOKE ALL ON FUNCTION public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.rpc_create_game(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; gid uuid;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  END IF;
  -- choose_actor re-asserts the caller owns the acting profile; a replay is only ever served to the creator.
  pid := public.choose_actor(p_actor_type);
  PERFORM pg_advisory_xact_lock(hashtextextended('rpc_create_game:' || pid::text || ':' || p_request_id::text, 0));
  SELECT g.id INTO gid FROM public.games g WHERE g.creator_profile_id = pid AND g.request_id = p_request_id;
  IF FOUND THEN RETURN gid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  gid := public.rpc_create_game_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_venue_space_id, p_start_at, p_end_at, p_bench_slots, p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, p_rules, p_squad_id, p_allow_spectators, p_allows_waitlist, p_sport_specific_data, p_cost_cover, p_geo_location_id, p_area_id, p_lat, p_lng, p_min_players, p_max_players, p_price_aed);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN gid;
END;
$function$;

ALTER FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) OWNER TO postgres;
-- anon stays revoked: kan444 (20261008214101) closed rpc_create_game to anon and this file does not reopen it.
REVOKE ALL ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) TO authenticated, service_role;

-- 4. rpc_create_meetup --------------------------------------------------------------------------------------

ALTER FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) RENAME TO rpc_create_meetup_legacy_v2;

REVOKE ALL ON FUNCTION public.rpc_create_meetup_legacy_v2(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.rpc_create_meetup(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text, p_description text DEFAULT NULL::text, p_venue_id uuid DEFAULT NULL::uuid, p_location_name text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_listing_visibility text DEFAULT 'public'::text, p_rsvp_policy text DEFAULT 'open'::text, p_members_only boolean DEFAULT false, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_vibe_key text DEFAULT NULL::text, p_meta jsonb DEFAULT NULL::jsonb, p_is_indoor boolean DEFAULT NULL::boolean, p_request_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; mid uuid;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  END IF;
  pid := public.choose_actor(p_actor_type);
  PERFORM pg_advisory_xact_lock(hashtextextended('rpc_create_meetup:' || pid::text || ':' || p_request_id::text, 0));
  SELECT m.id INTO mid FROM public.meetups m WHERE m.creator_profile_id = pid AND m.request_id = p_request_id;
  IF FOUND THEN RETURN mid; END IF;
  PERFORM set_config('thebes.create_request_id', p_request_id::text, true);
  mid := public.rpc_create_meetup_legacy_v2(p_actor_type, p_sport_id, p_sport_variant_id, p_title, p_description, p_venue_id, p_location_name, p_geo_location_id, p_area_id, p_start_at, p_end_at, p_capacity, p_listing_visibility, p_rsvp_policy, p_members_only, p_min_skill, p_max_skill, p_vibe_key, p_meta, p_is_indoor);
  PERFORM set_config('thebes.create_request_id', '', true);
  RETURN mid;
END;
$function$;

ALTER FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) TO authenticated, service_role;

-- 5. create_post --------------------------------------------------------------------------------------------

ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) RENAME TO create_post_legacy_v2;

REVOKE ALL ON FUNCTION public.create_post_legacy_v2(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.create_post(
  p_kind text, p_visibility text, p_post_type text DEFAULT NULL, p_origin_type text DEFAULT NULL,
  p_body text DEFAULT NULL, p_sport text DEFAULT NULL, p_media jsonb DEFAULT '[]'::jsonb,
  p_tags text[] DEFAULT '{}'::text[], p_game_id uuid DEFAULT NULL, p_location_tag_id uuid DEFAULT NULL,
  p_primary_vibe_id uuid DEFAULT NULL, p_vibe_ids uuid[] DEFAULT '{}'::uuid[],
  p_circle_ids uuid[] DEFAULT NULL, p_squad_ids uuid[] DEFAULT NULL, p_mention_profile_ids uuid[] DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL, p_location_name text DEFAULT NULL,
  p_geo_lat double precision DEFAULT NULL, p_geo_lng double precision DEFAULT NULL, p_area_id uuid DEFAULT NULL,
  p_request_id uuid DEFAULT NULL
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_uid uuid := auth.uid(); v_profile record; v_post_id uuid; v_result jsonb;
  v_cid uuid; v_sid uuid; v_mid uuid; v_post_type text; v_circle_count int := 0;
  v_tag text; v_norm text; v_hid uuid; v_sport_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT id, display_name, persona_type INTO v_profile FROM public.profiles
  WHERE user_id = v_uid AND is_active = true ORDER BY created_at ASC LIMIT 1;
  IF v_profile IS NULL THEN
    SELECT id, display_name, persona_type INTO v_profile FROM public.profiles
    WHERE user_id = v_uid ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_profile IS NULL THEN RAISE EXCEPTION 'No profile found for user %', v_uid; END IF;
  -- KAN-611: a repeated request id returns the post the first call created (same jsonb shape), before any insert.
  IF p_request_id IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('create_post:' || v_profile.id::text || ':' || p_request_id::text, 0));
    SELECT id INTO v_post_id FROM public.posts WHERE author_profile_id = v_profile.id AND request_id = p_request_id;
    IF v_post_id IS NOT NULL THEN
      SELECT to_jsonb(p.*) || jsonb_build_object(
        'vibe',
        CASE WHEN p.vibe_id IS NOT NULL THEN (
          SELECT jsonb_build_object('id', v.id, 'key', v.key, 'label_en', v.label_en, 'label_ar', v.label_ar, 'emoji', v.emoji, 'color_hex', v.color_hex)
          FROM public.vibes v WHERE v.id = p.vibe_id
        ) ELSE NULL END
      ) INTO v_result FROM public.posts p WHERE p.id = v_post_id;
      RETURN v_result;
    END IF;
  END IF;
  -- Half a point is never stored (KAN-524).
  IF (p_geo_lat IS NULL) <> (p_geo_lng IS NULL) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'geo_incomplete';
  END IF;
  v_post_type := COALESCE(p_post_type, p_kind);
  IF v_post_type = 'kickin' THEN v_post_type := 'kick_in'; END IF;
  INSERT INTO public.posts (
    author_user_id, author_profile_id, author_display_name,
    kind, visibility, post_type, origin_type,
    body, sport, media, tags, game_id, location_tag_id,
    vibe_id, persona_type_snapshot,
    venue_id, location_name, geo_lat, geo_lng, area_id,
    request_id
  ) VALUES (
    v_uid, v_profile.id, v_profile.display_name,
    p_kind::post_kind, p_visibility, v_post_type::post_type_enum,
    COALESCE(p_origin_type, 'manual')::origin_type_enum,
    p_body, p_sport, p_media, p_tags, p_game_id, p_location_tag_id,
    p_primary_vibe_id, v_profile.persona_type,
    p_venue_id, p_location_name, p_geo_lat, p_geo_lng, p_area_id,
    p_request_id
  ) RETURNING id INTO v_post_id;
  IF p_visibility = 'circle' AND p_circle_ids IS NOT NULL AND array_length(p_circle_ids, 1) > 0 THEN
    FOREACH v_cid IN ARRAY p_circle_ids LOOP
      INSERT INTO public.post_circles (post_id, circle_id) VALUES (v_post_id, v_cid) ON CONFLICT DO NOTHING;
      v_circle_count := v_circle_count + 1;
    END LOOP;
  END IF;
  IF p_visibility = 'circle' THEN
    IF NOT EXISTS (SELECT 1 FROM public.post_circles WHERE post_id = v_post_id) THEN
      RAISE EXCEPTION 'DEBUG: circle insert failed. p_circle_ids=%, array_length=%, loop_count=%',
        p_circle_ids, array_length(p_circle_ids, 1), v_circle_count;
    END IF;
  END IF;
  IF p_visibility = 'squad' AND p_squad_ids IS NOT NULL AND array_length(p_squad_ids, 1) > 0 THEN
    FOREACH v_sid IN ARRAY p_squad_ids LOOP
      INSERT INTO public.post_squads (post_id, squad_id) VALUES (v_post_id, v_sid) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;
  IF p_mention_profile_ids IS NOT NULL AND array_length(p_mention_profile_ids, 1) > 0 THEN
    FOREACH v_mid IN ARRAY p_mention_profile_ids LOOP
      INSERT INTO public.post_mentions (post_id, mentioned_profile_id) VALUES (v_post_id, v_mid) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;
  -- KAN-611: hashtags linked in the same transaction (same normalisation as the app's _linkHashtags: lower, trim,
  -- strip leading #; the app upserts the same (post_id, hashtag_id) pair, so an older client that still links them
  -- afterwards changes nothing). A failure here rolls the whole call back, so no post is left without its tags.
  IF p_tags IS NOT NULL AND array_length(p_tags, 1) > 0 THEN
    IF p_sport IS NOT NULL THEN
      SELECT id INTO v_sport_id FROM public.sports WHERE sport_key = p_sport LIMIT 1;
    END IF;
    FOREACH v_tag IN ARRAY p_tags LOOP
      v_norm := regexp_replace(lower(btrim(v_tag)), '^#+', '');
      CONTINUE WHEN v_norm IS NULL OR v_norm = '';
      v_hid := NULL;
      SELECT id INTO v_hid FROM public.hashtags WHERE tag = v_norm LIMIT 1;
      IF v_hid IS NULL THEN SELECT id INTO v_hid FROM public.hashtags WHERE slug = v_norm LIMIT 1; END IF;
      IF v_hid IS NULL THEN
        INSERT INTO public.hashtags (tag) VALUES (v_norm) ON CONFLICT DO NOTHING RETURNING id INTO v_hid;
        IF v_hid IS NULL THEN SELECT id INTO v_hid FROM public.hashtags WHERE tag = v_norm OR slug = v_norm LIMIT 1; END IF;
      END IF;
      INSERT INTO public.post_hashtags (post_id, hashtag_id, sport_id, created_by)
      VALUES (v_post_id, v_hid, v_sport_id, v_uid)
      ON CONFLICT (post_id, hashtag_id) DO NOTHING;
    END LOOP;
  END IF;
  SELECT to_jsonb(p.*) || jsonb_build_object(
    'vibe',
    CASE WHEN p.vibe_id IS NOT NULL THEN (
      SELECT jsonb_build_object('id', v.id, 'key', v.key, 'label_en', v.label_en, 'label_ar', v.label_ar, 'emoji', v.emoji, 'color_hex', v.color_hex)
      FROM public.vibes v WHERE v.id = p.vibe_id
    ) ELSE NULL END
  ) INTO v_result FROM public.posts p WHERE p.id = v_post_id;
  RETURN v_result;
END;
$$;

ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) TO authenticated, service_role;

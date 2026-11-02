-- KAN-714 — Events P2: move listing queries, views and existing consumers to parent (public.events) reads.
--
-- AUTHORED, NOT APPLIED. Local proof only (supabase/tests/events_p2_kan714/, KAN714_CONTRACT.md).
--
-- What this does, in ONE transaction:
--   0. Stage guard: KAN-712 stage B (cutover) and KAN-713 must be live; KAN-714 must not already be applied;
--      the applying role must bypass RLS (public.events is FORCE RLS with zero policies and no API grants).
--   1. Drift pins: md5(prosrc) of the five repointed functions and a column-signature + column-dependency md5 of
--      the six repointed views. Any drift from the authored pre-image aborts.
--   2. Pre-image capture into public.kan714_preimage (RLS on, no API grants) — rollback_kan714.sql restores
--      from it byte-for-byte (pg_get_functiondef / pg_get_viewdef + ACL + owner + reloptions).
--   3. CREATE OR REPLACE of 6 views and 5 functions so every SHARED column (the columns public.events owns)
--      is read from public.events, joined `e.id = <subtype>.event_id AND e.event_type = '<game|meetup>'`.
--      Subtype-only columns (description, location_name, game_type, bench_slots, members_only, vibe_key, ...)
--      stay on the subtype. Exact output shape is enforced by CREATE OR REPLACE itself (Postgres refuses a
--      changed column name/type/order); ids stay subtype ids (games.id / meetups.id); smallint skill columns
--      are cast back to integer. Owner, ACL, SECURITY DEFINER, search_path, volatility and reloptions are
--      unchanged and asserted against the pre-image in post-conditions.
--   4. Two btree indexes on public.events for keyset pagination and the sport overview counts.
--   5. Post-conditions.
--
-- NOT changed here (named, see KAN714_CONTRACT.md section 1): v_game_rating (reads only games.id — UNCHANGED),
-- rpc_meetup_my (pre-existing broken body: m.starts_at / m.visibility / m.owner_user_id do not exist, 42703 —
-- EXCEPTION, kept byte-for-byte), meetups.search_tsv readers (meetups.search_tsv is weighted A/B/C, events
-- search_tsv is title-only — EXCEPTION, KAN-718), INVOKER readers (cannot read public.events as an API role;
-- legacy columns stay exact via the KAN-712 compat mirror — UNCHANGED-WITH-REASON).
-- No DROP TABLE, no DROP COLUMN, no CASCADE, no data mutation, no legacy column removal.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_applied boolean := false;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-714: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;

  IF to_regclass('public.kan714_preimage') IS NOT NULL THEN
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.kan714_preimage)' INTO v_applied;
  END IF;
  IF v_applied THEN
    RAISE EXCEPTION 'KAN-714: already applied (public.kan714_preimage has rows); run rollback_kan714.sql first';
  END IF;

  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-714: public.events missing (KAN-710 not applied)';
  END IF;

  -- KAN-712 stage B markers (cutover): compat mirror on events, guards on both subtypes, wrapped RPC registry.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_after_delete'),
      -- KAN-713 markers
      ('public.events',  'trg_kan713_events_location'),
      ('public.games',   'trg_kan713_games_a_location'),
      ('public.games',   'trg_kan713_games_b_joining'),
      ('public.games',   'trg_kan713_games_c_venue_geo'),
      ('public.meetups', 'trg_kan713_meetups_a_location'),
      ('public.meetups', 'trg_kan713_meetups_b_joining')) AS t(rel, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger
                    WHERE tgrelid = r.rel::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      v_missing := v_missing || (r.rel || '.' || r.tg);
    END IF;
  END LOOP;

  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    v_missing := v_missing || 'public.kan712_wrapped_rpcs'::text;
  ELSE
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs)' INTO v_applied;
    IF NOT v_applied THEN
      v_missing := v_missing || 'public.kan712_wrapped_rpcs (empty: stage B not run)'::text;
    END IF;
  END IF;

  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    v_missing := v_missing || 'public.kan713_meetup_visible(uuid)'::text;
  END IF;

  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'KAN-714: prerequisite stage missing: %', array_to_string(v_missing, ', ');
  END IF;

  -- events must still be closed to the API (KAN-710 posture). KAN-714 reads it only from owner views and
  -- SECURITY DEFINER functions owned by a BYPASSRLS role.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR NOT (SELECT relforcerowsecurity AND relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-714: public.events is no longer closed (policy or API grant present) — re-assess';
  END IF;

  -- Every subtype row has its parent (INNER JOIN must not lose rows).
  IF EXISTS (SELECT 1 FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE e.id IS NULL)
     OR EXISTS (SELECT 1 FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-714: a games/meetups row has no events parent of the matching event_type';
  END IF;
END
$guard$;

CREATE TEMP TABLE kan714_events_acl ON COMMIT DROP AS
  SELECT relacl::text AS acl FROM pg_class WHERE oid = 'public.events'::regclass;

-- The owners of the readers must be able to read events past FORCE RLS (definer functions / owner views).
DO $owners$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS obj, p.proowner AS own FROM pg_proc p
     WHERE p.oid IN ('public.meetup_counts(uuid)'::regprocedure, 'public.rpc_games_following_joined(uuid[])'::regprocedure,
                     'public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure,
                     'public.rpc_meetup_card(uuid,text)'::regprocedure, 'public.rpc_sport_overview(uuid,text)'::regprocedure)
    UNION ALL
    SELECT c.oid::regclass::text, c.relowner FROM pg_class c
     WHERE c.oid IN ('public.v_game_card'::regclass, 'public.v_my_games'::regclass, 'public.v_meetup_list'::regclass,
                     'public.v_meetup_counts'::regclass, 'public.v_rateable_after_game'::regclass,
                     'public.v_host_weekly_metrics'::regclass)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = r.own AND (rolsuper OR rolbypassrls)) THEN
      RAISE EXCEPTION 'KAN-714: owner of % cannot bypass RLS on public.events', r.obj;
    END IF;
  END LOOP;
END
$owners$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins (authored against these exact pre-images; pg-version independent)
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.meetup_counts(uuid)',                                 'ec29fe4c662d0c6fbe1117a5d01a7652'),
      ('public.rpc_games_following_joined(uuid[])',                  'd3b31f55b000b4991be313f4c96d88d9'),
      ('public.rpc_meetup_attendees(uuid,text,integer,integer)',     '0d4d8906a37cf2498850912836c4396f'),
      ('public.rpc_meetup_card(uuid,text)',                          'f5063f027042e30c006efa960f7016d1'),
      ('public.rpc_sport_overview(uuid,text)',                       '1ba644397046241ae6c1f7f81c5bc9b7')) AS t(f, h)
  LOOP
    IF to_regprocedure(r.f) IS NULL THEN
      RAISE EXCEPTION 'KAN-714 pin: % missing', r.f;
    END IF;
    SELECT md5(prosrc) INTO v FROM pg_proc WHERE oid = to_regprocedure(r.f);
    IF v <> r.h THEN
      RAISE EXCEPTION 'KAN-714 pin: % body drifted (md5 % expected %)', r.f, v, r.h;
    END IF;
  END LOOP;

  -- Views: md5 of the output column signature, and md5 of the games/meetups/events columns the rule depends on.
  FOR r IN SELECT * FROM (VALUES
      ('v_game_card',           'e76e308c1c7bf5eb86715833bc43f3df', '8bae59c4cbd762b8e2dcfd544e58bb79'),
      ('v_host_weekly_metrics', '1d76ace9f1cfce7fda0d9ec3ad7c065f', '49ec8ddfcaac7104c744305dc6cdc1c4'),
      ('v_meetup_counts',       'dd838c23130d89c039a722701b1977b5', '45969358c5b69c6908fc3d1c663285e9'),
      ('v_meetup_list',         'f663167fc1008de9394e11f5c04c4d04', '9e0506d7d890fc1714b8182a3b201c39'),
      ('v_my_games',            'c46dc79c8e744637eadb935f1fcc8af0', '00d1d90b6bbe7c0d4657ea95888c737f'),
      ('v_rateable_after_game', '1e6a11420e215a3f621928c055996116', '43f0f35181fd741e2f1cb6ac5e8e8c03')) AS t(vw, sig, dep)
  LOOP
    SELECT md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)) INTO v
      FROM pg_attribute a WHERE a.attrelid = ('public.' || r.vw)::regclass AND a.attnum > 0 AND NOT a.attisdropped;
    IF v IS DISTINCT FROM r.sig THEN
      RAISE EXCEPTION 'KAN-714 pin: public.% column signature drifted (md5 % expected %)', r.vw, v, r.sig;
    END IF;
    SELECT md5(string_agg(DISTINCT t.relname || '.' || a.attname, ',' ORDER BY t.relname || '.' || a.attname)) INTO v
      FROM pg_rewrite rw
      JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
      JOIN pg_class t ON t.oid = d.refobjid AND t.relnamespace = 'public'::regnamespace
                     AND t.relname IN ('games', 'meetups', 'events')
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
     WHERE rw.ev_class = ('public.' || r.vw)::regclass;
    IF v IS DISTINCT FROM r.dep THEN
      RAISE EXCEPTION 'KAN-714 pin: public.% column dependencies drifted (md5 % expected %)', r.vw, v, r.dep;
    END IF;
  END LOOP;
END
$pins$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Pre-image capture
-- ---------------------------------------------------------------------------------------------------------
-- Fixed search_path so pg_get_viewdef() qualifies exactly the names rollback_kan714.sql resolves under the
-- same setting.
SET LOCAL search_path TO public, extensions;
CREATE TABLE IF NOT EXISTS public.kan714_preimage (
  object      text PRIMARY KEY,           -- regprocedure text, or regclass text for a view
  kind        text NOT NULL CHECK (kind IN ('function', 'view')),
  definition  text NOT NULL,              -- pg_get_functiondef(), or pg_get_viewdef(oid, false)
  acl         text,                       -- proacl / relacl as text (NULL = default)
  owner       name NOT NULL,
  secdef      boolean,
  config      text[],
  volatility  "char",
  reloptions  text[],
  captured_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.kan714_preimage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kan714_preimage FROM PUBLIC, anon, authenticated, service_role;

INSERT INTO public.kan714_preimage (object, kind, definition, acl, owner, secdef, config, volatility)
SELECT p.oid::regprocedure::text, 'function', pg_get_functiondef(p.oid), p.proacl::text, pg_get_userbyid(p.proowner),
       p.prosecdef, p.proconfig, p.provolatile
  FROM pg_proc p
 WHERE p.oid IN ('public.meetup_counts(uuid)'::regprocedure, 'public.rpc_games_following_joined(uuid[])'::regprocedure,
                 'public.rpc_meetup_attendees(uuid,text,integer,integer)'::regprocedure,
                 'public.rpc_meetup_card(uuid,text)'::regprocedure, 'public.rpc_sport_overview(uuid,text)'::regprocedure);

INSERT INTO public.kan714_preimage (object, kind, definition, acl, owner, reloptions)
SELECT c.oid::regclass::text, 'view', pg_get_viewdef(c.oid, false), c.relacl::text, pg_get_userbyid(c.relowner), c.reloptions
  FROM pg_class c
 WHERE c.oid IN ('public.v_game_card'::regclass, 'public.v_my_games'::regclass, 'public.v_meetup_list'::regclass,
                 'public.v_meetup_counts'::regclass, 'public.v_rateable_after_game'::regclass,
                 'public.v_host_weekly_metrics'::regclass);

DO $cnt$ BEGIN
  IF (SELECT count(*) FROM public.kan714_preimage) <> 11 THEN
    RAISE EXCEPTION 'KAN-714: pre-image capture expected 11 objects, got %', (SELECT count(*) FROM public.kan714_preimage);
  END IF;
END $cnt$;

-- ---------------------------------------------------------------------------------------------------------
-- 3a. Views
-- ---------------------------------------------------------------------------------------------------------

-- v_meetup_counts (owner view, security_invoker=off): visibility gate reads events.
CREATE OR REPLACE VIEW public.v_meetup_counts WITH (security_invoker = off) AS
 SELECT r.meetup_id,
    sum((r.status = 'going'::text)::integer) AS going_count,
    sum((r.status = 'interested'::text)::integer) AS interested_count,
    sum((r.status = 'declined'::text)::integer) AS declined_count
   FROM public.meetup_rsvps r
     JOIN public.meetups m ON m.id = r.meetup_id
     JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'::text
  WHERE public.can_view_owner(e.creator_user_id, e.listing_visibility) = true
  GROUP BY r.meetup_id;

-- v_meetup_list: shared columns from events; rsvp_policy <- events.join_policy; skill cast back to integer.
-- ORDER BY gains a final m.id tie-break (the previous order was non-deterministic on equal timestamps).
CREATE OR REPLACE VIEW public.v_meetup_list AS
 SELECT m.id,
    e.title,
    m.description,
    e.start_at,
    e.end_at,
    e.capacity,
    m.members_only,
    e.listing_visibility,
    e.join_policy AS rsvp_policy,
    e.is_cancelled,
    m.vibe_key,
    e.created_at,
    e.updated_at,
    e.creator_profile_id,
    cp.display_name AS creator_display_name,
    cp.username AS creator_username,
    cp.avatar_url AS creator_avatar_url,
    e.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    s.emoji AS sport_emoji,
    e.area_id,
    a.name AS area_name,
    e.venue_id,
    v.name_en AS venue_name,
    m.location_name,
    e.geo_location_id,
    e.min_skill::integer AS min_skill,
    e.max_skill::integer AS max_skill,
    e.joining_rule,
    e.cost_cover,
    COALESCE(c.going_count, 0::bigint) AS going_count,
    COALESCE(c.interested_count, 0::bigint) AS interested_count,
    COALESCE(c.declined_count, 0::bigint) AS declined_count,
    att.status AS my_rsvp_status,
        CASE
            WHEN auth.uid() IS NULL THEN '[]'::jsonb
            ELSE COALESCE(( SELECT jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name) ORDER BY x.updated_at DESC NULLS LAST) AS jsonb_agg
               FROM ( SELECT r2.profile_id,
                        r2.updated_at
                       FROM public.meetup_rsvps r2
                      WHERE r2.meetup_id = m.id AND r2.status = 'going'::text
                      ORDER BY r2.updated_at DESC NULLS LAST, r2.created_at DESC
                     LIMIT 5) x
                 JOIN public.profiles ap ON ap.id = x.profile_id), '[]'::jsonb)
        END AS attendee_avatars,
    ( SELECT bool_or(vs.indoor) AS bool_or
           FROM public.venue_spaces vs
          WHERE vs.venue_id = e.venue_id AND vs.is_active = true) AS venue_is_indoor,
    (( SELECT count(*) AS count
           FROM public.favorites f
          WHERE f.meetup_id = m.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM public.favorites f
          WHERE f.meetup_id = m.id AND f.user_id = auth.uid())) AS favourited_by_me,
    COALESCE(( SELECT bool_or(vs2.indoor) AS bool_or
           FROM public.venue_spaces vs2
          WHERE vs2.venue_id = e.venue_id AND vs2.is_active = true), m.is_indoor) AS setting_is_indoor
   FROM public.meetups m
     JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'::text
     LEFT JOIN public.profiles cp ON cp.id = e.creator_profile_id
     LEFT JOIN public.sports s ON s.id = e.sport_id
     LEFT JOIN public.areas a ON a.id = e.area_id
     LEFT JOIN public.venues v ON v.id = e.venue_id
     LEFT JOIN public.v_meetup_counts c ON c.meetup_id = m.id
     LEFT JOIN public.meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
  WHERE public.can_view_owner(e.creator_user_id, e.listing_visibility) = true
  ORDER BY (COALESCE(e.updated_at, e.created_at)) DESC, m.id;

-- v_game_card
CREATE OR REPLACE VIEW public.v_game_card AS
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
           FROM public.game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text AND (gr.role = 'player'::text OR gr.role = 'host'::text AND g.game_type = 'hosted'::text)) AS roster_count,
    e.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM public.game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
    COALESCE(( SELECT pv.verified
           FROM public.profile_verifications pv
          WHERE pv.profile_id = e.creator_profile_id), false) OR (EXISTS ( SELECT 1
           FROM public.organiser o
          WHERE o.profile_id = e.creator_profile_id AND o.sport = s.sport_key AND o.is_verified AND o.is_active)) AS host_verified,
    (EXISTS ( SELECT 1
           FROM public.likes lk
          WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
    st_y(gl.location) AS latitude,
    st_x(gl.location) AS longitude,
    (( SELECT count(*) AS count
           FROM public.favorites f
          WHERE f.game_id = g.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM public.favorites f
          WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
    g.price_aed,
    g.series_id,
        CASE
            WHEN s2.id IS NULL THEN NULL::text
            WHEN s2.rrule ~~ '%INTERVAL=2%'::text THEN 'biweekly'::text
            ELSE 'weekly'::text
        END AS series_frequency,
    s2.ends_on AS series_ends_on
   FROM public.games g
     JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'::text
     LEFT JOIN public.sports s ON s.id = e.sport_id
     LEFT JOIN public.sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN public.profiles cp ON cp.id = e.creator_profile_id
     LEFT JOIN public.areas a ON a.id = e.area_id
     LEFT JOIN public.venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN public.venues v ON v.id = COALESCE(vs.venue_id, e.venue_id)
     LEFT JOIN public.geo_locations gl ON gl.id = e.geo_location_id
     LEFT JOIN public.game_series s2 ON s2.id = g.series_id
  WHERE e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM public.game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR public.can_view_with_scope(auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id);

-- v_my_games
CREATE OR REPLACE VIEW public.v_my_games AS
 SELECT g.id,
    e.title,
    g.game_type,
    e.start_at,
    e.end_at,
    e.capacity,
    e.is_cancelled,
    e.listing_visibility,
    e.join_policy,
    e.created_at,
    e.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    e.creator_profile_id,
    e.creator_user_id,
    e.area_id,
    a.name AS area_name,
    e.venue_id,
    v.name_en AS venue_name,
    gr.status AS my_roster_status
   FROM public.games g
     JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'::text
     LEFT JOIN public.sports s ON s.id = e.sport_id
     LEFT JOIN public.areas a ON a.id = e.area_id
     LEFT JOIN public.venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN public.venues v ON v.id = COALESCE(vs.venue_id, e.venue_id)
     LEFT JOIN public.game_roster gr ON gr.game_id = g.id AND gr.user_id = auth.uid()
  WHERE e.creator_user_id = auth.uid() OR gr.user_id = auth.uid();

-- v_host_weekly_metrics
CREATE OR REPLACE VIEW public.v_host_weekly_metrics AS
 WITH g AS (
         SELECT g_1.id,
            e.creator_user_id AS host_user_id,
            date_trunc('week'::text, e.start_at)::date AS week_start,
            date_part('isoyear'::text, e.start_at)::integer AS isoy,
            date_part('week'::text, e.start_at)::integer AS isow,
            e.capacity,
            e.is_cancelled
           FROM public.games g_1
             JOIN public.events e ON e.id = g_1.event_id AND e.event_type = 'game'::text
        ), r AS (
         SELECT game_roster.game_id,
            count(*) FILTER (WHERE game_roster.status = 'active'::text) AS active_cnt
           FROM public.game_roster
          GROUP BY game_roster.game_id
        ), m AS (
         SELECT g.host_user_id AS user_id,
            g.isoy,
            g.isow,
            count(*) FILTER (WHERE NOT g.is_cancelled) AS games_hosted,
            round(avg(GREATEST(0.0, LEAST(1.0, COALESCE(r.active_cnt::numeric, 0::numeric) / NULLIF(g.capacity, 0)::numeric))), 3) AS fill_rate
           FROM g
             LEFT JOIN r ON r.game_id = g.id
          GROUP BY g.host_user_id, g.isoy, g.isow
        )
 SELECT user_id,
    isoy,
    isow,
    games_hosted,
    fill_rate
   FROM m;

-- v_rateable_after_game
CREATE OR REPLACE VIEW public.v_rateable_after_game AS
 WITH ctx AS (
         SELECT g.id AS game_id,
            e.creator_user_id AS host_user_id,
            e.end_at
           FROM public.games g
             JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'::text
        )
 SELECT c.game_id,
    rr.user_id AS you_user_id,
    r.user_id AS ratee_user_id,
        CASE
            WHEN r.user_id = (( SELECT ctx.host_user_id
               FROM ctx
              WHERE ctx.game_id = c.game_id)) THEN 'organiser'::text
            ELSE 'player'::text
        END AS ratee_role
   FROM ctx c
     JOIN public.game_roster rr ON rr.game_id = c.game_id AND rr.status = 'active'::text AND rr.user_id = auth.uid()
     JOIN public.game_roster r ON r.game_id = c.game_id AND r.status = 'active'::text
  WHERE r.user_id <> auth.uid() OR (( SELECT ctx.host_user_id
           FROM ctx
          WHERE ctx.game_id = c.game_id)) <> auth.uid();

-- ---------------------------------------------------------------------------------------------------------
-- 3b. Functions (authored from pg_get_functiondef; attributes verbatim)
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.meetup_counts(p_meetup_id uuid)
 RETURNS TABLE(going integer, interested integer, declined integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  left join public.meetup_rsvps r on r.meetup_id = m.id
  where m.id = p_meetup_id
    and public.can_view_owner(e.creator_user_id, e.listing_visibility)
$function$;

CREATE OR REPLACE FUNCTION public.rpc_games_following_joined(p_game_ids uuid[])
 RETURNS TABLE(game_id uuid, following_count integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with me as (
    select auth.uid() as uid
  ),
  my_following as (
    select distinct pf.following_profile_id as profile_id
    from public.profile_follows pf
    join public.profiles p on p.id = pf.follower_profile_id
    where p.user_id = (select uid from me)
  ),
  blocked as (
    select case when ub.blocker_user_id = (select uid from me)
                then ub.blocked_user_id else ub.blocker_user_id end as other_user_id
    from public.user_blocks ub
    where ub.blocker_user_id = (select uid from me)
       or ub.blocked_user_id = (select uid from me)
  ),
  visible as (
    select g.id
    from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'
    where (select uid from me) is not null
      and g.id = any (p_game_ids[1:200])
      and e.is_cancelled = false
      and public._can_view_game(g.id)
  )
  select gr.game_id, count(distinct gr.user_id)::int as following_count
  from public.game_roster gr
  join visible v on v.id = gr.game_id
  join my_following mf on mf.profile_id = gr.profile_id
  where gr.status = 'active'
    and gr.role in ('host', 'player', 'sub')
    and gr.user_id <> (select uid from me)
    and not exists (select 1 from blocked b where b.other_user_id = gr.user_id)
    and not exists (select 1 from public.privacy_settings ps
                    where ps.user_id = gr.user_id and ps.show_game_history = false)
  group by gr.game_id;
$function$;

-- rpc_meetup_attendees: no meetups%rowtype any more (shared fields come from events). The ORDER BY gains a
-- final r.profile_id tie-break so OFFSET pagination is deterministic on equal timestamps.
CREATE OR REPLACE FUNCTION public.rpc_meetup_attendees(p_meetup_id uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(actor_profile_id uuid, display_name text, username citext, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me        uuid := auth.uid();
  v_creator uuid;
  v_vis     text;
  v_host    boolean;
begin
  select e.creator_user_id, e.listing_visibility into v_creator, v_vis
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  where m.id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, v_creator, v_vis, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (v_creator = me or public.is_admin(me));

  return query
  select
    r.profile_id,
    p.display_name,
    p.username,
    r.status
  from public.meetup_rsvps r
  left join public.profiles p on p.id = r.profile_id
  where r.meetup_id = p_meetup_id
    and (p_status is null or r.status = p_status)
    and (v_host or r.status in ('going','interested'))
  order by r.updated_at desc nulls last, r.created_at desc, r.profile_id
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

-- rpc_meetup_card: no meetups%rowtype; subtype-only fields (description, location_name, host_actor_id) are
-- read as scalars, every shared field from an events%rowtype. JSON keys, order and values unchanged.
CREATE OR REPLACE FUNCTION public.rpc_meetup_card(p_meetup_id uuid, p_profile_type text DEFAULT 'player'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me      uuid := auth.uid();
  e       public.events%rowtype;
  v_mid   uuid;
  v_desc  text;
  v_loc   text;
  v_hostp uuid;
  v_host  boolean;
  g int; i int; d int; pn int;
  my_status_ text;
  hp_name text;
  hp_user citext;
  counts_ jsonb;
  hp_avatar text;
  sp public.sports%rowtype;
  v_area text;
  v_venue text;
  atts jsonb := '[]'::jsonb;
begin
  select m.id, m.description, m.location_name, m.host_actor_id
    into v_mid, v_desc, v_loc, v_hostp
  from public.meetups m where m.id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;
  select ev.* into e
  from public.meetups m
  join public.events ev on ev.id = m.event_id and ev.event_type = 'meetup'
  where m.id = p_meetup_id;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not public.can_view_with_scope(me, e.creator_user_id, e.listing_visibility, null) then
    raise exception using errcode='P0001', message='not_allowed';
  end if;

  v_host := me is not null and (e.creator_user_id = me or public.is_admin(me));

  select
    (count(*) filter (where r.status = 'going'))::int,
    (count(*) filter (where r.status = 'interested'))::int,
    (count(*) filter (where r.status = 'declined'))::int,
    (count(*) filter (where r.status = 'pending'))::int
    into g, i, d, pn
  from public.meetup_rsvps r
  where r.meetup_id = p_meetup_id;

  if me is not null then
    select r.status into my_status_
    from public.meetup_rsvps r
    where r.meetup_id = p_meetup_id and r.user_id = me;
  end if;

  select hp.display_name, hp.username, hp.avatar_url into hp_name, hp_user, hp_avatar
  from public.profiles hp where hp.id = v_hostp;

  select * into sp from public.sports s where s.id = e.sport_id;
  select a.name into v_area from public.areas a where a.id = e.area_id;
  select v.name_en into v_venue from public.venues v where v.id = e.venue_id;

  -- member names/avatars: authenticated callers only (the card is anon-callable)
  if me is not null then
    select coalesce(jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name)
                              order by x.updated_at desc nulls last), '[]'::jsonb)
      into atts
    from (select r.profile_id, r.updated_at from public.meetup_rsvps r
          where r.meetup_id = p_meetup_id and r.status = 'going'
          order by r.updated_at desc nulls last, r.created_at desc limit 8) x
    join public.profiles ap on ap.id = x.profile_id;
  end if;

  counts_ := jsonb_build_object(
    'going',      coalesce(g,0),
    'interested', coalesce(i,0),
    'declined',   coalesce(d,0)
  );
  if v_host then
    counts_ := counts_ || jsonb_build_object('pending', coalesce(pn,0));
  end if;

  return jsonb_build_object(
    'id',               v_mid,
    'title',            e.title,
    'description',      v_desc,
    'start_at',         e.start_at,
    'end_at',           e.end_at,
    'location_name',    v_loc,
    'capacity',         e.capacity,
    'visibility',       e.listing_visibility,
    'is_cancelled',     e.is_cancelled,
    'owner_profile_id', e.creator_profile_id,
    'host', jsonb_build_object(
      'actor_profile_id', v_hostp,
      'display_name',     hp_name,
      'username',         hp_user,
      'avatar_url',       hp_avatar
    ),
    'counts',    counts_,
    'my_status', my_status_,
    'sport_key',     sp.sport_key,
    'sport_name_en', sp.name_en,
    'sport_name_ar', sp.name_ar,
    'min_skill',     e.min_skill::integer,
    'max_skill',     e.max_skill::integer,
    'area_name',     v_area,
    'venue_name',    v_venue,
    'attendees',     atts,
    'is_host',   v_host
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_sport_overview(p_sport_id uuid, p_city_code text DEFAULT NULL::text)
 RETURNS TABLE(followers bigint, games_next7 bigint, meetups_next7 bigint, venues bigint, spaces bigint, posts bigint, news bigint, mutual_followers jsonb)
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
       JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       LEFT JOIN public.areas a ON a.id = e.area_id
      WHERE e.sport_id = p_sport_id AND e.is_cancelled = false
        AND e.listing_visibility = 'public'
        AND e.start_at >= now() AND e.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, e.creator_user_id)
        AND (v_city IS NULL OR a.city_code = v_city)),

    (SELECT count(DISTINCT m.id) FROM public.meetups m
       JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
       LEFT JOIN public.areas a ON a.id = e.area_id
      WHERE e.sport_id = p_sport_id AND e.is_cancelled = false
        AND e.listing_visibility = 'public'
        AND e.start_at >= now() AND e.start_at < now() + v_window
        AND NOT public.is_blocked(v_uid, e.creator_user_id)
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

-- ---------------------------------------------------------------------------------------------------------
-- 4. Indexes on public.events (keyset pagination; sport overview window counts)
-- ---------------------------------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS events_kan714_type_start_id_idx
  ON public.events (event_type, start_at, id);
CREATE INDEX IF NOT EXISTS events_kan714_sport_type_start_idx
  ON public.events (sport_id, event_type, start_at) WHERE NOT is_cancelled;

-- ---------------------------------------------------------------------------------------------------------
-- 5. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text; n int;
BEGIN
  -- Functions: owner, ACL, SECURITY DEFINER, search_path, volatility unchanged; body changed.
  FOR r IN SELECT pi.*, p.proacl::text AS acl_now, pg_get_userbyid(p.proowner) AS own_now, p.prosecdef AS sd_now,
                  p.proconfig AS cfg_now, p.provolatile AS vol_now, pg_get_functiondef(p.oid) AS def_now
             FROM public.kan714_preimage pi JOIN pg_proc p ON p.oid = pi.object::regprocedure
            WHERE pi.kind = 'function'
  LOOP
    IF r.acl IS DISTINCT FROM r.acl_now OR r.owner <> r.own_now OR r.secdef IS DISTINCT FROM r.sd_now
       OR r.config IS DISTINCT FROM r.cfg_now OR r.volatility IS DISTINCT FROM r.vol_now THEN
      RAISE EXCEPTION 'KAN-714 post: % attributes changed (acl % -> %, owner % -> %, secdef % -> %, config % -> %, vol % -> %)',
        r.object, r.acl, r.acl_now, r.owner, r.own_now, r.secdef, r.sd_now, r.config, r.cfg_now, r.volatility, r.vol_now;
    END IF;
    IF r.definition = r.def_now THEN
      RAISE EXCEPTION 'KAN-714 post: % was not repointed', r.object;
    END IF;
    IF r.def_now NOT LIKE '%public.events%' THEN
      RAISE EXCEPTION 'KAN-714 post: % does not read public.events', r.object;
    END IF;
  END LOOP;

  -- Views: owner, ACL, reloptions unchanged; column signature unchanged; depends on events; no remaining
  -- dependency on a SHARED games/meetups column (events owns it).
  FOR r IN SELECT pi.*, c.relacl::text AS acl_now, pg_get_userbyid(c.relowner) AS own_now, c.reloptions AS opt_now, c.oid AS voi
             FROM public.kan714_preimage pi JOIN pg_class c ON c.oid = pi.object::regclass
            WHERE pi.kind = 'view'
  LOOP
    IF r.acl IS DISTINCT FROM r.acl_now OR r.owner <> r.own_now OR r.reloptions IS DISTINCT FROM r.opt_now THEN
      RAISE EXCEPTION 'KAN-714 post: % attributes changed (acl % -> %, owner % -> %, reloptions % -> %)',
        r.object, r.acl, r.acl_now, r.owner, r.own_now, r.reloptions, r.opt_now;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_rewrite rw JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid
                    WHERE rw.ev_class = r.voi AND d.refobjid = 'public.events'::regclass) THEN
      RAISE EXCEPTION 'KAN-714 post: % does not depend on public.events', r.object;
    END IF;
    SELECT string_agg(DISTINCT t.relname || '.' || a.attname, ',') INTO v
      FROM pg_rewrite rw
      JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
      JOIN pg_class t ON t.oid = d.refobjid AND t.oid IN ('public.games'::regclass, 'public.meetups'::regclass)
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
     WHERE rw.ev_class = r.voi
       AND (a.attname = 'rsvp_policy'
            OR (a.attname <> 'id' AND EXISTS (SELECT 1 FROM pg_attribute ea
                                               WHERE ea.attrelid = 'public.events'::regclass AND ea.attnum > 0
                                                 AND NOT ea.attisdropped AND ea.attname = a.attname)));
    IF v IS NOT NULL THEN
      RAISE EXCEPTION 'KAN-714 post: % still reads shared legacy columns: %', r.object, v;
    END IF;
  END LOOP;

  -- Column signatures unchanged (CREATE OR REPLACE enforces it; asserted anyway against the pins).
  FOR r IN SELECT * FROM (VALUES
      ('v_game_card',           'e76e308c1c7bf5eb86715833bc43f3df'),
      ('v_host_weekly_metrics', '1d76ace9f1cfce7fda0d9ec3ad7c065f'),
      ('v_meetup_counts',       'dd838c23130d89c039a722701b1977b5'),
      ('v_meetup_list',         'f663167fc1008de9394e11f5c04c4d04'),
      ('v_my_games',            'c46dc79c8e744637eadb935f1fcc8af0'),
      ('v_rateable_after_game', '1e6a11420e215a3f621928c055996116')) AS t(vw, sig)
  LOOP
    SELECT md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)) INTO v
      FROM pg_attribute a WHERE a.attrelid = ('public.' || r.vw)::regclass AND a.attnum > 0 AND NOT a.attisdropped;
    IF v IS DISTINCT FROM r.sig THEN
      RAISE EXCEPTION 'KAN-714 post: public.% column signature changed', r.vw;
    END IF;
  END LOOP;

  -- events still closed to the API (anon/authenticated), ACL byte-identical to before (KAN-710 grants
  -- service_role, a BYPASSRLS server role; that is unchanged, not widened).
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT')
     OR (SELECT relacl::text FROM pg_class WHERE oid = 'public.events'::regclass)
        IS DISTINCT FROM (SELECT acl FROM pg_temp.kan714_events_acl) THEN
    RAISE EXCEPTION 'KAN-714 post: public.events ACL/policies changed';
  END IF;

  -- Pre-image table closed.
  IF has_table_privilege('anon', 'public.kan714_preimage', 'SELECT')
     OR has_table_privilege('authenticated', 'public.kan714_preimage', 'SELECT')
     OR has_table_privilege('service_role', 'public.kan714_preimage', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-714 post: kan714_preimage readable by an API role';
  END IF;

  SELECT count(*) INTO n FROM pg_index
   WHERE indexrelid IN (to_regclass('public.events_kan714_type_start_id_idx'), to_regclass('public.events_kan714_sport_type_start_idx'))
     AND indisvalid;
  IF n <> 2 THEN
    RAISE EXCEPTION 'KAN-714 post: expected 2 valid events indexes, got %', n;
  END IF;
END
$post$;

COMMIT;

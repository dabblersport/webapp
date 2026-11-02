-- KAN-720 (Events P2, KAN-714 piece B01): v_game_card and v_my_games read SHARED columns from public.events.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review. Local proof:
-- supabase/tests/events_p2/kan714_b01_game_views.sql.
--
-- What this does, in ONE transaction:
--   0. Stage guard: public.events present (KAN-710) with FORCE RLS; KAN-712 cutover live (compat mirror on
--      events, legacy guards on games, games.event_id NOT NULL + FK validated, no NULL event_id); KAN-713 live
--      (access helpers 20261104100000; the location triggers sort after this file); applying role bypasses RLS; both views exist, are owner-run
--      (NOT security_invoker) and owned by postgres.
--   1. Pre-image capture (temp table, ON COMMIT DROP): column signature, owner, ACL, reloptions.
--   2. CREATE OR REPLACE VIEW for both. Every SHARED column (the columns public.events owns) is read from
--      public.events, joined `e.id = g.event_id AND e.event_type = 'game'` (INNER: games.event_id is NOT NULL
--      and FK-validated since KAN-712 cutover, so no game row is lost; the type filter means a meetup parent can
--      never surface and a game appears once — events.id is the PK). Subtype-only columns stay on games.
--      games.id stays the row id. events.min_skill/max_skill are smallint and are cast back to integer.
--      Subqueries, predicates and joins are otherwise byte-for-byte the previous definitions with g.<shared>
--      replaced by e.<shared>; no subquery is added (the events read is one join, not a per-row lookup).
--   3. Post-conditions: column signature, owner, ACL, reloptions identical to the pre-image; neither view
--      references any games column that public.events also owns (except id); both depend on public.events.
--
-- Security: both views are owner-run (postgres, BYPASSRLS) exactly as before — security_invoker is NOT set on
-- either (asserted). API roles therefore need no grant on public.events, and none is added. No GRANT, no
-- REVOKE, no policy, no RPC, no DROP, no data mutation.
--
-- Columns (per view) — events (e.) vs games (g.):
--   v_game_card  e.: title, start_at, end_at, capacity, min_skill::int, max_skill::int, listing_visibility,
--                    join_policy, is_cancelled, created_at, updated_at, sport_id, creator_profile_id,
--                    geo_location_id, area_id, venue_id, joining_rule, cost_cover; total_slots = e.capacity +
--                    g.bench_slots; is_creator and the WHERE gate use e.creator_user_id / e.listing_visibility;
--                    sports/profiles/areas/venues/geo_locations joins key on e.*.
--                g.: id, game_type, bench_slots, allow_spectators, allows_waitlist, rules, sport_variant_id,
--                    venue_space_id, price_aed, series_id, squad_id (WHERE gate).
--   v_my_games   e.: title, start_at, end_at, capacity, is_cancelled, listing_visibility, join_policy,
--                    created_at, sport_id, creator_profile_id, creator_user_id, area_id, venue_id; WHERE uses
--                    e.creator_user_id.
--                g.: id, game_type, venue_space_id.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-720: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;

  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-720: public.events missing (KAN-710 not applied)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.events'::regclass AND relrowsecurity AND relforcerowsecurity) THEN
    RAISE EXCEPTION 'KAN-720: public.events is not RLS-enabled + FORCE (KAN-710 security model changed; stop)';
  END IF;

  -- KAN-712 stage B (cutover) markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events', 'trg_zz_kan712_events_compat_mirror'),
      ('public.games',  'trg_zz_kan712_games_guard')) AS t(tbl, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.tbl::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      RAISE EXCEPTION 'KAN-720: KAN-712 cutover not live (% on % missing or disabled)', r.tg, r.tbl;
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    RAISE EXCEPTION 'KAN-720: KAN-712 write contract not applied (public.kan712_wrapped_rpcs missing)';
  END IF;
  IF (SELECT count(*) FROM pg_constraint
       WHERE conrelid = 'public.games'::regclass AND conname IN ('games_event_id_not_null', 'games_event_id_fkey') AND convalidated) <> 2 THEN
    RAISE EXCEPTION 'KAN-720: games.event_id NOT NULL / FK not validated (KAN-711 validate_links)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'KAN-720: games rows with NULL event_id; the INNER join would drop them';
  END IF;

  -- KAN-713 live: access helpers (20261104100000, which sorts immediately before this file). The KAN-713
  -- location triggers (20261104110000) sort AFTER this file, so they are deliberately not required here;
  -- neither view reads anything they maintain beyond columns the compat mirror already keeps exact.
  IF to_regprocedure('public._can_view_game(uuid)') IS NULL
     OR to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-720: KAN-713 access helpers not live (20261104100000 not applied)';
  END IF;

  -- Both views exist, owned by postgres, owner-run (security_invoker NOT set). If either became
  -- security_invoker, API roles could not read public.events (FORCE RLS, no grants): decision required, stop.
  FOR r IN SELECT unnest(ARRAY['public.v_game_card', 'public.v_my_games']) AS v LOOP
    IF to_regclass(r.v) IS NULL THEN
      RAISE EXCEPTION 'KAN-720: % missing', r.v;
    END IF;
    IF (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = r.v::regclass) <> 'postgres' THEN
      RAISE EXCEPTION 'KAN-720: % not owned by postgres', r.v;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class c, unnest(coalesce(c.reloptions, '{}')) o
                WHERE c.oid = r.v::regclass AND o ~* '^security_invoker=(true|on|1|yes)$') THEN
      RAISE EXCEPTION 'KAN-720: % is security_invoker; API roles cannot read public.events — decision_required, stop', r.v;
    END IF;
  END LOOP;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan720_pre ON COMMIT DROP AS
SELECT c.relname,
       (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
          FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
       pg_get_userbyid(c.relowner) AS owner,
       c.relacl::text AS acl,
       coalesce(c.reloptions::text, '') AS opts
  FROM pg_class c
 WHERE c.oid IN ('public.v_game_card'::regclass, 'public.v_my_games'::regclass);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Views
-- ---------------------------------------------------------------------------------------------------------
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
    st_y(gl.location::geometry) AS latitude,
    st_x(gl.location::geometry) AS longitude,
    (( SELECT count(*) AS count
           FROM public.favorites f
          WHERE f.game_id = g.id))::integer AS favorite_count,
    (EXISTS ( SELECT 1
           FROM public.favorites f
          WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
    g.price_aed,
    g.series_id,
    CASE WHEN s2.id IS NULL THEN NULL WHEN s2.rrule LIKE '%INTERVAL=2%' THEN 'biweekly' ELSE 'weekly' END AS series_frequency,
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

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  r record;
  v_now record;
  v_bad text;
BEGIN
  IF (SELECT count(*) FROM kan720_pre) <> 2 THEN
    RAISE EXCEPTION 'KAN-720 post: pre-image incomplete';
  END IF;
  FOR r IN SELECT * FROM kan720_pre LOOP
    SELECT (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
              FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
           pg_get_userbyid(c.relowner) AS owner, c.relacl::text AS acl, coalesce(c.reloptions::text, '') AS opts
      INTO v_now
      FROM pg_class c WHERE c.oid = ('public.' || r.relname)::regclass;
    IF v_now.sig IS DISTINCT FROM r.sig THEN
      RAISE EXCEPTION 'KAN-720 post: % column signature changed: % -> %', r.relname, r.sig, v_now.sig;
    END IF;
    IF v_now.owner IS DISTINCT FROM r.owner OR v_now.acl IS DISTINCT FROM r.acl OR v_now.opts IS DISTINCT FROM r.opts THEN
      RAISE EXCEPTION 'KAN-720 post: % owner/ACL/reloptions changed', r.relname;
    END IF;

    -- Depends on public.events.
    IF NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                    WHERE rw.ev_class = ('public.' || r.relname)::regclass AND d.refobjid = 'public.events'::regclass) THEN
      RAISE EXCEPTION 'KAN-720 post: % does not read public.events', r.relname;
    END IF;

    -- No games column that events also owns is referenced (games.id, the subtype id, excepted).
    SELECT string_agg(DISTINCT a.attname, ',') INTO v_bad
      FROM pg_depend d
      JOIN pg_rewrite rw ON rw.oid = d.objid
      JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
     WHERE rw.ev_class = ('public.' || r.relname)::regclass
       AND d.refobjid = 'public.games'::regclass
       AND a.attname <> 'id'
       AND a.attname IN (SELECT ea.attname FROM pg_attribute ea
                          WHERE ea.attrelid = 'public.events'::regclass AND ea.attnum > 0 AND NOT ea.attisdropped);
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'KAN-720 post: % still reads shared games columns: %', r.relname, v_bad;
    END IF;
  END LOOP;
  RAISE NOTICE 'KAN-720: v_game_card and v_my_games now read shared columns from public.events';
END
$post$;

COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- ROLLBACK (manual; NOT executed by this migration). Restores the previous definitions verbatim:
-- v_game_card from 20261101120000_kan698_v_game_card_series_columns.sql:10, v_my_games from
-- 20260829080500_baseline_schema.sql:25861. CREATE OR REPLACE keeps owner, ACL and reloptions; no data is
-- touched. Run as postgres: strip the leading "-- " from the lines between the markers.
-- KAN720-ROLLBACK-BEGIN
-- BEGIN;
-- CREATE OR REPLACE VIEW public.v_game_card AS
--  SELECT g.id,
--     g.title,
--     g.game_type,
--     g.start_at,
--     g.end_at,
--     g.capacity,
--     g.bench_slots,
--     g.capacity + g.bench_slots AS total_slots,
--     g.min_skill,
--     g.max_skill,
--     g.listing_visibility,
--     g.join_policy,
--     g.allow_spectators,
--     g.allows_waitlist,
--     g.is_cancelled,
--     g.rules,
--     g.created_at,
--     g.updated_at,
--     g.sport_id,
--     s.sport_key,
--     s.name_en AS sport_name_en,
--     s.name_ar AS sport_name_ar,
--     g.sport_variant_id,
--     sv.variant_key,
--     sv.name_en AS variant_name_en,
--     sv.name_ar AS variant_name_ar,
--     sv.required_players,
--     sv.players_per_side,
--     g.creator_profile_id,
--     cp.username AS creator_username,
--     cp.display_name AS creator_display_name,
--     cp.avatar_url AS creator_avatar_url,
--     g.geo_location_id,
--     g.area_id,
--     a.name AS area_name,
--     g.venue_space_id,
--     g.venue_id,
--     vs.name_en AS venue_space_name,
--     v.name_en AS venue_name,
--     g.joining_rule,
--     g.cost_cover,
--     ( SELECT count(*) AS count
--            FROM game_roster gr
--           WHERE gr.game_id = g.id AND gr.status = 'active'::text AND (gr.role = 'player'::text OR gr.role = 'host'::text AND g.game_type = 'hosted'::text)) AS roster_count,
--     g.creator_user_id = auth.uid() AS is_creator,
--     (EXISTS ( SELECT 1
--            FROM game_roster grv
--           WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined,
--     COALESCE(( SELECT pv.verified
--            FROM profile_verifications pv
--           WHERE pv.profile_id = g.creator_profile_id), false) OR (EXISTS ( SELECT 1
--            FROM organiser o
--           WHERE o.profile_id = g.creator_profile_id AND o.sport = s.sport_key AND o.is_verified AND o.is_active)) AS host_verified,
--     (EXISTS ( SELECT 1
--            FROM likes lk
--           WHERE lk.parent_activity_id = g.id AND lk.actor_user_id = auth.uid())) AS liked_by_me,
--     st_y(gl.location::geometry) AS latitude,
--     st_x(gl.location::geometry) AS longitude,
--     (( SELECT count(*) AS count
--            FROM favorites f
--           WHERE f.game_id = g.id))::integer AS favorite_count,
--     (EXISTS ( SELECT 1
--            FROM favorites f
--           WHERE f.game_id = g.id AND f.user_id = auth.uid())) AS favourited_by_me,
--     g.price_aed,
--     g.series_id,
--     CASE WHEN s2.id IS NULL THEN NULL WHEN s2.rrule LIKE '%INTERVAL=2%' THEN 'biweekly' ELSE 'weekly' END AS series_frequency,
--     s2.ends_on AS series_ends_on
--    FROM games g
--      LEFT JOIN sports s ON s.id = g.sport_id
--      LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
--      LEFT JOIN profiles cp ON cp.id = g.creator_profile_id
--      LEFT JOIN areas a ON a.id = g.area_id
--      LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
--      LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, g.venue_id)
--      LEFT JOIN geo_locations gl ON gl.id = g.geo_location_id
--      LEFT JOIN game_series s2 ON s2.id = g.series_id
--   WHERE g.creator_user_id = auth.uid() OR is_admin(auth.uid()) OR (EXISTS ( SELECT 1
--            FROM game_roster grm
--           WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
--            FROM game_waitlist gw
--           WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id);
-- 
-- CREATE OR REPLACE VIEW "public"."v_my_games" AS
--  SELECT "g"."id",
--     "g"."title",
--     "g"."game_type",
--     "g"."start_at",
--     "g"."end_at",
--     "g"."capacity",
--     "g"."is_cancelled",
--     "g"."listing_visibility",
--     "g"."join_policy",
--     "g"."created_at",
--     "g"."sport_id",
--     "s"."sport_key",
--     "s"."name_en" AS "sport_name_en",
--     "s"."name_ar" AS "sport_name_ar",
--     "g"."creator_profile_id",
--     "g"."creator_user_id",
--     "g"."area_id",
--     "a"."name" AS "area_name",
--     "g"."venue_id",
--     "v"."name_en" AS "venue_name",
--     "gr"."status" AS "my_roster_status"
--    FROM ((((("public"."games" "g"
--      LEFT JOIN "public"."sports" "s" ON (("s"."id" = "g"."sport_id")))
--      LEFT JOIN "public"."areas" "a" ON (("a"."id" = "g"."area_id")))
--      LEFT JOIN "public"."venue_spaces" "vs" ON (("vs"."id" = "g"."venue_space_id")))
--      LEFT JOIN "public"."venues" "v" ON (("v"."id" = COALESCE("vs"."venue_id", "g"."venue_id"))))
--      LEFT JOIN "public"."game_roster" "gr" ON ((("gr"."game_id" = "g"."id") AND ("gr"."user_id" = "auth"."uid"()))))
--   WHERE (("g"."creator_user_id" = "auth"."uid"()) OR ("gr"."user_id" = "auth"."uid"()));
-- COMMIT;
-- KAN720-ROLLBACK-END

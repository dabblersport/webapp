-- KAN-726 (Events P2, KAN-714 piece B07): rpc_sport_overview game/meetup counts and the per-host game count
-- reader (v_host_weekly_metrics) read SHARED columns from public.events.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review. Local proof:
-- supabase/tests/events_p2/kan714_b07_sport_overview.sql.
--
-- Pre-images (latest definitions in this repository; nothing later in migrations/ redefines either):
--   rpc_sport_overview(uuid,text)  20261021115000_sport_overview_counts.sql:40 (ACL :116-118). It has NO count
--                                  helper functions: every count is an inline scalar subquery of that body.
--   v_host_weekly_metrics          20260829080500_baseline_schema.sql:25662 (owner :25698, ACL :38784-38786).
--                                  The only server-side reader that counts a profile's (host's) games.
--
-- Not KAN-712-wrapped: KAN-712 wraps only the 11 UPDATE-path RPCs (20261103110000_kan712_cutover.sql:102-112);
-- rpc_sport_overview is read-only and is not among them. The guard below refuses if
-- public.kan712_wrapped_rpcs lists it or a rpc_sport_overview_kan712_inner exists, because a bare
-- CREATE OR REPLACE would then clobber the wrapper (KAN712_CONTRACT.md §2).
--
-- What this does, in ONE transaction:
--   0. Stage guard: public.events present (KAN-710) with FORCE RLS; KAN-712 cutover live (compat mirror on events,
--      legacy guard on games and meetups, games/meetups.event_id NOT NULL + FK validated, no NULL event_id);
--      KAN-713 access helpers live (dependency KAN-713); applying role bypasses RLS; rpc_sport_overview exists,
--      is SECURITY DEFINER, STABLE, plpgsql, search_path pinned to (public, pg_temp), owned by postgres, not
--      wrapped, and its body is the 20261021115000 body or this file's body (md5 of prosrc) — anything else
--      means someone redefined it after 20261021115000 and this file would clobber that: stop;
--      v_host_weekly_metrics exists, owner-run (NOT security_invoker), owned by postgres; and NO games / meetups
--      row disagrees with its events parent on any column this file starts reading from events.
--   1. Pre-image capture (temp table, ON COMMIT DROP): function identity args, result, language, SECURITY
--      DEFINER, volatility, parallel, leakproof, strict, cost, rows, proconfig, owner, ACL, comment; view column
--      signature, owner, ACL, reloptions.
--   2. CREATE OR REPLACE FUNCTION rpc_sport_overview: the games_next7 and meetups_next7 subqueries join
--      `e.id = g.event_id AND e.event_type = 'game'` / `e.id = m.event_id AND e.event_type = 'meetup'` (INNER:
--      event_id is NOT NULL and FK-validated since the KAN-712 cutover, so no row is lost; events.id is the PK,
--      so the join yields at most one parent per row and cannot inflate count(DISTINCT g.id) / count(DISTINCT m.id);
--      the type filter means a parent of the other type never counts) and read sport_id, is_cancelled,
--      listing_visibility, start_at, creator_user_id and area_id from e. Every other subquery (followers, venues,
--      spaces, posts, news, mutual_followers), the 42501 anon gate, v_window and the attributes are unchanged.
--      CREATE OR REPLACE keeps owner, ACL and comment; attributes are restated verbatim and asserted.
--   3. CREATE OR REPLACE VIEW v_host_weekly_metrics: CTE g reads creator_user_id, start_at, capacity and
--      is_cancelled from events (same join); g.id stays the games id, so the game_roster join is unchanged.
--      Dependents (v_top_hosts_week, award_top_host_weekly) read only this view's columns, which keep name,
--      type and order (asserted).
--   4. Post-conditions: everything in the pre-image identical; the function body joins events for both types and
--      names no g./m. shared column; the view depends on public.events and on no games column events also owns
--      (games.id excepted).
--
-- Security: rpc_sport_overview stays SECURITY DEFINER (owner postgres, BYPASSRLS) and the view stays owner-run, so
-- API roles need no grant on public.events (FORCE RLS, no API grants) and none is added. No GRANT, no REVOKE, no
-- policy, no DROP, no data mutation. Result shapes unchanged.
--
-- Provenance after this file — events (e.) vs subtype:
--   rpc_sport_overview  games_next7:   e.sport_id, e.is_cancelled, e.listing_visibility, e.start_at,
--                                      e.creator_user_id, e.area_id; g.id (count key), g.event_id (join key).
--                       meetups_next7: the same e. columns; m.id (count key), m.event_id (join key).
--                       followers / venues / spaces / posts / news / mutual_followers: no games/meetups read.
--   v_host_weekly_metrics  e.creator_user_id (host_user_id), e.start_at (week/isoyear/week), e.capacity,
--                          e.is_cancelled; g.id (row key, game_roster join), g.event_id (join key).

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  r record;
  v_drift bigint;
  f oid := to_regprocedure('public.rpc_sport_overview(uuid,text)');
  p record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-726: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;

  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-726: public.events missing (KAN-710 not applied)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.events'::regclass AND relrowsecurity AND relforcerowsecurity) THEN
    RAISE EXCEPTION 'KAN-726: public.events is not RLS-enabled + FORCE (KAN-710 security model changed; stop)';
  END IF;

  -- KAN-712 stage B (cutover) markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard')) AS t(tbl, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.tbl::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      RAISE EXCEPTION 'KAN-726: KAN-712 cutover not live (% on % missing or disabled)', r.tg, r.tbl;
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    RAISE EXCEPTION 'KAN-726: KAN-712 write contract not applied (public.kan712_wrapped_rpcs missing)';
  END IF;
  FOR r IN SELECT * FROM (VALUES ('games'), ('meetups')) AS t(tbl) LOOP
    IF (SELECT count(*) FROM pg_constraint
         WHERE conrelid = ('public.' || r.tbl)::regclass
           AND conname IN (r.tbl || '_event_id_not_null', r.tbl || '_event_id_fkey') AND convalidated) <> 2 THEN
      RAISE EXCEPTION 'KAN-726: %.event_id NOT NULL / FK not validated (KAN-711 validate_links)', r.tbl;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM public.games WHERE event_id IS NULL) OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'KAN-726: games/meetups rows with NULL event_id; the INNER join would drop them';
  END IF;

  -- KAN-713 live: access helpers (20261104100000), the same dependency marker B01/B02 use.
  IF to_regprocedure('public._can_view_game(uuid)') IS NULL
     OR to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-726: KAN-713 access helpers not live (20261104100000 not applied)';
  END IF;

  -- rpc_sport_overview: present, unwrapped, definer, expected attributes, expected body.
  IF f IS NULL THEN
    RAISE EXCEPTION 'KAN-726: public.rpc_sport_overview(uuid,text) missing (20261021115000 not applied)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_sport_overview')
     OR EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_sport_overview_kan712_inner') THEN
    RAISE EXCEPTION 'KAN-726: rpc_sport_overview is KAN-712-wrapped; change it via kan712_unwrap_rpc/kan712_wrap_rpc — decision_required, stop';
  END IF;
  SELECT pr.prosecdef, pr.provolatile, pr.proconfig, l.lanname, pg_get_userbyid(pr.proowner) AS owner, md5(pr.prosrc) AS h
    INTO p FROM pg_proc pr JOIN pg_language l ON l.oid = pr.prolang WHERE pr.oid = f;
  IF NOT p.prosecdef THEN
    RAISE EXCEPTION 'KAN-726: rpc_sport_overview is SECURITY INVOKER; API roles cannot read public.events — decision_required, stop';
  END IF;
  IF p.provolatile <> 's' OR p.lanname <> 'plpgsql' OR p.owner <> 'postgres'
     OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
    RAISE EXCEPTION 'KAN-726: rpc_sport_overview attributes drifted from 20261021115000 (volatility %, language %, owner %, config %); stop',
      p.provolatile, p.lanname, p.owner, p.proconfig;
  END IF;
  -- 1ba644... = prosrc of 20261021115000:40-112; e7eb36... = prosrc of this file (idempotent re-apply).
  IF p.h NOT IN ('1ba644397046241ae6c1f7f81c5bc9b7', 'e7eb361a30f342e9e98df7b944638787') THEN
    RAISE EXCEPTION 'KAN-726: rpc_sport_overview body (md5 %) is neither 20261021115000 nor this file; it was redefined elsewhere — stop', p.h;
  END IF;

  -- v_host_weekly_metrics: present, postgres-owned, owner-run.
  IF to_regclass('public.v_host_weekly_metrics') IS NULL THEN
    RAISE EXCEPTION 'KAN-726: public.v_host_weekly_metrics missing';
  END IF;
  IF (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'public.v_host_weekly_metrics'::regclass) <> 'postgres' THEN
    RAISE EXCEPTION 'KAN-726: v_host_weekly_metrics not owned by postgres';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c, unnest(coalesce(c.reloptions, '{}')) o
              WHERE c.oid = 'public.v_host_weekly_metrics'::regclass AND o ~* '^security_invoker=(true|on|1|yes)$') THEN
    RAISE EXCEPTION 'KAN-726: v_host_weekly_metrics is security_invoker; API roles cannot read public.events — decision_required, stop';
  END IF;

  -- Value equivalence on every column this file moves to events.
  SELECT count(*) INTO v_drift
    FROM public.games g
    LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE e.id IS NULL
      OR (g.sport_id, g.is_cancelled, g.listing_visibility, g.start_at, g.creator_user_id, g.area_id, g.capacity)
         IS DISTINCT FROM
         (e.sport_id, e.is_cancelled, e.listing_visibility, e.start_at, e.creator_user_id, e.area_id, e.capacity);
  IF v_drift <> 0 THEN
    RAISE EXCEPTION 'KAN-726: % games rows disagree with (or lack) their events parent on shared columns; reconcile first', v_drift;
  END IF;
  SELECT count(*) INTO v_drift
    FROM public.meetups m
    LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE e.id IS NULL
      OR (m.sport_id, m.is_cancelled, m.listing_visibility, m.start_at, m.creator_user_id, m.area_id)
         IS DISTINCT FROM
         (e.sport_id, e.is_cancelled, e.listing_visibility, e.start_at, e.creator_user_id, e.area_id);
  IF v_drift <> 0 THEN
    RAISE EXCEPTION 'KAN-726: % meetups rows disagree with (or lack) their events parent on shared columns; reconcile first', v_drift;
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan726_fpre ON COMMIT DROP AS
SELECT pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_arguments(p.oid) AS full_args,
       pg_get_function_result(p.oid) AS result, p.prolang, p.prosecdef, p.provolatile, p.proparallel, p.proleakproof,
       p.proisstrict, p.procost, p.prorows, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl,
       obj_description(p.oid, 'pg_proc') AS comment
  FROM pg_proc p WHERE p.oid = 'public.rpc_sport_overview(uuid,text)'::regprocedure;

CREATE TEMP TABLE kan726_vpre ON COMMIT DROP AS
SELECT (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
          FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
       pg_get_userbyid(c.relowner) AS owner, c.relacl::text AS acl, coalesce(c.reloptions::text, '') AS opts
  FROM pg_class c WHERE c.oid = 'public.v_host_weekly_metrics'::regclass;

-- ---------------------------------------------------------------------------------------------------------
-- 2. rpc_sport_overview
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_sport_overview(p_sport_id uuid, p_city_code text DEFAULT NULL)
 RETURNS TABLE(followers bigint, games_next7 bigint, meetups_next7 bigint, venues bigint, spaces bigint,
               posts bigint, news bigint, mutual_followers jsonb)
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
-- 3. v_host_weekly_metrics
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_host_weekly_metrics AS
 WITH g AS (
         SELECT g_1.id,
            e.creator_user_id AS host_user_id,
            (date_trunc('week'::text, e.start_at))::date AS week_start,
            (date_part('isoyear'::text, e.start_at))::integer AS isoy,
            (date_part('week'::text, e.start_at))::integer AS isow,
            e.capacity,
            e.is_cancelled
           FROM public.games g_1
             JOIN public.events e ON e.id = g_1.event_id AND e.event_type = 'game'::text
        ), r AS (
         SELECT game_roster.game_id,
            count(*) FILTER (WHERE (game_roster.status = 'active'::text)) AS active_cnt
           FROM public.game_roster
          GROUP BY game_roster.game_id
        ), m AS (
         SELECT g.host_user_id AS user_id,
            g.isoy,
            g.isow,
            count(*) FILTER (WHERE (NOT g.is_cancelled)) AS games_hosted,
            round(avg(GREATEST(0.0, LEAST(1.0, (COALESCE((r.active_cnt)::numeric, (0)::numeric) / (NULLIF(g.capacity, 0))::numeric)))), 3) AS fill_rate
           FROM (g
             LEFT JOIN r ON ((r.game_id = g.id)))
          GROUP BY g.host_user_id, g.isoy, g.isow
        )
 SELECT user_id,
    isoy,
    isow,
    games_hosted,
    fill_rate
   FROM m;

-- ---------------------------------------------------------------------------------------------------------
-- 4. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  pre kan726_fpre%ROWTYPE;
  now_f record;
  vpre kan726_vpre%ROWTYPE;
  now_v record;
  v_src text;
  v_bad text;
BEGIN
  SELECT * INTO pre FROM kan726_fpre;
  IF NOT FOUND THEN RAISE EXCEPTION 'KAN-726 post: function pre-image missing'; END IF;
  SELECT pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_arguments(p.oid) AS full_args,
         pg_get_function_result(p.oid) AS result, p.prolang, p.prosecdef, p.provolatile, p.proparallel, p.proleakproof,
         p.proisstrict, p.procost, p.prorows, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl,
         obj_description(p.oid, 'pg_proc') AS comment, p.prosrc
    INTO now_f FROM pg_proc p WHERE p.oid = 'public.rpc_sport_overview(uuid,text)'::regprocedure;
  IF (now_f.args, now_f.full_args, now_f.result, now_f.prolang, now_f.prosecdef, now_f.provolatile, now_f.proparallel,
      now_f.proleakproof, now_f.proisstrict, now_f.procost, now_f.prorows, now_f.proconfig, now_f.owner, now_f.acl, now_f.comment)
     IS DISTINCT FROM
     (pre.args, pre.full_args, pre.result, pre.prolang, pre.prosecdef, pre.provolatile, pre.proparallel,
      pre.proleakproof, pre.proisstrict, pre.procost, pre.prorows, pre.proconfig, pre.owner, pre.acl, pre.comment) THEN
    RAISE EXCEPTION 'KAN-726 post: rpc_sport_overview signature/result/attributes/owner/ACL/comment changed';
  END IF;
  IF has_function_privilege('anon', 'public.rpc_sport_overview(uuid,text)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-726 post: anon can EXECUTE rpc_sport_overview';
  END IF;
  v_src := now_f.prosrc;
  IF position('JOIN public.events e ON e.id = g.event_id AND e.event_type = ''game''' IN v_src) = 0
     OR position('JOIN public.events e ON e.id = m.event_id AND e.event_type = ''meetup''' IN v_src) = 0 THEN
    RAISE EXCEPTION 'KAN-726 post: rpc_sport_overview does not join public.events for both types';
  END IF;
  IF v_src ~ '\m[gm]\.(sport_id|is_cancelled|listing_visibility|start_at|end_at|creator_user_id|creator_profile_id|area_id)\M' THEN
    RAISE EXCEPTION 'KAN-726 post: rpc_sport_overview still reads a shared games/meetups column';
  END IF;

  SELECT * INTO vpre FROM kan726_vpre;
  SELECT (SELECT string_agg(a.attnum || ':' || a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
            FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS sig,
         pg_get_userbyid(c.relowner) AS owner, c.relacl::text AS acl, coalesce(c.reloptions::text, '') AS opts
    INTO now_v FROM pg_class c WHERE c.oid = 'public.v_host_weekly_metrics'::regclass;
  IF (now_v.sig, now_v.owner, now_v.acl, now_v.opts) IS DISTINCT FROM (vpre.sig, vpre.owner, vpre.acl, vpre.opts) THEN
    RAISE EXCEPTION 'KAN-726 post: v_host_weekly_metrics signature/owner/ACL/reloptions changed (% -> %)', row_to_json(vpre), row_to_json(now_v);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid = d.objid
                  WHERE rw.ev_class = 'public.v_host_weekly_metrics'::regclass AND d.refobjid = 'public.events'::regclass) THEN
    RAISE EXCEPTION 'KAN-726 post: v_host_weekly_metrics does not read public.events';
  END IF;
  SELECT string_agg(DISTINCT a.attname, ',') INTO v_bad
    FROM pg_depend d
    JOIN pg_rewrite rw ON rw.oid = d.objid
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE rw.ev_class = 'public.v_host_weekly_metrics'::regclass
     AND d.refobjid = 'public.games'::regclass
     AND a.attname <> 'id'
     AND a.attname IN (SELECT ea.attname FROM pg_attribute ea
                        WHERE ea.attrelid = 'public.events'::regclass AND ea.attnum > 0 AND NOT ea.attisdropped);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-726 post: v_host_weekly_metrics still reads shared games columns: %', v_bad;
  END IF;
  RAISE NOTICE 'KAN-726: rpc_sport_overview game/meetup counts and v_host_weekly_metrics now read shared columns from public.events';
END
$post$;

COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- ROLLBACK (manual; NOT executed by this migration). Restores the previous definitions verbatim:
-- rpc_sport_overview from 20261021115000_sport_overview_counts.sql:40-112 and v_host_weekly_metrics from
-- 20260829080500_baseline_schema.sql:25662-25695. CREATE OR REPLACE keeps owner, ACL and comment. No data is
-- touched. Run as postgres: strip the leading "-- " from the lines between the markers.
-- KAN726-ROLLBACK-BEGIN
-- BEGIN;
-- CREATE OR REPLACE FUNCTION public.rpc_sport_overview(p_sport_id uuid, p_city_code text DEFAULT NULL)
--  RETURNS TABLE(followers bigint, games_next7 bigint, meetups_next7 bigint, venues bigint, spaces bigint,
--                posts bigint, news bigint, mutual_followers jsonb)
--  LANGUAGE plpgsql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
-- DECLARE
--   v_uid    uuid := auth.uid();
--   v_window interval := interval '7 days';
--   v_key    text;
--   v_city   text := p_city_code;
-- BEGIN
--   IF v_uid IS NULL THEN
--     RAISE EXCEPTION 'permission denied for function rpc_sport_overview' USING ERRCODE = '42501';
--   END IF;
--
--   SELECT s.sport_key INTO v_key FROM public.sports s WHERE s.id = p_sport_id;
--
--   RETURN QUERY
--   SELECT
--     (SELECT count(DISTINCT p.id) FROM public.profiles p
--       WHERE p.interests @> ARRAY[p_sport_id]
--         AND NOT public.is_blocked(v_uid, p.user_id)),
--
--     (SELECT count(DISTINCT g.id) FROM public.games g
--        LEFT JOIN public.areas a ON a.id = g.area_id
--       WHERE g.sport_id = p_sport_id AND g.is_cancelled = false
--         AND g.listing_visibility = 'public'
--         AND g.start_at >= now() AND g.start_at < now() + v_window
--         AND NOT public.is_blocked(v_uid, g.creator_user_id)
--         AND (v_city IS NULL OR a.city_code = v_city)),
--
--     (SELECT count(DISTINCT m.id) FROM public.meetups m
--        LEFT JOIN public.areas a ON a.id = m.area_id
--       WHERE m.sport_id = p_sport_id AND m.is_cancelled = false
--         AND m.listing_visibility = 'public'
--         AND m.start_at >= now() AND m.start_at < now() + v_window
--         AND NOT public.is_blocked(v_uid, m.creator_user_id)
--         AND (v_city IS NULL OR a.city_code = v_city)),
--
--     (SELECT count(DISTINCT v.id) FROM public.venues v
--        LEFT JOIN public.areas a ON a.id = v.area_id
--       WHERE v.is_active = true
--         AND (v_city IS NULL OR a.city_code = v_city)
--         AND ( (v_key IS NOT NULL AND v.sports @> ARRAY[v_key])
--               OR EXISTS (SELECT 1 FROM public.venue_spaces vs
--                           WHERE vs.venue_id = v.id AND vs.sport_id = p_sport_id AND vs.is_active = true) )),
--
--     (SELECT count(DISTINCT vs.id) FROM public.venue_spaces vs
--        JOIN public.venues v ON v.id = vs.venue_id AND v.is_active = true
--        LEFT JOIN public.areas a ON a.id = v.area_id
--       WHERE vs.sport_id = p_sport_id AND vs.is_active = true
--         AND (v_city IS NULL OR a.city_code = v_city)),
--
--     (SELECT count(DISTINCT po.id) FROM public.posts po
--       WHERE po.sport_id = p_sport_id AND po.visibility = 'public'
--         AND po.is_deleted = false AND po.is_hidden_admin = false
--         AND coalesce(po.is_active, true) = true
--         AND (po.expires_at IS NULL OR po.expires_at > now())
--         AND NOT public.is_blocked(v_uid, po.author_user_id)),
--
--     (SELECT count(DISTINCT n.id) FROM public.news n
--        LEFT JOIN public.areas a ON a.id = n.area_id
--       WHERE n.sport_id = p_sport_id AND n.status = 'published'
--         AND n.published_at <= now() AND (n.expires_at IS NULL OR n.expires_at > now())
--         AND (v_city IS NULL OR a.city_code = v_city)),
--
--     coalesce((SELECT jsonb_agg(jsonb_build_object('display_name', x.display_name,
--                                                   'avatar_url', x.avatar_url,
--                                                   'username', x.username::text) ORDER BY x.username)
--                 FROM (SELECT DISTINCT ON (p.id) p.id, p.display_name, p.avatar_url, p.username
--                         FROM public.profile_follows f
--                         JOIN public.profiles me ON me.id = f.follower_profile_id AND me.user_id = v_uid
--                         JOIN public.profiles p  ON p.id = f.following_profile_id
--                        WHERE p.interests @> ARRAY[p_sport_id]
--                          AND p.user_id <> v_uid
--                          AND NOT public.is_blocked(v_uid, p.user_id)
--                        ORDER BY p.id
--                        LIMIT 3) x), '[]'::jsonb);
-- END;
-- $function$;
--
-- CREATE OR REPLACE VIEW "public"."v_host_weekly_metrics" AS
--  WITH "g" AS (
--          SELECT "g"."id",
--             "g"."creator_user_id" AS "host_user_id",
--             ("date_trunc"('week'::"text", "g"."start_at"))::"date" AS "week_start",
--             ("date_part"('isoyear'::"text", "g"."start_at"))::integer AS "isoy",
--             ("date_part"('week'::"text", "g"."start_at"))::integer AS "isow",
--             "g"."capacity",
--             "g"."is_cancelled"
--            FROM "public"."games" "g"
--         ), "r" AS (
--          SELECT "game_roster"."game_id",
--             "count"(*) FILTER (WHERE ("game_roster"."status" = 'active'::"text")) AS "active_cnt"
--            FROM "public"."game_roster"
--           GROUP BY "game_roster"."game_id"
--         ), "m" AS (
--          SELECT "g"."host_user_id" AS "user_id",
--             "g"."isoy",
--             "g"."isow",
--             "count"(*) FILTER (WHERE (NOT "g"."is_cancelled")) AS "games_hosted",
--             "round"("avg"(GREATEST(0.0, LEAST(1.0, (COALESCE(("r"."active_cnt")::numeric, (0)::numeric) / (NULLIF("g"."capacity", 0))::numeric)))), 3) AS "fill_rate"
--            FROM ("g"
--              LEFT JOIN "r" ON (("r"."game_id" = "g"."id")))
--           GROUP BY "g"."host_user_id", "g"."isoy", "g"."isow"
--         )
--  SELECT "user_id",
--     "isoy",
--     "isow",
--     "games_hosted",
--     "fill_rate"
--    FROM "m";
-- COMMIT;
-- KAN726-ROLLBACK-END

-- KAN-722 (KAN-714 piece B03, Epic KAN-708) — rating / host-metrics views read their SHARED facts from public.events.
--
-- AUTHORED, NOT APPLIED. Local proof only: supabase/tests/events_p2/kan714_b03_rating_views.sql.
-- Rollback: supabase/tests/events_p2/rollback_kan714_b03.sql (restores the pre-image below, verbatim).
--
-- SCOPE, per view (pre-image = baseline 20260829080500_baseline_schema.sql:25639, :25665, :26152; no later
-- migration redefines any of the three):
--   v_rateable_after_game  REPOINTED. Shared columns read: games.creator_user_id, games.end_at
--                          -> events.creator_user_id, events.end_at. Rating eligibility is NOT encoded in this
--                          view (it never filtered on end_at or is_cancelled; end_at is carried in ctx but unused),
--                          so nothing about eligibility changes and no filter is invented. games.end_at and
--                          events.end_at are both NOT NULL for games (events_game_end_required), so there is no
--                          NULL end case to preserve; types are identical (uuid, timestamptz) — no casts needed.
--   v_host_weekly_metrics  REPOINTED. Shared columns read: creator_user_id, start_at, capacity, is_cancelled
--                          -> events.*. Types identical (uuid, timestamptz, integer, boolean).
--   v_game_rating          UNCHANGED, by design. Its only games column is games.id — the subtype id, not a shared
--                          fact (definition: SELECT g.id AS game_id, gra.* FROM games g LEFT JOIN
--                          game_rating_aggregate gra ON gra.game_id = g.id). Joining events would add a scan and
--                          change nothing. Pinned below and asserted untouched.
--   No meetup analogue: none of the three views reads meetups.
--
-- JOIN: games g JOIN events e ON e.id = g.event_id AND e.event_type = 'game'. events.id is the PK, so the join is
-- 1:0..1; the stage guard proves it is exactly 1:1 for every games row (no row lost, none doubled).
-- STRUCTURE: everything except the source of the shared columns is the pre-image verbatim — including
-- v_rateable_after_game's two scalar sub-selects over ctx (pre-existing correlated SubPlans, not added here) and
-- its self-row quirk for a non-host rater (WHERE r.user_id <> uid OR host <> uid). Output shape is enforced by
-- CREATE OR REPLACE VIEW (same names, types, order) and re-asserted.
--
-- ACCESS: all three are OWNER views (reloptions NULL, owner postgres, no security_invoker). public.events is
-- FORCE RLS with zero policies and no API grants; the owner (superuser / BYPASSRLS, asserted) reads it, API callers
-- never touch it directly. v_rateable_after_game keeps anon/authenticated SELECT and its auth.uid() gate;
-- v_host_weekly_metrics / v_game_rating keep NO API SELECT. CREATE OR REPLACE VIEW preserves owner, ACL and
-- reloptions; all three are captured before and asserted equal after. No grant on events is added or changed.
-- KAN-712: none of these views is a wrapped RPC, and no wrapped RPC (kan712_wrapped_rpcs) reads them;
-- the only readers are award_top_host_weekly(text,jsonb) and v_top_hosts_week (both read v_host_weekly_metrics,
-- whose output shape is unchanged). The KAN-712 unwrap/wrap path therefore does not apply.
--
-- ORDERING NOTE: this file sorts BEFORE 20261105100000_kan714_events_parent_reads.sql, whose drift pins
-- (:160-166) hash the games/meetups/events column dependencies of v_host_weekly_metrics and
-- v_rateable_after_game as they are BEFORE this file. After this file those pins no longer match and that
-- migration aborts by design (it would otherwise re-apply an identical rewrite). Reconciling it is that file's
-- owner's change, not this one's.
--
-- No DROP, no CASCADE, no data mutation, no grant change. Single transaction.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_has boolean;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-722: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-722: public.events missing (KAN-710 not applied)';
  END IF;

  -- KAN-712 stage B (cutover) and KAN-713 markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_after_delete'),
      ('public.events',  'trg_kan713_events_location'),
      ('public.games',   'trg_kan713_games_a_location'),
      ('public.games',   'trg_kan713_games_b_joining'),
      ('public.games',   'trg_kan713_games_c_venue_geo'),
      ('public.meetups', 'trg_kan713_meetups_a_location'),
      ('public.meetups', 'trg_kan713_meetups_b_joining')) AS t(rel, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.rel::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      v_missing := v_missing || (r.rel || '.' || r.tg);
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    v_missing := v_missing || 'public.kan712_wrapped_rpcs'::text;
  ELSE
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs)' INTO v_has;
    IF NOT v_has THEN
      v_missing := v_missing || 'public.kan712_wrapped_rpcs (empty: stage B not run)'::text;
    END IF;
  END IF;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    v_missing := v_missing || 'public.kan713_meetup_visible(uuid)'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'KAN-722: prerequisite stage missing: %', array_to_string(v_missing, ', ');
  END IF;

  -- events still closed to the API.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR NOT (SELECT relforcerowsecurity AND relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-722: public.events is no longer closed (policy or API grant present) — re-assess';
  END IF;

  -- Every games row has exactly one parent of event_type 'game' (INNER JOIN loses and doubles nothing).
  IF EXISTS (SELECT 1 FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-722: a games row has no events parent of event_type game';
  END IF;

  -- The view owners must read events past FORCE RLS; the views must stay owner views.
  FOR r IN SELECT c.oid::regclass::text AS obj, c.relowner AS own, c.reloptions FROM pg_class c
            WHERE c.oid IN ('public.v_rateable_after_game'::regclass, 'public.v_host_weekly_metrics'::regclass) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = r.own AND (rolsuper OR rolbypassrls)) THEN
      RAISE EXCEPTION 'KAN-722: owner of % cannot bypass RLS on public.events', r.obj;
    END IF;
    IF coalesce(array_to_string(r.reloptions, ','), '') LIKE '%security_invoker=on%'
       OR coalesce(array_to_string(r.reloptions, ','), '') LIKE '%security_invoker=true%' THEN
      RAISE EXCEPTION 'KAN-722: % is security_invoker; reading events would break API callers — EXCEPTION, stop', r.obj;
    END IF;
  END LOOP;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins on the pre-image (pg-version independent): md5 of the output column signature, and the exact
--    list of public columns each view's rule depends on. Already-applied state fails here too (deps differ).
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('v_rateable_after_game', '1e6a11420e215a3f621928c055996116',
       'game_roster.game_id,game_roster.status,game_roster.user_id,games.creator_user_id,games.end_at,games.id'),
      ('v_host_weekly_metrics', '1d76ace9f1cfce7fda0d9ec3ad7c065f',
       'game_roster.game_id,game_roster.status,games.capacity,games.creator_user_id,games.id,games.is_cancelled,games.start_at'),
      ('v_game_rating',         '98e6f13a1a9a3f74467e722395688334',
       'game_rating_aggregate.composite_score,game_rating_aggregate.dim_counts,game_rating_aggregate.dim_sums,'
       || 'game_rating_aggregate.event_count,game_rating_aggregate.game_id,game_rating_aggregate.last_event_at,games.id'))
      AS t(vw, sig, dep)
  LOOP
    IF to_regclass('public.' || r.vw) IS NULL THEN
      RAISE EXCEPTION 'KAN-722 pin: public.% missing', r.vw;
    END IF;
    SELECT md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)) INTO v
      FROM pg_attribute a WHERE a.attrelid = ('public.' || r.vw)::regclass AND a.attnum > 0 AND NOT a.attisdropped;
    IF v IS DISTINCT FROM r.sig THEN
      RAISE EXCEPTION 'KAN-722 pin: public.% column signature drifted (md5 % expected %)', r.vw, v, r.sig;
    END IF;
    SELECT string_agg(DISTINCT t.relname || '.' || a.attname, ',' ORDER BY t.relname || '.' || a.attname) INTO v
      FROM pg_rewrite rw
      JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
      JOIN pg_class t ON t.oid = d.refobjid AND t.relnamespace = 'public'::regnamespace
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
     WHERE rw.ev_class = ('public.' || r.vw)::regclass;
    IF v IS DISTINCT FROM r.dep THEN
      RAISE EXCEPTION 'KAN-722 pin: public.% column dependencies drifted (got % expected %) — already applied, or the pre-image moved',
        r.vw, v, r.dep;
    END IF;
  END LOOP;
END
$pins$;

-- Attribute capture for the post-conditions (ON COMMIT DROP: nothing persists).
CREATE TEMP TABLE kan722_pre ON COMMIT DROP AS
  SELECT c.oid, c.relname, c.relowner, c.relacl::text AS acl, c.reloptions, md5(pg_get_viewdef(c.oid, false)) AS def
    FROM pg_class c
   WHERE c.oid IN ('public.v_rateable_after_game'::regclass, 'public.v_host_weekly_metrics'::regclass,
                   'public.v_game_rating'::regclass, 'public.events'::regclass);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Views
-- ---------------------------------------------------------------------------------------------------------
SET LOCAL search_path TO public, extensions;

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

-- v_game_rating: intentionally not touched (see header).

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text;
BEGIN
  -- Exact shape, and the new dependency set: no shared games column remains; events is joined by id + type.
  FOR r IN SELECT * FROM (VALUES
      ('v_rateable_after_game', '1e6a11420e215a3f621928c055996116',
       'events.creator_user_id,events.end_at,events.event_type,events.id,game_roster.game_id,game_roster.status,'
       || 'game_roster.user_id,games.event_id,games.id'),
      ('v_host_weekly_metrics', '1d76ace9f1cfce7fda0d9ec3ad7c065f',
       'events.capacity,events.creator_user_id,events.event_type,events.id,events.is_cancelled,events.start_at,'
       || 'game_roster.game_id,game_roster.status,games.event_id,games.id'),
      ('v_game_rating',         '98e6f13a1a9a3f74467e722395688334',
       'game_rating_aggregate.composite_score,game_rating_aggregate.dim_counts,game_rating_aggregate.dim_sums,'
       || 'game_rating_aggregate.event_count,game_rating_aggregate.game_id,game_rating_aggregate.last_event_at,games.id'))
      AS t(vw, sig, dep)
  LOOP
    SELECT md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)) INTO v
      FROM pg_attribute a WHERE a.attrelid = ('public.' || r.vw)::regclass AND a.attnum > 0 AND NOT a.attisdropped;
    IF v IS DISTINCT FROM r.sig THEN
      RAISE EXCEPTION 'KAN-722 post: public.% column signature changed', r.vw;
    END IF;
    SELECT string_agg(DISTINCT t.relname || '.' || a.attname, ',' ORDER BY t.relname || '.' || a.attname) INTO v
      FROM pg_rewrite rw
      JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.objid = rw.oid AND d.refobjsubid > 0
      JOIN pg_class t ON t.oid = d.refobjid AND t.relnamespace = 'public'::regnamespace
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
     WHERE rw.ev_class = ('public.' || r.vw)::regclass;
    IF v IS DISTINCT FROM r.dep THEN
      RAISE EXCEPTION 'KAN-722 post: public.% dependencies are % (expected %)', r.vw, v, r.dep;
    END IF;
  END LOOP;

  -- Owner, ACL, reloptions byte-identical for all three views and for events; v_game_rating definition identical.
  IF EXISTS (SELECT 1 FROM pg_temp.kan722_pre p JOIN pg_class c ON c.oid = p.oid
              WHERE c.relowner <> p.relowner OR c.relacl::text IS DISTINCT FROM p.acl
                 OR c.reloptions IS DISTINCT FROM p.reloptions) THEN
    RAISE EXCEPTION 'KAN-722 post: owner / ACL / reloptions changed on a view or on events';
  END IF;
  IF (SELECT md5(pg_get_viewdef('public.v_game_rating'::regclass, false)))
     IS DISTINCT FROM (SELECT def FROM pg_temp.kan722_pre WHERE relname = 'v_game_rating') THEN
    RAISE EXCEPTION 'KAN-722 post: v_game_rating changed';
  END IF;

  -- events still closed to the API.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-722 post: public.events opened to the API';
  END IF;
  -- Access parity on the views themselves.
  IF NOT has_table_privilege('authenticated', 'public.v_rateable_after_game', 'SELECT')
     OR NOT has_table_privilege('anon', 'public.v_rateable_after_game', 'SELECT')
     OR has_table_privilege('anon', 'public.v_host_weekly_metrics', 'SELECT')
     OR has_table_privilege('authenticated', 'public.v_host_weekly_metrics', 'SELECT')
     OR has_table_privilege('anon', 'public.v_game_rating', 'SELECT')
     OR has_table_privilege('authenticated', 'public.v_game_rating', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-722 post: view SELECT grants differ from the pre-image';
  END IF;
END
$post$;

COMMIT;

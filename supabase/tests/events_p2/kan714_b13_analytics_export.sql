-- KAN-732 (KAN-714 piece B13) test: admin_cleanup_user_data reads game ownership (creator_profile_id) and
-- admin_overview_row reads game creation time (created_at) from public.events.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE. Run as postgres (superuser), psql -v ON_ERROR_STOP=1.
--
-- Load order:
--   tests/events_p1/local_harness_kan711.sql, tests/events_p1/local_seed_kan711.sql,
--   tests/events_p2/local_harness_kan712.sql, tests/events_p2_kan713/local_harness_kan713.sql,
--   tests/events_p2_kan714/local_harness_kan714.sql,
--   migrations 20261101140000, 20261102110000, 20261102120000,
--     CALL public.kan711_events_backfill_run(200); SELECT public.kan711_events_validate_links();
--   migrations 20261103100000, 20261103110000, 20261104100000, 20261104110000, 20261104110300,
--   psql -v fixture_only=1 -f THIS FILE   (admin_overview_row pre-image + what it reads; stops there),
--   migrations/20261104101300_kan714_b13_analytics_admin_export_cleanup.sql,
--   psql -f THIS FILE                     (fixture is a no-op now; then every assertion).
--
-- Flow: seed (idempotent) -> NEW snapshot + probes -> rollback block (verbatim, uncommented copy of the migration's
-- KAN732-ROLLBACK section) -> LEGACY snapshot + the same probes -> compare -> re-apply the migration with \ir ->
-- verify the round trip and data intact. Every call runs in a rolled-back subtransaction, so the file commits only
-- its seed rows and leaves the database migrated.
-- Assertions: T0 precondition, A shape unchanged, B result sets / counts = legacy (games and meetups), nothing
-- doubled, C provenance from events (each probe fails on legacy), D refusals = legacy, E rollback md5 + data intact
-- + re-apply round trip, F plan (one added join, no SubPlan).

\set ON_ERROR_STOP 1
SET client_min_messages = warning;

-- ---------------------------------------------------------------------------------------------------------
-- FIXTURE (idempotent). The KAN-711..714 harness has admin_cleanup_user_data (local_harness_kan712.sql:271,
-- verbatim baseline) but not admin_overview_row or what it reads. Created only when absent:
--   _week_bounds          baseline 20260829080500:1826-1835, grants :34519-34521
--   admin_overview_row    baseline :2515-2583 VERBATIM (the pre-image), grants :34645-34647 (no PUBLIC revoke)
--   v_admin_overview      baseline :25113-25127, grants :38664-38666
--   profiles.profile_type baseline profiles column (the harness profiles table omits it)
--   content_reports(id, status): read by admin_overview_row but CREATED BY NO TRACKED MIGRATION (limitation,
--                         see the KAN-732 report); the two columns the function reads, RLS on, no policy.
-- Load with `psql -v fixture_only=1 -f THIS_FILE` BEFORE the migration; the run stops after this section.
-- ---------------------------------------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_type text;
CREATE TABLE IF NOT EXISTS public.content_reports (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  status text NOT NULL
);
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

SELECT to_regprocedure('public._week_bounds(timestamptz)') IS NULL AS kan732_need_wb,
       to_regprocedure('public.admin_overview_row()') IS NULL AS kan732_need_ov,
       to_regclass('public.v_admin_overview') IS NULL AS kan732_need_v \gset

\if :kan732_need_wb
CREATE OR REPLACE FUNCTION "public"."_week_bounds"("now_ts" timestamp with time zone) RETURNS TABLE("week_start" timestamp with time zone, "week_end" timestamp with time zone)
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select date_trunc('week', now_ts) as week_start,
         date_trunc('week', now_ts) + interval '7 days' as week_end
$$;
ALTER FUNCTION "public"."_week_bounds"("now_ts" timestamp with time zone) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."_week_bounds"("now_ts" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."_week_bounds"("now_ts" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_week_bounds"("now_ts" timestamp with time zone) TO "service_role";
\endif

\if :kan732_need_ov
CREATE OR REPLACE FUNCTION "public"."admin_overview_row"() RETURNS TABLE("snapshot_at" timestamp with time zone, "total_users" bigint, "frozen_users" bigint, "active_users" bigint, "games_created_this_week" bigint, "reports_open" bigint, "reports_resolved" bigint, "verified_profiles_total" bigint, "verified_players" bigint, "verified_organisers" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  wk_start timestamptz;
  wk_end   timestamptz;
begin
  -- Gate: admin only
  if not public.is_admin(auth.uid()) then
    raise exception using errcode = 'P0001', message = 'not_admin';
  end if;

  select week_start, week_end into wk_start, wk_end
  from public._week_bounds(now());

  -- Return single-row snapshot
  return query
  with
  -- Distinct humans inferred from profiles; avoids needing auth.users privileges
  users_distinct as (
    select count(distinct p.user_id)::bigint as c
    from public.profiles p
    where p.is_active = true
  ),
  frozen as (
    select count(distinct f.user_id)::bigint as c
    from public.user_freezes f
    where f.is_frozen = true
      and (f.until is null or now() < f.until)
      and f.lifted_at is null
  ),
  games_week as (
    select count(*)::bigint as c
    from public.games g
    where g.created_at >= wk_start
      and g.created_at <  wk_end
  ),
  reports as (
    select
      count(*) filter (where status in ('open','reviewing'))::bigint as open_c,
      count(*) filter (where status = 'resolved')::bigint          as resolved_c
    from public.content_reports
  ),
  verif as (
    select
      count(*)::bigint                                                     as total_c,
      count(*) filter (where p.profile_type = 'player')::bigint            as players_c,
      count(*) filter (where p.profile_type = 'organiser')::bigint         as organisers_c
    from public.profile_verifications v
    join public.profiles p on p.id = v.profile_id
    where v.verified = true
  )
  select
    now()                                              as snapshot_at,
    (select c from users_distinct)                     as total_users,
    (select c from frozen)                             as frozen_users,
    (select c from users_distinct) - (select c from frozen)  as active_users,
    (select c from games_week)                         as games_created_this_week,
    (select open_c from reports)                       as reports_open,
    (select resolved_c from reports)                   as reports_resolved,
    (select total_c from verif)                        as verified_profiles_total,
    (select players_c from verif)                      as verified_players,
    (select organisers_c from verif)                   as verified_organisers;
end;
$$;

ALTER FUNCTION "public"."admin_overview_row"() OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."admin_overview_row"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_overview_row"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_overview_row"() TO "service_role";
\endif

\if :kan732_need_v
CREATE OR REPLACE VIEW "public"."v_admin_overview" AS
 SELECT "snapshot_at",
    "total_users",
    "frozen_users",
    "active_users",
    "games_created_this_week",
    "reports_open",
    "reports_resolved",
    "verified_profiles_total",
    "verified_players",
    "verified_organisers"
   FROM "public"."admin_overview_row"() "admin_overview_row"("snapshot_at", "total_users", "frozen_users", "active_users", "games_created_this_week", "reports_open", "reports_resolved", "verified_profiles_total", "verified_players", "verified_organisers");
ALTER VIEW "public"."v_admin_overview" OWNER TO "postgres";
GRANT REFERENCES,TRIGGER ON TABLE "public"."v_admin_overview" TO "anon";
GRANT REFERENCES,TRIGGER ON TABLE "public"."v_admin_overview" TO "authenticated";
GRANT ALL ON TABLE "public"."v_admin_overview" TO "service_role";
-- MAINTAIN exists from PG17 (the baseline's server); the local PG16 harness has no such privilege.
DO $mt$ BEGIN
  IF current_setting('server_version_num')::int >= 170000 THEN
    EXECUTE 'GRANT MAINTAIN ON TABLE public.v_admin_overview TO anon, authenticated';
  END IF;
END $mt$;
\endif

\if :{?fixture_only}
\echo 'KAN-732 fixture loaded (fixture_only); stopping before the assertions.'
\quit
\endif
SET client_min_messages = notice;

-- ---------------------------------------------------------------------------------------------------------
-- T0. Preconditions
-- ---------------------------------------------------------------------------------------------------------
DO $t0$
DECLARE v_c text; v_o text;
BEGIN
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'T0 FAIL: run as a superuser (local harness)';
  END IF;
  SELECT md5(prosrc) INTO v_c FROM pg_proc WHERE oid = to_regprocedure('public.admin_cleanup_user_data(uuid,boolean)');
  SELECT md5(prosrc) INTO v_o FROM pg_proc WHERE oid = to_regprocedure('public.admin_overview_row()');
  IF v_c IS DISTINCT FROM '09baee67932be2618af9043c89155db2' OR v_o IS DISTINCT FROM '42573e04bc2aae0af755ded1f8eceb5a' THEN
    RAISE EXCEPTION 'T0 FAIL: migration 20261104101300 not applied (admin_cleanup_user_data md5 %, admin_overview_row md5 %)',
      v_c, v_o;
  END IF;
  IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name IN ('admin_cleanup_user_data', 'admin_overview_row'))
     OR EXISTS (SELECT 1 FROM pg_proc WHERE proname IN ('admin_cleanup_user_data_kan712_inner', 'admin_overview_row_kan712_inner')) THEN
    RAISE EXCEPTION 'T0 FAIL: a target is KAN-712-wrapped';
  END IF;
  IF (SELECT count(*) FROM public.games) = 0 OR (SELECT count(*) FROM public.meetups) = 0 THEN
    RAISE EXCEPTION 'T0 FAIL: harness must hold games and meetups';
  END IF;
  RAISE NOTICE 'T0 PASS preconditions (games=%, meetups=%, events=%, wrapped_rpcs=% and neither target among them; both bodies are the migrated ones)',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events),
    (SELECT count(*) FROM public.kan712_wrapped_rpcs);
END
$t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Seed (idempotent, fixed ids 73200000-...). Games/meetups go through the KAN-712 guard, so each gets its parent.
--   a8/b8  owns games 1,2,3 (this week) + a profile_verifications row  -> the cleanup target
--   a9/b9  owns game 4 + meetup m1                                        -> meetup owner (L-2: 23503 in both)
--   b7     owns game 5 (created 60 days ago: overview provenance target) and game 6 (cleanup provenance target),
--          and meetup m2 created this week (a meetup must never count as a game created this week)
--   content_reports: 2 open, 1 reviewing, 1 resolved
-- ---------------------------------------------------------------------------------------------------------
INSERT INTO auth.users (id) VALUES ('00000000-0000-0000-0000-0000000000a8'), ('00000000-0000-0000-0000-0000000000a9')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.profiles (id, user_id, persona_type, is_active, username, display_name, profile_type)
VALUES ('00000000-0000-0000-0000-0000000000b8', '00000000-0000-0000-0000-0000000000a8', 'player', true, 'user_b8', 'User b8', 'personal'),
       ('00000000-0000-0000-0000-0000000000b9', '00000000-0000-0000-0000-0000000000a9', 'player', true, 'user_b9', 'User b9', 'personal')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
                          join_policy, sport_id, geo_location_id, area_id, min_skill, max_skill, game_type, is_cancelled,
                          created_at)
SELECT ('73200000-0000-0000-0000-00000000000' || f.n)::uuid, 'B13 game ' || f.n,
       ('00000000-0000-0000-0000-0000000000b' || f.who)::uuid, ('00000000-0000-0000-0000-0000000000a' || f.who)::uuid,
       date_trunc('minute', now()) + interval '3 days', date_trunc('minute', now()) + interval '3 days' + interval '1 hour',
       10, 'public', 'open', '00000000-0000-0000-0000-0000000000e1'::uuid,
       '00000000-0000-0000-0000-0000000000d1'::uuid, '00000000-0000-0000-0000-0000000000c1'::uuid, 1, 6, 'pickup', false,
       now() - f.age
  FROM (VALUES (1, '8', interval '0'), (2, '8', interval '0'), (3, '8', interval '0'), (4, '9', interval '0'),
               (5, '7', interval '60 days'), (6, '7', interval '0')) AS f(n, who, age)
 -- NOT EXISTS, not ON CONFLICT: the KAN-712 guard creates the events parent before the games conflict check.
 WHERE NOT EXISTS (SELECT 1 FROM public.games x WHERE x.id = ('73200000-0000-0000-0000-00000000000' || f.n)::uuid);

INSERT INTO public.meetups (id, title, creator_profile_id, creator_user_id, host_actor_id, start_at, end_at,
                            listing_visibility, rsvp_policy, sport_id, geo_location_id, area_id)
SELECT ('73200000-0000-0000-0001-00000000000' || f.n)::uuid, 'B13 meetup ' || f.n,
       ('00000000-0000-0000-0000-0000000000b' || f.who)::uuid, ('00000000-0000-0000-0000-0000000000a' || f.who)::uuid,
       ('00000000-0000-0000-0000-0000000000b' || f.who)::uuid,
       date_trunc('minute', now()) + interval '4 days', date_trunc('minute', now()) + interval '4 days' + interval '1 hour',
       'public', 'open', '00000000-0000-0000-0000-0000000000e1'::uuid,
       '00000000-0000-0000-0000-0000000000d1'::uuid, '00000000-0000-0000-0000-0000000000c1'::uuid
  FROM (VALUES (1, '9'), (2, '7')) AS f(n, who)
 WHERE NOT EXISTS (SELECT 1 FROM public.meetups x WHERE x.id = ('73200000-0000-0000-0001-00000000000' || f.n)::uuid);

INSERT INTO public.profile_verifications (profile_id, verified)
SELECT '00000000-0000-0000-0000-0000000000b8', true
 WHERE NOT EXISTS (SELECT 1 FROM public.profile_verifications WHERE profile_id = '00000000-0000-0000-0000-0000000000b8');

INSERT INTO public.content_reports (id, status)
VALUES ('73200000-0000-0000-00cc-000000000001', 'open'), ('73200000-0000-0000-00cc-000000000002', 'open'),
       ('73200000-0000-0000-00cc-000000000003', 'reviewing'), ('73200000-0000-0000-00cc-000000000004', 'resolved')
ON CONFLICT (id) DO NOTHING;

SELECT 'seed' AS t,
       (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
         WHERE g.id::text LIKE '73200000-0000-0000-0000-%') AS b13_games_with_parent,
       (SELECT count(*) FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
         WHERE m.id::text LIKE '73200000-0000-0000-0001-%') AS b13_meetups_with_parent,
       (SELECT e.created_at < now() - interval '59 days' FROM public.games g JOIN public.events e ON e.id = g.event_id
         WHERE g.id = '73200000-0000-0000-0000-000000000005') AS g5_parent_is_old;

DO $seedchk$
BEGIN
  IF (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
       WHERE g.id::text LIKE '73200000-0000-0000-0000-%' AND (g.creator_profile_id, g.created_at) = (e.creator_profile_id, e.created_at)) <> 6
     OR (SELECT count(*) FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
          WHERE m.id::text LIKE '73200000-0000-0000-0001-%') <> 2 THEN
    RAISE EXCEPTION 'SEED FAIL: B13 games/meetups lack an agreeing events parent';
  END IF;
END
$seedchk$;

-- ---------------------------------------------------------------------------------------------------------
-- Probe machinery. Every call runs inside a plpgsql subtransaction that is ALWAYS rolled back (the result is
-- smuggled out through a private SQLSTATE), so NEW and LEGACY each start from the same committed state.
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan732_res  (phase text, label text, res jsonb, PRIMARY KEY (phase, label));
CREATE TEMP TABLE kan732_meta (phase text, fn text, args text, full_args text, result text, lang text, secdef boolean,
                               vol "char", config text[], owner text, acl text, comment text, src_md5 text,
                               PRIMARY KEY (phase, fn));
CREATE TEMP TABLE kan732_view (phase text PRIMARY KEY, def text, acl text, reloptions text[], owner text);
CREATE TEMP TABLE kan732_data (phase text PRIMARY KEY, games text, events text, meetups text, profiles text,
                               verifications text, reports text, harness_meetup text);
CREATE TEMP TABLE kan732_plan (phase text, stmt text, rels text[], events_scans int, events_node text, subplans int,
                               PRIMARY KEY (phase, stmt));

CREATE FUNCTION pg_temp.kan732_state() RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object(
    'games', (SELECT count(*) FROM public.games), 'events_game', (SELECT count(*) FROM public.events WHERE event_type = 'game'),
    'meetups', (SELECT count(*) FROM public.meetups), 'events_meetup', (SELECT count(*) FROM public.events WHERE event_type = 'meetup'),
    'b13_games_left', (SELECT coalesce(jsonb_agg(right(id::text, 1) ORDER BY id), '[]'::jsonb) FROM public.games
                        WHERE id::text LIKE '73200000-0000-0000-0000-%'),
    'b8_profile', (SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-0000-0000-0000000000b8'),
    'b8_events', (SELECT count(*) FROM public.events WHERE creator_profile_id = '00000000-0000-0000-0000-0000000000b8'),
    'orphan_events', (SELECT count(*) FROM public.events e WHERE e.event_type = 'game'
                        AND NOT EXISTS (SELECT 1 FROM public.games g WHERE g.event_id = e.id)),
    'data_md5', md5((SELECT string_agg(t::text, '|' ORDER BY t.id) FROM public.games t)
                 || (SELECT string_agg(t::text, '|' ORDER BY t.id) FROM public.events t)
                 || (SELECT string_agg(t::text, '|' ORDER BY t.id) FROM public.meetups t)
                 || (SELECT string_agg(t::text, '|' ORDER BY t.id) FROM public.profiles t)
                 || coalesce((SELECT string_agg(t::text, '|' ORDER BY t.profile_id) FROM public.profile_verifications t), '')))
$f$;

-- One case. kind: 'cleanup' (p_target, p_dry) | 'overview' | 'view'. p_prov: 'cleanup' rewrites game 6's events
-- parent creator to b8, 'overview' moves game 5's events parent created_at into this week (mirror disabled, events
-- ONLY — the games rows keep b7 / 60 days ago).
CREATE FUNCTION pg_temp.kan732_try(p_kind text, p_uid uuid, p_target uuid, p_dry boolean, p_prov text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE
  v_out jsonb := '{}'::jsonb;
  v_ev uuid;
  v_g uuid;
  v_ret jsonb;
  v_c text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_prov IS NOT NULL THEN
      v_g := CASE p_prov WHEN 'cleanup' THEN '73200000-0000-0000-0000-000000000006'::uuid
                         ELSE '73200000-0000-0000-0000-000000000005'::uuid END;
      SELECT event_id INTO v_ev FROM public.games WHERE id = v_g;
      ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
      IF p_prov = 'cleanup' THEN
        UPDATE public.events SET creator_profile_id = '00000000-0000-0000-0000-0000000000b8' WHERE id = v_ev;
      ELSE
        UPDATE public.events SET created_at = now() WHERE id = v_ev;
      END IF;
      v_out := v_out || jsonb_build_object(
        'prov_games_side',  (SELECT jsonb_build_object('creator', creator_profile_id, 'this_week', created_at >= date_trunc('week', now()))
                               FROM public.games WHERE id = v_g),
        'prov_events_side', (SELECT jsonb_build_object('creator', creator_profile_id, 'this_week', created_at >= date_trunc('week', now()))
                               FROM public.events WHERE id = v_ev));
    END IF;
    IF p_kind = 'cleanup' THEN
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY o), '[]'::jsonb) INTO v_ret
        FROM public.admin_cleanup_user_data(p_target, p_dry) WITH ORDINALITY AS x(affected_table, affected_column, rows_affected, o);
      v_ret := (SELECT jsonb_agg(e - 'o' ORDER BY (e->>'o')::int) FROM jsonb_array_elements(v_ret) e);
    ELSIF p_kind = 'overview' THEN
      SELECT to_jsonb(x) - 'snapshot_at' INTO v_ret FROM public.admin_overview_row() x;
    ELSE
      SELECT to_jsonb(x) - 'snapshot_at' INTO v_ret FROM public.v_admin_overview x;
    END IF;
    v_out := v_out || jsonb_build_object('ok', true, 'ret', v_ret, 'state', pg_temp.kan732_state());
    RAISE EXCEPTION USING ERRCODE = 'KX732', MESSAGE = v_out::text;
  EXCEPTION
    WHEN SQLSTATE 'KX732' THEN RETURN SQLERRM::jsonb;
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_c = CONSTRAINT_NAME;
      RETURN v_out || jsonb_build_object('ok', false, 'sqlstate', SQLSTATE, 'error', SQLERRM, 'constraint', nullif(v_c, ''));
  END;
END
$f$;

CREATE FUNCTION pg_temp.kan732_run(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c record;
BEGIN
  FOR c IN SELECT * FROM (VALUES
      -- label                 kind        caller (a<n>)                           target user (a<n>)                     dry    prov
      ('B1_cleanup_dry_b8',    'cleanup',  '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a8', true,  NULL),
      ('B2_cleanup_real_b8',   'cleanup',  '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a8', false, NULL),
      ('B3_cleanup_dry_b9',    'cleanup',  '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a9', true,  NULL),
      ('B4_cleanup_real_b9_meetup_owner', 'cleanup', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a9', false, NULL),
      ('B5_cleanup_no_profile','cleanup',  '00000000-0000-0000-0000-0000000000a3', '73200000-0000-0000-00ff-000000000001', false, NULL),
      ('B6_overview_admin',    'overview', '00000000-0000-0000-0000-0000000000a3', NULL, NULL, NULL),
      ('B7_view_admin',        'view',     '00000000-0000-0000-0000-0000000000a3', NULL, NULL, NULL),
      ('C1_prov_cleanup',      'cleanup',  '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a8', false, 'cleanup'),
      ('C2_prov_overview',     'overview', '00000000-0000-0000-0000-0000000000a3', NULL, NULL, 'overview'),
      ('D1_overview_anon',     'overview', NULL, NULL, NULL, NULL),
      ('D2_overview_member',   'overview', '00000000-0000-0000-0000-0000000000a7', NULL, NULL, NULL),
      ('D3_overview_blocked',  'overview', '00000000-0000-0000-0000-0000000000a6', NULL, NULL, NULL),
      ('D4_view_member',       'view',     '00000000-0000-0000-0000-0000000000a7', NULL, NULL, NULL),
      ('D5_cleanup_anon',      'cleanup',  NULL, '00000000-0000-0000-0000-0000000000a8', false, NULL),
      ('D6_cleanup_member',    'cleanup',  '00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000a8', false, NULL),
      ('D7_cleanup_blocked',   'cleanup',  '00000000-0000-0000-0000-0000000000a6', '00000000-0000-0000-0000-0000000000a8', false, NULL),
      ('D8_cleanup_self_prov', 'cleanup',  '00000000-0000-0000-0000-0000000000a8', '00000000-0000-0000-0000-0000000000a8', false, 'cleanup')
    ) AS t(label, kind, uid, target, dry, prov)
  LOOP
    INSERT INTO kan732_res VALUES (p_phase, c.label,
      pg_temp.kan732_try(c.kind, c.uid::uuid, c.target::uuid, c.dry, c.prov));
  END LOOP;
END
$f$;

CREATE FUNCTION pg_temp.kan732_plan(p_phase text, p_stmt text, p_sql text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE v_plan jsonb;
BEGIN
  EXECUTE 'EXPLAIN (FORMAT JSON) ' || p_sql INTO v_plan;
  INSERT INTO kan732_plan SELECT p_phase, p_stmt,
    ARRAY(SELECT DISTINCT x #>> '{}' FROM jsonb_path_query(v_plan, 'strict $.**."Relation Name"') x ORDER BY 1),
    (SELECT count(*) FROM jsonb_path_query(v_plan, 'strict $.** ? (@."Relation Name" == "events")') x),
    (SELECT string_agg((x->>'Node Type') || coalesce(' using ' || (x->>'Index Name'), ''), ',')
       FROM jsonb_path_query(v_plan, 'strict $.** ? (@."Relation Name" == "events")') x),
    (SELECT count(*) FROM jsonb_path_query(v_plan, 'strict $.** ? (@."Parent Relationship" == "SubPlan")') x);
END
$f$;

CREATE FUNCTION pg_temp.kan732_snap(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO kan732_meta
  SELECT p_phase, p.proname, pg_get_function_identity_arguments(p.oid), pg_get_function_arguments(p.oid),
         pg_get_function_result(p.oid), l.lanname, p.prosecdef, p.provolatile, p.proconfig, pg_get_userbyid(p.proowner),
         p.proacl::text, obj_description(p.oid, 'pg_proc'), md5(p.prosrc)
    FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
   WHERE p.oid IN ('public.admin_cleanup_user_data(uuid,boolean)'::regprocedure, 'public.admin_overview_row()'::regprocedure);

  INSERT INTO kan732_view SELECT p_phase, pg_get_viewdef(c.oid), c.relacl::text, c.reloptions, pg_get_userbyid(c.relowner)
    FROM pg_class c WHERE c.oid = 'public.v_admin_overview'::regclass;

  INSERT INTO kan732_data SELECT p_phase,
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.profiles t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.profile_id)) FROM public.profile_verifications t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.content_reports t),
    (SELECT md5(t::text) FROM public.meetups t WHERE t.id = '30000000-0000-0000-0000-000000000001');

  -- The changed statements exactly as each body states them (post-condition / T0 pin the body text).
  IF p_phase = 'new' THEN
    PERFORM pg_temp.kan732_plan(p_phase, 'cleanup',
      'DELETE FROM public.games g USING public.events e WHERE e.id = g.event_id AND e.event_type = ''game''
          AND e.creator_profile_id = ''00000000-0000-0000-0000-0000000000b8''::uuid');
    PERFORM pg_temp.kan732_plan(p_phase, 'overview',
      'select count(*)::bigint as c from public.games g join public.events e on e.id = g.event_id and e.event_type = ''game''
        where e.created_at >= date_trunc(''week'', now()) and e.created_at < date_trunc(''week'', now()) + interval ''7 days''');
  ELSIF p_phase = 'legacy' THEN
    PERFORM pg_temp.kan732_plan(p_phase, 'cleanup',
      'DELETE FROM public.games WHERE creator_profile_id = ''00000000-0000-0000-0000-0000000000b8''::uuid');
    PERFORM pg_temp.kan732_plan(p_phase, 'overview',
      'select count(*)::bigint as c from public.games g
        where g.created_at >= date_trunc(''week'', now()) and g.created_at < date_trunc(''week'', now()) + interval ''7 days''');
  END IF;
END
$f$;

-- Independent expectations, computed from the tables (not from either body).
CREATE TEMP TABLE kan732_expect AS
SELECT (SELECT count(*) FROM public.games WHERE created_at >= date_trunc('week', now())
          AND created_at < date_trunc('week', now()) + interval '7 days') AS games_week,
       (SELECT count(*) FROM public.meetups WHERE created_at >= date_trunc('week', now())
          AND created_at < date_trunc('week', now()) + interval '7 days') AS meetups_week,
       (SELECT count(*) FROM public.games) AS games, (SELECT count(*) FROM public.meetups) AS meetups,
       (SELECT count(*) FROM public.events WHERE event_type = 'game') AS events_game,
       (SELECT count(*) FROM public.events WHERE event_type = 'meetup') AS events_meetup,
       (SELECT count(*) FROM public.content_reports WHERE status IN ('open', 'reviewing')) AS reports_open,
       (SELECT count(*) FROM public.content_reports WHERE status = 'resolved') AS reports_resolved;

-- ---------------------------------------------------------------------------------------------------------
-- NEW phase
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.kan732_snap('new');
SELECT pg_temp.kan732_run('new');
SELECT label, res->>'ok' AS ok, coalesce(res->>'sqlstate', '') AS sqlstate, coalesce(res->>'constraint', res->>'error', '') AS err,
       left(coalesce(res->>'ret', ''), 160) AS ret
  FROM kan732_res WHERE phase = 'new' ORDER BY label;

-- ---------------------------------------------------------------------------------------------------------
-- E (part 1). ROLLBACK block: verbatim copy of the migration's KAN732-ROLLBACK section, uncommented.
-- ---------------------------------------------------------------------------------------------------------
BEGIN;
CREATE OR REPLACE FUNCTION "public"."admin_cleanup_user_data"("p_user_id" "uuid", "p_dry_run" boolean DEFAULT true) RETURNS TABLE("affected_table" "text", "affected_column" "text", "rows_affected" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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
CREATE OR REPLACE FUNCTION "public"."admin_overview_row"() RETURNS TABLE("snapshot_at" timestamp with time zone, "total_users" bigint, "frozen_users" bigint, "active_users" bigint, "games_created_this_week" bigint, "reports_open" bigint, "reports_resolved" bigint, "verified_profiles_total" bigint, "verified_players" bigint, "verified_organisers" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  wk_start timestamptz;
  wk_end   timestamptz;
begin
  -- Gate: admin only
  if not public.is_admin(auth.uid()) then
    raise exception using errcode = 'P0001', message = 'not_admin';
  end if;

  select week_start, week_end into wk_start, wk_end
  from public._week_bounds(now());

  -- Return single-row snapshot
  return query
  with
  -- Distinct humans inferred from profiles; avoids needing auth.users privileges
  users_distinct as (
    select count(distinct p.user_id)::bigint as c
    from public.profiles p
    where p.is_active = true
  ),
  frozen as (
    select count(distinct f.user_id)::bigint as c
    from public.user_freezes f
    where f.is_frozen = true
      and (f.until is null or now() < f.until)
      and f.lifted_at is null
  ),
  games_week as (
    select count(*)::bigint as c
    from public.games g
    where g.created_at >= wk_start
      and g.created_at <  wk_end
  ),
  reports as (
    select
      count(*) filter (where status in ('open','reviewing'))::bigint as open_c,
      count(*) filter (where status = 'resolved')::bigint          as resolved_c
    from public.content_reports
  ),
  verif as (
    select
      count(*)::bigint                                                     as total_c,
      count(*) filter (where p.profile_type = 'player')::bigint            as players_c,
      count(*) filter (where p.profile_type = 'organiser')::bigint         as organisers_c
    from public.profile_verifications v
    join public.profiles p on p.id = v.profile_id
    where v.verified = true
  )
  select
    now()                                              as snapshot_at,
    (select c from users_distinct)                     as total_users,
    (select c from frozen)                             as frozen_users,
    (select c from users_distinct) - (select c from frozen)  as active_users,
    (select c from games_week)                         as games_created_this_week,
    (select open_c from reports)                       as reports_open,
    (select resolved_c from reports)                   as reports_resolved,
    (select total_c from verif)                        as verified_profiles_total,
    (select players_c from verif)                      as verified_players,
    (select organisers_c from verif)                   as verified_organisers;
end;
$$;
COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- LEGACY phase (the same probes on the pre-image bodies)
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.kan732_snap('legacy');
SELECT pg_temp.kan732_run('legacy');

-- ---------------------------------------------------------------------------------------------------------
-- Assertions A-D, F
-- ---------------------------------------------------------------------------------------------------------
DO $asrt$
DECLARE
  n record; o record; r record; x record;
  v_new jsonb; v_old jsonb;
  v_ret jsonb;
BEGIN
  SELECT * INTO x FROM kan732_expect;

  -- A. shape
  FOR r IN SELECT fn FROM kan732_meta WHERE phase = 'new' LOOP
    SELECT * INTO n FROM kan732_meta WHERE phase = 'new' AND fn = r.fn;
    SELECT * INTO o FROM kan732_meta WHERE phase = 'legacy' AND fn = r.fn;
    IF (n.args, n.full_args, n.result, n.lang, n.secdef, n.vol, n.config, n.owner, n.acl, n.comment)
       IS DISTINCT FROM
       (o.args, o.full_args, o.result, o.lang, o.secdef, o.vol, o.config, o.owner, o.acl, o.comment) THEN
      RAISE EXCEPTION 'A FAIL: % signature/result/attributes differ: new % legacy %', r.fn, row_to_json(n), row_to_json(o);
    END IF;
    IF NOT n.secdef OR n.owner <> 'postgres' OR n.lang <> 'plpgsql' THEN
      RAISE EXCEPTION 'A FAIL: % unexpected identity %', r.fn, row_to_json(n);
    END IF;
  END LOOP;
  SELECT * INTO n FROM kan732_meta WHERE phase = 'new' AND fn = 'admin_cleanup_user_data';
  IF n.full_args <> 'p_user_id uuid, p_dry_run boolean DEFAULT true'
     OR n.result <> 'TABLE(affected_table text, affected_column text, rows_affected bigint)'
     OR n.config IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
    RAISE EXCEPTION 'A FAIL: admin_cleanup_user_data identity %', row_to_json(n);
  END IF;
  SELECT * INTO o FROM kan732_meta WHERE phase = 'new' AND fn = 'admin_overview_row';
  IF o.args <> '' OR o.config IS DISTINCT FROM ARRAY['search_path=public']
     OR o.result <> 'TABLE(snapshot_at timestamp with time zone, total_users bigint, frozen_users bigint, active_users bigint, games_created_this_week bigint, reports_open bigint, reports_resolved bigint, verified_profiles_total bigint, verified_players bigint, verified_organisers bigint)' THEN
    RAISE EXCEPTION 'A FAIL: admin_overview_row identity %', row_to_json(o);
  END IF;
  IF (SELECT row(def, acl, reloptions, owner) FROM kan732_view WHERE phase = 'new')
     IS DISTINCT FROM (SELECT row(def, acl, reloptions, owner) FROM kan732_view WHERE phase = 'legacy') THEN
    RAISE EXCEPTION 'A FAIL: v_admin_overview changed';
  END IF;
  FOR r IN SELECT label FROM kan732_res WHERE phase = 'new' AND label IN ('B1_cleanup_dry_b8', 'B2_cleanup_real_b8') LOOP
    IF EXISTS (SELECT 1 FROM jsonb_array_elements((SELECT res->'ret' FROM kan732_res WHERE phase = 'new' AND label = r.label)) e
                WHERE (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(e) k) <> ARRAY['affected_column','affected_table','rows_affected']) THEN
      RAISE EXCEPTION 'A FAIL: % result columns changed', r.label;
    END IF;
  END LOOP;
  RAISE NOTICE 'A PASS shape: admin_cleanup_user_data(%) RETURNS %, admin_overview_row() RETURNS TABLE(10 cols); both SECURITY DEFINER plpgsql owner postgres, config %/% , acl %/% and comment identical to legacy; v_admin_overview def/acl/owner unchanged',
    n.full_args, n.result, n.config, o.config, n.acl, o.acl;

  -- B. result sets and counts = legacy, nothing doubled, games and meetups
  FOR r IN SELECT unnest(ARRAY['B1_cleanup_dry_b8','B2_cleanup_real_b8','B3_cleanup_dry_b9','B4_cleanup_real_b9_meetup_owner',
                               'B5_cleanup_no_profile','B6_overview_admin','B7_view_admin']) AS label LOOP
    SELECT res INTO v_new FROM kan732_res WHERE phase = 'new' AND label = r.label;
    SELECT res INTO v_old FROM kan732_res WHERE phase = 'legacy' AND label = r.label;
    IF v_new IS DISTINCT FROM v_old THEN
      RAISE EXCEPTION 'B FAIL: % differs from legacy: new % legacy %', r.label, v_new, v_old;
    END IF;
  END LOOP;
  v_new := (SELECT res FROM kan732_res WHERE phase = 'new' AND label = 'B2_cleanup_real_b8');
  IF NOT (v_new->>'ok')::boolean
     OR v_new->'ret' <> '[{"affected_table": "games", "affected_column": "creator_profile_id", "rows_affected": 3},
                          {"affected_table": "profile_verifications", "affected_column": "profile_id", "rows_affected": 1},
                          {"affected_table": "profiles", "affected_column": "id", "rows_affected": 1}]'::jsonb
     OR (v_new->'state'->>'games')::bigint <> x.games - 3 OR (v_new->'state'->>'events_game')::bigint <> x.events_game - 3
     OR (v_new->'state'->>'meetups')::bigint <> x.meetups OR (v_new->'state'->>'events_meetup')::bigint <> x.events_meetup
     OR v_new->'state'->'b13_games_left' <> '["4","5","6"]'::jsonb OR (v_new->'state'->>'b8_profile')::int <> 0
     OR (v_new->'state'->>'b8_events')::int <> 0 OR (v_new->'state'->>'orphan_events')::int <> 0 THEN
    RAISE EXCEPTION 'B FAIL: B2 real cleanup of b8 must delete exactly its 3 games (+3 parents), its verification and profile: %', v_new;
  END IF;
  v_new := (SELECT res FROM kan732_res WHERE phase = 'new' AND label = 'B1_cleanup_dry_b8');
  IF NOT (v_new->>'ok')::boolean
     OR v_new->'ret' <> '[{"affected_table": "games", "affected_column": "creator_profile_id", "rows_affected": 1},
                          {"affected_table": "posts", "affected_column": "author_profile_id", "rows_affected": 1},
                          {"affected_table": "profile_verifications", "affected_column": "profile_id", "rows_affected": 1},
                          {"affected_table": "profiles", "affected_column": "id", "rows_affected": 1}]'::jsonb
     OR (v_new->'state'->>'games')::bigint <> x.games OR (v_new->'state'->>'events_game')::bigint <> x.events_game THEN
    RAISE EXCEPTION 'B FAIL: B1 dry run must write nothing and report the pre-existing ROW_COUNT carry-over exactly as legacy: %', v_new;
  END IF;
  v_new := (SELECT res FROM kan732_res WHERE phase = 'new' AND label = 'B4_cleanup_real_b9_meetup_owner');
  IF (v_new->>'ok')::boolean OR v_new->>'sqlstate' <> '23503' THEN
    RAISE EXCEPTION 'B FAIL: B4 meetup owner must keep the pre-existing 23503 refusal (KAN712_CONTRACT L-2): %', v_new;
  END IF;
  v_new := (SELECT res FROM kan732_res WHERE phase = 'new' AND label = 'B5_cleanup_no_profile');
  IF v_new->'ret' <> '[{"affected_table": "profiles", "affected_column": "user_id", "rows_affected": 0}]'::jsonb THEN
    RAISE EXCEPTION 'B FAIL: B5 unknown user: %', v_new;
  END IF;
  v_ret := (SELECT res->'ret' FROM kan732_res WHERE phase = 'new' AND label = 'B6_overview_admin');
  IF (v_ret->>'games_created_this_week')::bigint <> x.games_week
     OR (v_ret->>'reports_open')::bigint <> x.reports_open OR (v_ret->>'reports_resolved')::bigint <> x.reports_resolved
     OR v_ret IS DISTINCT FROM (SELECT res->'ret' FROM kan732_res WHERE phase = 'new' AND label = 'B7_view_admin') THEN
    RAISE EXCEPTION 'B FAIL: B6 overview games_created_this_week % (games created this week %; meetups created this week % must not count), reports % / %',
      v_ret->>'games_created_this_week', x.games_week, x.meetups_week, v_ret->>'reports_open', v_ret->>'reports_resolved';
  END IF;
  IF x.meetups_week = 0 THEN RAISE EXCEPTION 'B FAIL: fixture needs a meetup created this week'; END IF;
  RAISE NOTICE 'B PASS = legacy byte for byte (B1..B7). Cleanup b8 real: [games 3, profile_verifications 1, profiles 1], games % -> %, game parents % -> %, meetups/meetup parents unchanged (%/%), no orphan parent; dry run writes nothing and reports the same rows as legacy (incl. the pre-existing ROW_COUNT carry-over games 1 / posts 1); meetup owner b9 refused 23503 in both; overview games_created_this_week % = games created this week (% meetups created this week not counted), view = function',
    x.games, x.games - 3, x.events_game, x.events_game - 3, x.meetups, x.events_meetup, x.games_week, x.meetups_week;

  -- C. provenance (mirror disabled; events changed, games untouched)
  SELECT res INTO v_new FROM kan732_res WHERE phase = 'new' AND label = 'C1_prov_cleanup';
  SELECT res INTO v_old FROM kan732_res WHERE phase = 'legacy' AND label = 'C1_prov_cleanup';
  IF v_new->'prov_games_side'->>'creator' <> '00000000-0000-0000-0000-0000000000b7'
     OR v_new->'prov_events_side'->>'creator' <> '00000000-0000-0000-0000-0000000000b8' THEN
    RAISE EXCEPTION 'C FAIL: C1 probe did not diverge games from events: %', v_new;
  END IF;
  IF NOT (v_new->>'ok')::boolean OR v_new->'ret'->0->>'rows_affected' <> '4'
     OR v_new->'state'->'b13_games_left' <> '["4","5"]'::jsonb OR (v_new->'state'->>'b8_events')::int <> 0 THEN
    RAISE EXCEPTION 'C FAIL: NEW did not delete by the events owner: %', v_new;
  END IF;
  IF (v_old->>'ok')::boolean OR v_old->>'sqlstate' <> '23503' OR v_old->>'constraint' <> 'events_creator_profile_id_fkey' THEN
    RAISE EXCEPTION 'C FAIL: C1 does not fail on LEGACY (it would prove nothing): %', v_old;
  END IF;
  SELECT res INTO v_new FROM kan732_res WHERE phase = 'new' AND label = 'C2_prov_overview';
  SELECT res INTO v_old FROM kan732_res WHERE phase = 'legacy' AND label = 'C2_prov_overview';
  IF (v_new->'prov_games_side'->>'this_week')::boolean OR NOT (v_new->'prov_events_side'->>'this_week')::boolean THEN
    RAISE EXCEPTION 'C FAIL: C2 probe did not diverge games from events: %', v_new;
  END IF;
  IF (v_new->'ret'->>'games_created_this_week')::bigint <> x.games_week + 1 THEN
    RAISE EXCEPTION 'C FAIL: NEW did not count by events.created_at: % (base %)', v_new->'ret'->>'games_created_this_week', x.games_week;
  END IF;
  IF (v_old->'ret'->>'games_created_this_week')::bigint <> x.games_week THEN
    RAISE EXCEPTION 'C FAIL: C2 does not fail on LEGACY (it would prove nothing): %', v_old->'ret'->>'games_created_this_week';
  END IF;
  RAISE NOTICE 'C PASS provenance (mirror disabled, events changed, games rows untouched): C1 game 6 parent owner b7 -> b8: NEW deletes 4 games incl. game 6 and the profile; LEGACY deletes 3 and then fails 23503 events_creator_profile_id_fkey. C2 game 5 parent created_at moved into this week: NEW counts % (+1), LEGACY % — both probes fail on legacy',
    v_new->'ret'->>'games_created_this_week', v_old->'ret'->>'games_created_this_week';

  -- D. refusals = legacy, and nobody but an admin gets anything
  FOR r IN SELECT unnest(ARRAY['D1_overview_anon','D2_overview_member','D3_overview_blocked','D4_view_member',
                               'D5_cleanup_anon','D6_cleanup_member','D7_cleanup_blocked','D8_cleanup_self_prov']) AS label LOOP
    SELECT res INTO v_new FROM kan732_res WHERE phase = 'new' AND label = r.label;
    SELECT res INTO v_old FROM kan732_res WHERE phase = 'legacy' AND label = r.label;
    IF (v_new - 'prov_games_side' - 'prov_events_side') IS DISTINCT FROM (v_old - 'prov_games_side' - 'prov_events_side') THEN
      RAISE EXCEPTION 'D FAIL: % differs: new % legacy %', r.label, v_new, v_old;
    END IF;
    IF (v_new->>'ok')::boolean OR v_new->>'sqlstate' <> 'P0001'
       OR v_new->>'error' <> (CASE WHEN r.label LIKE '%cleanup%' THEN 'Access denied: admin privileges required' ELSE 'not_admin' END) THEN
      RAISE EXCEPTION 'D FAIL: % was not refused: %', r.label, v_new;
    END IF;
  END LOOP;
  RAISE NOTICE 'D PASS refusals = legacy: overview/view for anon, member a7, blocked a6 -> P0001 not_admin; cleanup for anon, a7, a6 and a8 on itself (even with an events parent pointed at it) -> P0001 Access denied: admin privileges required; nothing returned, nothing written';

  -- F. plan
  FOR r IN SELECT stmt FROM kan732_plan WHERE phase = 'new' LOOP
    SELECT * INTO n FROM kan732_plan WHERE phase = 'new' AND stmt = r.stmt;
    SELECT * INTO o FROM kan732_plan WHERE phase = 'legacy' AND stmt = r.stmt;
    IF n.events_scans <> 1 OR n.subplans <> 0 OR o.subplans <> 0 OR o.events_scans <> 0
       OR n.rels <> ARRAY['events','games'] OR o.rels <> ARRAY['games'] THEN
      RAISE EXCEPTION 'F FAIL: % plan new % legacy %', r.stmt, row_to_json(n), row_to_json(o);
    END IF;
    RAISE NOTICE 'F PASS plan %: legacy relations % -> new % (one added: events, scanned once via %), 0 SubPlans; one set-based statement, no per-row repetition',
      r.stmt, o.rels, n.rels, n.events_node;
  END LOOP;
END
$asrt$;

-- ---------------------------------------------------------------------------------------------------------
-- E (part 2). Rollback restored the old bodies; data intact; re-apply the migration and verify the round trip.
-- ---------------------------------------------------------------------------------------------------------
DO $e1$
DECLARE dn record; dl record;
BEGIN
  SELECT * INTO dn FROM kan732_data WHERE phase = 'new';
  SELECT * INTO dl FROM kan732_data WHERE phase = 'legacy';
  IF (SELECT src_md5 FROM kan732_meta WHERE phase = 'legacy' AND fn = 'admin_cleanup_user_data') <> '978ae882109662a5e229bb87aebad01b'
     OR (SELECT src_md5 FROM kan732_meta WHERE phase = 'legacy' AND fn = 'admin_overview_row') <> 'f5a9160e240140ed7c5a373a3d494e79'
     OR (SELECT src_md5 FROM kan732_meta WHERE phase = 'new' AND fn = 'admin_cleanup_user_data') <> '09baee67932be2618af9043c89155db2'
     OR (SELECT src_md5 FROM kan732_meta WHERE phase = 'new' AND fn = 'admin_overview_row') <> '42573e04bc2aae0af755ded1f8eceb5a' THEN
    RAISE EXCEPTION 'E FAIL: md5 after rollback / before rollback not as expected: %',
      (SELECT json_agg(row_to_json(m)) FROM kan732_meta m);
  END IF;
  IF row(dn.games, dn.events, dn.meetups, dn.profiles, dn.verifications, dn.reports, dn.harness_meetup)
     IS DISTINCT FROM row(dl.games, dl.events, dl.meetups, dl.profiles, dl.verifications, dl.reports, dl.harness_meetup) THEN
    RAISE EXCEPTION 'E FAIL: data changed across the NEW probes / rollback: % vs %', row_to_json(dn), row_to_json(dl);
  END IF;
  RAISE NOTICE 'E PASS rollback block restores md5 978ae882109662a5e229bb87aebad01b / f5a9160e240140ed7c5a373a3d494e79 (baseline), owner/ACL/comment unchanged; games/events/meetups/profiles/verifications/reports byte-identical across the NEW probes, the rollback and the LEGACY probes';
END
$e1$;

\ir ../../migrations/20261104101300_kan714_b13_analytics_admin_export_cleanup.sql

SELECT pg_temp.kan732_snap('reapplied');

DO $e2$
DECLARE r record; n record; ra record; dn record; dr record;
BEGIN
  FOR r IN SELECT fn FROM kan732_meta WHERE phase = 'new' LOOP
    SELECT * INTO n FROM kan732_meta WHERE phase = 'new' AND fn = r.fn;
    SELECT * INTO ra FROM kan732_meta WHERE phase = 'reapplied' AND fn = r.fn;
    IF (n.args, n.full_args, n.result, n.lang, n.secdef, n.vol, n.config, n.owner, n.acl, n.comment, n.src_md5)
       IS DISTINCT FROM
       (ra.args, ra.full_args, ra.result, ra.lang, ra.secdef, ra.vol, ra.config, ra.owner, ra.acl, ra.comment, ra.src_md5) THEN
      RAISE EXCEPTION 'E FAIL: re-applied % differs from first apply: % vs %', r.fn, row_to_json(n), row_to_json(ra);
    END IF;
  END LOOP;
  SELECT * INTO dn FROM kan732_data WHERE phase = 'new';
  SELECT * INTO dr FROM kan732_data WHERE phase = 'reapplied';
  IF row(dn.games, dn.events, dn.meetups, dn.profiles, dn.verifications, dn.reports, dn.harness_meetup)
     IS DISTINCT FROM row(dr.games, dr.events, dr.meetups, dr.profiles, dr.verifications, dr.reports, dr.harness_meetup)
     OR dn.harness_meetup IS NULL THEN
    RAISE EXCEPTION 'E FAIL: data changed across re-apply (or harness meetup missing)';
  END IF;
  IF (SELECT row(def, acl, reloptions, owner) FROM kan732_view WHERE phase = 'new')
     IS DISTINCT FROM (SELECT row(def, acl, reloptions, owner) FROM kan732_view WHERE phase = 'reapplied') THEN
    RAISE EXCEPTION 'E FAIL: v_admin_overview changed across re-apply';
  END IF;
  RAISE NOTICE 'E PASS re-apply: md5 09baee67932be2618af9043c89155db2 / 42573e04bc2aae0af755ded1f8eceb5a again, identical attributes/ACL/comment, v_admin_overview unchanged, data intact, harness meetup 30000000-...-0001 present and unchanged';
END
$e2$;

DO $done$ BEGIN RAISE NOTICE 'KAN-732 ALL PASS'; END $done$;

-- KAN-851 test: the captured production function public.run_seed_meetup_template(uuid, jsonb).
-- LOCAL THROWAWAY POSTGRES ONLY (refuses any database not named k851*). Built by build_kan851.sh.
--
--   T1  prosrc md5 = 74e763538070a1460fa4e1dc62f7cdf6 (production, KAN-844 comment 15527), length 6605.
--   T2  owner postgres, prosecdef = f, proconfig {"search_path=public, pg_temp"},
--       proacl exactly {postgres=X/postgres,service_role=X/postgres}: no PUBLIC, anon or authenticated.
--   T3  body scan: no UPDATE, EXECUTE, format(, session_replication_role, DISABLE TRIGGER; no DELETE.
--   T4  (run after 6c + step 7) as service_role with valid seed args: status 'success', and the rows are really there
--       (the function's EXCEPTION WHEN OTHERS would hide a guard refusal): meetups +1, meetup_rsvps +5 (3 going,
--       2 interested), and an events parent (event_type 'meetup') for the new meetup written through kan712_legacy_guard.
--   Fixture rows are written inside a transaction that is rolled back.
\set ON_ERROR_STOP 1
DO $g$ BEGIN
  IF current_database() NOT LIKE 'k851%' THEN RAISE EXCEPTION 'kan851 test: database % is not k851*; refusing', current_database(); END IF;
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'kan851 test: this looks like a Supabase database; refusing';
  END IF;
END $g$;

\echo == T1 md5(prosrc)
SELECT md5(prosrc) AS prosrc_md5, length(prosrc) AS len FROM pg_proc
 WHERE oid = to_regprocedure('public.run_seed_meetup_template(uuid,jsonb)');
DO $t1$ DECLARE v text; BEGIN
  SELECT md5(prosrc) INTO v FROM pg_proc WHERE oid = to_regprocedure('public.run_seed_meetup_template(uuid,jsonb)');
  IF v IS DISTINCT FROM '74e763538070a1460fa4e1dc62f7cdf6' THEN RAISE EXCEPTION 'T1 FAIL: prosrc md5 %', v; END IF;
  RAISE NOTICE 'T1 PASS';
END $t1$;

\echo == T2 attributes and ACL
SELECT pg_get_userbyid(proowner) AS owner, prosecdef, proconfig, proacl::text AS proacl, l.lanname
  FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
 WHERE p.oid = 'public.run_seed_meetup_template(uuid,jsonb)'::regprocedure;
SELECT r AS role, has_function_privilege(r, 'public.run_seed_meetup_template(uuid,jsonb)', 'EXECUTE') AS can_execute
  FROM unnest(ARRAY['anon', 'authenticated', 'service_role']) r;
DO $t2$ DECLARE p record; BEGIN
  SELECT * INTO p FROM pg_proc WHERE oid = 'public.run_seed_meetup_template(uuid,jsonb)'::regprocedure;
  IF pg_get_userbyid(p.proowner) <> 'postgres' THEN RAISE EXCEPTION 'T2 FAIL: owner %', pg_get_userbyid(p.proowner); END IF;
  IF p.prosecdef THEN RAISE EXCEPTION 'T2 FAIL: SECURITY DEFINER'; END IF;
  IF p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN RAISE EXCEPTION 'T2 FAIL: proconfig %', p.proconfig; END IF;
  IF p.proacl::text IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'T2 FAIL: proacl %', p.proacl; END IF;
  IF has_function_privilege('anon', p.oid, 'EXECUTE') OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
     OR NOT has_function_privilege('service_role', p.oid, 'EXECUTE') THEN RAISE EXCEPTION 'T2 FAIL: effective privileges'; END IF;
  RAISE NOTICE 'T2 PASS';
END $t2$;

\echo == T3 body scan
SELECT pat, (SELECT count(*) FROM regexp_matches(prosrc, pat, 'gi')) AS hits
  FROM pg_proc, unnest(ARRAY['\mupdate\M', '\mexecute\M', '\mformat\s*\(', 'session_replication_role',
                             'disable\s+trigger', '\mdelete\M', '\minsert\s+into\s+public\.\w+']) pat
 WHERE oid = 'public.run_seed_meetup_template(uuid,jsonb)'::regprocedure;
SELECT m[1] AS insert_target, count(*) FROM pg_proc, regexp_matches(prosrc, 'insert\s+into\s+(public\.\w+)', 'gi') m
 WHERE oid = 'public.run_seed_meetup_template(uuid,jsonb)'::regprocedure GROUP BY 1 ORDER BY 1;
DO $t3$ DECLARE s text; BEGIN
  SELECT prosrc INTO s FROM pg_proc WHERE oid = 'public.run_seed_meetup_template(uuid,jsonb)'::regprocedure;
  IF s ~* '\mupdate\M|\mexecute\M|\mformat\s*\(|session_replication_role|disable\s+trigger|\mdelete\M|\malter\s+table\M' THEN
    RAISE EXCEPTION 'T3 FAIL: forbidden token in body';
  END IF;
  IF EXISTS (SELECT 1 FROM regexp_matches(s, 'insert\s+into\s+(public\.\w+)', 'gi') m
              WHERE m[1] NOT IN ('public.meetups', 'public.meetup_rsvps')) THEN
    RAISE EXCEPTION 'T3 FAIL: inserts outside meetups/meetup_rsvps';
  END IF;
  RAISE NOTICE 'T3 PASS';
END $t3$;

\if :{?skip_call}
\echo == T4 skipped (skip_call set)
\quit
\endif

\echo == T4 call as service_role after 6c + step 7
DO $pre$ BEGIN
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL OR NOT EXISTS (
       SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass AND tgname = 'trg_zz_kan712_meetups_guard') THEN
    RAISE EXCEPTION 'T4: step 7 is not applied (no trg_zz_kan712_meetups_guard on meetups)';
  END IF;
END $pre$;

BEGIN;
-- Local fixture. The KAN-711..714 harnesses carry only the profiles/areas columns their own tests read; these are
-- production baseline columns the function reads (profiles.is_original/city/primary_sport/created_at, areas.city)
-- and the baseline table public.player. Added here, locally, because no harness in this chain defines them.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_original boolean NOT NULL DEFAULT true,
                            ADD COLUMN IF NOT EXISTS city text,
                            ADD COLUMN IF NOT EXISTS primary_sport uuid,
                            ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS city text;
CREATE TABLE IF NOT EXISTS public.player (profile_id uuid);
GRANT ALL ON public.player TO service_role;
-- Supabase grants service_role USAGE on public sequences; the harness default privileges cover tables only, so a
-- trigger sink with a serial key (event_outbox, fed on meetup insert) refused service_role locally (first run, T4 RED).
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;

INSERT INTO public.sports (id, can_solo, is_active, sport_key)
VALUES ('00000000-0000-0000-0000-000000851001', true, true, 'kan851_run');
INSERT INTO public.areas (id, city) VALUES ('00000000-0000-0000-0000-000000851002', 'KAN851City');
INSERT INTO public.geo_locations (id, area_id) VALUES ('00000000-0000-0000-0000-000000851003', '00000000-0000-0000-0000-000000851002');
INSERT INTO auth.users (id) SELECT ('00000000-0000-0000-0000-0000008511' || lpad(i::text, 2, '0'))::uuid FROM generate_series(1, 6) i;
INSERT INTO public.profiles (id, user_id, persona_type, is_active, is_original, city, primary_sport, created_at)
SELECT ('00000000-0000-0000-0000-0000008512' || lpad(i::text, 2, '0'))::uuid,
       ('00000000-0000-0000-0000-0000008511' || lpad(i::text, 2, '0'))::uuid,
       'player', true, false, 'KAN851City', '00000000-0000-0000-0000-000000851001', now() - make_interval(mins => i)
  FROM generate_series(1, 6) i;

CREATE TEMP TABLE kan851_before ON COMMIT DROP AS
SELECT (SELECT count(*) FROM public.meetups) AS meetups, (SELECT count(*) FROM public.meetup_rsvps) AS rsvps,
       (SELECT count(*) FROM public.events WHERE event_type = 'meetup') AS events;
GRANT SELECT ON kan851_before TO service_role;

SET LOCAL ROLE service_role;
SELECT current_user AS calling_as;
CREATE TEMP TABLE kan851_result ON COMMIT DROP AS
SELECT public.run_seed_meetup_template('00000000-0000-0000-0000-000000851099'::uuid, jsonb_build_object(
         'city', 'KAN851City', 'title', 'KAN-851 seed run', 'sport_key', 'kan851_run',
         'geo_location_id', '00000000-0000-0000-0000-000000851003', 'location_name', 'KAN-851 park', 'is_indoor', false,
         'capacity', 8, 'seed_going', 3, 'seed_interested', 2, 'days_ahead', 2, 'start_hour', 18)) AS r;
RESET ROLE;

SELECT r FROM kan851_result;
SELECT b.meetups AS meetups_before, (SELECT count(*) FROM public.meetups) AS meetups_after,
       b.rsvps AS rsvps_before, (SELECT count(*) FROM public.meetup_rsvps) AS rsvps_after,
       b.events AS meetup_events_before, (SELECT count(*) FROM public.events WHERE event_type = 'meetup') AS meetup_events_after
  FROM kan851_before b;
SELECT m.id, m.request_id IS NOT NULL AS has_request_id, m.meta->>'source' AS meta_source, m.host_actor_id = m.creator_profile_id AS host_is_creator,
       m.listing_visibility, m.rsvp_policy, m.members_only, m.joining_rule, m.cost_cover,
       e.id IS NOT NULL AS events_parent, e.event_type, e.join_policy, e.request_id = m.request_id AS parent_request_id_matches
  FROM public.meetups m LEFT JOIN public.events e ON e.id = m.id
 WHERE m.id = ((SELECT r FROM kan851_result)->>'meetup_id')::uuid;
SELECT status, count(*) FROM public.meetup_rsvps WHERE meetup_id = ((SELECT r FROM kan851_result)->>'meetup_id')::uuid GROUP BY 1 ORDER BY 1;

DO $t4$ DECLARE v jsonb; b record; v_mid uuid; BEGIN
  SELECT r INTO v FROM kan851_result;
  IF v->>'status' IS DISTINCT FROM 'success' THEN RAISE EXCEPTION 'T4 FAIL: function returned %', v; END IF;
  v_mid := (v->>'meetup_id')::uuid;
  SELECT * INTO b FROM kan851_before;
  IF (SELECT count(*) FROM public.meetups) <> b.meetups + 1 THEN RAISE EXCEPTION 'T4 FAIL: meetups did not grow by 1'; END IF;
  IF (SELECT count(*) FROM public.meetup_rsvps) <> b.rsvps + 5 THEN RAISE EXCEPTION 'T4 FAIL: meetup_rsvps did not grow by 5'; END IF;
  IF (SELECT count(*) FROM public.meetup_rsvps WHERE meetup_id = v_mid AND status = 'going') <> 3
     OR (SELECT count(*) FROM public.meetup_rsvps WHERE meetup_id = v_mid AND status = 'interested') <> 2 THEN
    RAISE EXCEPTION 'T4 FAIL: rsvp split';
  END IF;
  IF (SELECT count(*) FROM public.events WHERE event_type = 'meetup') <> b.events + 1
     OR NOT EXISTS (SELECT 1 FROM public.events e JOIN public.meetups m ON m.id = e.id
                     WHERE e.id = v_mid AND e.event_type = 'meetup' AND e.request_id = m.request_id) THEN
    RAISE EXCEPTION 'T4 FAIL: no events parent for meetup %', v_mid;
  END IF;
  RAISE NOTICE 'T4 PASS (meetup %)', v_mid;
END $t4$;
ROLLBACK;

-- KAN-862 live proof: the meetup create path writes events first and names only retained meetups columns
-- (Z01 blocker, PEER comment 16219). Extends kan717_f6_meetup_create_live_test.sql (probes 1-7, same call)
-- and reads the creator from events, not meetups, so it still runs after Z01.
-- Runs on the hosted project as postgres, entirely inside BEGIN ... ROLLBACK.
-- RED on the pre-image (legacy_v2 prosrc 88ed8d98...): probe 8 (its INSERT INTO public.meetups lists
-- creator_profile_id, title, start_at, ... and RETURNING joining_rule, cost_cover).
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k862_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k862_out (k text PRIMARY KEY, v text) ON COMMIT DROP;

DO $t$
DECLARE v_mid uuid; v_mid2 uuid; v_err text; v_err2 text; v_err3 text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', true);
  SET LOCAL ROLE authenticated;
  BEGIN
    v_mid := public.rpc_create_meetup(
      p_actor_type => 'player', p_sport_id => '91554c52-47b4-40e2-bf45-5f3b1e67f64a'::uuid,
      p_sport_variant_id => '6cde6a6d-7785-43e3-883d-be369ef47aa5'::uuid,
      p_title => 'KAN717 JWEB probe meetup F1', p_description => NULL,
      p_venue_id => '0d5145ca-5d5e-489e-8f01-a84fd8bf39c1'::uuid, p_location_name => 'The Warehouse Gym DIFC',
      p_geo_location_id => '67e53ee4-d5bf-4ced-82f2-c8de28a12b91'::uuid, p_area_id => '7aeab558-fcc2-4559-b4a2-56832e57e33d'::uuid,
      p_start_at => timestamptz '2026-11-27 06:00 Asia/Dubai', p_end_at => timestamptz '2026-11-27 07:00 Asia/Dubai',
      p_capacity => 8, p_listing_visibility => 'public', p_rsvp_policy => 'open',
      p_request_id => 'a717f600-0000-4000-8000-000000000001'::uuid);
    -- replay: same request_id returns the same meetup
    v_mid2 := public.rpc_create_meetup(
      p_actor_type => 'player', p_sport_id => '91554c52-47b4-40e2-bf45-5f3b1e67f64a'::uuid,
      p_sport_variant_id => '6cde6a6d-7785-43e3-883d-be369ef47aa5'::uuid,
      p_title => 'KAN717 JWEB probe meetup F1', p_description => NULL,
      p_venue_id => '0d5145ca-5d5e-489e-8f01-a84fd8bf39c1'::uuid, p_location_name => 'The Warehouse Gym DIFC',
      p_geo_location_id => '67e53ee4-d5bf-4ced-82f2-c8de28a12b91'::uuid, p_area_id => '7aeab558-fcc2-4559-b4a2-56832e57e33d'::uuid,
      p_start_at => timestamptz '2026-11-27 06:00 Asia/Dubai', p_end_at => timestamptz '2026-11-27 07:00 Asia/Dubai',
      p_capacity => 8, p_listing_visibility => 'public', p_rsvp_policy => 'open',
      p_request_id => 'a717f600-0000-4000-8000-000000000001'::uuid);
  EXCEPTION WHEN OTHERS THEN
    v_err := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  -- same error as before: a meta.venue_space_id that does not exist
  BEGIN
    PERFORM public.rpc_create_meetup(
      p_actor_type => 'player', p_sport_id => '91554c52-47b4-40e2-bf45-5f3b1e67f64a'::uuid,
      p_sport_variant_id => '6cde6a6d-7785-43e3-883d-be369ef47aa5'::uuid,
      p_title => 'KAN862 bad space', p_location_name => 'Somewhere', p_is_indoor => true,
      p_start_at => timestamptz '2026-11-28 06:00 Asia/Dubai',
      p_meta => '{"venue_space_id":"00000000-0000-4000-8000-000000000000"}'::jsonb);
    v_err2 := 'no error';
  EXCEPTION WHEN OTHERS THEN
    v_err2 := SQLSTATE || ' ' || SQLERRM;
  END;
  -- same error as before: no start_at (events.start_at NOT NULL)
  BEGIN
    PERFORM public.rpc_create_meetup(
      p_actor_type => 'player', p_sport_id => '91554c52-47b4-40e2-bf45-5f3b1e67f64a'::uuid,
      p_sport_variant_id => '6cde6a6d-7785-43e3-883d-be369ef47aa5'::uuid,
      p_title => 'KAN862 no start', p_location_name => 'Somewhere', p_is_indoor => true);
    v_err3 := 'no error';
  EXCEPTION WHEN OTHERS THEN
    v_err3 := SQLSTATE || ' ' || SQLERRM;
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k862_out VALUES ('mid', v_mid::text), ('mid2', v_mid2::text), ('err', v_err), ('err2', v_err2), ('err3', v_err3);
END $t$;

CREATE TEMP TABLE k862_m ON COMMIT DROP AS
SELECT m.id, m.event_id, m.host_actor_id, e.creator_profile_id, to_jsonb(m) AS mj, to_jsonb(e) AS ej
  FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
 WHERE m.id = (SELECT v::uuid FROM pg_temp.k862_out WHERE k = 'mid');

-- the create body with comments and string literals removed
CREATE TEMP TABLE k862_src ON COMMIT DROP AS
SELECT regexp_replace(regexp_replace(p.prosrc, '--[^\n]*', '', 'g'), '''[^'']*''', '''''', 'g') AS s
  FROM pg_proc p WHERE p.oid = 'public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)'::regprocedure;

INSERT INTO pg_temp.k862_tap
SELECT 1, (SELECT v FROM k862_out WHERE k='err') IS NULL, 'rpc_create_meetup returns without error',
       coalesce((SELECT v FROM k862_out WHERE k='err'), 'ok')
UNION ALL
SELECT 2, (SELECT count(*) FROM k862_m) = 1 AND EXISTS (SELECT 1 FROM k862_m
             WHERE creator_profile_id = '5eeb4305-9277-458e-a56f-a5ed77e3f208'),
       'meetup row created for the caller''s profile', (SELECT v FROM k862_out WHERE k='mid')
UNION ALL
SELECT 3, EXISTS (SELECT 1 FROM k862_m WHERE host_actor_id = creator_profile_id),
       'host_actor_id = creator_profile_id (as every existing row)', (SELECT host_actor_id::text FROM k862_m)
UNION ALL
SELECT 4, (SELECT count(*) FROM k862_m) = 1 AND (SELECT count(*) FROM k862_m m
             JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
                                 AND e.creator_profile_id = m.creator_profile_id
                                 AND e.request_id = 'a717f600-0000-4000-8000-000000000001') = 1
          AND (SELECT count(*) FROM public.meetups m2 WHERE m2.event_id = (SELECT event_id FROM k862_m)) = 1,
       'events<->meetups paired 1:1', (SELECT id::text || '>' || coalesce(event_id::text, 'null') FROM k862_m)
UNION ALL
SELECT 5, EXISTS (SELECT 1 FROM k862_m m JOIN public.meetup_rsvps r ON r.meetup_id = m.id
                    AND r.profile_id = m.creator_profile_id AND r.status = 'going'),
       'host is the first going RSVP', NULL
UNION ALL
SELECT 6, (SELECT p.proacl::text || '|' || p.prosecdef || '|' || array_to_string(p.proconfig, ',') || '|' || pg_get_userbyid(p.proowner)
             FROM pg_proc p WHERE p.oid = 'public.rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean)'::regprocedure)
          = '{postgres=X/postgres,service_role=X/postgres}|true|search_path=public, pg_temp|postgres',
       'rpc_create_meetup_legacy_v2 ACL/secdef/search_path/owner unchanged', NULL
UNION ALL
SELECT 7, (SELECT p.proacl::text || '|' || md5(p.prosrc) FROM pg_proc p WHERE p.oid =
             'public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)'::regprocedure)
          = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}|f347168e1c1a6b424ebabea41ff3e85f',
       'rpc_create_meetup ACL and body unchanged (no anon)', NULL
UNION ALL
-- 8 (catalog): the only meetups reference in the create body is one INSERT whose column list is retained-only
SELECT 8, (SELECT count(*) FROM k862_src, regexp_matches(s, '\mmeetups\M', 'g')) = 1
          AND (SELECT bool_and(trim(c) = ANY (ARRAY['id','event_id','vibe_key','meta','host_actor_id','members_only','description','location_name','is_indoor']))
                 FROM k862_src, regexp_matches(s, 'INSERT\s+INTO\s+public\.meetups\s*\(([^)]*)\)', 'i') AS mm,
                      unnest(string_to_array(mm[1], ',')) AS c),
       'legacy_v2 body references no Z01-dropped meetups column',
       (SELECT (regexp_match(s, 'INSERT\s+INTO\s+public\.meetups\s*\(([^)]*)\)', 'i'))[1] FROM k862_src)
UNION ALL
-- 9: while the legacy columns exist, every shared key on the meetups row equals the events parent
SELECT 9, (SELECT count(*) FROM k862_m) = 1 AND NOT EXISTS (
             SELECT 1 FROM k862_m, jsonb_object_keys(mj) k
              WHERE ej ? k AND k NOT IN ('id', 'search_tsv') AND mj->k IS DISTINCT FROM ej->k)
          AND (SELECT NOT (mj ? 'rsvp_policy') OR mj->'rsvp_policy' = ej->'join_policy' FROM k862_m)
          AND (SELECT NOT (mj ? 'search_tsv') OR (mj->>'search_tsv') LIKE '%''kan717'':1A%' FROM k862_m),
       'legacy meetups columns mirror events (title/time/venue/geo/joining/request_id; rsvp_policy; search_tsv has title)',
       (SELECT (mj->>'geo_location_id') || '/' || (ej->>'geo_location_id') FROM k862_m)
UNION ALL
SELECT 10, (SELECT v FROM k862_out WHERE k='mid2') = (SELECT v FROM k862_out WHERE k='mid')
           AND (SELECT count(*) FROM public.events WHERE event_type = 'meetup' AND request_id = 'a717f600-0000-4000-8000-000000000001') = 1,
       'request_id replay returns the same meetup, one events parent', (SELECT v FROM k862_out WHERE k='mid2')
UNION ALL
SELECT 11, (SELECT v FROM k862_out WHERE k='err2') LIKE '23503 kan713_space_not_found%',
       'unknown meta.venue_space_id still raises 23503 kan713_space_not_found', (SELECT v FROM k862_out WHERE k='err2')
UNION ALL
SELECT 12, (SELECT v FROM k862_out WHERE k='err3') LIKE '23502 %"start_at"%"events"%',
       'missing start_at still raises 23502 on events.start_at', (SELECT v FROM k862_out WHERE k='err3');

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label
                  || CASE WHEN detail IS NOT NULL THEN ' [' || detail || ']' ELSE '' END, E'\n' ORDER BY n)
       || E'\n# ' || count(*) FILTER (WHERE ok) || '/' || count(*) || ' passed' AS tap
  FROM pg_temp.k862_tap;

ROLLBACK;

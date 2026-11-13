-- KAN-717 F6 live proof: rpc_create_meetup as user a3ba3271 (profile 5eeb4305, contributor with a player row).
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK:
-- the meetup, its events parent and the host RSVP are undone by the final ROLLBACK.
--
-- Reproduces the KAN-717 web journey call of 2026-11-13: Gym, "KAN717 JWEB probe meetup F1", The Warehouse Gym
-- DIFC, 2026-11-27 06:00 Asia/Dubai, capacity 8, public, open, free.
-- RED on the pre-image: rpc_create_meetup_legacy_v2's INSERT INTO public.meetups never listed host_actor_id,
-- which has been NOT NULL with no default since the baseline (20260829080500), so the insert raised 23502.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k717f6_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k717f6_out (k text PRIMARY KEY, v text) ON COMMIT DROP;

DO $t$
DECLARE v_mid uuid; v_err text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', true);
    SET LOCAL ROLE authenticated;
    v_mid := public.rpc_create_meetup(
      p_actor_type => 'player', p_sport_id => '91554c52-47b4-40e2-bf45-5f3b1e67f64a'::uuid,
      p_sport_variant_id => '6cde6a6d-7785-43e3-883d-be369ef47aa5'::uuid,
      p_title => 'KAN717 JWEB probe meetup F1', p_description => NULL,
      p_venue_id => '0d5145ca-5d5e-489e-8f01-a84fd8bf39c1'::uuid, p_location_name => 'The Warehouse Gym DIFC',
      p_geo_location_id => '67e53ee4-d5bf-4ced-82f2-c8de28a12b91'::uuid, p_area_id => '7aeab558-fcc2-4559-b4a2-56832e57e33d'::uuid,
      p_start_at => timestamptz '2026-11-27 06:00 Asia/Dubai', p_end_at => timestamptz '2026-11-27 07:00 Asia/Dubai',
      p_capacity => 8, p_listing_visibility => 'public', p_rsvp_policy => 'open',
      p_request_id => 'a717f600-0000-4000-8000-000000000001'::uuid);
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    v_err := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k717f6_out VALUES ('mid', v_mid::text), ('err', v_err);
END $t$;

CREATE TEMP TABLE k717f6_m ON COMMIT DROP AS
SELECT m.id, m.event_id, e.creator_profile_id, m.host_actor_id   -- KAN-862 Z01: creator_profile_id lives on events only
  FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
 WHERE m.id = (SELECT v::uuid FROM pg_temp.k717f6_out WHERE k = 'mid');

INSERT INTO pg_temp.k717f6_tap
SELECT 1, (SELECT v FROM k717f6_out WHERE k='err') IS NULL, 'rpc_create_meetup returns without error',
       coalesce((SELECT v FROM k717f6_out WHERE k='err'), 'ok')
UNION ALL
SELECT 2, (SELECT count(*) FROM k717f6_m) = 1 AND EXISTS (SELECT 1 FROM k717f6_m
             WHERE creator_profile_id = '5eeb4305-9277-458e-a56f-a5ed77e3f208'),
       'meetup row created for the caller''s profile', (SELECT v FROM k717f6_out WHERE k='mid')
UNION ALL
SELECT 3, EXISTS (SELECT 1 FROM k717f6_m WHERE host_actor_id = creator_profile_id),
       'host_actor_id = creator_profile_id (as every existing row)', (SELECT host_actor_id::text FROM k717f6_m)
UNION ALL
SELECT 4, (SELECT count(*) FROM k717f6_m) = 1 AND (SELECT count(*) FROM k717f6_m m
             JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
                                 AND e.creator_profile_id = m.creator_profile_id
                                 AND e.request_id = 'a717f600-0000-4000-8000-000000000001') = 1
          AND (SELECT count(*) FROM public.meetups m2 WHERE m2.event_id = (SELECT event_id FROM k717f6_m)) = 1,
       'events<->meetups paired 1:1', (SELECT id::text || '>' || coalesce(event_id::text, 'null') FROM k717f6_m)
UNION ALL
SELECT 5, EXISTS (SELECT 1 FROM k717f6_m m JOIN public.meetup_rsvps r ON r.meetup_id = m.id
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
       'rpc_create_meetup ACL and body unchanged (no anon)', NULL;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label
                  || CASE WHEN detail IS NOT NULL THEN ' [' || detail || ']' ELSE '' END, E'\n' ORDER BY n)
       || E'\n# ' || count(*) FILTER (WHERE ok) || '/' || count(*) || ' passed' AS tap
  FROM pg_temp.k717f6_tap;

ROLLBACK;

-- KAN-910 (KAN-714 chain stage R; Epic KAN-708, Events P4): drop the dead 6-argument public.nearby_games.
--
-- WHY. public.nearby_games(double precision, double precision, integer, text, integer, integer) has no caller:
--   git grep -n -w nearby_games origin/staging -- lib test integration_test supabase/functions web   -> no match
--   git grep -n -w nearby_games origin/staging -- supabase tests -> only its own definition (baseline 9006-9037,
--   35818-35820; 20261105110000 [manifest 42]), the part-2 pin lists and the KAN-714/718 manifests and probes.
--   No other SQL body calls it. The app reads nearby games through public.rpc_get_nearby_games (the
--   get_nearby_games pair was already dropped by 20261105100000 Z01, seq 801-802). It is also broken on every
--   chain: its body reads g.sport, which games (and the kan714_games_read overlay) do not have
--   (KAN718_D04_DISPOSITION.md #11; KAN-871 ruling: "dead nearby_games ... drop preferred").
--
-- WHAT. Block 1 is a fail-closed drift guard on md5(prosrc) of the 6-arg oid. Block 2 is exactly one
-- DROP FUNCTION of that signature: no IF EXISTS, no CASCADE, no other overload, nothing else touched.
-- No BEGIN/COMMIT here: the Supabase CLI runs each migration in one transaction (with psql use
-- --single-transaction). IDEMPOTENT: no. A second run raises in block 1 (function missing); that is intended.
--
-- PIN. md5(prosrc) pin 19b0a6c0ce028c4273f46ece71713d9a = the baseline body (20260829080500:9006-9034), the
-- value 20261105110000 itself pins before it rewrites the function. 20261105110000 [manifest 42] then replaces
-- the body (games -> kan714_games_read); that post-image is 4132dec168331c547f299f1cccd04804 (md5 of the text
-- between the $function$ markers of 20261105110000:1047-1077). This file runs after 20261105110000 in chain
-- order, so the guard accepts exactly those two known bodies and refuses anything else.
--
-- AUTHORED ONLY. Nothing here was applied by the authoring ticket. Memphis applies it (D-043) when it
-- integrates the commit into staging. Local proof: supabase/tests/events_p4/kan714_r_nearby_games_6arg_drop_test.sql
--
-- ROLLBACK (after COMMIT). Run uncommented, in one transaction, as postgres. The body references a column that
-- does not exist (g.sport), so it is created with check_function_bodies off, as 20261105110000 was (KAN-871).
-- Pre-image, verbatim from 20261105110000_kan714_events_parent_reads_2.sql:1047-1077 ([manifest 42]):
-- KAN910-ROLLBACK-BEGIN
-- SET LOCAL check_function_bodies = off;
-- CREATE OR REPLACE FUNCTION public.nearby_games(p_lat double precision, p_lng double precision, p_radius integer DEFAULT 10000, p_sport text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
--  RETURNS TABLE(id uuid, sport text, title text, start_at timestamp with time zone, geo_location_id uuid, area_id uuid, lat double precision, lng double precision, district text, city text, capacity integer, slots_available integer, distance_m double precision)
--  LANGUAGE sql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
--   SELECT
--     g.id, g.sport, g.title, g.start_at,
--     g.geo_location_id, g.area_id,
--     ST_Y(gl.location::geometry) AS lat,
--     ST_X(gl.location::geometry) AS lng,
--     a.district, a.city,
--     g.capacity,
--     (g.capacity - COALESCE((
--       SELECT COUNT(*)::integer FROM public.game_roster gr
--       WHERE gr.game_id = g.id AND gr.status = 'confirmed'
--     ), 0)) AS slots_available,
--     ST_Distance(
--       ST_MakePoint(p_lng, p_lat)::geography,
--       gl.location
--     ) AS distance_m
--   FROM public.kan714_games_read g
--   JOIN public.geo_locations gl ON gl.id = g.geo_location_id
--   JOIN public.areas a ON a.id = g.area_id
--   WHERE g.is_cancelled = false
--     AND g.start_at > now()
--     AND ST_DWithin(gl.location, ST_MakePoint(p_lng, p_lat)::geography, p_radius)
--     AND (p_sport IS NULL OR g.sport = p_sport)
--   ORDER BY distance_m ASC, g.start_at ASC
--   LIMIT p_limit OFFSET p_offset;
-- $function$;
-- ALTER FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) OWNER TO postgres;
-- -- ACL as the repo chain leaves it (baseline 20260829080500:35818-35820; no later GRANT/REVOKE/COMMENT on it in
-- -- any migration). Re-create the live proacl instead if Memphis captured a different one before applying.
-- GRANT ALL ON FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) TO anon;
-- GRANT ALL ON FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) TO authenticated;
-- GRANT ALL ON FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) TO service_role;
-- KAN910-ROLLBACK-END
-- If the guard matched the baseline pin (20261105110000 not yet applied), restore the baseline body instead:
-- 20260829080500_baseline_schema.sql:9006-9037 (CREATE + OWNER), then the same three GRANTs.
-- Before applying, capture the live ACL for the record:
--   SELECT proacl FROM pg_proc
--    WHERE oid = 'public.nearby_games(double precision,double precision,integer,text,integer,integer)'::regprocedure;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  f oid := to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)');
  h text;
BEGIN
  IF f IS NULL THEN
    RAISE EXCEPTION 'KAN-910: public.nearby_games(double precision,double precision,integer,text,integer,integer) is missing';
  END IF;
  SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid = f;
  IF h IS NULL OR h NOT IN ('19b0a6c0ce028c4273f46ece71713d9a',   -- baseline body
                            '4132dec168331c547f299f1cccd04804') THEN -- 20261105110000 [manifest 42] body
    RAISE EXCEPTION 'KAN-910: nearby_games 6-arg body drifted (md5 %, expected 19b0a6c0ce028c4273f46ece71713d9a or 4132dec168331c547f299f1cccd04804)', h;
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Drop
-- ---------------------------------------------------------------------------------------------------------
DROP FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer);

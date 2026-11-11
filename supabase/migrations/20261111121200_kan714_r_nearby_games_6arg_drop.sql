-- KAN-910: drop the legacy 6-argument public.nearby_games overload.
--
--   public.nearby_games(double precision, double precision, integer, text, integer, integer)
--
-- Why: KAN718_D04_DISPOSITION.md row 11 -- the body reads g.sport, which public.games does not have (it is
-- sport_id), so every call errors on every chain. Nothing calls it: no pg_depend row, no view, trigger, policy,
-- default, constraint or index references it, no function or view body calls nearby_games( (word-boundary scan,
-- get_nearby_games / rpc_get_nearby_games excluded), and no client code, edge function or test calls it
-- (git grep -nw nearby_games origin/staging -- lib supabase/functions tests supabase). The app calls
-- rpc_get_nearby_games and get_nearby_games, which this migration does not touch.
--
-- Guard: the function must exist and its body must be the current definition -- the post-image installed by
-- 20261105110000_kan714_events_parent_reads_2.sql [manifest 42] (reads public.kan714_games_read):
-- md5(prosrc) = 4132dec168331c547f299f1cccd04804. (19b0a6c0ce028c4273f46ece71713d9a is the part 2 PRE-image
-- pin -- the baseline body reading public.games -- and is no longer what any chain at or past part 2 holds.)
-- Any other body aborts the migration before anything is dropped. DROP is plain: no IF EXISTS, no CASCADE, so an
-- unseen dependent also aborts it.
--
-- ROLLBACK (pre-image, from pg_get_functiondef on the tracked chain; owner and grants as in
-- 20260829080500_baseline_schema.sql:9037 / 35818-35820; no COMMENT exists on the function):
--
--   CREATE OR REPLACE FUNCTION public.nearby_games(p_lat double precision, p_lng double precision, p_radius integer DEFAULT 10000, p_sport text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
--    RETURNS TABLE(id uuid, sport text, title text, start_at timestamp with time zone, geo_location_id uuid, area_id uuid, lat double precision, lng double precision, district text, city text, capacity integer, slots_available integer, distance_m double precision)
--    LANGUAGE sql
--    STABLE SECURITY DEFINER
--    SET search_path TO 'public', 'pg_temp'
--   AS $function$
--     SELECT
--       g.id, g.sport, g.title, g.start_at,
--       g.geo_location_id, g.area_id,
--       ST_Y(gl.location::geometry) AS lat,
--       ST_X(gl.location::geometry) AS lng,
--       a.district, a.city,
--       g.capacity,
--       (g.capacity - COALESCE((
--         SELECT COUNT(*)::integer FROM public.game_roster gr
--         WHERE gr.game_id = g.id AND gr.status = 'confirmed'
--       ), 0)) AS slots_available,
--       ST_Distance(
--         ST_MakePoint(p_lng, p_lat)::geography,
--         gl.location
--       ) AS distance_m
--     FROM public.kan714_games_read g
--     JOIN public.geo_locations gl ON gl.id = g.geo_location_id
--     JOIN public.areas a ON a.id = g.area_id
--     WHERE g.is_cancelled = false
--       AND g.start_at > now()
--       AND ST_DWithin(gl.location, ST_MakePoint(p_lng, p_lat)::geography, p_radius)
--       AND (p_sport IS NULL OR g.sport = p_sport)
--     ORDER BY distance_m ASC, g.start_at ASC
--     LIMIT p_limit OFFSET p_offset;
--   $function$
--   ;
--   ALTER FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) OWNER TO postgres;
--   GRANT ALL ON FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) TO anon;
--   GRANT ALL ON FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) TO authenticated;
--   GRANT ALL ON FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer) TO service_role;
--   (PUBLIC EXECUTE is the CREATE default; the tracked chain's proacl before the drop was
--    {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}.)
--
-- LIVE CHECK for Memphis (read-only; run before applying -- expect one row, md5 4132dec1..., dependents 0,
-- body_callers 0, view_callers 0; after applying expect present = false):
--
--   SELECT to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)') IS NOT NULL AS present,
--          (SELECT md5(prosrc) FROM pg_proc
--            WHERE oid = to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)')) AS body_md5,
--          (SELECT count(*) FROM pg_depend
--            WHERE refclassid = 'pg_proc'::regclass
--              AND refobjid = to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)')) AS dependents,
--          (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--            WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
--              AND p.prosrc ~ '(^|[^A-Za-z0-9_])nearby_games\s*\(') AS body_callers,
--          (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
--            WHERE c.relkind IN ('v', 'm') AND n.nspname NOT IN ('pg_catalog', 'information_schema')
--              AND pg_get_viewdef(c.oid) ~ '(^|[^A-Za-z0-9_])nearby_games\s*\(') AS view_callers;

BEGIN;

DO $guard$
DECLARE
  v_md5 text;
BEGIN
  IF to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)') IS NULL THEN
    RAISE EXCEPTION 'KAN-910 guard: public.nearby_games(double precision,double precision,integer,text,integer,integer) is absent';
  END IF;
  SELECT md5(p.prosrc) INTO v_md5 FROM pg_proc p
   WHERE p.oid = 'public.nearby_games(double precision,double precision,integer,text,integer,integer)'::regprocedure;
  IF v_md5 IS DISTINCT FROM '4132dec168331c547f299f1cccd04804' THEN
    RAISE EXCEPTION 'KAN-910 guard: public.nearby_games 6-arg body drifted (md5 % expected 4132dec168331c547f299f1cccd04804)', v_md5;
  END IF;
END
$guard$;

DROP FUNCTION public.nearby_games(double precision, double precision, integer, text, integer, integer);

COMMIT;

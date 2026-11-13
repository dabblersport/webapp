-- KAN-855 (KAN-718 follow-up F2, Epic KAN-708): getnearbygames (inventory #8). DECISION: RETIRE.
--
-- This migration REPLACES NOTHING. It records the retirement on the function (COMMENT ON FUNCTION) so the decision
-- is in the catalogue where F8 (the Z01 re-scope) and its scans read it. It writes no function body, no grant and no
-- data, and it contains no DROP: removing the function belongs to F8.
--
-- WHY RETIRE AND NOT REWRITE (evidence, 2026-11-04, alpha-luxor @ e4890a9e):
--   1. No caller. `grep -rn getnearbygames lib supabase` finds no `.rpc('getnearbygames'` call and no
--      SupabaseConfig constant; the only hits are the baseline definition, comments and test manifests. The lib/
--      "getNearbyGames" names are Dart methods calling get_nearby_games (F1, retired) or rpc_get_nearby_games (the
--      live nearby list, KAN-723 / B04). No SQL function or view calls it (test T6).
--   2. It has never returned a row. The only definition is the baseline (20260829080500_baseline_schema.sql:7823);
--      no later migration replaces it. The LANGUAGE sql body joins public.geolocations and reads g.sport, g.lat,
--      g.lng, g.areaid and g.geolocationid; none exist in the repo schema (games has sport_id, area_id,
--      geo_location_id; there is no geolocations table). The dump loads with check_function_bodies = false, so it
--      fails at call time: ERROR 42P01 relation "public.geolocations" does not exist (local chain, test T4).
--   3. A working REWRITE would need SECURITY DEFINER plus a copied visibility predicate: public.events is FORCE RLS
--      with no API grant, so this SECURITY INVOKER function cannot read it as anon/authenticated. That is a
--      security-posture change to revive dead code, not a column conversion.
--   Ruling dreq-8ae9bcfa (option C): nothing here reads, keeps or removes a games column.
--
-- Z01 INTERPLAY. The body is a string ($$), not a SQL-standard BEGIN ATOMIC body, so it records no pg_depend row on
-- public.games and does not block Z01 (test T5). After Z01 it keeps failing as it fails today, until F8 drops it.
-- FOLLOW-UPS (not done here): F8 drops it. No lib/ caller exists, so no frontend follow-up.
--
-- FAIL-CLOSED GATE. The pre-image must be the baseline one (md5 of prosrc and the exact result signature). If the
-- live body differs, the evidence above was not taken against it: this migration refuses and the decision must be
-- re-taken from pg_get_functiondef on the live catalogue.
-- IDEMPOTENT: yes (COMMENT replaces the comment; the gate still holds).

DO $gate$
DECLARE
  sig    constant text := 'public.getnearbygames(double precision,double precision,double precision)';
  md     constant text := '69ad4a9016477af16c938e12272234d7';
  res    constant text := 'TABLE(id uuid, title text, sport text, start_at timestamp with time zone, lat double precision, lng double precision, areaid uuid, distance_m double precision)';
  fn     regprocedure := to_regprocedure(sig);
BEGIN
  IF fn IS NULL THEN
    RAISE EXCEPTION 'KAN-855 gate refused: % absent', sig;
  ELSIF (SELECT md5(prosrc) FROM pg_proc WHERE oid = fn) <> md THEN
    RAISE EXCEPTION 'KAN-855 gate refused: % body is not the baseline pre-image (md5 %)', sig,
      (SELECT md5(prosrc) FROM pg_proc WHERE oid = fn);
  ELSIF pg_get_function_result(fn) <> res THEN
    RAISE EXCEPTION 'KAN-855 gate refused: % result signature changed: %', sig, pg_get_function_result(fn);
  END IF;
END
$gate$;

COMMENT ON FUNCTION public.getnearbygames(double precision, double precision, double precision) IS
  'KAN-855 RETIRED (KAN-718 F2): broken since baseline (joins public.geolocations and reads games.sport/lat/lng/areaid/geolocationid, none exist: 42P01); no caller; use rpc_get_nearby_games. Removal is KAN-718 F8.';

DO $post$
BEGIN
  IF (SELECT count(*) FROM pg_proc
       WHERE oid = to_regprocedure('public.getnearbygames(double precision,double precision,double precision)')
         AND obj_description(oid, 'pg_proc') LIKE 'KAN-855 RETIRED%'
         AND md5(prosrc) = '69ad4a9016477af16c938e12272234d7') <> 1 THEN
    RAISE EXCEPTION 'KAN-855 post: expected getnearbygames retired with its body unchanged';
  END IF;
END
$post$;

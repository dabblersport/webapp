-- KAN-854 (KAN-718 follow-up F1, Epic KAN-708): get_nearby_games x2 (inventory #5 and #6). DECISION: RETIRE.
--
-- This migration REPLACES NOTHING. It records the retirement on both overloads (COMMENT ON FUNCTION) so the
-- decision is in the catalogue where F8 (the Z01 re-scope) and its scans read it. It writes no function body, no
-- grant and no data, and it contains no DROP: removing the two functions belongs to F8.
--
-- WHY RETIRE AND NOT REWRITE (evidence, 2026-11-04, re-verified on alpha-karnak @ c30a6644):
--   1. Both overloads are already broken on every call. The only definitions are the baseline
--      (20260829080500_baseline_schema.sql:7381 and :7421); no later migration replaces either. Both bodies
--      select g.lat and g.lng, and public.games has no lat or lng column (baseline CREATE TABLE "public"."games").
--      plpgsql does not check this at CREATE, so it fails at run time: ERROR 42703 column g.lat does not exist
--      (shown on the local chain; supabase/tests/events_p4/kan718_f1_get_nearby_games_test.sql T4). No caller has
--      received a row from either overload since the baseline.
--   2. No caller can reach them. The two lib/ `.rpc('get_nearby_games'` calls are dead:
--      - lib/features/games/data/datasources/supabase_games_datasource.dart:672 sends lat/lng/radius_km/
--        page_offset/page_limit; no overload has those parameter names, so PostgREST cannot resolve it. Its only
--        caller, GamesRepositoryImpl.getNearbyGames (games_repository_impl.dart:329), has no caller in lib/.
--      - lib/data/repositories/nearby_games_repository_impl.dart:23 is reached only from explore's
--        nearbyGamesProvider (lib/features/explore/providers/nearby_games_providers.dart:62), which no screen
--        watches: games_screen.dart and features/games/providers.dart both `hide nearbyGamesProvider`.
--      The live nearby list uses rpc_get_nearby_games (KAN-723 / B04, already converted to events).
--   3. No SQL function or view in the migration chain calls get_nearby_games (only B05 comment lines name it).
--   4. A working REWRITE would need SECURITY DEFINER plus a copied visibility predicate (public.events is FORCE
--      RLS with no API grant, so this SECURITY INVOKER function cannot read it as anon/authenticated). That is a
--      security-posture change to revive dead code, not a column conversion.
--   F2 getnearbygames is a different function and ticket; it is not touched here.
--
-- Z01 INTERPLAY. plpgsql bodies create no pg_depend rows on columns, so leaving the bodies unchanged does not block
-- Z01 (the test asserts it). After Z01 they keep failing exactly as they fail today, until F8 drops them.
-- FOLLOW-UPS (not done here): F8 drops both overloads; frontend deletes the two dead lib/ callers above.
--
-- FAIL-CLOSED GATE. The pre-image must be the baseline one (md5 of prosrc and the exact result signature). If the
-- live body differs, the evidence above was not taken against it: this migration refuses and the decision must
-- be re-taken from pg_get_functiondef on the live catalogue.
-- IDEMPOTENT: yes (COMMENT replaces the comment; the gate still holds).

DO $gate$
DECLARE
  fails text[] := '{}';
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('public.get_nearby_games(double precision,double precision,double precision)', 'be73f2aefdf274c057b57908203ea8e5',
       'TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, sport_id uuid, area_id uuid, distance_meters double precision)'),
      ('public.get_nearby_games(double precision,double precision,integer)', 'f1bd3be9053559637086fdad82dffd90',
       'TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, distance_meters double precision)')
    ) v(sig, src_md5, result)
  LOOP
    IF to_regprocedure(r.sig) IS NULL THEN
      fails := fails || format('%s: absent', r.sig);
    ELSIF (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.sig)) <> r.src_md5 THEN
      fails := fails || format('%s: body is not the baseline pre-image (md5 %s)', r.sig,
                               (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.sig)));
    ELSIF pg_get_function_result(to_regprocedure(r.sig)) <> r.result THEN
      fails := fails || format('%s: result signature changed: %s', r.sig, pg_get_function_result(to_regprocedure(r.sig)));
    END IF;
  END LOOP;
  IF cardinality(fails) > 0 THEN
    RAISE EXCEPTION 'KAN-854 gate refused: %', array_to_string(fails, '; ');
  END IF;
END
$gate$;

COMMENT ON FUNCTION public.get_nearby_games(double precision, double precision, double precision) IS
  'KAN-854 RETIRED (KAN-718 F1): broken since baseline (selects games.lat/lng, which do not exist: 42703); no reachable caller; use rpc_get_nearby_games. Removal is KAN-718 F8.';
COMMENT ON FUNCTION public.get_nearby_games(double precision, double precision, integer) IS
  'KAN-854 RETIRED (KAN-718 F1): broken since baseline (selects games.lat/lng, which do not exist: 42703); no reachable caller; use rpc_get_nearby_games. Removal is KAN-718 F8.';

DO $post$
BEGIN
  IF (SELECT count(*) FROM pg_proc
       WHERE pronamespace = 'public'::regnamespace AND proname = 'get_nearby_games'
         AND obj_description(oid, 'pg_proc') LIKE 'KAN-854 RETIRED%'
         AND md5(prosrc) IN ('be73f2aefdf274c057b57908203ea8e5', 'f1bd3be9053559637086fdad82dffd90')) <> 2 THEN
    RAISE EXCEPTION 'KAN-854 post: expected both overloads retired with their bodies unchanged';
  END IF;
END
$post$;

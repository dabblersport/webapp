-- KAN-664 probes. Run AFTER 20261027120000_kan664_ratings_read_paths.sql is applied, as postgres, in ONE transaction ending in ROLLBACK.
-- Hook-safe: no drops, no writes to the auth schema, no commit, no bare star. Fixtures are existing rows picked read-only; the only writes are
-- one user_reputation_aggregate row (P5), rolled back with the transaction. Output: one row per probe; the last statement raises on any failure.
-- Data-dependent probes (P4, P6) record ok=true with detail 'skipped: no fixture' when the live data has no suitable row; read the detail column.
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);
GRANT ALL ON _r TO authenticated;
CREATE FUNCTION pg_temp.chk(p_name text, p_cond boolean, p_detail text DEFAULT '') RETURNS void LANGUAGE sql AS $f$
  INSERT INTO _r VALUES (p_name, COALESCE(p_cond,false), p_detail) $f$;
CREATE FUNCTION pg_temp.as_user(p_user uuid) RETURNS void LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', json_build_object('sub', p_user, 'role','authenticated')::text, true),
         set_config('request.jwt.claim.sub', COALESCE(p_user::text,''), true) $f$;

DO $$
DECLARE
  oid1 oid := to_regprocedure('public.rpc_get_unrated_coplayers(uuid)')::oid;
  oid2 oid := to_regprocedure('public.rpc_get_user_rating_aggregate(uuid)')::oid;
  oid3 oid := to_regprocedure('public.rpc_list_rating_dimensions()')::oid;
  t text; tbl text[] := ARRAY['user_reputation_events','ratings','game_rating_events','venue_rating_events','rating_reports'];
  vw text; vws text[] := ARRAY['v_reputation_leaderboard','v_reliable_teammate_candidates'];
BEGIN
  -- P1 new functions: exist, SECURITY DEFINER, pinned search_path, no PUBLIC/anon execute, authenticated may execute
  PERFORM pg_temp.chk('P1.1 both read functions exist', oid1 IS NOT NULL AND oid2 IS NOT NULL AND oid3 IS NOT NULL);
  PERFORM pg_temp.chk('P1.2 security definer + search_path', (SELECT bool_and(p.prosecdef AND p.proconfig::text LIKE '%search_path=public%') FROM pg_proc p WHERE p.oid IN (oid1, oid2, oid3)));
  PERFORM pg_temp.chk('P1.3 no PUBLIC/anon execute', (SELECT bool_and(COALESCE(p.proacl::text,'') !~ '(^|[{,])=X/' AND NOT has_function_privilege('anon', p.oid, 'execute')) FROM pg_proc p WHERE p.oid IN (oid1, oid2, oid3)));
  PERFORM pg_temp.chk('P1.4 authenticated may execute', has_function_privilege('authenticated', oid1, 'execute') AND has_function_privilege('authenticated', oid2, 'execute') AND has_function_privilege('authenticated', oid3, 'execute'));
  PERFORM pg_temp.chk('P1.5 return columns carry no rater identity', (SELECT count(*) FROM pg_proc p, unnest(p.proargnames) n WHERE p.oid IN (oid1, oid2, oid3) AND n ILIKE '%rater%') = 0);
  -- P2 existing submit RPCs untouched (signatures present, authenticated only)
  PERFORM pg_temp.chk('P2.1 rpc_rate_user signature present', to_regprocedure('public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)') IS NOT NULL);
  PERFORM pg_temp.chk('P2.2 rpc_rate_user not executable by anon', NOT has_function_privilege('anon', to_regprocedure('public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)'), 'execute'), 'FAIL here = existing grant gap (baseline granted ALL to anon)');
  -- P3 anonymity at the privilege layer: clients cannot select any table/view that stores or exposes rater ids
  FOREACH t IN ARRAY tbl LOOP
    PERFORM pg_temp.chk('P3 no client SELECT on table '||t, to_regclass('public.'||t) IS NULL OR NOT (has_table_privilege('authenticated','public.'||t,'select') OR has_table_privilege('anon','public.'||t,'select')));
  END LOOP;
  FOREACH vw IN ARRAY vws LOOP
    PERFORM pg_temp.chk('P3 no client SELECT on view '||vw, to_regclass('public.'||vw) IS NULL OR NOT (has_table_privilege('authenticated','public.'||vw,'select') OR has_table_privilege('anon','public.'||vw,'select')));
  END LOOP;
  PERFORM pg_temp.chk('P3 no SELECT policy on user_reputation_events other than deny-all',
    NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_reputation_events' AND cmd IN ('SELECT','ALL') AND COALESCE(qual,'') <> 'false'));
END $$;

-- P3b the dimension list is non-empty and is the only tag source
DO $$
BEGIN
  PERFORM pg_temp.as_user((SELECT p.user_id FROM public.profiles p ORDER BY p.user_id LIMIT 1));
  PERFORM pg_temp.chk('P3b active rating dimensions listed', (SELECT count(d.key) FROM public.rpc_list_rating_dimensions() d) > 0, (SELECT string_agg(d.key, ',' ORDER BY d.sort_order) FROM public.rpc_list_rating_dimensions() d));
END $$;

-- P4 ratee-role session: a real ratee cannot read rater identity from the events table, and the aggregate function exposes none
DO $$
DECLARE
  ratee uuid; n integer := NULL; denied boolean := false;
BEGIN
  SELECT e.ratee_user_id INTO ratee FROM public.user_reputation_events e LIMIT 1;
  IF ratee IS NULL THEN
    PERFORM pg_temp.chk('P4 ratee cannot read rater identity', true, 'skipped: no fixture (no rating event exists)');
    RETURN;
  END IF;
  PERFORM pg_temp.as_user(ratee);
  EXECUTE 'set local role authenticated';
  BEGIN
    EXECUTE 'select count(rater_user_id) from public.user_reputation_events' INTO n;
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  EXECUTE 'reset role';
  PERFORM pg_temp.chk('P4.1 ratee select of rater ids is denied or empty', denied OR COALESCE(n,0) = 0, 'denied='||denied||' rows='||COALESCE(n::text,'null'));
  PERFORM pg_temp.chk('P4.2 aggregate function output columns', (SELECT p.proargnames::text FROM pg_proc p WHERE p.oid = to_regprocedure('public.rpc_get_user_rating_aggregate(uuid)')) = '{p_user_id,user_id,composite_score,event_count,dimension_means}');
END $$;

-- P5 threshold: below the existing minimum count -> no row; at it -> exactly one row. Number read from the same source as the function.
DO $$
DECLARE
  u uuid; thr integer; below integer; at_thr integer; zero integer;
BEGIN
  thr := COALESCE((SELECT (b.params ->> 'min_count')::integer FROM public.badge_rules b WHERE b.badge_key = 'reliable_teammate' LIMIT 1), 8);
  SELECT p.user_id INTO u FROM public.profiles p WHERE NOT EXISTS (SELECT 1 FROM public.user_reputation_aggregate a WHERE a.user_id = p.user_id) ORDER BY p.user_id LIMIT 1;
  IF u IS NULL THEN
    PERFORM pg_temp.chk('P5 threshold gating', true, 'skipped: no fixture user without an aggregate row');
    RETURN;
  END IF;
  PERFORM pg_temp.as_user(u);
  INSERT INTO public.user_reputation_aggregate(user_id, event_count, dim_sums, dim_counts, composite_score)
  VALUES (u, 0, '{"sportsmanship": 0}'::jsonb, '{"sportsmanship": 0}'::jsonb, 4.50);
  SELECT count(user_id) INTO zero FROM public.rpc_get_user_rating_aggregate(u);
  UPDATE public.user_reputation_aggregate SET event_count = thr - 1, dim_sums = '{"sportsmanship": 20}'::jsonb, dim_counts = '{"sportsmanship": 5}'::jsonb WHERE user_id = u;
  SELECT count(user_id) INTO below FROM public.rpc_get_user_rating_aggregate(u);
  UPDATE public.user_reputation_aggregate SET event_count = thr WHERE user_id = u;
  SELECT count(user_id) INTO at_thr FROM public.rpc_get_user_rating_aggregate(u);
  PERFORM pg_temp.chk('P5.1 count 0 -> no row', zero = 0, 'threshold='||thr);
  PERFORM pg_temp.chk('P5.2 count threshold-1 -> no row, no partial average', below = 0, 'threshold='||thr);
  PERFORM pg_temp.chk('P5.3 count = threshold -> one row', at_thr = 1, 'threshold='||thr);
  PERFORM pg_temp.chk('P5.4 dimension mean is sum/count', (SELECT (r.dimension_means ->> 'sportsmanship')::numeric FROM public.rpc_get_user_rating_aggregate(u) r) = 4.00);
END $$;

-- P6 unrated co-players: unauthenticated, non-member, not-finished and window rules; participant result equals roster minus self minus already-rated
DO $$
DECLARE
  g record; me uuid; outsider uuid; got uuid[]; want uuid[]; msg text;
BEGIN
  SELECT gm.id, gm.end_at INTO g FROM public.games gm
   WHERE NOT gm.is_cancelled AND gm.end_at < now() AND gm.end_at > now() - interval '7 days'
     AND (SELECT count(r.user_id) FROM public.game_roster r WHERE r.game_id = gm.id AND r.status = 'active') >= 2
   ORDER BY gm.end_at DESC LIMIT 1;
  PERFORM pg_temp.as_user(NULL);
  BEGIN PERFORM public.rpc_get_unrated_coplayers(COALESCE(g.id, gen_random_uuid())); msg := 'no error';
  EXCEPTION WHEN OTHERS THEN msg := SQLERRM; END;
  PERFORM pg_temp.chk('P6.1 signed-out is refused', msg = 'auth_required', msg);
  IF g.id IS NULL THEN
    PERFORM pg_temp.chk('P6 participant/outsider/set equality', true, 'skipped: no finished game inside the 7-day window with 2+ active players');
    RETURN;
  END IF;
  SELECT r.user_id INTO me FROM public.game_roster r WHERE r.game_id = g.id AND r.status = 'active' ORDER BY r.user_id LIMIT 1;
  SELECT p.user_id INTO outsider FROM public.profiles p WHERE NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g.id AND r.user_id = p.user_id)
     AND p.user_id <> (SELECT creator_user_id FROM public.games WHERE id = g.id) ORDER BY p.user_id LIMIT 1;
  PERFORM pg_temp.as_user(outsider);
  BEGIN PERFORM public.rpc_get_unrated_coplayers(g.id); msg := 'no error'; EXCEPTION WHEN OTHERS THEN msg := SQLERRM; END;
  PERFORM pg_temp.chk('P6.2 non-participant is refused', msg = 'rater_not_in_game', msg);
  want := ARRAY(SELECT DISTINCT x.u FROM (
      SELECT r.user_id AS u FROM public.game_roster r WHERE r.game_id = g.id AND r.status = 'active'
      UNION SELECT gm.creator_user_id FROM public.games gm WHERE gm.id = g.id) x
    WHERE x.u <> me AND NOT EXISTS (SELECT 1 FROM public.user_reputation_events e WHERE e.game_id = g.id AND e.rater_user_id = me AND e.ratee_user_id = x.u)
    ORDER BY x.u);
  PERFORM pg_temp.as_user(me);
  got := ARRAY(SELECT c.user_id FROM public.rpc_get_unrated_coplayers(g.id) c ORDER BY c.user_id);
  PERFORM pg_temp.chk('P6.3 result = roster+host minus self minus already rated', got = want, 'got '||cardinality(got)||' want '||cardinality(want));
  PERFORM pg_temp.chk('P6.4 caller never listed', NOT (me = ANY(got)));
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-664 probes FAILED: %', (SELECT string_agg(name, ', ') FROM _r WHERE NOT ok); END IF; END $$;
ROLLBACK;

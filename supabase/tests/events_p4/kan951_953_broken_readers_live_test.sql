-- KAN-951 / KAN-953 live proof. After 20261114124807 and 20261114125102: both get_nearby_games overloads,
-- get_home_feed(int,int) and rpc_autocomplete_entities are gone; rpc_get_nearby_games (the nearby list) and
-- get_home_feed(int,timestamptz) (the home feed) still answer around Dubai (25.2, 55.3) as authenticated
-- (a real profile), with no error.
-- One DO block as postgres that ends by raising its result line, so nothing it does survives.
-- RED on the pre-image: probes 1-2 (get_nearby_games overloads present, each raising 42703 / 42501) and 3 (the two
-- KAN-953 functions present).
DO $test$
DECLARE
  v_uid  uuid := '5858bd7d-180c-4370-855d-d5f0bbd2817a';  -- profile 3f346693-00c4-41b7-ad01-347e53c30883
  v_n int; v_txt text; v_out text; v_pass int; v_fail int;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS k951_tap (n serial, ok boolean, label text, detail text) ON COMMIT DROP;

  -- KAN-951: both overloads dropped.
  INSERT INTO k951_tap(ok, label, detail) VALUES (
    to_regprocedure('public.get_nearby_games(double precision,double precision,integer)') IS NULL,
    'get_nearby_games(f8,f8,int) dropped', coalesce(to_regprocedure('public.get_nearby_games(double precision,double precision,integer)')::text, 'absent'));
  INSERT INTO k951_tap(ok, label, detail) VALUES (
    to_regprocedure('public.get_nearby_games(double precision,double precision,double precision)') IS NULL,
    'get_nearby_games(f8,f8,f8) dropped', coalesce(to_regprocedure('public.get_nearby_games(double precision,double precision,double precision)')::text, 'absent'));

  -- KAN-953: both broken functions dropped.
  SELECT count(*) INTO v_n FROM pg_proc WHERE oid IN (
    coalesce(to_regprocedure('public.get_home_feed(integer,integer)'), 0),
    coalesce(to_regprocedure('public.rpc_autocomplete_entities(text,text[],text,integer)'), 0));
  INSERT INTO k951_tap(ok, label, detail) VALUES (v_n = 0, 'get_home_feed(int,int) and rpc_autocomplete_entities dropped', v_n || ' left');

  -- The readers the app does use still answer as authenticated.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO v_n FROM public.rpc_get_nearby_games(25.2::float8, 55.3::float8, 50000, NULL, 'distance', NULL);
    v_txt := v_n || ' rows';
  EXCEPTION WHEN OTHERS THEN v_n := -1; v_txt := SQLSTATE || ' ' || SQLERRM; END;
  EXECUTE 'RESET ROLE';
  INSERT INTO k951_tap(ok, label, detail) VALUES (v_n >= 0, 'authenticated: rpc_get_nearby_games Dubai answers', v_txt);

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO v_n FROM public.get_home_feed(20, NULL::timestamptz);
    v_txt := v_n || ' rows';
  EXCEPTION WHEN OTHERS THEN v_n := -1; v_txt := SQLSTATE || ' ' || SQLERRM; END;
  EXECUTE 'RESET ROLE';
  INSERT INTO k951_tap(ok, label, detail) VALUES (v_n >= 0, 'authenticated: get_home_feed(int,timestamptz) answers', v_txt);

  SELECT count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok),
         string_agg(format('%s %s %s (%s)', n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END, label, detail), E'\n' ORDER BY n)
    INTO v_pass, v_fail, v_out FROM k951_tap;
  RAISE EXCEPTION 'KAN-951/953 RESULT pass=% fail=%', v_pass, v_fail::text || E'\n' || v_out;
END
$test$;

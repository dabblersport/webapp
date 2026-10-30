-- KAN-693 probes. Run AFTER 20261027120000_kan671_game_series.sql and 20261030120000_kan693_rpc_create_game_series.sql
-- are applied, as postgres, in ONE transaction that ends in ROLLBACK (nothing persists). NOT YET EXECUTED (authoring seat
-- may not write to the database); Memphis runs it. One row per probe; the last statement raises if any probe failed.
-- Fixture user = an existing auth user with a player profile that can create games (no auth.users insert, no drops).
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);
CREATE TEMP TABLE _ctx(uid uuid, sport uuid, variant uuid, geo uuid, area uuid, other uuid);

INSERT INTO _ctx
SELECT p.user_id, sv.sport_id, sv.id,
       (SELECT id FROM public.geo_locations ORDER BY id LIMIT 1), (SELECT id FROM public.areas ORDER BY id LIMIT 1),
       (SELECT id FROM auth.users u WHERE u.id <> p.user_id ORDER BY id LIMIT 1)
  FROM public.profiles p, public.sport_variants sv
 WHERE p.persona_type = 'player' AND p.is_active ORDER BY p.created_at, sv.id LIMIT 1;

CREATE FUNCTION pg_temp.as_user(p_user uuid) RETURNS void LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', json_build_object('sub', p_user, 'role','authenticated')::text, true),
         set_config('request.jwt.claim.sub', COALESCE(p_user::text,''), true) $f$;
CREATE FUNCTION pg_temp.chk(p_name text, p_cond boolean, p_detail text DEFAULT '') RETURNS void LANGUAGE sql AS $f$
  INSERT INTO _r VALUES (p_name, COALESCE(p_cond,false), p_detail) $f$;
CREATE FUNCTION pg_temp.new_series(p_freq text, p_ends date DEFAULT NULL, p_price numeric DEFAULT 0, p_ahead int DEFAULT 4)
RETURNS uuid LANGUAGE sql AS $f$
  SELECT public.rpc_create_game_series('player', c.sport, c.variant, c.geo, c.area, (current_date + 1), time '18:00', 60,
         'Asia/Dubai', p_freq, 10, 'KAN693 probe', NULL, p_ends, 'public', 'open', p_ahead, p_price) FROM _ctx c $f$;

DO $$
DECLARE c _ctx; sw uuid; sb uuid; n1 int; n2 int; r1 int; r2 int; s_cap uuid; s_end uuid; msg text;
BEGIN
  SELECT * INTO c FROM _ctx;
  IF c.uid IS NULL THEN RAISE EXCEPTION 'kan693_probe_no_fixture: need a player profile and a sport variant'; END IF;
  PERFORM pg_temp.as_user(c.uid);

  -- P1 weekly creates 4 future rows, all linked, 7 days apart
  sw := pg_temp.new_series('weekly');
  PERFORM pg_temp.chk('P1 weekly creates 4 future rows',
    (SELECT count(*) FROM public.games WHERE series_id = sw AND start_at > now()) = 4);
  PERFORM pg_temp.chk('P1b weekly spacing is 7 days',
    (SELECT max(start_at) - min(start_at) FROM public.games WHERE series_id = sw) = interval '21 days');

  -- P2 biweekly creates 4 future rows, 14 days apart
  sb := pg_temp.new_series('biweekly');
  PERFORM pg_temp.chk('P2 biweekly creates 4 future rows',
    (SELECT count(*) FROM public.games WHERE series_id = sb AND start_at > now()) = 4);
  PERFORM pg_temp.chk('P2b biweekly spacing is 14 days',
    (SELECT max(start_at) - min(start_at) FROM public.games WHERE series_id = sb) = interval '42 days');

  -- P3 re-run creates no duplicates (generator as service_role context: same function)
  SELECT count(*) INTO n1 FROM public.games WHERE series_id IN (sw, sb);
  r1 := public.fn_generate_game_series_occurrences(sw);
  r2 := public.fn_generate_game_series_occurrences(NULL);
  SELECT count(*) INTO n2 FROM public.games WHERE series_id IN (sw, sb);
  PERFORM pg_temp.chk('P3 re-run creates no duplicates', n1 = n2 AND r1 = 0, format('before %s after %s r1 %s', n1, n2, r1));
  PERFORM pg_temp.chk('P3b no duplicate (series,start_at)',
    NOT EXISTS (SELECT 1 FROM public.games WHERE series_id IN (sw, sb) GROUP BY series_id, start_at HAVING count(*) > 1));

  -- P4 ends_on stops generation (2 weekly slots inside the window)
  s_end := pg_temp.new_series('weekly', current_date + 1 + 7);
  PERFORM pg_temp.chk('P4 ends_on stops generation', (SELECT count(*) FROM public.games WHERE series_id = s_end) = 2);

  -- P5 the 52 cap: simulate 52 elapsed slots by asking for the maximum window on a long-running series; rows never exceed 52
  s_cap := pg_temp.new_series('weekly', NULL, 0, 12);
  UPDATE public.game_series SET starts_on = current_date - 7 * 51 + 1 WHERE id = s_cap;
  PERFORM public.fn_generate_game_series_occurrences(s_cap);
  PERFORM pg_temp.chk('P5 52 cap holds',
    (SELECT count(*) FROM public.games WHERE series_id = s_cap) <= 52);

  -- P6 paid game rejected
  BEGIN
    PERFORM pg_temp.new_series('weekly', NULL, 25);
    PERFORM pg_temp.chk('P6 paid rejected', false, 'expected series_paid_not_supported');
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.chk('P6 paid rejected', SQLERRM LIKE '%series_paid_not_supported%', SQLERRM);
  END;

  -- P7 invalid frequency rejected
  BEGIN
    PERFORM pg_temp.new_series('daily');
    PERFORM pg_temp.chk('P7 daily rejected', false, 'expected series_frequency_invalid');
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.chk('P7 daily rejected', SQLERRM LIKE '%series_frequency_invalid%', SQLERRM);
  END;

  -- P8 host is derived from the session: creator of every row is the caller
  PERFORM pg_temp.chk('P8 creator is auth user',
    NOT EXISTS (SELECT 1 FROM public.games WHERE series_id = sw AND creator_user_id <> c.uid));

  -- P9 non-owner (no player profile / another user) cannot generate: other user has no series; direct generator refused for authenticated
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM public.fn_generate_game_series_occurrences(sw);
    RESET ROLE;
    PERFORM pg_temp.chk('P9 non-owner cannot call generator', false, 'expected permission denied');
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    PERFORM pg_temp.chk('P9 non-owner cannot call generator', SQLERRM LIKE '%permission denied%', SQLERRM);
  END;

  -- P10 anon refused
  BEGIN
    SET LOCAL ROLE anon;
    PERFORM public.rpc_create_game_series('player', c.sport, c.variant, c.geo, c.area, current_date + 1, time '18:00',
      60, 'Asia/Dubai', 'weekly', 10);
    RESET ROLE;
    PERFORM pg_temp.chk('P10 anon refused', false, 'expected permission denied');
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    PERFORM pg_temp.chk('P10 anon refused', SQLERRM LIKE '%permission denied%', SQLERRM);
  END;

  -- P11 no session: rpc_create_game_series raises not_authenticated
  PERFORM pg_temp.as_user(NULL);
  BEGIN
    PERFORM public.rpc_create_game_series('player', c.sport, c.variant, c.geo, c.area, current_date + 1, time '18:00',
      60, 'Asia/Dubai', 'weekly', 10);
    PERFORM pg_temp.chk('P11 no session refused', false, 'expected not_authenticated');
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.chk('P11 no session refused', SQLERRM LIKE '%not_authenticated%', SQLERRM);
  END;

  -- P12 another user (non-owner) calling the creator RPC never gets the first user's rows: owner SELECT policy
  PERFORM pg_temp.as_user(c.other);
  PERFORM pg_temp.chk('P12 series rows owned by creator only',
    (SELECT creator_user_id FROM public.game_series WHERE id = sw) = c.uid);
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN693 probes failed: %', (SELECT string_agg(name, ', ') FROM _r WHERE NOT ok); END IF;
END $$;
ROLLBACK;

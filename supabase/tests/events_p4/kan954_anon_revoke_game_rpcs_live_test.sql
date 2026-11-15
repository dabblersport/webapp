-- KAN-954 live proof: PUBLIC and anon lose EXECUTE on rpc_challenge_spawn_game, rpc_booking_hold_for_game,
-- rpc_reschedule_game and can_current_user_join_game; authenticated owners still succeed, authenticated non-owners are
-- still refused with the same errors, and can_current_user_join_game answers authenticated callers as before.
-- One DO block as postgres that ends by raising its result line (nothing survives).
-- RED on the pre-image: probes 1-5 (anon still has EXECUTE; anon spawn succeeds, anon hold reaches the NOT NULL,
-- anon reschedule answers not_host_or_not_found, anon can_current_user_join_game answers) and 14 (anon fixture spawned).
-- Seen 2026-11-15: pre-image pass=8 fail=6; after 20261115191313 pass=14 fail=0.
DO $test$
DECLARE
  v_uid   uuid := '5858bd7d-180c-4370-855d-d5f0bbd2817a';   -- owner (profile 3f346693-...)
  v_uid2  uuid := '5dacb715-c263-4af8-ba22-b7a68799cbc6';   -- non-owner, not admin, not venue admin
  v_pid   uuid := '3f346693-00c4-41b7-ad01-347e53c30883';
  v_sport uuid := '2502490a-0339-436c-8b5e-5ac1514606c9';
  v_var   uuid := '9208e6be-811a-4c76-9149-8dc736983dcc';
  v_space uuid := 'aabdc183-8345-4f83-b366-ff4a704ea3de';
  v_start timestamptz := date_trunc('hour', now()) + interval '41 days';
  v_cid uuid; v_fa uuid; v_fo uuid; v_fn uuid; v_g uuid; v_gs uuid; v_b uuid;
  v_n int; v_txt text; v_j jsonb; v_out text; v_pass int; v_fail int;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS k954_tap (n serial, ok boolean, label text, detail text) ON COMMIT DROP;
  GRANT INSERT ON k954_tap TO anon, authenticated;
  GRANT USAGE ON SEQUENCE k954_tap_n_seq TO anon, authenticated;

  -- 1. catalogue: no anon / PUBLIC EXECUTE, authenticated + service_role kept
  SELECT count(*) INTO v_n FROM unnest(ARRAY[
      'public.rpc_challenge_spawn_game(uuid,timestamptz,uuid)',
      'public.rpc_booking_hold_for_game(uuid,uuid,timestamptz,timestamptz)',
      'public.rpc_reschedule_game(uuid,timestamptz,timestamptz)',
      'public.can_current_user_join_game(uuid,text,uuid)']::regprocedure[]) f(oid)
   WHERE NOT has_function_privilege('anon', f.oid, 'EXECUTE')
     AND has_function_privilege('authenticated', f.oid, 'EXECUTE')
     AND has_function_privilege('service_role', f.oid, 'EXECUTE')
     AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = f.oid AND a.grantee = 0);
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_n = 4, 'ACL: anon and PUBLIC revoked, authenticated and service_role kept', v_n || '/4');

  -- fixtures: one for anon, one for the owner, one for the non-owner
  INSERT INTO public.challenges (owner_profile_id, owner_user_id, title, sport, sport_id) VALUES (v_pid, v_uid, 'KAN954 challenge', 'padel', v_sport) RETURNING id INTO v_cid;
  INSERT INTO public.challenge_fixtures (challenge_id) VALUES (v_cid) RETURNING id INTO v_fa;
  INSERT INTO public.challenge_fixtures (challenge_id) VALUES (v_cid) RETURNING id INTO v_fo;
  INSERT INTO public.challenge_fixtures (challenge_id) VALUES (v_cid) RETURNING id INTO v_fn;

  -- a game the owner created (no venue) for hold / reschedule / join
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_g := public.rpc_create_game('player', v_sport, v_var, 'KAN954 game', NULL, v_start + interval '3 hours', v_start + interval '4 hours',
            0, 'public', 'open', NULL, NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 25.2, 55.3, NULL, NULL, 0, NULL);
  EXECUTE 'RESET ROLE';

  -- 2-5. anon: every one of the four raises 42501
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN PERFORM public.rpc_challenge_spawn_game(v_fa, v_start, v_space); v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM; END;
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_txt LIKE '42501 %', 'anon rpc_challenge_spawn_game -> 42501', v_txt);
  BEGIN PERFORM public.rpc_booking_hold_for_game(v_g, v_space, v_start + interval '3 hours', v_start + interval '4 hours'); v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM; END;
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_txt LIKE '42501 %', 'anon rpc_booking_hold_for_game -> 42501', v_txt);
  BEGIN PERFORM public.rpc_reschedule_game(v_g, v_start + interval '5 hours', v_start + interval '6 hours'); v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM; END;
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_txt LIKE '42501 %', 'anon rpc_reschedule_game -> 42501', v_txt);
  BEGIN v_j := public.can_current_user_join_game(v_g, 'player', NULL); v_txt := 'no error ' || v_j::text;
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM; END;
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_txt LIKE '42501 %', 'anon can_current_user_join_game -> 42501', v_txt);
  EXECUTE 'RESET ROLE';

  -- 6-8. authenticated non-owner: refused with the same errors as before
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid2, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid2::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.rpc_challenge_spawn_game(v_fn, v_start, v_space); v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM; END;
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_txt = 'P0001 not_owner', 'non-owner spawn refused not_owner', v_txt);
  BEGIN PERFORM public.rpc_booking_hold_for_game(v_g, v_space, v_start + interval '3 hours', v_start + interval '4 hours'); v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM; END;
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_txt = 'P0001 not_authorized', 'non-owner booking hold refused not_authorized', v_txt);
  BEGIN PERFORM public.rpc_reschedule_game(v_g, v_start + interval '5 hours', v_start + interval '6 hours'); v_txt := 'no error';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM; END;
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_txt = 'P0001 not_host_or_not_found', 'non-owner reschedule refused not_host_or_not_found', v_txt);
  -- 9. can_current_user_join_game as authenticated (INVOKER, games has no policy) answers not_found, as before (KAN-947)
  v_j := public.can_current_user_join_game(v_g, 'player', NULL);
  INSERT INTO k954_tap(ok, label, detail) VALUES (v_j->>'reason' = 'not_found', 'authenticated can_current_user_join_game answers as before', v_j::text);
  EXECUTE 'RESET ROLE';

  -- 10-12. authenticated owner: spawn, booking hold and reschedule still work
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  DECLARE t_spawn text; t_hold text; t_resched text; v_j9 jsonb;
  BEGIN
    BEGIN v_gs := public.rpc_challenge_spawn_game(v_fo, v_start, v_space); t_spawn := coalesce(v_gs::text, 'null');
    EXCEPTION WHEN OTHERS THEN t_spawn := SQLSTATE || ' ' || SQLERRM; END;
    BEGIN v_b := public.rpc_booking_hold_for_game(v_g, v_space, v_start + interval '3 hours', v_start + interval '4 hours'); t_hold := coalesce(v_b::text, 'null');
    EXCEPTION WHEN OTHERS THEN t_hold := SQLSTATE || ' ' || SQLERRM; END;
    BEGIN t_resched := public.rpc_reschedule_game(v_g, v_start + interval '5 hours', v_start + interval '6 hours');
    EXCEPTION WHEN OTHERS THEN t_resched := SQLSTATE || ' ' || SQLERRM; END;
    v_j9 := public.can_current_user_join_game(v_g, 'player', NULL);
    EXECUTE 'RESET ROLE';
    INSERT INTO k954_tap(ok, label, detail) VALUES (v_gs IS NOT NULL AND (SELECT game_id FROM public.challenge_fixtures WHERE id = v_fo) = v_gs,
           'owner spawn works and links the fixture', t_spawn);
    INSERT INTO k954_tap(ok, label, detail) VALUES (v_b IS NOT NULL AND EXISTS (SELECT 1 FROM public.venue_bookings WHERE id = v_b AND source_id = v_g),
           'owner booking hold works', t_hold);
    INSERT INTO k954_tap(ok, label, detail) VALUES (t_resched = 'rescheduled' AND (SELECT start_at FROM public.events WHERE id = v_g) = v_start + interval '5 hours',
           'owner reschedule works', t_resched);
    INSERT INTO k954_tap(ok, label, detail) VALUES (v_j9->>'reason' = 'not_found', 'owner can_current_user_join_game answers as before', v_j9::text);
  END;

  -- 14. the anon fixture was not spawned
  INSERT INTO k954_tap(ok, label, detail) VALUES ((SELECT game_id FROM public.challenge_fixtures WHERE id = v_fa) IS NULL,
         'anon fixture untouched', coalesce((SELECT game_id FROM public.challenge_fixtures WHERE id = v_fa)::text, 'null'));

  SELECT count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok OR ok IS NULL),
         string_agg(format('%s %s %s (%s)', n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END, label, detail), E'\n' ORDER BY n)
    INTO v_pass, v_fail, v_out FROM k954_tap;
  RAISE EXCEPTION 'K954 RESULT pass=% fail=% %', v_pass, v_fail, E'\n' || v_out;
END
$test$;

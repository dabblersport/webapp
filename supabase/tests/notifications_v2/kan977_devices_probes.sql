-- KAN-977 [W0-4] Devices: live probe pack for 20261117045109_kan977_fcm_tokens_installations.sql.
-- Run as postgres on wtncuzcskpigqpmnxwws. The whole pack is one DO block that ends in RAISE EXCEPTION, so every
-- write rolls back; the exception message carries the results. Nothing persists.
-- Users A and B are the two oldest auth.users rows (stand-ins for the two staging accounts; any two users work).
--
-- Expected: every line "ok". Each probe that asserts a refusal (N*) is the negative control for the one before it.
--   P1  A registers two installations on android            -> A has 2 installation rows
--   P2  A1 refreshes its token (same installation)          -> still 2 rows, same id, new token   (control for P1)
--   P3  B registers with A2's token (account switch)        -> A2 row gone, token on B only, 1 row holds it
--   P4  legacy upsert (old build, onConflict user_id,platform), twice -> 1 legacy row, second token kept,
--                                                              installation rows untouched
--   P5  legacy upsert with an installation row's token      -> installation row removed, token on 1 row
--   P6  upgrade: register with the legacy row's token       -> legacy row removed
--   P7  unregister                                          -> true, then false; only that installation removed
--   P8  RLS: A sees 0 of B's rows; update/delete of B's rows affect 0; insert as B -> 42501
--   P9  anon: rpc_register_push_token -> 42501; select fcm_tokens -> 42501
--   N1  direct second row for same (user, installation)     -> 23505 fcm_tokens_user_installation_key
--   N2  register with installation id 'legacy:x'            -> 22023
--   N3  direct row with platform NULL and legacy id         -> 23514
--   N4  duplicate token with the normalize trigger disabled    -> 23505 fcm_tokens_token_key (index is the backstop)
--   N5  register with os_permission 'maybe'                 -> 22023
--
-- Run 2026-11-17 by backend-4 after apply (migration 20261117045109): P1 ok (2), P2 ok (2), P3 ok (holders 1),
-- P4 ok (1), P5 ok (holders 1), P6 ok (holders 1), P7 ok, P8 ok, P9 ok, N1 23505, N2 22023, N3 23514, N4 23505
-- fcm_tokens_token_key, N5 22023. After the rollback: 56 rows, 0 probe rows, fingerprint unchanged
-- (md5 8672b16650f826d1818d8c432b0746c9, same as the pre-image), both triggers enabled.
-- Why the legacy key cannot be a partial index: ON CONFLICT (user_id, platform) against a unique index
-- WHERE installation_id LIKE 'legacy:%' fails 42P10 (checked live on a temp table, 2026-11-17).

DO $probe$
DECLARE
  a uuid; b uuid; r text := ''; n int; id1 uuid; id2 uuid; ok boolean;
BEGIN
  SELECT id INTO a FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT id INTO b FROM auth.users WHERE id <> a ORDER BY created_at LIMIT 1;

  -- act as A
  PERFORM set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- P1
  id1 := public.rpc_register_push_token('kan977-A1', 'kan977-tokA1', 'android', '1.9.0+90', 'ar-AE', 'granted');
  id2 := public.rpc_register_push_token('kan977-A2', 'kan977-tokA2', 'android', '1.9.0+90', 'en-US', 'provisional');
  SELECT count(*) INTO n FROM public.fcm_tokens WHERE user_id = a AND installation_id LIKE 'kan977-A%';
  r := r || format(E'P1 two installations: %s (%s)\n', CASE WHEN n = 2 AND id1 <> id2 THEN 'ok' ELSE 'FAIL' END, n);

  -- P2
  ok := public.rpc_register_push_token('kan977-A1', 'kan977-tokA1b', 'android', '1.9.1+91', 'ar-AE', 'denied') = id1;
  SELECT count(*) INTO n FROM public.fcm_tokens WHERE user_id = a AND installation_id LIKE 'kan977-A%';
  ok := ok AND n = 2 AND EXISTS (SELECT 1 FROM public.fcm_tokens WHERE id = id1 AND token = 'kan977-tokA1b'
                                   AND app_version = '1.9.1+91' AND os_permission = 'denied' AND platform IS NULL
                                   AND device_platform = 'android');
  r := r || format(E'P2 refresh keeps one row: %s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n);

  -- P3 (switch to B)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  PERFORM public.rpc_register_push_token('kan977-B1', 'kan977-tokA2', 'iOS', '1.9.0+90', 'en-GB', 'granted');
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO n FROM public.fcm_tokens WHERE token = 'kan977-tokA2';
  ok := n = 1 AND NOT EXISTS (SELECT 1 FROM public.fcm_tokens WHERE id = id2)
       AND EXISTS (SELECT 1 FROM public.fcm_tokens WHERE token = 'kan977-tokA2' AND user_id = b);
  r := r || format(E'P3 token moves to B: %s (holders %s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n);

  -- P4 (back to A, old-build upsert exactly as PostgREST issues it)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  INSERT INTO public.fcm_tokens (user_id, token, platform, updated_at) VALUES (a, 'kan977-legA', 'android', now())
    ON CONFLICT (user_id, platform) DO UPDATE SET user_id = EXCLUDED.user_id, token = EXCLUDED.token,
                                                  platform = EXCLUDED.platform, updated_at = EXCLUDED.updated_at;
  INSERT INTO public.fcm_tokens (user_id, token, platform, updated_at) VALUES (a, 'kan977-legA2', 'android', now())
    ON CONFLICT (user_id, platform) DO UPDATE SET user_id = EXCLUDED.user_id, token = EXCLUDED.token,
                                                  platform = EXCLUDED.platform, updated_at = EXCLUDED.updated_at;
  SELECT count(*) INTO n FROM public.fcm_tokens WHERE user_id = a AND installation_id = 'legacy:android';
  ok := n = 1 AND EXISTS (SELECT 1 FROM public.fcm_tokens WHERE user_id = a AND installation_id = 'legacy:android'
                            AND token = 'kan977-legA2' AND device_platform = 'android' AND platform = 'android')
       AND EXISTS (SELECT 1 FROM public.fcm_tokens WHERE id = id1);
  r := r || format(E'P4 legacy upsert, one legacy row beside installation rows: %s (%s)\n',
                   CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n);

  -- P5 legacy upsert carrying A1's token (a downgrade on that device)
  INSERT INTO public.fcm_tokens (user_id, token, platform, updated_at) VALUES (a, 'kan977-tokA1b', 'android', now())
    ON CONFLICT (user_id, platform) DO UPDATE SET user_id = EXCLUDED.user_id, token = EXCLUDED.token,
                                                  platform = EXCLUDED.platform, updated_at = EXCLUDED.updated_at;
  SELECT count(*) INTO n FROM public.fcm_tokens WHERE token = 'kan977-tokA1b';
  ok := n = 1 AND NOT EXISTS (SELECT 1 FROM public.fcm_tokens WHERE id = id1);
  r := r || format(E'P5 legacy upsert takes the token, no duplicate: %s (holders %s)\n',
                   CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n);

  -- P6 upgrade: the same device registers through the RPC with the legacy row's token
  PERFORM public.rpc_register_push_token('kan977-A3', 'kan977-tokA1b', 'android', '2.0.0+100', 'ar-AE', 'granted');
  SELECT count(*) INTO n FROM public.fcm_tokens WHERE token = 'kan977-tokA1b';
  ok := n = 1 AND NOT EXISTS (SELECT 1 FROM public.fcm_tokens WHERE user_id = a AND installation_id = 'legacy:android');
  r := r || format(E'P6 upgrade retires the legacy row: %s (holders %s)\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END, n);

  -- P7 unregister
  PERFORM public.rpc_register_push_token('kan977-A4', 'kan977-tokA4', 'web', NULL, NULL, NULL);
  ok := public.rpc_unregister_push_token('kan977-A3');
  ok := ok AND NOT public.rpc_unregister_push_token('kan977-A3');
  ok := ok AND EXISTS (SELECT 1 FROM public.fcm_tokens WHERE user_id = a AND installation_id = 'kan977-A4')
           AND NOT EXISTS (SELECT 1 FROM public.fcm_tokens WHERE user_id = a AND installation_id = 'kan977-A3');
  r := r || format(E'P7 unregister removes only that installation: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- P8 RLS isolation (still A; B owns kan977-B1)
  SELECT count(*) INTO n FROM public.fcm_tokens WHERE user_id = b;
  ok := n = 0;
  UPDATE public.fcm_tokens SET locale = 'xx' WHERE user_id = b; GET DIAGNOSTICS n = ROW_COUNT; ok := ok AND n = 0;
  DELETE FROM public.fcm_tokens WHERE user_id = b;              GET DIAGNOSTICS n = ROW_COUNT; ok := ok AND n = 0;
  ok := ok AND NOT public.rpc_unregister_push_token('kan977-B1');
  BEGIN
    INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform)
      VALUES (b, 'kan977-forged', 'kan977-forged', 'android');
    ok := false;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  r := r || format(E'P8 RLS isolation: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- N1 / N2 / N3 / N5 as A
  BEGIN
    INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform)
      VALUES (a, 'kan977-A4', 'kan977-other', 'web');
    r := r || E'N1 duplicate installation: FAIL (accepted)\n';
  EXCEPTION WHEN unique_violation THEN
    r := r || E'N1 duplicate installation refused 23505: ok\n';
  END;
  BEGIN
    PERFORM public.rpc_register_push_token('legacy:x', 'kan977-n2', 'android');
    r := r || E'N2 legacy id via RPC: FAIL (accepted)\n';
  EXCEPTION WHEN invalid_parameter_value THEN r := r || E'N2 legacy id via RPC refused 22023: ok\n';
  END;
  BEGIN
    INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform)
      VALUES (a, 'legacy:android', 'kan977-n3', 'android');
    r := r || E'N3 platform NULL with legacy id: FAIL (accepted)\n';
  EXCEPTION WHEN check_violation THEN r := r || E'N3 platform NULL with legacy id refused 23514: ok\n';
  END;
  BEGIN
    PERFORM public.rpc_register_push_token('kan977-n5', 'kan977-n5', 'android', NULL, NULL, 'maybe');
    r := r || E'N5 bad os_permission: FAIL (accepted)\n';
  EXCEPTION WHEN invalid_parameter_value THEN r := r || E'N5 bad os_permission refused 22023: ok\n';
  END;

  -- P9 anon
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  PERFORM set_config('role', 'anon', true);
  ok := true;
  BEGIN PERFORM public.rpc_register_push_token('kan977-anon', 'kan977-anon', 'android'); ok := false;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM public.fcm_tokens; ok := false;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  r := r || format(E'P9 anon refused: %s\n', CASE WHEN ok THEN 'ok' ELSE 'FAIL' END);

  -- N4 the unique index holds even with the trigger disabled (inside the rolled-back block)
  EXECUTE 'RESET ROLE';
  EXECUTE 'ALTER TABLE public.fcm_tokens DISABLE TRIGGER fcm_tokens_normalize';
  BEGIN
    INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform)
      VALUES (b, 'kan977-B2', 'kan977-tokA2', 'android');
    r := r || E'N4 duplicate token, triggers off: FAIL (accepted)\n';
  EXCEPTION WHEN unique_violation THEN r := r || E'N4 duplicate token refused by fcm_tokens_token_key: ok\n';
  END;
  EXECUTE 'ALTER TABLE public.fcm_tokens ENABLE TRIGGER fcm_tokens_normalize';

  RAISE EXCEPTION E'KAN977 PROBE RESULTS (rolled back)\n%', r;
END
$probe$;

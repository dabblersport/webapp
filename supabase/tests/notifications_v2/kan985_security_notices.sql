-- KAN-985 + KAN-985b live test: security notices. Runs on wtncuzcskpigqpmnxwws as postgres.
-- One DO block ending in RAISE EXCEPTION: every write (sessions, ledger rows, notifications and the pg_net push
-- requests they enqueue, auth.users updates, the test account) is rolled back. The message is the result table.
-- Expected: every line PASS (lines marked "info" carry values only).
--
-- Users: A = dabbler.pro@proton.me, B = jidep35093@iconcubic.com (CEO-approved staging accounts); C = an account created
-- before KAN-985 shipped with no session history; NU = a throwaway account inserted here (created after ship).
-- Each positive probe is paired with a negative control.
DO $test$
DECLARE
  ship timestamptz := '2026-11-17 10:07:46+00';
  A   uuid := (SELECT id FROM auth.users WHERE email = 'dabbler.pro@proton.me');
  B   uuid := (SELECT id FROM auth.users WHERE email = 'jidep35093@iconcubic.com');
  C   uuid;
  NU  uuid := gen_random_uuid();
  BS  uuid;
  S1  uuid := gen_random_uuid();  -- A, app, I1 (first installation, fresh post-ship session -> notice, fix 2b)
  S2  uuid := gen_random_uuid();  -- A, app, I1 again (known)
  S3  uuid := gen_random_uuid();  -- A, app, I2 (new installation -> notice)
  S4  uuid := gen_random_uuid();  -- A, Firefox on Windows (new family -> notice, 3rd in the hour)
  S5  uuid := gen_random_uuid();  -- A, app, I2 again
  S6  uuid := gen_random_uuid();  -- A, Edge on Windows (new family, 4th in the hour -> capped)
  S7  uuid := gen_random_uuid();  -- A, curl20 (collapsed into known other:client)
  SC1 uuid := gen_random_uuid();  -- C, curl (pre-ship account without history -> notice, fix 2a)
  SC2 uuid := gen_random_uuid();  -- C, python-requests (same other:client family -> no notice)
  SN1 uuid := gen_random_uuid();  -- N, app (brand-new account: baseline)
  I1  text := 'kan985-test-inst-1';
  I2  text := 'kan985-test-inst-2';
  IB  text := 'kan985-test-inst-b';
  IN1 text := 'kan985-test-inst-n';
  dart text := 'Dart/3.13 (dart:io)';
  ff   text := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0';
  edge text := 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 Edg/130.0';
  res text[] := '{}';
  n0  int; n int; v jsonb; st text; code text; l1 uuid; l2 uuid; l3 uuid; l4 uuid; nrow record;
BEGIN
  IF A IS NULL OR B IS NULL THEN RAISE EXCEPTION 'test users missing'; END IF;
  SELECT u.id INTO C FROM auth.users u
   WHERE u.created_at < ship
     AND NOT EXISTS (SELECT 1 FROM public.security_sign_ins l WHERE l.user_id = u.id)
     AND NOT EXISTS (SELECT 1 FROM public.security_known_devices k WHERE k.user_id = u.id)
   ORDER BY u.created_at LIMIT 1;
  SELECT session_id INTO BS FROM public.security_sign_ins
   WHERE user_id = B AND signed_in_at < ship AND installation_id IS NULL
     AND EXISTS (SELECT 1 FROM auth.sessions s WHERE s.id = session_id)
   ORDER BY signed_in_at DESC LIMIT 1;
  IF C IS NULL OR BS IS NULL THEN RAISE EXCEPTION 'fixture missing (C=%, BS=%)', C, BS; END IF;

  SELECT count(*) INTO n0 FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.new_signin';

  -- T1 sign-in from a known family (app), not yet bound: ledger row 'known', no notice
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (S1, A, now(), now(), 'aal1', dart, '203.0.113.7');
  SELECT state INTO st FROM public.security_sign_ins WHERE session_id = S1;
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.new_signin';
  res := res || format('T1 session insert writes a ledger row (state=%s): %s', st, CASE WHEN st = 'known' THEN 'PASS' ELSE 'FAIL' END);
  res := res || format('T1 NEG known family writes no notice (%s new): %s', n - n0, CASE WHEN n = n0 THEN 'PASS' ELSE 'FAIL' END);
  res := res || format('T1 no IP stored, place NULL: %s',
    CASE WHEN (SELECT place_city IS NULL AND place_country IS NULL FROM public.security_sign_ins WHERE session_id = S1) THEN 'PASS' ELSE 'FAIL' END);

  -- T2 (fix 2b) a fresh post-ship session of an existing account binds its first installation: one notice
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S1)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.rpc_security_register_sign_in(I1, 'iOS', 'iPhone 15');
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.new_signin';
  res := res || format('T2 fix2b fresh post-ship sign-in, first installation, notifies (%s new, %s): %s', n - n0, v,
    CASE WHEN n = n0 + 1 AND v->>'state' = 'new' THEN 'PASS' ELSE 'FAIL' END);
  -- T2 NEG: a pre-ship (seeded) session of an existing account binds silently
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = B AND kind_key = 'security.new_signin';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', B, 'role', 'authenticated', 'session_id', BS)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.rpc_security_register_sign_in(IB, 'android', 'Galaxy S24');
  PERFORM set_config('role', 'postgres', true);
  res := res || format('T2 NEG fix2b pre-ship session binds silently (%s, B notices %s -> %s): %s', v, n,
    (SELECT count(*) FROM public.notifications WHERE to_user_id = B AND kind_key = 'security.new_signin'),
    CASE WHEN v->>'state' = 'known'
          AND (SELECT count(*) FROM public.notifications WHERE to_user_id = B AND kind_key = 'security.new_signin') = n
         THEN 'PASS' ELSE 'FAIL' END);

  -- T3 another sign-in from the known installation: no notice
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (S2, A, now(), now(), 'aal1', dart, '203.0.113.7');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S2)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.rpc_security_register_sign_in(I1, 'iOS', 'iPhone 15');
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.new_signin';
  res := res || format('T3 NEG sign-in from known installation writes no notice (total %s): %s', n - n0, CASE WHEN n = n0 + 1 THEN 'PASS' ELSE 'FAIL' END);

  -- T4 a new installation: one notice; binding again adds none
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (S3, A, now(), now(), 'aal1', dart, '198.51.100.9');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S3)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.rpc_security_register_sign_in(I2, 'android', 'Pixel 9');
  v := public.rpc_security_register_sign_in(I2, 'android', 'Pixel 9');
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.new_signin';
  res := res || format('T4 new installation writes exactly one notice (total %s): %s', n - n0, CASE WHEN n = n0 + 2 AND v->>'state' = 'new' THEN 'PASS' ELSE 'FAIL' END);
  SELECT n2.* INTO nrow FROM public.notifications n2 JOIN public.security_sign_ins l ON l.notification_id = n2.id WHERE l.session_id = S3;
  res := res || format('T4 info: dedupe=%s priority=%s', nrow.dedupe_key, nrow.priority);
  res := res || format('T4 lock-screen text has no device/city (title="%s" body="%s"): %s', nrow.title, nrow.body,
    CASE WHEN nrow.title NOT ILIKE '%pixel%' AND nrow.body NOT ILIKE '%pixel%' AND nrow.title NOT ILIKE '%android%' THEN 'PASS' ELSE 'FAIL' END);
  res := res || format('T4 inbox row holds the device (args.device=%s): %s', nrow.args->>'device', CASE WHEN nrow.args->>'device' = 'Pixel 9' THEN 'PASS' ELSE 'FAIL' END);
  SELECT id INTO l1 FROM public.security_sign_ins WHERE session_id = S1;
  SELECT id INTO l2 FROM public.security_sign_ins WHERE session_id = S2;
  SELECT id INTO l3 FROM public.security_sign_ins WHERE session_id = S3;

  -- T5 a family the user never used, unbound: notice from the trigger (3rd this hour, under the cap)
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (S4, A, now(), now(), 'aal1', ff, '192.0.2.44');
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.new_signin';
  SELECT id INTO l4 FROM public.security_sign_ins WHERE session_id = S4;
  res := res || format('T5 NEG(cap) 3rd notice in the hour still sent (total %s, %s): %s', n - n0,
    (SELECT device_label FROM public.security_sign_ins WHERE id = l4), CASE WHEN n = n0 + 3 THEN 'PASS' ELSE 'FAIL' END);

  -- T5b (cap) a 4th new device within the hour: ledger row 'new', no notice
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (S6, A, now(), now(), 'aal1', edge, '192.0.2.45');
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.new_signin';
  res := res || format('T5b cap: 4th new device in the hour gets no notice (total %s, ledger state=%s, label=%s, notification_id=%s): %s', n - n0,
    (SELECT state FROM public.security_sign_ins WHERE session_id = S6), (SELECT device_label FROM public.security_sign_ins WHERE session_id = S6),
    (SELECT notification_id FROM public.security_sign_ins WHERE session_id = S6),
    CASE WHEN n = n0 + 3 AND (SELECT state = 'new' AND notification_id IS NULL FROM public.security_sign_ins WHERE session_id = S6) THEN 'PASS' ELSE 'FAIL' END);

  -- T5c (collapse) every non-browser, non-app agent is one family
  res := res || format('T5c collapse: curl20/8.0, wget/1.21, node -> %s, %s, %s: %s',
    (public.security_device_from_agent('curl20/8.0')).device_key, (public.security_device_from_agent('Wget/1.21')).device_key,
    (public.security_device_from_agent('node')).device_key,
    CASE WHEN (public.security_device_from_agent('curl20/8.0')).device_key = 'other:client'
          AND (public.security_device_from_agent('Wget/1.21')).device_key = 'other:client' THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (S7, A, now(), now(), 'aal1', 'curl20/8.0', '192.0.2.46');
  res := res || format('T5c NEG A (had other:curl before) signs in with curl20: state=%s (old code: new family other:curl20): %s',
    (SELECT state FROM public.security_sign_ins WHERE session_id = S7),
    CASE WHEN (SELECT state FROM public.security_sign_ins WHERE session_id = S7) = 'known' THEN 'PASS' ELSE 'FAIL' END);

  -- T5d (fix 2a) a pre-ship account with no history: its next sign-in notifies; a 2nd scripted agent does not
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (SC1, C, now(), now(), 'aal1', 'curl/8.7.1', '192.0.2.47');
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (SC2, C, now(), now(), 'aal1', 'python-requests/2.31', '192.0.2.48');
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = C AND kind_key = 'security.new_signin';
  res := res || format('T5d fix2a pre-ship account without history: 1st sign-in state=%s, 2nd (other family member) state=%s, notices=%s: %s',
    (SELECT state FROM public.security_sign_ins WHERE session_id = SC1), (SELECT state FROM public.security_sign_ins WHERE session_id = SC2), n,
    CASE WHEN n = 1 AND (SELECT state FROM public.security_sign_ins WHERE session_id = SC1) = 'new'
          AND (SELECT state FROM public.security_sign_ins WHERE session_id = SC2) = 'known' THEN 'PASS' ELSE 'FAIL' END);

  -- T5e NEG (fix 2a/2b) a brand-new account: first sign-in and first installation stay silent baselines
  INSERT INTO auth.users (id, aud, role, email, created_at, updated_at)
  VALUES (NU, 'authenticated', 'authenticated', 'kan985-new-' || left(NU::text, 8) || '@example.invalid', now(), now());
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (SN1, NU, now(), now(), 'aal1', dart, '192.0.2.49');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', NU, 'role', 'authenticated', 'session_id', SN1)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.rpc_security_register_sign_in(IN1, 'iOS', 'iPhone 16');
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = NU AND kind_key = 'security.new_signin';
  res := res || format('T5e NEG brand-new account: sign-in + first installation silent (%s, notices=%s): %s', v, n,
    CASE WHEN n = 0 AND v->>'state' = 'known' THEN 'PASS' ELSE 'FAIL' END);

  -- T6 "This was me": refused from the session it describes, accepted from another device
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S3)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    v := public.rpc_security_confirm_sign_in(l3); code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T6 NEG self-confirm from the new device refused (%s): %s', code, CASE WHEN code = '42501' THEN 'PASS' ELSE 'FAIL' END);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S1)::text, true);
  v := public.rpc_security_confirm_sign_in(l3);
  PERFORM set_config('role', 'postgres', true);
  SELECT n2.* INTO nrow FROM public.notifications n2 JOIN public.security_sign_ins l ON l.notification_id = n2.id WHERE l.id = l3;
  res := res || format('T6 "This was me" -> ledger %s, notice args.state=%s is_read=%s: %s',
    (SELECT state FROM public.security_sign_ins WHERE id = l3), nrow.args->>'state', nrow.is_read,
    CASE WHEN (SELECT state FROM public.security_sign_ins WHERE id = l3) = 'confirmed' AND nrow.args->>'state' = 'confirmed' AND nrow.is_read THEN 'PASS' ELSE 'FAIL' END);

  -- T7 "Not me" on ANOTHER installation (I2) from S1 (on I1): signs out S3 + S5, removes I2's token
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal, user_agent, ip)
  VALUES (S5, A, now(), now(), 'aal1', dart, '198.51.100.9');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S5)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.rpc_security_register_sign_in(I2, 'android', 'Pixel 9');
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform) VALUES (A, I2, 'kan985-test-token-2', 'android');
  INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform) VALUES (A, I1, 'kan985-test-token-1', 'iOS');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S1)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    v := public.rpc_security_not_me(l1); code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T7 NEG "Not me" on the current session refused (%s): %s', code, CASE WHEN code = '22023' THEN 'PASS' ELSE 'FAIL' END);
  v := public.rpc_security_not_me(l3);
  PERFORM set_config('role', 'postgres', true);
  res := res || format('T7 "Not me" other installation: %s: %s', v,
    CASE WHEN (v->>'route_to_password_change')::boolean AND (v->>'revoked_sessions')::int = 2
          AND NOT (v->>'kept_current_device')::boolean THEN 'PASS' ELSE 'FAIL' END);
  res := res || format('T7 I2 sessions gone, S1 S2 S4 alive: %s',
    CASE WHEN NOT EXISTS (SELECT 1 FROM auth.sessions WHERE id IN (S3, S5))
          AND (SELECT count(*) FROM auth.sessions WHERE id IN (S1, S2, S4)) = 3 THEN 'PASS' ELSE 'FAIL' END);
  res := res || format('T7 NEG(fix1) other installation: I2 token removed (%s left), I2 no longer known: %s',
    (SELECT count(*) FROM public.fcm_tokens WHERE user_id = A AND installation_id = I2),
    CASE WHEN NOT EXISTS (SELECT 1 FROM public.fcm_tokens WHERE user_id = A AND installation_id = I2)
          AND NOT EXISTS (SELECT 1 FROM public.security_known_devices WHERE user_id = A AND kind = 'installation' AND device_key = I2)
         THEN 'PASS' ELSE 'FAIL' END);

  -- T7b (fix 1) "Not me" on an OLD session of the caller's OWN installation (S2 on I1, caller S1 on I1)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S1)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.rpc_security_not_me(l2);
  PERFORM set_config('role', 'postgres', true);
  res := res || format('T7b fix1 own installation: %s: %s', v,
    CASE WHEN (v->>'revoked_sessions')::int = 1 AND (v->>'kept_current_device')::boolean
          AND v->>'signed_out_installation' IS NULL AND (v->>'route_to_password_change')::boolean THEN 'PASS' ELSE 'FAIL' END);
  res := res || format('T7b fix1 only S2 revoked (S2=%s S1=%s), I1 token kept (%s), I1 still known (%s): %s',
    EXISTS (SELECT 1 FROM auth.sessions WHERE id = S2), EXISTS (SELECT 1 FROM auth.sessions WHERE id = S1),
    (SELECT count(*) FROM public.fcm_tokens WHERE user_id = A AND installation_id = I1),
    EXISTS (SELECT 1 FROM public.security_known_devices WHERE user_id = A AND kind = 'installation' AND device_key = I1),
    CASE WHEN NOT EXISTS (SELECT 1 FROM auth.sessions WHERE id = S2) AND EXISTS (SELECT 1 FROM auth.sessions WHERE id = S1)
          AND EXISTS (SELECT 1 FROM public.fcm_tokens WHERE user_id = A AND installation_id = I1)
          AND EXISTS (SELECT 1 FROM public.security_known_devices WHERE user_id = A AND kind = 'installation' AND device_key = I1)
         THEN 'PASS' ELSE 'FAIL' END);

  -- T8 another user cannot revoke, confirm or read A's sign-ins
  PERFORM set_config('request.jwt.claims', json_build_object('sub', B, 'role', 'authenticated', 'session_id', BS)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    v := public.rpc_security_not_me(l4); code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T8 NEG B cannot revoke A''s session (%s): %s', code, CASE WHEN code = 'P0002' THEN 'PASS' ELSE 'FAIL' END);
  BEGIN
    v := public.rpc_security_confirm_sign_in(l4); code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T8 NEG B cannot confirm A''s sign-in (%s): %s', code, CASE WHEN code = 'P0002' THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO n FROM public.security_sign_ins WHERE user_id = A;
  res := res || format('T8 NEG RLS: B reads %s of A''s ledger rows: %s', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO n FROM public.security_sign_ins;
  res := res || format('T8 RLS: B reads only own rows (%s visible): %s', n,
    CASE WHEN n > 0 AND (SELECT bool_and(user_id = B) FROM public.security_sign_ins) THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO n FROM public.rpc_security_sign_ins(200) r WHERE r.id IN (l1, l3, l4);
  res := res || format('T8 NEG read RPC as B returns %s of A''s rows: %s', n, CASE WHEN n = 0 THEN 'PASS' ELSE 'FAIL' END);
  BEGIN
    PERFORM count(*) FROM public.security_known_devices; code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T8 NEG known-devices table not readable by a client (%s): %s', code, CASE WHEN code = '42501' THEN 'PASS' ELSE 'FAIL' END);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', A, 'role', 'authenticated', 'session_id', S1)::text, true);
  SELECT count(*) INTO n FROM public.security_sign_ins WHERE id IN (l1, l3, l4);
  res := res || format('T8 RLS positive: A reads own rows (%s of 3): %s', n, CASE WHEN n = 3 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO n FROM public.rpc_security_sign_ins(200) r WHERE r.id = l1 AND r.is_current AND r.is_active;
  res := res || format('T8 read RPC flags current session: %s', CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END);
  PERFORM set_config('role', 'anon', true);
  BEGIN
    PERFORM count(*) FROM public.security_sign_ins; code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T8 NEG anon cannot read the ledger (%s): %s', code, CASE WHEN code = '42501' THEN 'PASS' ELSE 'FAIL' END);
  BEGIN
    PERFORM public.rpc_security_sign_ins(5); code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T8 NEG anon cannot call the read RPC (%s): %s', code, CASE WHEN code = '42501' THEN 'PASS' ELSE 'FAIL' END);
  PERFORM set_config('role', 'postgres', true);
  res := res || format('T8 NEG A''s S4 session still alive after B''s attempt: %s',
    CASE WHEN EXISTS (SELECT 1 FROM auth.sessions WHERE id = S4) THEN 'PASS' ELSE 'FAIL' END);

  -- T9 password and email change from auth.users; other columns change nothing; muting is refused
  BEGIN
    INSERT INTO public.notification_settings (user_id, muted_kinds) VALUES (A, ARRAY['security.password_changed'])
    ON CONFLICT (user_id) DO UPDATE SET muted_kinds = EXCLUDED.muted_kinds;
    code := 'none';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  res := res || format('T9 NEG muting a security kind is refused (%s): %s', code, CASE WHEN code = '22023' THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO n0 FROM public.notifications WHERE to_user_id = A AND kind_key IN ('security.password_changed', 'security.email_changed');
  UPDATE auth.users SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"kan985":"x"}', last_sign_in_at = now() WHERE id = A;
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key IN ('security.password_changed', 'security.email_changed');
  res := res || format('T9 NEG update of other auth.users columns writes no notice (%s new): %s', n - n0, CASE WHEN n = n0 THEN 'PASS' ELSE 'FAIL' END);
  UPDATE auth.users SET encrypted_password = extensions.crypt('kan985-not-a-real-password', extensions.gen_salt('bf')) WHERE id = A;
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.password_changed';
  res := res || format('T9 password change writes one notice (%s): %s', n, CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END);
  UPDATE auth.users SET email = 'kan985-live-test@example.invalid' WHERE id = A;
  SELECT count(*) INTO n FROM public.notifications WHERE to_user_id = A AND kind_key = 'security.email_changed';
  res := res || format('T9 email change writes one notice (%s): %s', n, CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END);

  RAISE EXCEPTION E'KAN985 RESULTS (rolled back)\n%', array_to_string(res, E'\n');
END
$test$;

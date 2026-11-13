-- KAN-862 P4 (write path) live proof. Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely
-- inside BEGIN ... ROLLBACK. Every RPC call runs in its own subtransaction that is always undone; the twins live in
-- pg_temp. Nothing persists.
--
-- P4 decisions under test:
--   kan809  REBASED and applied (20261113144620_kan862_p4_kan809_rpc_update_game_stale_guard.sql): the 18-arg
--           rpc_update_game overload with p_expected_updated_at.
--   kan810  SUPERSEDED, live already covers it: rpc_cancel_game_kan712_inner (KAN-913/KAN-718 body) keeps the first
--           cancel's cancelled_reason on a repeat cancel.
--   kan806  SUPERSEDED, no change: kan712_update_event_shared has no caller and refuses 55000 kan712_not_cut_over
--           since KAN-718 dropped trg_zz_kan712_events_compat_mirror; its body reads no games/meetups column.
--   kan712_legacy_guard  no change: its only attachment is meetups.trg_zz_kan712_meetups_guard, which Z01 drops.
--
-- METHOD. G = the first future, uncancelled game with a price, H = its creator (not admin). Calls run as
-- SET LOCAL ROLE authenticated with request.jwt.claims {sub: H}.
--   T1  new overload: present, SECURITY DEFINER, search_path '', owner postgres, returns text, 14 defaults
--   T2  new overload ACL = the 17-arg wrapper ACL; anon and PUBLIC cannot execute
--   T3  17-arg wrapper and KAN-718 inner unchanged (md5 prosrc pins measured before the apply)
--   T4  sanity: matching p_expected_updated_at -> 'updated' (the path executes)
--   T5  stale p_expected_updated_at -> ERR 40001 stale_update                        (RED before: ERR 42883)
--   T6  negative control: the twin without the guard returns 'updated' on the T5 input
--   T7  NULL p_expected_updated_at -> 'updated' (no check)
--   T8  named call without p_expected_updated_at -> 'updated' (old shape still resolves, not ambiguous)
--   T9  3-arg positional call -> ERR P0001 price_required (old overload body)
--   T10 unknown game with an expected version -> ERR P0001 not_host_or_not_found, not stale_update
--   T11 kan810: host cancels G with 'A', then again with 'B' -> both 'cancelled', reason stays 'A' on events and games
--   T12 negative control: the inner twin without the KAN-810 guard leaves reason 'B'
--   T13 kan810: rpc_cancel_game wrapper and inner attributes/ACL unchanged
--   T14 kan806: kan712_update_event_shared(G, '{}') as postgres -> ERR 55000 kan712_not_cut_over
--   T15 kan806: no function, trigger or view names kan712_update_event_shared outside a HINT string (legacy_guard's
--       42501 HINT mentions it as advice; it is not a call); body unchanged; reads no games/meetups
--   T16 legacy_guard: exactly one trigger uses it, meetups.trg_zz_kan712_meetups_guard (Z01 seq 304); body unchanged
--   T17 new overload body names neither public.games nor public.meetups (no Z01-manifest column read)
--   T18 every authenticated call really ran as role authenticated
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k862p4_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k862p4_out (k text PRIMARY KEY, who text, v text) ON COMMIT DROP;

-- Runs p_sql as authenticated (sub p_uid) in a subtransaction that is always undone. p_after (optional) runs as
-- postgres inside the same subtransaction, after p_sql, and its text is appended.
CREATE FUNCTION pg_temp.k862p4_call(p_key text, p_uid uuid, p_sql text, p_after text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE r text; a text; who text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    PERFORM set_config('role', 'authenticated', true);
    who := current_user;
    EXECUTE p_sql INTO r;
    IF p_after IS NOT NULL THEN
      PERFORM set_config('role', 'postgres', true);
      EXECUTE p_after INTO a;
      r := r || ' | ' || a;
    END IF;
    RAISE EXCEPTION 'k862p4_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k862p4_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k862p4_out VALUES (p_key, who, r);
END $f$;

-- Twins from the live definitions (T-058), each with exactly one guard removed.
DO $mk$
DECLARE d text; d2 text;
BEGIN
  d := pg_get_functiondef('public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure);
  d2 := replace(replace(d, 'FUNCTION public.rpc_update_game(', 'FUNCTION pg_temp.k862p4_update_noguard('),
                'IF FOUND AND p_expected_updated_at IS NOT NULL', 'IF false AND p_expected_updated_at IS NOT NULL');
  IF d2 = d OR position('IF false AND' IN d2) = 0 THEN RAISE EXCEPTION 'twin 1 not built'; END IF;
  EXECUTE d2;
  d := pg_get_functiondef('public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure);
  d2 := replace(replace(d, 'FUNCTION public.rpc_cancel_game_kan712_inner(', 'FUNCTION pg_temp.k862p4_cancel_noguard('),
                'AND e.is_cancelled IS NOT TRUE)', ')');
  IF position('is_cancelled IS NOT TRUE' IN d2) > 0 THEN RAISE EXCEPTION 'twin 2 not built'; END IF;
  EXECUTE d2;
  -- pg_temp functions get no default EXECUTE for the session's other roles; the twins are called as authenticated.
  GRANT EXECUTE ON FUNCTION pg_temp.k862p4_update_noguard(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric) TO authenticated;
  GRANT EXECUTE ON FUNCTION pg_temp.k862p4_cancel_noguard(uuid,text) TO authenticated;
END $mk$;

CREATE TEMP TABLE k862p4_case ON COMMIT DROP AS
SELECT g.id AS gid, e.creator_user_id AS h, e.start_at AS s, e.end_at AS en, e.updated_at AS u, g.price_aed AS price
  FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
 WHERE e.start_at > now() + interval '1 day' AND NOT e.is_cancelled AND g.price_aed IS NOT NULL
   AND e.creator_user_id IS NOT NULL AND NOT public.is_admin(e.creator_user_id)
 ORDER BY e.start_at, g.id LIMIT 1;

SELECT pg_temp.k862p4_call('t4_match', h, format(
  'select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_title=>%L, p_price_aed=>%s)', gid, s, en, u, 'k862p4', price)) FROM k862p4_case;
SELECT pg_temp.k862p4_call('t5_stale', h, format(
  'select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_title=>%L, p_price_aed=>%s)', gid, s, en, '2000-01-01 00:00+00', 'k862p4', price)) FROM k862p4_case;
SELECT pg_temp.k862p4_call('t6_twin_stale', h, format(
  'select pg_temp.k862p4_update_noguard(%L, %L, %L, p_expected_updated_at=>%L, p_title=>%L, p_price_aed=>%s)', gid, s, en, '2000-01-01 00:00+00', 'k862p4', price)) FROM k862p4_case;
SELECT pg_temp.k862p4_call('t7_null', h, format(
  'select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>null, p_title=>%L, p_price_aed=>%s)', gid, s, en, 'k862p4', price)) FROM k862p4_case;
SELECT pg_temp.k862p4_call('t8_named_old', h, format(
  'select public.rpc_update_game(p_game_id=>%L, p_start_at=>%L, p_end_at=>%L, p_title=>%L, p_price_aed=>%s)', gid, s, en, 'k862p4', price)) FROM k862p4_case;
SELECT pg_temp.k862p4_call('t9_positional3', h, format(
  'select public.rpc_update_game(%L, %L, %L)', gid, s, en)) FROM k862p4_case;
SELECT pg_temp.k862p4_call('t10_unknown', h, format(
  'select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_price_aed=>0)', gen_random_uuid(), s, en, u)) FROM k862p4_case;
SELECT pg_temp.k862p4_call('t11_cancel_twice', h,
  format('select public.rpc_cancel_game(%L, %L) || '','' || public.rpc_cancel_game(%L, %L)', gid, 'A', gid, 'B'),
  format('select e.cancelled_reason || '','' || g.cancelled_reason from public.events e join public.games g on g.event_id = e.id where g.id = %L', gid))
  FROM k862p4_case;
SELECT pg_temp.k862p4_call('t12_twin_cancel_twice', h,
  format('select pg_temp.k862p4_cancel_noguard(%L, %L) || '','' || pg_temp.k862p4_cancel_noguard(%L, %L)', gid, 'A', gid, 'B'),
  format('select e.cancelled_reason || '','' || g.cancelled_reason from public.events e join public.games g on g.event_id = e.id where g.id = %L', gid))
  FROM k862p4_case;

-- T14 as postgres (service_role-only ops path), in a subtransaction that is undone.
DO $t14$
DECLARE r text;
BEGIN
  BEGIN
    SELECT public.kan712_update_event_shared((SELECT gid FROM pg_temp.k862p4_case), '{}'::jsonb)::text INTO r;
    RAISE EXCEPTION 'k862p4_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k862p4_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; ELSE r := 'OPEN ' || r; END IF;
  END;
  INSERT INTO pg_temp.k862p4_out VALUES ('t14_shared', current_user, r);
END $t14$;

INSERT INTO k862p4_tap SELECT 1,
  prosecdef AND proconfig = ARRAY['search_path=""'] AND proowner = 'postgres'::regrole
  AND pg_get_function_result(oid) = 'text' AND pronargdefaults = 14,
  'new overload: SECURITY DEFINER, search_path '''', owner postgres, returns text, 14 defaults', 'md5(prosrc) ' || md5(prosrc)
  FROM pg_proc WHERE oid = 'public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure;
INSERT INTO k862p4_tap SELECT 2,
  n.proacl = o.proacl AND n.proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND NOT has_function_privilege('anon', n.oid, 'EXECUTE') AND NOT has_function_privilege('public', n.oid, 'EXECUTE'),
  'new overload ACL = 17-arg wrapper ACL; no anon, no PUBLIC', n.proacl::text
  FROM pg_proc n, pg_proc o
 WHERE n.oid = 'public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure
   AND o.oid = 'public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure;
INSERT INTO k862p4_tap SELECT 3,
  md5(o.prosrc) = 'cf869fd1507bf17c273a57af599840cb' AND md5(i.prosrc) = 'af77954cbb14e8fa2f494d231dd49484'
  AND o.proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' AND i.proacl::text = '{postgres=X/postgres}'
  AND (SELECT count(*) FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_update_game') = 1,
  '17-arg wrapper and KAN-718 inner unchanged; still one kan712_wrapped_rpcs row', md5(o.prosrc) || ' ' || md5(i.prosrc)
  FROM pg_proc o, pg_proc i
 WHERE o.oid = 'public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure
   AND i.oid = 'public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure;
INSERT INTO k862p4_tap SELECT 4, v = 'updated', 'sanity: matching expected version -> updated (path executes)', v FROM k862p4_out WHERE k = 't4_match';
INSERT INTO k862p4_tap SELECT 5, v LIKE 'ERR 40001 stale_update%', 'stale expected version -> 40001 stale_update', v FROM k862p4_out WHERE k = 't5_stale';
INSERT INTO k862p4_tap SELECT 6, v = 'updated', 'negative control: twin without the guard -> updated on the stale input', v FROM k862p4_out WHERE k = 't6_twin_stale';
INSERT INTO k862p4_tap SELECT 7, v = 'updated', 'NULL expected version -> updated (no check)', v FROM k862p4_out WHERE k = 't7_null';
INSERT INTO k862p4_tap SELECT 8, v = 'updated', 'named call without p_expected_updated_at -> updated (old overload, not ambiguous)', v FROM k862p4_out WHERE k = 't8_named_old';
INSERT INTO k862p4_tap SELECT 9, v LIKE 'ERR P0001 price_required%', '3-arg positional -> P0001 price_required (old overload body)', v FROM k862p4_out WHERE k = 't9_positional3';
INSERT INTO k862p4_tap SELECT 10, v LIKE 'ERR P0001 not_host_or_not_found%', 'unknown game -> not_host_or_not_found, not stale_update', v FROM k862p4_out WHERE k = 't10_unknown';
INSERT INTO k862p4_tap SELECT 11, v = 'cancelled,cancelled | A,A', 'kan810: repeat cancel returns cancelled and keeps the first reason (events, games)', v FROM k862p4_out WHERE k = 't11_cancel_twice';
INSERT INTO k862p4_tap SELECT 12, v = 'cancelled,cancelled | B,B', 'negative control: inner twin without the KAN-810 guard rewrites the reason', v FROM k862p4_out WHERE k = 't12_twin_cancel_twice';
INSERT INTO k862p4_tap SELECT 13,
  md5(w.prosrc) = '32e9b96473d6351cc2a10db926212822' AND md5(i.prosrc) = '80dad909302213765aef271259738276'
  AND w.proacl::text = '{postgres=X/postgres,=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND i.proacl::text = '{postgres=X/postgres}' AND w.prosecdef AND i.prosecdef,
  'kan810: rpc_cancel_game wrapper and inner attributes/ACL unchanged', w.proacl::text
  FROM pg_proc w, pg_proc i
 WHERE w.oid = 'public.rpc_cancel_game(uuid,text)'::regprocedure AND i.oid = 'public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure;
INSERT INTO k862p4_tap SELECT 14, v LIKE 'ERR 55000 kan712_not_cut_over%', 'kan806: kan712_update_event_shared refuses 55000 (mirror gone)', v FROM k862p4_out WHERE k = 't14_shared';
INSERT INTO k862p4_tap SELECT 15,
  md5(p.prosrc) = 'e25772a438b80fa09833eaf87fb82860' AND p.proacl::text = '{postgres=X/postgres,service_role=X/postgres}'
  AND position('public.games' IN p.prosrc) = 0 AND position('public.meetups' IN p.prosrc) = 0
  AND NOT EXISTS (SELECT 1 FROM pg_proc q, regexp_split_to_table(q.prosrc, E'\n') ln
                   WHERE q.oid <> p.oid AND ln LIKE '%kan712_update_event_shared%' AND ln NOT LIKE '%HINT%'
                    AND q.pronamespace NOT IN ('pg_catalog'::regnamespace, pg_my_temp_schema()))
  AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgfoid = p.oid)
  AND NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.relkind IN ('v', 'm') AND pg_get_viewdef(c.oid) LIKE '%kan712_update_event_shared%'),
  'kan806: kan712_update_event_shared has no caller, is unchanged and reads no games/meetups', md5(p.prosrc)
  FROM pg_proc p WHERE p.oid = 'public.kan712_update_event_shared(uuid,jsonb)'::regprocedure;
INSERT INTO k862p4_tap SELECT 16,
  md5(p.prosrc) = '30687c53fc53c229af23df616b9852a3' AND p.proacl::text = '{postgres=X/postgres}'
  AND (SELECT array_agg(tgrelid::regclass::text || '.' || tgname::text) FROM pg_trigger WHERE tgfoid = p.oid)
      = ARRAY['meetups.trg_zz_kan712_meetups_guard'],
  'legacy_guard: unchanged; only attachment is meetups.trg_zz_kan712_meetups_guard (Z01 seq 304 drops it)',
  (SELECT string_agg(tgrelid::regclass::text || '.' || tgname::text, ',') FROM pg_trigger WHERE tgfoid = p.oid)
  FROM pg_proc p WHERE p.oid = 'public.kan712_legacy_guard()'::regprocedure;
INSERT INTO k862p4_tap SELECT 17,
  position('public.games' IN prosrc) = 0 AND position('public.meetups' IN prosrc) = 0,
  'new overload body reads neither public.games nor public.meetups', NULL
  FROM pg_proc WHERE oid = 'public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure;
INSERT INTO k862p4_tap SELECT 18, count(*) = 9 AND bool_and(who = 'authenticated'),
  'every RPC call ran as role authenticated', string_agg(k || '=' || coalesce(who, 'null'), ' ' ORDER BY k)
  FROM k862p4_out WHERE k <> 't14_shared';

SELECT tap FROM (
  SELECT n, CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
    FROM k862p4_tap
  UNION ALL
  SELECT 0, '# case: game ' || gid || ' host ' || h FROM k862p4_case) t
ORDER BY n;
ROLLBACK;

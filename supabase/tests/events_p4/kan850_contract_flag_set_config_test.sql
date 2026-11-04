-- KAN-850 (KAN-844 step 6c) -- the kan712.contract flag is set in the wrapper body with set_config(..., true), not by a
-- function-level SET clause (which needs superuser: 42501 on Supabase, where postgres is rolsuper = false), and the
-- KAN-712 guard honours the flag only for current_user postgres / supabase_admin.
-- LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end. Run as a superuser, on a database built by
-- supabase/tests/events_p4/build_kan850.sh (any of k788 / k772_kan850 / k810_kan850):
--   psql -X -h /tmp -p <port> -U postgres -d k810_kan850 -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan850_contract_flag_set_config_test.sql
-- Output: one row per case, id | PASS/FAIL | expected | actual | name, then a TOTAL line.
-- MARKS. [K] = KAN-850 behaviour: FAIL on a chain built with the 20261103100000 generator (no 6c), PASS after.
--        [=] = identical before and after. The C4 flag semantics are [=] on purpose: the old SET clause also scoped
--              and restored the flag; KAN-850 must keep that behaviour while moving it into the body.
-- C4 note: when the flag was never defined in the session, current_setting(.., true) is NULL before the call and ''
-- after (the wrapper restores coalesce(prior, '')). The guard reads coalesce(.., '') = 'on', so NULL and '' are the
-- same state; C4a compares coalesce(prior, '') and also prints the raw values.
\set ON_ERROR_STOP 1
\pset pager off
\set G '''71400000-0000-0000-0000-000000000300'''
\set H '''00000000-0000-0000-0000-0000000000a1'''
BEGIN;
SET LOCAL lock_timeout = '3s';
DO $g$ BEGIN
  IF current_database() !~ '^k(788|772|810)' THEN
    RAISE EXCEPTION 'KAN-850 test: local throwaway k788* / k772* / k810* databases only (got %)', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-850 test: this looks like a Supabase database; refusing';
  END IF;
END $g$;

-- C4a must read the flag before anything in this session defines it.
CREATE TEMP TABLE k850_raw (k text PRIMARY KEY, v text);
INSERT INTO k850_raw VALUES ('c4a_prior', current_setting('kan712.contract', true));

CREATE TEMP TABLE k850_res (n serial, id text, verdict text, expected text, actual text, name text);
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expect text, p_actual text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO k850_res (id, verdict, expected, actual, name)
  VALUES (p_id, CASE WHEN p_actual IS NOT DISTINCT FROM p_expect THEN 'PASS' ELSE 'FAIL' END, p_expect,
          coalesce(p_actual, '<null>'), p_name);
$$;

-- ---- C3: every wrapper -- SECURITY DEFINER, proconfig exactly {search_path=""}, body sets the flag with set_config,
--          owner and ACL equal original_owner / original_acl recorded by kan712_wrap_rpc.
SELECT pg_temp.chk('C3a [=]', 'kan712_wrapped_rpcs rows (one per wrapped overload)', '11',
  (SELECT count(*)::text FROM public.kan712_wrapped_rpcs));
SELECT pg_temp.chk('C3b [K]', 'wrappers with prosecdef, proconfig {search_path=""}, body set_config(kan712.contract, on, true)', '11',
  (SELECT count(*)::text FROM public.kan712_wrapped_rpcs w JOIN pg_proc p
      ON p.pronamespace = 'public'::regnamespace AND p.proname = w.name
     AND pg_get_function_identity_arguments(p.oid) = w.identity_args
   WHERE p.prosecdef AND p.proconfig = ARRAY['search_path=""']
     AND position('set_config(''kan712.contract'', ''on'', true)' IN p.prosrc) > 0
     AND position('set_config(''kan712.contract'', coalesce(v_prev, ''''), true)' IN p.prosrc) > 0));
SELECT pg_temp.chk('C3c [=]', 'wrappers whose owner and ACL equal original_owner / original_acl', '11',
  (SELECT count(*)::text FROM public.kan712_wrapped_rpcs w JOIN pg_proc p
      ON p.pronamespace = 'public'::regnamespace AND p.proname = w.name
     AND pg_get_function_identity_arguments(p.oid) = w.identity_args
   WHERE p.proowner = w.original_owner AND p.proacl IS NOT DISTINCT FROM w.original_acl));
SELECT pg_temp.chk('C3d [K]', 'no public function carries a kan712.contract SET clause', '0',
  (SELECT count(*)::text FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'kan712.contract=%')));
SELECT pg_temp.chk('C3e [=]', 'no inner is executable by anon, authenticated or service_role', '0',
  (SELECT count(*)::text FROM public.kan712_wrapped_rpcs w JOIN pg_proc p
      ON p.pronamespace = 'public'::regnamespace AND p.proname = w.inner_name
   WHERE has_function_privilege('anon', p.oid, 'EXECUTE') OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('service_role', p.oid, 'EXECUTE')));

-- ---- C4: the flag inside and after a wrapper. A throwaway SECURITY DEFINER function, wrapped by the live
--          kan712_wrap_rpc (rolled back), returns the flag it sees and raises on request.
CREATE FUNCTION public.kan850_t_flag(p_fail boolean) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $f$
BEGIN
  IF p_fail THEN
    RAISE EXCEPTION USING ERRCODE = 'KN850', MESSAGE = 'kan850 inner failure, flag=' || coalesce(current_setting('kan712.contract', true), '<null>');
  END IF;
  RETURN coalesce(current_setting('kan712.contract', true), '<null>');
END $f$;
SELECT public.kan712_wrap_rpc('public.kan850_t_flag(boolean)'::regprocedure, 'none');

-- C4a prior never defined in this session (read at the top of the file).
INSERT INTO k850_raw VALUES ('c4a_inside', public.kan850_t_flag(false));
INSERT INTO k850_raw VALUES ('c4a_after', current_setting('kan712.contract', true));
SELECT pg_temp.chk('C4a1 [=]', 'prior unset: flag inside the wrapper is on', 'on', (SELECT v FROM k850_raw WHERE k = 'c4a_inside'));
SELECT pg_temp.chk('C4a2 [=]', 'prior unset: flag after return equals prior (coalesced; raw prior/after printed)',
  coalesce((SELECT v FROM k850_raw WHERE k = 'c4a_prior'), ''), (SELECT coalesce(v, '') FROM k850_raw WHERE k = 'c4a_after'));
SELECT pg_temp.chk('C4a3 [=]', 'prior unset: raw prior / after',
  'prior=' || coalesce((SELECT v FROM k850_raw WHERE k = 'c4a_prior'), '<null>') || ' after='
         || coalesce((SELECT v FROM k850_raw WHERE k = 'c4a_after'), '<null>'),
  'prior=' || coalesce((SELECT v FROM k850_raw WHERE k = 'c4a_prior'), '<null>') || ' after='
         || coalesce((SELECT v FROM k850_raw WHERE k = 'c4a_after'), '<null>'));

-- C4b prior 'on' (as when a wrapper calls another wrapper).
SELECT set_config('kan712.contract', 'on', true);
INSERT INTO k850_raw VALUES ('c4b_inside', public.kan850_t_flag(false));
INSERT INTO k850_raw VALUES ('c4b_after', current_setting('kan712.contract', true));
SELECT pg_temp.chk('C4b1 [=]', 'prior on: flag inside is on', 'on', (SELECT v FROM k850_raw WHERE k = 'c4b_inside'));
SELECT pg_temp.chk('C4b2 [=]', 'prior on: flag after return is on', 'on', (SELECT v FROM k850_raw WHERE k = 'c4b_after'));

-- C4c prior '' (the value every other wrapper call leaves) and an arbitrary prior value.
SELECT set_config('kan712.contract', '', true);
INSERT INTO k850_raw VALUES ('c4c_inside', public.kan850_t_flag(false));
INSERT INTO k850_raw VALUES ('c4c_after', current_setting('kan712.contract', true));
SELECT set_config('kan712.contract', 'kan850-prior', true);
INSERT INTO k850_raw VALUES ('c4d_inside', public.kan850_t_flag(false));
INSERT INTO k850_raw VALUES ('c4d_after', current_setting('kan712.contract', true));
SELECT pg_temp.chk('C4c [=]', 'prior empty: inside on, after empty', 'on|',
  (SELECT v FROM k850_raw WHERE k = 'c4c_inside') || '|' || (SELECT v FROM k850_raw WHERE k = 'c4c_after'));
SELECT pg_temp.chk('C4d [=]', 'prior kan850-prior: inside on, after kan850-prior', 'on|kan850-prior',
  (SELECT v FROM k850_raw WHERE k = 'c4d_inside') || '|' || (SELECT v FROM k850_raw WHERE k = 'c4d_after'));

-- C4e inner error, SQL-level SAVEPOINT / ROLLBACK TO SAVEPOINT (the error aborts the subtransaction that set the flag).
SELECT set_config('kan712.contract', 'kan850-prior', true);
SAVEPOINT k850_s;
\set ON_ERROR_STOP 0
SELECT public.kan850_t_flag(true);
\set ON_ERROR_STOP 1
ROLLBACK TO SAVEPOINT k850_s;
INSERT INTO k850_raw VALUES ('c4e_after', current_setting('kan712.contract', true));
SELECT pg_temp.chk('C4e [=]', 'inner error + ROLLBACK TO SAVEPOINT: flag equals prior (kan850-prior)', 'kan850-prior',
  (SELECT v FROM k850_raw WHERE k = 'c4e_after'));
-- C4f the same through a PL/pgSQL exception block, also capturing the flag the inner saw when it failed.
DO $d$
DECLARE m text;
BEGIN
  PERFORM set_config('kan712.contract', '', true);
  BEGIN
    PERFORM public.kan850_t_flag(true);
  EXCEPTION WHEN SQLSTATE 'KN850' THEN
    GET STACKED DIAGNOSTICS m = MESSAGE_TEXT;
  END;
  INSERT INTO k850_raw VALUES ('c4f_msg', m), ('c4f_after', current_setting('kan712.contract', true));
END $d$;
SELECT pg_temp.chk('C4f [=]', 'inner error caught: inner saw on, flag after equals prior (empty)',
  'kan850 inner failure, flag=on|', (SELECT v FROM k850_raw WHERE k = 'c4f_msg') || '|' || (SELECT v FROM k850_raw WHERE k = 'c4f_after'));
SELECT set_config('kan712.contract', '', true);

-- ---- C5: a flag forged by an API role is inert; the same change through the wrapped RPC succeeds.
--   authenticated (host): the guard is SECURITY INVOKER and its first read of the parent is
--     SELECT .. FROM public.events .. FOR UPDATE [NOWAIT]; events is closed to authenticated, so a direct games UPDATE
--     is refused 42501 'permission denied for table events' BEFORE the guard reaches its own
--     'kan712_direct_shared_write_refused' -- with or without the forged flag, before and after KAN-850 ([=]).
--   service_role (BYPASSRLS, reads events): this is where the forged flag used to open the write. Before KAN-850 the
--     forged-flag UPDATE succeeds; after, it is refused 42501 kan712_direct_shared_write_refused ([K], = probes D4).
CREATE FUNCTION pg_temp.as_role(p_role text, p_uid text, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text; s text; m text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid, ''), true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', p_role)::text, true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    RESET ROLE;
    v := 'ERR ' || s || ' ' || m;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('kan712.contract', '', true);
  RETURN coalesce(v, '<null>');
END $f$;
-- The local harness enables RLS on games with no policy, so an authenticated UPDATE matches 0 rows and the guard never
-- runs. Two host-only policies (production's games policies let the host see and update its own game) are added here
-- and rolled back with everything else; without them C5b / C5c would pass vacuously.
CREATE POLICY kan850_t_host_select ON public.games FOR SELECT TO authenticated USING (creator_user_id = auth.uid());
CREATE POLICY kan850_t_host_update ON public.games FOR UPDATE TO authenticated
  USING (creator_user_id = auth.uid()) WITH CHECK (creator_user_id = auth.uid());
SELECT pg_temp.chk('C5h [=]', 'fixture: with the policies, the host sees its game (so a refusal is the guard, not RLS)', '1',
  pg_temp.as_role('authenticated', :H, format($s$SELECT count(*)::text FROM public.games WHERE id = %L$s$, :G)));
INSERT INTO k850_raw SELECT 'c5_title', title FROM public.games WHERE id = :G;
SELECT pg_temp.chk('C5a [=]', 'fixture: game exists, host is a1, live, has a title', :H || '|false|true',
  (SELECT creator_user_id || '|' || is_cancelled || '|' || (title IS NOT NULL) FROM public.games WHERE id = :G));
SELECT pg_temp.chk('C5b [=]', 'authenticated host, no flag: direct UPDATE games.title refused 42501 (events closed to authenticated)',
  'ERR 42501 permission denied for table events',
  pg_temp.as_role('authenticated', :H, format($s$WITH u AS (UPDATE public.games SET title = 'kan850 direct' WHERE id = %L RETURNING 1)
                                SELECT count(*)::text FROM u$s$, :G)));
SELECT pg_temp.chk('C5c [=]', 'authenticated host SETs kan712.contract = on, then direct UPDATE games.title: refused 42501',
  'ERR 42501 permission denied for table events',
  pg_temp.as_role('authenticated', :H, format($s$WITH s AS (SELECT set_config('kan712.contract', 'on', true)),
                                     u AS (UPDATE public.games SET title = 'kan850 forged' WHERE id = %L
                                            AND (SELECT count(*) FROM s) = 1 RETURNING 1)
                                SELECT count(*)::text FROM u$s$, :G)));
SELECT pg_temp.chk('C5i [K]', 'service_role SETs kan712.contract = on, then direct UPDATE games.title: refused (forged flag inert)',
  'ERR 42501 kan712_direct_shared_write_refused',
  pg_temp.as_role('service_role', NULL, format($s$WITH s AS (SELECT set_config('kan712.contract', 'on', true)),
                                     u AS (UPDATE public.games SET title = 'kan850 forged sr' WHERE id = %L
                                            AND (SELECT count(*) FROM s) = 1 RETURNING 1)
                                SELECT count(*)::text FROM u$s$, :G)));
SELECT pg_temp.chk('C5j [=]', 'service_role, no flag: direct UPDATE games.title refused', 'ERR 42501 kan712_direct_shared_write_refused',
  pg_temp.as_role('service_role', NULL, format($s$WITH u AS (UPDATE public.games SET title = 'kan850 direct sr' WHERE id = %L RETURNING 1)
                                SELECT count(*)::text FROM u$s$, :G)));
SELECT pg_temp.chk('C5d [K]', 'title unchanged after the refused writes', (SELECT v FROM k850_raw WHERE k = 'c5_title'),
  (SELECT title FROM public.games WHERE id = :G));
SELECT pg_temp.chk('C5e [=]', 'the same change through the wrapped rpc_update_game (named, 17-arg overload) succeeds', 'ok',
  (SELECT CASE WHEN r LIKE 'ERR%' THEN r ELSE 'ok' END FROM (SELECT pg_temp.as_role('authenticated', :H, format(
     $s$SELECT public.rpc_update_game(p_game_id => %1$L, p_start_at => (SELECT start_at FROM public.games WHERE id = %1$L),
                                      p_end_at => (SELECT end_at FROM public.games WHERE id = %1$L), p_title => 'kan850 via rpc', p_price_aed => 0)::text$s$, :G)) AS r) x));
SELECT pg_temp.chk('C5f [=]', 'title written by the RPC, games and events agree', 'kan850 via rpc|kan850 via rpc',
  (SELECT g.title || '|' || e.title FROM public.games g JOIN public.events e ON e.id = g.id WHERE g.id = :G));
SELECT pg_temp.chk('C5g [=]', 'flag after the RPC as seen by the caller session is not on', 'not on',
  CASE WHEN coalesce(current_setting('kan712.contract', true), '') = 'on' THEN 'on' ELSE 'not on' END);

SELECT id, verdict, expected, actual, name FROM k850_res ORDER BY n;
SELECT format('KAN-850 TOTAL pass=%s fail=%s ([K] fail=%s)', count(*) FILTER (WHERE verdict = 'PASS'),
              count(*) FILTER (WHERE verdict = 'FAIL'), count(*) FILTER (WHERE verdict = 'FAIL' AND id LIKE '%[K]%')) AS total
  FROM k850_res;
ROLLBACK;

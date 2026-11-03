-- KAN-809 probe: the expected-version overload of public.rpc_update_game
-- (migration 20261104110800_kan809_update_game_stale_guard.sql).
-- LOCAL DISPOSABLE k772* DATABASES ONLY. Sections C, R and S run in transactions that are rolled back.
-- Section D (two-session concurrency, via dblink) COMMITS on three bulk games of the KAN-772 harness.
-- Run as a superuser: psql -X -v ON_ERROR_STOP=0 -d <db> -f supabase/tests/events_p4/kan809_update_game_stale_guard.sql
-- Output: one NOTICE per case, "PASS|<id>|..." or "FAIL|<id>|...". Any FAIL line means KAN-809 is not in place.
-- Expected on a pre-KAN-809 database: C1 and every R/S/D case that needs the new overload FAIL.
--
-- TWO REAL psql SESSIONS (same cases as section D, without dblink). Shell driver, run against a disposable clone:
--   G=<game id>; H=<its creator_user_id>; S/E=<its start_at/end_at>; U=<its events.updated_at>, all read FIRST.
--   psql -c "set role authenticated; set request.jwt.claim.sub='$H';" -c begin \
--        -c "select public.rpc_reschedule_game('$G', '$S'::timestamptz + interval '1 day', '$E'::timestamptz + interval '1 day')" \
--        -c "select pg_sleep(3)" -c commit &                                       # session A
--   sleep 1
--   psql -c "set role authenticated; set request.jwt.claim.sub='$H';" \
--        -c "select public.rpc_update_game('$G', '$S', '$E', p_expected_updated_at=>'$U', p_title=>'B', p_price_aed=>0)"   # session B
--   wait
--   Expected: B blocks until A commits, then fails 40001 stale_update; games/events keep S+1d (parity holds).
--   Without p_expected_updated_at (or with it NULL) B returns 'updated' and S comes back: today's behaviour, unchanged.
\set QUIET on
set client_min_messages = notice;

do $chk$
begin
  if current_database() !~ '^k772' then
    raise exception 'kan809 probe: local disposable k772* databases only (got %)', current_database();
  end if;
end $chk$;

create or replace function pg_temp.k809_report(p_id text, p_ok boolean, p_desc text, p_expected text, p_actual text)
returns void language plpgsql as $f$
begin
  raise notice '%|%|%|expected=%|actual=%', case when coalesce(p_ok, false) then 'PASS' else 'FAIL' end, p_id, p_desc,
    p_expected, coalesce(p_actual, '<null>');
end $f$;

create or replace function pg_temp.k809_new() returns oid language sql as $f$
  select to_regprocedure('public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)')::oid
$f$;
create or replace function pg_temp.k809_old() returns oid language sql as $f$
  select to_regprocedure('public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)')::oid
$f$;

-- Runs one SQL text as role authenticated with the given auth.uid(); returns 'OK <result>' or 'ERR <sqlstate> <message>'.
-- Also returns which public.rpc_update_game overload(s) ran in this call, from pg_stat_xact_user_functions.
create or replace function pg_temp.k809_call(p_sub uuid, p_sql text) returns text language plpgsql as $f$
declare v_state text; v_msg text; v_res text; v_n0 bigint; v_o0 bigint; v_n1 bigint; v_o1 bigint; v_out text;
begin
  select coalesce(sum(calls) filter (where funcid = pg_temp.k809_new()), 0), coalesce(sum(calls) filter (where funcid = pg_temp.k809_old()), 0)
    into v_n0, v_o0 from pg_stat_xact_user_functions;
  perform set_config('request.jwt.claim.sub', p_sub::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v_res;
    v_out := 'OK ' || coalesce(v_res, '<null>');
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    v_out := 'ERR ' || v_state || ' ' || v_msg;
  end;
  execute 'reset role';
  select coalesce(sum(calls) filter (where funcid = pg_temp.k809_new()), 0), coalesce(sum(calls) filter (where funcid = pg_temp.k809_old()), 0)
    into v_n1, v_o1 from pg_stat_xact_user_functions;
  return v_out || ' [new=' || (v_n1 - v_n0) || ' old=' || (v_o1 - v_o0) || ']';
end $f$;

-- ---------------------------------------------------------------------------------------------------------
-- C. Catalogue
-- ---------------------------------------------------------------------------------------------------------
do $c$
declare n record; o record; v_cnt int;
begin
  select * into n from pg_proc where oid = pg_temp.k809_new();
  select * into o from pg_proc where oid = pg_temp.k809_old();
  perform pg_temp.k809_report('C1', n.oid is not null, 'expected-version overload exists', 'present',
    case when n.oid is null then 'absent' else pg_get_function_identity_arguments(n.oid) end);
  perform pg_temp.k809_report('C2', n.prosecdef and n.proconfig = array['search_path=""', 'kan712.contract=on']
      and n.proconfig = o.proconfig and n.proowner = 'postgres'::regrole and pg_get_function_result(n.oid) = 'text',
    'SECURITY DEFINER, search_path='''', kan712.contract=on, owner postgres, returns text',
    'secdef|{search_path="",kan712.contract=on}|postgres|text',
    n.prosecdef::text || '|' || n.proconfig::text || '|' || n.proowner::regrole::text || '|' || pg_get_function_result(n.oid));
  perform pg_temp.k809_report('C3', n.proacl = o.proacl and n.proacl = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'::aclitem[],
    'proacl equals the existing rpc_update_game', o.proacl::text, n.proacl::text);
  perform pg_temp.k809_report('C4', n.oid is not null and not has_function_privilege('anon', n.oid, 'EXECUTE')
      and not has_function_privilege('public', n.oid, 'EXECUTE'), 'anon and PUBLIC cannot execute', 'false|false',
    case when n.oid is null then 'absent' else has_function_privilege('anon', n.oid, 'EXECUTE')::text || '|'
      || has_function_privilege('public', n.oid, 'EXECUTE')::text end);
  perform pg_temp.k809_report('C5', o.oid is not null and md5(o.prosrc) = '742f0a18ddeaae48904263fbf86aa578'
      and o.proacl = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'::aclitem[]
      and o.proconfig = array['search_path=""', 'kan712.contract=on'],
    'existing 17-arg wrapper unchanged (md5 prosrc, ACL, proconfig)', '742f0a18ddeaae48904263fbf86aa578',
    md5(o.prosrc) || ' ' || o.proacl::text);
  select count(*) into v_cnt from public.kan712_wrapped_rpcs;
  perform pg_temp.k809_report('C6', v_cnt = 11 and (select count(*) from public.kan712_wrapped_rpcs where name = 'rpc_update_game') = 1,
    'kan712_wrapped_rpcs unchanged: 11 rows, one rpc_update_game (new overload not registered)', '11|1',
    v_cnt || '|' || (select count(*) from public.kan712_wrapped_rpcs where name = 'rpc_update_game'));
  perform pg_temp.k809_report('C7', n.oid is not null and position('FOR UPDATE' in n.prosrc) > 0
      and position('FOR UPDATE' in n.prosrc) < position('stale_update' in n.prosrc)
      and position('stale_update' in n.prosrc) < position('RETURN public.rpc_update_game($1, $2, $3, $5' in n.prosrc),
    'body order: lock events FOR UPDATE, then compare, then delegate to the 17-arg public function', 'lock<compare<delegate',
    case when n.oid is null then 'absent' else 'positions ' || position('FOR UPDATE' in n.prosrc) || '<'
      || position('stale_update' in n.prosrc) || '<' || position('RETURN public.rpc_update_game($1, $2, $3, $5' in n.prosrc) end);
end $c$;

-- ---------------------------------------------------------------------------------------------------------
-- R. Overload resolution (one transaction, rolled back). [new=N old=M] counts which overload body ran; Postgres does not
--    record a call that raises, so R1-R3 (which raise) are told apart by the error: price_required comes from the old
--    body; the new overload cannot take 3 args (R1), would fail 22007 casting 'T' to timestamptz (R2), and has no
--    implicit text->timestamptz cast (R3).
-- ---------------------------------------------------------------------------------------------------------
begin;
set local track_functions = 'all';
do $r$
declare
  g uuid := '71400000-0000-0000-0000-000000000300';
  h uuid;
  s text; e text; u timestamptz; v text;
begin
  select creator_user_id, start_at::text, end_at::text into h, s, e from public.games where id = g;
  select updated_at into u from public.events where id = g;

  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L)', g, s, e));
  perform pg_temp.k809_report('R1', v like 'ERR P0001 price_required %', '3-arg positional -> old overload (unchanged error)', 'ERR P0001 price_required', v);
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, %L)', g, s, e, 'T'));
  perform pg_temp.k809_report('R2', v like 'ERR P0001 price_required %', '4-arg positional, unknown literal -> old overload', 'ERR P0001 price_required', v);
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, %L::text)', g, s, e, 'T'));
  perform pg_temp.k809_report('R3', v like 'ERR P0001 price_required %', '4-arg positional, text -> old overload', 'ERR P0001 price_required', v);
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(p_game_id=>%L, p_start_at=>%L, p_end_at=>%L, p_title=>%L, p_price_aed=>0)', g, s, e, 'R4'));
  perform pg_temp.k809_report('R4', v = 'OK updated [new=0 old=1]', 'named call without p_expected_updated_at -> old overload', 'OK updated [new=0 old=1]', v);
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L::uuid, %L::timestamptz, %L::timestamptz, %L::text, null::uuid, false, null::text, null::text, null::boolean, null::boolean, null::int, null::int, false, null::jsonb, null::int, null::int, 0::numeric)', g, s, e, 'R5'));
  perform pg_temp.k809_report('R5', v = 'OK updated [new=0 old=1]', '17-arg typed positional -> old overload', 'OK updated [new=0 old=1]', v);
  select updated_at into u from public.events where id = g;
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_title=>%L, p_price_aed=>0)', g, s, e, u, 'R6'));
  perform pg_temp.k809_report('R6', v = 'OK updated [new=1 old=1]', 'named call with p_expected_updated_at -> new overload, which delegates once to the old', 'OK updated [new=1 old=1]', v);
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, %L::timestamptz, %L, p_price_aed=>0)', g, s, e, u, 'R7'));
  perform pg_temp.k809_report('R7', v = 'OK updated [new=1 old=1]', '4th positional typed timestamptz -> new overload', 'OK updated [new=1 old=1]', v);
end $r$;
rollback;

-- ---------------------------------------------------------------------------------------------------------
-- S. Single-session guard behaviour (one transaction, rolled back).
-- A reschedule inside this transaction sets events.updated_at = now(), so a version read before it is stale.
-- ---------------------------------------------------------------------------------------------------------
begin;
do $s$
declare
  g uuid := '71400000-0000-0000-0000-000000000300';
  h uuid; s timestamptz; e timestamptz; u0 timestamptz; u1 timestamptz; v text; r record;
  stranger uuid := '00000000-0000-0000-0000-00000000dead';
begin
  select creator_user_id, start_at, end_at into h, s, e from public.games where id = g;
  select updated_at into u0 from public.events where id = g;

  -- S1: matching version -> update applies, games/events parity.
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_title=>%L, p_price_aed=>7)', g, s, e, u0, 'S1'));
  select g2.start_at gs, ev.start_at es, ev.title t, g2.end_at ge, ev.end_at ee into r from public.games g2 join public.events ev on ev.id = g2.id where g2.id = g;
  perform pg_temp.k809_report('S1', v like 'OK updated%' and r.t = 'S1' and r.gs = r.es and r.ge = r.ee, 'matching expected version -> updated, parity', 'OK updated|S1|parity',
    v || '|' || r.t || '|' || (r.gs = r.es and r.ge = r.ee)::text);

  -- S2: version changes (reschedule), stale expected -> 40001 stale_update, nothing written.
  select updated_at into u1 from public.events where id = g;
  v := pg_temp.k809_call(h, format('select public.rpc_reschedule_game(%L, %L, %L)', g, s + interval '1 day', e + interval '1 day'));
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_title=>%L, p_price_aed=>7)', g, s, e, '2000-01-01 00:00+00', 'S2'));
  select g2.start_at gs, ev.start_at es, ev.title t into r from public.games g2 join public.events ev on ev.id = g2.id where g2.id = g;
  perform pg_temp.k809_report('S2', v like 'ERR 40001 stale_update%' and r.gs = s + interval '1 day' and r.es = r.gs and r.t = 'S1',
    'stale expected version -> 40001 stale_update, reschedule kept, title not written', 'ERR 40001 stale_update|+1d|S1',
    v || '|' || r.gs::text || '|' || r.t);

  -- S3: explicit NULL expected -> no check (today's behaviour): the old start is written back.
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>null, p_title=>%L, p_price_aed=>7)', g, s, e, 'S3'));
  select g2.start_at gs, ev.start_at es into r from public.games g2 join public.events ev on ev.id = g2.id where g2.id = g;
  perform pg_temp.k809_report('S3', v like 'OK updated%' and r.gs = s and r.es = s, 'NULL expected version -> no check, updated', 'OK updated|start=old', v || '|' || r.gs::text);

  -- S4: missing game with an expected version -> the body's own error, never stale_update.
  v := pg_temp.k809_call(h, format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_price_aed=>7)', gen_random_uuid(), s, e, u0));
  perform pg_temp.k809_report('S4', v like 'ERR P0001 not_host_or_not_found%', 'unknown game -> not_host_or_not_found, not stale_update', 'ERR P0001 not_host_or_not_found', v);

  -- S5: non-host with the current version -> the body's authorisation error.
  select updated_at into u1 from public.events where id = g;
  v := pg_temp.k809_call(stranger, format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_price_aed=>7)', g, s, e, u1));
  perform pg_temp.k809_report('S5', v like 'ERR P0001 not_host_or_not_found%', 'non-host, current version -> not_host_or_not_found', 'ERR P0001 not_host_or_not_found', v);

  -- S6: non-host with a stale version -> stale_update is raised under the lock before authorisation. Leaks only
  -- "this game id exists" to a caller who already named it; recorded so a change of order is a visible decision.
  v := pg_temp.k809_call(stranger, format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_price_aed=>7)', g, s, e, '2000-01-01 00:00+00'));
  perform pg_temp.k809_report('S6', v like 'ERR 40001 stale_update%', 'non-host, stale version -> stale_update (check precedes body)', 'ERR 40001 stale_update', v);
end $s$;
rollback;

-- ---------------------------------------------------------------------------------------------------------
-- D. Two sessions (dblink). COMMITS. Session A: reschedule +1d then sleeps 2s holding the lock.
-- Session B (this one) calls rpc_update_game with the start/end/version it read before A, and blocks on the lock.
-- ---------------------------------------------------------------------------------------------------------
do $dx$
begin
  if not exists (select 1 from pg_available_extensions where name = 'dblink') then
    raise notice 'SKIP|D*|dblink not available; run the two-session shell driver in the header instead';
  end if;
end $dx$;
create extension if not exists dblink;

create or replace function pg_temp.k809_two(p_case text, p_game uuid, p_mode text) returns void language plpgsql as $f$
declare
  h uuid; s timestamptz; e timestamptz; u timestamptz; v text; r record; v_pid int; v_i int := 0;
  v_conn text := 'dbname=' || current_database() || ' port=' || current_setting('port') || ' host='
                 || split_part(current_setting('unix_socket_directories'), ',', 1) || ' user=postgres';
begin
  select creator_user_id, start_at, end_at into h, s, e from public.games where id = p_game;
  select updated_at into u from public.events where id = p_game;
  perform dblink_connect('k809a', v_conn);
  select x into v_pid from dblink('k809a', 'select pg_backend_pid()') as t(x int);
  perform dblink_exec('k809a', 'set role authenticated');
  perform dblink_exec('k809a', format('set request.jwt.claim.sub = %L', h));
  perform dblink_send_query('k809a', format('select public.rpc_reschedule_game(%L, %L, %L), pg_sleep(2)',
    p_game, s + interval '1 day', e + interval '1 day'));
  loop
    perform pg_stat_clear_snapshot();  -- pg_stat_activity is cached per transaction otherwise
    exit when exists (select 1 from pg_stat_activity where pid = v_pid and wait_event = 'PgSleep');
    v_i := v_i + 1;
    if v_i > 200 then raise exception 'session A never reached pg_sleep'; end if;
    perform pg_sleep(0.05);
  end loop;
  v := pg_temp.k809_call(h, case p_mode
    when 'guard' then format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>%L, p_title=>%L, p_price_aed=>0)', p_game, s, e, u, 'B')
    when 'null'  then format('select public.rpc_update_game(%L, %L, %L, p_expected_updated_at=>null, p_title=>%L, p_price_aed=>0)', p_game, s, e, 'B')
    else              format('select public.rpc_update_game(%L, %L, %L, p_title=>%L, p_price_aed=>0)', p_game, s, e, 'B') end);
  perform * from dblink_get_result('k809a') as t(a text, b text);
  perform dblink_disconnect('k809a');
  select g.start_at gs, ev.start_at es, g.end_at ge, ev.end_at ee, ev.title t into r
    from public.games g join public.events ev on ev.id = g.id where g.id = p_game;
  if p_mode = 'guard' then
    perform pg_temp.k809_report(p_case, v like 'ERR 40001 stale_update%' and r.gs = s + interval '1 day' and r.gs = r.es and r.ge = r.ee,
      'concurrent reschedule + stale guarded update -> 40001, reschedule kept, parity', 'ERR 40001 stale_update|start+1d|parity',
      v || '|' || r.gs::text || '|' || (r.gs = r.es and r.ge = r.ee)::text);
  else
    perform pg_temp.k809_report(p_case, v like 'OK updated%' and r.gs = s and r.t = 'B' and r.gs = r.es and r.ge = r.ee,
      'concurrent reschedule + unguarded update (' || p_mode || ') -> unchanged behaviour: old start written back, parity',
      'OK updated|start=old|parity', v || '|' || r.gs::text || '|' || (r.gs = r.es and r.ge = r.ee)::text);
  end if;
exception when others then
  begin perform dblink_disconnect('k809a'); exception when others then null; end;
  perform pg_temp.k809_report(p_case, false, 'two-session case raised', 'no error', sqlerrm);
end $f$;

select pg_temp.k809_two('D1', '71400000-0000-0000-0000-000000000150', 'guard');
select pg_temp.k809_two('D2', '71400000-0000-0000-0000-000000001500', 'old');
select pg_temp.k809_two('D3', '71400000-0000-0000-0000-000000000300', 'null');

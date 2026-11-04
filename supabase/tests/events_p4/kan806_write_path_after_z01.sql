-- KAN-806 probe: kan712_update_event_shared(uuid, jsonb) after 20261104110700_kan806_kan712_write_path_after_z01.sql.
-- LOCAL DISPOSABLE DATABASES ONLY. Every case runs in BEGIN ... ROLLBACK; nothing is committed.
-- Run as a superuser: psql -X -v ON_ERROR_STOP=0 -d <db> -f supabase/tests/events_p4/kan806_write_path_after_z01.sql
-- Detects the phase on its own: PRE-Z01 (mirror trigger present) or POST-Z01 (mirror gone, legacy columns gone).
-- Output: one NOTICE per case, "PASS|<id>|..." or "FAIL|<id>|...". Any FAIL line means KAN-806 is not in place.
\set QUIET on
set client_min_messages = notice;

do $chk$
begin
  if current_database() !~ '^k772' and current_database() !~ '^k806' then
    raise exception 'kan806 probe: local disposable k772*/k806* databases only (got %)', current_database();
  end if;
end $chk$;

create or replace function pg_temp.k806_report(p_id text, p_ok boolean, p_desc text, p_expected text, p_actual text)
returns void language plpgsql as $f$
begin
  raise notice '%|%|%|expected=%|actual=%', case when p_ok then 'PASS' else 'FAIL' end, p_id, p_desc, p_expected, p_actual;
end $f$;

-- Calls the ops function as service_role; returns 'OK' or 'ERR <sqlstate> <message>'.
create or replace function pg_temp.k806_call(p_event_id uuid, p_patch jsonb) returns text language plpgsql as $f$
declare v_state text; v_msg text;
begin
  execute 'set local role service_role';
  begin
    perform public.kan712_update_event_shared(p_event_id, p_patch);
    execute 'reset role';
    return 'OK';
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    execute 'reset role';
    return 'ERR ' || v_state || ' ' || v_msg;
  end;
end $f$;

create or replace function pg_temp.k806_upd(p_rel text) returns bigint language sql as $f$
  select coalesce((select n_tup_upd from pg_stat_xact_user_tables where schemaname = 'public' and relname = p_rel), 0)
$f$;

create or replace function pg_temp.k806_phase() returns text language sql as $f$
  select case when exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                            and tgname = 'trg_zz_kan712_events_compat_mirror') then 'PRE-Z01'
              when not exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'title'
                                and attnum > 0 and not attisdropped) then 'POST-Z01'
              else 'STAGE-1' end
$f$;

do $p$ begin raise notice 'INFO|phase=%|db=%', pg_temp.k806_phase(), current_database(); end $p$;

-- ---------------------------------------------------------------------------------------------------------
-- C. Catalogue (both phases)
-- ---------------------------------------------------------------------------------------------------------
do $c$
declare r record; v_old_guard constant text := $g$  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
                  WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled = 'O') THEN
$g$;
  v_s int; v_e int; v_tail constant text := '))))) THEN' || chr(10); v_spliced text; v_mut text;
begin
  select p.*, p.proowner::regrole::text as owner, pg_get_function_identity_arguments(p.oid) as args,
         pg_get_function_result(p.oid) as res
    into r from pg_proc p where p.oid = 'public.kan712_update_event_shared(uuid,jsonb)'::regprocedure;
  perform pg_temp.k806_report('C1', r.args = 'p_event_id uuid, p_patch jsonb' and r.res = 'jsonb',
    'signature unchanged', 'p_event_id uuid, p_patch jsonb -> jsonb', r.args || ' -> ' || r.res);
  perform pg_temp.k806_report('C2', r.prosecdef and r.provolatile = 'v' and r.proconfig = array['search_path=""'] and r.owner = 'postgres',
    'SECURITY DEFINER, volatile, search_path='''', owner postgres', 't|v|{"search_path=\"\""}|postgres',
    r.prosecdef::text || '|' || r.provolatile::text || '|' || r.proconfig::text || '|' || r.owner);
  perform pg_temp.k806_report('C3', r.proacl::text = '{postgres=X/postgres,service_role=X/postgres}',
    'ACL unchanged', '{postgres=X/postgres,service_role=X/postgres}', r.proacl::text);
  perform pg_temp.k806_report('C4', not has_function_privilege('anon', r.oid, 'EXECUTE')
      and not has_function_privilege('authenticated', r.oid, 'EXECUTE') and has_function_privilege('service_role', r.oid, 'EXECUTE'),
    'EXECUTE: service_role yes, anon no, authenticated no', 'true|false|false',
    has_function_privilege('service_role', r.oid, 'EXECUTE')::text || '|' || has_function_privilege('anon', r.oid, 'EXECUTE')::text
      || '|' || has_function_privilege('authenticated', r.oid, 'EXECUTE')::text);
  perform pg_temp.k806_report('C5', md5(r.prosrc) = '057b107e684eef48608faa947c0275b2',
    'body is the KAN-806 body', '057b107e684eef48608faa947c0275b2', md5(r.prosrc));
  v_s := strpos(r.prosrc, '  -- KAN-806:'); v_e := strpos(r.prosrc, v_tail);
  v_spliced := case when v_s > 0 and v_e > v_s then left(r.prosrc, v_s - 1) || v_old_guard || substr(r.prosrc, v_e + length(v_tail)) end;
  perform pg_temp.k806_report('C6', md5(v_spliced) is not distinct from 'e25772a438b80fa09833eaf87fb82860',
    'body outside the guard is byte-identical to the pre-image', 'e25772a438b80fa09833eaf87fb82860', coalesce(md5(v_spliced), 'guard not found'));
  -- negative control: one byte changed outside the guard must break the identity check
  v_mut := replace(r.prosrc, 'kan712_event_not_found', 'kan712_event_not_founD');
  v_spliced := left(v_mut, v_s - 1) || v_old_guard || substr(v_mut, v_e + length(v_tail));
  perform pg_temp.k806_report('C6n', md5(v_spliced) <> 'e25772a438b80fa09833eaf87fb82860',
    'negative control: a 1-byte change outside the guard is detected', 'md5 <> pin', md5(v_spliced));
end $c$;

-- ---------------------------------------------------------------------------------------------------------
-- P. PRE-Z01 phase: the mirror path still works; disabled mirror and stage 1 still refuse 55000
-- ---------------------------------------------------------------------------------------------------------
begin;
do $p1$
declare v_g uuid; v_m uuid; v_ge uuid; v_me uuid; v_res text; v_res2 text; v_t text; v_t2 text;
begin
  if pg_temp.k806_phase() <> 'PRE-Z01' then return; end if;
  select id, event_id into v_g, v_ge from public.games order by id limit 1;
  select id, event_id into v_m, v_me from public.meetups order by id limit 1;
  v_res := pg_temp.k806_call(v_ge, '{"title":"kan806 pre g"}');
  v_res2 := pg_temp.k806_call(v_me, '{"title":"kan806 pre m"}');
  execute 'select (select title from public.events where id = $1) || ''/'' || (select title from public.games where id = $2)'
    into v_t using v_ge, v_g;
  execute 'select (select title from public.events where id = $1) || ''/'' || (select title from public.meetups where id = $2)'
    into v_t2 using v_me, v_m;
  perform pg_temp.k806_report('P1', v_res = 'OK' and v_t = 'kan806 pre g/kan806 pre g',
    'pre-Z01 game patch: events updated and mirrored to games', 'OK events/games=kan806 pre g/kan806 pre g', v_res || ' ' || coalesce(v_t, 'null'));
  perform pg_temp.k806_report('P2', v_res2 = 'OK' and v_t2 = 'kan806 pre m/kan806 pre m',
    'pre-Z01 meetup patch: events updated and mirrored to meetups', 'OK events/meetups=kan806 pre m/kan806 pre m', v_res2 || ' ' || coalesce(v_t2, 'null'));
end $p1$;
rollback;

begin;
do $p3$
declare v_ge uuid; v_res text;
begin
  if pg_temp.k806_phase() <> 'PRE-Z01' then return; end if;
  select event_id into v_ge from public.games order by id limit 1;
  alter table public.events disable trigger trg_zz_kan712_events_compat_mirror;
  v_res := pg_temp.k806_call(v_ge, '{"title":"kan806 disabled"}');
  perform pg_temp.k806_report('P3', v_res like 'ERR 55000 kan712_not_cut_over%',
    'pre-Z01 mirror DISABLED refuses', 'ERR 55000 kan712_not_cut_over', v_res);
end $p3$;
rollback;

begin;
do $p4$
declare v_ge uuid; v_res text;
begin
  if pg_temp.k806_phase() <> 'PRE-Z01' then return; end if;
  select event_id into v_ge from public.games order by id limit 1;
  drop trigger trg_zz_kan712_events_compat_mirror on public.events;   -- stage 1 / rolled back: mirror gone, columns present
  v_res := pg_temp.k806_call(v_ge, '{"title":"kan806 stage1"}');
  perform pg_temp.k806_report('P4', v_res like 'ERR 55000 kan712_not_cut_over%',
    'stage 1 (mirror absent, legacy columns present) refuses', 'ERR 55000 kan712_not_cut_over', v_res);
end $p4$;
rollback;

-- ---------------------------------------------------------------------------------------------------------
-- Q. POST-Z01 phase: the path works, writes events exactly once and nothing else; partial states refuse
-- ---------------------------------------------------------------------------------------------------------
begin;
do $q1$
declare v_g uuid; v_ge uuid; g0 jsonb; g1 jsonb; e0 jsonb; e1 jsonb; u0 bigint[]; u1 bigint[]; v_res text; v_ok boolean;
begin
  if pg_temp.k806_phase() <> 'POST-Z01' then return; end if;
  select id, event_id into v_g, v_ge from public.games order by id limit 1;
  select to_jsonb(g) into g0 from public.games g where id = v_g;
  select to_jsonb(e) - 'search_tsv' into e0 from public.events e where id = v_ge;
  u0 := array[pg_temp.k806_upd('events'), pg_temp.k806_upd('games'), pg_temp.k806_upd('meetups')];
  v_res := pg_temp.k806_call(v_ge, '{"title":"kan806 post g"}');
  u1 := array[pg_temp.k806_upd('events'), pg_temp.k806_upd('games'), pg_temp.k806_upd('meetups')];
  select to_jsonb(g) into g1 from public.games g where id = v_g;
  select to_jsonb(e) - 'search_tsv' into e1 from public.events e where id = v_ge;
  perform pg_temp.k806_report('Q1', v_res = 'OK' and e1->>'title' = 'kan806 post g',
    'post-Z01 game patch succeeds; events.title has the new value', 'OK|kan806 post g', v_res || '|' || coalesce(e1->>'title', 'null'));
  perform pg_temp.k806_report('Q2', u1[1] - u0[1] = 1 and u1[2] = u0[2] and u1[3] = u0[3],
    'n_tup_upd delta events/games/meetups', '1/0/0', (u1[1]-u0[1]) || '/' || (u1[2]-u0[2]) || '/' || (u1[3]-u0[3]));
  v_ok := v_res = 'OK' and g1 = g0 and (g1->>'event_id')::uuid = v_ge and (e1->>'id')::uuid = v_ge and e1->>'event_type' = 'game';
  perform pg_temp.k806_report('Q3', v_ok,
    'parity after a successful call: games row (id, event_id, every retained column) unchanged; events id/event_type unchanged', 'games row equal, link intact',
    'games_equal=' || (g1 = g0)::text || ' event_id=' || coalesce(g1->>'event_id', 'null'));
  v_ok := v_res = 'OK' and (e1 - 'title' - 'updated_at') = (e0 - 'title' - 'updated_at');
  perform pg_temp.k806_report('Q4', v_ok, 'events: after a successful call only title (and touch-trigger updated_at) changed', 'true', v_ok::text);
end $q1$;
rollback;

begin;
do $q5$
declare v_m uuid; v_me uuid; m0 jsonb; m1 jsonb; e1 jsonb; u0 bigint[]; u1 bigint[]; v_res text;
begin
  if pg_temp.k806_phase() <> 'POST-Z01' then return; end if;
  select id, event_id into v_m, v_me from public.meetups order by id limit 1;
  select to_jsonb(m) into m0 from public.meetups m where id = v_m;
  u0 := array[pg_temp.k806_upd('events'), pg_temp.k806_upd('games'), pg_temp.k806_upd('meetups')];
  v_res := pg_temp.k806_call(v_me, '{"title":"kan806 post m"}');
  u1 := array[pg_temp.k806_upd('events'), pg_temp.k806_upd('games'), pg_temp.k806_upd('meetups')];
  select to_jsonb(m) into m1 from public.meetups m where id = v_m;
  select to_jsonb(e) - 'search_tsv' into e1 from public.events e where id = v_me;
  perform pg_temp.k806_report('Q5', v_res = 'OK' and e1->>'title' = 'kan806 post m' and e1->>'event_type' = 'meetup',
    'post-Z01 meetup patch succeeds; events.title has the new value', 'OK|kan806 post m|meetup',
    v_res || '|' || coalesce(e1->>'title', 'null') || '|' || coalesce(e1->>'event_type', 'null'));
  perform pg_temp.k806_report('Q6', u1[1] - u0[1] = 1 and u1[2] = u0[2] and u1[3] = u0[3] and m1 = m0 and (m1->>'event_id')::uuid = v_me,
    'meetup: n_tup_upd events/games/meetups = 1/0/0; meetups row unchanged, event_id link intact', '1/0/0 equal',
    (u1[1]-u0[1]) || '/' || (u1[2]-u0[2]) || '/' || (u1[3]-u0[3]) || ' equal=' || (m1 = m0)::text);
end $q5$;
rollback;

begin;
do $q7$
declare v_ge uuid; v_res text;
begin
  if pg_temp.k806_phase() <> 'POST-Z01' then return; end if;
  select event_id into v_ge from public.games order by id limit 1;
  alter table public.games add column title text;   -- a mirrored legacy column survives: must stay closed
  v_res := pg_temp.k806_call(v_ge, '{"title":"kan806 partial g"}');
  perform pg_temp.k806_report('Q7', v_res like 'ERR 55000 kan712_not_cut_over%',
    'mirror absent but games.title present refuses', 'ERR 55000 kan712_not_cut_over', v_res);
end $q7$;
rollback;

begin;
do $q8$
declare v_ge uuid; v_res text;
begin
  if pg_temp.k806_phase() <> 'POST-Z01' then return; end if;
  select event_id into v_ge from public.games order by id limit 1;
  alter table public.meetups add column rsvp_policy text;
  v_res := pg_temp.k806_call(v_ge, '{"title":"kan806 partial m"}');
  perform pg_temp.k806_report('Q8', v_res like 'ERR 55000 kan712_not_cut_over%',
    'mirror absent but meetups.rsvp_policy present refuses', 'ERR 55000 kan712_not_cut_over', v_res);
end $q8$;
rollback;

begin;
do $q9$
declare v_ge uuid; v_res text;
begin
  if pg_temp.k806_phase() <> 'POST-Z01' then return; end if;
  select event_id into v_ge from public.games order by id limit 1;
  create function pg_temp.k806_noop() returns trigger language plpgsql as 'begin return null; end';
  create trigger trg_zz_kan712_events_compat_mirror after update on public.events for each row execute function pg_temp.k806_noop();
  alter table public.events disable trigger trg_zz_kan712_events_compat_mirror;
  v_res := pg_temp.k806_call(v_ge, '{"title":"kan806 disabled post"}');
  perform pg_temp.k806_report('Q9', v_res like 'ERR 55000 kan712_not_cut_over%',
    'a present but DISABLED mirror refuses even with legacy columns gone', 'ERR 55000 kan712_not_cut_over', v_res);
end $q9$;
rollback;

begin;
do $q10$
declare v_res text;
begin
  if pg_temp.k806_phase() <> 'POST-Z01' then return; end if;
  v_res := pg_temp.k806_call((select event_id from public.games order by id limit 1), '{"creator_user_id":null}');
  perform pg_temp.k806_report('Q10', v_res like 'ERR 22023 kan712_patch_key_not_allowed%',
    'post-Z01 patch key allow-list still enforced', 'ERR 22023 kan712_patch_key_not_allowed', v_res);
end $q10$;
rollback;

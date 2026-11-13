-- KAN-803 rebased on live (KAN-862 package P1, backend-1; Epic KAN-708). Supersedes
-- supabase/migrations/_superseded/20261104110800_kan803_d04_blockers_frozen_guards_a.sql (authored, never applied).
--
-- WHAT: the invite, join-request and waitlist frozen guards take the host from the new DEFINER helper
--   kan803_game_host_uid(uuid) (events.creator_user_id) inside their unchanged RLS-scoped games lookup
--   (CTO dreq-da12f7c0 option (a)).
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058), wtncuzcskpigqpmnxwws, 2026-11-13: pg_get_functiondef of each target.
-- Each live md5(prosrc) was compared with the superseded file's pre-image pin; the body change is that file's
-- intent and nothing else. Live pre-image -> post-image md5(prosrc):
--   public.trgfn_invite_block_frozen_guard()  af79f8013de8db8fd3a970e78308b0a5 -> 81e302c646fd39c0c809009d4debc382
--   public.trgfn_joinreq_block_frozen_guard()  5986334a1449ecaffc530ec1301fdba6 -> a883c3cb708111f5e52f441e3c9e26d3
--   public.trgfn_waitlist_block_frozen_guard()  e9e1d50b5a46d1daefc73f295b8c0b70 -> 03296c42de73e93b4b5eefba9583e2ba
--
-- HOW: CREATE OR REPLACE with the same signature keeps oid, owner, ACL, SECURITY, volatility and search_path; the
-- post block asserts them, and every trigger definition on them, unchanged. Definitions only: no row is written and
-- no column, table, policy or existing grant changes. Equivalence: the pre block refuses unless every games row has
-- its 'game' events parent and every games column whose read moves equals its events counterpart (KAN-711 parity;
-- checked only while the column exists). Any other live body refuses (re-author from pg_get_functiondef).
-- No BEGIN/COMMIT: apply_migration and the CLI wrap each migration in one transaction.
-- Live test: supabase/tests/events_p4/kan803_p1_live_test.sql (BEGIN ... ROLLBACK, TAP).

do $pre$
declare
  r record; c text; v_n bigint; v_attr jsonb := '{}'::jsonb;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'kan803 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  for r in select * from (values
    ('public.trgfn_invite_block_frozen_guard()', 'af79f8013de8db8fd3a970e78308b0a5', '81e302c646fd39c0c809009d4debc382'),
    ('public.trgfn_joinreq_block_frozen_guard()', '5986334a1449ecaffc530ec1301fdba6', 'a883c3cb708111f5e52f441e3c9e26d3'),
    ('public.trgfn_waitlist_block_frozen_guard()', 'e9e1d50b5a46d1daefc73f295b8c0b70', '03296c42de73e93b4b5eefba9583e2ba')) t(fn, pin, post) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'kan803 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pin then
      raise exception 'kan803 pre: pre-image drift on % (md5(prosrc) %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pin;
    end if;
    v_attr := v_attr || jsonb_build_object(r.fn, (
      select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
        from pg_proc p where p.oid = to_regprocedure(r.fn)));
  end loop;
  if to_regprocedure('public.kan803_game_host_uid(uuid)') is not null then
    raise exception 'kan803 pre: helper public.kan803_game_host_uid(uuid) already exists';
  end if;
  select count(*) into v_n from public.games g
    left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null;
  if v_n > 0 then
    raise exception 'kan803 pre: % games row(s) without a ''game'' events parent', v_n;
  end if;
  foreach c in array array['creator_user_id'] loop
    if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = c and attnum > 0 and not attisdropped) then
      execute format('select count(*) from public.games x join public.events e on e.id = x.event_id and e.event_type = %L
                       where x.%I is distinct from e.%I', 'game', c, c) into v_n;
      if v_n > 0 then
        raise exception 'kan803 pre: % games row(s) differ from events on % (KAN-711 parity)', v_n, c;
      end if;
    end if;
  end loop;
  perform set_config('kan803.attr', v_attr::text, true);
end
$pre$;

create function public.kan803_game_host_uid(p_game_id uuid)
 returns uuid
 language sql
 stable
 security definer
 set search_path = public, pg_temp
as $function$
  select e.creator_user_id
    from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'
   where g.id = p_game_id
$function$;

alter function public.kan803_game_host_uid(uuid) owner to postgres;
revoke all on function public.kan803_game_host_uid(uuid) from public, anon, authenticated, service_role;
grant execute on function public.kan803_game_host_uid(uuid) to authenticated, service_role;

comment on function public.kan803_game_host_uid(uuid) is
  'KAN-803: host user id (events.creator_user_id) of a game, via games.event_id. SECURITY DEFINER so the invoker '
  'frozen-guard triggers can read FORCE-RLS public.events. Returns nothing else. EXECUTE: authenticated, service_role.';

CREATE OR REPLACE FUNCTION public.trgfn_invite_block_frozen_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare host_uid uuid;
begin
  select public.kan803_game_host_uid(g.id) into host_uid from public.games g where g.id = new.game_id;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  perform public.guard_user_not_frozen(new.to_user_id);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trgfn_joinreq_block_frozen_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare host_uid uuid;
begin
  perform public.guard_user_not_frozen(new.from_user_id);
  select public.kan803_game_host_uid(g.id) into host_uid from public.games g where g.id = new.game_id;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trgfn_waitlist_block_frozen_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare host_uid uuid;
begin
  perform public.guard_user_not_frozen(new.user_id);
  select public.kan803_game_host_uid(g.id) into host_uid from public.games g where g.id = new.game_id;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  return new;
end;
$function$;

do $post$
declare
  r record; v_attr jsonb := current_setting('kan803.attr')::jsonb; v_now jsonb;
begin
  for r in select * from (values
    ('public.trgfn_invite_block_frozen_guard()', 'af79f8013de8db8fd3a970e78308b0a5', '81e302c646fd39c0c809009d4debc382'),
    ('public.trgfn_joinreq_block_frozen_guard()', '5986334a1449ecaffc530ec1301fdba6', 'a883c3cb708111f5e52f441e3c9e26d3'),
    ('public.trgfn_waitlist_block_frozen_guard()', 'e9e1d50b5a46d1daefc73f295b8c0b70', '03296c42de73e93b4b5eefba9583e2ba')) t(fn, pin, post) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post then
      raise exception 'kan803 post: % body md5 %, expected %', r.fn,
        (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.post;
    end if;
    select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'kan803 post: % signature/attributes/owner/ACL/trigger changed: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
  if (select proacl::text from pg_proc where oid = to_regprocedure('public.kan803_game_host_uid(uuid)')) is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
     or (select pg_get_userbyid(proowner) from pg_proc where oid = to_regprocedure('public.kan803_game_host_uid(uuid)')) <> 'postgres'
     or not (select prosecdef from pg_proc where oid = to_regprocedure('public.kan803_game_host_uid(uuid)'))
     or (select provolatile from pg_proc where oid = to_regprocedure('public.kan803_game_host_uid(uuid)')) <> 's'
     or (select proconfig from pg_proc where oid = to_regprocedure('public.kan803_game_host_uid(uuid)')) is distinct from array['search_path=public, pg_temp'] then
    raise exception 'kan803 post: helper public.kan803_game_host_uid(uuid) attributes/ACL wrong (acl %)', (select proacl::text from pg_proc where oid = to_regprocedure('public.kan803_game_host_uid(uuid)'));
  end if;
end
$post$;

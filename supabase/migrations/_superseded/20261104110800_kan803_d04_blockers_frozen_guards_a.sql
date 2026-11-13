-- KAN-803 (supporting KAN-772 / KAN-719, Epic KAN-708; part (a) of the frozen-guard D04 BLOCKERS): three of the four
-- frozen-guard trigger functions (supabase/tests/events_p4/KAN718_D04_DISPOSITION.md rows 30/31/34) stop reading
-- games.creator_user_id, so they keep working after KAN-719 Z01 (20261105100000_kan719_z01_remove_replaced_columns.sql,
-- seq 603) drops that column. trgfn_roster_block_frozen_guard (row 33) is OUT OF SCOPE and is not touched here.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan803_d04_frozen_guards_a_test.sql (throwaway PG16; it installs the
-- pre-images and their baseline triggers as a fixture because the local chain has none of them).
--
-- CTO DECISION dreq-da12f7c0, option (a). The three functions are SECURITY INVOKER trigger functions. On a direct
-- client insert into game_join_requests (authenticated keeps INSERT there, 20260901190000_kan86) the trigger runs as
-- authenticated, and public.events is FORCE RLS with every client grant revoked (20261101140000_kan710), so reading
-- events.creator_user_id inline would raise 42501 for that caller. The host therefore comes from one new helper:
--
--   public.kan803_game_host_uid(uuid) -> uuid
--     LANGUAGE sql, STABLE, SECURITY DEFINER, SET search_path = public, pg_temp, owned by the applying role.
--     Returns events.creator_user_id of the game's typed parent (games.event_id -> events.id, event_type 'game')
--     and nothing else. EXECUTE: authenticated and service_role only (PUBLIC and anon revoked, asserted below).
--
-- Each body keeps its RLS-scoped lookup `from public.games g where g.id = new.game_id` (so a caller that cannot see
-- the game still gets game_not_found, exactly as before) and takes the host from the helper inside that same
-- statement. Every other byte of each body is the pre-image's:
--
--   function                                 pre-image                               read changed
--   trgfn_invite_block_frozen_guard()        20260829080500_baseline_schema:18977    g.creator_user_id -> helper(g.id)
--   trgfn_joinreq_block_frozen_guard()       20260829080500_baseline_schema:19032    g.creator_user_id -> helper(g.id)
--   trgfn_waitlist_block_frozen_guard()      20260829080500_baseline_schema:20320    g.creator_user_id -> helper(g.id)
--
-- Replaced in place (CREATE OR REPLACE, same signature): SECURITY INVOKER, search_path, owner and ACL are kept and
-- asserted in section 4. No trigger is created, altered or dropped; no table, column, policy or row is touched; the
-- only GRANT/REVOKE is on the new helper.
--
-- EQUIVALENCE: games.event_id is NOT NULL and FK-validated since the KAN-712 cutover and events.id is the PK, so the
-- helper returns exactly one value per existing game; section 0 refuses if any game lacks its typed parent or if
-- any games.creator_user_id differs from events.creator_user_id (KAN-711 parity).
--
-- T-058 SUBSTITUTE (as KAN-772 / KAN-799 / KAN-800): production is not read here. Section 0 pins md5(prosrc),
-- SECURITY, volatility and search_path of each pre-image as authored in the baseline; any drift fails closed --
-- re-author from pg_get_functiondef on the live catalogue then.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
  v_n bigint;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-803 pre: applying role % must be superuser or BYPASSRLS (the helper reads FORCE-RLS public.events as its owner)', current_user;
  end if;
  if to_regclass('public.events') is null then
    raise exception 'KAN-803 pre: public.events missing (KAN-710 not applied)';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                  and tgname = 'trg_zz_kan712_events_compat_mirror' and tgenabled <> 'D') then
    raise exception 'KAN-803 pre: KAN-712 cutover not live (compat mirror trigger on events missing or disabled)';
  end if;
  if to_regprocedure('public.kan803_game_host_uid(uuid)') is not null then
    raise exception 'KAN-803 pre: public.kan803_game_host_uid(uuid) already exists';
  end if;

  -- Pre-image pins: md5(prosrc) | SECURITY INVOKER | volatile | proconfig
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|' || p.proconfig::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public.trgfn_invite_block_frozen_guard()',  'af79f8013de8db8fd3a970e78308b0a5'),
      ('public.trgfn_joinreq_block_frozen_guard()', '5986334a1449ecaffc530ec1301fdba6'),
      ('public.trgfn_waitlist_block_frozen_guard()','e9e1d50b5a46d1daefc73f295b8c0b70')
    ) t(f, src)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src or p.prosecdef or p.provolatile <> 'v'
      or p.proconfig is distinct from array['search_path=public, pg_temp'];
  if v_bad is not null then
    raise exception 'KAN-803 pre: pre-image drift (re-author from pg_get_functiondef on this catalogue): %', v_bad;
  end if;

  -- Every game has exactly its typed parent (KAN-712 cutover invariant).
  select count(*) into v_n
    from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where e.id is null;
  if v_n <> 0 then
    raise exception 'KAN-803 pre: % game row(s) without their typed events parent', v_n;
  end if;

  -- The value this file starts reading from events must equal the legacy mirror while the column still exists.
  if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'creator_user_id' and not attisdropped) then
    execute 'select count(*) from public.games g join public.events e on e.id = g.event_id
              where g.creator_user_id is distinct from e.creator_user_id' into v_n;
    if v_n <> 0 then
      raise exception 'KAN-803 pre: % game row(s) differ from events on creator_user_id; reconcile first (KAN-711 parity)', v_n;
    end if;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image attributes and trigger rows (asserted unchanged in section 4).
-- ---------------------------------------------------------------------------------------------------------
create temp table kan803_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, pg_get_function_identity_arguments(p.oid) as args,
       pg_get_function_result(p.oid) as res, p.prorettype, p.prosecdef, p.provolatile, p.proconfig, p.proacl,
       p.proowner, p.proretset, p.proisstrict, p.proparallel, p.pronargdefaults, p.proargtypes::text as argtypes
  from pg_proc p
 where p.oid in ('public.trgfn_invite_block_frozen_guard()'::regprocedure,
                 'public.trgfn_joinreq_block_frozen_guard()'::regprocedure,
                 'public.trgfn_waitlist_block_frozen_guard()'::regprocedure);

create temp table kan803_pre_trg on commit drop as
select t.oid, t.tgrelid, t.tgname, t.tgfoid, t.tgtype, t.tgenabled, pg_get_triggerdef(t.oid) as def
  from pg_trigger t
 where not t.tgisinternal and t.tgfoid in (select oid from kan803_pre);

-- ---------------------------------------------------------------------------------------------------------
-- 2. The helper (CTO decision dreq-da12f7c0, option (a)).
-- ---------------------------------------------------------------------------------------------------------
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

revoke all on function public.kan803_game_host_uid(uuid) from public, anon, authenticated, service_role;
grant execute on function public.kan803_game_host_uid(uuid) to authenticated, service_role;

comment on function public.kan803_game_host_uid(uuid) is
  'KAN-803: host user id (events.creator_user_id) of a game, via games.event_id. SECURITY DEFINER so the invoker '
  'frozen-guard triggers can read FORCE-RLS public.events. Returns nothing else. EXECUTE: authenticated, service_role.';

-- ---------------------------------------------------------------------------------------------------------
-- 3. Replacements. Pre-image bodies verbatim except the one read listed in the header.
-- ---------------------------------------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------------------------------------
-- 4. Post-conditions.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
  v_acl text;
begin
  -- signature, result, security, volatility, search_path, owner and ACL unchanged
  select string_agg(b.fn, ', ') into v_bad
    from kan803_pre b
    left join pg_proc p on p.oid = b.oid
   where p.oid is null
      or (pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prorettype, p.prosecdef,
          p.provolatile, p.proconfig, p.proacl::text, p.proowner, p.proretset, p.proisstrict, p.proparallel,
          p.pronargdefaults, p.proargtypes::text)
         is distinct from
         (b.args, b.res, b.prorettype, b.prosecdef, b.provolatile, b.proconfig, b.proacl::text, b.proowner,
          b.proretset, b.proisstrict, b.proparallel, b.pronargdefaults, b.argtypes);
  if v_bad is not null then
    raise exception 'KAN-803 post: attributes changed for %', v_bad;
  end if;
  if (select count(*) from kan803_pre) <> 3 then
    raise exception 'KAN-803 post: expected 3 functions, saw %', (select count(*) from kan803_pre);
  end if;

  -- trigger rows unchanged
  if exists (select 1 from kan803_pre_trg b left join pg_trigger t on t.oid = b.oid
              where t.oid is null or (t.tgrelid, t.tgname, t.tgfoid, t.tgtype, t.tgenabled, pg_get_triggerdef(t.oid))
                    is distinct from (b.tgrelid, b.tgname, b.tgfoid, b.tgtype, b.tgenabled, b.def))
     or (select count(*) from pg_trigger t where not t.tgisinternal and t.tgfoid in (select oid from kan803_pre))
        <> (select count(*) from kan803_pre_trg) then
    raise exception 'KAN-803 post: trigger rows changed';
  end if;

  -- helper: SECURITY DEFINER, STABLE, search_path, owner = applying role, EXECUTE only authenticated + service_role
  if not exists (select 1 from pg_proc p
                  where p.oid = 'public.kan803_game_host_uid(uuid)'::regprocedure
                    and p.prosecdef and p.provolatile = 's'
                    and p.proconfig = array['search_path=public, pg_temp']
                    and p.proowner = (select oid from pg_roles where rolname = current_user)) then
    raise exception 'KAN-803 post: helper attributes wrong';
  end if;
  select string_agg(coalesce(r.rolname, 'PUBLIC') || ':' || a.privilege_type, ',' order by coalesce(r.rolname, 'PUBLIC'), a.privilege_type)
    into v_acl
    from pg_proc p, aclexplode(p.proacl) a left join pg_roles r on r.oid = a.grantee
   where p.oid = 'public.kan803_game_host_uid(uuid)'::regprocedure
     and a.grantee <> p.proowner;
  if v_acl is distinct from 'authenticated:EXECUTE,service_role:EXECUTE' then
    raise exception 'KAN-803 post: helper ACL is %, expected authenticated + service_role EXECUTE only', v_acl;
  end if;
  if has_function_privilege('anon', 'public.kan803_game_host_uid(uuid)', 'EXECUTE') then
    raise exception 'KAN-803 post: anon can execute the helper';
  end if;
end
$post$;

commit;

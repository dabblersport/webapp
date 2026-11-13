-- KAN-862 P4 (backend-4): KAN-809 rebased onto the live catalogue after KAN-718 (2026-11-13). Supersedes
-- 20261104110800_kan809_update_game_stale_guard.sql (moved to _superseded/, never edited).
-- KAN-809 (KAN-761 F3): a stale rpc_update_game must not revert a concurrent reschedule. Adds ONE new overload
--   public.rpc_update_game(p_game_id, p_start_at, p_end_at, p_expected_updated_at timestamptz /* no default */,
--                          <the 14 existing optionals>)
-- that locks the events row FOR UPDATE, raises 40001 stale_update when p_expected_updated_at is not null and differs
-- from events.updated_at, and otherwise delegates to the existing 17-argument public wrapper (which reaches the KAN-718
-- inner, rpc_update_game_kan712_inner; its argument list is the inner's). Nothing existing is replaced, dropped or
-- re-granted; no row is written. Not registered in kan712_wrapped_rpcs (see the superseded file's header for why).
--
-- REBASE. Pins re-measured live (pg_proc) on 2026-11-13: the 17-arg wrapper md5(prosrc) cf869fd1507bf17c273a57af599840cb
-- (unchanged since the original authoring), ACL {postgres,authenticated,service_role}; added a pin on the KAN-718 inner
-- md5(prosrc) af77954cbb14e8fa2f494d231dd49484. No body references a games/meetups column from the Z01 manifest
-- (it reads public.events.updated_at only). The explicit BEGIN/COMMIT of the original is dropped: apply_migration
-- runs the file in one transaction. Live proof: supabase/tests/events_p4/kan862_p4_write_path_live_test.sql.

set local lock_timeout = '10s';

do $pre$
declare
  v_bad text;
begin
  if to_regclass('public.events') is null or not exists (
       select 1 from pg_attribute where attrelid = 'public.events'::regclass and attname = 'updated_at'
          and attnum > 0 and not attisdropped) then
    raise exception 'KAN-809 pre: public.events.updated_at missing';
  end if;
  if to_regprocedure('public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)') is not null then
    raise exception 'KAN-809 pre: the KAN-809 overload already exists';
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname = 'rpc_update_game') <> 1 then
    raise exception 'KAN-809 pre: expected exactly one public.rpc_update_game overload';
  end if;
  -- The existing overload: the KAN-712 wrapper, its attributes and ACL as measured on the chain.
  select coalesce(p.prosecdef::text || '|' || p.proconfig::text || '|' || p.proowner::regrole::text || '|' || p.proacl::text
                  || '|' || md5(p.prosrc), 'absent')
    into v_bad
    from (select 1) d
    left join pg_proc p on p.oid = to_regprocedure('public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)')
   where p.oid is null
      or not p.prosecdef
      or p.proconfig is distinct from array['search_path=""']
      or position('set_config(''kan712.contract'', ''on'', true)' in p.prosrc) = 0
      or p.proowner <> 'postgres'::regrole
      or p.proacl is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'::aclitem[]
      or md5(p.prosrc) <> 'cf869fd1507bf17c273a57af599840cb';
  if v_bad is not null then
    raise exception 'KAN-809 pre: existing rpc_update_game absent or drifted (re-measure on the live catalogue): %', v_bad;
  end if;
  -- The inner the wrapper delegates to: the KAN-718 body (20261113052351), as measured live 2026-11-13.
  if (select md5(prosrc) from pg_proc where oid = to_regprocedure('public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'))
     is distinct from 'af77954cbb14e8fa2f494d231dd49484' then
    raise exception 'KAN-809 pre: rpc_update_game_kan712_inner absent or drifted from the KAN-718 body (re-measure on the live catalogue)';
  end if;
  if not exists (select 1 from public.kan712_wrapped_rpcs where name = 'rpc_update_game' and lock_spec = 'game:p_game_id') then
    raise exception 'KAN-809 pre: rpc_update_game is not recorded as KAN-712-wrapped with lock game:p_game_id';
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Capture what must not change: every existing rpc_update_game* function.
-- ---------------------------------------------------------------------------------------------------------
create temp table kan809_pre on commit drop as
select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args, pg_get_function_result(p.oid) as res,
       p.prosecdef, p.proconfig, p.proowner, p.proacl, md5(p.prosrc) as src
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace and p.proname like 'rpc\_update\_game%';

-- ---------------------------------------------------------------------------------------------------------
-- 2. The new overload.
-- ---------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.rpc_update_game(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone,
  p_expected_updated_at timestamp with time zone,
  p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false,
  p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text,
  p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean,
  p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false,
  p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer,
  p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_prev text := current_setting('kan712.contract', true);
  v_result text;
  v_updated_at timestamp with time zone;
BEGIN
  PERFORM set_config('kan712.contract', 'on', true);
  -- Same lock as the KAN-712 wrapper, taken first; the comparison reads the LOCKED (latest committed) row.
  SELECT e.updated_at INTO v_updated_at FROM public.events e WHERE e.id = $1 AND e.event_type = 'game' FOR UPDATE;
  IF FOUND AND p_expected_updated_at IS NOT NULL AND v_updated_at IS DISTINCT FROM p_expected_updated_at THEN
    RAISE EXCEPTION USING ERRCODE = '40001', MESSAGE = 'stale_update',
      DETAIL = 'events.updated_at changed since it was read; re-read the game and retry.';
  END IF;
  v_result := public.rpc_update_game($1, $2, $3, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18);
  PERFORM set_config('kan712.contract', coalesce(v_prev, ''), true);
  RETURN v_result;
END
$function$;

ALTER FUNCTION public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-checks.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
  v_new oid := to_regprocedure('public.rpc_update_game(uuid,timestamptz,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)');
  v_old oid := to_regprocedure('public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)');
begin
  -- 3a. Every pre-existing rpc_update_game* is untouched.
  select string_agg(b.proname || '(' || b.args || ')', '; ') into v_bad
    from kan809_pre b
    left join pg_proc p on p.oid = b.oid
   where p.oid is null or p.proname <> b.proname or pg_get_function_identity_arguments(p.oid) <> b.args
      or pg_get_function_result(p.oid) <> b.res or p.prosecdef <> b.prosecdef or p.proconfig is distinct from b.proconfig
      or p.proowner <> b.proowner or p.proacl is distinct from b.proacl or md5(p.prosrc) <> b.src;
  if v_bad is not null then
    raise exception 'KAN-809 post: an existing function changed: %', v_bad;
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname like 'rpc\_update\_game%')
     <> (select count(*) from kan809_pre) + 1 then
    raise exception 'KAN-809 post: expected exactly one new rpc_update_game* function';
  end if;

  -- 3b. New overload: attributes, owner, ACL equal to the existing public overload.
  if v_new is null or not exists (
       select 1 from pg_proc n join pg_proc o on o.oid = v_old
        where n.oid = v_new and n.prosecdef and n.proconfig = o.proconfig and n.proowner = o.proowner
          and n.proacl = o.proacl and pg_get_function_result(n.oid) = 'text' and n.pronargdefaults = 14) then
    raise exception 'KAN-809 post: new overload attributes/owner/ACL differ from the existing rpc_update_game';
  end if;
  if has_function_privilege('anon', v_new, 'EXECUTE') then
    raise exception 'KAN-809 post: anon can execute the new overload';
  end if;

  -- 3c. Not a registered wrapper (see header).
  if (select count(*) from public.kan712_wrapped_rpcs where name = 'rpc_update_game') <> 1 then
    raise exception 'KAN-809 post: kan712_wrapped_rpcs rpc_update_game rows changed';
  end if;
end
$post$;

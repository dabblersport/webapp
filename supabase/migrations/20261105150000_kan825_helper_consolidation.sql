-- KAN-825: consolidate the two game-host helpers (CTO ruling dreq-951c3bed).
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan825_helper_consolidation_test.sql (throwaway PG16 only).
--
-- Two helpers answer the same question with the same query:
--   public.kan803_game_host_uid(uuid) -> uuid                20261104110800_kan803_d04_blockers_frozen_guards_a.sql
--   public.kan804_game_event_facts(uuid) -> TABLE(creator_user_id, geo_location_id, area_id)
--                                                             20261104110900_kan804_d04_blockers_frozen_guards_b.sql
-- Ruling: kan804_game_event_facts is canonical. kan803_game_host_uid keeps its exact signature, return type,
-- LANGUAGE sql, STABLE, SECURITY DEFINER, search_path, owner and grants; only its body changes, to read the host
-- through the canonical function. The three KAN-803 trigger bodies and the KAN-804 functions are NOT touched.
-- Nothing is dropped; no grant, owner, comment, table, policy or row changes.
--
-- Why the call is legal for every current caller: kan803_game_host_uid is SECURITY DEFINER owned by postgres, so
-- its body runs as postgres, which owns (and holds EXECUTE on) kan804_game_event_facts. authenticated keeps EXECUTE
-- on kan803_game_host_uid only; it still has no EXECUTE on kan804_game_event_facts (asserted below).
--
-- Body authored from pg_get_functiondef of the catalogue (T-058); only the AS $function$ ... $function$ text differs.
--
-- Fail-closed pre-check (section 1): signature, return type, language, volatility, security mode, search_path,
-- owner, ACL and body of kan803_game_host_uid are what KAN-803 created (or already this migration's body, so a
-- re-run is a no-op), and kan804_game_event_facts is the KAN-804 function. Post-check (section 3): every attribute
-- except prosrc is identical to the pre-image, and the ACLs of both functions are unchanged.

begin;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-check (fail closed).
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_h   oid := to_regprocedure('public.kan803_game_host_uid(uuid)');
  v_f   oid := to_regprocedure('public.kan804_game_event_facts(uuid)');
  v_acl text;
  p     record;
begin
  if v_h is null then raise exception 'KAN-825 pre: public.kan803_game_host_uid(uuid) is absent'; end if;
  if v_f is null then raise exception 'KAN-825 pre: public.kan804_game_event_facts(uuid) is absent'; end if;

  select pr.*, l.lanname, pg_get_function_arguments(pr.oid) as fargs, pg_get_function_result(pr.oid) as fres,
         pg_get_userbyid(pr.proowner) as owner_name
    into p from pg_proc pr join pg_language l on l.oid = pr.prolang where pr.oid = v_h;
  if p.fargs <> 'p_game_id uuid' or p.fres <> 'uuid' or p.prorettype <> 'uuid'::regtype or p.proretset
     or p.lanname <> 'sql' or p.provolatile <> 's' or not p.prosecdef or p.proisstrict or p.proparallel <> 'u'
     or p.proconfig is distinct from array['search_path=public, pg_temp'] or p.owner_name <> 'postgres' then
    raise exception 'KAN-825 pre: kan803_game_host_uid attributes are not what KAN-803 created '
      '(args=% result=% lang=% vol=% secdef=% strict=% parallel=% config=% owner=%)',
      p.fargs, p.fres, p.lanname, p.provolatile, p.prosecdef, p.proisstrict, p.proparallel, p.proconfig, p.owner_name;
  end if;
  -- KAN-803 body (3e6e858b...) or this migration's body (re-run).
  if md5(p.prosrc) not in ('3e6e858b0fb1d80d09e2db2a9bfe770b', '4a0cd1f7d576ef7eda529a6e2253d7bc') then
    raise exception 'KAN-825 pre: kan803_game_host_uid body md5 % is neither the KAN-803 nor the KAN-825 body', md5(p.prosrc);
  end if;
  select string_agg(coalesce(r.rolname, 'PUBLIC') || ':' || a.privilege_type, ','
                    order by coalesce(r.rolname, 'PUBLIC'), a.privilege_type)
    into v_acl
    from aclexplode(p.proacl) a left join pg_roles r on r.oid = a.grantee
   where a.grantee <> p.proowner;
  if v_acl is distinct from 'authenticated:EXECUTE,service_role:EXECUTE' then
    raise exception 'KAN-825 pre: kan803_game_host_uid ACL is %, KAN-803 created authenticated + service_role EXECUTE', v_acl;
  end if;

  select pr.*, pg_get_function_result(pr.oid) as fres, pg_get_userbyid(pr.proowner) as owner_name
    into p from pg_proc pr where pr.oid = v_f;
  if p.fres <> 'TABLE(creator_user_id uuid, geo_location_id uuid, area_id uuid)' or not p.prosecdef
     or p.provolatile <> 's' or p.proconfig is distinct from array['search_path=public, pg_temp']
     or p.owner_name <> 'postgres' or md5(p.prosrc) <> 'd9946ed919c387868e7f9cc5f2053af2' then
    raise exception 'KAN-825 pre: kan804_game_event_facts is not the KAN-804 function (result=% secdef=% owner=% md5=%)',
      p.fres, p.prosecdef, p.owner_name, md5(p.prosrc);
  end if;
  if has_function_privilege('authenticated', v_f, 'EXECUTE') or has_function_privilege('anon', v_f, 'EXECUTE') then
    raise exception 'KAN-825 pre: a client role can execute kan804_game_event_facts';
  end if;
end
$pre$;

create temp table kan825_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, pg_get_function_arguments(p.oid) as args,
       pg_get_function_identity_arguments(p.oid) as idargs, pg_get_function_result(p.oid) as res, p.prorettype,
       p.proretset, p.prolang, p.prosecdef, p.provolatile, p.proisstrict, p.proparallel, p.proconfig,
       p.proacl::text as acl, p.proowner, p.pronargs, p.pronargdefaults, p.proargtypes::text as argtypes,
       p.proargnames, md5(p.prosrc) as src_md5, obj_description(p.oid, 'pg_proc') as descr
  from pg_proc p
 where p.oid in ('public.kan803_game_host_uid(uuid)'::regprocedure, 'public.kan804_game_event_facts(uuid)'::regprocedure);

-- ---------------------------------------------------------------------------------------------------------
-- 2. The replacement. Header = pg_get_functiondef of the catalogue; body reads through the canonical helper.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.kan803_game_host_uid(p_game_id uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT f.creator_user_id
    FROM public.kan804_game_event_facts(p_game_id) AS f
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-check.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare v_bad text;
begin
  if (select count(*) from kan825_pre) <> 2 then
    raise exception 'KAN-825 post: expected 2 functions in the pre-image, saw %', (select count(*) from kan825_pre);
  end if;
  select string_agg(b.fn, ', ') into v_bad
    from kan825_pre b left join pg_proc p on p.oid = b.oid
   where p.oid is null
      or (pg_get_function_arguments(p.oid), pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
          p.prorettype, p.proretset, p.prolang, p.prosecdef, p.provolatile, p.proisstrict, p.proparallel, p.proconfig,
          p.proacl::text, p.proowner, p.pronargs, p.pronargdefaults, p.proargtypes::text, p.proargnames,
          obj_description(p.oid, 'pg_proc'))
         is distinct from
         (b.args, b.idargs, b.res, b.prorettype, b.proretset, b.prolang, b.prosecdef, b.provolatile, b.proisstrict,
          b.proparallel, b.proconfig, b.acl, b.proowner, b.pronargs, b.pronargdefaults, b.argtypes, b.proargnames,
          b.descr);
  if v_bad is not null then raise exception 'KAN-825 post: attributes changed for %', v_bad; end if;
  if (select md5(prosrc) from pg_proc where oid = 'public.kan804_game_event_facts(uuid)'::regprocedure)
     is distinct from (select src_md5 from kan825_pre where fn = 'kan804_game_event_facts(uuid)') then
    raise exception 'KAN-825 post: kan804_game_event_facts body changed';
  end if;
  if (select md5(prosrc) from pg_proc where oid = 'public.kan803_game_host_uid(uuid)'::regprocedure)
     <> '4a0cd1f7d576ef7eda529a6e2253d7bc' then
    raise exception 'KAN-825 post: kan803_game_host_uid body is not the KAN-825 body';
  end if;
  if has_function_privilege('anon', 'public.kan803_game_host_uid(uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.kan804_game_event_facts(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.kan803_game_host_uid(uuid)', 'EXECUTE') then
    raise exception 'KAN-825 post: EXECUTE privileges changed';
  end if;
end
$post$;

commit;

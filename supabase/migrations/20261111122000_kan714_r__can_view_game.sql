-- KAN-903 (Epic KAN-714): public._can_view_game(uuid) reads the shared game facts from public.events only.
--
-- Before: the body (KAN-713) evaluates the same visibility predicate twice and intersects the results, once on
-- g.creator_user_id / g.listing_visibility (public.games) and once on e.creator_user_id / e.listing_visibility
-- (public.events, joined e.id = g.event_id and e.event_type = 'game'). After: the games copy is removed and the events
-- copy is kept verbatim. g.id, g.event_id and g.squad_id stay (games-only columns, not among the 22 KAN-866 columns).
--
-- Why equality holds: the two copies differ only in reading creator_user_id and listing_visibility from g or from e.
-- The guard refuses unless every game has its game event and both rows agree on those two columns (KAN-711 parity),
-- so on the data present the games copy is identical to the events copy and dropping it changes no result. The
-- intersection could only ever make the result narrower when the two disagreed; with parity it is a no-op.
--
-- Attributes. LANGUAGE sql, STABLE, SECURITY DEFINER, SET search_path TO 'public', owner postgres and the ACL
-- {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres} are kept:
-- CREATE OR REPLACE keeps oid, owner and ACL, and the DDL header is pg_get_functiondef of the live function (T-058).
-- The post check asserts the oid, the body md5 and every attribute unchanged.
--
-- Pins. pre md5(prosrc) 7ee01526ff64e59691ada52fa77474ce (functiondef f7c9d38aa625a03bf39cc96567ebc173, live
-- 2026-11-12); post md5(prosrc) 85f265c09711425a66a21c4a595cce62. At post the migration raises a notice and returns.
-- Test: supabase/tests/events_p4/kan714_r__can_view_game_live_test.sql.
--
-- ROLLBACK: run this pre-image (pg_get_functiondef of the live function, 2026-11-12) with the leading "-- " removed.
-- CREATE OR REPLACE FUNCTION public._can_view_game(p_game_id uuid)
--  RETURNS boolean
--  LANGUAGE sql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
--   select exists (
--     select 1 from public.games g
--     join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
--     where g.id = p_game_id
--       and (
--         g.creator_user_id = auth.uid()
--         or public.is_admin(auth.uid())
--         or exists (
--              select 1 from public.game_roster gr
--              where gr.game_id = g.id
--                and gr.user_id = auth.uid()
--                and gr.status = 'active'
--            )
--         or exists (
--              select 1 from public.game_waitlist gw
--              where gw.game_id = g.id
--                and gw.user_id = auth.uid()
--            )
--         or public.can_view_with_scope(
--              auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
--            )
--       )
--       -- KAN-713: the same predicate on the events fields; intersection, never wider.
--       and (
--         e.creator_user_id = auth.uid()
--         or public.is_admin(auth.uid())
--         or exists (
--              select 1 from public.game_roster gr
--              where gr.game_id = g.id
--                and gr.user_id = auth.uid()
--                and gr.status = 'active'
--            )
--         or exists (
--              select 1 from public.game_waitlist gw
--              where gw.game_id = g.id
--                and gw.user_id = auth.uid()
--            )
--         or public.can_view_with_scope(
--              auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
--            )
--       )
--   );
-- $function$
-- ;
do $kan903$
declare
  c_sig  constant text := 'public._can_view_game(uuid)';
  c_pre  constant text := '7ee01526ff64e59691ada52fa77474ce';
  c_post constant text := '85f265c09711425a66a21c4a595cce62';
  v_oid  oid;
  v_md5  text;
  v_before jsonb;
  v_after  jsonb;
  v_n    bigint;
begin
  v_oid := to_regprocedure(c_sig);
  if v_oid is null then
    raise notice 'KAN-903: % absent; nothing to do', c_sig;
    return;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 = c_post then
    raise notice 'KAN-903: % already reads from events only (md5 %); nothing to do', c_sig, v_md5;
    return;
  end if;
  if v_md5 <> c_pre then
    raise exception 'KAN-903 pre: pre-image drift on % (md5(prosrc) %, expected %); re-author from pg_get_functiondef',
      c_sig, v_md5, c_pre;
  end if;

  select count(*) into v_n
    from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where e.id is null
      or e.creator_user_id is distinct from g.creator_user_id
      or e.listing_visibility is distinct from g.listing_visibility;
  if v_n <> 0 then
    raise exception 'KAN-903 pre: % games row(s) without their game event or differing on creator/visibility', v_n;
  end if;

  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_before from pg_proc p where p.oid = v_oid;

  execute $ddl$
CREATE OR REPLACE FUNCTION public._can_view_game(p_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
    where g.id = p_game_id
      -- KAN-903 (KAN-714): the predicate reads the shared facts from events only.
      and (
        e.creator_user_id = auth.uid()
        or public.is_admin(auth.uid())
        or exists (
             select 1 from public.game_roster gr
             where gr.game_id = g.id
               and gr.user_id = auth.uid()
               and gr.status = 'active'
           )
        or exists (
             select 1 from public.game_waitlist gw
             where gw.game_id = g.id
               and gw.user_id = auth.uid()
           )
        or public.can_view_with_scope(
             auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
           )
      )
  );
$function$
$ddl$;

  if to_regprocedure(c_sig) is distinct from v_oid then
    raise exception 'KAN-903 post: % is not the same oid after CREATE OR REPLACE', c_sig;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> c_post then
    raise exception 'KAN-903 post: % body md5 %, expected %', c_sig, v_md5, c_post;
  end if;
  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_after from pg_proc p where p.oid = v_oid;
  if v_after is distinct from v_before then
    raise exception 'KAN-903 post: % attributes changed: % -> %', c_sig, v_before, v_after;
  end if;
  if exists (select 1 from pg_proc p where p.oid = v_oid and p.prosrc ~* '\mg\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M') then
    raise exception 'KAN-903 post: % still reads a KAN-866 games column', c_sig;
  end if;
end
$kan903$;

-- KAN-913 (KAN-714 W, Epic KAN-708): move the reads of public.rpc_cancel_game_kan712_inner(uuid,text) off the 22
-- public.games columns that KAN-866 will drop, onto public.events. Writes do not move.
--
-- THE 22 COLUMNS: creator_profile_id, creator_user_id, title, start_at, end_at, capacity, listing_visibility,
-- join_policy, is_cancelled, cancelled_at, cancelled_reason, sport_id, area_id, geo_location_id, venue_id, min_skill,
-- max_skill, joining_rule, cost_cover, request_id, created_at, updated_at.
--
-- RE-AUTHORED 2026-11-12 FROM THE LIVE CATALOGUE (T-058). The first version of this file assumed the inner was the
-- KAN-810 post-image (idempotent repeat cancel, md5(prosrc) f5b4c52d331cc03f6d6a7ae806cd3f36). It is not:
-- pg_get_functiondef on wtncuzcskpigqpmnxwws gives the pre-KAN-810 body (md5(prosrc) 0b5bd8bbda5cfac206e75b262503c0cf,
-- md5(pg_get_functiondef) e12056fd977b7305f8318e60a49b6f1b):
--   UPDATE public.games SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
--    WHERE id = p_game_id AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()));
--   IF NOT FOUND THEN RAISE ... 'not_host_or_not_found'; RETURN 'cancelled';
-- Its only read of the 22 is creator_user_id in the WHERE. The live original_acl recorded in kan712_wrapped_rpcs also
-- carries PUBLIC (=X/postgres), which the first version's guard rejected.
--
-- TWO KNOWN PRE-IMAGES, ONE RULE. Behaviour is kept exactly; only the host predicate moves to the parent row:
--   A. live body 0b5bd8bb...      -> post A 077ac3f080df0f4678a8cd58d90e4da8 (non-idempotent, as live is today)
--   B. KAN-810 body f5b4c52d...   -> post B 39f496234ef7fd35295ab0ab4740f703 (idempotent; the local tracked chain)
--   Already at post A or post B   -> notice, nothing done.  Anything else -> exception (re-author).
-- In both, the UPDATE target public.games and its SET list are unchanged; the WHERE keeps id = p_game_id and reads the
-- predicate as  event_id IN (SELECT e.id FROM public.events e WHERE e.event_type = 'game' AND (e.creator_user_id =
-- auth.uid() OR public.is_admin(auth.uid())) [AND e.is_cancelled IS NOT TRUE]). events.id is the primary key and every
-- game has its parent with the same creator_user_id / is_cancelled (KAN-711 parity; the guard refuses otherwise), so the
-- same row is updated or none, exactly as before.
--
-- HOW. CREATE OR REPLACE of the inner only (as KAN-912 / KAN-917): it keeps oid, owner, ACL ({postgres=X/postgres},
-- owner-only), SECURITY DEFINER, SET search_path TO 'public', VOLATILE, the signature and the default. The public
-- wrapper rpc_cancel_game (events row FOR UPDATE, kan712.contract, call to the inner; reads no games column) and the
-- kan712_wrapped_rpcs row are not touched. No DROP, no CASCADE, no GRANT/REVOKE, no row touched.
-- No BEGIN/COMMIT: the Supabase CLI runs each migration in one transaction.
--
-- Live proof: supabase/tests/events_p4/kan714_w_rpc_cancel_game_kan712_inner_live_test.sql (runs in BEGIN ... ROLLBACK).
--
-- ROLLBACK (path A, live). Run uncommented, in one transaction, as postgres:
-- CREATE OR REPLACE FUNCTION public.rpc_cancel_game_kan712_inner(p_game_id uuid, p_reason text DEFAULT NULL::text)
--  RETURNS text
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- BEGIN
--   UPDATE public.games
--   SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
--   WHERE id = p_game_id
--     AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()));
--   IF NOT FOUND THEN
--     RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
--   END IF;
--   RETURN 'cancelled';
-- END$function$;
-- (Path B rollback: the 2b body of 20261104112000_kan810_cancel_game_idempotent.sql, through CREATE OR REPLACE.)

do $kan913$
declare
  c_sig    constant text := 'public.rpc_cancel_game_kan712_inner(uuid,text)';
  c_pre_a  constant text := '0b5bd8bbda5cfac206e75b262503c0cf';
  c_post_a constant text := '077ac3f080df0f4678a8cd58d90e4da8';
  c_pre_b  constant text := 'f5b4c52d331cc03f6d6a7ae806cd3f36';
  c_post_b constant text := '39f496234ef7fd35295ab0ab4740f703';
  v_oid  oid;
  v_md5  text;
  v_want text;
  v_n    bigint;
  v_src  text;
  v_before jsonb;
  v_after  jsonb;
begin
  v_oid := to_regprocedure(c_sig);
  if v_oid is null then
    raise notice 'KAN-913: rpc_cancel_game_kan712_inner absent; nothing to convert';
    return;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 in (c_post_a, c_post_b) then
    raise notice 'KAN-913: inner already converted (md5(prosrc) %); nothing to do', v_md5;
    return;
  end if;
  if v_md5 not in (c_pre_a, c_pre_b) then
    raise exception 'KAN-913 pre: pre-image drift on % (md5(prosrc) is %, expected % or %); re-author from pg_get_functiondef',
      c_sig, v_md5, c_pre_a, c_pre_b;
  end if;

  -- Semantics hold only while every game has its parent and both agree on the predicate columns.
  select count(*) into v_n
    from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where e.id is null or e.creator_user_id is distinct from g.creator_user_id
      or e.is_cancelled is distinct from g.is_cancelled;
  if v_n <> 0 then
    raise exception 'KAN-913 pre: % games row(s) without their game event or differing on creator_user_id / is_cancelled', v_n;
  end if;

  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_before from pg_proc p where p.oid = v_oid;

  if v_md5 = c_pre_a then
    v_want := c_post_a;
    execute $ddl$
CREATE OR REPLACE FUNCTION public.rpc_cancel_game_kan712_inner(p_game_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.games
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_game_id
    AND event_id IN (SELECT e.id FROM public.events e   -- KAN-913: host predicate read from the parent
                      WHERE e.event_type = 'game'
                        AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid())));
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'cancelled';
END$function$
$ddl$;
  else
    v_want := c_post_b;
    execute $ddl$
CREATE OR REPLACE FUNCTION public.rpc_cancel_game_kan712_inner(p_game_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.games
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_game_id
    AND event_id IN (SELECT e.id FROM public.events e   -- KAN-913: host / cancel predicate read from the parent
                      WHERE e.event_type = 'game'
                        AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
                        AND e.is_cancelled IS NOT TRUE);   -- KAN-810: a repeat cancel keeps the first cancel's cancelled_at / reason
  IF NOT FOUND THEN
    -- KAN-810: already cancelled, and the caller may cancel it: same result as before, nothing rewritten.
    IF EXISTS (SELECT 1 FROM public.games g
                 JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-913
                WHERE g.id = p_game_id
                  AND e.is_cancelled IS TRUE
                  AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))) THEN
      RETURN 'cancelled';
    END IF;
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'cancelled';
END$function$
$ddl$;
  end if;

  -- Post-conditions: same oid, the authored body, unchanged attributes, no read of the 22 left on games.
  if to_regprocedure(c_sig) is distinct from v_oid then
    raise exception 'KAN-913 post: % is not the same function oid after CREATE OR REPLACE', c_sig;
  end if;
  select prosrc, md5(prosrc) into v_src, v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> v_want then
    raise exception 'KAN-913 post: % body md5 is %, expected %', c_sig, v_md5, v_want;
  end if;
  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_after from pg_proc p where p.oid = v_oid;
  if v_after is distinct from v_before then
    raise exception 'KAN-913 post: % attributes changed: % -> %', c_sig, v_before, v_after;
  end if;
  -- No g. / games. qualified read, and outside the unchanged SET list no bare mention (every remaining one is e.<col>).
  if v_src ~* '(\mg|\mgames)\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'
     or regexp_replace(replace(v_src, 'SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason', ''),
                       '--[^\n]*', '', 'g')
        ~* '(^|[^.a-z0-9_])(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M' then
    raise exception 'KAN-913 post: % still reads a KAN-866 games column', c_sig;
  end if;
end
$kan913$;

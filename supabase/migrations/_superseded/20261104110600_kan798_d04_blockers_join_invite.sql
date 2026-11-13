-- KAN-798 (KAN-718 D04 blockers 16, 17, 26; Epic KAN-708): rpc_decide_join_request, rpc_invite_user and
-- rpc_mint_join_link read the host from public.events instead of games.creator_user_id, which KAN-719 Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql, seq 603) removes.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan798_d04_join_invite.sql (before/after equality, events-follows probe,
-- catalogue and grant equality, Z01-removed-column scan). Disposition rows: KAN718_D04_DISPOSITION.md 16, 17, 26.
--
-- No DROP, no table/column/grant/policy change, no row written, no write path changed, no new behaviour. Three
-- function bodies are replaced in place (CREATE OR REPLACE, same signature, so oid, owner and ACL are kept;
-- asserted in section 3). The ONLY change in each body is the host read:
--
--   function                                    was                                   now
--   rpc_decide_join_request(uuid,boolean)       SELECT jr.*, g.creator_user_id         SELECT jr.*, e.creator_user_id
--                                               ... JOIN games g ... FOR UPDATE        ... JOIN games g JOIN events e ...
--                                                                                      FOR UPDATE OF jr, g
--   rpc_invite_user(uuid,uuid)                  EXISTS (games g ... g.creator_user_id)  EXISTS (games g JOIN events e ...
--   rpc_mint_join_link(uuid,timestamptz,int)    EXISTS (games g ... g.creator_user_id)    e.creator_user_id)
--
-- The parent is read as `public.events e ON e.id = g.event_id AND e.event_type = 'game'` (the KAN-772 pattern,
-- 20261104110100 _user_hosted_game). INNER join: games.event_id is NOT NULL + FK-validated since the KAN-712
-- cutover and events.id is the PK, so the join neither drops nor doubles a game row (section 0 also refuses on
-- any game without a 'game' events parent). The record field in rpc_decide_join_request keeps the name
-- creator_user_id, so the rest of that body is byte-identical. The lock set is unchanged: the pre-image's bare
-- FOR UPDATE locked game_join_requests and games; FOR UPDATE OF jr, g locks exactly those two and does NOT newly
-- lock events (KAN-712 lock order: subtype row, then events through the guard trigger, is untouched).
--
-- All three are SECURITY DEFINER, owner postgres. public.events is FORCE RLS with no client grant (KAN-710), so a
-- direct events read is correct ONLY because the owner bypasses RLS; section 0 refuses unless the owner is a
-- superuser or BYPASSRLS. No has_table_privilege() fallback is needed (that pattern is for INVOKER functions
-- granted to clients, KAN-727 / KAN-772); the same holds for KAN-772's DEFINER conversions.
--
-- Z01 ORDER: works BEFORE Z01 (games.creator_user_id present) and AFTER Z01 (column gone). The equality refusal in
-- section 0 is dynamic SQL and runs only while games.creator_user_id exists; the orphan refusal runs always.
--
-- KAN-714 PART 2 INTERACTION: 20261105110000_kan714_events_parent_reads_2.sql (authored, not applied) also
-- replaces these three and pins the SAME pre-image md5s as below. Once this file is applied, part 2's drift pin
-- for them refuses (fails closed). The two are alternative conversions of the same three bodies; the sequencing
-- decision is not this file's.
--
-- T-058 SUBSTITUTE (as KAN-772): production is not read here. Section 0 pins md5(prosrc), SECURITY, volatility
-- and proconfig of each pre-image. The pins were measured on the local chain from the baseline bodies installed
-- verbatim (20260829080500:12064-12147, 13367-13391, 14053-14074; no later migration in this tree is applied
-- before this file that redefines them) and equal the pins KAN-714 part 2 measured independently. Any drift fails
-- closed: re-author from pg_get_functiondef on the live catalogue in that case.

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
    raise exception 'KAN-798 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  if to_regclass('public.events') is null then
    raise exception 'KAN-798 pre: public.events missing (KAN-710 not applied)';
  end if;
  if not exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'event_id'
                  and attnum > 0 and not attisdropped) then
    raise exception 'KAN-798 pre: public.games.event_id missing (KAN-711 not applied)';
  end if;
  if to_regclass('public.kan712_wrapped_rpcs') is not null and exists (
       select 1 from public.kan712_wrapped_rpcs w
        where w.name in ('rpc_decide_join_request', 'rpc_invite_user', 'rpc_mint_join_link')) then
    raise exception 'KAN-798 pre: a target function is on the KAN-712 wrap list; re-triage';
  end if;

  -- Pre-image pins: md5(prosrc) | SECURITY DEFINER | volatility | proconfig | owner bypasses RLS
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text
                    || '|' || p.proconfig::text || '|' || (r.rolsuper or r.rolbypassrls)::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public.rpc_decide_join_request(uuid,boolean)', '7c03f9298eb4754f9a281e3620af7f93'),
      ('public.rpc_invite_user(uuid,uuid)', 'f090ca17e10a837091f19c1e0597f164'),
      ('public.rpc_mint_join_link(uuid,timestamp with time zone,integer)', '6ffbb7cdf8421eef95f4060659084bbe')
    ) as t(f, pin)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
    left join pg_roles r on r.oid = p.proowner
   where p.oid is null
      or md5(p.prosrc) <> t.pin
      or not p.prosecdef
      or p.provolatile <> 'v'
      or p.proconfig is distinct from array['search_path=public']
      or not (r.rolsuper or r.rolbypassrls);
  if v_bad is not null then
    raise exception 'KAN-798 pre: pre-image absent or drifted (re-author from pg_get_functiondef on the live catalogue): %', v_bad;
  end if;

  -- Every game has exactly its 'game' events parent (the INNER join must not drop a row).
  select count(*) into v_n
    from public.games g
    left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where e.id is null;
  if v_n > 0 then
    raise exception 'KAN-798 pre: % games row(s) without a ''game'' events parent; reconcile first', v_n;
  end if;

  -- While the legacy column exists, the host it holds must equal the events host (applying cannot change a result).
  if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'creator_user_id'
              and attnum > 0 and not attisdropped) then
    execute $q$select count(*) from public.games g
                 join public.events e on e.id = g.event_id and e.event_type = 'game'
                where e.creator_user_id is distinct from g.creator_user_id$q$ into v_n;
    if v_n > 0 then
      raise exception 'KAN-798 pre: % games row(s) whose creator_user_id differs from events.creator_user_id; reconcile first', v_n;
    end if;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Capture what must not change.
-- ---------------------------------------------------------------------------------------------------------
create temp table kan798_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, p.proargtypes::text as argtypes, p.prorettype, p.prosecdef,
       p.provolatile, p.proconfig, p.proacl, p.proowner, p.proretset, p.proisstrict, p.proparallel,
       p.pronargdefaults, pg_get_function_arguments(p.oid) as args, pg_get_function_result(p.oid) as res
  from pg_proc p
 where p.oid in ('public.rpc_decide_join_request(uuid,boolean)'::regprocedure,
                 'public.rpc_invite_user(uuid,uuid)'::regprocedure,
                 'public.rpc_mint_join_link(uuid,timestamp with time zone,integer)'::regprocedure);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Replacements. Header identical to the pre-image; body changed only at the host read.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_decide_join_request(p_request_id uuid, p_approve boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
DECLARE
  req   record;
  slots int;
BEGIN
  -- KAN-798: host from events; the lock set stays the pre-image's (request row and games row).
  SELECT jr.*, e.creator_user_id
  INTO req
  FROM public.game_join_requests jr
  JOIN public.games g ON g.id = jr.game_id
  JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
  WHERE jr.id = p_request_id
  FOR UPDATE OF jr, g;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='request_not_found';
  END IF;

  IF req.creator_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  IF req.status <> 'pending' THEN RETURN 'already_decided'; END IF;

  IF p_approve THEN
    slots := public.game_slots_left(req.game_id);

    UPDATE public.game_join_requests
       SET status = 'approved', decided_at = now()
     WHERE id = p_request_id;

    IF slots > 0 THEN
      INSERT INTO public.game_roster(game_id, profile_id, role, status)
      VALUES (req.game_id, req.from_profile_id, 'player', 'active')
      ON CONFLICT (game_id, profile_id) DO UPDATE
        SET status = 'active', left_at = null;

      -- Notify the requester (entity_type 'game' also yields the
      -- /sports/games/<id> deep link). Never let notification failure
      -- roll back the approval itself.
      BEGIN
        PERFORM public.process_notification_event(
          req.from_user_id,
          'game.join_accepted',
          'game',
          req.game_id,
          auth.uid(),
          'You''re in! Your request to join was accepted'
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'join_accepted notification failed: %', SQLERRM;
      END;

      RETURN 'approved_joined';
    ELSE
      INSERT INTO public.game_waitlist(game_id, profile_id, user_id, position)
      SELECT req.game_id, req.from_profile_id, req.from_user_id,
             COALESCE((SELECT MAX(position)+1 FROM public.game_waitlist WHERE game_id = req.game_id), 1)
      ON CONFLICT DO NOTHING;

      BEGIN
        PERFORM public.process_notification_event(
          req.from_user_id,
          'game.join_accepted',
          'game',
          req.game_id,
          auth.uid(),
          'Request approved — the game is full, you''re on the waitlist'
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'join_accepted (waitlist) notification failed: %', SQLERRM;
      END;

      RETURN 'approved_waitlisted';
    END IF;
  ELSE
    UPDATE public.game_join_requests
       SET status = 'denied', decided_at = now()
     WHERE id = p_request_id;
    RETURN 'denied';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_invite_user(p_game_id uuid, p_to_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
DECLARE gid uuid;
BEGIN
  -- KAN-798: host from events.
  IF NOT EXISTS (
    SELECT 1 FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    WHERE g.id = p_game_id
      AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  INSERT INTO public.game_invites(game_id, to_user_id, invited_by_profile_id, status)
  VALUES (
    p_game_id,
    p_to_user_id,
    (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND profile_type = 'organiser' LIMIT 1),
    'pending'
  )
  RETURNING id INTO gid;

  RETURN gid;
END$$;

CREATE OR REPLACE FUNCTION public.rpc_mint_join_link(p_game_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_uses integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
DECLARE t uuid;
BEGIN
  -- KAN-798: host from events.
  IF NOT EXISTS (
    SELECT 1 FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    WHERE g.id = p_game_id
      AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  t := gen_random_uuid();

  INSERT INTO public.game_link_tokens(game_id, token, created_by, expires_at, max_uses)
  VALUES (p_game_id, t, auth.uid(), p_expires_at, p_max_uses);

  RETURN t;
END;
$$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions: same object, same attributes, same ACL; the body reads events and no longer the column.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
begin
  if (select count(*) from kan798_pre) <> 3 then
    raise exception 'KAN-798 post: captured % pre-image rows, expected 3', (select count(*) from kan798_pre);
  end if;
  select string_agg(b.fn, ', ') into v_bad
    from kan798_pre b
    left join pg_proc p on p.oid = b.oid
   where p.oid is null
      or p.proargtypes::text <> b.argtypes
      or p.prorettype <> b.prorettype
      or p.prosecdef <> b.prosecdef
      or p.provolatile <> b.provolatile
      or p.proconfig is distinct from b.proconfig
      or p.proacl is distinct from b.proacl
      or p.proowner <> b.proowner
      or p.proretset <> b.proretset
      or p.proisstrict <> b.proisstrict
      or p.proparallel <> b.proparallel
      or p.pronargdefaults <> b.pronargdefaults
      or pg_get_function_arguments(p.oid) <> b.args
      or pg_get_function_result(p.oid) <> b.res;
  if v_bad is not null then
    raise exception 'KAN-798 post: signature/attribute/ACL/owner changed for: %', v_bad;
  end if;

  select string_agg(b.fn, ', ') into v_bad
    from kan798_pre b
    join pg_proc p on p.oid = b.oid
   where p.prosrc !~ 'JOIN public\.events e ON e\.id = g\.event_id AND e\.event_type = ''game'''
      or p.prosrc !~ 'e\.creator_user_id'
      or p.prosrc ~ 'g\.creator_user_id';
  if v_bad is not null then
    raise exception 'KAN-798 post: body does not read the host from events (or still names g.creator_user_id): %', v_bad;
  end if;
end
$post$;

commit;

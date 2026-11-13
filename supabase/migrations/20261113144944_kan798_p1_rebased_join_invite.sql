-- KAN-798 rebased on live (KAN-862 package P1, backend-1; Epic KAN-708). Supersedes
-- supabase/migrations/_superseded/20261104110600_kan798_d04_blockers_join_invite.sql (authored, never applied).
--
-- WHAT: rpc_decide_join_request, rpc_invite_user and rpc_mint_join_link read the host from public.events
--   (games.event_id) instead of games.creator_user_id. rpc_decide_join_request locks FOR UPDATE OF jr, g (same lock set).
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058), wtncuzcskpigqpmnxwws, 2026-11-13: pg_get_functiondef of each target.
-- Each live md5(prosrc) was compared with the superseded file's pre-image pin; the body change is that file's
-- intent and nothing else. Live pre-image -> post-image md5(prosrc):
--   public.rpc_decide_join_request(uuid,boolean)  7c03f9298eb4754f9a281e3620af7f93 -> 2fcf8e73dedc9917abce87d4b5ac30e6
--   public.rpc_invite_user(uuid,uuid)  f090ca17e10a837091f19c1e0597f164 -> 265a120631a1ea3885d7c4f2f2527c32
--   public.rpc_mint_join_link(uuid,timestamp with time zone,integer)  6ffbb7cdf8421eef95f4060659084bbe -> d6f6d1f5ea0e1205432378795ea5b369
--
-- HOW: CREATE OR REPLACE with the same signature keeps oid, owner, ACL, SECURITY, volatility and search_path; the
-- post block asserts them, and every trigger definition on them, unchanged. Definitions only: no row is written and
-- no column, table, policy or existing grant changes. Equivalence: the pre block refuses unless every games row has
-- its 'game' events parent and every games column whose read moves equals its events counterpart (KAN-711 parity;
-- checked only while the column exists). Any other live body refuses (re-author from pg_get_functiondef).
-- No BEGIN/COMMIT: apply_migration and the CLI wrap each migration in one transaction.
-- Live test: supabase/tests/events_p4/kan798_p1_live_test.sql (BEGIN ... ROLLBACK, TAP).

do $pre$
declare
  r record; c text; v_n bigint; v_attr jsonb := '{}'::jsonb;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'kan798 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  for r in select * from (values
    ('public.rpc_decide_join_request(uuid,boolean)', '7c03f9298eb4754f9a281e3620af7f93', '2fcf8e73dedc9917abce87d4b5ac30e6'),
    ('public.rpc_invite_user(uuid,uuid)', 'f090ca17e10a837091f19c1e0597f164', '265a120631a1ea3885d7c4f2f2527c32'),
    ('public.rpc_mint_join_link(uuid,timestamp with time zone,integer)', '6ffbb7cdf8421eef95f4060659084bbe', 'd6f6d1f5ea0e1205432378795ea5b369')) t(fn, pin, post) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'kan798 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pin then
      raise exception 'kan798 pre: pre-image drift on % (md5(prosrc) %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pin;
    end if;
    v_attr := v_attr || jsonb_build_object(r.fn, (
      select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
        from pg_proc p where p.oid = to_regprocedure(r.fn)));
  end loop;
  select count(*) into v_n from public.games g
    left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null;
  if v_n > 0 then
    raise exception 'kan798 pre: % games row(s) without a ''game'' events parent', v_n;
  end if;
  foreach c in array array['creator_user_id'] loop
    if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = c and attnum > 0 and not attisdropped) then
      execute format('select count(*) from public.games x join public.events e on e.id = x.event_id and e.event_type = %L
                       where x.%I is distinct from e.%I', 'game', c, c) into v_n;
      if v_n > 0 then
        raise exception 'kan798 pre: % games row(s) differ from events on % (KAN-711 parity)', v_n, c;
      end if;
    end if;
  end loop;
  perform set_config('kan798.attr', v_attr::text, true);
end
$pre$;

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

do $post$
declare
  r record; v_attr jsonb := current_setting('kan798.attr')::jsonb; v_now jsonb;
begin
  for r in select * from (values
    ('public.rpc_decide_join_request(uuid,boolean)', '7c03f9298eb4754f9a281e3620af7f93', '2fcf8e73dedc9917abce87d4b5ac30e6'),
    ('public.rpc_invite_user(uuid,uuid)', 'f090ca17e10a837091f19c1e0597f164', '265a120631a1ea3885d7c4f2f2527c32'),
    ('public.rpc_mint_join_link(uuid,timestamp with time zone,integer)', '6ffbb7cdf8421eef95f4060659084bbe', 'd6f6d1f5ea0e1205432378795ea5b369')) t(fn, pin, post) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post then
      raise exception 'kan798 post: % body md5 %, expected %', r.fn,
        (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.post;
    end if;
    select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'kan798 post: % signature/attributes/owner/ACL/trigger changed: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end
$post$;

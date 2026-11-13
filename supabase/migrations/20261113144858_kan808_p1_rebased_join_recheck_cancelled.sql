-- KAN-808 rebased on live (KAN-862 package P1, backend-1; Epic KAN-708). Supersedes
-- supabase/migrations/_superseded/20261104110700_kan808_join_recheck_cancelled.sql (authored, never applied).
--
-- WHAT: rpc_join_game takes the games row lock before both branches, then re-checks events.is_cancelled and
--   raises P0001 cancelled/cancelled (the refusal a join after a committed cancel already gets). Closes the KAN-761 S5
--   cancel-vs-join race; rpc_cancel_game locks events then updates games, so there is no lock cycle.
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058), wtncuzcskpigqpmnxwws, 2026-11-13: pg_get_functiondef of each target.
-- Each live md5(prosrc) was compared with the superseded file's pre-image pin; the body change is that file's
-- intent and nothing else. Live pre-image -> post-image md5(prosrc):
--   public.rpc_join_game(text,uuid,uuid)  9d1ca06d255364137a456b31980a5c60 -> 639151365d83933d1fce0de84d282990
--
-- HOW: CREATE OR REPLACE with the same signature keeps oid, owner, ACL, SECURITY, volatility and search_path; the
-- post block asserts them, and every trigger definition on them, unchanged. Definitions only: no row is written and
-- no column, table, policy or existing grant changes. Equivalence: the pre block refuses unless every games row has
-- its 'game' events parent and every games column whose read moves equals its events counterpart (KAN-711 parity;
-- checked only while the column exists). Any other live body refuses (re-author from pg_get_functiondef).
-- No BEGIN/COMMIT: apply_migration and the CLI wrap each migration in one transaction.
-- Live test: supabase/tests/events_p4/kan808_p1_live_test.sql (BEGIN ... ROLLBACK, TAP).

do $pre$
declare
  r record; c text; v_n bigint; v_attr jsonb := '{}'::jsonb;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'kan808 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  for r in select * from (values
    ('public.rpc_join_game(text,uuid,uuid)', '9d1ca06d255364137a456b31980a5c60', '639151365d83933d1fce0de84d282990')) t(fn, pin, post) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'kan808 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pin then
      raise exception 'kan808 pre: pre-image drift on % (md5(prosrc) %, expected %); re-author from pg_get_functiondef',
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
    raise exception 'kan808 pre: % games row(s) without a ''game'' events parent', v_n;
  end if;
  foreach c in array array['is_cancelled'] loop
    if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = c and attnum > 0 and not attisdropped) then
      execute format('select count(*) from public.games x join public.events e on e.id = x.event_id and e.event_type = %L
                       where x.%I is distinct from e.%I', 'game', c, c) into v_n;
      if v_n > 0 then
        raise exception 'kan808 pre: % games row(s) differ from events on % (KAN-711 parity)', v_n, c;
      end if;
    end if;
  end loop;
  perform set_config('kan808.attr', v_attr::text, true);
end
$pre$;

CREATE OR REPLACE FUNCTION public.rpc_join_game(p_actor_type text, p_game_id uuid, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS TABLE(result text, roster_status text, waitlist_position integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  decision jsonb;
  pid uuid;
  uid uuid := auth.uid();
  g record;
  slots int;
BEGIN
  decision := public.can_current_user_join_game(p_game_id, p_actor_type, p_link_token);

  IF COALESCE((decision->>'allowed')::boolean, false) = false THEN
    RAISE EXCEPTION USING
      errcode = 'P0001',
      message = COALESCE(decision->>'cta', 'not_allowed'),
      detail  = COALESCE(decision->>'reason', '');
  END IF;

  pid := public.choose_actor(p_actor_type);

  IF (decision->>'cta') = 'join_with_link' THEN
    PERFORM public._consume_link_token(p_game_id, p_link_token);
  END IF;

  -- KAN-808: lock the games row first (both branches), then re-check the cancel a concurrent rpc_cancel_game may
  -- have committed while this call waited; the refusal is the one can_current_user_join_game gives a cancelled game.
  SELECT * INTO g FROM public.games WHERE id = p_game_id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.event_id AND e.event_type = 'game' AND e.is_cancelled) THEN
    RAISE EXCEPTION USING
      errcode = 'P0001',
      message = 'cancelled',
      detail  = 'cancelled';
  END IF;

  IF (decision->>'cta') = 'request' THEN
    INSERT INTO public.game_join_requests(game_id, from_profile_id, status)
    VALUES (p_game_id, pid, 'pending')
    ON CONFLICT DO NOTHING;
    result := 'request_submitted'; roster_status := NULL; waitlist_position := NULL; RETURN NEXT; RETURN;
  END IF;

  slots := public.game_slots_left(p_game_id);

  IF slots > 0 THEN
    INSERT INTO public.game_roster(game_id, profile_id, role, status)
    VALUES (p_game_id, pid, 'player', 'active')
    ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
    result := 'joined'; roster_status := 'active'; waitlist_position := NULL; RETURN NEXT; RETURN;
  ELSE
    INSERT INTO public.game_waitlist(game_id, profile_id, user_id, position)
    SELECT p_game_id, pid, uid,
           COALESCE((SELECT max(position)+1 FROM public.game_waitlist WHERE game_id = p_game_id), 1)
    ON CONFLICT DO NOTHING;
    waitlist_position := (SELECT position FROM public.game_waitlist WHERE game_id=p_game_id AND profile_id=pid);
    result := 'waitlisted'; roster_status := NULL; RETURN NEXT; RETURN;
  END IF;
END;
$function$;

do $post$
declare
  r record; v_attr jsonb := current_setting('kan808.attr')::jsonb; v_now jsonb;
begin
  for r in select * from (values
    ('public.rpc_join_game(text,uuid,uuid)', '9d1ca06d255364137a456b31980a5c60', '639151365d83933d1fce0de84d282990')) t(fn, pin, post) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post then
      raise exception 'kan808 post: % body md5 %, expected %', r.fn,
        (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.post;
    end if;
    select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'kan808 post: % signature/attributes/owner/ACL/trigger changed: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end
$post$;

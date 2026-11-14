-- KAN-945 item 1: joining the waitlist of a link-policy game with a token consumes a use, the same as joining does.
-- Before: rpc_join_game consumed a use only on cta join_with_link. On a full link game the decision is cta waitlist,
-- so one single-use token could waitlist any number of holders, and promotion never re-checks the token.
-- Now: on cta waitlist for a join_policy = 'link' game, rpc_join_game calls _consume_link_token (the same
-- conditional UPDATE, so an exhausted token raises invalid_or_expired_link and nothing is inserted). It runs after
-- the games row lock and the cancel re-check, and is skipped when the caller's actor is already on the waitlist (a
-- repeat call does not spend a second use). Promotion needs no token check: the use was spent at waitlist time.
-- can_current_user_join_game, _consume_link_token and _link_token_valid are unchanged.
-- Re-authored from pg_get_functiondef on the live catalogue. Attributes (SECURITY DEFINER, search_path=public) and
-- the ACL are unchanged (CREATE OR REPLACE keeps the ACL).

DO $guard$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure)
     <> '639151365d83933d1fce0de84d282990' THEN
    RAISE EXCEPTION 'KAN-945 pre-image guard: rpc_join_game changed';
  END IF;
  IF to_regprocedure('public._consume_link_token(uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-945 pre-image guard: _consume_link_token missing';
  END IF;
END
$guard$;

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

  -- KAN-945: a full link-policy game gives cta waitlist; taking a waitlist place with the token spends a use, the same
  -- conditional UPDATE as join_with_link. Not again for an actor already on the waitlist.
  IF (decision->>'cta') = 'waitlist' AND p_link_token IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.event_id AND e.event_type = 'game' AND e.join_policy = 'link')
     AND NOT EXISTS (SELECT 1 FROM public.game_waitlist w WHERE w.game_id = p_game_id AND w.profile_id = pid) THEN
    PERFORM public._consume_link_token(p_game_id, p_link_token);
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

DO $post$
DECLARE r record;
BEGIN
  SELECT p.prosecdef, p.proconfig, p.proowner::regrole::text AS owner, p.proacl::text AS acl,
         position('KAN-945' IN p.prosrc) > 0 AS has_change
    INTO r FROM pg_proc p WHERE p.oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure;
  IF NOT (r.prosecdef AND r.proconfig = ARRAY['search_path=public'] AND r.owner = 'postgres' AND r.has_change
          AND r.acl = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}') THEN
    RAISE EXCEPTION 'KAN-945 post-assert rpc_join_game: %', row_to_json(r);
  END IF;
END
$post$;

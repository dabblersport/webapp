-- KAN-808 (KAN-761 scenario S5, cancel vs join; Jira KAN-761 comment 15170): rpc_join_game re-checks the cancel
-- after it holds the games row lock, on BOTH branches, so a join that races an uncommitted rpc_cancel_game is refused
-- instead of landing on the cancelled game.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof (throwaway PG16, two real authenticated sessions, git-archive build):
--   supabase/tests/events_p4/kan808_join_recheck_cancelled.sh
--
-- DEFECTS (pre-image = baseline 20260829080500:13417-13467, md5(prosrc) 9d1ca06d255364137a456b31980a5c60; no later
-- tracked migration up to this one redefines it):
--   F1 can_current_user_join_game runs BEFORE `SELECT ... FROM games ... FOR UPDATE` and nothing re-checks the cancel
--      once the lock is held. rpc_cancel_game (KAN-712 wrapper: events row FOR UPDATE, then the inner
--      `UPDATE public.games SET is_cancelled = true`) holds the games row until it commits, so a join started inside
--      that window passes the check, waits on the row, then inserts an active roster row on the cancelled game.
--   F2 the join_policy = 'request' branch inserted game_join_requests with no lock at all: a pending request was left
--      on the cancelled game without even waiting.
--
-- CHANGE (exactly this; every other line is the pre-image byte for byte, from pg_get_functiondef):
--   * `SELECT * INTO g FROM public.games WHERE id = p_game_id FOR UPDATE;` moves up, from after the request branch
--     to just before it, so both branches take it (after the link-token consumption, as before);
--   * right after it: IF the game's events row (games.event_id; the shared field lives on events since KAN-712) is
--     cancelled THEN RAISE errcode P0001, message 'cancelled', detail 'cancelled' -- the exact refusal a join made
--     after the cancel commits already gets (can_current_user_join_game returns cta 'cancelled', reason 'cancelled',
--     20261104100000_kan713_access_helpers.sql:276, and rpc_join_game raises cta as message, reason as detail).
--   The raise rolls back the whole call, so a link token consumed before it is not consumed either.
--   Untouched: the eligibility call and its refusals, choose_actor, link consumption, the request insert and result,
--   game_slots_left, the roster/waitlist inserts and results, and the waitlist rule (O1: a full game waitlists even
--   with allows_waitlist = false; kept open per KAN-757 J6.a3).
--
-- LOCK ORDER. rpc_cancel_game takes events (FOR UPDATE) then games (UPDATE). rpc_join_game takes games (FOR UPDATE)
-- and only READS events, without a lock, so there is no cycle and no new deadlock. The read runs in a new statement
-- after the lock is granted (READ COMMITTED), so it sees the cancel the lock waited for.
-- LIMIT: the re-check closes the race only while every cancel also writes the games row in its transaction (today:
-- the inner UPDATE games; an events-only write reaches games through trg_zz_kan712_events_compat_mirror). KAN-719 Z01
-- (20261105100000) drops games.is_cancelled and that mirror; after it a cancel touches only events and this games
-- lock no longer orders a join against it (see the KAN-808 report).
--
-- Signature, RETURNS TABLE shape, LANGUAGE, SECURITY DEFINER, volatility, search_path, owner and proacl are kept
-- (CREATE OR REPLACE, same signature); section 0 captures owner/ACL and section 2 asserts them unchanged.
-- KAN-712: rpc_join_game is not on the wrap list (it writes roster/waitlist/requests, never games); section 0 refuses
-- if it has been wrapped.
--
-- T-058 SUBSTITUTE (as KAN-772/KAN-801): production is not read here. Section 0 pins md5(prosrc) to the reviewed
-- pre-image or this migration's own post-image (re-apply is a no-op); any other body refuses -- re-author from
-- pg_get_functiondef on the live catalogue in that case.
-- KAN-714 part 2 (20261105110000_kan714_events_parent_reads_2.sql:159) pins the pre-image md5 9d1ca06d and refuses
-- ('body drifted') once this is applied. That file is not edited here.
--
-- No DROP, no table/column/grant/policy change, no row written.
--
-- ROLLBACK: re-run the pre-image body, baseline 20260829080500_baseline_schema.sql:13417-13467 (its CREATE OR REPLACE
-- statement; CREATE OR REPLACE keeps the ACL). Pinned by md5 in section 0.

BEGIN;
SET LOCAL lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
DO $pre$
DECLARE p record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-808 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL OR NOT EXISTS (SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'games' AND column_name = 'event_id')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'events' AND column_name = 'is_cancelled') THEN
    RAISE EXCEPTION 'KAN-808 pre: public.events.is_cancelled / games.event_id missing (KAN-710/711 not applied)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_join_game_kan712_inner')
     OR (to_regclass('public.kan712_wrapped_rpcs') IS NOT NULL
         AND EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_join_game')) THEN
    RAISE EXCEPTION 'KAN-808 pre: rpc_join_game is KAN-712-wrapped; use kan712_unwrap_rpc/kan712_wrap_rpc, stop';
  END IF;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_join_game') <> 1
     OR to_regprocedure('public.rpc_join_game(text,uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-808 pre: expected exactly one overload public.rpc_join_game(text,uuid,uuid), stop';
  END IF;
  SELECT * INTO p FROM pg_proc WHERE oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure;
  IF md5(p.prosrc) NOT IN ('9d1ca06d255364137a456b31980a5c60', '639151365d83933d1fce0de84d282990') THEN
    RAISE EXCEPTION 'KAN-808 pre: rpc_join_game drifted from the reviewed pre-image (md5 %), re-author from pg_get_functiondef, stop',
      md5(p.prosrc);
  END IF;
  IF NOT p.prosecdef OR p.provolatile <> 'v' OR p.proconfig::text IS DISTINCT FROM '{search_path=public}'
     OR pg_get_function_result(p.oid) <> 'TABLE(result text, roster_status text, waitlist_position integer)' THEN
    RAISE EXCEPTION 'KAN-808 pre: rpc_join_game attributes drifted (secdef=% vol=% config=% ret=%), stop',
      p.prosecdef, p.provolatile, p.proconfig, pg_get_function_result(p.oid);
  END IF;
END $pre$;

CREATE TEMP TABLE k808_acl ON COMMIT DROP AS
  SELECT oid, proacl::text AS acl, proowner, pg_get_function_identity_arguments(oid) AS args, prolang
    FROM pg_proc WHERE oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Body (pg_get_functiondef of the pre-image; the change is marked KAN-808 and described in the header).
-- ---------------------------------------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------------------------------------
-- 2. Post-conditions.
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE p record; v_lock int; v_check int; v_req int;
BEGIN
  SELECT * INTO p FROM pg_proc WHERE oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure;
  IF md5(p.prosrc) <> '639151365d83933d1fce0de84d282990' THEN
    RAISE EXCEPTION 'KAN-808 post: rpc_join_game body md5 %', md5(p.prosrc);
  END IF;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_join_game') <> 1 THEN
    RAISE EXCEPTION 'KAN-808 post: rpc_join_game overload count changed';
  END IF;
  IF NOT p.prosecdef OR p.provolatile <> 'v' OR p.proconfig::text IS DISTINCT FROM '{search_path=public}'
     OR pg_get_function_result(p.oid) <> 'TABLE(result text, roster_status text, waitlist_position integer)' THEN
    RAISE EXCEPTION 'KAN-808 post: rpc_join_game attributes changed (secdef=% vol=% config=% ret=%)', p.prosecdef, p.provolatile,
      p.proconfig, pg_get_function_result(p.oid);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM k808_acl a WHERE a.oid = p.oid AND a.acl IS NOT DISTINCT FROM p.proacl::text
                   AND a.proowner = p.proowner AND a.prolang = p.prolang
                   AND a.args = pg_get_function_identity_arguments(p.oid)) THEN
    RAISE EXCEPTION 'KAN-808 post: rpc_join_game owner/ACL/signature changed (now owner % acl %)', p.proowner::regrole, p.proacl;
  END IF;
  -- shape: one games lock, then the cancel re-check, then the request branch
  v_lock  := strpos(p.prosrc, 'SELECT * INTO g FROM public.games WHERE id = p_game_id FOR UPDATE;');
  v_check := strpos(p.prosrc, 'e.is_cancelled) THEN');
  v_req   := strpos(p.prosrc, 'IF (decision->>''cta'') = ''request'' THEN');
  IF NOT (v_lock > 0 AND v_lock < v_check AND v_check < v_req)
     OR (length(p.prosrc) - length(replace(p.prosrc, 'FOR UPDATE', ''))) / length('FOR UPDATE') <> 1 THEN
    RAISE EXCEPTION 'KAN-808 post: rpc_join_game lock / re-check / request order not as reviewed';
  END IF;
END $post$;

COMMIT;

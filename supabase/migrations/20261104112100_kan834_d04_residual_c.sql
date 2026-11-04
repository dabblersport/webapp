-- KAN-834 (KAN-807 leftovers; supporting KAN-778 / KAN-719): D04 residual, part (c). These four functions still read
-- games columns that KAN-719 Z01 (20261105100000_kan719_z01_remove_replaced_columns.sql) drops, so after Z01 they raise
-- 42703. Each body now reads those fields only from public.events (games.event_id -> events.id). Same pattern as
-- KAN-807 parts (a) and (b) (20261104110900 / 20261104111000); none of these four is in either of them.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan834_d04_residual_c_test.sql (throwaway PG16, KAN-808 chain + Z01).
--
--   function                                              removed read                       now read
--   public.can_current_user_join_game(uuid, text, uuid)  g.creator_user_id, g.listing_visibility, g.is_cancelled, g.start_at, g.join_policy
--                                                         (every games half of the KAN-713 intersection)   e.* halves only
--   public._recent_activity_score(uuid, integer)         g.start_at (INVOKER fallback)      e.start_at
--   public._user_hosted_game(uuid, uuid)                 g.creator_user_id (INVOKER fallback) e.creator_user_id
--   public.game_is_joinable(uuid)                        g.is_cancelled, g.start_at (INVOKER fallback) e.is_cancelled, e.start_at
--
-- WHY THIS IS NOT A MECHANICAL READ SWAP. All four are SECURITY INVOKER and EXECUTE is granted to anon and
-- authenticated, while public.events has FORCE RLS and no client grant. Simply reading events would make every
-- client call raise 42501. That is why the D04 bodies kept a has_table_privilege('public.events','SELECT') switch
-- with a games-only fallback (Z05 lists them as "fallback kept").
--
-- WHY THE RESULT IS UNCHANGED.
--   Events branch (postgres, service_role, SECURITY DEFINER callers rpc_join_game / rpc_rate_venue): every removed
--   read was one half of an intersection, or an equal alternative, whose other half reads the same field from
--   events. Section 0 refuses unless those games columns equal their events counterparts on every row (KAN-711
--   parity, D09), so dropping the games half gives the same answer. The same holds for the KAN-713 policy_mismatch
--   check (e.join_policy IS DISTINCT FROM g.join_policy): parity makes it unreachable, and Z01 drops g.join_policy.
--   Fallback branch (anon, authenticated): public.games has RLS enabled and NO policy, so a client caller sees no
--   games row at all. The old fallback could therefore only ever return its no-row answer: false, NULL, 0.0 and
--   'not_found'. The new fallback keeps exactly that gate. It reads games through RLS using only retained columns
--   (id, event_id), and on no visible row it returns the same no-row answer without reading a slated column. If a
--   games row ever becomes visible to a caller that cannot read events (only possible after someone adds a games
--   policy), the body goes on to the events read and raises 42501. That fails closed and loudly. It never guesses.
--   Section 0 refuses unless games still has RLS on and no policy, the premise of this argument.
--
-- Replaced in place (CREATE OR REPLACE, same signature, same return type): SECURITY INVOKER, STABLE, search_path,
-- owner and ACL are kept and asserted in section 2. No table, column, policy, trigger, grant or row is touched.
-- Bodies authored from pg_get_functiondef of the KAN-808 local chain (T-058). Every unchanged line is byte-identical.
--
-- KNOWN, UNCHANGED (not this ticket): KAN-713 E-2. The 'invite' arm reads game_invites.to_profile_id, which does
-- not exist, and raises 42703. It is kept byte-for-byte; fixing it would change behaviour. The 'circle', 'squad' and
-- 'closed' arms are unreachable from events (events_game_join_policy_check allows open/request/invite/link only),
-- but they are kept. Only the circle arm's g.creator_user_id changes, to e.creator_user_id. game_slots_left
-- (called at the end) is NOT touched; its INVOKER fallback still reads g.capacity after Z01. It is not reached by a
-- client caller, because the games gate returns not_found first.
--
-- T-058 SUBSTITUTE: production is not read here. Section 0 pins md5(prosrc) of each pre-image; any other value
-- fails closed, so re-author from pg_get_functiondef on the live catalogue then. The authored post-image md5 is also
-- accepted, so a re-apply is a verified no-op (idempotent). Section 2 pins md5(prosrc) of each new body.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  r record;
  c record;
  v_n bigint;
  v_md5 text;
  v_attr jsonb := '{}'::jsonb;
begin
  if to_regclass('public.events') is null then
    raise exception 'KAN-834 pre: public.events missing (KAN-710 not applied)';
  end if;
  for r in select * from (values
    ('public.can_current_user_join_game(uuid, text, uuid)', 'c26ddc863eb05995224c7edb6e57f956', 'dec4ccbbeaac92e7e5ff23e6806cdb30'),
    ('public._recent_activity_score(uuid, integer)', '6cec16401372d08e38d17e74d68ec322', '2202f744a38453ddb883089c274dd2e1'),
    ('public._user_hosted_game(uuid, uuid)', '41a0f3b192055a68f7dbaea2807c9933', '792f07c44f71c4dc154716a5905b0659'),
    ('public.game_is_joinable(uuid)', 'a7245a8bc76da50e56cb011fca0f4797', '7075cd9e1f42e083960708f11bf7d0f1')) k(fn, pre_md5, post_md5) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'KAN-834 pre: % is absent', r.fn;
    end if;
    select count(*) into v_n from pg_proc
     where pronamespace = 'public'::regnamespace and proname = (select proname from pg_proc where oid = to_regprocedure(r.fn));
    if v_n <> 1 then
      raise exception 'KAN-834 pre: % has % overloads, expected exactly 1', r.fn, v_n;
    end if;
    select md5(prosrc) into v_md5 from pg_proc where oid = to_regprocedure(r.fn);
    if v_md5 not in (r.pre_md5, r.post_md5) then
      raise exception 'KAN-834 pre: pre-image drift on % (md5(prosrc) is %, expected % or the authored %); re-author from pg_get_functiondef',
        r.fn, v_md5, r.pre_md5, r.post_md5;
    end if;
    if (select prosecdef from pg_proc where oid = to_regprocedure(r.fn)) then
      raise exception 'KAN-834 pre: % is SECURITY DEFINER; this rewrite is argued for SECURITY INVOKER only', r.fn;
    end if;
    v_attr := v_attr || jsonb_build_object(r.fn, (
      select jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef,
               p.provolatile, p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset)
        from pg_proc p where p.oid = to_regprocedure(r.fn)));
  end loop;
  -- The fallback argument's premise: a caller without events access sees no games row.
  if not (select relrowsecurity from pg_class where oid = 'public.games'::regclass) then
    raise exception 'KAN-834 pre: public.games no longer has RLS enabled; the INVOKER fallback argument does not hold';
  end if;
  select count(*) into v_n from pg_policy where polrelid = 'public.games'::regclass;
  if v_n <> 0 then
    raise exception 'KAN-834 pre: public.games has % policy(ies); a client could see a games row, so the fallback no longer returns only its no-row answer -- re-decide', v_n;
  end if;
  -- KAN-711 parity on every column whose read is removed. Checked only where the column still exists, so the
  -- migration is also safe to re-check after Z01 (it then has nothing to compare).
  for c in select * from (values ('creator_user_id'), ('listing_visibility'), ('is_cancelled'), ('start_at'),
                                 ('join_policy')) v(col) loop
    if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = c.col and not attisdropped) then
      execute format('select count(*) from public.games x left join public.events e on e.id = x.event_id and e.event_type = %L
                       where e.id is null or x.%I is distinct from e.%I', 'game', c.col, c.col) into v_n;
      if v_n <> 0 then
        raise exception 'KAN-834 pre: % row(s) of public.games lack their typed events parent or differ on % (KAN-711 parity)', v_n, c.col;
      end if;
    end if;
  end loop;
  perform set_config('kan834.c_attr', v_attr::text, true);
end $pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Bodies.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.can_current_user_join_game(p_game_id uuid, p_actor_type text DEFAULT 'player'::text, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.games%rowtype; viewer uuid := auth.uid(); actor_id uuid;
  slots int; visible boolean; cta text;
  e public.events%rowtype;
BEGIN
  IF viewer IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'anon'); END IF;
  IF public.is_frozen(viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'frozen'); END IF;
  actor_id := public.choose_actor(p_actor_type);
  IF NOT public.actor_is_player(actor_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'actor_not_player'); END IF;
  -- KAN-834: games is read for its retained columns only (event_id, squad_id), through RLS. games has no policy, so
  -- a caller without events access (INVOKER client) stops here with not_found, as before. Every shared field is
  -- read from events; a caller that sees a games row but cannot read events raises 42501 below (fail closed).
  SELECT * INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  SELECT * INTO e FROM public.events WHERE id = g.event_id AND event_type = 'game';
  IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  IF e.creator_user_id = viewer THEN RETURN jsonb_build_object('allowed', false, 'cta', 'host', 'reason', 'host'); END IF;
  visible := public.can_view_with_scope(viewer, e.creator_user_id, e.listing_visibility, g.squad_id);
  IF NOT visible THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_visible', 'reason', 'visibility_denied'); END IF;
  IF e.is_cancelled THEN RETURN jsonb_build_object('allowed', false, 'cta', 'cancelled', 'reason', 'cancelled'); END IF;
  IF e.start_at <= now() THEN RETURN jsonb_build_object('allowed', false, 'cta', 'started', 'reason', 'started'); END IF;
  IF EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.status = 'active' AND (r.user_id = viewer OR r.profile_id = actor_id)) THEN
    RETURN jsonb_build_object('allowed', false, 'cta', 'joined', 'reason', 'already');
  END IF;
  CASE e.join_policy
    WHEN 'open' THEN cta := 'join';
    WHEN 'request' THEN
      IF EXISTS (SELECT 1 FROM public.game_join_requests q WHERE q.game_id = p_game_id AND q.status = 'pending' AND (q.from_user_id = viewer OR q.from_profile_id = actor_id)) THEN
        RETURN jsonb_build_object('allowed', false, 'cta', 'requested', 'reason', 'pending_request');
      END IF;
      cta := 'request';
    WHEN 'invite' THEN
      IF EXISTS (SELECT 1 FROM public.game_invites i WHERE i.game_id = p_game_id AND i.status = 'pending' AND (i.to_user_id = viewer OR i.to_profile_id = actor_id)) THEN
        cta := 'accept_invite';
      ELSE
        RETURN jsonb_build_object('allowed', false, 'cta', 'invite_only', 'reason', 'invite_required');
      END IF;
    WHEN 'link' THEN
      IF p_link_token IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_required', 'reason', 'missing_link'); END IF;
      IF NOT public._link_token_valid(p_game_id, p_link_token) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_invalid', 'reason', 'invalid_link'); END IF;
      cta := 'join_with_link';
    WHEN 'circle' THEN
      IF NOT public.are_synced(viewer, e.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
      cta := 'join';
    WHEN 'squad' THEN
      IF g.squad_id IS NULL OR NOT public.is_in_squad(viewer, g.squad_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'squad_only', 'reason', 'not_in_squad'); END IF;
      cta := 'join';
    WHEN 'closed' THEN RETURN jsonb_build_object('allowed', false, 'cta', 'closed', 'reason', 'closed');
    ELSE RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'unknown_policy');
  END CASE;
  slots := public.game_slots_left(p_game_id);
  IF slots = 0 THEN
    RETURN jsonb_build_object('allowed', true,
      'cta', CASE WHEN e.join_policy = 'request' THEN 'request' ELSE 'waitlist' END,
      'reason', 'full');
  END IF;
  RETURN jsonb_build_object('allowed', true, 'cta', cta, 'reason', NULL);
END;
$function$;

CREATE OR REPLACE FUNCTION public._recent_activity_score(u uuid, p_recent_days integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: start_at from events for callers that may read events (INVOKER).
-- KAN-834: a caller that may not read events gets the old fallback's answer without a games column read: games has
-- RLS and no policy, so no roster row joins a visible game and the answer is 0.0. If one ever does, the events read
-- below raises 42501 (fail closed).
BEGIN
  IF NOT has_table_privilege('public.events', 'SELECT') AND NOT EXISTS (
      SELECT 1
        FROM public.game_roster gr
        JOIN public.games g ON g.id = gr.game_id
       WHERE gr.user_id = u
         AND gr.status = 'active') THEN
    RETURN 0.0;
  END IF;
  IF EXISTS (
    SELECT 1
      FROM public.game_roster gr
      JOIN public.games g ON g.id = gr.game_id
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
     WHERE gr.user_id = u
       AND gr.status = 'active'
       AND e.start_at >= now() - (p_recent_days || ' days')::interval) THEN
    RETURN 1.0;
  END IF;
  RETURN 0.0;
END
$function$;

CREATE OR REPLACE FUNCTION public._user_hosted_game(p_user_id uuid, p_game_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: creator from events for callers that may read events (rpc_rate_venue, SECURITY DEFINER).
-- KAN-834: a caller that may not read events (INVOKER, granted to clients; events has no client grant) gets the old
-- fallback's answer without a games column read: games has RLS and no policy, so it sees no row and the answer is
-- false. If it ever sees one, the events read below raises 42501 (fail closed).
BEGIN
  IF NOT has_table_privilege('public.events', 'SELECT')
     AND NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = p_game_id) THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
     WHERE g.id = p_game_id
       AND e.creator_user_id = p_user_id);
END
$function$;

CREATE OR REPLACE FUNCTION public.game_is_joinable(p_game uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- KAN-772: cancel state and start from events for callers that may read events (INVOKER). An unknown game returns
-- NULL, as the pre-image's one-row SQL select did.
-- KAN-834: a caller that may not read events gets the old fallback's answer without a games column read: games has
-- RLS and no policy, so it sees no row and the answer is NULL. If it ever sees one, the events read below raises
-- 42501 (fail closed).
DECLARE
  v boolean;
BEGIN
  IF NOT has_table_privilege('public.events', 'SELECT')
     AND NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = p_game) THEN
    RETURN NULL;
  END IF;
  SELECT NOT e.is_cancelled AND e.start_at > now() INTO v
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE g.id = p_game;
  RETURN v;
END
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Postconditions: authored bodies, attributes unchanged.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  r record;
  v_attr jsonb := current_setting('kan834.c_attr')::jsonb;
  v_now jsonb;
begin
  for r in select * from (values
    ('public.can_current_user_join_game(uuid, text, uuid)', 'dec4ccbbeaac92e7e5ff23e6806cdb30'),
    ('public._recent_activity_score(uuid, integer)', '2202f744a38453ddb883089c274dd2e1'),
    ('public._user_hosted_game(uuid, uuid)', '792f07c44f71c4dc154716a5905b0659'),
    ('public.game_is_joinable(uuid)', '7075cd9e1f42e083960708f11bf7d0f1')) k(fn, post_md5) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post_md5 then
      raise exception 'KAN-834 post: % body is not the authored one', r.fn;
    end if;
    select jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
             p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset)
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'KAN-834 post: % changed signature/result/SECURITY/volatility/search_path/owner/ACL: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end $post$;

commit;

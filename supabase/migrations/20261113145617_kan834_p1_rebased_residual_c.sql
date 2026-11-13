-- KAN-834 rebased on live (KAN-862 package P1, backend-1; Epic KAN-708). Supersedes
-- supabase/migrations/_superseded/20261104112100_kan834_d04_residual_c.sql (authored, never applied).
--
-- WHAT: can_current_user_join_game (rebased on the live KAN-717 F1 body: the invite arm matches i.to_user_id
--   only), _recent_activity_score, _user_hosted_game and game_is_joinable read every shared field from events. The
--   INVOKER client fallback keeps its no-row answer (games has RLS and no policy) without a games shared-column read.
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058), wtncuzcskpigqpmnxwws, 2026-11-13: pg_get_functiondef of each target.
-- Each live md5(prosrc) was compared with the superseded file's pre-image pin; the body change is that file's
-- intent and nothing else. Live pre-image -> post-image md5(prosrc):
--   public.can_current_user_join_game(uuid,text,uuid)  0ad68af0cbf6cf75fca30b52676e8ead -> 085495b09a90c68d2f009ffcdc5a46d5
--   public._recent_activity_score(uuid,integer)  6cec16401372d08e38d17e74d68ec322 -> 2202f744a38453ddb883089c274dd2e1
--   public._user_hosted_game(uuid,uuid)  41a0f3b192055a68f7dbaea2807c9933 -> 792f07c44f71c4dc154716a5905b0659
--   public.game_is_joinable(uuid)  a7245a8bc76da50e56cb011fca0f4797 -> 7075cd9e1f42e083960708f11bf7d0f1
--
-- HOW: CREATE OR REPLACE with the same signature keeps oid, owner, ACL, SECURITY, volatility and search_path; the
-- post block asserts them, and every trigger definition on them, unchanged. Definitions only: no row is written and
-- no column, table, policy or existing grant changes. Equivalence: the pre block refuses unless every games row has
-- its 'game' events parent and every games column whose read moves equals its events counterpart (KAN-711 parity;
-- checked only while the column exists). Any other live body refuses (re-author from pg_get_functiondef).
-- No BEGIN/COMMIT: apply_migration and the CLI wrap each migration in one transaction.
-- Live test: supabase/tests/events_p4/kan834_p1_live_test.sql (BEGIN ... ROLLBACK, TAP).

do $pre$
declare
  r record; c text; v_n bigint; v_attr jsonb := '{}'::jsonb;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'kan834 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  for r in select * from (values
    ('public.can_current_user_join_game(uuid,text,uuid)', '0ad68af0cbf6cf75fca30b52676e8ead', '085495b09a90c68d2f009ffcdc5a46d5'),
    ('public._recent_activity_score(uuid,integer)', '6cec16401372d08e38d17e74d68ec322', '2202f744a38453ddb883089c274dd2e1'),
    ('public._user_hosted_game(uuid,uuid)', '41a0f3b192055a68f7dbaea2807c9933', '792f07c44f71c4dc154716a5905b0659'),
    ('public.game_is_joinable(uuid)', 'a7245a8bc76da50e56cb011fca0f4797', '7075cd9e1f42e083960708f11bf7d0f1')) t(fn, pin, post) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'kan834 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pin then
      raise exception 'kan834 pre: pre-image drift on % (md5(prosrc) %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pin;
    end if;
    v_attr := v_attr || jsonb_build_object(r.fn, (
      select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
        from pg_proc p where p.oid = to_regprocedure(r.fn)));
  end loop;
  -- INVOKER fallback premise: a caller without events access sees no games row.
  if not (select relrowsecurity from pg_class where oid = 'public.games'::regclass)
     or exists (select 1 from pg_policy where polrelid = 'public.games'::regclass) then
    raise exception 'kan834 pre: public.games must have RLS on and no policy (INVOKER fallback premise)';
  end if;
  select count(*) into v_n from public.games g
    left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null;
  if v_n > 0 then
    raise exception 'kan834 pre: % games row(s) without a ''game'' events parent', v_n;
  end if;
  foreach c in array array['creator_user_id', 'listing_visibility', 'is_cancelled', 'start_at', 'join_policy'] loop
    if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = c and attnum > 0 and not attisdropped) then
      execute format('select count(*) from public.games x join public.events e on e.id = x.event_id and e.event_type = %L
                       where x.%I is distinct from e.%I', 'game', c, c) into v_n;
      if v_n > 0 then
        raise exception 'kan834 pre: % games row(s) differ from events on % (KAN-711 parity)', v_n, c;
      end if;
    end if;
  end loop;
  perform set_config('kan834.attr', v_attr::text, true);
end
$pre$;

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
      IF EXISTS (SELECT 1 FROM public.game_invites i WHERE i.game_id = p_game_id AND i.status = 'pending' AND i.to_user_id = viewer) THEN   -- KAN-717 F1: rpc_invite_user writes to_user_id
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

do $post$
declare
  r record; v_attr jsonb := current_setting('kan834.attr')::jsonb; v_now jsonb;
begin
  for r in select * from (values
    ('public.can_current_user_join_game(uuid,text,uuid)', '0ad68af0cbf6cf75fca30b52676e8ead', '085495b09a90c68d2f009ffcdc5a46d5'),
    ('public._recent_activity_score(uuid,integer)', '6cec16401372d08e38d17e74d68ec322', '2202f744a38453ddb883089c274dd2e1'),
    ('public._user_hosted_game(uuid,uuid)', '41a0f3b192055a68f7dbaea2807c9933', '792f07c44f71c4dc154716a5905b0659'),
    ('public.game_is_joinable(uuid)', 'a7245a8bc76da50e56cb011fca0f4797', '7075cd9e1f42e083960708f11bf7d0f1')) t(fn, pin, post) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post then
      raise exception 'kan834 post: % body md5 %, expected %', r.fn,
        (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.post;
    end if;
    select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'kan834 post: % signature/attributes/owner/ACL/trigger changed: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end
$post$;

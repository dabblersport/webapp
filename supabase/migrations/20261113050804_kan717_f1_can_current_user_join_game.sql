-- KAN-717 F1 (Events P3 verification; defect list KAN-766 comment 15476): public.can_current_user_join_game reads
-- game_invites.to_profile_id, a column that does not exist. game_invites has id, game_id, to_user_id NOT NULL,
-- invited_by_profile_id, status, created_at, responded_at, and public.rpc_invite_user writes to_user_id only. plpgsql
-- resolves the column at run time, so every join on an invite-policy game raised 42703 through public.rpc_join_game
-- (its only caller), including for a user holding a pending invite.
--
-- FIX. The invite arm matches i.to_user_id = viewer only, the way rpc_invite_user writes the row. Nothing else changes.
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058): pg_get_functiondef on wtncuzcskpigqpmnxwws, md5(prosrc) c26ddc863eb05995224c7edb6e57f956.
-- HOW. CREATE OR REPLACE with the same signature: keeps oid, owner postgres, ACL
-- {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}, SECURITY INVOKER,
-- STABLE, SET search_path TO 'public'. Pinned on the pre-image md5; asserts the post-image md5 0ad68af0cbf6cf75fca30b52676e8ead and unchanged
-- attributes/ACL. Re-running at the post-image is a no-op. No BEGIN/COMMIT (the CLI wraps each migration).
--
-- Live proof: supabase/tests/events_p4/kan717_f1_can_current_user_join_game_test.sql (BEGIN ... ROLLBACK).
--
-- ROLLBACK (verbatim live pre-image, md5(prosrc) c26ddc863eb05995224c7edb6e57f956). Run uncommented, as postgres:
-- CREATE OR REPLACE FUNCTION public.can_current_user_join_game(p_game_id uuid, p_actor_type text DEFAULT 'player'::text, p_link_token uuid DEFAULT NULL::uuid)
--  RETURNS jsonb
--  LANGUAGE plpgsql
--  STABLE
--  SET search_path TO 'public'
-- AS $function$
-- DECLARE
--   g public.games%rowtype; viewer uuid := auth.uid(); actor_id uuid;
--   slots int; visible boolean; cta text;
--   e public.events%rowtype; v_events boolean := has_table_privilege('public.events', 'SELECT');   -- KAN-713
-- BEGIN
--   IF viewer IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'anon'); END IF;
--   IF public.is_frozen(viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'frozen'); END IF;
--   actor_id := public.choose_actor(p_actor_type);
--   IF NOT public.actor_is_player(actor_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'actor_not_player'); END IF;
--   SELECT * INTO g FROM public.games WHERE id = p_game_id;
--   IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
--   IF v_events THEN                                                                                    -- KAN-713
--     SELECT * INTO e FROM public.events WHERE id = g.event_id AND event_type = 'game';
--     IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
--   END IF;
--   IF g.creator_user_id = viewer OR (v_events AND e.creator_user_id = viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'host', 'reason', 'host'); END IF;
--   visible := public.can_view_with_scope(viewer, g.creator_user_id, g.listing_visibility, g.squad_id);
--   IF visible AND v_events THEN                                                                        -- KAN-713
--     visible := public.can_view_with_scope(viewer, e.creator_user_id, e.listing_visibility, g.squad_id);
--   END IF;
--   IF NOT visible THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_visible', 'reason', 'visibility_denied'); END IF;
--   IF g.is_cancelled OR (v_events AND e.is_cancelled) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'cancelled', 'reason', 'cancelled'); END IF;
--   IF g.start_at <= now() OR (v_events AND e.start_at <= now()) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'started', 'reason', 'started'); END IF;
--   IF v_events AND e.join_policy IS DISTINCT FROM g.join_policy THEN                                   -- KAN-713: fail closed
--     RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'policy_mismatch');
--   END IF;
--   IF EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.status = 'active' AND (r.user_id = viewer OR r.profile_id = actor_id)) THEN
--     RETURN jsonb_build_object('allowed', false, 'cta', 'joined', 'reason', 'already');
--   END IF;
--   CASE g.join_policy
--     WHEN 'open' THEN cta := 'join';
--     WHEN 'request' THEN
--       IF EXISTS (SELECT 1 FROM public.game_join_requests q WHERE q.game_id = p_game_id AND q.status = 'pending' AND (q.from_user_id = viewer OR q.from_profile_id = actor_id)) THEN
--         RETURN jsonb_build_object('allowed', false, 'cta', 'requested', 'reason', 'pending_request');
--       END IF;
--       cta := 'request';
--     WHEN 'invite' THEN
--       IF EXISTS (SELECT 1 FROM public.game_invites i WHERE i.game_id = p_game_id AND i.status = 'pending' AND (i.to_user_id = viewer OR i.to_profile_id = actor_id)) THEN
--         cta := 'accept_invite';
--       ELSE
--         RETURN jsonb_build_object('allowed', false, 'cta', 'invite_only', 'reason', 'invite_required');
--       END IF;
--     WHEN 'link' THEN
--       IF p_link_token IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_required', 'reason', 'missing_link'); END IF;
--       IF NOT public._link_token_valid(p_game_id, p_link_token) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'link_invalid', 'reason', 'invalid_link'); END IF;
--       cta := 'join_with_link';
--     WHEN 'circle' THEN
--       IF NOT public.are_synced(viewer, g.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
--       IF v_events AND NOT public.are_synced(viewer, e.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
--       cta := 'join';
--     WHEN 'squad' THEN
--       IF g.squad_id IS NULL OR NOT public.is_in_squad(viewer, g.squad_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'squad_only', 'reason', 'not_in_squad'); END IF;
--       cta := 'join';
--     WHEN 'closed' THEN RETURN jsonb_build_object('allowed', false, 'cta', 'closed', 'reason', 'closed');
--     ELSE RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'unknown_policy');
--   END CASE;
--   slots := public.game_slots_left(p_game_id);
--   IF slots = 0 THEN
--     RETURN jsonb_build_object('allowed', true,
--       'cta', CASE WHEN g.join_policy = 'request' THEN 'request' ELSE 'waitlist' END,
--       'reason', 'full');
--   END IF;
--   RETURN jsonb_build_object('allowed', true, 'cta', cta, 'reason', NULL);
-- END;
-- $function$;

do $kan717f1$
declare
  c_sig  constant text := 'public.can_current_user_join_game(uuid,text,uuid)';
  c_pre  constant text := 'c26ddc863eb05995224c7edb6e57f956';
  c_post constant text := '0ad68af0cbf6cf75fca30b52676e8ead';
  v_oid  oid;
  v_md5  text;
  v_before jsonb;
  v_after  jsonb;
begin
  v_oid := to_regprocedure(c_sig);
  if v_oid is null then
    raise exception 'kan717f1 pre: % is absent', c_sig;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 = c_post then
    raise notice 'kan717f1: % already fixed (md5(prosrc) %); nothing to do', c_sig, v_md5;
    return;
  end if;
  if v_md5 <> c_pre then
    raise exception 'kan717f1 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
      c_sig, v_md5, c_pre;
  end if;

  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_before from pg_proc p where p.oid = v_oid;

  execute $ddl$
CREATE OR REPLACE FUNCTION public.can_current_user_join_game(p_game_id uuid, p_actor_type text DEFAULT 'player'::text, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  g public.games%rowtype; viewer uuid := auth.uid(); actor_id uuid;
  slots int; visible boolean; cta text;
  e public.events%rowtype; v_events boolean := has_table_privilege('public.events', 'SELECT');   -- KAN-713
BEGIN
  IF viewer IS NULL THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'anon'); END IF;
  IF public.is_frozen(viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'frozen'); END IF;
  actor_id := public.choose_actor(p_actor_type);
  IF NOT public.actor_is_player(actor_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'actor_not_player'); END IF;
  SELECT * INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  IF v_events THEN                                                                                    -- KAN-713
    SELECT * INTO e FROM public.events WHERE id = g.event_id AND event_type = 'game';
    IF NOT FOUND THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'not_found'); END IF;
  END IF;
  IF g.creator_user_id = viewer OR (v_events AND e.creator_user_id = viewer) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'host', 'reason', 'host'); END IF;
  visible := public.can_view_with_scope(viewer, g.creator_user_id, g.listing_visibility, g.squad_id);
  IF visible AND v_events THEN                                                                        -- KAN-713
    visible := public.can_view_with_scope(viewer, e.creator_user_id, e.listing_visibility, g.squad_id);
  END IF;
  IF NOT visible THEN RETURN jsonb_build_object('allowed', false, 'cta', 'not_visible', 'reason', 'visibility_denied'); END IF;
  IF g.is_cancelled OR (v_events AND e.is_cancelled) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'cancelled', 'reason', 'cancelled'); END IF;
  IF g.start_at <= now() OR (v_events AND e.start_at <= now()) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'started', 'reason', 'started'); END IF;
  IF v_events AND e.join_policy IS DISTINCT FROM g.join_policy THEN                                   -- KAN-713: fail closed
    RETURN jsonb_build_object('allowed', false, 'cta', 'not_allowed', 'reason', 'policy_mismatch');
  END IF;
  IF EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = p_game_id AND r.status = 'active' AND (r.user_id = viewer OR r.profile_id = actor_id)) THEN
    RETURN jsonb_build_object('allowed', false, 'cta', 'joined', 'reason', 'already');
  END IF;
  CASE g.join_policy
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
      IF NOT public.are_synced(viewer, g.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
      IF v_events AND NOT public.are_synced(viewer, e.creator_user_id) THEN RETURN jsonb_build_object('allowed', false, 'cta', 'circle_only', 'reason', 'not_in_circle'); END IF;
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
      'cta', CASE WHEN g.join_policy = 'request' THEN 'request' ELSE 'waitlist' END,
      'reason', 'full');
  END IF;
  RETURN jsonb_build_object('allowed', true, 'cta', cta, 'reason', NULL);
END;
$function$
$ddl$;

  if to_regprocedure(c_sig) is distinct from v_oid then
    raise exception 'kan717f1 post: % is not the same function oid after CREATE OR REPLACE', c_sig;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> c_post then
    raise exception 'kan717f1 post: % body md5 is %, expected %', c_sig, v_md5, c_post;
  end if;
  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_after from pg_proc p where p.oid = v_oid;
  if v_after is distinct from v_before then
    raise exception 'kan717f1 post: % attributes or ACL changed: % -> %', c_sig, v_before, v_after;
  end if;
end
$kan717f1$;

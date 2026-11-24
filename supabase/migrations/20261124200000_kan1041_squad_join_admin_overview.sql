-- KAN-1041: squad join and invite accept called helpers that never existed live; dead admin overview removed.
-- Part A: _profile_is_player_for_sport and _can_participate are not defined anywhere (baseline only calls them),
--   so rpc_squad_request_join and rpc_squad_respond_invite(uuid,text,uuid) raised 42883. Repointed at the live
--   equivalents used by can_join_squad and can_current_user_join_game: actor_is_player, is_frozen, is_benched.
--   Their ON CONFLICT (squad_id, user_id) matched no constraint (42P10); the live key is (squad_id, profile_id).
--   rpc_squad_respond_invite also gains the KAN-1038 profile ownership check.
-- Part B: admin_overview_row reads content_reports, admin_is_hidden reads content_enforcement (via is_shadow_hidden
--   and is_takedown); neither table exists. No caller in lib/, supabase/functions, policies, other functions
--   or pg_stat_statements, so they are dropped with v_admin_overview.
-- Bodies are from pg_get_functiondef on the live catalogue.

CREATE OR REPLACE FUNCTION public.rpc_squad_request_join(p_squad_id uuid, p_profile_id uuid, p_message text DEFAULT NULL::text, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE s record; members int;
BEGIN
  -- KAN-1038: the profile must belong to the caller.
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION USING errcode='42501', message='profile_not_owned';
  END IF;

  SELECT id, sport, join_policy, max_members INTO s
  FROM public.squads WHERE id=p_squad_id AND is_active=true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='squad_not_found'; END IF;

  -- KAN-1041: live equivalents of the never-created helpers (same checks as can_join_squad / game join).
  IF NOT public.actor_is_player(p_profile_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='profile_not_player_for_sport';
  END IF;
  IF public.is_frozen(auth.uid()) OR public.is_benched(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='benched_or_frozen';
  END IF;

  IF s.max_members IS NOT NULL THEN
    SELECT COUNT(*) INTO members FROM public.squad_members WHERE squad_id=s.id AND status='active';
    IF members >= s.max_members THEN RAISE EXCEPTION USING errcode='P0001', message='squad_full'; END IF;
  END IF;

  CASE s.join_policy
    WHEN 'open' THEN
      INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
      VALUES (s.id, auth.uid(), p_profile_id, 'member','active')
      ON CONFLICT (squad_id, profile_id) DO UPDATE  -- KAN-1041: the live key is (squad_id, profile_id)
        SET status='active', user_id=EXCLUDED.user_id, left_at=NULL;

      PERFORM public.emit_event('squad.member_joined','squad', s.id, auth.uid(), jsonb_build_object('via','open'));
      RETURN 'joined';

    WHEN 'request' THEN
      INSERT INTO public.squad_join_requests(squad_id,user_id,profile_id,status,message)
      VALUES (s.id, auth.uid(), p_profile_id, 'pending', LEFT(p_message,300))
      ON CONFLICT DO NOTHING;

      PERFORM public.emit_event('squad.join_requested','squad', s.id, auth.uid(), '{}');
      RETURN 'pending';

    WHEN 'invite' THEN
      RAISE EXCEPTION USING errcode='P0001', message='invite_only';

    WHEN 'closed' THEN
      RAISE EXCEPTION USING errcode='P0001', message='closed';

    WHEN 'link' THEN
      IF p_link_token IS NULL OR NOT public._squad_link_valid(s.id, p_link_token) THEN
        RAISE EXCEPTION USING errcode='P0001', message='link_required';
      END IF;
      PERFORM public._squad_link_consume(s.id, p_link_token);

      INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
      VALUES (s.id, auth.uid(), p_profile_id, 'member','active')
      ON CONFLICT (squad_id, profile_id) DO UPDATE  -- KAN-1041: the live key is (squad_id, profile_id)
        SET status='active', user_id=EXCLUDED.user_id, left_at=NULL;

      PERFORM public.emit_event('squad.member_joined','squad', s.id, auth.uid(), jsonb_build_object('via','link'));
      RETURN 'joined';

    ELSE
      RAISE EXCEPTION USING errcode='P0001', message='unknown_policy';
  END CASE;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_squad_request_join(uuid,uuid,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_squad_request_join(uuid,uuid,text,uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_squad_respond_invite(p_invite_id uuid, p_action text, p_profile_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE inv record; sp text; members int; maxm int;
BEGIN
  SELECT * INTO inv FROM public.squad_invites WHERE id=p_invite_id AND to_user_id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invite_not_found'; END IF;

  SELECT sport, max_members INTO sp, maxm FROM public.squads WHERE id=inv.squad_id;

  IF p_action = 'decline' THEN
    UPDATE public.squad_invites SET status='declined' WHERE id=p_invite_id AND status='pending';
    RETURN 'declined';

  ELSIF p_action = 'accept' THEN
    -- KAN-1041: the profile must belong to the caller (as in rpc_squad_request_join), then live helpers.
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
      RAISE EXCEPTION USING errcode='42501', message='profile_not_owned';
    END IF;
    IF NOT public.actor_is_player(p_profile_id) THEN
      RAISE EXCEPTION USING errcode='P0001', message='profile_not_player_for_sport';
    END IF;

    IF public.is_frozen(auth.uid()) OR public.is_benched(auth.uid()) THEN
      RAISE EXCEPTION USING errcode='P0001', message='benched_or_frozen';
    END IF;

    IF maxm IS NOT NULL THEN
      SELECT COUNT(*) INTO members FROM public.squad_members WHERE squad_id=inv.squad_id AND status='active';
      IF members >= maxm THEN RAISE EXCEPTION USING errcode='P0001', message='squad_full'; END IF;
    END IF;

    INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
    VALUES (inv.squad_id, auth.uid(), p_profile_id, 'member','active')
    ON CONFLICT (squad_id, profile_id) DO UPDATE  -- KAN-1041: the live key is (squad_id, profile_id)
      SET status='active', user_id=EXCLUDED.user_id, left_at=NULL;

    UPDATE public.squad_invites SET status='accepted' WHERE id=p_invite_id AND status='pending';

    PERFORM public.emit_event('squad.member_joined','squad', inv.squad_id, auth.uid(), jsonb_build_object('via','invite'));
    RETURN 'accepted';

  ELSE
    RAISE EXCEPTION USING errcode='P0001', message='invalid_action';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_squad_respond_invite(uuid,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_squad_respond_invite(uuid,text,uuid) TO authenticated, service_role;

DROP VIEW public.v_admin_overview;
DROP FUNCTION public.admin_overview_row();
DROP FUNCTION public.admin_is_hidden(text, uuid);

-- Rollback for 20261124183000_kan1038_sec8_definer_fixes.sql: restores the exact pre-change bodies and ACLs.

CREATE OR REPLACE FUNCTION public.rpc_squad_request_join(p_squad_id uuid, p_profile_id uuid, p_message text DEFAULT NULL::text, p_link_token uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE s record; members int;
BEGIN
  SELECT id, sport, join_policy, max_members INTO s
  FROM public.squads WHERE id=p_squad_id AND is_active=true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='squad_not_found'; END IF;

  IF NOT public._profile_is_player_for_sport(p_profile_id, s.sport) THEN
    RAISE EXCEPTION USING errcode='P0001', message='profile_not_player_for_sport';
  END IF;
  IF NOT public._can_participate(auth.uid()) THEN
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
      ON CONFLICT (squad_id, user_id) DO UPDATE
        SET status='active', profile_id=EXCLUDED.profile_id, left_at=NULL;

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
      ON CONFLICT (squad_id, user_id) DO UPDATE
        SET status='active', profile_id=EXCLUDED.profile_id, left_at=NULL;

      PERFORM public.emit_event('squad.member_joined','squad', s.id, auth.uid(), jsonb_build_object('via','link'));
      RETURN 'joined';

    ELSE
      RAISE EXCEPTION USING errcode='P0001', message='unknown_policy';
  END CASE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_toggle_post_vibe(p_post_id uuid, p_vibe_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM public.post_vibes WHERE post_id = p_post_id AND vibe_id = p_vibe_id) THEN
    DELETE FROM public.post_vibes WHERE post_id = p_post_id AND vibe_id = p_vibe_id;
    RETURN 'removed';
  ELSE
    INSERT INTO public.post_vibes(post_id, vibe_id) VALUES (p_post_id, p_vibe_id);
    RETURN 'added';
  END IF;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.rpc_toggle_post_vibe(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_toggle_post_vibe(uuid, uuid) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.rpc_expire_freezes() TO authenticated;

GRANT EXECUTE ON FUNCTION public._debug_can_view(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public._whoami_definer() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.effective_actor_uid_debug() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_actor() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_actor() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_approve_payout(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_approve_payout(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_assert_posts_integrity() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_assert_posts_integrity() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_cancel_payout(uuid,text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_cancel_payout(uuid,text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_cleanup_user_data(uuid,boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_force_delete_auth_user(text) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_force_delete_auth_user(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_is_hidden(text,uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_mark_payout_paid(uuid,jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_mark_payout_paid(uuid,jsonb) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_mark_payout_processing(uuid,jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_mark_payout_processing(uuid,jsonb) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_overview_row() TO anon;
GRANT EXECUTE ON FUNCTION public.admin_overview_row() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid,report_status,text,uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid,report_status,text,uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_take_action(mod_action,mod_target,uuid,uuid,text,timestamp with time zone,jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.admin_take_action(mod_action,mod_target,uuid,uuid,text,timestamp with time zone,jsonb) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_submission_action_state(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.rpc_admin_submission_action_state(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_submission_approval_state(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.rpc_submission_approval_state(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_submission_audit_timeline(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.rpc_submission_audit_timeline(uuid) TO PUBLIC;
REVOKE EXECUTE ON FUNCTION public.upsert_area_from_mapbox(text,text,text,double precision,double precision) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_area_from_mapbox(text,text,text,double precision,double precision) TO PUBLIC, anon;

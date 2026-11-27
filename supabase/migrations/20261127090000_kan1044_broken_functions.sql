-- KAN-1044: live functions that referenced missing tables, columns or functions.
-- Plan: /root/.claude/plans/polymorphic-jumping-mochi.md. Rollback: supabase/rollbacks/20261127090000_kan1044_broken_functions_rollback.sql
-- Caller re-check (2026-11-27): pg_depend, pg_trigger, cron.job, lib/, supabase/functions,
-- pg_stat_statements (anon/authenticated/service_role) and 7 days of edge logs. The only live caller among the
-- functions dropped/fixed here is is_takedown(mod_target,uuid) (the app, 200s, already reads safety_takedowns; kept).
--
-- 1. plpgsql_check, used for the full scan (kept installed for future scans).
CREATE EXTENSION IF NOT EXISTS plpgsql_check;

-- 2. rpc_squad_create: the app sends (p_sport,p_name,p_bio,p_logo_url,p_listing_visibility,p_join_policy,
--    p_max_members,p_city) (squads_repository_impl.dart:65); the live signature took p_created_by_profile_id and
--    p_captain_user_id, so PostgREST could not even resolve the call. Body also used profile_type 'player'/'organiser'
--    (live values are personal/business/organisation/venue), founder_user_id (column is owner_user_id) and the missing
--    _profile_matches_sport. New signature = the app's params. Creator profile = the caller's own active player
--    profile (actor_is_player), same rule as squad join. One squad per owner per sport (squads_owner_user_id_sport_key).
DROP FUNCTION public.rpc_squad_create(uuid,text,text,text,text,text,integer,uuid);
CREATE FUNCTION public.rpc_squad_create(
  p_sport text, p_name text, p_bio text DEFAULT NULL, p_logo_url text DEFAULT NULL,
  p_listing_visibility text DEFAULT 'public', p_join_policy text DEFAULT 'request',
  p_max_members integer DEFAULT NULL, p_city text DEFAULT NULL)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_profile uuid; sid uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  SELECT pr.id INTO v_profile
  FROM public.profiles pr
  WHERE pr.user_id = v_uid AND public.actor_is_player(pr.id)
  ORDER BY pr.created_at
  LIMIT 1;
  IF v_profile IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='profile_not_player'; END IF;

  IF public.is_frozen(v_uid) OR public.is_benched(v_uid) THEN
    RAISE EXCEPTION USING errcode='P0001', message='benched_or_frozen';
  END IF;

  IF EXISTS (SELECT 1 FROM public.squads WHERE owner_user_id = v_uid AND sport = p_sport) THEN
    RAISE EXCEPTION USING errcode='P0001', message='founder_limit_reached';
  END IF;

  INSERT INTO public.squads(
    sport, name, bio, logo_url, created_by_user_id, created_by_profile_id, created_by_role,
    owner_user_id, owner_profile_id, listing_visibility, join_policy, max_members, city
  ) VALUES (
    p_sport, p_name, p_bio, p_logo_url, v_uid, v_profile, 'player',
    v_uid, v_profile, COALESCE(p_listing_visibility,'public'), COALESCE(p_join_policy,'request'),
    p_max_members, COALESCE(NULLIF(btrim(p_city),''),'Dubai')
  ) RETURNING id INTO sid;

  INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
  VALUES (sid, v_uid, v_profile, 'captain','active');

  PERFORM public.emit_event('squad.created','squad', sid, v_uid,
    jsonb_build_object('sport',p_sport,'name',p_name));
  RETURN sid;
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_squad_create(text,text,text,text,text,text,integer,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_squad_create(text,text,text,text,text,text,integer,text) TO authenticated, service_role;

-- 3. Squad join: error text matches what is checked (actor_is_player, no sport check, as can_join_squad).
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
      RAISE EXCEPTION USING errcode='P0001', message='profile_not_player';
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
$function$
;

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
    RAISE EXCEPTION USING errcode='P0001', message='profile_not_player';
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
$function$
;


-- 4. Comment replies: trg_enforce_single_level_reply on public.comments read the missing public.post_comments,
--    so every reply insert (post_repository_impl.dart:1532) failed with 42P01. Read public.comments.
CREATE OR REPLACE FUNCTION public.enforce_single_level_reply()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    parent_parent_id uuid;
BEGIN
    IF NEW.parent_comment_id IS NOT NULL THEN
        SELECT parent_comment_id
        INTO parent_parent_id
        FROM public.comments
        WHERE id = NEW.parent_comment_id;

        IF parent_parent_id IS NOT NULL THEN
            RAISE EXCEPTION 'Replies to replies are not allowed (single-level threading only)';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

-- 5. One pending join request per (squad, profile). No duplicates exist (checked 2026-11-27).
CREATE UNIQUE INDEX IF NOT EXISTS squad_join_requests_pending_uniq
  ON public.squad_join_requests (squad_id, profile_id) WHERE status = 'pending';

-- 6. Dead functions: no caller anywhere (see header). Each references a missing relation or function.
DROP FUNCTION public.rpc_create_squad(uuid,text,text,text,text);
DROP FUNCTION public.rpc_review_report(uuid,text,text,text);
DROP FUNCTION public.rpc_flag_content(text,uuid,text,text);
DROP FUNCTION public.rpc_shadow_hide(text,uuid,text,timestamp with time zone);
DROP FUNCTION public.rpc_shadow_unhide(text,uuid,text);
DROP FUNCTION public.rpc_takedown(text,uuid,text);
DROP FUNCTION public.is_shadow_hidden(text,uuid);
DROP FUNCTION public.is_takedown(text,uuid);  -- the app's is_takedown(mod_target,uuid) stays
DROP FUNCTION public.rpc_create_post(uuid,text,text,text,text,text,uuid,double precision,double precision,jsonb,uuid[]);
DROP FUNCTION public.rpc_report_post(uuid,text,text);
DROP FUNCTION public.rpc_toggle_like(uuid);
DROP FUNCTION public.rpc_draft_publish_game(uuid);
DROP FUNCTION public.rpc_draft_publish_meetup(uuid);
DROP FUNCTION public.rpc_draft_publish_challenge(uuid);
DROP FUNCTION public.send_vibe_request(uuid);
DROP FUNCTION public.toggle_venue_favorite_legacy_v1(uuid,uuid);
DROP FUNCTION public.toggle_venue_favorite_legacy_v1(uuid);
DROP FUNCTION public.trg_scan_post();

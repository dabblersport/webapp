-- Rollback for 20261124200000_kan1041_squad_join_admin_overview.sql. Exact live definitions and grants before it.

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
    IF NOT public._profile_is_player_for_sport(p_profile_id, sp) THEN
      RAISE EXCEPTION USING errcode='P0001', message='profile_not_player_for_sport';
    END IF;

    IF NOT public._can_participate(auth.uid()) THEN
      RAISE EXCEPTION USING errcode='P0001', message='benched_or_frozen';
    END IF;

    IF maxm IS NOT NULL THEN
      SELECT COUNT(*) INTO members FROM public.squad_members WHERE squad_id=inv.squad_id AND status='active';
      IF members >= maxm THEN RAISE EXCEPTION USING errcode='P0001', message='squad_full'; END IF;
    END IF;

    INSERT INTO public.squad_members(squad_id,user_id,profile_id,role,status)
    VALUES (inv.squad_id, auth.uid(), p_profile_id, 'member','active')
    ON CONFLICT (squad_id, user_id) DO UPDATE
      SET status='active', profile_id=EXCLUDED.profile_id, left_at=NULL;

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

CREATE OR REPLACE FUNCTION public.admin_overview_row()
 RETURNS TABLE(snapshot_at timestamp with time zone, total_users bigint, frozen_users bigint, active_users bigint, games_created_this_week bigint, reports_open bigint, reports_resolved bigint, verified_profiles_total bigint, verified_players bigint, verified_organisers bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  wk_start timestamptz;
  wk_end   timestamptz;
begin
  -- Gate: admin only
  if not public.is_admin(auth.uid()) then
    raise exception using errcode = 'P0001', message = 'not_admin';
  end if;

  select week_start, week_end into wk_start, wk_end
  from public._week_bounds(now());

  -- Return single-row snapshot
  return query
  with
  -- Distinct humans inferred from profiles; avoids needing auth.users privileges
  users_distinct as (
    select count(distinct p.user_id)::bigint as c
    from public.profiles p
    where p.is_active = true
  ),
  frozen as (
    select count(distinct f.user_id)::bigint as c
    from public.user_freezes f
    where f.is_frozen = true
      and (f.until is null or now() < f.until)
      and f.lifted_at is null
  ),
  -- KAN-732 (KAN-714 B13): created_at is a SHARED fact, read from the game's events parent.
  games_week as (
    select count(*)::bigint as c
    from public.kan714_games_read g
    join public.events e on e.id = g.event_id and e.event_type = 'game'
    where e.created_at >= wk_start
      and e.created_at <  wk_end
  ),
  reports as (
    select
      count(*) filter (where status in ('open','reviewing'))::bigint as open_c,
      count(*) filter (where status = 'resolved')::bigint          as resolved_c
    from public.content_reports
  ),
  verif as (
    select
      count(*)::bigint                                                     as total_c,
      count(*) filter (where p.profile_type = 'player')::bigint            as players_c,
      count(*) filter (where p.profile_type = 'organiser')::bigint         as organisers_c
    from public.profile_verifications v
    join public.profiles p on p.id = v.profile_id
    where v.verified = true
  )
  select
    now()                                              as snapshot_at,
    (select c from users_distinct)                     as total_users,
    (select c from frozen)                             as frozen_users,
    (select c from users_distinct) - (select c from frozen)  as active_users,
    (select c from games_week)                         as games_created_this_week,
    (select open_c from reports)                       as reports_open,
    (select resolved_c from reports)                   as reports_resolved,
    (select total_c from verif)                        as verified_profiles_total,
    (select players_c from verif)                      as verified_players,
    (select organisers_c from verif)                   as verified_organisers;
end;
$function$;

REVOKE ALL ON FUNCTION public.admin_overview_row() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_overview_row() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_is_hidden(p_table text, p_id uuid)
 RETURNS TABLE(is_shadow_hidden boolean, is_takedown boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT public.is_shadow_hidden(p_table, p_id), public.is_takedown(p_table, p_id)
$function$;

REVOKE ALL ON FUNCTION public.admin_is_hidden(text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_is_hidden(text,uuid) TO authenticated, service_role;

CREATE VIEW public.v_admin_overview AS
 SELECT snapshot_at,
    total_users,
    frozen_users,
    active_users,
    games_created_this_week,
    reports_open,
    reports_resolved,
    verified_profiles_total,
    verified_players,
    verified_organisers
   FROM admin_overview_row() admin_overview_row(snapshot_at, total_users, frozen_users, active_users, games_created_this_week, reports_open, reports_resolved, verified_profiles_total, verified_players, verified_organisers);
REVOKE ALL ON public.v_admin_overview FROM PUBLIC, anon, authenticated;
GRANT REFERENCES, TRIGGER ON public.v_admin_overview TO anon, authenticated;
GRANT ALL ON public.v_admin_overview TO service_role;

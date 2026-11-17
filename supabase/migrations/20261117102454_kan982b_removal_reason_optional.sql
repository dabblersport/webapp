-- KAN-982b: the app that is live today calls rpc_remove_player(p_game_id, p_profile_id) and
-- rpc_meetup_remove_attendee(p_meetup_id, p_user_id) without a reason. KAN-982 refused that with reason_required,
-- so live removal broke. Until the frontend ships the required reason field, a missing or blank reason is
-- accepted again. The notice then shows the organiser's name and no reason line. Over 500 characters is still
-- refused. TODO (docs/SCHEMA.md §21): once the reason field ships, a later migration enforces reason_required.
--
-- No DROP: the 3-argument functions keep their signature (p_reason DEFAULT NULL, so 2-argument calls resolve), their
-- ACL and their attributes; only the reason check and the notice args change (CREATE OR REPLACE).
-- Templates: "{organiser} removed you{reason_line}" / "أزالك {organiser}{reason_line}". reason_line is ': <reason>'
-- when a reason exists and absent otherwise (renders empty). args.reason keeps the raw reason when given.

-- 0. Pre-image guard ---------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_remove_player(uuid,uuid,text)'::regprocedure))
       <> 'e6f1ec0a1f2809d9615f7477e2a7fb3c' THEN
    RAISE EXCEPTION 'KAN-982b guard: rpc_remove_player changed since KAN-982';
  END IF;
  IF md5(pg_get_functiondef('public.rpc_meetup_remove_attendee(uuid,uuid,text)'::regprocedure))
       <> 'c8e42cc8875f1e6a8a5081c781686d5a' THEN
    RAISE EXCEPTION 'KAN-982b guard: rpc_meetup_remove_attendee changed since KAN-982';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('game.removed', 'meetup.removed')
         AND md5(body_template_en || body_template_ar) = '9ffe1f85e2206daf542dc10eb9ba97ae') <> 2 THEN
    RAISE EXCEPTION 'KAN-982b guard: removal templates changed since KAN-982';
  END IF;
END
$guard$;

-- 1. Templates: the reason line is optional -----------------------------------------------------------------------------
UPDATE public.notification_kinds
   SET body_template_en = '{organiser} removed you{reason_line}',
       body_template_ar = 'أزالك {organiser}{reason_line}'
 WHERE key IN ('game.removed', 'meetup.removed');

-- 2. rpc_remove_player: reason optional for now --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_remove_player(p_game_id uuid, p_profile_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_creator uuid;
  v_title   text;
  v_target  record;
  v_reason  text := nullif(btrim(p_reason), '');
  v_name    text;
  v_before  int;
  v_after   int;
  v_left_at timestamptz;
begin
  select ev.creator_user_id, ev.title into v_creator, v_title
  from public.games g
  join public.events ev on ev.id = g.event_id and ev.event_type = 'game'
  where g.id = p_game_id and ev.is_cancelled = false;
  if v_creator is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  if v_creator <> auth.uid() and not public.is_admin(auth.uid()) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  -- KAN-982b: a reason is optional until the app sends one (TODO: enforce reason_required, SCHEMA §21).
  if char_length(v_reason) > 500 then
    raise exception using errcode='P0001', message='reason_too_long';
  end if;

  select * into v_target
  from public.game_roster
  where game_id = p_game_id and profile_id = p_profile_id and status = 'active'
  for update;
  if not found then
    raise exception using errcode='P0001', message='player_not_on_roster';
  end if;
  if v_target.role = 'host' then
    raise exception using errcode='P0001', message='cannot_remove_host';
  end if;

  select count(*) into v_before from public.game_waitlist where game_id = p_game_id;

  -- the roster trigger promotes the next person on the waitlist
  update public.game_roster
     set status = 'kicked', left_at = now()
   where game_id = p_game_id and profile_id = p_profile_id
  returning left_at into v_left_at;

  v_name := public.kan982_display_name(auth.uid());
  perform public.kan982_notify(v_target.user_id, 'game.removed',
    jsonb_build_object('title', v_title)
      || case when v_reason is not null
              then jsonb_build_object('reason', v_reason, 'reason_line', ': ' || v_reason)
              else '{}'::jsonb end
      || case when v_name is not null then jsonb_build_object('organiser', v_name)
              else jsonb_build_object('organiser_en', 'The organiser', 'organiser_ar', 'المنظّم') end,
    'game', p_game_id, auth.uid(),
    'game.removed:' || v_target.id || ':' || public.kan982_tkey(v_left_at));

  select count(*) into v_after from public.game_waitlist where game_id = p_game_id;
  if v_after < v_before then return 'removed_promoted_waitlist'; end if;
  return 'removed';
end$function$;

-- 3. rpc_meetup_remove_attendee: reason optional for now -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_meetup_remove_attendee(p_meetup_id uuid, p_user_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me       uuid := auth.uid();
  m        record;
  v_reason text := nullif(btrim(p_reason), '');
  v_rsvp   record;
  v_name   text;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select mt.id, e.creator_user_id, e.title into m
    from public.meetups mt
    join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id for update of mt;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not (m.creator_user_id = me or public.is_admin(me)) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if p_user_id = m.creator_user_id then
    raise exception using errcode='P0001', message='cannot_remove_host';
  end if;

  -- KAN-982b: a reason is optional until the app sends one (TODO: enforce reason_required, SCHEMA §21).
  if char_length(v_reason) > 500 then
    raise exception using errcode='P0001', message='reason_too_long';
  end if;

  update public.meetup_rsvps
     set status = 'removed', updated_at = now()
   where meetup_id = p_meetup_id and user_id = p_user_id
     and status in ('going','interested','pending')
  returning * into v_rsvp;
  if not found then
    raise exception using errcode='P0001', message='attendee_not_found';
  end if;

  v_name := public.kan982_display_name(me);
  perform public.kan982_notify(p_user_id, 'meetup.removed',
    jsonb_build_object('title', m.title)
      || case when v_reason is not null
              then jsonb_build_object('reason', v_reason, 'reason_line', ': ' || v_reason)
              else '{}'::jsonb end
      || case when v_name is not null then jsonb_build_object('organiser', v_name)
              else jsonb_build_object('organiser_en', 'The organiser', 'organiser_ar', 'المنظّم') end,
    'meetup', p_meetup_id, me,
    'meetup.removed:' || v_rsvp.id || ':' || public.kan982_tkey(v_rsvp.updated_at));
  return 'removed';
end;
$function$;

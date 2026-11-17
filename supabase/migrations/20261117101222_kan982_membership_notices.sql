-- KAN-982 [W1-B4] Membership: removal with reason, join declined, re-join, waitlist promotion with a no-penalty
-- cancel, invite and roster notices. Every notice here is sent through notify_v2 (KAN-974), with a stable dedupe key.
--
-- One sender per kind. In this same migration:
--   game.removed           rpc_remove_player              process_notification_event -> notify_v2 (with reason)
--   game.join_accepted     rpc_decide_join_request        process_notification_event -> notify_v2
--   game.waitlist_promoted trg_game_waitlist_promoted_notify (dropped)  -> kan982_promote_waitlist
--   game.player_joined     fn_public_activities_notify game_join branch (removed) -> kan982_roster_after
-- Activated here (inactive until now, no old sender): game.join_declined, game.invite_accepted/declined/withdrawn/
-- expired, game.player_left, game.full, game.waitlist_joined, meetup.removed, meetup.player_left.
--
-- Promotion: one AFTER UPDATE trigger on game_roster promotes whenever an active non-host row becomes left or
-- kicked, by any path (rpc_leave_game, rpc_remove_player, rpc_cancel_waitlist_place, a direct update). The inline
-- promotion in rpc_leave_game and rpc_remove_player is removed so nobody is promoted twice. The dead self-leave
-- policy (authenticated has no UPDATE grant on game_roster) is dropped: leaving goes through the RPCs.
--
-- Nothing here is a trigger on events (KAN-976 owns that signal).

-- 0. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_expected CONSTANT jsonb := jsonb_build_object(
    'fn_public_activities_notify()',            'bdc3b8625c1c0ef70ba8d5cb55dbc7ac',
    'rpc_decide_join_request(uuid,boolean)',     '80cce22d50cba70acfa436ea9e6d2db4',
    'rpc_leave_game(text,uuid)',                 '262c97f2fef3039c41ac8b2e6d6f7a70',
    'rpc_meetup_remove_attendee(uuid,uuid)',     'f865a227c951d3fe7e5e55e6615da156',
    'rpc_remove_player(uuid,uuid)',              'e27b5b9c54799fddbeeef7ff55ad2d9d',
    'trg_game_waitlist_promoted_notify()',       'b86d020fd1f9457eb144139e6f6c4c62');
  k text;
  v_h text;
BEGIN
  FOR k IN SELECT jsonb_object_keys(v_expected) LOOP
    SELECT md5(pg_get_functiondef(to_regprocedure('public.' || k))) INTO v_h;
    IF v_h IS DISTINCT FROM v_expected ->> k THEN
      RAISE EXCEPTION 'KAN-982 guard: % changed since it was read (md5 %)', k, v_h;
    END IF;
  END LOOP;
  IF to_regprocedure('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN-982 guard: notify_v2 missing (KAN-974)';
  END IF;
  IF pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conname = 'meetup_rsvps_status_check'
                            AND conrelid = 'public.meetup_rsvps'::regclass))
     <> 'CHECK ((status = ANY (ARRAY[''going''::text, ''interested''::text, ''pending''::text, ''declined''::text, ''cancelled''::text])))' THEN
    RAISE EXCEPTION 'KAN-982 guard: meetup_rsvps_status_check changed';
  END IF;
  IF pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conname = 'game_invites_status_check'
                            AND conrelid = 'public.game_invites'::regclass))
     <> 'CHECK ((status = ANY (ARRAY[''pending''::text, ''accepted''::text, ''declined''::text, ''expired''::text])))' THEN
    RAISE EXCEPTION 'KAN-982 guard: game_invites_status_check changed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'game_roster'
                  AND policyname = 'roster_update_self_leave') THEN
    RAISE EXCEPTION 'KAN-982 guard: roster_update_self_leave missing';
  END IF;
  IF has_table_privilege('authenticated', 'public.game_roster', 'UPDATE') THEN
    RAISE EXCEPTION 'KAN-982 guard: authenticated gained UPDATE on game_roster; the self-leave analysis no longer holds';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('game.join_declined', 'game.invite_accepted', 'game.invite_declined', 'game.invite_withdrawn',
                     'game.invite_expired', 'game.player_left', 'game.full', 'game.waitlist_joined',
                     'meetup.removed', 'meetup.player_left') AND NOT is_active) <> 10 THEN
    RAISE EXCEPTION 'KAN-982 guard: the 10 kinds to activate are not all present and inactive';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('game.removed', 'game.waitlist_promoted', 'game.join_accepted', 'game.player_joined')
         AND is_active) <> 4 THEN
    RAISE EXCEPTION 'KAN-982 guard: the 4 kinds to move are not all active';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules
              WHERE enabled AND kind_key IN ('game.removed', 'game.waitlist_promoted', 'game.join_accepted',
                     'game.player_joined', 'game.join_declined', 'game.invite_accepted', 'game.invite_declined',
                     'game.invite_withdrawn', 'game.invite_expired', 'game.player_left', 'game.full',
                     'game.waitlist_joined', 'meetup.removed', 'meetup.player_left')) THEN
    RAISE EXCEPTION 'KAN-982 guard: a membership kind has an aggregation rule; notify_v2 would not dedupe it';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname LIKE 'kan982%')
     OR EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan982_expire_game_invites') THEN
    RAISE EXCEPTION 'KAN-982 guard: KAN-982 objects already exist';
  END IF;
END
$guard$;

-- 1. Statuses ---------------------------------------------------------------------------------------------------------
-- Meetup removal is its own status, distinct from leaving ('cancelled').
ALTER TABLE public.meetup_rsvps DROP CONSTRAINT meetup_rsvps_status_check;
ALTER TABLE public.meetup_rsvps ADD CONSTRAINT meetup_rsvps_status_check
  CHECK (status = ANY (ARRAY['going'::text, 'interested'::text, 'pending'::text, 'declined'::text, 'cancelled'::text,
                             'removed'::text]));

ALTER TABLE public.game_invites DROP CONSTRAINT game_invites_status_check;
ALTER TABLE public.game_invites ADD CONSTRAINT game_invites_status_check
  CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'expired'::text,
                             'withdrawn'::text]));

-- 2. Kinds: templates for the moved kinds, then activation ---------------------------------------------------------
UPDATE public.notification_kinds
   SET title_template_en = 'You were removed from {title}',
       body_template_en  = '{organiser} removed you: {reason}',
       title_template_ar = 'تمت إزالتك من {title}',
       body_template_ar  = 'أزالك {organiser}: {reason}'
 WHERE key = 'game.removed';

UPDATE public.notification_kinds
   SET title_template_en = 'You got a place in {title}',
       body_template_en  = 'A place opened and it''s yours. Can''t make it? Cancel with no penalty.',
       title_template_ar = 'حصلت على مكان في {title}',
       body_template_ar  = 'توفّر مكان وأصبح لك. لا تستطيع الحضور؟ ألغِ دون أي عقوبة.'
 WHERE key = 'game.waitlist_promoted';

UPDATE public.notification_kinds
   SET title_template_en = 'Your request to join {title} was accepted',
       title_template_ar = 'تم قبول طلب انضمامك إلى {title}'
 WHERE key = 'game.join_accepted';

UPDATE public.notification_kinds
   SET title_template_en = '{actor} joined {title}',
       title_template_ar = '{actor} انضم إلى {title}'
 WHERE key = 'game.player_joined';

UPDATE public.notification_kinds SET is_active = true
 WHERE key IN ('game.join_declined', 'game.invite_accepted', 'game.invite_declined', 'game.invite_withdrawn',
               'game.invite_expired', 'game.player_left', 'game.full', 'game.waitlist_joined',
               'meetup.removed', 'meetup.player_left');

-- 3. Internal helpers (no client EXECUTE) -------------------------------------------------------------------------------
CREATE FUNCTION public.kan982_game_ctx(p_game_id uuid)
 RETURNS TABLE(host_user_id uuid, title text, start_at timestamptz, is_cancelled boolean, capacity integer)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT e.creator_user_id, e.title, e.start_at, e.is_cancelled, e.capacity
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE g.id = p_game_id
$function$;

CREATE FUNCTION public.kan982_display_name(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT p.display_name FROM public.profiles p
   WHERE p.user_id = p_user_id AND p.is_active = true
   ORDER BY p.updated_at DESC NULLS LAST LIMIT 1
$function$;

-- Stable text form of a timestamp for dedupe keys.
CREATE FUNCTION public.kan982_tkey(p_ts timestamptz)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  SELECT to_char(p_ts AT TIME ZONE 'UTC', 'YYYYMMDD"T"HH24MISS.US')
$function$;

-- A notice never rolls back the membership change that caused it.
CREATE FUNCTION public.kan982_notify(p_to uuid, p_kind text, p_args jsonb, p_entity_type text, p_entity_id uuid,
                                     p_actor uuid, p_dedupe_key text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF p_to IS NULL THEN RETURN NULL; END IF;
  RETURN public.notify_v2(p_to, p_kind, p_args, p_entity_type, p_entity_id, p_actor, NULL, p_dedupe_key);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'kan982_notify % to %: % (%)', p_kind, p_to, SQLERRM, SQLSTATE;
  RETURN NULL;
END;
$function$;

-- 4. Waitlist promotion: the only promoter --------------------------------------------------------------------------
CREATE FUNCTION public.kan982_promote_waitlist(p_game_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  c   record;
  w   record;
  n   integer := 0;
BEGIN
  SELECT * INTO c FROM public.kan982_game_ctx(p_game_id);
  IF NOT FOUND OR c.is_cancelled OR c.start_at <= now() THEN
    RETURN 0;
  END IF;

  PERFORM 1 FROM public.games WHERE id = p_game_id FOR UPDATE;

  FOR w IN SELECT * FROM public.game_waitlist
            WHERE game_id = p_game_id ORDER BY position, joined_at LOOP
    -- With a capacity, promote while there is room. Without one (game_slots_left reads 0), promote one person per
    -- freed place, as the old inline code did.
    EXIT WHEN c.capacity IS NOT NULL AND public.game_slots_left(p_game_id) <= 0;
    EXIT WHEN c.capacity IS NULL AND n >= 1;
    BEGIN
      INSERT INTO public.game_roster (game_id, profile_id, role, status)
      VALUES (p_game_id, w.profile_id, 'player', 'active')
      ON CONFLICT (game_id, profile_id) DO UPDATE SET status = 'active', left_at = NULL;
      DELETE FROM public.game_waitlist WHERE game_id = p_game_id AND profile_id = w.profile_id;
      PERFORM public.kan982_notify(w.user_id, 'game.waitlist_promoted', jsonb_build_object('title', c.title),
        'game', p_game_id, c.host_user_id,
        'game.waitlist_promoted:' || p_game_id || ':' || w.profile_id || ':' || public.kan982_tkey(w.joined_at));
      n := n + 1;
    EXCEPTION WHEN OTHERS THEN
      -- e.g. the waitlisted user is now frozen or blocked by the host: skip them, try the next one
      RAISE WARNING 'kan982_promote_waitlist: could not promote % in %: %', w.profile_id, p_game_id, SQLERRM;
    END;
  END LOOP;
  RETURN n;
END;
$function$;

-- 5. Roster trigger: joined / re-joined, full, left, promotion ------------------------------------------------------
CREATE FUNCTION public.kan982_roster_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  c     record;
  v_key text;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NULL;
  END IF;
  SELECT * INTO c FROM public.kan982_game_ctx(NEW.game_id);

  IF NEW.status = 'active' AND (TG_OP = 'INSERT' OR OLD.status <> 'active') THEN
    -- One key per join: the first join, or the re-join after the recorded leave.
    v_key := NEW.id || ':' || CASE WHEN TG_OP = 'INSERT' THEN 'first'
                                  ELSE 'rejoin:' || COALESCE(public.kan982_tkey(OLD.left_at), 'unknown') END;

    -- A pending invite to this player for this game is now accepted (game.invite_accepted, via its trigger).
    UPDATE public.game_invites SET status = 'accepted', responded_at = now()
     WHERE game_id = NEW.game_id AND to_user_id = NEW.user_id AND status = 'pending';

    -- Tell the host, unless the host is the one joining or the host made it happen (approval).
    IF NEW.role <> 'host' AND c.host_user_id IS NOT NULL AND NEW.user_id <> c.host_user_id
       AND auth.uid() IS DISTINCT FROM c.host_user_id THEN
      PERFORM public.kan982_notify(c.host_user_id, 'game.player_joined', jsonb_build_object('title', c.title),
        'game', NEW.game_id, NEW.user_id, 'game.player_joined:' || v_key);
    END IF;

    IF c.capacity IS NOT NULL AND c.host_user_id IS NOT NULL AND public.game_slots_left(NEW.game_id) = 0 THEN
      PERFORM public.kan982_notify(c.host_user_id, 'game.full', jsonb_build_object('title', c.title),
        'game', NEW.game_id, NULL, 'game.full:' || NEW.game_id || ':' || v_key);
    END IF;

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status IN ('left', 'kicked') THEN
    IF NEW.status = 'left' AND NEW.role <> 'host' AND c.host_user_id IS NOT NULL
       AND NEW.user_id <> c.host_user_id THEN
      PERFORM public.kan982_notify(c.host_user_id, 'game.player_left', jsonb_build_object('title', c.title),
        'game', NEW.game_id, NEW.user_id,
        'game.player_left:' || NEW.id || ':' || public.kan982_tkey(COALESCE(NEW.left_at, now())));
    END IF;
    IF OLD.role <> 'host' THEN
      PERFORM public.kan982_promote_waitlist(NEW.game_id);
    END IF;
  END IF;

  RETURN NULL;
END;
$function$;

CREATE TRIGGER trg_kan982_roster_after
  AFTER INSERT OR UPDATE OF status ON public.game_roster
  FOR EACH ROW EXECUTE FUNCTION public.kan982_roster_after();

-- 6. Waitlist joined --------------------------------------------------------------------------------------------------
CREATE FUNCTION public.kan982_waitlist_after_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  c record;
BEGIN
  SELECT * INTO c FROM public.kan982_game_ctx(NEW.game_id);
  PERFORM public.kan982_notify(NEW.user_id, 'game.waitlist_joined',
    jsonb_build_object('title', c.title, 'position', NEW.position),
    'game', NEW.game_id, NULL,
    'game.waitlist_joined:' || NEW.game_id || ':' || NEW.profile_id || ':' || public.kan982_tkey(NEW.joined_at));
  RETURN NULL;
END;
$function$;

CREATE TRIGGER trg_kan982_waitlist_after_insert
  AFTER INSERT ON public.game_waitlist
  FOR EACH ROW EXECUTE FUNCTION public.kan982_waitlist_after_insert();

-- The old promotion notice (fired on every waitlist delete, whether or not it was a promotion).
DROP TRIGGER trg_game_waitlist_promoted_notify ON public.game_waitlist;
DROP FUNCTION public.trg_game_waitlist_promoted_notify();

-- 7. Invite outcomes --------------------------------------------------------------------------------------------------
CREATE FUNCTION public.kan982_game_invite_after_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  c         record;
  v_inviter uuid;
  v_to      uuid;
  v_actor   uuid;
  v_kind    text;
BEGIN
  SELECT * INTO c FROM public.kan982_game_ctx(NEW.game_id);
  SELECT p.user_id INTO v_inviter FROM public.profiles p WHERE p.id = NEW.invited_by_profile_id;
  v_inviter := COALESCE(v_inviter, c.host_user_id);

  CASE NEW.status
    WHEN 'accepted'  THEN v_kind := 'game.invite_accepted';  v_to := v_inviter;      v_actor := NEW.to_user_id;
    WHEN 'declined'  THEN v_kind := 'game.invite_declined';  v_to := v_inviter;      v_actor := NEW.to_user_id;
    WHEN 'withdrawn' THEN v_kind := 'game.invite_withdrawn'; v_to := NEW.to_user_id; v_actor := COALESCE(auth.uid(), v_inviter);
    WHEN 'expired'   THEN v_kind := 'game.invite_expired';   v_to := NEW.to_user_id; v_actor := NULL;
    ELSE RETURN NULL;
  END CASE;

  IF v_to IS NULL OR v_to = v_actor THEN RETURN NULL; END IF;
  PERFORM public.kan982_notify(v_to, v_kind, jsonb_build_object('title', c.title), 'game', NEW.game_id, v_actor,
    v_kind || ':' || NEW.id);
  RETURN NULL;
END;
$function$;

CREATE TRIGGER trg_kan982_game_invite_after_status
  AFTER UPDATE OF status ON public.game_invites
  FOR EACH ROW WHEN (OLD.status = 'pending' AND NEW.status IS DISTINCT FROM 'pending')
  EXECUTE FUNCTION public.kan982_game_invite_after_status();

-- 8. Meetup participant left (going -> cancelled by the attendee themselves) ------------------------------------------
CREATE FUNCTION public.kan982_meetup_rsvp_left()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_host  uuid;
  v_title text;
BEGIN
  IF auth.uid() IS DISTINCT FROM NEW.user_id THEN RETURN NULL; END IF;
  SELECT e.creator_user_id, e.title INTO v_host, v_title
    FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE m.id = NEW.meetup_id;
  IF v_host IS NULL OR v_host = NEW.user_id THEN RETURN NULL; END IF;
  PERFORM public.kan982_notify(v_host, 'meetup.player_left', jsonb_build_object('title', v_title),
    'meetup', NEW.meetup_id, NEW.user_id,
    'meetup.player_left:' || NEW.id || ':' || public.kan982_tkey(NEW.updated_at));
  RETURN NULL;
END;
$function$;

CREATE TRIGGER trg_kan982_meetup_rsvp_left
  AFTER UPDATE OF status ON public.meetup_rsvps
  FOR EACH ROW WHEN (OLD.status = 'going' AND NEW.status = 'cancelled')
  EXECUTE FUNCTION public.kan982_meetup_rsvp_left();

-- 9. Replaced RPCs ----------------------------------------------------------------------------------------------------
-- 9a. rpc_remove_player: reason required; game.removed via notify_v2; promotion by the roster trigger.
DROP FUNCTION public.rpc_remove_player(uuid, uuid);
CREATE FUNCTION public.rpc_remove_player(p_game_id uuid, p_profile_id uuid, p_reason text DEFAULT NULL)
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
  -- KAN-982 (F-13): a removal needs a reason; the removed player is shown it with the organiser's name.
  if v_reason is null then
    raise exception using errcode='P0001', message='reason_required';
  end if;
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
    jsonb_build_object('title', v_title, 'reason', v_reason)
      || case when v_name is not null then jsonb_build_object('organiser', v_name)
              else jsonb_build_object('organiser_en', 'The organiser', 'organiser_ar', 'المنظّم') end,
    'game', p_game_id, auth.uid(),
    'game.removed:' || v_target.id || ':' || public.kan982_tkey(v_left_at));

  select count(*) into v_after from public.game_waitlist where game_id = p_game_id;
  if v_after < v_before then return 'removed_promoted_waitlist'; end if;
  return 'removed';
end$function$;

REVOKE ALL ON FUNCTION public.rpc_remove_player(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_remove_player(uuid, uuid, text) TO authenticated, service_role;

-- 9b. rpc_meetup_remove_attendee: reason required; its own 'removed' status; meetup.removed via notify_v2.
DROP FUNCTION public.rpc_meetup_remove_attendee(uuid, uuid);
CREATE FUNCTION public.rpc_meetup_remove_attendee(p_meetup_id uuid, p_user_id uuid, p_reason text DEFAULT NULL)
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

  -- KAN-982 (F-13): a removal needs a reason.
  if v_reason is null then
    raise exception using errcode='P0001', message='reason_required';
  end if;
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
    jsonb_build_object('title', m.title, 'reason', v_reason)
      || case when v_name is not null then jsonb_build_object('organiser', v_name)
              else jsonb_build_object('organiser_en', 'The organiser', 'organiser_ar', 'المنظّم') end,
    'meetup', p_meetup_id, me,
    'meetup.removed:' || v_rsvp.id || ':' || public.kan982_tkey(v_rsvp.updated_at));
  return 'removed';
end;
$function$;

REVOKE ALL ON FUNCTION public.rpc_meetup_remove_attendee(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_meetup_remove_attendee(uuid, uuid, text) TO authenticated, service_role;

-- 9c. rpc_decide_join_request (from the live definition): accepted and declined via notify_v2. An approval onto the
-- waitlist is told by game.waitlist_joined (waitlist trigger), not by a "you're in" notice.
CREATE OR REPLACE FUNCTION public.rpc_decide_join_request(p_request_id uuid, p_approve boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  req   record;
  slots int;
BEGIN
  -- KAN-798: host from events; the lock set stays the pre-image's (request row and games row).
  SELECT jr.*, e.creator_user_id, e.title AS game_title
  INTO req
  FROM public.game_join_requests jr
  JOIN public.games g ON g.id = jr.game_id
  JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
  WHERE jr.id = p_request_id
  FOR UPDATE OF jr, g;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='request_not_found';
  END IF;

  IF req.creator_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  IF req.status <> 'pending' THEN RETURN 'already_decided'; END IF;

  IF p_approve THEN
    slots := public.game_slots_left(req.game_id);

    UPDATE public.game_join_requests
       SET status = 'approved', decided_at = now()
     WHERE id = p_request_id;

    IF slots > 0 THEN
      INSERT INTO public.game_roster(game_id, profile_id, role, status)
      VALUES (req.game_id, req.from_profile_id, 'player', 'active')
      ON CONFLICT (game_id, profile_id) DO UPDATE
        SET status = 'active', left_at = null;

      PERFORM public.kan982_notify(req.from_user_id, 'game.join_accepted',
        jsonb_build_object('title', req.game_title), 'game', req.game_id, auth.uid(),
        'game.join_accepted:' || p_request_id);

      RETURN 'approved_joined';
    ELSE
      INSERT INTO public.game_waitlist(game_id, profile_id, user_id, position)
      SELECT req.game_id, req.from_profile_id, req.from_user_id,
             COALESCE((SELECT MAX(position)+1 FROM public.game_waitlist WHERE game_id = req.game_id), 1)
      ON CONFLICT DO NOTHING;

      RETURN 'approved_waitlisted';
    END IF;
  ELSE
    UPDATE public.game_join_requests
       SET status = 'denied', decided_at = now()
     WHERE id = p_request_id;

    PERFORM public.kan982_notify(req.from_user_id, 'game.join_declined',
      jsonb_build_object('title', req.game_title), 'game', req.game_id, auth.uid(),
      'game.join_declined:' || p_request_id);
    RETURN 'denied';
  END IF;
END;
$function$;

-- 9d. rpc_leave_game (from the live definition): the roster trigger promotes; the return values are unchanged.
CREATE OR REPLACE FUNCTION public.rpc_leave_game(p_actor_type text, p_game_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  pid uuid := public.choose_actor(p_actor_type);
  was_active boolean;
  v_before int;
  v_after  int;
BEGIN
  SELECT count(*) INTO v_before FROM public.game_waitlist WHERE game_id = p_game_id;
  -- KAN-982: promotion happens in trg_kan982_roster_after, for this path and every other.
  UPDATE public.game_roster
     SET status = 'left', left_at = now()
   WHERE game_id = p_game_id AND profile_id = pid AND status = 'active'
  RETURNING true INTO was_active;
  IF NOT coalesce(was_active, false) THEN RETURN 'not_on_roster'; END IF;   -- KAN-717 F2: no row updated leaves was_active NULL
  SELECT count(*) INTO v_after FROM public.game_waitlist WHERE game_id = p_game_id;
  IF v_after < v_before THEN RETURN 'left_promoted_waitlist'; END IF;
  RETURN 'left';
END;
$function$;

-- 9e. fn_public_activities_notify (from the live definition): game_join no longer notifies here
-- (game.player_joined is sent by trg_kan982_roster_after, which also covers a re-join). meetup_join is unchanged.
CREATE OR REPLACE FUNCTION public.fn_public_activities_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_target_user_id uuid;
  v_kind_key       text;
  v_entity_type    text;
  v_entity_id      uuid;
BEGIN
  -- Only act on INSERT of non-deleted activities that have a target
  IF TG_OP <> 'INSERT' THEN RETURN NEW; END IF;
  IF NEW.is_deleted THEN RETURN NEW; END IF;
  IF NEW.target_profile_id IS NULL THEN RETURN NEW; END IF;

  -- Skip self-actions
  IF NEW.target_profile_id = NEW.actor_profile_id THEN RETURN NEW; END IF;

  -- Only handle types NOT already covered by per-domain notification triggers
  -- (comment → trg_post_comment_notify, reaction → trg_post_reaction_notify,
  --  follow → trg_profile_follow_notify, badge → trg_badge_awarded_notify,
  --  game_join → trg_kan982_roster_after, KAN-982)
  IF NEW.activity_type NOT IN ('meetup_join') THEN
    RETURN NEW;
  END IF;

  -- Resolve target profile → user_id
  SELECT user_id INTO v_target_user_id
  FROM public.profiles WHERE id = NEW.target_profile_id;

  IF v_target_user_id IS NULL THEN RETURN NEW; END IF;
  IF v_target_user_id = NEW.actor_user_id THEN RETURN NEW; END IF;

  v_kind_key := CASE NEW.activity_type
    WHEN 'meetup_join' THEN 'meetup.player_joined'
    ELSE NULL
  END;

  IF v_kind_key IS NULL THEN RETURN NEW; END IF;

  v_entity_type := CASE NEW.activity_type
    WHEN 'meetup_join' THEN 'meetup'
  END;
  v_entity_id := COALESCE(NEW.parent_activity_id, NEW.id);

  PERFORM public.process_notification_event(
    v_target_user_id,
    v_kind_key,
    v_entity_type,
    v_entity_id,
    NEW.actor_user_id
  );

  RETURN NEW;
END;
$function$;

-- 10. New RPCs -------------------------------------------------------------------------------------------------------
-- G-14: give up a place with no penalty. Promoted (or any non-host) player: the place is released and the next
-- person on the waitlist is promoted by the roster trigger. Still on the waitlist: the waitlist place is given up.
-- Refused once the game has started or is cancelled. Nothing is recorded against the player.
CREATE FUNCTION public.rpc_cancel_waitlist_place(p_game_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  c     record;
  v_n   int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'auth_required';
  END IF;
  SELECT * INTO c FROM public.kan982_game_ctx(p_game_id);
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'game_not_found';
  END IF;
  IF c.is_cancelled THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'cancelled';
  END IF;
  IF c.start_at <= now() THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'started';
  END IF;

  UPDATE public.game_roster SET status = 'left', left_at = now()
   WHERE game_id = p_game_id AND user_id = v_uid AND status = 'active' AND role <> 'host';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n > 0 THEN
    RETURN 'place_released';
  END IF;

  DELETE FROM public.game_waitlist WHERE game_id = p_game_id AND user_id = v_uid;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n > 0 THEN
    RETURN 'waitlist_left';
  END IF;

  RAISE EXCEPTION USING errcode = 'P0001', message = 'not_on_waitlist';
END;
$function$;

-- The invitee declines a pending game invite (game.invite_declined to the inviter).
CREATE FUNCTION public.rpc_decline_game_invite(p_invite_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  i record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'auth_required';
  END IF;
  SELECT * INTO i FROM public.game_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND OR i.to_user_id <> auth.uid() THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'invite_not_found';
  END IF;
  IF i.status <> 'pending' THEN
    RETURN 'already_' || i.status;
  END IF;
  UPDATE public.game_invites SET status = 'declined', responded_at = now() WHERE id = p_invite_id;
  RETURN 'declined';
END;
$function$;

-- The host, the inviter or an admin withdraws a pending game invite (game.invite_withdrawn to the invitee).
CREATE FUNCTION public.rpc_withdraw_game_invite(p_invite_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  i         record;
  c         record;
  v_inviter uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'auth_required';
  END IF;
  SELECT * INTO i FROM public.game_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'invite_not_found';
  END IF;
  SELECT * INTO c FROM public.kan982_game_ctx(i.game_id);
  SELECT p.user_id INTO v_inviter FROM public.profiles p WHERE p.id = i.invited_by_profile_id;
  IF auth.uid() IS DISTINCT FROM c.host_user_id AND auth.uid() IS DISTINCT FROM v_inviter
     AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host';
  END IF;
  IF i.status <> 'pending' THEN
    RETURN 'already_' || i.status;
  END IF;
  UPDATE public.game_invites SET status = 'withdrawn', responded_at = now() WHERE id = p_invite_id;
  RETURN 'withdrawn';
END;
$function$;

-- Pending invites to a game that has started or was cancelled expire (game.invite_expired to the invitee).
CREATE FUNCTION public.expire_game_invites()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  n int;
BEGIN
  UPDATE public.game_invites i
     SET status = 'expired', responded_at = now()
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE g.id = i.game_id AND i.status = 'pending' AND (e.start_at <= now() OR e.is_cancelled);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$function$;

SELECT cron.schedule('kan982_expire_game_invites', '*/5 * * * *', 'SELECT public.expire_game_invites()');

-- 11. Self-leave goes through the RPCs. The policy was dead (no UPDATE grant), and a promotion now follows any leave.
DROP POLICY roster_update_self_leave ON public.game_roster;

-- 12. Grants -----------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.kan982_game_ctx(uuid)                                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_display_name(uuid)                               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_tkey(timestamptz)                                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_notify(uuid, text, jsonb, text, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_promote_waitlist(uuid)                           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_roster_after()                                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_waitlist_after_insert()                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_game_invite_after_status()                       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan982_meetup_rsvp_left()                               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.expire_game_invites()                                   FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_game_invites() TO service_role;

REVOKE ALL ON FUNCTION public.rpc_cancel_waitlist_place(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_decline_game_invite(uuid)   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_withdraw_game_invite(uuid)  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_waitlist_place(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_decline_game_invite(uuid)   TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_withdraw_game_invite(uuid)  TO authenticated, service_role;

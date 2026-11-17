-- KAN-983b (PEER fix, comment 16444): rpc_answer_meetup_attendance(id, 'going') must refuse the same callers as
-- rpc_meetup_rsvp. The 'going' branch now runs can_current_user_rsvp_meetup and refuses on any denial except
-- 'already' (the caller is a current member, which this RPC requires). That covers frozen (cta not_allowed),
-- not visible, blocked by or blocking the host (can_view_with_scope -> is_blocked, cta not_visible), cancelled and
-- started. 'not_going' is unchanged (rpc_meetup_rsvp 'cancel' already applies the same rule).
-- Authored from pg_get_functiondef on the live catalogue; CREATE OR REPLACE keeps the owner, attributes and proacl.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_answer_meetup_attendance(uuid,text)'::regprocedure))
     <> '29ee7225a2cb082b6057f0e78bb74bfb' THEN
    RAISE EXCEPTION 'KAN-983b guard: rpc_answer_meetup_attendance is not the version applied in 20261117102448';
  END IF;
  IF to_regprocedure('public.can_current_user_rsvp_meetup(uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-983b guard: can_current_user_rsvp_meetup(uuid,uuid) missing';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.rpc_answer_meetup_attendance(p_meetup_id uuid, p_answer text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_status text;
  v_d      jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'rpc_answer_meetup_attendance: not authenticated';
  END IF;
  IF p_answer IS NULL OR p_answer NOT IN ('going', 'not_going') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'rpc_answer_meetup_attendance: answer must be going or not_going';
  END IF;
  SELECT s.status INTO v_status FROM public.meetup_rsvps s
   WHERE s.meetup_id = p_meetup_id AND s.user_id = v_uid AND s.status IN ('going', 'interested')
     FOR UPDATE;
  IF v_status IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'not_attending';
  END IF;

  IF p_answer = 'not_going' THEN
    RETURN public.rpc_meetup_rsvp(p_meetup_id, 'cancel');
  END IF;

  -- KAN-983b: the same eligibility rpc_meetup_rsvp applies. For a current member the helper answers
  -- allowed=false / cta='already' once frozen, visibility (incl. blocks either way), cancelled and started all pass;
  -- every other denial is refused with the helper's cta, as rpc_meetup_rsvp does.
  v_d := public.can_current_user_rsvp_meetup(p_meetup_id, NULL);
  IF coalesce((v_d ->> 'allowed')::boolean, false) = false
     AND coalesce(v_d ->> 'cta', 'not_allowed') <> 'already' THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = coalesce(v_d ->> 'cta', 'not_allowed');
  END IF;

  IF v_status = 'going' THEN
    RETURN 'going';
  END IF;
  IF public.meetup_slots_left(p_meetup_id) = 0 THEN
    RETURN 'interested';
  END IF;
  UPDATE public.meetup_rsvps SET status = 'going', updated_at = now()
   WHERE meetup_id = p_meetup_id AND user_id = v_uid AND status = 'interested';
  RETURN 'going';
END;
$function$;

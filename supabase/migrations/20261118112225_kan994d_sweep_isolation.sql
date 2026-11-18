-- KAN-994d: attendance_sweep isolates each step. One bad event (or one bad attendance row) raising inside the sweep
-- no longer rolls back the whole run: each step runs in its own subtransaction, a failure is logged as a WARNING and
-- counted in the returned jsonb as 'failed'. Everything else is the live body verbatim (pg_get_functiondef, md5
-- guarded). CREATE OR REPLACE keeps owner (postgres), SECURITY DEFINER, search_path and the ACL
-- {postgres=X, service_role=X}; asserted below.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.attendance_sweep(timestamp with time zone)'::regprocedure)) <> 'da6bd2d1f41184c90f4e30974ecdbe5b' THEN
    RAISE EXCEPTION 'kan994d pre-image: attendance_sweep changed since 20261118103940';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.attendance_sweep(p_now timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; r record; v_res int; v_auto int := 0; v_dnh int := 0; v_wait int := 0; v_conf int := 0; v_exp int := 0;
        v_void int := 0; v_fail int := 0;
BEGIN
  -- 48h passed with no review request: confirmed, unless the event is now cancelled or did not happen (voided)
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_pending' AND a.no_show_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    BEGIN
      IF (SELECT ae.is_cancelled FROM public.attendance_event(r.event_id) ae)
         OR (SELECT l.state FROM public.attendance_lifecycle(r.event_id) l) = 'did_not_happen' THEN
        UPDATE public.event_attendance SET outcome = NULL, no_show_deadline = NULL, updated_at = p_now WHERE id = r.id;
        v_void := v_void + 1;
      ELSE
        UPDATE public.event_attendance SET outcome = 'no_show_confirmed', updated_at = p_now WHERE id = r.id;
        PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.no_show_confirmed', NULL);
        v_conf := v_conf + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'attendance_sweep: no_show expiry failed for attendance % (event %): % %', r.id, r.event_id, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  -- an unanswered review request after 48h is accepted in the player's favour (voided on a cancelled/did_not_happen event)
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_review' AND a.review_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    BEGIN
      IF (SELECT ae.is_cancelled FROM public.attendance_event(r.event_id) ae)
         OR (SELECT l.state FROM public.attendance_lifecycle(r.event_id) l) = 'did_not_happen' THEN
        UPDATE public.event_attendance SET outcome = NULL, review_deadline = NULL, updated_at = p_now WHERE id = r.id;
        v_void := v_void + 1;
      ELSE
        UPDATE public.event_attendance SET outcome = 'attended', review_decision = 'expired_accepted',
               review_decided_at = p_now, updated_at = p_now WHERE id = r.id;
        PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.review_accepted', NULL);
        v_exp := v_exp + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'attendance_sweep: review expiry failed for attendance % (event %): % %', r.id, r.event_id, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  -- never finalized: attendance_finalize_event locks the event and re-checks cancelled / lifecycle state / end + 24h
  FOR v_e IN SELECT e.id FROM public.events e
              WHERE e.event_type IN ('game', 'meetup') AND NOT COALESCE(e.is_cancelled, false)
                AND e.start_at >= timestamptz '2026-11-17 18:00:00+00'
                AND e.start_at + interval '24 hours' <= p_now
                AND NOT EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = e.id) LOOP
    BEGIN
      v_res := public.attendance_finalize_event(v_e, NULL, true, p_now);
      IF v_res = -3 THEN v_dnh := v_dnh + 1;
      ELSIF v_res = -2 THEN v_wait := v_wait + 1;
      ELSIF v_res >= 0 THEN v_auto := v_auto + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'attendance_sweep: finalize failed for event %: % %', v_e, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  RETURN jsonb_build_object('no_show_confirmed', v_conf, 'review_expired_accepted', v_exp, 'voided', v_void,
                            'auto_finalized', v_auto, 'did_not_happen', v_dnh, 'waiting_for_lifecycle', v_wait,
                            'failed', v_fail);
END;
$function$;

DO $post$
DECLARE p record;
BEGIN
  SELECT pg_get_userbyid(proowner) o, prosecdef s, proconfig c, proacl::text a INTO p
    FROM pg_proc WHERE oid = 'public.attendance_sweep(timestamp with time zone)'::regprocedure;
  IF p.o <> 'postgres' OR NOT p.s OR p.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR p.a <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan994d post-image: attendance_sweep attributes drifted: % % % %', p.o, p.s, p.c, p.a;
  END IF;
END
$post$;

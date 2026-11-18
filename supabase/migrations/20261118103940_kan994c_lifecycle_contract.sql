-- KAN-994c: attendance follows the KAN-995 contract exactly.
--
-- * attendance_lifecycle reads public.event_lifecycle_state only (static call, the fallback is gone: KAN-995 is live).
-- * attendance_finalize_event takes a per-event advisory lock, then RE-CHECKS the event after the lock:
--     cancelled                      -> records nothing, returns -1
--     did_not_happen                 -> finalization row reason 'did_not_happen', no outcomes, no no-shows, returns -3
--     auto and state not ended/auto_closed (a past 'scheduled' or 'started' = the KAN-995 worker has not closed it yet)
--       or effective_end_at + 24h not reached                          -> nothing, returns -2 (retried next sweep)
-- * attendance_sweep: candidates go through attendance_finalize_event (the lock and the re-check live there). Pending
--   no-shows and open reviews on an event that is now cancelled or did_not_happen are voided (outcome NULL), not
--   confirmed and not notified.
-- * rpc_attendance_finalize maps the negative results to errors (a race lost after its pre-checks).
-- * rpc_showup_rate excludes did_not_happen events.
-- Rebuilt from pg_get_functiondef on the live catalogue (md5 guarded). No DROP, no DELETE.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.attendance_sweep(timestamp with time zone)'::regprocedure)) <> 'c8e12f7b1e988b87cec1a4aff6ca65b1'
     OR md5(pg_get_functiondef('public.attendance_finalize_event(uuid,uuid,boolean,timestamp with time zone)'::regprocedure)) <> 'b09954a925e824e3a53f83541d2eebaf'
     OR md5(pg_get_functiondef('public.rpc_attendance_finalize(uuid)'::regprocedure)) <> '5f50062a11b6d579c83bac51e856eb9d'
     OR md5(pg_get_functiondef('public.attendance_lifecycle(uuid)'::regprocedure)) <> '28972fedf7120936623fa698a535c913'
     OR md5(pg_get_functiondef('public.rpc_showup_rate(uuid)'::regprocedure)) <> '4033ea3710fd91e4300052d541025491' THEN
    RAISE EXCEPTION 'kan994c pre-image: attendance functions changed since 20261118052547';
  END IF;
  IF to_regprocedure('public.event_lifecycle_state(uuid)') IS NULL THEN
    RAISE EXCEPTION 'kan994c pre-image: KAN-995 event_lifecycle_state is not live';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.attendance_lifecycle(p_event_id uuid, OUT state text, OUT effective_end_at timestamp with time zone, OUT source text)
 RETURNS record
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  SELECT l.state, l.effective_end_at INTO state, effective_end_at FROM public.event_lifecycle_state(p_event_id) l;
  source := 'event_lifecycle_state';
END;
$function$;

CREATE OR REPLACE FUNCTION public.attendance_finalize_event(p_event_id uuid, p_by uuid, p_auto boolean, p_now timestamp with time zone DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; lc record; v_uid uuid; v_mark text; v_n integer := 0;
BEGIN
  -- one finalizer per event; everything below is re-read after the lock
  PERFORM pg_advisory_xact_lock(hashtextextended('kan994:attendance:' || p_event_id::text, 0));
  IF EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id) THEN
    RETURN 0;
  END IF;
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF ev.event_type IS NULL OR ev.is_cancelled THEN
    RETURN -1;
  END IF;
  SELECT * INTO lc FROM public.attendance_lifecycle(p_event_id);
  IF lc.state = 'did_not_happen' THEN
    INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto, reason)
    VALUES (p_event_id, p_now, p_by, p_auto, 'did_not_happen') ON CONFLICT (event_id) DO NOTHING;
    RETURN -3;
  END IF;
  IF p_auto AND (lc.state NOT IN ('ended', 'auto_closed') OR lc.effective_end_at + interval '24 hours' > p_now) THEN
    RETURN -2;
  END IF;
  INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto, reason)
  VALUES (p_event_id, p_now, p_by, p_auto, CASE WHEN p_auto THEN 'auto' ELSE 'organiser' END)
  ON CONFLICT (event_id) DO NOTHING;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  FOR v_uid IN SELECT public.attendance_participants(p_event_id) LOOP
    INSERT INTO public.event_attendance (event_id, event_type, user_id)
    VALUES (p_event_id, ev.event_type, v_uid) ON CONFLICT (event_id, user_id) DO NOTHING;
    SELECT a.mark INTO v_mark FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = v_uid FOR UPDATE;
    IF v_mark = 'attended' THEN
      UPDATE public.event_attendance SET outcome = 'attended', finalized_at = p_now, updated_at = p_now
       WHERE event_id = p_event_id AND user_id = v_uid;
    ELSIF p_auto THEN
      -- assumption: auto-finalize marks nobody no-show
      UPDATE public.event_attendance SET outcome = 'unknown', finalized_at = p_now, updated_at = p_now
       WHERE event_id = p_event_id AND user_id = v_uid;
    ELSE
      UPDATE public.event_attendance
         SET outcome = 'no_show_pending', finalized_at = p_now, no_show_deadline = p_now + interval '48 hours',
             updated_at = p_now
       WHERE event_id = p_event_id AND user_id = v_uid;
      PERFORM public.attendance_notify(p_event_id, v_uid, 'activity.no_show_pending', p_by,
        jsonb_strip_nulls(jsonb_build_object('reason',
          (SELECT a.correction_reason FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = v_uid))));
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$function$;

CREATE OR REPLACE FUNCTION public.attendance_sweep(p_now timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; r record; v_res int; v_auto int := 0; v_dnh int := 0; v_wait int := 0; v_conf int := 0; v_exp int := 0;
        v_void int := 0;
BEGIN
  -- 48h passed with no review request: confirmed, unless the event is now cancelled or did not happen (voided)
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_pending' AND a.no_show_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    IF (SELECT ae.is_cancelled FROM public.attendance_event(r.event_id) ae)
       OR (SELECT l.state FROM public.attendance_lifecycle(r.event_id) l) = 'did_not_happen' THEN
      UPDATE public.event_attendance SET outcome = NULL, no_show_deadline = NULL, updated_at = p_now WHERE id = r.id;
      v_void := v_void + 1;
      CONTINUE;
    END IF;
    UPDATE public.event_attendance SET outcome = 'no_show_confirmed', updated_at = p_now WHERE id = r.id;
    PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.no_show_confirmed', NULL);
    v_conf := v_conf + 1;
  END LOOP;
  -- an unanswered review request after 48h is accepted in the player's favour (voided on a cancelled/did_not_happen event)
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_review' AND a.review_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    IF (SELECT ae.is_cancelled FROM public.attendance_event(r.event_id) ae)
       OR (SELECT l.state FROM public.attendance_lifecycle(r.event_id) l) = 'did_not_happen' THEN
      UPDATE public.event_attendance SET outcome = NULL, review_deadline = NULL, updated_at = p_now WHERE id = r.id;
      v_void := v_void + 1;
      CONTINUE;
    END IF;
    UPDATE public.event_attendance SET outcome = 'attended', review_decision = 'expired_accepted',
           review_decided_at = p_now, updated_at = p_now WHERE id = r.id;
    PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.review_accepted', NULL);
    v_exp := v_exp + 1;
  END LOOP;
  -- never finalized: attendance_finalize_event locks the event and re-checks cancelled / lifecycle state / end + 24h
  FOR v_e IN SELECT e.id FROM public.events e
              WHERE e.event_type IN ('game', 'meetup') AND NOT COALESCE(e.is_cancelled, false)
                AND e.start_at >= timestamptz '2026-11-17 18:00:00+00'
                AND e.start_at + interval '24 hours' <= p_now
                AND NOT EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = e.id) LOOP
    v_res := public.attendance_finalize_event(v_e, NULL, true, p_now);
    IF v_res = -3 THEN v_dnh := v_dnh + 1;
    ELSIF v_res = -2 THEN v_wait := v_wait + 1;
    ELSIF v_res >= 0 THEN v_auto := v_auto + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('no_show_confirmed', v_conf, 'review_expired_accepted', v_exp, 'voided', v_void,
                            'auto_finalized', v_auto, 'did_not_happen', v_dnh, 'waiting_for_lifecycle', v_wait);
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_attendance_finalize(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; v_n int;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF v_uid IS NULL OR ev.organiser IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_organiser';
  END IF;
  IF ev.is_cancelled THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'event_cancelled';
  END IF;
  IF (SELECT l.state FROM public.attendance_lifecycle(p_event_id) l) = 'did_not_happen' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'event_did_not_happen';
  END IF;
  IF now() <= ev.start_at + interval '15 minutes' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'window_not_closed';
  END IF;
  IF EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'attendance_finalized';
  END IF;
  v_n := public.attendance_finalize_event(p_event_id, v_uid, false, now());
  IF v_n = -1 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'event_cancelled';
  ELSIF v_n = -3 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'event_did_not_happen';
  END IF;
  RETURN jsonb_build_object('event_id', p_event_id, 'finalized', true, 'participants', v_n);
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_showup_rate(p_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := COALESCE(p_user_id, auth.uid()); v_att int; v_ns int;
BEGIN
  IF auth.uid() IS NULL AND p_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT count(*) FILTER (WHERE a.outcome = 'attended'), count(*) FILTER (WHERE a.outcome = 'no_show_confirmed')
    INTO v_att, v_ns
    FROM public.event_attendance a JOIN public.events e ON e.id = a.event_id
   WHERE a.user_id = v_uid AND NOT COALESCE(e.is_cancelled, false)
     AND a.outcome IN ('attended', 'no_show_confirmed')
     AND (SELECT l.state FROM public.attendance_lifecycle(e.id) l) IS DISTINCT FROM 'did_not_happen';
  RETURN jsonb_build_object(
    'user_id', v_uid, 'confirmed', v_att + v_ns, 'attended', v_att, 'no_shows', v_ns,
    'enough', (v_att + v_ns) >= 3,
    'rate', CASE WHEN (v_att + v_ns) >= 3 THEN round(100.0 * v_att / (v_att + v_ns))::int END);
END;
$function$;

DO $post$
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.attendance_lifecycle(uuid)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}'
     OR (SELECT proacl::text FROM pg_proc WHERE oid = 'public.attendance_sweep(timestamp with time zone)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}'
     OR (SELECT proacl::text FROM pg_proc WHERE oid = 'public.attendance_finalize_event(uuid,uuid,boolean,timestamp with time zone)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}'
     OR has_function_privilege('anon', 'public.rpc_showup_rate(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.rpc_attendance_finalize(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.rpc_showup_rate(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan994c post-image: grants';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan994_attendance_sweep' AND active) THEN
    RAISE EXCEPTION 'kan994c post-image: sweep cron job missing';
  END IF;
END
$post$;

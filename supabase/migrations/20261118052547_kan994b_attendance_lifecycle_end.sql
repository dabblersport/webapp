-- KAN-994b (coordinator, 2026-11-18): auto-finalize follows KAN-995's lifecycle.
--
-- * attendance_lifecycle(event_id) reads public.event_lifecycle_state(p_event_id) (KAN-995, backend-3) when it exists,
--   through a dynamic call so this migration does not depend on it; never event_lifecycle directly. Until it ships, or
--   if the call fails, the fallback is state 'scheduled' with effective_end_at = COALESCE(end_at, start_at), which is
--   exactly the KAN-994 behaviour.
-- * attendance_sweep: auto-finalize 24h after effective_end_at. A did_not_happen event is finalized with NO outcomes
--   (no attended, no unknown, no no-show); a cancelled event (events.is_cancelled) is skipped and records nothing.
-- * rpc_attendance_finalize refuses a did_not_happen event (22023 event_did_not_happen).
-- * event_attendance_finalizations.reason: organiser | auto | did_not_happen.
-- Rebuilt from the live definitions (md5 guarded). No DROP, no DELETE.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.attendance_sweep(timestamp with time zone)'::regprocedure)) <> 'ef9f4409ca04db11560148124b9ee28b'
     OR md5(pg_get_functiondef('public.attendance_finalize_event(uuid,uuid,boolean,timestamp with time zone)'::regprocedure)) <> '3e12f20d839ea27fe163bda26859b944'
     OR md5(pg_get_functiondef('public.rpc_attendance_finalize(uuid)'::regprocedure)) <> '52a07d8ba85d4d6e58f05f2414713c4f' THEN
    RAISE EXCEPTION 'kan994b pre-image: attendance functions changed since 20261117181706';
  END IF;
  IF to_regproc('public.attendance_lifecycle') IS NOT NULL
     OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                 AND table_name = 'event_attendance_finalizations' AND column_name = 'reason') THEN
    RAISE EXCEPTION 'kan994b pre-image: already applied';
  END IF;
END
$guard$;

ALTER TABLE public.event_attendance_finalizations
  ADD COLUMN reason text NOT NULL DEFAULT 'organiser',
  ADD CONSTRAINT event_attendance_finalizations_reason_chk CHECK (reason IN ('organiser', 'auto', 'did_not_happen'));
UPDATE public.event_attendance_finalizations SET reason = 'auto' WHERE auto;

-- The one reader of the lifecycle. Dynamic so it compiles and runs before KAN-995 ships.
CREATE FUNCTION public.attendance_lifecycle(p_event_id uuid, OUT state text, OUT effective_end_at timestamptz, OUT source text)
RETURNS record
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF to_regprocedure('public.event_lifecycle_state(uuid)') IS NOT NULL THEN
    BEGIN
      EXECUTE 'SELECT l.state::text, l.effective_end_at FROM public.event_lifecycle_state($1) l'
         INTO state, effective_end_at USING p_event_id;
      source := 'event_lifecycle_state';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'attendance_lifecycle: event_lifecycle_state failed (sqlstate %), using the fallback', SQLSTATE;
      state := NULL;
    END;
  END IF;
  IF state IS NULL OR effective_end_at IS NULL THEN
    SELECT COALESCE(state, 'scheduled'), COALESCE(effective_end_at, COALESCE(e.end_at, e.start_at)),
           COALESCE(source, 'fallback')
      INTO state, effective_end_at, source
      FROM public.events e WHERE e.id = p_event_id;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.attendance_finalize_event(p_event_id uuid, p_by uuid, p_auto boolean, p_now timestamp with time zone DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; v_uid uuid; v_mark text; v_n integer := 0;
BEGIN
  INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto, reason)
  VALUES (p_event_id, p_now, p_by, p_auto, CASE WHEN p_auto THEN 'auto' ELSE 'organiser' END)
  ON CONFLICT (event_id) DO NOTHING;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
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
DECLARE v_e uuid; r record; lc record; v_auto int := 0; v_dnh int := 0; v_conf int := 0; v_exp int := 0;
BEGIN
  -- 48h passed with no review request: the no-show is confirmed
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_pending' AND a.no_show_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    UPDATE public.event_attendance SET outcome = 'no_show_confirmed', updated_at = p_now WHERE id = r.id;
    PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.no_show_confirmed', NULL);
    v_conf := v_conf + 1;
  END LOOP;
  -- an unanswered review request after 48h is accepted in the player's favour
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_review' AND a.review_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    UPDATE public.event_attendance SET outcome = 'attended', review_decision = 'expired_accepted',
           review_decided_at = p_now, updated_at = p_now WHERE id = r.id;
    PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.review_accepted', NULL);
    v_exp := v_exp + 1;
  END LOOP;
  -- never finalized: 24h after the effective end (KAN-995 lifecycle), check-ins as recorded, nobody marked no-show.
  -- A cancelled event records nothing; a did_not_happen event is closed with no outcomes.
  FOR v_e IN SELECT e.id FROM public.events e
              WHERE e.event_type IN ('game', 'meetup') AND NOT COALESCE(e.is_cancelled, false)
                AND e.start_at >= timestamptz '2026-11-17 18:00:00+00'
                AND e.start_at + interval '24 hours' <= p_now
                AND NOT EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = e.id) LOOP
    SELECT * INTO lc FROM public.attendance_lifecycle(v_e);
    IF lc.state = 'did_not_happen' THEN
      INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto, reason)
      VALUES (v_e, p_now, NULL, true, 'did_not_happen') ON CONFLICT (event_id) DO NOTHING;
      v_dnh := v_dnh + 1;
    ELSIF lc.effective_end_at + interval '24 hours' <= p_now THEN
      PERFORM public.attendance_finalize_event(v_e, NULL, true, p_now);
      v_auto := v_auto + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('no_show_confirmed', v_conf, 'review_expired_accepted', v_exp,
                            'auto_finalized', v_auto, 'did_not_happen', v_dnh);
END;
$function$;

-- Organiser finalize: refuse a did_not_happen event (rebuilt from its live definition; one added check).
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
  RETURN jsonb_build_object('event_id', p_event_id, 'finalized', true, 'participants', v_n);
END;
$function$;

REVOKE ALL ON FUNCTION public.attendance_lifecycle(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_lifecycle(uuid) TO service_role;

DO $post$
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.attendance_lifecycle(uuid)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}'
     OR (SELECT proacl::text FROM pg_proc WHERE oid = 'public.attendance_sweep(timestamp with time zone)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}'
     OR NOT has_function_privilege('authenticated', 'public.rpc_attendance_finalize(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan994b post-image: grants';
  END IF;
END
$post$;

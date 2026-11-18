-- KAN-996b: results hardening after PEER review. Bodies are the live pg_get_functiondef text (md5 guarded) with:
-- 1. results_sweep: each event in its own subtransaction; a failure is a WARNING and counted as 'failed'.
-- 2. results_tally: only submissions from users still in results_eligible count (rpc_result_submit's early notice
--    uses the tally, so it follows).
-- 3. Cancelled events: rpc_result_submit / approve / set_final refuse 'event_cancelled'; the sweep CLOSES a cancelled
--    event's open result with no result (closed_no_result, no winning side, so no win) instead of auto-confirming.
-- 4. rpc_result_approve / rpc_result_set_final refuse 'result_final' at or after deadline_at (submit already did).
-- 5. results_notify_organiser: notified_score is written only after results_notify returned an id.
-- CREATE OR REPLACE keeps owner, SECURITY DEFINER, search_path and ACL; asserted after.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.results_sweep(timestamptz)'::regprocedure)) <> '64c684de25fb78eb96ebda8f8281138f'
     OR md5(pg_get_functiondef('public.results_tally(uuid)'::regprocedure)) <> '56c55eb6474b5602786fa7060136eb20'
     OR md5(pg_get_functiondef('public.rpc_result_submit(uuid,integer,integer,text)'::regprocedure)) <> 'e2e25dfae1e982ba080c0a93bfa018ca'
     OR md5(pg_get_functiondef('public.rpc_result_approve(uuid)'::regprocedure)) <> 'ab0624eb6894041a3112bab806f233f0'
     OR md5(pg_get_functiondef('public.rpc_result_set_final(uuid,integer,integer)'::regprocedure)) <> '4dfc0c51a2045b6c4182363f1a446554'
     OR md5(pg_get_functiondef('public.results_notify_organiser(uuid)'::regprocedure)) <> 'f0abdf758539ce7bc568d4ae0a1da737' THEN
    RAISE EXCEPTION 'kan996b pre-image: a results function changed since 20261118112808';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.results_tally(p_event_id uuid, OUT score_a integer, OUT score_b integer, OUT votes integer, OUT submissions integer, OUT eligible integer, OUT is_tie boolean, OUT spread jsonb)
 RETURNS record
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_top integer; v_top_n integer;
BEGIN
  SELECT count(*) INTO submissions FROM public.event_result_submissions s WHERE s.event_id = p_event_id
     AND s.user_id IN (SELECT u FROM public.results_eligible(p_event_id) u);
  SELECT count(*) INTO eligible FROM public.results_eligible(p_event_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object('score_a', q.a, 'score_b', q.b, 'votes', q.n) ORDER BY q.n DESC, q.a, q.b), '[]'::jsonb),
         max(q.n) INTO spread, v_top
    FROM (SELECT s.score_a a, s.score_b b, count(*)::int n FROM public.event_result_submissions s
           WHERE s.event_id = p_event_id AND s.user_id IN (SELECT u FROM public.results_eligible(p_event_id) u)
           GROUP BY 1, 2) q;
  votes := COALESCE(v_top, 0);
  SELECT count(*) INTO v_top_n
    FROM (SELECT 1 FROM public.event_result_submissions s WHERE s.event_id = p_event_id
             AND s.user_id IN (SELECT u FROM public.results_eligible(p_event_id) u)
           GROUP BY s.score_a, s.score_b HAVING count(*) = v_top) q;
  is_tie := v_top_n > 1;
  IF v_top_n = 1 THEN
    SELECT s.score_a, s.score_b INTO score_a, score_b FROM public.event_result_submissions s
     WHERE s.event_id = p_event_id AND s.user_id IN (SELECT u FROM public.results_eligible(p_event_id) u)
     GROUP BY 1, 2 HAVING count(*) = v_top;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.results_notify_organiser(p_event_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE t record; v_key text; v_org uuid; v_id uuid;
BEGIN
  SELECT * INTO t FROM public.results_tally(p_event_id);
  IF t.submissions = 0 THEN RETURN NULL; END IF;
  v_key := CASE WHEN t.score_a IS NULL THEN 'tie' ELSE t.score_a || '-' || t.score_b END;
  IF (SELECT notified_score FROM public.event_results WHERE event_id = p_event_id) IS NOT DISTINCT FROM v_key THEN
    RETURN NULL;
  END IF;
  SELECT organiser INTO v_org FROM public.attendance_event(p_event_id);
  IF v_key = 'tie' THEN
    v_id := public.results_notify(p_event_id, v_org, 'activity.result_enter_final', NULL, 'tie',
      jsonb_build_object('submissions', t.submissions, 'eligible', t.eligible, 'spread', t.spread));
  ELSE
    v_id := public.results_notify(p_event_id, v_org, 'activity.result_ready', NULL, v_key,
      jsonb_build_object('score', t.score_a || ' – ' || t.score_b, 'votes', t.votes, 'eligible', t.eligible,
                         'summary', t.votes || ' of ' || t.eligible || ' said ' || t.score_a || ' – ' || t.score_b,
                         'spread', t.spread));
  END IF;
  IF v_id IS NULL THEN RETURN NULL; END IF;  -- not sent: leave notified_score so the next sweep retries
  UPDATE public.event_results SET notified_score = v_key, updated_at = now() WHERE event_id = p_event_id;
  RETURN v_key;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_result_submit(p_event_id uuid, p_score_a integer, p_score_b integer, p_side text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_state text; r record; t record; v_now timestamptz := now();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT public.results_competitive(p_event_id) THEN RAISE EXCEPTION 'no_score_step'; END IF;
  IF p_side IS NULL OR p_side NOT IN ('a', 'b') OR p_score_a IS NULL OR p_score_b IS NULL
     OR p_score_a NOT BETWEEN 0 AND 999 OR p_score_b NOT BETWEEN 0 AND 999 THEN
    RAISE EXCEPTION 'invalid_score';
  END IF;
  IF COALESCE((SELECT e.is_cancelled FROM public.events e WHERE e.id = p_event_id), false) THEN
    RAISE EXCEPTION 'event_cancelled';
  END IF;
  SELECT l.state INTO v_state FROM public.event_lifecycle_state(p_event_id) l;
  IF v_state IS NULL OR v_state NOT IN ('ended', 'auto_closed') THEN RAISE EXCEPTION 'not_ended'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.results_eligible(p_event_id) u WHERE u = v_uid) THEN
    RAISE EXCEPTION 'not_eligible';
  END IF;
  INSERT INTO public.event_results (event_id, first_submission_at, deadline_at)
  VALUES (p_event_id, v_now, v_now + interval '24 hours') ON CONFLICT (event_id) DO NOTHING;
  SELECT * INTO r FROM public.event_results WHERE event_id = p_event_id FOR UPDATE;
  IF r.status <> 'open' OR r.deadline_at <= v_now THEN RAISE EXCEPTION 'result_final'; END IF;
  INSERT INTO public.event_result_submissions (event_id, user_id, score_a, score_b, side)
  VALUES (p_event_id, v_uid, p_score_a, p_score_b, p_side)
  ON CONFLICT (event_id, user_id) DO UPDATE
     SET score_a = EXCLUDED.score_a, score_b = EXCLUDED.score_b, side = EXCLUDED.side, updated_at = now();
  SELECT * INTO t FROM public.results_tally(p_event_id);
  IF t.submissions >= t.eligible THEN PERFORM public.results_notify_organiser(p_event_id); END IF;
  RETURN jsonb_build_object('ok', true, 'submissions', t.submissions, 'eligible', t.eligible);
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_result_approve(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); r record; t record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF (SELECT organiser FROM public.attendance_event(p_event_id)) IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'not_organiser'; END IF;
  IF COALESCE((SELECT e.is_cancelled FROM public.events e WHERE e.id = p_event_id), false) THEN
    RAISE EXCEPTION 'event_cancelled';
  END IF;
  SELECT * INTO r FROM public.event_results WHERE event_id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no_submissions'; END IF;
  IF r.status <> 'open' OR r.deadline_at <= now() THEN RAISE EXCEPTION 'result_final'; END IF;
  SELECT * INTO t FROM public.results_tally(p_event_id);
  IF t.score_a IS NULL THEN RAISE EXCEPTION 'no_majority'; END IF;
  PERFORM public.results_settle(p_event_id, t.score_a, t.score_b, 'approved', v_uid);
  RETURN jsonb_build_object('ok', true, 'score_a', t.score_a, 'score_b', t.score_b, 'method', 'approved');
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_result_set_final(p_event_id uuid, p_score_a integer, p_score_b integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); r record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF (SELECT organiser FROM public.attendance_event(p_event_id)) IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'not_organiser'; END IF;
  IF p_score_a IS NULL OR p_score_b IS NULL OR p_score_a NOT BETWEEN 0 AND 999 OR p_score_b NOT BETWEEN 0 AND 999 THEN
    RAISE EXCEPTION 'invalid_score';
  END IF;
  IF COALESCE((SELECT e.is_cancelled FROM public.events e WHERE e.id = p_event_id), false) THEN
    RAISE EXCEPTION 'event_cancelled';
  END IF;
  SELECT * INTO r FROM public.event_results WHERE event_id = p_event_id FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM public.event_result_submissions s WHERE s.event_id = p_event_id) THEN
    RAISE EXCEPTION 'no_submissions';
  END IF;
  IF r.status <> 'open' OR r.deadline_at <= now() THEN RAISE EXCEPTION 'result_final'; END IF;
  PERFORM public.results_settle(p_event_id, p_score_a, p_score_b, 'organiser_final', v_uid);
  RETURN jsonb_build_object('ok', true, 'score_a', p_score_a, 'score_b', p_score_b, 'method', 'organiser_final');
END;
$function$;

CREATE OR REPLACE FUNCTION public.results_sweep(p_now timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; t record; v_conf int := 0; v_closed int := 0; v_told int := 0; v_fail int := 0;
BEGIN
  FOR v_e IN SELECT event_id FROM public.event_results WHERE status = 'open' AND deadline_at <= p_now
              ORDER BY deadline_at FOR UPDATE SKIP LOCKED LOOP
    BEGIN
      SELECT * INTO t FROM public.results_tally(v_e);
      IF t.score_a IS NOT NULL
         AND NOT COALESCE((SELECT e.is_cancelled FROM public.events e WHERE e.id = v_e), false) THEN
        PERFORM public.results_settle(v_e, t.score_a, t.score_b, 'auto', NULL, p_now); v_conf := v_conf + 1;
      ELSE
        -- no provisional, or the event was cancelled: closed with no result (no winning side, no win)
        PERFORM public.results_settle(v_e, NULL, NULL, NULL, NULL, p_now); v_closed := v_closed + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'results_sweep: settle failed for event %: % %', v_e, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  FOR v_e IN SELECT event_id FROM public.event_results WHERE status = 'open' AND deadline_at > p_now
                AND first_submission_at <= p_now - interval '2 hours'
              FOR UPDATE SKIP LOCKED LOOP
    BEGIN
      IF public.results_notify_organiser(v_e) IS NOT NULL THEN v_told := v_told + 1; END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'results_sweep: organiser notice failed for event %: % %', v_e, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  RETURN jsonb_build_object('auto_confirmed', v_conf, 'closed_no_result', v_closed, 'organiser_notified', v_told,
                            'failed', v_fail);
END;
$function$;

DO $post$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.results_sweep(timestamptz)', 'public.results_tally(uuid)', 'public.results_notify_organiser(uuid)'] LOOP
    IF has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'kan996b post-image: ACL wrong on %', f;
    END IF;
  END LOOP;
  FOREACH f IN ARRAY ARRAY['public.rpc_result_submit(uuid,integer,integer,text)', 'public.rpc_result_approve(uuid)',
                           'public.rpc_result_set_final(uuid,integer,integer)'] LOOP
    IF has_function_privilege('anon', f, 'EXECUTE') OR NOT has_function_privilege('authenticated', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'kan996b post-image: ACL wrong on %', f;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
              AND proname IN ('results_sweep','results_tally','results_notify_organiser','rpc_result_submit',
                              'rpc_result_approve','rpc_result_set_final')
              AND (NOT prosecdef OR proowner <> 'postgres'::regrole
                   OR NOT proconfig @> ARRAY['search_path=public, pg_temp'])) THEN
    RAISE EXCEPTION 'kan996b post-image: owner / SECURITY DEFINER / search_path drifted';
  END IF;
END
$post$;

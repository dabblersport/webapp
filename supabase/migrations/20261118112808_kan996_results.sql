-- KAN-996 [W2-B3] Results (Epic KAN-973). F-10, I-4, G-02/G-03, CEO tie rule. Absorbs KAN-969's result data.
--
-- * No existing structure fits: games has no score; challenge_fixtures is squad-vs-squad for challenges, not Events.
--   New: event_results (one official, versioned result per Event), event_result_submissions (one per player),
--   event_result_revisions (audit of every change of the official result).
-- * The score is two-sided, "A - B". Each submitter also says which side they played on (a | b); that side is what
--   wins are counted from. A player who never submitted has no side and gets no win.
-- * Competitive = a game Event whose games.game_type is not 'training' and whose sport category is not 'fitness' or
--   'mind_body'. Meetups and other games have no score step (results_competitive()).
-- * Who may submit: an attendee with outcome 'attended' once the Event's attendance is finalized (KAN-994), and the
--   Event's lifecycle (KAN-995) is ended or auto_closed. The organiser is never a submitter.
-- * The first submission opens the result: deadline = first submission + 24h. Submitters may change their own
--   submission while the result is open. Provisional = the single most common score; a tie for most common = none.
-- * Organiser: approve (needs a provisional) -> confirmed 'approved'; set final (needs >= 1 submission: the reject
--   path and the tie path) -> confirmed 'organiser_final'. Nobody can enter or change anything after confirmation.
-- * Notice to the organiser ("N of M said A - B" or "enter the final") when every eligible player has submitted, or
--   from the sweep 2h after the first submission, once per score. results_sweep() at the deadline: provisional ->
--   confirmed 'auto'; no provisional -> closed_no_result. Every 5 minutes on cron, like attendance_sweep.
-- * Wins: result_wins(user, from, to) counts confirmed results whose winning side equals the player's submitted side.
-- * Kinds activated (this file is their only sender): activity.result_ready, result_enter_final, result_confirmed,
--   result_corrected, result_closed.

-- 0. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF to_regclass('public.event_results') IS NOT NULL OR to_regclass('public.event_result_submissions') IS NOT NULL
     OR to_regclass('public.event_result_revisions') IS NOT NULL
     OR to_regproc('public.results_sweep') IS NOT NULL OR to_regproc('public.rpc_result_submit') IS NOT NULL THEN
    RAISE EXCEPTION 'kan996 pre-image: a result object already exists';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('activity.result_ready','activity.result_enter_final','activity.result_confirmed',
                     'activity.result_corrected','activity.result_closed') AND NOT is_active) <> 5 THEN
    RAISE EXCEPTION 'kan996 pre-image: result kinds are not all inactive';
  END IF;
  IF to_regclass('public.event_attendance_finalizations') IS NULL OR to_regproc('public.event_lifecycle_state') IS NULL THEN
    RAISE EXCEPTION 'kan996 pre-image: KAN-994 / KAN-995 objects missing';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan996_results_sweep') THEN
    RAISE EXCEPTION 'kan996 pre-image: cron job exists';
  END IF;
END
$guard$;

-- 1. Tables ----------------------------------------------------------------------------------------------------------
CREATE TABLE public.event_results (
  event_id            uuid        PRIMARY KEY REFERENCES public.events (id) ON DELETE CASCADE,
  status              text        NOT NULL DEFAULT 'open',      -- open | confirmed | closed_no_result
  first_submission_at timestamptz NOT NULL,
  deadline_at         timestamptz NOT NULL,
  score_a             integer,                                  -- official, set when confirmed
  score_b             integer,
  winning_side        text,                                     -- a | b | NULL (draw / no result)
  confirm_method      text,                                     -- approved | organiser_final | auto
  confirmed_by        uuid,                                     -- NULL = auto
  confirmed_at        timestamptz,
  closed_at           timestamptz,
  notified_score      text,                                     -- last state the organiser was told ('a-b' or 'tie')
  revision            integer     NOT NULL DEFAULT 1,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_results_status_chk CHECK (status IN ('open', 'confirmed', 'closed_no_result')),
  CONSTRAINT event_results_method_chk CHECK (confirm_method IS NULL OR confirm_method IN ('approved', 'organiser_final', 'auto')),
  CONSTRAINT event_results_side_chk CHECK (winning_side IS NULL OR winning_side IN ('a', 'b')),
  CONSTRAINT event_results_confirmed_chk CHECK ((status = 'confirmed') =
    (score_a IS NOT NULL AND score_b IS NOT NULL AND confirm_method IS NOT NULL AND confirmed_at IS NOT NULL)),
  CONSTRAINT event_results_closed_chk CHECK ((status = 'closed_no_result') = (closed_at IS NOT NULL)),
  CONSTRAINT event_results_score_chk CHECK ((score_a IS NULL OR score_a BETWEEN 0 AND 999) AND (score_b IS NULL OR score_b BETWEEN 0 AND 999))
);
CREATE INDEX event_results_open_idx ON public.event_results (deadline_at) WHERE status = 'open';
CREATE INDEX event_results_confirmed_idx ON public.event_results (confirmed_at) WHERE status = 'confirmed';
COMMENT ON TABLE public.event_results IS
  'KAN-996: the official, versioned result of a competitive game Event. Written only by the result RPCs and results_sweep.';

CREATE TABLE public.event_result_submissions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid        NOT NULL REFERENCES public.event_results (event_id) ON DELETE CASCADE,
  user_id     uuid        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  score_a     integer     NOT NULL,
  score_b     integer     NOT NULL,
  side        text        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_result_submissions_unique UNIQUE (event_id, user_id),
  CONSTRAINT event_result_submissions_side_chk CHECK (side IN ('a', 'b')),
  CONSTRAINT event_result_submissions_score_chk CHECK (score_a BETWEEN 0 AND 999 AND score_b BETWEEN 0 AND 999)
);
CREATE INDEX event_result_submissions_user_idx ON public.event_result_submissions (user_id);
COMMENT ON TABLE public.event_result_submissions IS 'KAN-996: each eligible attendee''s submitted score and side.';

CREATE TABLE public.event_result_revisions (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id       uuid        NOT NULL REFERENCES public.event_results (event_id) ON DELETE CASCADE,
  revision       integer     NOT NULL,
  status         text        NOT NULL,
  score_a        integer,
  score_b        integer,
  confirm_method text,
  actor_user_id  uuid,
  votes          integer,
  submissions    integer,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX event_result_revisions_event_idx ON public.event_result_revisions (event_id, revision);
COMMENT ON TABLE public.event_result_revisions IS 'KAN-996: audit of every change of an official result.';

-- Server-only tables (T-020): RLS on, no policy, no client grant. Clients use the RPCs.
ALTER TABLE public.event_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_result_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_result_revisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_results, public.event_result_submissions, public.event_result_revisions FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.event_results, public.event_result_submissions, public.event_result_revisions TO service_role;

-- 2. Helpers ---------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.results_competitive(p_event_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.events e JOIN public.games g ON g.event_id = e.id
      LEFT JOIN public.sports s ON s.id = e.sport_id
     WHERE e.id = p_event_id AND e.event_type = 'game'
       AND COALESCE(g.game_type, '') <> 'training'
       AND COALESCE(s.category, '') NOT IN ('fitness', 'mind_body'));
$function$;

-- Eligible submitters: finalized attendance, outcome attended.
CREATE FUNCTION public.results_eligible(p_event_id uuid)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT a.user_id FROM public.event_attendance a
    JOIN public.event_attendance_finalizations f ON f.event_id = a.event_id
   WHERE a.event_id = p_event_id AND a.outcome = 'attended';
$function$;

-- Tally: the single most common score (NULL on a tie), its votes, total submissions, eligible, spread.
CREATE FUNCTION public.results_tally(p_event_id uuid,
  OUT score_a integer, OUT score_b integer, OUT votes integer, OUT submissions integer, OUT eligible integer,
  OUT is_tie boolean, OUT spread jsonb)
RETURNS record
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_top integer; v_top_n integer;
BEGIN
  SELECT count(*) INTO submissions FROM public.event_result_submissions s WHERE s.event_id = p_event_id;
  SELECT count(*) INTO eligible FROM public.results_eligible(p_event_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object('score_a', q.a, 'score_b', q.b, 'votes', q.n) ORDER BY q.n DESC, q.a, q.b), '[]'::jsonb),
         max(q.n) INTO spread, v_top
    FROM (SELECT s.score_a a, s.score_b b, count(*)::int n FROM public.event_result_submissions s
           WHERE s.event_id = p_event_id GROUP BY 1, 2) q;
  votes := COALESCE(v_top, 0);
  SELECT count(*) INTO v_top_n
    FROM (SELECT 1 FROM public.event_result_submissions s WHERE s.event_id = p_event_id
           GROUP BY s.score_a, s.score_b HAVING count(*) = v_top) q;
  is_tie := v_top_n > 1;
  IF v_top_n = 1 THEN
    SELECT s.score_a, s.score_b INTO score_a, score_b FROM public.event_result_submissions s
     WHERE s.event_id = p_event_id GROUP BY 1, 2 HAVING count(*) = v_top;
  END IF;
END;
$function$;

CREATE FUNCTION public.results_notify(p_event_id uuid, p_to uuid, p_kind text, p_actor uuid, p_dedupe text,
                                      p_extra jsonb DEFAULT '{}'::jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  RETURN public.notify_v2(
    p_to, p_kind,
    jsonb_strip_nulls(jsonb_build_object('title', ev.title, 'event_id', p_event_id::text)) || COALESCE(p_extra, '{}'::jsonb),
    ev.event_type, ev.entity_id, p_actor,
    'result:' || p_event_id::text,
    p_kind || ':' || p_event_id::text || ':' || p_to::text || ':' || p_dedupe,
    NULL, NULL);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'results_notify % failed (sqlstate %)', p_kind, SQLSTATE;
  RETURN NULL;
END;
$function$;

-- Tell the organiser the current state (majority or tie), once per state. Caller holds the row lock.
CREATE FUNCTION public.results_notify_organiser(p_event_id uuid)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE t record; v_key text; v_org uuid;
BEGIN
  SELECT * INTO t FROM public.results_tally(p_event_id);
  IF t.submissions = 0 THEN RETURN NULL; END IF;
  v_key := CASE WHEN t.score_a IS NULL THEN 'tie' ELSE t.score_a || '-' || t.score_b END;
  IF (SELECT notified_score FROM public.event_results WHERE event_id = p_event_id) IS NOT DISTINCT FROM v_key THEN
    RETURN NULL;
  END IF;
  SELECT organiser INTO v_org FROM public.attendance_event(p_event_id);
  UPDATE public.event_results SET notified_score = v_key, updated_at = now() WHERE event_id = p_event_id;
  IF v_key = 'tie' THEN
    PERFORM public.results_notify(p_event_id, v_org, 'activity.result_enter_final', NULL, 'tie',
      jsonb_build_object('submissions', t.submissions, 'eligible', t.eligible, 'spread', t.spread));
  ELSE
    PERFORM public.results_notify(p_event_id, v_org, 'activity.result_ready', NULL, v_key,
      jsonb_build_object('score', t.score_a || ' – ' || t.score_b, 'votes', t.votes, 'eligible', t.eligible,
                         'summary', t.votes || ' of ' || t.eligible || ' said ' || t.score_a || ' – ' || t.score_b,
                         'spread', t.spread));
  END IF;
  RETURN v_key;
END;
$function$;

-- Confirm (p_a/p_b set) or close with no result (p_a NULL). Caller holds the row lock and checked status = 'open'.
CREATE FUNCTION public.results_settle(p_event_id uuid, p_a integer, p_b integer, p_method text, p_by uuid,
                                      p_now timestamptz DEFAULT now())
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE t record; v_rev integer; v_status text; v_uid uuid; v_org uuid; v_kind text; v_score text;
BEGIN
  SELECT * INTO t FROM public.results_tally(p_event_id);
  v_status := CASE WHEN p_a IS NULL THEN 'closed_no_result' ELSE 'confirmed' END;
  UPDATE public.event_results
     SET status = v_status, score_a = p_a, score_b = p_b,
         winning_side = CASE WHEN p_a > p_b THEN 'a' WHEN p_b > p_a THEN 'b' END,
         confirm_method = CASE WHEN p_a IS NULL THEN NULL ELSE p_method END,
         confirmed_by = CASE WHEN p_a IS NULL THEN NULL ELSE p_by END,
         confirmed_at = CASE WHEN p_a IS NULL THEN NULL ELSE p_now END,
         closed_at = CASE WHEN p_a IS NULL THEN p_now END,
         revision = revision + 1, updated_at = now()
   WHERE event_id = p_event_id RETURNING revision INTO v_rev;
  INSERT INTO public.event_result_revisions (event_id, revision, status, score_a, score_b, confirm_method, actor_user_id, votes, submissions)
  VALUES (p_event_id, v_rev, v_status, p_a, p_b, CASE WHEN p_a IS NULL THEN NULL ELSE p_method END, p_by, t.votes, t.submissions);

  SELECT organiser INTO v_org FROM public.attendance_event(p_event_id);
  v_kind := CASE WHEN p_a IS NULL THEN 'activity.result_closed'
                 WHEN p_method = 'organiser_final' THEN 'activity.result_corrected'
                 ELSE 'activity.result_confirmed' END;
  v_score := CASE WHEN p_a IS NULL THEN NULL ELSE p_a || ' – ' || p_b END;
  FOR v_uid IN SELECT u FROM public.results_eligible(p_event_id) u UNION SELECT v_org LOOP
    CONTINUE WHEN v_uid IS NULL OR v_uid IS NOT DISTINCT FROM p_by;
    PERFORM public.results_notify(p_event_id, v_uid, v_kind, p_by, v_rev::text,
      jsonb_strip_nulls(jsonb_build_object('score', v_score)));
  END LOOP;
  RETURN v_status;
END;
$function$;

-- 3. Wins (KAN-969 reads this) ---------------------------------------------------------------------------------------
CREATE FUNCTION public.result_wins(p_user_id uuid, p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT count(*)::int
    FROM public.event_results r JOIN public.event_result_submissions s ON s.event_id = r.event_id
   WHERE r.status = 'confirmed' AND r.winning_side IS NOT NULL AND s.user_id = p_user_id AND s.side = r.winning_side
     AND (p_from IS NULL OR r.confirmed_at >= p_from) AND (p_to IS NULL OR r.confirmed_at < p_to);
$function$;

CREATE FUNCTION public.rpc_player_wins(p_user_id uuid, p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN public.result_wins(p_user_id, p_from, p_to);
END;
$function$;

-- 4. Client RPCs -----------------------------------------------------------------------------------------------------
CREATE FUNCTION public.rpc_result_submit(p_event_id uuid, p_score_a integer, p_score_b integer, p_side text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
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

CREATE FUNCTION public.rpc_result_approve(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); r record; t record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF (SELECT organiser FROM public.attendance_event(p_event_id)) IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'not_organiser'; END IF;
  SELECT * INTO r FROM public.event_results WHERE event_id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no_submissions'; END IF;
  IF r.status <> 'open' THEN RAISE EXCEPTION 'result_final'; END IF;
  SELECT * INTO t FROM public.results_tally(p_event_id);
  IF t.score_a IS NULL THEN RAISE EXCEPTION 'no_majority'; END IF;
  PERFORM public.results_settle(p_event_id, t.score_a, t.score_b, 'approved', v_uid);
  RETURN jsonb_build_object('ok', true, 'score_a', t.score_a, 'score_b', t.score_b, 'method', 'approved');
END;
$function$;

-- Reject (or tie): the organiser enters the final score. Needs at least one submission.
CREATE FUNCTION public.rpc_result_set_final(p_event_id uuid, p_score_a integer, p_score_b integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); r record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF (SELECT organiser FROM public.attendance_event(p_event_id)) IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'not_organiser'; END IF;
  IF p_score_a IS NULL OR p_score_b IS NULL OR p_score_a NOT BETWEEN 0 AND 999 OR p_score_b NOT BETWEEN 0 AND 999 THEN
    RAISE EXCEPTION 'invalid_score';
  END IF;
  SELECT * INTO r FROM public.event_results WHERE event_id = p_event_id FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM public.event_result_submissions s WHERE s.event_id = p_event_id) THEN
    RAISE EXCEPTION 'no_submissions';
  END IF;
  IF r.status <> 'open' THEN RAISE EXCEPTION 'result_final'; END IF;
  PERFORM public.results_settle(p_event_id, p_score_a, p_score_b, 'organiser_final', v_uid);
  RETURN jsonb_build_object('ok', true, 'score_a', p_score_a, 'score_b', p_score_b, 'method', 'organiser_final');
END;
$function$;

-- Read for eligible players and the organiser (G-03 states).
CREATE FUNCTION public.rpc_result_get(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); r record; t record; v_org boolean; v_mine jsonb; v_state text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v_org := (SELECT organiser FROM public.attendance_event(p_event_id)) IS NOT DISTINCT FROM v_uid;
  IF NOT v_org AND NOT EXISTS (SELECT 1 FROM public.results_eligible(p_event_id) u WHERE u = v_uid) THEN
    RAISE EXCEPTION 'not_eligible';
  END IF;
  IF NOT public.results_competitive(p_event_id) THEN RETURN jsonb_build_object('competitive', false); END IF;
  SELECT * INTO r FROM public.event_results WHERE event_id = p_event_id;
  SELECT * INTO t FROM public.results_tally(p_event_id);
  SELECT jsonb_build_object('score_a', s.score_a, 'score_b', s.score_b, 'side', s.side) INTO v_mine
    FROM public.event_result_submissions s WHERE s.event_id = p_event_id AND s.user_id = v_uid;
  v_state := CASE WHEN r.event_id IS NULL OR t.submissions = 0 THEN 'waiting_for_submissions'
                  WHEN r.status = 'confirmed' AND r.confirm_method = 'approved' THEN 'approved'
                  WHEN r.status = 'confirmed' AND r.confirm_method = 'organiser_final' THEN 'rejected'
                  WHEN r.status = 'confirmed' THEN '24h_passed'
                  WHEN r.status = 'closed_no_result' THEN 'closed_no_result'
                  WHEN t.score_a IS NULL THEN 'tie'
                  ELSE 'majority_ready' END;
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'competitive', true, 'state', v_state, 'status', r.status, 'deadline_at', r.deadline_at,
    'provisional', CASE WHEN t.score_a IS NOT NULL THEN jsonb_build_object('score_a', t.score_a, 'score_b', t.score_b) END,
    'votes', t.votes, 'submissions', t.submissions, 'eligible', t.eligible, 'spread', t.spread,
    'final', CASE WHEN r.status = 'confirmed' THEN jsonb_build_object('score_a', r.score_a, 'score_b', r.score_b,
               'winning_side', r.winning_side, 'method', r.confirm_method, 'confirmed_at', r.confirmed_at) END,
    'revision', r.revision, 'mine', v_mine, 'is_organiser', v_org));
END;
$function$;

-- 5. Sweep -----------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.results_sweep(p_now timestamptz DEFAULT now())
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; t record; v_conf int := 0; v_closed int := 0; v_told int := 0;
BEGIN
  FOR v_e IN SELECT event_id FROM public.event_results WHERE status = 'open' AND deadline_at <= p_now
              ORDER BY deadline_at FOR UPDATE SKIP LOCKED LOOP
    SELECT * INTO t FROM public.results_tally(v_e);
    IF t.score_a IS NOT NULL THEN
      PERFORM public.results_settle(v_e, t.score_a, t.score_b, 'auto', NULL, p_now); v_conf := v_conf + 1;
    ELSE
      PERFORM public.results_settle(v_e, NULL, NULL, NULL, NULL, p_now); v_closed := v_closed + 1;
    END IF;
  END LOOP;
  FOR v_e IN SELECT event_id FROM public.event_results WHERE status = 'open' AND deadline_at > p_now
                AND first_submission_at <= p_now - interval '2 hours'
              FOR UPDATE SKIP LOCKED LOOP
    IF public.results_notify_organiser(v_e) IS NOT NULL THEN v_told := v_told + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('auto_confirmed', v_conf, 'closed_no_result', v_closed, 'organiser_notified', v_told);
END;
$function$;

-- 6. Grants ----------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.results_competitive(uuid), public.results_eligible(uuid), public.results_tally(uuid),
  public.results_notify(uuid, uuid, text, uuid, text, jsonb), public.results_notify_organiser(uuid),
  public.results_settle(uuid, integer, integer, text, uuid, timestamptz), public.result_wins(uuid, timestamptz, timestamptz),
  public.results_sweep(timestamptz),
  public.rpc_player_wins(uuid, timestamptz, timestamptz), public.rpc_result_submit(uuid, integer, integer, text),
  public.rpc_result_approve(uuid), public.rpc_result_set_final(uuid, integer, integer), public.rpc_result_get(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.results_competitive(uuid), public.results_eligible(uuid), public.results_tally(uuid),
  public.results_notify(uuid, uuid, text, uuid, text, jsonb), public.results_notify_organiser(uuid),
  public.results_settle(uuid, integer, integer, text, uuid, timestamptz), public.result_wins(uuid, timestamptz, timestamptz),
  public.results_sweep(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION
  public.rpc_player_wins(uuid, timestamptz, timestamptz), public.rpc_result_submit(uuid, integer, integer, text),
  public.rpc_result_approve(uuid), public.rpc_result_set_final(uuid, integer, integer), public.rpc_result_get(uuid)
  TO authenticated, service_role;

-- 7. Kinds and the sweep job -----------------------------------------------------------------------------------------
UPDATE public.notification_kinds SET is_active = true
 WHERE key IN ('activity.result_ready', 'activity.result_enter_final', 'activity.result_confirmed',
               'activity.result_corrected', 'activity.result_closed');

SELECT cron.schedule('kan996_results_sweep', '*/5 * * * *', 'SELECT public.results_sweep()');

-- 8. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
BEGIN
  IF has_table_privilege('authenticated', 'public.event_results', 'SELECT')
     OR has_table_privilege('anon', 'public.event_result_submissions', 'SELECT')
     OR has_function_privilege('anon', 'public.rpc_result_submit(uuid, integer, integer, text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.results_sweep(timestamptz)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.result_wins(uuid, timestamptz, timestamptz)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan996 post-image: grants are wrong';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('activity.result_ready', 'activity.result_enter_final', 'activity.result_confirmed',
                     'activity.result_corrected', 'activity.result_closed') AND is_active) <> 5 THEN
    RAISE EXCEPTION 'kan996 post-image: kinds not active';
  END IF;
END
$post$;

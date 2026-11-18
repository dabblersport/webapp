-- KAN-997 [W2-B4] Ratings (Epic KAN-973). F-11, I-4, G-02 post-activity flow, H.3-a (eligibility follows finalized
-- attendance), F ruling (meetups included), report sections 4 and 5.
--
-- * Existing scheme reused, not replaced: user_reputation_events (players and the organiser, dimensions by
--   reputation_dimensions.applicable_to) and venue_rating_events (venue_rating_dimensions), with their aggregates,
--   triggers and recompute functions. Both had 0 rows and were keyed on game_id only, so they gain event_id (games and
--   meetups) and updated_at; game_id becomes nullable (set for game Events, NULL for meetups).
-- * The old RPCs rpc_rate_user / rpc_rate_venue(game, ...) / rpc_get_unrated_coplayers and the view
--   v_rateable_after_game are dropped: 7-day window, roster eligibility, and a profile_type = 'player' check that no
--   live profile satisfies (all are 'personal'). No app code calls them. rpc_rate_game (rating the game itself) is not
--   part of this ticket and is left as it is.
-- * Window: opens when the Event's attendance is finalized (KAN-994), closes at the effective end (KAN-995
--   event_lifecycle_state.effective_end_at) + 48h. Cancelled Events are not ratable.
-- * Rater: outcome 'attended' on finalized attendance, read live, so a player corrected to attended (review accepted)
--   can rate after the correction. The organiser is never a rater. Targets: another attended player, the organiser,
--   the Event's venue. Never yourself.
-- * One rating per rater, target and Event. Repeat = UPDATE (the latest scores replace the earlier ones) while the
--   window is open; that is what lets a partly saved flow be resumed and corrected.
-- * Each step is optional. rpc_rating_submit marks the flow submitted ("waiting for others"); rpc_rating_dismiss stops
--   prompts. rpc_rating_get returns the G-02 state and only the caller's own given values.
-- * Prompt de-dup: event_rating_prompts (user, event, feedback_kind). ratings_sweep() every 5 minutes: one
--   activity.post_activity per eligible user per Event once the window opens; one activity.rating_reminder 6h before it
--   closes, only if the user has rated nothing, not dismissed and not submitted. Each Event runs in its own
--   subtransaction (KAN-994d). Only Events finalized after this migration are prompted (no backfill).
-- * Kinds activated (this file is their only sender; none had a sender before): activity.post_activity,
--   activity.rating_reminder. activity.summary stays inactive.
-- * Privacy: the rating tables keep RLS on with a deny-all policy and no client grant. Only the aggregates are public.

-- 0. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF to_regclass('public.event_rating_prompts') IS NOT NULL OR to_regproc('public.ratings_sweep') IS NOT NULL
     OR to_regproc('public.rpc_rate_player') IS NOT NULL OR to_regproc('public.rpc_rate_organiser') IS NOT NULL
     OR to_regproc('public.rpc_rating_get') IS NOT NULL THEN
    RAISE EXCEPTION 'kan997 pre-image: a rating object already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
              AND table_name IN ('user_reputation_events', 'venue_rating_events') AND column_name = 'event_id') THEN
    RAISE EXCEPTION 'kan997 pre-image: event_id already added';
  END IF;
  IF (SELECT count(*) FROM public.user_reputation_events) + (SELECT count(*) FROM public.venue_rating_events) <> 0 THEN
    RAISE EXCEPTION 'kan997 pre-image: rating events are not empty';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('activity.post_activity', 'activity.rating_reminder') AND NOT is_active) <> 2 THEN
    RAISE EXCEPTION 'kan997 pre-image: rating kinds are not both inactive';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
              AND (p.prosrc ILIKE '%activity.post_activity%' OR p.prosrc ILIKE '%activity.rating_reminder%')) THEN
    RAISE EXCEPTION 'kan997 pre-image: a sender of a rating kind exists';
  END IF;
  IF to_regclass('public.event_attendance_finalizations') IS NULL OR to_regproc('public.event_lifecycle_state') IS NULL
     OR to_regproc('public.attendance_event') IS NULL THEN
    RAISE EXCEPTION 'kan997 pre-image: KAN-994 / KAN-995 objects missing';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan997_ratings_sweep') THEN
    RAISE EXCEPTION 'kan997 pre-image: cron job exists';
  END IF;
END
$guard$;

-- 1. Drop the superseded game-only surface ---------------------------------------------------------------------------
DROP VIEW public.v_rateable_after_game;
DROP FUNCTION public.rpc_rate_user(uuid, uuid, uuid, jsonb, text);
DROP FUNCTION public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text);
DROP FUNCTION public.rpc_get_unrated_coplayers(uuid);

-- 2. Tables ----------------------------------------------------------------------------------------------------------
ALTER TABLE public.user_reputation_events
  ADD COLUMN event_id uuid REFERENCES public.events (id) ON DELETE CASCADE,
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
  ALTER COLUMN game_id DROP NOT NULL;
CREATE UNIQUE INDEX ux_repu_once_per_event ON public.user_reputation_events (event_id, rater_user_id, ratee_user_id)
  WHERE event_id IS NOT NULL;

ALTER TABLE public.venue_rating_events
  ADD COLUMN event_id uuid REFERENCES public.events (id) ON DELETE CASCADE,
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
  ALTER COLUMN game_id DROP NOT NULL;
CREATE UNIQUE INDEX ux_venue_rating_once_per_event ON public.venue_rating_events (event_id, rater_user_id)
  WHERE event_id IS NOT NULL;

CREATE TABLE public.event_rating_prompts (
  user_id       uuid        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  event_id      uuid        NOT NULL REFERENCES public.events (id) ON DELETE CASCADE,
  feedback_kind text        NOT NULL DEFAULT 'event_rating',
  prompted_at   timestamptz,
  reminded_at   timestamptz,
  dismissed_at  timestamptz,
  submitted_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_id, feedback_kind),
  CONSTRAINT event_rating_prompts_kind_chk CHECK (feedback_kind IN ('event_rating'))
);
CREATE INDEX event_rating_prompts_event_idx ON public.event_rating_prompts (event_id);
COMMENT ON TABLE public.event_rating_prompts IS
  'KAN-997: rating prompt de-dup per (user, event, feedback_kind): prompted, reminded, dismissed, submitted.';
ALTER TABLE public.event_rating_prompts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_rating_prompts FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.event_rating_prompts TO service_role;

-- 3. Helpers ---------------------------------------------------------------------------------------------------------
-- The rating window of an Event. ratable = finalized, not cancelled, game or meetup.
CREATE FUNCTION public.ratings_window(p_event_id uuid,
  OUT ratable boolean, OUT opens_at timestamptz, OUT closes_at timestamptz, OUT organiser uuid, OUT venue_id uuid,
  OUT event_type text, OUT game_id uuid)
RETURNS record
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  event_type := ev.event_type; organiser := ev.organiser;
  game_id := CASE WHEN ev.event_type = 'game' THEN ev.entity_id END;
  SELECT e.venue_id INTO venue_id FROM public.events e WHERE e.id = p_event_id;
  SELECT f.finalized_at INTO opens_at FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id;
  SELECT l.effective_end_at + interval '48 hours' INTO closes_at FROM public.event_lifecycle_state(p_event_id) l;
  closes_at := COALESCE(closes_at, ev.end_at + interval '48 hours');
  ratable := ev.event_type IN ('game', 'meetup') AND NOT COALESCE(ev.is_cancelled, false) AND opens_at IS NOT NULL;
END;
$function$;

-- Eligible raters: finalized attendance, outcome attended, never the organiser.
CREATE FUNCTION public.ratings_eligible(p_event_id uuid)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT a.user_id FROM public.event_attendance a
    JOIN public.event_attendance_finalizations f ON f.event_id = a.event_id
    JOIN public.events e ON e.id = a.event_id
   WHERE a.event_id = p_event_id AND a.outcome = 'attended' AND a.user_id IS DISTINCT FROM e.creator_user_id;
$function$;

-- Raises unless p_uid may rate p_event_id now. Returns the window.
CREATE FUNCTION public.ratings_guard(p_event_id uuid, p_uid uuid,
  OUT closes_at timestamptz, OUT organiser uuid, OUT venue_id uuid, OUT game_id uuid)
RETURNS record
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE w record;
BEGIN
  IF p_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO w FROM public.ratings_window(p_event_id);
  IF w.event_type IS NULL OR w.event_type NOT IN ('game', 'meetup') OR EXISTS (
       SELECT 1 FROM public.events e WHERE e.id = p_event_id AND COALESCE(e.is_cancelled, false)) THEN
    RAISE EXCEPTION 'not_ratable';
  END IF;
  IF NOT w.ratable OR now() < w.opens_at THEN RAISE EXCEPTION 'window_not_open'; END IF;
  IF now() > w.closes_at THEN RAISE EXCEPTION 'window_closed'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ratings_eligible(p_event_id) u WHERE u = p_uid) THEN
    RAISE EXCEPTION 'not_eligible';
  END IF;
  closes_at := w.closes_at; organiser := w.organiser; venue_id := w.venue_id; game_id := w.game_id;
END;
$function$;

-- Scores: a non-empty object, every key an active dimension of the target, every value 1..5.
CREATE FUNCTION public.ratings_check_scores(p_scores jsonb, p_target text)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE k text; v jsonb;
BEGIN
  IF p_scores IS NULL OR jsonb_typeof(p_scores) <> 'object' OR p_scores = '{}'::jsonb THEN
    RAISE EXCEPTION 'invalid_scores';
  END IF;
  FOR k, v IN SELECT * FROM jsonb_each(p_scores) LOOP
    IF p_target = 'venue' THEN
      IF NOT EXISTS (SELECT 1 FROM public.venue_rating_dimensions d WHERE d.key = k AND d.is_active) THEN
        RAISE EXCEPTION 'unknown_dimension';
      END IF;
    ELSIF NOT EXISTS (SELECT 1 FROM public.reputation_dimensions d WHERE d.key = k AND d.is_active
                        AND ('rate_' || p_target) = ANY (d.applicable_to)) THEN
      RAISE EXCEPTION 'unknown_dimension';
    END IF;
    IF jsonb_typeof(v) <> 'number' OR v::numeric < 1 OR v::numeric > 5 THEN RAISE EXCEPTION 'score_out_of_range'; END IF;
  END LOOP;
END;
$function$;

CREATE FUNCTION public.ratings_rater_profile(p_uid uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.id FROM public.profiles p WHERE p.user_id = p_uid
   ORDER BY (p.profile_type = 'personal') DESC, p.created_at LIMIT 1;
$function$;

-- Upsert one person rating (player or organiser). Caller ran ratings_guard.
CREATE FUNCTION public.ratings_put_person(p_event_id uuid, p_game_id uuid, p_rater uuid, p_ratee uuid, p_scores jsonb,
                                          p_comment text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO public.user_reputation_events (event_id, game_id, rater_user_id, rater_profile_id, ratee_user_id, scores, comment)
  VALUES (p_event_id, p_game_id, p_rater, public.ratings_rater_profile(p_rater), p_ratee, p_scores, left(p_comment, 280))
  ON CONFLICT (event_id, rater_user_id, ratee_user_id) WHERE event_id IS NOT NULL DO UPDATE
     SET scores = EXCLUDED.scores, comment = EXCLUDED.comment, updated_at = now();
  PERFORM public.reputation_recompute(p_ratee);
END;
$function$;

CREATE FUNCTION public.ratings_notify(p_event_id uuid, p_to uuid, p_kind text, p_extra jsonb DEFAULT '{}'::jsonb)
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
    ev.event_type, ev.entity_id, NULL,
    'rating:' || p_event_id::text,
    p_kind || ':' || p_event_id::text || ':' || p_to::text,
    NULL, NULL);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'ratings_notify % failed (sqlstate %)', p_kind, SQLSTATE;
  RETURN NULL;
END;
$function$;

-- 4. Client RPCs -----------------------------------------------------------------------------------------------------
CREATE FUNCTION public.rpc_rate_player(p_event_id uuid, p_ratee_user_id uuid, p_scores jsonb, p_comment text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); w record;
BEGIN
  SELECT * INTO w FROM public.ratings_guard(p_event_id, v_uid);
  IF p_ratee_user_id IS NULL OR p_ratee_user_id = v_uid THEN RAISE EXCEPTION 'cannot_rate_self'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ratings_eligible(p_event_id) u WHERE u = p_ratee_user_id) THEN
    RAISE EXCEPTION 'ratee_not_attended';
  END IF;
  PERFORM public.ratings_check_scores(p_scores, 'player');
  PERFORM public.ratings_put_person(p_event_id, w.game_id, v_uid, p_ratee_user_id, p_scores, p_comment);
  RETURN jsonb_build_object('ok', true, 'closes_at', w.closes_at);
END;
$function$;

CREATE FUNCTION public.rpc_rate_organiser(p_event_id uuid, p_scores jsonb, p_comment text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); w record;
BEGIN
  SELECT * INTO w FROM public.ratings_guard(p_event_id, v_uid);
  IF w.organiser IS NULL THEN RAISE EXCEPTION 'no_organiser'; END IF;
  IF w.organiser = v_uid THEN RAISE EXCEPTION 'cannot_rate_self'; END IF;
  PERFORM public.ratings_check_scores(p_scores, 'organiser');
  PERFORM public.ratings_put_person(p_event_id, w.game_id, v_uid, w.organiser, p_scores, p_comment);
  RETURN jsonb_build_object('ok', true, 'closes_at', w.closes_at);
END;
$function$;

CREATE FUNCTION public.rpc_rate_venue(p_event_id uuid, p_scores jsonb, p_comment text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); w record;
BEGIN
  SELECT * INTO w FROM public.ratings_guard(p_event_id, v_uid);
  IF w.venue_id IS NULL THEN RAISE EXCEPTION 'no_venue'; END IF;
  PERFORM public.ratings_check_scores(p_scores, 'venue');
  INSERT INTO public.venue_rating_events (event_id, game_id, venue_id, rater_user_id, rater_profile_id, scores, comment)
  VALUES (p_event_id, w.game_id, w.venue_id, v_uid, public.ratings_rater_profile(v_uid), p_scores, left(p_comment, 280))
  ON CONFLICT (event_id, rater_user_id) WHERE event_id IS NOT NULL DO UPDATE
     SET scores = EXCLUDED.scores, comment = EXCLUDED.comment, updated_at = now();
  PERFORM public.venue_rating_recompute(w.venue_id);
  RETURN jsonb_build_object('ok', true, 'closes_at', w.closes_at);
END;
$function$;

-- "Submitted, waiting for others" and "dismissed". Both stop the prompt and the reminder.
CREATE FUNCTION public.rpc_rating_submit(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); w record;
BEGIN
  SELECT * INTO w FROM public.ratings_guard(p_event_id, v_uid);
  INSERT INTO public.event_rating_prompts (user_id, event_id, submitted_at) VALUES (v_uid, p_event_id, now())
  ON CONFLICT (user_id, event_id, feedback_kind) DO UPDATE SET submitted_at = now(), updated_at = now();
  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE FUNCTION public.rpc_rating_dismiss(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ratings_eligible(p_event_id) u WHERE u = v_uid) THEN RAISE EXCEPTION 'not_eligible'; END IF;
  INSERT INTO public.event_rating_prompts (user_id, event_id, dismissed_at) VALUES (v_uid, p_event_id, now())
  ON CONFLICT (user_id, event_id, feedback_kind) DO UPDATE SET dismissed_at = now(), updated_at = now();
  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- G-02 state and the caller's own given values only. States: not_eligible | not_open | closed | not_started |
-- partly_saved | submitted.
CREATE FUNCTION public.rpc_rating_get(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); w record; pr record; v_players jsonb; v_org jsonb; v_venue jsonb; v_any boolean;
        v_state text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO w FROM public.ratings_window(p_event_id);
  IF NOT EXISTS (SELECT 1 FROM public.ratings_eligible(p_event_id) u WHERE u = v_uid) THEN
    RETURN jsonb_build_object('state', CASE WHEN w.ratable THEN 'not_eligible' ELSE 'not_open' END);
  END IF;
  IF NOT w.ratable THEN RETURN jsonb_build_object('state', 'not_open'); END IF;
  SELECT * INTO pr FROM public.event_rating_prompts p WHERE p.user_id = v_uid AND p.event_id = p_event_id;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('user_id', u, 'mine', ue.scores) ORDER BY u), '[]'::jsonb) INTO v_players
    FROM public.ratings_eligible(p_event_id) u
    LEFT JOIN public.user_reputation_events ue ON ue.event_id = p_event_id AND ue.rater_user_id = v_uid AND ue.ratee_user_id = u
   WHERE u <> v_uid;
  SELECT jsonb_build_object('user_id', w.organiser, 'mine', ue.scores) INTO v_org
    FROM (SELECT 1) x LEFT JOIN public.user_reputation_events ue
      ON ue.event_id = p_event_id AND ue.rater_user_id = v_uid AND ue.ratee_user_id = w.organiser;
  SELECT jsonb_build_object('venue_id', w.venue_id, 'mine', ve.scores) INTO v_venue
    FROM (SELECT 1) x LEFT JOIN public.venue_rating_events ve ON ve.event_id = p_event_id AND ve.rater_user_id = v_uid;
  v_any := EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = p_event_id AND rater_user_id = v_uid)
        OR EXISTS (SELECT 1 FROM public.venue_rating_events WHERE event_id = p_event_id AND rater_user_id = v_uid);
  v_state := CASE WHEN now() > w.closes_at THEN 'closed'
                  WHEN pr.submitted_at IS NOT NULL THEN 'submitted'
                  WHEN v_any THEN 'partly_saved'
                  ELSE 'not_started' END;
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'state', v_state, 'opens_at', w.opens_at, 'closes_at', w.closes_at, 'read_only', now() > w.closes_at,
    'dismissed', pr.dismissed_at IS NOT NULL, 'players', v_players,
    'organiser', CASE WHEN w.organiser IS NOT NULL AND w.organiser <> v_uid THEN v_org END,
    'venue', CASE WHEN w.venue_id IS NOT NULL THEN v_venue END));
END;
$function$;

-- 5. Sweep -----------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.ratings_sweep(p_now timestamptz DEFAULT now())
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; w record; v_u uuid; pr record; v_prompted int := 0; v_reminded int := 0; v_fail int := 0;
BEGIN
  FOR v_e IN SELECT f.event_id FROM public.event_attendance_finalizations f
              WHERE f.finalized_at >= timestamptz '2026-11-18 11:45:00+00' AND f.finalized_at <= p_now
                AND f.finalized_at > p_now - interval '10 days' LOOP
    BEGIN
      SELECT * INTO w FROM public.ratings_window(v_e);
      CONTINUE WHEN NOT w.ratable OR p_now > w.closes_at;
      FOR v_u IN SELECT u FROM public.ratings_eligible(v_e) u LOOP
        SELECT * INTO pr FROM public.event_rating_prompts p WHERE p.user_id = v_u AND p.event_id = v_e FOR UPDATE;
        IF NOT FOUND THEN
          INSERT INTO public.event_rating_prompts (user_id, event_id, prompted_at) VALUES (v_u, v_e, p_now);
          PERFORM public.ratings_notify(v_e, v_u, 'activity.post_activity', jsonb_build_object('closes_at', w.closes_at));
          v_prompted := v_prompted + 1;
        ELSIF pr.reminded_at IS NULL AND pr.dismissed_at IS NULL AND pr.submitted_at IS NULL
              AND p_now >= w.closes_at - interval '6 hours'
              AND NOT EXISTS (SELECT 1 FROM public.user_reputation_events WHERE event_id = v_e AND rater_user_id = v_u)
              AND NOT EXISTS (SELECT 1 FROM public.venue_rating_events WHERE event_id = v_e AND rater_user_id = v_u) THEN
          UPDATE public.event_rating_prompts SET reminded_at = p_now, updated_at = now()
           WHERE user_id = v_u AND event_id = v_e AND feedback_kind = 'event_rating';
          PERFORM public.ratings_notify(v_e, v_u, 'activity.rating_reminder', jsonb_build_object('closes_at', w.closes_at));
          v_reminded := v_reminded + 1;
        END IF;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'ratings_sweep: event % failed: % %', v_e, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  RETURN jsonb_build_object('prompted', v_prompted, 'reminded', v_reminded, 'failed', v_fail);
END;
$function$;

-- 6. Grants ----------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.ratings_window(uuid), public.ratings_eligible(uuid), public.ratings_guard(uuid, uuid),
  public.ratings_check_scores(jsonb, text), public.ratings_rater_profile(uuid),
  public.ratings_put_person(uuid, uuid, uuid, uuid, jsonb, text), public.ratings_notify(uuid, uuid, text, jsonb),
  public.ratings_sweep(timestamptz),
  public.rpc_rate_player(uuid, uuid, jsonb, text), public.rpc_rate_organiser(uuid, jsonb, text),
  public.rpc_rate_venue(uuid, jsonb, text), public.rpc_rating_submit(uuid), public.rpc_rating_dismiss(uuid),
  public.rpc_rating_get(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ratings_window(uuid), public.ratings_eligible(uuid), public.ratings_guard(uuid, uuid),
  public.ratings_check_scores(jsonb, text), public.ratings_rater_profile(uuid),
  public.ratings_put_person(uuid, uuid, uuid, uuid, jsonb, text), public.ratings_notify(uuid, uuid, text, jsonb),
  public.ratings_sweep(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.rpc_rate_player(uuid, uuid, jsonb, text), public.rpc_rate_organiser(uuid, jsonb, text),
  public.rpc_rate_venue(uuid, jsonb, text), public.rpc_rating_submit(uuid), public.rpc_rating_dismiss(uuid),
  public.rpc_rating_get(uuid)
  TO authenticated, service_role;

-- 7. Kinds and the sweep job -----------------------------------------------------------------------------------------
UPDATE public.notification_kinds SET is_active = true
 WHERE key IN ('activity.post_activity', 'activity.rating_reminder');

SELECT cron.schedule('kan997_ratings_sweep', '*/5 * * * *', 'SELECT public.ratings_sweep()');

-- 8. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(p.oid::regprocedure::text || ' ' || COALESCE(p.proacl::text, 'NULL'), '; ') INTO v_bad
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND (p.proname LIKE 'ratings\_%' OR p.proname IN ('rpc_rate_player', 'rpc_rate_organiser', 'rpc_rate_venue',
                                                        'rpc_rating_submit', 'rpc_rating_dismiss', 'rpc_rating_get'))
     AND (NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
          OR p.proacl::text LIKE '%anon=%' OR p.proacl::text LIKE '%{=X%' OR p.proacl::text LIKE '%,=X%'
          OR (p.proname LIKE 'ratings\_%' AND p.proacl::text LIKE '%authenticated=%')
          OR (p.proname LIKE 'rpc\_%' AND p.proacl::text NOT LIKE '%authenticated=X%'));
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'kan997 post-image: function attributes: %', v_bad; END IF;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_rate_venue') <> 1 THEN
    RAISE EXCEPTION 'kan997 post-image: rpc_rate_venue overloads';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.role_table_grants
              WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated', 'PUBLIC')
                AND table_name IN ('user_reputation_events', 'venue_rating_events', 'event_rating_prompts')) THEN
    RAISE EXCEPTION 'kan997 post-image: a client grant exists on a rating table';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('activity.post_activity', 'activity.rating_reminder') AND is_active) <> 2 THEN
    RAISE EXCEPTION 'kan997 post-image: kinds not active';
  END IF;
END
$post$;

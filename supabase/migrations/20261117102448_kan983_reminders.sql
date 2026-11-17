-- KAN-983 [W1-B5] Reminders: the 24h / 09:00 local / 2h / 30m ladder for games and meetups.
--
-- Rules (Epic KAN-973; review F-3, F-4, F-5, I-3, I-5, G-13):
--   * Ladder: 24h before; 09:00 on the event's local date (event_timezone) only if that is earlier than 2h before;
--     2h before; 30m before. The 30m rung is never skipped (a Live Activity does not replace it, and there is no
--     separate activity.starting_soon push).
--   * Going (active game_roster row, meetup_rsvps 'going') gets the ladder with game.reminder / meetup.reminder.
--     Interested (meetup_rsvps 'interested') gets the same ladder; its 09:00 rung is meetup.confirm_attendance
--     ("... is today at 6:30 PM · Are you going?") answered with rpc_answer_meetup_attendance. 'Not going' stops it.
--   * Planned on join (triggers on game_roster and meetup_rsvps); a late joiner gets only the rungs still ahead.
--     Re-planned when schedule_revision bumps (read from the KAN-976 event_changes outbox, consumer key 'w1_b5';
--     no trigger on events). Pending jobs are deleted on cancel, leave, removal and 'Not going'.
--   * At send time the worker checks again: event exists, not cancelled, same schedule_revision, not expired,
--     not started, still a participant, rung on in notification_settings.reminder_rungs. Any failure: the job
--     is 'skipped' with skip_reason. A job past expires_at (the next rung, or the start) is dropped, not sent late.
--   * One job per (user, event, revision, rung): dedupe_key 'reminder:<user>:<event>:<rev>:<rung>', unique here and
--     passed to notify_v2 as its dedupe key, so a second worker run cannot send twice.
--   * Jobs: pending -> claimed (FOR UPDATE SKIP LOCKED, lease) -> sent | skipped | failed (5 attempts).
--   * notification_jobs and its sequence: service_role only. Reminders break quiet hours (kinds have breaks_quiet).
--   * Replaces schedule_game_reminders_for_user (dead: no callers, wrote to a table that did not exist).

-- 0. Pre-image guard ---------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF to_regclass('public.notification_jobs') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-983 guard: public.notification_jobs already exists';
  END IF;
  IF to_regprocedure('public.schedule_game_reminders_for_user(uuid,uuid,timestamp with time zone,jsonb)') IS NULL THEN
    RAISE EXCEPTION 'KAN-983 guard: schedule_game_reminders_for_user missing';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname <> 'schedule_game_reminders_for_user'
                AND p.prosrc ILIKE '%schedule_game_reminders_for_user%') THEN
    RAISE EXCEPTION 'KAN-983 guard: schedule_game_reminders_for_user has a caller';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('game.reminder', 'meetup.reminder', 'meetup.confirm_attendance')) <> 3 THEN
    RAISE EXCEPTION 'KAN-983 guard: reminder kinds missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_kinds WHERE key = 'activity.starting_soon') THEN
    RAISE EXCEPTION 'KAN-983 guard: activity.starting_soon exists; the 30m rung is the only starting-soon push';
  END IF;
  IF to_regprocedure('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)') IS NULL
     OR to_regprocedure('public.event_timezone(uuid)') IS NULL
     OR to_regclass('public.event_changes') IS NULL THEN
    RAISE EXCEPTION 'KAN-983 guard: Wave 0 contract missing (notify_v2, event_timezone, event_changes)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'events' AND column_name = 'schedule_revision')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'notification_settings'
                    AND column_name = 'reminder_rungs') THEN
    RAISE EXCEPTION 'KAN-983 guard: events.schedule_revision or notification_settings.reminder_rungs missing';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan983_reminders_worker') THEN
    RAISE EXCEPTION 'KAN-983 guard: cron job kan983_reminders_worker exists';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games WHERE id <> event_id)
     OR EXISTS (SELECT 1 FROM public.meetups WHERE id <> event_id) THEN
    RAISE EXCEPTION 'KAN-983 guard: games.id / meetups.id no longer equal events.id';
  END IF;
END
$guard$;

-- 1. The old dead function -------------------------------------------------------------------------------------------
DROP FUNCTION public.schedule_game_reminders_for_user(uuid, uuid, timestamp with time zone, jsonb);

-- 2. notification_jobs -----------------------------------------------------------------------------------------------
CREATE TABLE public.notification_jobs (
  id                bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  job_type          text        NOT NULL DEFAULT 'reminder' CHECK (job_type = 'reminder'),
  event_id          uuid        NOT NULL REFERENCES public.events (id) ON DELETE CASCADE,
  event_type        text        NOT NULL CHECK (event_type IN ('game', 'meetup')),
  user_id           uuid        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  audience          text        NOT NULL CHECK (audience IN ('going', 'interested')),
  rung              text        NOT NULL CHECK (rung IN ('24h', '09:00', '2h', '30m')),
  kind_key          text        NOT NULL REFERENCES public.notification_kinds (key),
  schedule_revision integer     NOT NULL,
  due_at            timestamptz NOT NULL,
  expires_at        timestamptz NOT NULL,
  status            text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'claimed', 'sent', 'skipped', 'failed')),
  lease_until       timestamptz,
  attempts          smallint    NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  retry_at          timestamptz,
  skip_reason       text,
  last_error        text,
  notification_id   uuid,
  sent_at           timestamptz,
  dedupe_key        text        NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_jobs_dedupe_key_key UNIQUE (dedupe_key),
  CONSTRAINT notification_jobs_expires_after_due CHECK (expires_at > due_at),
  CONSTRAINT notification_jobs_claim_has_lease CHECK (status <> 'claimed' OR lease_until IS NOT NULL)
);

CREATE INDEX notification_jobs_due_idx ON public.notification_jobs (due_at) WHERE status IN ('pending', 'claimed');
CREATE INDEX notification_jobs_event_user_idx ON public.notification_jobs (event_id, user_id);
CREATE INDEX notification_jobs_user_idx ON public.notification_jobs (user_id);

COMMENT ON TABLE public.notification_jobs IS
  'KAN-983: reminder queue (24h / 09:00 local / 2h / 30m). One row per (user, event, schedule_revision, rung). '
  'Written by the reminder_* planner, sent by reminder_worker_run (cron kan983_reminders_worker). service_role only.';
COMMENT ON COLUMN public.notification_jobs.expires_at IS
  'KAN-983: the next rung''s due time, or the start for the 30m rung. A job not sent by then is skipped (expired).';
COMMENT ON COLUMN public.notification_jobs.skip_reason IS
  'KAN-983: event_missing | event_cancelled | revision_changed | expired | started | not_participant | '
  'rung_disabled | not_written (notify_v2 wrote nothing: kind inactive, muted, blocked) | max_attempts.';

ALTER TABLE public.notification_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.notification_jobs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notification_jobs TO service_role;
REVOKE ALL ON SEQUENCE public.notification_jobs_id_seq FROM PUBLIC, anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.notification_jobs_id_seq TO service_role;

-- 3. Helpers ---------------------------------------------------------------------------------------------------------
-- The ladder for one start time in one timezone. expires_at is the next rung's due time (the start for 30m).
CREATE FUNCTION public.reminder_rung_times(p_start_at timestamptz, p_tz text)
 RETURNS TABLE (rung text, due_at timestamptz, expires_at timestamptz)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  WITH l(rung, due) AS (
    SELECT '24h'::text, p_start_at - interval '24 hours'
    UNION ALL
    SELECT '09:00', ((p_start_at AT TIME ZONE p_tz)::date + time '09:00') AT TIME ZONE p_tz
     WHERE ((p_start_at AT TIME ZONE p_tz)::date + time '09:00') AT TIME ZONE p_tz < p_start_at - interval '2 hours'
    UNION ALL
    SELECT '2h', p_start_at - interval '2 hours'
    UNION ALL
    SELECT '30m', p_start_at - interval '30 minutes'
  )
  SELECT l.rung, l.due, coalesce(lead(l.due) OVER (ORDER BY l.due), p_start_at)
    FROM l
   ORDER BY l.due;
$function$;

-- 'going' | 'interested' | NULL. games.id and meetups.id equal events.id (checked by the guard).
CREATE FUNCTION public.reminder_audience(p_event_id uuid, p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT CASE
           WHEN EXISTS (SELECT 1 FROM public.game_roster r
                         WHERE r.game_id = p_event_id AND r.user_id = p_user_id AND r.status = 'active')
             THEN 'going'
           ELSE (SELECT s.status FROM public.meetup_rsvps s
                  WHERE s.meetup_id = p_event_id AND s.user_id = p_user_id
                    AND s.status IN ('going', 'interested'))
         END;
$function$;

CREATE FUNCTION public.reminder_kind(p_event_type text, p_audience text, p_rung text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  SELECT CASE
           WHEN p_event_type = 'game' THEN 'game.reminder'
           WHEN p_audience = 'interested' AND p_rung = '09:00' THEN 'meetup.confirm_attendance'
           ELSE 'meetup.reminder'
         END;
$function$;

-- A user with no notification_settings row has every rung on (the column default).
CREATE FUNCTION public.reminder_rung_enabled(p_user_id uuid, p_audience text, p_rung text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT coalesce((SELECT (s.reminder_rungs -> p_audience ->> p_rung)::boolean
                     FROM public.notification_settings s WHERE s.user_id = p_user_id), true);
$function$;

-- 4. Planner ---------------------------------------------------------------------------------------------------------
-- (Re)plans one person's jobs for one event: deletes their pending jobs, then plans the rungs still ahead for the
-- current revision. Claimed / sent / skipped rows are kept; the dedupe key stops a rung being planned twice.
CREATE FUNCTION public.reminder_plan_member(p_event_id uuid, p_user_id uuid, p_now timestamptz DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  e     record;
  v_aud text;
  v_tz  text;
  n     integer := 0;
BEGIN
  IF p_event_id IS NULL OR p_user_id IS NULL THEN
    RETURN 0;
  END IF;

  DELETE FROM public.notification_jobs j
   WHERE j.event_id = p_event_id AND j.user_id = p_user_id AND j.status = 'pending';

  SELECT ev.id, ev.event_type, ev.start_at, ev.is_cancelled, ev.schedule_revision
    INTO e
    FROM public.events ev
   WHERE ev.id = p_event_id;
  IF e.id IS NULL OR e.is_cancelled OR e.start_at <= p_now THEN
    RETURN 0;
  END IF;

  v_aud := public.reminder_audience(p_event_id, p_user_id);
  IF v_aud IS NULL THEN
    RETURN 0;
  END IF;

  v_tz := coalesce(public.event_timezone(p_event_id), 'Asia/Dubai');

  INSERT INTO public.notification_jobs
         (event_id, event_type, user_id, audience, rung, kind_key, schedule_revision, due_at, expires_at, dedupe_key)
  SELECT p_event_id, e.event_type, p_user_id, v_aud, t.rung, public.reminder_kind(e.event_type, v_aud, t.rung),
         e.schedule_revision, t.due_at, t.expires_at,
         format('reminder:%s:%s:%s:%s', p_user_id, p_event_id, e.schedule_revision, t.rung)
    FROM public.reminder_rung_times(e.start_at, v_tz) t
   WHERE t.due_at > p_now
  ON CONFLICT (dedupe_key) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$function$;

-- Re-plans every participant of one event (after a schedule change, a cancel or an un-cancel).
CREATE FUNCTION public.reminder_plan_event(p_event_id uuid, p_now timestamptz DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  u uuid;
  n integer := 0;
BEGIN
  DELETE FROM public.notification_jobs j WHERE j.event_id = p_event_id AND j.status = 'pending';
  FOR u IN
    SELECT r.user_id FROM public.game_roster r WHERE r.game_id = p_event_id AND r.status = 'active'
    UNION
    SELECT s.user_id FROM public.meetup_rsvps s
     WHERE s.meetup_id = p_event_id AND s.status IN ('going', 'interested')
  LOOP
    n := n + public.reminder_plan_member(p_event_id, u, p_now);
  END LOOP;
  RETURN n;
END;
$function$;

-- Reads the KAN-976 outbox: every row not yet stamped 'w1_b5' is stamped; events with a schedule change or a
-- cancel flip are re-planned. Returns the number of events re-planned.
CREATE FUNCTION public.reminder_sync_event_changes(p_now timestamptz DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_ids    bigint[];
  v_events uuid[];
  ev       uuid;
  n        integer := 0;
BEGIN
  SELECT array_agg(c.id), array_agg(DISTINCT c.event_id) FILTER (WHERE c.schedule_change OR c.field = 'is_cancelled')
    INTO v_ids, v_events
    FROM (SELECT x.id, x.event_id, x.schedule_change, x.field
            FROM public.event_changes x
           WHERE NOT (x.consumed_by ? 'w1_b5')
           ORDER BY x.id
           LIMIT 1000
             FOR UPDATE SKIP LOCKED) c;
  IF v_ids IS NULL THEN
    RETURN 0;
  END IF;

  UPDATE public.event_changes x
     SET consumed_by = x.consumed_by || jsonb_build_object('w1_b5', p_now)
   WHERE x.id = ANY (v_ids);

  FOREACH ev IN ARRAY coalesce(v_events, '{}'::uuid[]) LOOP
    PERFORM public.reminder_plan_event(ev, p_now);
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$function$;

-- 5. Worker ----------------------------------------------------------------------------------------------------------
-- Claims due jobs (and jobs whose lease ran out). Each claim counts as an attempt.
CREATE FUNCTION public.reminder_jobs_claim(p_limit integer DEFAULT 200, p_now timestamptz DEFAULT now(),
                                           p_lease interval DEFAULT interval '2 minutes')
 RETURNS SETOF bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  WITH due AS (
    SELECT j.id
      FROM public.notification_jobs j
     WHERE (j.status = 'pending' AND coalesce(j.retry_at, j.due_at) <= p_now)
        OR (j.status = 'claimed' AND j.lease_until < p_now)
     ORDER BY j.due_at
     LIMIT p_limit
       FOR UPDATE SKIP LOCKED
  )
  UPDATE public.notification_jobs j
     SET status = 'claimed', lease_until = p_now + p_lease, attempts = j.attempts + 1, updated_at = now()
    FROM due
   WHERE j.id = due.id
  RETURNING j.id;
END;
$function$;

-- Sends one claimed job after re-checking everything. Returns 'sent', 'skipped:<reason>', 'failed:max_attempts',
-- 'missing' or 'not_claimed:<status>'.
CREATE FUNCTION public.reminder_job_process(p_job_id bigint, p_now timestamptz DEFAULT now())
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  j         public.notification_jobs%ROWTYPE;
  e         record;
  v_aud     text;
  v_reason  text;
  v_kind    text;
  v_tz      text;
  v_local   timestamp;
  v_title_en text;
  v_title_ar text;
  v_time_en text;
  v_time_ar text;
  v_when_en text;
  v_when_ar text;
  v_args    jsonb;
  v_id      uuid;
BEGIN
  SELECT * INTO j FROM public.notification_jobs WHERE id = p_job_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN 'missing';
  END IF;
  IF j.status <> 'claimed' THEN
    RETURN 'not_claimed:' || j.status;
  END IF;
  IF j.attempts > 5 THEN
    UPDATE public.notification_jobs
       SET status = 'failed', skip_reason = 'max_attempts', lease_until = NULL, updated_at = now()
     WHERE id = j.id;
    RETURN 'failed:max_attempts';
  END IF;

  SELECT ev.id, ev.event_type, ev.title, ev.start_at, ev.is_cancelled, ev.schedule_revision
    INTO e
    FROM public.events ev
   WHERE ev.id = j.event_id;

  v_reason := CASE
                WHEN e.id IS NULL                                THEN 'event_missing'
                WHEN e.is_cancelled                              THEN 'event_cancelled'
                WHEN e.schedule_revision <> j.schedule_revision  THEN 'revision_changed'
                WHEN p_now >= j.expires_at                       THEN 'expired'
                WHEN p_now >= e.start_at                         THEN 'started'
              END;
  IF v_reason IS NULL THEN
    v_aud := public.reminder_audience(j.event_id, j.user_id);
    IF v_aud IS NULL THEN
      v_reason := 'not_participant';
    ELSIF NOT public.reminder_rung_enabled(j.user_id, v_aud, j.rung) THEN
      v_reason := 'rung_disabled';
    END IF;
  END IF;

  IF v_reason IS NOT NULL THEN
    UPDATE public.notification_jobs
       SET status = 'skipped', skip_reason = v_reason, lease_until = NULL, updated_at = now()
     WHERE id = j.id;
    RETURN 'skipped:' || v_reason;
  END IF;

  -- The audience is read again here, so someone who moved Interested -> Going gets the Going copy.
  v_kind  := public.reminder_kind(e.event_type, v_aud, j.rung);
  v_tz    := coalesce(public.event_timezone(e.id), 'Asia/Dubai');
  v_local := e.start_at AT TIME ZONE v_tz;
  v_time_en := to_char(v_local, 'FMHH12:MI AM');
  v_time_ar := to_char(v_local, 'FMHH12:MI') || CASE WHEN extract(hour FROM v_local) < 12 THEN ' ص' ELSE ' م' END;
  v_title_en := coalesce(nullif(btrim(e.title), ''), CASE WHEN e.event_type = 'game' THEN 'Your game' ELSE 'Your meet-up' END);
  v_title_ar := coalesce(nullif(btrim(e.title), ''), CASE WHEN e.event_type = 'game' THEN 'مباراتك' ELSE 'لقاؤك' END);
  v_when_en := CASE j.rung
                 WHEN '24h'   THEN 'tomorrow at ' || v_time_en
                 WHEN '09:00' THEN 'today at ' || v_time_en
                 WHEN '2h'    THEN 'in 2 hours'
                 ELSE              'in 30 minutes'
               END;
  v_when_ar := CASE j.rung
                 WHEN '24h'   THEN 'غدًا الساعة ' || v_time_ar
                 WHEN '09:00' THEN 'اليوم الساعة ' || v_time_ar
                 WHEN '2h'    THEN 'خلال ساعتين'
                 ELSE              'خلال 30 دقيقة'
               END;

  v_args := jsonb_build_object(
              'title_en', v_title_en, 'title_ar', v_title_ar,
              'time_en', v_time_en,   'time_ar', v_time_ar,
              'when_en', v_when_en,   'when_ar', v_when_ar,
              'rung', j.rung, 'audience', v_aud, 'event_id', e.id, 'event_type', e.event_type,
              'starts_at', e.start_at, 'schedule_revision', e.schedule_revision)
         || CASE WHEN v_kind = 'meetup.confirm_attendance'
                 THEN jsonb_build_object('actions', jsonb_build_array('going', 'not_going'))
                 ELSE '{}'::jsonb END;

  v_id := public.notify_v2(j.user_id, v_kind, v_args, e.event_type, e.id, NULL,
                           'notification_jobs:' || j.id, j.dedupe_key, NULL, NULL);

  IF v_id IS NULL THEN
    UPDATE public.notification_jobs
       SET status = 'skipped', skip_reason = 'not_written', kind_key = v_kind, lease_until = NULL, updated_at = now()
     WHERE id = j.id;
    RETURN 'skipped:not_written';
  END IF;

  UPDATE public.notification_jobs
     SET status = 'sent', notification_id = v_id, kind_key = v_kind, sent_at = now(), lease_until = NULL,
         skip_reason = NULL, last_error = NULL, updated_at = now()
   WHERE id = j.id;
  RETURN 'sent';
END;
$function$;

-- One cron tick: read the outbox, claim, send. A job whose send raises goes back to pending with a back-off,
-- or to failed after 5 attempts.
CREATE FUNCTION public.reminder_worker_run(p_limit integer DEFAULT 200, p_now timestamptz DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_replanned integer;
  v_ids       bigint[];
  v_id        bigint;
  v_res       text;
  v_sent      integer := 0;
  v_skipped   integer := 0;
  v_failed    integer := 0;
  v_retry     integer := 0;
  v_reasons   jsonb := '{}'::jsonb;
BEGIN
  v_replanned := public.reminder_sync_event_changes(p_now);
  v_ids := ARRAY(SELECT public.reminder_jobs_claim(p_limit, p_now));

  FOREACH v_id IN ARRAY v_ids LOOP
    BEGIN
      v_res := public.reminder_job_process(v_id, p_now);
      IF v_res = 'sent' THEN
        v_sent := v_sent + 1;
      ELSIF v_res LIKE 'skipped:%' THEN
        v_skipped := v_skipped + 1;
        v_reasons := v_reasons || jsonb_build_object(substr(v_res, 9),
                                                     coalesce((v_reasons ->> substr(v_res, 9))::int, 0) + 1);
      ELSIF v_res LIKE 'failed:%' THEN
        v_failed := v_failed + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.notification_jobs j
         SET status      = CASE WHEN j.attempts >= 5 THEN 'failed' ELSE 'pending' END,
             skip_reason = CASE WHEN j.attempts >= 5 THEN 'max_attempts' END,
             retry_at    = p_now + make_interval(mins => j.attempts),
             lease_until = NULL,
             last_error  = left(SQLERRM, 500),
             updated_at  = now()
       WHERE j.id = v_id;
      v_retry := v_retry + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object('replanned_events', v_replanned, 'claimed', cardinality(v_ids), 'sent', v_sent,
                            'skipped', v_skipped, 'skip_reasons', v_reasons, 'failed', v_failed, 'errored', v_retry);
END;
$function$;

-- 6. Membership triggers (new; no existing RPC or trigger is edited) ---------------------------------------------------
-- A planning error must not block a join or a leave: it is raised as a WARNING and the send-time checks still hold.
CREATE FUNCTION public.kan983_roster_reminders()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
      PERFORM public.reminder_plan_member(NEW.game_id, NEW.user_id);
    END IF;
    IF TG_OP = 'DELETE'
       OR (TG_OP = 'UPDATE' AND (OLD.user_id IS DISTINCT FROM NEW.user_id OR OLD.game_id IS DISTINCT FROM NEW.game_id)) THEN
      PERFORM public.reminder_plan_member(OLD.game_id, OLD.user_id);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'kan983_roster_reminders: % (%)', SQLERRM, SQLSTATE;
  END;
  RETURN NULL;
END;
$function$;

CREATE FUNCTION public.kan983_rsvp_reminders()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
      PERFORM public.reminder_plan_member(NEW.meetup_id, NEW.user_id);
    END IF;
    IF TG_OP = 'DELETE'
       OR (TG_OP = 'UPDATE' AND (OLD.user_id IS DISTINCT FROM NEW.user_id OR OLD.meetup_id IS DISTINCT FROM NEW.meetup_id)) THEN
      PERFORM public.reminder_plan_member(OLD.meetup_id, OLD.user_id);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'kan983_rsvp_reminders: % (%)', SQLERRM, SQLSTATE;
  END;
  RETURN NULL;
END;
$function$;

CREATE TRIGGER trg_kan983_roster_reminders
  AFTER INSERT OR DELETE OR UPDATE OF status, user_id, game_id ON public.game_roster
  FOR EACH ROW EXECUTE FUNCTION public.kan983_roster_reminders();

CREATE TRIGGER trg_kan983_rsvp_reminders
  AFTER INSERT OR DELETE OR UPDATE OF status, user_id, meetup_id ON public.meetup_rsvps
  FOR EACH ROW EXECUTE FUNCTION public.kan983_rsvp_reminders();

-- 7. The 09:00 card's answer -------------------------------------------------------------------------------------------
-- Only for the caller's current Going/Interested RSVP. Returns the resulting status.
--   'going'     -> Interested becomes Going when the meetup is upcoming, not cancelled and has a free slot; when full it
--                  stays 'interested' (same rule as rpc_meetup_rsvp). rpc_meetup_rsvp itself refuses a current member
--                  ('already'), so the upgrade is done here on the caller's own row.
--   'not_going' -> rpc_meetup_rsvp(..., 'cancel') -> 'cancelled', which stops the reminders.
-- Definer because authenticated has no SELECT/UPDATE on meetup_rsvps; it touches only auth.uid()'s own row.
CREATE FUNCTION public.rpc_answer_meetup_attendance(p_meetup_id uuid, p_answer text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_status text;
  v_cancel boolean;
  v_start  timestamptz;
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

  SELECT e.is_cancelled, e.start_at INTO v_cancel, v_start
    FROM public.events e WHERE e.id = p_meetup_id AND e.event_type = 'meetup';
  IF v_cancel IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'not_found';
  ELSIF v_cancel THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'cancelled';
  ELSIF v_start <= now() THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'started';
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

-- 8. Grants: server functions are service_role only (pg_default_acl grants anon/authenticated by name) -----------------
REVOKE ALL ON FUNCTION public.reminder_rung_times(timestamptz, text)                 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_audience(uuid, uuid)                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_kind(text, text, text)                        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_rung_enabled(uuid, text, text)                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_plan_member(uuid, uuid, timestamptz)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_plan_event(uuid, timestamptz)                 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_sync_event_changes(timestamptz)               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_jobs_claim(integer, timestamptz, interval)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_job_process(bigint, timestamptz)              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reminder_worker_run(integer, timestamptz)              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan983_roster_reminders()                              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan983_rsvp_reminders()                                FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reminder_rung_times(timestamptz, text)              TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_audience(uuid, uuid)                       TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_kind(text, text, text)                     TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_rung_enabled(uuid, text, text)             TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_plan_member(uuid, uuid, timestamptz)       TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_plan_event(uuid, timestamptz)              TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_sync_event_changes(timestamptz)            TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_jobs_claim(integer, timestamptz, interval) TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_job_process(bigint, timestamptz)           TO service_role;
GRANT EXECUTE ON FUNCTION public.reminder_worker_run(integer, timestamptz)           TO service_role;
REVOKE ALL ON FUNCTION public.rpc_answer_meetup_attendance(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_answer_meetup_attendance(uuid, text) TO authenticated, service_role;

-- 9. Kinds: one copy pattern for every rung (G.9); the meetup kinds are activated here ---------------------------------
UPDATE public.notification_kinds
   SET title_template_en = '{title} starts {when}',
       title_template_ar = 'تبدأ {title} {when}',
       timing            = '{"rungs": ["24h", "09:00", "2h", "30m"], "sender": "reminder_worker_run"}'::jsonb
 WHERE key = 'game.reminder';
UPDATE public.notification_kinds
   SET is_active = true,
       timing    = '{"rungs": ["24h", "09:00", "2h", "30m"], "sender": "reminder_worker_run"}'::jsonb
 WHERE key = 'meetup.reminder';
UPDATE public.notification_kinds
   SET is_active = true,
       timing    = '{"rungs": ["09:00"], "audience": "interested", "sender": "reminder_worker_run"}'::jsonb
 WHERE key = 'meetup.confirm_attendance';

-- 10. Backfill: outbox rows so far are covered by planning the current state; plan every upcoming participant ---------
UPDATE public.event_changes x
   SET consumed_by = x.consumed_by || jsonb_build_object('w1_b5', now())
 WHERE NOT (x.consumed_by ? 'w1_b5');

SELECT public.reminder_plan_event(e.id)
  FROM public.events e
 WHERE e.start_at > now() AND NOT e.is_cancelled;

-- 11. Cron: every minute --------------------------------------------------------------------------------------------
SELECT cron.schedule('kan983_reminders_worker', '* * * * *', 'SELECT public.reminder_worker_run();');

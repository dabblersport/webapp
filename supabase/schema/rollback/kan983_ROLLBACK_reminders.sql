-- KAN-983 rollback: removes everything 20261117102448_kan983_reminders added and puts the kinds back as they were on
-- 2026-11-17 (game.reminder static copy; meetup.reminder and meetup.confirm_attendance inactive). The old dead
-- schedule_game_reminders_for_user is NOT recreated: it wrote to a table that did not exist and had no callers.
-- Run as postgres on wtncuzcskpigqpmnxwws only if KAN-983 must be undone. No CASCADE on purpose.
BEGIN;
SELECT cron.unschedule('kan983_reminders_worker');
DROP TRIGGER trg_kan983_roster_reminders ON public.game_roster;
DROP TRIGGER trg_kan983_rsvp_reminders ON public.meetup_rsvps;
DROP FUNCTION public.kan983_roster_reminders();
DROP FUNCTION public.kan983_rsvp_reminders();
DROP FUNCTION public.rpc_answer_meetup_attendance(uuid, text);
DROP FUNCTION public.reminder_worker_run(integer, timestamptz);
DROP FUNCTION public.reminder_job_process(bigint, timestamptz);
DROP FUNCTION public.reminder_jobs_claim(integer, timestamptz, interval);
DROP FUNCTION public.reminder_sync_event_changes(timestamptz);
DROP FUNCTION public.reminder_plan_event(uuid, timestamptz);
DROP FUNCTION public.reminder_plan_member(uuid, uuid, timestamptz);
DROP FUNCTION public.reminder_rung_enabled(uuid, text, text);
DROP FUNCTION public.reminder_kind(text, text, text);
DROP FUNCTION public.reminder_audience(uuid, uuid);
DROP FUNCTION public.reminder_rung_times(timestamptz, text);
DROP TABLE public.notification_jobs;
UPDATE public.notification_kinds
   SET title_template_en = 'Your game starts soon', title_template_ar = 'مباراتك تبدأ قريبًا',
       timing = '{"reminder_offsets": ["-24h", "-2h", "-30m"]}'::jsonb
 WHERE key = 'game.reminder';
UPDATE public.notification_kinds SET is_active = false, timing = NULL
 WHERE key IN ('meetup.reminder', 'meetup.confirm_attendance');
UPDATE public.event_changes SET consumed_by = consumed_by - 'w1_b5' WHERE consumed_by ? 'w1_b5';
COMMIT;

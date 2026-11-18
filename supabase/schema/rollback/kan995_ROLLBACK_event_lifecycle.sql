-- KAN-995 rollback: undoes 20261118053016_kan995_event_lifecycle, nothing else. Run as postgres on
-- wtncuzcskpigqpmnxwws only if KAN-995 must be undone. KAN-994's attendance_lifecycle() calls event_lifecycle_state()
-- dynamically and falls back to the scheduled end when it is missing, so it keeps working after this rollback.
-- Notifications already sent stay in the inbox.
BEGIN;
SELECT cron.unschedule('kan995_lifecycle_every_minute');
DROP FUNCTION public.kan995_lifecycle_worker(timestamptz);
DROP FUNCTION public.rpc_event_confirm_end(uuid, text);
DROP FUNCTION public.rpc_event_start(uuid);
DROP FUNCTION public.event_lifecycle_state(uuid);
DROP FUNCTION public.kan995_ensure(uuid);
DROP FUNCTION public.kan995_transition(uuid, text, uuid, text, timestamptz, text, timestamptz);
DROP FUNCTION public.kan995_scheduled_end(timestamptz, timestamptz);
DROP TABLE public.event_lifecycle_transitions;
DROP TABLE public.event_lifecycle;
UPDATE public.notification_kinds SET is_active = false
 WHERE key IN ('activity.confirm_end', 'activity.confirm_end_reminder', 'activity.auto_closed', 'activity.ended');
COMMIT;

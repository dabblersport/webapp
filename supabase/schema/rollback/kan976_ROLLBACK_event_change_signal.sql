-- KAN-976 rollback: removes everything 20261117045201_kan976_event_change_signal and its PEER fix
-- 20261117053118_kan976b_event_changes_seq_acl_tz_names and 20261117054042_kan976c_event_timezone_fast_zone_check added
-- (the sequence goes with the table; both follow-ups are undone by the DROPs below), nothing else.
-- Run as postgres on wtncuzcskpigqpmnxwws only if KAN-976 must be undone. Consumers of event_changes, schedule_revision
-- or event_timezone (W1-B3, W1-B5 / KAN-983, KAN-981) must be rolled back first; the DROPs below fail loudly if a
-- dependent object exists (no CASCADE on purpose).
BEGIN;
DROP TRIGGER trg_kan976_events_change_signal ON public.events;
DROP FUNCTION public.kan976_events_change_signal();
DROP FUNCTION public.event_timezone(uuid);
DROP TABLE public.event_changes;
ALTER TABLE public.events DROP COLUMN schedule_revision;
COMMIT;

-- Applied to live DB on 2026-07-11 (migrations: drop_broken_dead_notification_functions,
-- drop_evaluate_notification_strategy_correct_signature).
-- Two notification functions were both BROKEN and DEAD (zero callers in client
-- code, edge functions, or other DB functions):
--   evaluate_notification_strategy(uuid, text): read
--     notification_aggregation_rules.force_instant, a column that does not
--     exist — errored on any call.
--   rpc_mark_notification_read(uuid): filtered notifications.user_id, but the
--     column is to_user_id — never matched. The working paths are
--     mark_notification_read and the client's direct UPDATE.
DROP FUNCTION IF EXISTS public.evaluate_notification_strategy(uuid, text);
DROP FUNCTION IF EXISTS public.rpc_mark_notification_read(uuid);

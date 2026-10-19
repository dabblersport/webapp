-- KAN-572 probes. READ-ONLY. Run after apply; each returns one row with ok = true.
-- Demonstrated-fail note: before apply, probes 1 and 2 return ok = false (no kind, no insert).
-- 1. the kind exists, is active and carries push
SELECT 'kind' AS probe, EXISTS (SELECT 1 FROM public.notification_kinds
  WHERE key = 'message.received' AND is_active AND 'push' = ANY(default_channels)) AS ok;
-- 2. msg_notify inserts message.received and still sends Realtime
SELECT 'body' AS probe,
  pg_get_functiondef('public.msg_notify(uuid,bigint,text)'::regprocedure) LIKE '%message.received%'
  AND pg_get_functiondef('public.msg_notify(uuid,bigint,text)'::regprocedure) LIKE '%realtime.send%' AS ok;
-- 3. definer, pinned search_path, no anon/PUBLIC execute
SELECT 'acl' AS probe, p.prosecdef
  AND array_to_string(p.proconfig, ',') LIKE 'search_path=%'
  AND NOT has_function_privilege('anon', p.oid, 'EXECUTE') AS ok
  FROM pg_proc p WHERE p.oid = 'public.msg_notify(uuid,bigint,text)'::regprocedure;
-- 4. the push trigger this relies on is present
SELECT 'push_trigger' AS probe, EXISTS (SELECT 1 FROM pg_trigger
  WHERE tgname = 'trg_push_on_notification_insert' AND NOT tgisinternal) AS ok;

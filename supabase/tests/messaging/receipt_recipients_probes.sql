-- KAN-580 recipient drawer probes. NOT RUN (no local Postgres here). Run by operations after both KAN-580
-- migrations are applied, inside a transaction that ends in ROLLBACK, in a 3-member conversation.
-- P1  a member with seen_seq >= s is 'seen'; delivered_seq >= s only -> 'delivered'; no msg_receipts row -> 'sent'.
-- P2  the caller never appears in their own list.
-- P3  a member who blocked the caller does not appear; the counts per state equal msg_receipt_summary(seq).
-- P4  p_seq < 1, a NULL conversation, NULL caller or NULL member list each return zero rows.
-- P5  ONLY service_role can execute it (the CTO's condition): all three below must be false / false / false / true.
SELECT has_function_privilege('anon',          'public.msg_receipt_recipients(uuid,bigint,uuid,uuid[])', 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', 'public.msg_receipt_recipients(uuid,bigint,uuid,uuid[])', 'EXECUTE') AS authenticated_can_execute,
       has_function_privilege('public',        'public.msg_receipt_recipients(uuid,bigint,uuid,uuid[])', 'EXECUTE') AS public_can_execute,
       has_function_privilege('service_role',  'public.msg_receipt_recipients(uuid,bigint,uuid,uuid[])', 'EXECUTE') AS service_role_can_execute;
-- P1-P3 (as service_role): :conv :seq :caller :members are test values.
SELECT user_id, state FROM public.msg_receipt_recipients(:conv::uuid, :seq::bigint, :caller::uuid, :members::uuid[]);

-- Rollback (no DROP): stop exposing the function.
-- REVOKE EXECUTE ON FUNCTION public.msg_receipt_recipients(uuid, bigint, uuid, uuid[]) FROM service_role;

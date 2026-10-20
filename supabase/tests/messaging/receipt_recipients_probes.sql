-- KAN-580 recipient drawer probes. NOT RUN (no local Postgres here). Run by operations after both KAN-580
-- migrations are applied, inside a transaction that ends in ROLLBACK, as a test user in a 3-member conversation.
-- P1  a member who acked seen_seq >= s appears as 'seen'; delivered_seq >= s only -> 'delivered'; no row -> 'sent'.
-- P2  the caller never appears in their own list.
-- P3  a member who blocked the caller does not appear; the counts of states equal msg_receipt_summary(seq).
-- P4  a non-member, an anon caller, p_seq < 1 and a NULL conversation each return zero rows.
-- P5  has_function_privilege('anon', 'public.msg_receipt_recipients(uuid,bigint,text)', 'EXECUTE') is false.
SELECT (SELECT count(*) FROM public.msg_receipt_recipients(:conv::uuid, :seq::bigint)) AS listed,
       (SELECT recipients FROM public.msg_receipt_summary(:conv::uuid, ARRAY[:seq::bigint])) AS summary_recipients;
SELECT has_function_privilege('anon', 'public.msg_receipt_recipients(uuid,bigint,text)', 'EXECUTE') AS anon_can_execute;

-- Rollback (no DROP): stop exposing the function.
-- REVOKE EXECUTE ON FUNCTION public.msg_receipt_recipients(uuid, bigint, text) FROM authenticated;

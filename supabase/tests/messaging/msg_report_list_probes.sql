-- KAN-551 (Messaging launch M1a) report-list probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: a NON-PRODUCTION branch of project wtncuzcskpigqpmnxwws, after
-- 20261013161100_kan551_msg_report_list.sql is applied there. Run with psql as the branch owner.
-- Every block is READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK and ends in `rollback;`. Each block
-- prints boolean pass columns; every one must be true. No block writes app_admins or role_grants:
-- the runner supplies users who ALREADY are, or are not, admins.
--
-- Variables (non-prod test users only, supplied by the runner, no secrets here):
--   :admin_user  a user for whom public.is_admin(:admin_user) is already true
--   :plain_user  a user for whom public.is_admin(:plain_user) is false
-- e.g. psql -v admin_user=... -v plain_user=... -f msg_report_list_probes.sql
-- Report targets below are fixed test uuids; no message text exists in Supabase.

-- L1 [READ-ONLY] AUTHORED, NOT RUN. Grants and settings.
begin;
select
  not has_function_privilege('anon', 'public.msg_list_message_reports(integer)', 'EXECUTE') as pass_anon_no_exec,
  has_function_privilege('authenticated', 'public.msg_list_message_reports(integer)', 'EXECUTE') as pass_auth_exec,
  (select prosecdef from pg_proc where oid = 'public.msg_list_message_reports(integer)'::regprocedure) as pass_definer,
  (select proconfig::text like '%search_path=public, pg_temp%' from pg_proc
    where oid = 'public.msg_list_message_reports(integer)'::regprocedure) as pass_search_path;
rollback;

-- L2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Admin sees a message report; a non-message
-- report is excluded; newest first.
begin;
insert into public.moderation_reports (id, reporter_user_id, target_type, target_id, reason, created_at)
values ('00000000-0000-4000-8000-000000055101', :'plain_user', 'message', '00000000-0000-4000-8000-0000000551a1', 'spam', now() - interval '2 minutes'),
       ('00000000-0000-4000-8000-000000055102', :'plain_user', 'message', '00000000-0000-4000-8000-0000000551a2', 'spam', now() - interval '1 minute'),
       ('00000000-0000-4000-8000-000000055103', :'plain_user', 'post',    '00000000-0000-4000-8000-0000000551a3', 'spam', now());
select set_config('request.jwt.claims', json_build_object('sub', :'admin_user', 'role', 'authenticated')::text, true);
set local role authenticated;
with l as (select row_number() over () as n, * from public.msg_list_message_reports(100))
select
  exists (select 1 from l where report_id = '00000000-0000-4000-8000-000000055101') as pass_admin_sees,
  not exists (select 1 from l where report_id = '00000000-0000-4000-8000-000000055103') as pass_non_message_excluded,
  (select n from l where report_id = '00000000-0000-4000-8000-000000055102')
    < (select n from l where report_id = '00000000-0000-4000-8000-000000055101') as pass_newest_first,
  (select bool_and(conversation_id is null) from l) as pass_conversation_null;
rollback;

-- L3 [READ-ONLY] AUTHORED, NOT RUN. Non-admin refused with P0001 forbidden.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'plain_user', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  perform public.msg_list_message_reports();
  raise exception 'FAIL: non-admin was not refused';
exception when sqlstate 'P0001' then
  if sqlerrm <> 'forbidden' then raise; end if;
  raise notice 'pass_non_admin_refused';
end $$;
rollback;

-- L4 [READ-ONLY] AUTHORED, NOT RUN. anon refused (no EXECUTE: 42501).
begin;
set local role anon;
do $$
begin
  perform public.msg_list_message_reports();
  raise exception 'FAIL: anon was not refused';
exception when insufficient_privilege then
  raise notice 'pass_anon_refused';
end $$;
rollback;

-- L5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Clamp: 0 -> 1, 1000 -> 100, default 50.
begin;
insert into public.moderation_reports (reporter_user_id, target_type, target_id, reason)
select :'plain_user', 'message', gen_random_uuid(), 'spam' from generate_series(1, 120);
select set_config('request.jwt.claims', json_build_object('sub', :'admin_user', 'role', 'authenticated')::text, true);
set local role authenticated;
select
  (select count(*) from public.msg_list_message_reports(0)) = 1 as pass_zero_is_one,
  (select count(*) from public.msg_list_message_reports(1000)) = 100 as pass_thousand_is_hundred,
  (select count(*) from public.msg_list_message_reports()) = 50 as pass_default_fifty;
rollback;

-- L6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A message report creates exactly one
-- notification per app_admins row, and neither body nor context carries text beyond ids and reason.
begin;
insert into public.moderation_reports (id, reporter_user_id, target_type, target_id, reason)
values ('00000000-0000-4000-8000-000000055106', :'plain_user', 'message', '00000000-0000-4000-8000-0000000551a6', 'spam');
select
  (select count(*) from public.notifications
    where kind_key = 'moderation.report_submitted'
      and context->>'report_id' = '00000000-0000-4000-8000-000000055106')
  = (select count(*) from public.app_admins) as pass_one_per_admin_row,
  (select bool_and(body = 'message reported for spam'
                   and (select array_agg(k order by k) from jsonb_object_keys(context) k)
                       = array['reason','report_id','target_id','target_type'])
     from public.notifications
    where kind_key = 'moderation.report_submitted'
      and context->>'report_id' = '00000000-0000-4000-8000-000000055106') is not false as pass_no_text;
rollback;

-- L7 [READ-ONLY] AUTHORED, NOT RUN. Counts only, no ids: is_admin() users vs app_admins rows.
-- Not a pass/fail probe; the runner copies the four numbers into the PR text.
begin;
with adm as (select distinct user_id from public.role_grants where role in ('admin', 'super_admin')),
     aa  as (select user_id from public.app_admins)
select
  (select count(*) from adm) as is_admin_users,
  (select count(*) from aa) as app_admins_rows,
  (select count(*) from adm where user_id not in (select user_id from aa)) as is_admin_not_in_app_admins,
  (select count(*) from aa where not public.is_admin(aa.user_id)) as app_admins_not_is_admin;
rollback;

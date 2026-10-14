-- KAN-512 (Messaging T17) report probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: a NON-PRODUCTION branch of project wtncuzcskpigqpmnxwws, after the KAN-505
-- migrations and the two KAN-512 migrations are applied there. Run with psql as the
-- branch owner role. Every block is READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK and ends in
-- `rollback;`. Each block prints boolean `pass` columns; every one must be true.
--
-- Variables (non-prod test users only, ids supplied by the runner, no secrets here):
--   :user_a   pilot user, active 'player' on :game_id   (reporter / member)
--   :user_c   pilot user, NOT on :game_id's roster      (non-member)
--   :game_id  non-prod test game, end_at in the future, not cancelled, no msg_conversations row
-- e.g. psql -v user_a=... -v user_c=... -v game_id=... -f report_probes.sql
-- Message ids below are fixed test uuids; no message text exists in Supabase to read.

-- R1 [READ-ONLY] AUTHORED, NOT RUN. Violator count for the NOT VALID check: expects 0.
-- Run BEFORE any VALIDATE CONSTRAINT. A non-zero count means validation must not run.
begin;
select count(*) as violators,
       count(*) = 0 as pass_no_violators
  from public.moderation_reports
 where target_type = 'message'::public.mod_target
   and content_snapshot is not null;
rollback;

-- R2 [READ-ONLY] AUTHORED, NOT RUN. Grants, settings and the constraint.
begin;
select
  not has_function_privilege('anon', 'public.msg_report_message(uuid,uuid,bigint,public.report_reason,text)', 'EXECUTE') as pass_anon_no_exec,
  has_function_privilege('authenticated', 'public.msg_report_message(uuid,uuid,bigint,public.report_reason,text)', 'EXECUTE') as pass_auth_exec,
  (select p.prosecdef and p.proconfig @> array['search_path=public, pg_temp']
     from pg_proc p where p.oid = 'public.msg_report_message(uuid,uuid,bigint,public.report_reason,text)'::regprocedure) as pass_definer_path,
  exists (select 1 from pg_constraint
           where conname = 'moderation_reports_message_no_snapshot_check'
             and conrelid = 'public.moderation_reports'::regclass) as pass_check_present;
rollback;

-- R3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Non-member denied, nothing written.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_c');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c512', :'game_id');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_c', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.msg_report_message('00000000-0000-4000-8000-00000000c512',
                                    '00000000-0000-4000-8000-0000000a0001', 1, 'spam', 'allowlist');
  raise exception 'R3 FAIL: non-member report was accepted';
exception when insufficient_privilege then
  raise notice 'R3 pass_non_member_denied';
end;
$$;
reset role;
select count(*) = 0 as pass_no_row_for_non_member
  from public.moderation_reports
 where target_type = 'message' and target_id = '00000000-0000-4000-8000-0000000a0001';
rollback;

-- R4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. Member allowed; NULL snapshot; repeat report no duplicate.
begin;
insert into public.msg_access_allowlist (user_id) values (:'user_a');
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000c512', :'game_id');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_a', 'role', 'authenticated')::text, true);
select r.created as pass_member_allowed
  from public.msg_report_message('00000000-0000-4000-8000-00000000c512',
                                 '00000000-0000-4000-8000-0000000a0002', 1, 'abuse', 'allowlist') r;
select (not r.created) as pass_repeat_not_created
  from public.msg_report_message('00000000-0000-4000-8000-00000000c512',
                                 '00000000-0000-4000-8000-0000000a0002', 1, 'abuse', 'allowlist') r;
reset role;
select count(*) = 1 as pass_repeat_no_duplicate,
       bool_and(content_snapshot is null and details is null) as pass_null_snapshot
  from public.moderation_reports
 where reporter_user_id = :'user_a'
   and target_type = 'message' and target_id = '00000000-0000-4000-8000-0000000a0002';
rollback;

-- R5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. The CHECK refuses a message report with a snapshot.
begin;
do $$
begin
  insert into public.moderation_reports (reporter_user_id, target_type, target_id, reason, content_snapshot)
  values ((select id from auth.users limit 1), 'message', '00000000-0000-4000-8000-0000000a0003', 'spam', '{"x":1}'::jsonb);
  raise exception 'R5 FAIL: snapshot on a message report was accepted';
exception when check_violation then
  raise notice 'R5 pass_check_refuses_snapshot';
end;
$$;
rollback;

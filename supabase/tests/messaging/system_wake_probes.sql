-- KAN-542 (Realtime R2) probe pack for the Realtime wake in public.msg_system_notify.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target: project wtncuzcskpigqpmnxwws, after 20261013160700_kan542_msg_system_wake.sql is applied
-- (after 20261013160600_kan541_msg_notify.sql), run as postgres. Every runnable block is READ-ONLY or
-- WRITE-IN-TRANSACTION-ROLLBACK, begins with BEGIN and ends with ROLLBACK. No block prints a payload,
-- a signature or a secret: the checks print booleans and counts only. The Vault secret msg_hmac_secret
-- must already exist (it is the CEO's; these probes never touch Vault).
--
-- Variables (supplied by the runner, no secrets): :game_id (future, not cancelled, no roster rows other
-- than :user_a), :user_a (active player on :game_id), :user_b and :user_c (test users with profiles
-- :profile_b and :profile_c, not on the roster). Conversation id 00000000-0000-4000-8000-00000000d542
-- is created in-block.
-- e.g. psql -v game_id=... -v user_a=... -v user_b=... -v profile_b=... -f system_wake_probes.sql
--
-- realtime.send stores each wake-up as a row in realtime.messages (topic, event, private, payload). The
-- platform adds an `id` key to the stored payload itself; the key checks below allow exactly that one
-- extra key. The system-line request is the net.http_request_queue row for the constant staging URL.

-- K1 [READ-ONLY] The function keeps its attributes and now contains the wake.
begin read only;
select
  (select prosecdef from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_definer,
  (select proconfig @> array['search_path=""'] from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_empty_search_path,
  (select prosrc ~ 'vault\.decrypted_secrets' and prosrc ~ 'msg_hmac_secret' and prosrc !~ 'app\.msg_' from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_reads_vault_by_name,
  (select prosrc ~ 'realtime\.send\(v_payload, ''msg'', ''user:'' \|\| v_to::text, true\)' from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_private_send,
  (select prosrc ~ '''type'', ''sync''' and prosrc !~ '''seq''' from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_seqless_sync_payload,
  not has_function_privilege('anon', 'public.msg_system_notify(text,uuid,uuid)', 'EXECUTE') as pass_anon_no_exec,
  not has_function_privilege('authenticated', 'public.msg_system_notify(text,uuid,uuid)', 'EXECUTE') as pass_auth_no_exec,
  (select count(*) = 0 from pg_proc p, aclexplode(p.proacl) a where p.oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure and a.grantee = 0) as pass_no_public_grant;
rollback;

-- K2 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A join queues the system-line request and one wake per
-- member of the roster after the change (the joiner included), each private with exactly the keys type and
-- conversation_id (plus the platform id).
begin;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d542', :'game_id');
select count(*) as queue_before from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line' \gset
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
select
  (select count(*) from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line') - :queue_before = 1 as pass_system_line_queued,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_a' and event = 'msg' and payload ->> 'type' = 'sync') = 1 as pass_member_a_woken_once,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b' and event = 'msg' and payload ->> 'type' = 'sync') = 1 as pass_joiner_b_woken_once,
  (select bool_and(private) from realtime.messages where payload ->> 'type' = 'sync' and topic in ('user:' || :'user_a', 'user:' || :'user_b')) as pass_all_private,
  (select bool_and(array(select k from jsonb_object_keys(payload) k where k <> 'id' order by k) = array['conversation_id','type'])
     from realtime.messages where payload ->> 'type' = 'sync' and topic in ('user:' || :'user_a', 'user:' || :'user_b')) as pass_exactly_type_and_conversation_id,
  (select bool_and(payload ->> 'conversation_id' = '00000000-0000-4000-8000-00000000d542')
     from realtime.messages where payload ->> 'type' = 'sync' and topic in ('user:' || :'user_a', 'user:' || :'user_b')) as pass_conversation_id_value;
rollback;

-- K3 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A removal and a leave do NOT wake the leaver (b is
-- removed first, then c leaves: b gets no wake at all, c gets only the one for b's removal, a gets both).
begin;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d542', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values
  (:'game_id', :'profile_b', :'user_b', 'player', 'active'),
  (:'game_id', :'profile_c', :'user_c', 'player', 'active');
select
  count(*) filter (where topic = 'user:' || :'user_a') as a_before,
  count(*) filter (where topic = 'user:' || :'user_b') as b_before,
  count(*) filter (where topic = 'user:' || :'user_c') as c_before
  from realtime.messages where payload ->> 'type' = 'sync' \gset
update public.game_roster set status = 'kicked' where game_id = :'game_id' and user_id = :'user_b';
update public.game_roster set status = 'left' where game_id = :'game_id' and user_id = :'user_c';
select
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b' and payload ->> 'type' = 'sync') = :b_before as pass_removed_not_woken,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_c' and payload ->> 'type' = 'sync') - :c_before = 1 as pass_leaver_woken_only_by_the_removal_of_b_not_by_own_leave,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_a' and payload ->> 'type' = 'sync') - :a_before = 2 as pass_remaining_member_woken_for_each;
rollback;

-- K4 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A cancellation queues one request and wakes every active member.
begin;
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d542', :'game_id');
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
select
  count(*) filter (where topic = 'user:' || :'user_a') as a_before,
  count(*) filter (where topic = 'user:' || :'user_b') as b_before
  from realtime.messages where payload ->> 'type' = 'sync' \gset
select count(*) as queue_before from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line' \gset
update public.games set is_cancelled = true where id = :'game_id';
select
  (select count(*) from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line') - :queue_before = 1 as pass_cancel_request_queued,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_a' and payload ->> 'type' = 'sync') - :a_before = 1 as pass_a_woken,
  (select count(*) from realtime.messages where topic = 'user:' || :'user_b' and payload ->> 'type' = 'sync') - :b_before = 1 as pass_b_woken;
rollback;

-- K5 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A game with no chat queues no request and sends no wake.
begin;
select count(*) as before_count from realtime.messages \gset
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
select (select count(*) from realtime.messages) - :before_count = 0 as pass_no_conversation_no_wake;
rollback;

-- K6 [WRITE-IN-TRANSACTION-ROLLBACK] AUTHORED, NOT RUN. A failing wake never fails the roster change and never
-- undoes the queued system line. The failure is simulated in-block with a trigger on realtime.messages that
-- raises; if the migration role cannot create it, this block is NOT RUN and the reason is recorded by the runner.
begin;
create function public.kan542_probe_raise() returns trigger language plpgsql as $f$ begin raise exception 'probe'; end; $f$;
create trigger kan542_probe_raise before insert on realtime.messages for each row execute function public.kan542_probe_raise();
insert into public.msg_conversations (id, game_id) values ('00000000-0000-4000-8000-00000000d542', :'game_id');
select count(*) as queue_before from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line' \gset
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_b', :'user_b', 'player', 'active');
select
  exists (select 1 from public.game_roster where game_id = :'game_id' and user_id = :'user_b' and status = 'active') as pass_roster_change_succeeded,
  (select count(*) from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line') - :queue_before = 1 as pass_system_line_still_queued;
rollback;

-- K7 NOT RUN: with the Vault secret msg_hmac_secret MISSING the function returns before the enqueue and before
-- any wake, and the roster change still succeeds (expected: zero system-line requests, zero sync wakes, no failure).
-- This is NOT RUN in this repository on purpose and has no SQL here: it would have to rename or hide the Vault
-- row, and the SQL hook refuses Vault access for agents. The operations team may run the KAN-539 probe V5
-- (system_notify_vault_probes.sql), which covers the same early return, then K2 with the secret absent.

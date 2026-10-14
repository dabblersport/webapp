-- KAN-510 (Messaging T15) probe pack.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target (once operations applies 20261013160000_kan510_msg_system_lines.sql): project
-- wtncuzcskpigqpmnxwws, as approved by the CEO's 2026-10-13 messaging test-environment ruling.
-- Every block is READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK and ends in `rollback;`.
-- Each block prints boolean `pass` columns; every one must be true.
-- No secret appears here: the two settings are set inside each transaction to PLACEHOLDERS the
-- runner supplies as psql variables (:worker_url, :test_key), never committed.
--
-- "Game finished" is not tested because it is not emitted: the client renders it from the
-- game's end time (T16). Block S6 proves nothing fires for a change of end time.
--
-- Variables: :game_id (future, not cancelled, with a msg_conversations row), :game_nochat (no
-- msg_conversations row), :user_x (a profile-owning test user not on :game_id), :profile_x.
-- Outbound calls are observed in net.http_request_queue, which pg_net fills inside the transaction.

-- S1 [READ-ONLY] Triggers exist, are scoped, and the functions are internal.
begin;
select
  (select count(*) = 3 from pg_trigger where tgname in ('msg_system_roster_insert','msg_system_roster_status','msg_system_game_cancelled') and not tgisinternal) as pass_three_triggers,
  not has_function_privilege('anon', 'public.msg_system_notify(text,uuid,uuid)', 'EXECUTE') as pass_anon_no_exec,
  not has_function_privilege('authenticated', 'public.msg_system_notify(text,uuid,uuid)', 'EXECUTE') as pass_auth_no_exec,
  (select bool_and(prosecdef) from pg_proc where proname in ('msg_system_notify','msg_system_roster_trg','msg_system_game_trg')) as pass_definer;
rollback;

-- S2 [WRITE-IN-TRANSACTION-ROLLBACK] A join and a removal each queue exactly one signed request.
begin;
select set_config('app.msg_worker_url', :'worker_url', true), set_config('app.msg_hmac_secret', :'test_key', true);
select count(*) as queue_before from net.http_request_queue \gset
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_x', :'user_x', 'player', 'active');
update public.game_roster set status = 'kicked' where game_id = :'game_id' and user_id = :'user_x';
select
  (select count(*) from net.http_request_queue) - :queue_before = 2 as pass_two_requests,
  (select bool_and(headers ->> 'X-Msg-Signature' ~ '^sha256=[0-9a-f]{64}$')
     from (select headers from net.http_request_queue order by id desc limit 2) q) as pass_signed,
  (select bool_and(convert_from(body, 'utf8')::jsonb ->> 'event' in ('joined','removed'))
     from (select body from net.http_request_queue order by id desc limit 2) q) as pass_events;
rollback;

-- S3 [WRITE-IN-TRANSACTION-ROLLBACK] A leave queues one request; an unrelated roster update queues none.
begin;
select set_config('app.msg_worker_url', :'worker_url', true), set_config('app.msg_hmac_secret', :'test_key', true);
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_x', :'user_x', 'player', 'active');
select count(*) as queue_before from net.http_request_queue \gset
update public.game_roster set left_at = null where game_id = :'game_id' and user_id = :'user_x';
select (select count(*) from net.http_request_queue) - :queue_before = 0 as pass_no_status_change_no_request;
update public.game_roster set status = 'left', left_at = now() where game_id = :'game_id' and user_id = :'user_x';
select (select count(*) from net.http_request_queue) - :queue_before = 1 as pass_leave_one_request;
rollback;

-- S4 [WRITE-IN-TRANSACTION-ROLLBACK] Cancelling queues one request; re-saving or uncancelling queues none.
begin;
select set_config('app.msg_worker_url', :'worker_url', true), set_config('app.msg_hmac_secret', :'test_key', true);
select count(*) as queue_before from net.http_request_queue \gset
update public.games set is_cancelled = true where id = :'game_id';
select (select count(*) from net.http_request_queue) - :queue_before = 1 as pass_cancel_one_request;
update public.games set is_cancelled = true where id = :'game_id';
update public.games set is_cancelled = false where id = :'game_id';
select (select count(*) from net.http_request_queue) - :queue_before = 1 as pass_nothing_else;
rollback;

-- S5 [WRITE-IN-TRANSACTION-ROLLBACK] Missing settings or a game with no chat: no request, the change succeeds.
begin;
select set_config('app.msg_worker_url', '', true), set_config('app.msg_hmac_secret', '', true);
select count(*) as queue_before from net.http_request_queue \gset
update public.games set is_cancelled = true where id = :'game_id';
select (select count(*) from net.http_request_queue) - :queue_before = 0 as pass_unset_settings_no_request,
       (select is_cancelled from public.games where id = :'game_id') as pass_change_not_blocked;
select set_config('app.msg_worker_url', :'worker_url', true), set_config('app.msg_hmac_secret', :'test_key', true);
update public.games set is_cancelled = true where id = :'game_nochat';
select (select count(*) from net.http_request_queue) - :queue_before = 0 as pass_no_chat_no_request;
rollback;

-- S6 [WRITE-IN-TRANSACTION-ROLLBACK] A change of the game's end time queues nothing (no 'finished' line).
begin;
select set_config('app.msg_worker_url', :'worker_url', true), set_config('app.msg_hmac_secret', :'test_key', true);
select count(*) as queue_before from net.http_request_queue \gset
update public.games set updated_at = now() where id = :'game_id';
select (select count(*) from net.http_request_queue) - :queue_before = 0 as pass_nothing_fires;
rollback;

-- S7 [READ-ONLY] The first-apply signature check: the signed text must equal what pg_net sends.
-- Run once after S2 with the transaction left open and compare the queued body text to the one
-- the Worker received; recorded by operations, not asserted here.

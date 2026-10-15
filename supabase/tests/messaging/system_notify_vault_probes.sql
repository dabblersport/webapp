-- KAN-539 probe pack: msg_system_notify reads the signing secret from Vault.   AUTHORED, NOT RUN.
-- Nothing in this file has been executed against any database.
--
-- Target (once operations applies 20261013160500_kan539_msg_system_notify_vault.sql after
-- 20261013160000_kan510_msg_system_lines.sql): project wtncuzcskpigqpmnxwws, as approved by the
-- CEO's 2026-10-13 messaging test-environment ruling. Run as postgres.
-- Every block is READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK and ends in `rollback;`. Each block
-- prints boolean `pass` columns; every one must be true.
-- NO SECRET OR SIGNATURE VALUE IS EVER PRINTED: the blocks only test presence, shape (a regex on
-- the header) and counts. The Vault secret msg_hmac_secret is created by the CEO, never here.
--
-- Variables: :game_id (future, not cancelled, with a msg_conversations row), :user_x (a
-- profile-owning test user not on :game_id), :profile_x.

-- V1 [READ-ONLY] The function exists with the expected attributes and the grants are closed.
begin read only;
select
  (select prosecdef from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_definer,
  (select proconfig @> array['search_path=""'] from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_empty_search_path,
  (select pg_get_userbyid(proowner) = 'postgres' from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_owner_postgres,
  (select prosrc ~ 'vault\.decrypted_secrets' and prosrc ~ 'msg_hmac_secret' and prosrc !~ 'app\.msg_' from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_reads_vault_not_settings,
  (select prosrc ~ 'dabbler-messaging-staging\.dabbler-sport\.workers\.dev/internal/system-line' from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_constant_url,
  not has_function_privilege('anon', 'public.msg_system_notify(text,uuid,uuid)', 'EXECUTE') as pass_anon_no_exec,
  not has_function_privilege('authenticated', 'public.msg_system_notify(text,uuid,uuid)', 'EXECUTE') as pass_auth_no_exec,
  (select count(*) = 0 from pg_proc p, aclexplode(p.proacl) a where p.oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure and a.grantee = 0) as pass_no_public_grant;
rollback;

-- V2 [READ-ONLY] The Vault secret exists (presence only; the value is not selected).
begin read only;
select exists (select 1 from vault.decrypted_secrets where name = 'msg_hmac_secret' and decrypted_secret is not null and decrypted_secret <> '') as pass_secret_present;
rollback;

-- V3 [WRITE-IN-TRANSACTION-ROLLBACK] With the secret present (the queue is filtered by the system-line URL: the
-- roster change also queues an unrelated push-notification request from another trigger), a join and a removal each queue
-- exactly one signed request; the signature header has the expected shape (value not printed).
begin;
select count(*) as queue_before from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line' \gset
insert into public.game_roster (game_id, profile_id, user_id, role, status) values (:'game_id', :'profile_x', :'user_x', 'player', 'active');
update public.game_roster set status = 'kicked' where game_id = :'game_id' and user_id = :'user_x';
select
  (select count(*) from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line') - :queue_before = 2 as pass_two_requests,
  (select bool_and(headers ->> 'X-Msg-Signature' ~ '^sha256=[0-9a-f]{64}$')
     from (select headers from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line' order by id desc limit 2) q) as pass_signature_header_present_and_well_formed,
  (select bool_and(url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line')
     from (select url from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line' order by id desc limit 2) q) as pass_constant_url_used,
  (select bool_and(convert_from(body, 'utf8')::jsonb ->> 'event' in ('joined','removed'))
     from (select body from net.http_request_queue where url = 'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line' order by id desc limit 2) q) as pass_events;
rollback;

-- V4 [WRITE-IN-TRANSACTION-ROLLBACK] A cancellation queues one request; nothing else does.
begin;
select count(*) as queue_before from net.http_request_queue \gset
update public.games set is_cancelled = true where id = :'game_id';
select (select count(*) from net.http_request_queue) - :queue_before = 1 as pass_cancel_one_request;
rollback;

-- V5 [WRITE-IN-TRANSACTION-ROLLBACK] With the secret missing the function does nothing and the
-- change still succeeds. The Vault row is hidden for this transaction only by renaming it, then
-- the transaction is rolled back (the rename never persists). Run only when V2 is true.
begin;
update vault.secrets set name = 'msg_hmac_secret_hidden_by_probe' where name = 'msg_hmac_secret';
select count(*) as queue_before from net.http_request_queue \gset
update public.games set is_cancelled = true where id = :'game_id';
select (select count(*) from net.http_request_queue) - :queue_before = 0 as pass_missing_secret_no_request,
       (select is_cancelled from public.games where id = :'game_id') as pass_change_not_blocked;
rollback;

-- V6 [READ-ONLY] No notice can carry a secret or a signature: the only RAISE in the function is the
-- payload-free WARNING (sqlstate only), and neither v_secret nor v_sig appears in any RAISE.
begin read only;
select
  (select (length(prosrc) - length(replace(prosrc, 'RAISE', ''))) / 5 = 1 from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_one_raise_only,
  (select prosrc ~ 'RAISE WARNING ''msg_system_notify failed \(sqlstate %\)'', SQLSTATE;' from pg_proc where oid = 'public.msg_system_notify(text,uuid,uuid)'::regprocedure) as pass_warning_has_sqlstate_only;
rollback;

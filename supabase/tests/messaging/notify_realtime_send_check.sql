-- KAN-541 (Realtime R1): READ-ONLY check of realtime.send for Memphis.   AUTHORED, NOT RUN.
-- Run BEFORE applying 20261013160600_kan541_msg_notify.sql, as the migration role (postgres),
-- on project wtncuzcskpigqpmnxwws. Every statement is a SELECT against the catalog; nothing is
-- written and no message is sent. Report the rows back.
--
-- What the repo establishes (and what it does not): the repo contains NO reference to realtime.send
-- or to the realtime.messages table other than the KAN-505 receive policy, so signature, owner and
-- privileges below are unconfirmed. Supabase documents realtime.send(payload jsonb, event text,
-- topic text, private boolean default true) as the database-side broadcast call; this check proves
-- it on this project.

BEGIN;

-- C1 signature, return type, owner, security mode, ACL.
select p.oid::regprocedure                       as signature,
       pg_get_function_result(p.oid)             as returns,
       pg_get_userbyid(p.proowner)               as owner,
       p.prosecdef                               as security_definer,
       p.proconfig                               as function_settings,
       p.proacl                                  as acl
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'realtime' and p.proname = 'send';

-- C2 the migration role may execute it; so may no anonymous role (informational).
select has_function_privilege('postgres', 'realtime.send(jsonb,text,text,boolean)', 'EXECUTE') as postgres_can_execute,
       has_function_privilege('anon',     'realtime.send(jsonb,text,text,boolean)', 'EXECUTE') as anon_can_execute,
       has_function_privilege('authenticated', 'realtime.send(jsonb,text,text,boolean)', 'EXECUTE') as authenticated_can_execute;

-- C3 the table realtime.send writes to, and the migration role's rights on it.
select has_table_privilege('postgres', 'realtime.messages', 'INSERT') as postgres_can_insert,
       has_table_privilege('postgres', 'realtime.messages', 'SELECT') as postgres_can_select,
       (select relrowsecurity from pg_class where oid = 'realtime.messages'::regclass) as rls_on;

-- C4 policies on realtime.messages (expect the KAN-505 receive policy and NO insert policy).
select policyname, cmd, roles, qual
  from pg_policies
 where schemaname = 'realtime' and tablename = 'messages'
 order by policyname;

-- C5 does anything else already call realtime.send from a function (so the pattern is known to work)?
select n.nspname || '.' || p.proname as caller
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where p.prosrc ilike '%realtime.send%'
   and not (n.nspname = 'realtime' and p.proname = 'send')
 order by 1;

ROLLBACK;

-- Reading the answer:
--   C1 returns one row with 4 arguments (jsonb, text, text, boolean) and returns void  -> the call in
--      msg_notify matches.
--   C2 postgres_can_execute = true  -> a SECURITY DEFINER function owned by postgres can call it.
--   C3 postgres_can_insert = true   -> the broadcast row can be written from that function.
--   C4 shows no INSERT policy       -> as designed (clients only receive).
-- If C1 returns no row, or postgres cannot execute it, STOP: msg_notify would only ever warn.

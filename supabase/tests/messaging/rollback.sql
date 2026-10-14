-- KAN-505 (Messaging T8) rollback.   AUTHORED, NOT RUN.
-- Running this is an APPLY against a live database and needs the CEO's explicit approval,
-- on a non-production branch of project wtncuzcskpigqpmnxwws first.
--
-- It removes nothing. It disables: every grant on the new functions and tables is revoked,
-- and the Realtime policy is altered to deny everyone. The objects and their rows stay in
-- place, so the change is reversible by re-running the original grants.

begin;

-- Realtime policy (4/4): deny all receives on 'user:' topics through this policy.
do $$
begin
  if exists (select 1 from pg_policies
              where schemaname = 'realtime' and tablename = 'messages'
                and policyname = 'msg_user_topic_receive') then
    alter policy msg_user_topic_receive on realtime.messages using (false);
  end if;
end;
$$;

-- Functions (3/4): nobody may execute them.
revoke all on function public.msg_authorize(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.msg_can_send(uuid, uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.msg_can_read(uuid, uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.msg_evaluate(uuid, uuid, text) from public, anon, authenticated, service_role;

-- Allowlist (2/4) and registry (1/4): no API role may read or write them. RLS stays on.
revoke all on table public.msg_access_allowlist from public, anon, authenticated, service_role;
revoke all on table public.msg_conversation_members from public, anon, authenticated, service_role;
revoke all on table public.msg_conversations from public, anon, authenticated, service_role;

commit;

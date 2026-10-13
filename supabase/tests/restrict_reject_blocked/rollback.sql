-- KAN-522 rollback. AUTHORED, NOT RUN.
--
-- THIS FILE IS ITSELF AN APPLY, done only by Memphis with the CEO approval of
-- 2026-10-13 (execute_sql, never apply_migration, project
-- wtncuzcskpigqpmnxwws, test data only). It REOPENS the second block store:
-- rpc_restrict_set / rpc_restrict_clear accept 'blocked' again and write rows
-- no guard reads. Last resort only. No DROP.
--
-- Restores the exact baseline bodies (supabase/migrations/
-- 20260829080500_baseline_schema.sql lines 15008-15047) and the prior ACL.
-- Prior ACL = PUBLIC plus explicit anon, authenticated, service_role (baseline
-- GRANT ALL lines 36677-36685). Confirm against probe A2's saved output first;
-- if the live ACL differed, STOP and ask.

BEGIN;

CREATE OR REPLACE FUNCTION "public"."rpc_restrict_clear"("p_target" "uuid", "p_type" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if p_type not in ('hidden','blocked') then raise exception using errcode='P0001', message='invalid_type'; end if;
  delete from public.restrictions
  where user_id = me and target_user_id = p_target and type = p_type;
end; $$;

CREATE OR REPLACE FUNCTION "public"."rpc_restrict_set"("p_target" "uuid", "p_type" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if p_target is null or p_target = me then raise exception using errcode='P0001', message='invalid_target'; end if;
  if p_type not in ('hidden','blocked') then raise exception using errcode='P0001', message='invalid_type'; end if;

  insert into public.restrictions(user_id, target_user_id, type)
  values (me, p_target, p_type)
  on conflict (user_id, target_user_id, type) do nothing;

  -- Optional: auto-downgrade friendship to removed if blocking
  if p_type = 'blocked' then
    update public.friendships
    set status='removed', updated_at=now()
    where (user_id, peer_user_id) in ( (least(me,p_target), greatest(me,p_target)) );
  end if;
end; $$;

GRANT EXECUTE ON FUNCTION public.rpc_restrict_set(uuid, text)   TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_restrict_clear(uuid, text) TO PUBLIC, anon, authenticated, service_role;

COMMIT;

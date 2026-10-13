-- KAN-522: rpc_restrict_set / rpc_restrict_clear stop writing 'blocked' rows
-- that nothing enforces.   AUTHORED, NOT APPLIED. Team Deir el-Bahari.
--
-- Problem: public.restrictions rows of type 'blocked' are read by no guard (the
-- block guards read public.user_blocks, written by rpc_block_user(uuid)). These
-- two SECURITY DEFINER functions still accept p_type = 'blocked', so a block
-- made through them looks blocked and is enforced nowhere. The app calls
-- neither function (supabase/tests/restrict_reject_blocked/CALLERS.md).
--
-- Change (smallest safe): CREATE OR REPLACE of the two bodies. Signatures,
-- owner, SECURITY DEFINER and search_path stay; nothing is renamed, so no
-- *_legacy_v1 and no DROP.
--   * p_type = 'blocked' raises errcode P0001: 'use_rpc_block_user' from
--     rpc_restrict_set, 'use_rpc_unblock_user' from rpc_restrict_clear.
--   * any other p_type than 'hidden' still raises 'invalid_type'.
--   * 'hidden', the not_authenticated and invalid_target guards are verbatim.
--   * the friendship auto-downgrade only ran for 'blocked'; that branch is now
--     unreachable and is removed.
-- is_hidden reads 'hidden' rows and is not touched.
--
-- ACL: REVOKE EXECUTE FROM PUBLIC and anon, keep authenticated and
-- service_role. The baseline granted anon explicitly (and PUBLIC by default); a
-- 'hidden' preference needs a signed-in user.
--
-- Not done here: existing 'blocked' rows are left alone (KAN-499 carries them
-- to user_blocks). After this migration rpc_restrict_clear can no longer clear
-- one; see the README.

CREATE OR REPLACE FUNCTION public.rpc_restrict_set(p_target uuid, p_type text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid();
begin
  if me is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if p_target is null or p_target = me then raise exception using errcode='P0001', message='invalid_target'; end if;
  if p_type = 'blocked' then raise exception using errcode='P0001', message='use_rpc_block_user'; end if;
  if p_type not in ('hidden') then raise exception using errcode='P0001', message='invalid_type'; end if;

  insert into public.restrictions(user_id, target_user_id, type)
  values (me, p_target, p_type)
  on conflict (user_id, target_user_id, type) do nothing;
end; $function$;

CREATE OR REPLACE FUNCTION public.rpc_restrict_clear(p_target uuid, p_type text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid();
begin
  if me is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if p_type = 'blocked' then raise exception using errcode='P0001', message='use_rpc_unblock_user'; end if;
  if p_type not in ('hidden') then raise exception using errcode='P0001', message='invalid_type'; end if;
  delete from public.restrictions
  where user_id = me and target_user_id = p_target and type = p_type;
end; $function$;

REVOKE EXECUTE ON FUNCTION public.rpc_restrict_set(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.rpc_restrict_set(uuid, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.rpc_restrict_clear(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.rpc_restrict_clear(uuid, text) TO authenticated, service_role;

-- Post-condition (read-only): shape and ACL.
DO $$
DECLARE
  sig text; d boolean; cfg text[]; src text;
BEGIN
  FOREACH sig IN ARRAY ARRAY['public.rpc_restrict_set(uuid,text)', 'public.rpc_restrict_clear(uuid,text)'] LOOP
    SELECT prosecdef, proconfig, prosrc INTO d, cfg, src FROM pg_proc WHERE oid = sig::regprocedure;
    IF NOT d THEN RAISE EXCEPTION 'POST-CONDITION FAILED: % lost SECURITY DEFINER', sig; END IF;
    IF cfg IS NULL OR NOT (cfg @> ARRAY['search_path=public']) THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: % search_path is %', sig, cfg; END IF;
    IF src !~ 'use_rpc_(un)?block_user' THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: % does not reject blocked', sig; END IF;
    IF has_function_privilege('anon', sig::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: anon can still execute %', sig; END IF;
    IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = sig::regprocedure AND a.grantee = 0) THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: PUBLIC can still execute %', sig; END IF;
    IF NOT has_function_privilege('authenticated', sig::regprocedure, 'EXECUTE')
       OR NOT has_function_privilege('service_role', sig::regprocedure, 'EXECUTE') THEN
      RAISE EXCEPTION 'POST-CONDITION FAILED: authenticated/service_role lost EXECUTE on %', sig; END IF;
  END LOOP;
END
$$;

-- KAN-942: the messaging access mode is server-controlled. A caller-supplied p_access_mode may NARROW access
-- (the Worker's off/allowlist kill switch keeps working) but can never WIDEN it past the server setting.
-- Every authenticated-callable msg_* RPC that takes p_access_mode funnels it into msg_evaluate, so the rule lives there once.
-- Applied live 2026-11-14 (recorded version 20261113231340). msg_evaluate md5(prosrc) d961daa7656c347a44674ed5c2a54922
-- -> 465aae783e87fa72b1beb54edad9de5e. The function is rewritten from pg_get_functiondef on the live catalogue (T-058).

CREATE TABLE IF NOT EXISTS public.msg_access_config (
  id         boolean PRIMARY KEY DEFAULT true CHECK (id),
  mode       text NOT NULL CHECK (mode IN ('off', 'allowlist', 'all')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.msg_access_config IS
  'KAN-942: one row. Server-side messaging access mode (off|allowlist|all). Changed only by postgres/service_role. msg_evaluate uses the more restrictive of this and the caller argument; a missing row means off.';
ALTER TABLE public.msg_access_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.msg_access_config FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON public.msg_access_config TO service_role;
-- Seeded to the live Worker value (MESSAGING_ACCESS_MODE = "all", wrangler.toml / CEO 2026-10-22): no behaviour change.
INSERT INTO public.msg_access_config (id, mode) VALUES (true, 'all') ON CONFLICT (id) DO NOTHING;

DO $mig$
DECLARE
  v_oid oid := 'public.msg_evaluate(uuid,uuid,text)'::regprocedure;
  v_def text;
  v_new text;
BEGIN
  IF md5((SELECT prosrc FROM pg_proc WHERE oid = v_oid)) <> 'd961daa7656c347a44674ed5c2a54922' THEN
    RAISE EXCEPTION 'KAN-942: msg_evaluate pre-image md5 mismatch; re-author from the live catalogue';
  END IF;
  v_def := pg_get_functiondef(v_oid);

  v_new := replace(v_def,
$o$  v_m_status  text;
BEGIN
  IF p_user_id IS NULL THEN$o$,
$n$  v_m_status  text;
  v_srv_mode  text;
BEGIN
  IF p_user_id IS NULL THEN$n$);

  v_new := replace(v_new,
$o$  IF p_access_mode IS NULL OR p_access_mode NOT IN ('allowlist', 'all') THEN$o$,
$n$  -- KAN-942: the server setting caps the mode. A missing row fails closed (off). The caller argument may only narrow.
  SELECT c.mode INTO v_srv_mode FROM public.msg_access_config c WHERE c.id;
  v_srv_mode := COALESCE(v_srv_mode, 'off');

  IF p_access_mode IS NULL OR p_access_mode NOT IN ('allowlist', 'all')
     OR v_srv_mode NOT IN ('allowlist', 'all') THEN$n$);

  v_new := replace(v_new,
$o$  IF p_access_mode = 'allowlist'
     AND NOT EXISTS$o$,
$n$  IF (p_access_mode = 'allowlist' OR v_srv_mode = 'allowlist')
     AND NOT EXISTS$n$);

  IF v_new = v_def
     OR position('v_srv_mode  text;' IN v_new) = 0
     OR position('OR v_srv_mode NOT IN' IN v_new) = 0
     OR position('OR v_srv_mode = ''allowlist'')' IN v_new) = 0 THEN
    RAISE EXCEPTION 'KAN-942: msg_evaluate rewrite did not apply all three edits';
  END IF;
  EXECUTE v_new;
END
$mig$;

-- CREATE OR REPLACE keeps owner and ACL; re-assert the expected posture anyway.
REVOKE ALL ON FUNCTION public.msg_evaluate(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.msg_evaluate(uuid, uuid, text) TO service_role;

DO $post$
DECLARE r record;
BEGIN
  SELECT p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl INTO r
    FROM pg_proc p WHERE p.oid = 'public.msg_evaluate(uuid,uuid,text)'::regprocedure;
  IF NOT r.prosecdef OR r.proconfig <> ARRAY['search_path=public, pg_temp'] OR r.owner <> 'postgres'
     OR r.acl <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-942 post-assert failed: % % % %', r.prosecdef, r.proconfig, r.owner, r.acl;
  END IF;
  IF has_table_privilege('authenticated', 'public.msg_access_config', 'SELECT,UPDATE,INSERT,DELETE')
     OR has_table_privilege('anon', 'public.msg_access_config', 'SELECT,UPDATE,INSERT,DELETE') THEN
    RAISE EXCEPTION 'KAN-942 post-assert failed: msg_access_config reachable by anon/authenticated';
  END IF;
END
$post$;

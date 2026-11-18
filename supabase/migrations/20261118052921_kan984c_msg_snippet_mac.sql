-- KAN-984c: the message snippet is accepted only with a MAC from the messaging Worker (option A, KAN-984 comment
-- 16473, approved by the CEO 2026-11-17).
--
-- The Worker sends, with the USER's token (identity stays auth.uid(), KAN-543 holds: no elevated key in the Worker),
--   header  x-msg-snippet-mac: lowercase hex HMAC-SHA256(key, '<conversation uuid>:<seq>:<snippet>')
-- where key = Worker secret MSG_SNIPPET_HMAC_KEY = Vault secret 'msg_snippet_hmac_key' (same value; set outside
-- this repository, never printed). PostgREST puts the request headers in current_setting('request.headers').
--
-- msg_snippet_verified() recomputes the MAC with pgcrypto. Missing header, malformed MAC, no Vault key, or a MAC for
-- another conversation, seq or text => the snippet is dropped and the push is sender-only. It never raises: a failure
-- in the check falls back to sender-only and the notification is still sent. The comparison is on digests of both
-- MACs, so timing does not reveal a matching prefix. A MAC is bound to one conversation, one seq and one exact text, and
-- notify_v2 dedupes per seq, so a replayed MAC reproduces only the same notice.
--
-- With the check in place, msg_notify(uuid,bigint,text,text) is granted back to authenticated (R4 of comment 16469
-- stays closed: without the key no caller can produce a valid MAC). Until the Vault key exists, every snippet is
-- dropped, so applying this before the key is set changes nothing for users.
--
-- No DROP, no DELETE, no UPDATE. msg_notify_core, the 3-argument msg_notify and notification_push_dispatch untouched.

-- 1. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.msg_notify(uuid,bigint,text,text)'::regprocedure)) <> '50fcf78e9ccbf4b0b579bec86d1bf92d' THEN
    RAISE EXCEPTION 'kan984c pre-image: msg_notify(uuid,bigint,text,text) changed since 20261117170659';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.msg_notify(uuid,bigint,text,text)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan984c pre-image: msg_notify(uuid,bigint,text,text) grants changed since 20261117170659';
  END IF;
  IF md5(pg_get_functiondef('public.msg_notify_core(uuid,uuid,bigint,text,text)'::regprocedure)) <> 'aa455c18648ada5c8025817fcedf7b36' THEN
    RAISE EXCEPTION 'kan984c pre-image: msg_notify_core changed';
  END IF;
  IF to_regprocedure('public.msg_snippet_verified(uuid,bigint,text)') IS NOT NULL THEN
    RAISE EXCEPTION 'kan984c pre-image: msg_snippet_verified already exists';
  END IF;
END
$guard$;

-- 2. The check -------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.msg_snippet_verified(p_conversation_id uuid, p_seq bigint, p_snippet text)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_hdr      text;
  v_mac      text;
  v_key      text;
  v_expected text;
BEGIN
  IF p_snippet IS NULL OR p_snippet = '' OR p_conversation_id IS NULL OR p_seq IS NULL THEN
    RETURN NULL;
  END IF;
  v_hdr := NULLIF(current_setting('request.headers', true), '');
  IF v_hdr IS NULL THEN
    RETURN NULL;
  END IF;
  v_mac := lower(btrim(v_hdr::json ->> 'x-msg-snippet-mac'));
  IF v_mac IS NULL OR v_mac !~ '^[0-9a-f]{64}$' THEN
    RETURN NULL;
  END IF;
  SELECT s.decrypted_secret INTO v_key FROM vault.decrypted_secrets s WHERE s.name = 'msg_snippet_hmac_key';
  IF v_key IS NULL OR v_key = '' THEN
    RETURN NULL;
  END IF;
  v_expected := encode(extensions.hmac(
                  convert_to(p_conversation_id::text || ':' || p_seq::text || ':' || p_snippet, 'UTF8'),
                  convert_to(v_key, 'UTF8'), 'sha256'), 'hex');
  IF extensions.digest(v_mac, 'sha256') = extensions.digest(v_expected, 'sha256') THEN
    RETURN p_snippet;
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;  -- never raise: a failed check is a sender-only push
END;
$function$;

COMMENT ON FUNCTION public.msg_snippet_verified(uuid, bigint, text) IS
  'KAN-984c: returns p_snippet only when request header x-msg-snippet-mac = HMAC-SHA256(Vault msg_snippet_hmac_key, '
  '"<conversation>:<seq>:<snippet>"); otherwise NULL. Never raises. Internal: no client grant.';

REVOKE ALL ON FUNCTION public.msg_snippet_verified(uuid, bigint, text) FROM PUBLIC, anon, authenticated, service_role;

-- 3. The snippet overload uses the check (replaced from the live definition) -----------------------------------------
CREATE OR REPLACE FUNCTION public.msg_notify(p_conversation_id uuid, p_seq bigint, p_access_mode text, p_snippet text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_snip text;
BEGIN
  -- KAN-984c: the snippet is kept only with a valid MAC from the messaging Worker; otherwise the push is sender-only.
  v_snip := public.msg_snippet_verified(p_conversation_id, p_seq, p_snippet);
  PERFORM public.msg_notify_core(auth.uid(), p_conversation_id, p_seq, p_access_mode, v_snip);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text, text) TO authenticated;

-- 4. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.msg_snippet_verified(uuid,bigint,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.msg_snippet_verified(uuid,bigint,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.msg_snippet_verified(uuid,bigint,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.msg_notify_core(uuid,uuid,bigint,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan984c post-image: grants not as intended';
  END IF;
END
$post$;

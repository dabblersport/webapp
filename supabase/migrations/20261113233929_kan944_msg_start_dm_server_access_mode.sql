-- KAN-944 item 2: msg_start_dm respects the server messaging access mode (KAN-942 msg_access_config), the same way
-- msg_evaluate does: a missing row or 'off' refuses with messaging_off; 'allowlist' admits only a caller on
-- msg_access_allowlist (not_in_pilot otherwise); 'all' is unchanged. Checked before any lookup, so an existing DM
-- is not returned either while messaging is closed.
-- Re-authored from pg_get_functiondef on the live catalogue (T-058). CREATE OR REPLACE keeps proacl, SECURITY DEFINER
-- and search_path. Pre-image: md5(prosrc) 983620413c9cb7136033e44060865ff3
-- (md5(pg_get_functiondef) 0b7c4b4d66b1e75587b1900343cd4c83).
-- Applied live 2026-11-14 (recorded version 20261113233929). Post-image md5(prosrc) 474f0221ea7f7f21633e1e1088bf4c67.

DO $pre$
BEGIN
  IF md5((SELECT prosrc FROM pg_proc WHERE oid = 'public.msg_start_dm(uuid)'::regprocedure))
     <> '983620413c9cb7136033e44060865ff3' THEN
    RAISE EXCEPTION 'KAN-944: msg_start_dm pre-image md5 mismatch; re-author from the live catalogue';
  END IF;
END $pre$;

CREATE OR REPLACE FUNCTION public.msg_start_dm(p_other_user uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  msg_dm_daily_cap CONSTANT int := 20;
  v_uid  uuid := auth.uid();
  v_low  uuid;
  v_high uuid;
  v_conv uuid;
  v_srv_mode text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  -- KAN-944: the server access mode (KAN-942) gates DM creation exactly as msg_evaluate gates read/send.
  -- A missing row fails closed (off).
  SELECT c.mode INTO v_srv_mode FROM public.msg_access_config c WHERE c.id;
  v_srv_mode := COALESCE(v_srv_mode, 'off');
  IF v_srv_mode NOT IN ('allowlist', 'all') THEN
    RAISE EXCEPTION 'messaging_off' USING ERRCODE = '42501';
  END IF;
  IF v_srv_mode = 'allowlist'
     AND NOT EXISTS (SELECT 1 FROM public.msg_access_allowlist a WHERE a.user_id = v_uid) THEN
    RAISE EXCEPTION 'not_in_pilot' USING ERRCODE = '42501';
  END IF;

  IF p_other_user IS NULL OR p_other_user = v_uid THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;

  IF NOT public.msg_user_age_ok(v_uid) OR NOT public.msg_user_age_ok(p_other_user) THEN
    RAISE EXCEPTION 'age_restricted' USING ERRCODE = '42501';
  END IF;

  IF public.msg_user_unavailable(p_other_user) THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (SELECT 1 FROM public.user_blocks b
              WHERE (b.blocker_user_id = v_uid AND b.blocked_user_id = p_other_user)
                 OR (b.blocker_user_id = p_other_user AND b.blocked_user_id = v_uid)) THEN
    RAISE EXCEPTION 'blocked' USING ERRCODE = '42501';
  END IF;

  v_low := least(v_uid, p_other_user);
  v_high := greatest(v_uid, p_other_user);

  PERFORM pg_advisory_xact_lock(hashtextextended('msg_dm_cap:' || v_uid::text, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('msg_dm_pair:' || v_low::text || ':' || v_high::text, 0));

  SELECT d.conversation_id INTO v_conv
    FROM public.msg_dm_pairs d
   WHERE d.user_low = v_low AND d.user_high = v_high;
  IF v_conv IS NOT NULL THEN
    RETURN v_conv;
  END IF;

  IF (SELECT count(*) FROM public.msg_dm_pairs d
       WHERE d.started_by = v_uid
         AND d.created_at > now() - interval '24 hours') >= msg_dm_daily_cap THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '54000';
  END IF;

  INSERT INTO public.msg_conversations (kind) VALUES ('dm') RETURNING id INTO v_conv;
  INSERT INTO public.msg_dm_pairs (conversation_id, user_low, user_high, started_by)
  VALUES (v_conv, v_low, v_high, v_uid);
  INSERT INTO public.msg_conversation_members (conversation_id, user_id) VALUES (v_conv, v_low), (v_conv, v_high);

  RETURN v_conv;
END;
$function$;

DO $post$
DECLARE p pg_proc;
BEGIN
  SELECT * INTO p FROM pg_proc WHERE oid = 'public.msg_start_dm(uuid)'::regprocedure;
  IF NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR position('msg_access_config' IN p.prosrc) = 0
     OR p.proacl::text <> '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-944: msg_start_dm post-assert failed (secdef %, config %, acl %)', p.prosecdef, p.proconfig, p.proacl;
  END IF;
END $post$;

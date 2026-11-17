-- KAN-985b: PEER review fixes (KAN-985 comment 16434, backend-6).
--
-- Blocking 1 "Not me" on the caller's own installation: when the target row is on the installation of the caller's
--   current session (ledger row of auth.jwt()->>'session_id'), revoke only that one old session; keep the push token
--   and the known-installation entry. Same for an unbound row whose user-agent family is the caller's own: the agent
--   family stays known.
-- Blocking 2 rollout gap:
--   (a) security_on_session_created: an account created before KAN-985 shipped (2026-11-17 10:07:46 UTC) has history,
--       so only a real sign-up is a silent baseline.
--   (b) rpc_security_register_sign_in: the first-installation baseline only from a pre-ship (seeded) session row or a
--       brand-new account. Existing logged-in users bind silently; a fresh sign-in after ship sends one notice.
-- Non-blocking: security.new_signin capped at 3 per user per rolling hour (the ledger row is still written, state
--   'new', notification_id NULL); every non-browser, non-app user agent is one family, other:client.
--
-- Every function is replaced from its live definition (pg_get_functiondef, guarded by md5 below). CREATE OR REPLACE
-- keeps the ACLs. No DROP, no DELETE, no UPDATE: the only data change is an additive INSERT of other:client into
-- security_known_devices for users who already had an other:* family (old other:* rows stay, unused).

-- 1. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.security_device_from_agent(text)'::regprocedure)) <> '8f7fccd3abe711e988477ac2068ffdb9'
  OR md5(pg_get_functiondef('public.security_send_sign_in_notice(uuid)'::regprocedure)) <> 'ecf02a8c64e3101882d28608c2c789df'
  OR md5(pg_get_functiondef('public.security_on_session_created()'::regprocedure)) <> '43450b3492f2e89e75d5a0b49ab193d7'
  OR md5(pg_get_functiondef('public.rpc_security_register_sign_in(text,text,text)'::regprocedure)) <> '3042f89ca72fd4b8acfc45b058ad725e'
  OR md5(pg_get_functiondef('public.rpc_security_not_me(uuid)'::regprocedure)) <> 'f51e3ea63e7e8a2dccffb11424cb029a' THEN
    RAISE EXCEPTION 'kan985b pre-image: a KAN-985 function changed since 20261117100746';
  END IF;
END
$guard$;

-- 2. One family for every non-browser, non-app client ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.security_device_from_agent(p_user_agent text, OUT device_key text, OUT device_label text)
 RETURNS record
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE
  v_ua  text := COALESCE(p_user_agent, '');
  v_os  text;
  v_br  text;
BEGIN
  IF v_ua ~ '^Dart/' THEN
    device_key := 'app:dabbler';
    device_label := 'Dabbler app';
    RETURN;
  END IF;
  IF v_ua ~* '^Mozilla/' THEN
    v_os := CASE
      WHEN v_ua ~ 'iPhone'    THEN 'iPhone'
      WHEN v_ua ~ 'iPad'      THEN 'iPad'
      WHEN v_ua ~ 'Android'   THEN 'Android'
      WHEN v_ua ~ 'CrOS'      THEN 'ChromeOS'
      WHEN v_ua ~ 'Macintosh' THEN 'macOS'
      WHEN v_ua ~ 'Windows'   THEN 'Windows'
      WHEN v_ua ~ 'Linux'     THEN 'Linux'
      ELSE 'unknown OS' END;
    v_br := CASE
      WHEN v_ua ~ 'Edg(e|A|iOS)?/'                          THEN 'Edge'
      WHEN v_ua ~ '(OPR|Opera)/'                            THEN 'Opera'
      WHEN v_ua ~ 'SamsungBrowser/'                         THEN 'Samsung Internet'
      WHEN v_ua ~ '(Firefox|FxiOS)/'                        THEN 'Firefox'
      WHEN v_ua ~ '(CriOS|HeadlessChrome|Chromium|Chrome)/' THEN 'Chrome'
      WHEN v_ua ~ 'Safari/'                                 THEN 'Safari'
      ELSE 'Browser' END;
    device_key := 'web:' || lower(replace(v_br, ' ', '_')) || ':' || lower(replace(v_os, ' ', '_'));
    device_label := v_br || ' on ' || v_os;
    RETURN;
  END IF;
  -- curl, node, python, scripts: one family, so rotating the user agent cannot multiply notices
  device_key := 'other:client';
  device_label := 'Unknown device';
END;
$function$;

-- 3. Cap: at most 3 new-sign-in notices per user per rolling hour ----------------------------------------------------
CREATE OR REPLACE FUNCTION public.security_send_sign_in_notice(p_sign_in_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  r     public.security_sign_ins%ROWTYPE;
  v_nid uuid;
BEGIN
  SELECT * INTO r FROM public.security_sign_ins WHERE id = p_sign_in_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  IF r.notification_id IS NOT NULL THEN
    RETURN r.notification_id;
  END IF;
  -- the ledger row stays 'new' (visible in the sign-in list); only the notice is skipped
  IF (SELECT count(*) FROM public.security_sign_ins l
       WHERE l.user_id = r.user_id AND l.id <> r.id AND l.notification_id IS NOT NULL
         AND l.signed_in_at > now() - interval '1 hour') >= 3 THEN
    RETURN NULL;
  END IF;
  v_nid := public.notify_v2(
    r.user_id,
    'security.new_signin',
    jsonb_build_object(
      'sign_in_id',   r.id,
      'device',       r.device_label,
      'platform',     r.platform,
      'city',         r.place_city,
      'country',      r.place_country,
      'signed_in_at', r.signed_in_at,
      'state',        'new'),
    'security_sign_in', r.id, NULL,
    'auth.session:' || r.session_id::text,
    'security.new_signin:' || r.session_id::text,
    NULL, NULL);
  IF v_nid IS NOT NULL THEN
    UPDATE public.security_sign_ins SET notification_id = v_nid WHERE id = r.id AND notification_id IS NULL;
  END IF;
  RETURN v_nid;
END;
$function$;

-- 4. (a) pre-ship accounts have history ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.security_on_session_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_dev     record;
  v_history boolean;
  v_known   boolean;
  v_new     boolean;
  v_id      uuid;
BEGIN
  BEGIN
    SELECT * INTO v_dev FROM public.security_device_from_agent(NEW.user_agent);

    v_history := EXISTS (SELECT 1 FROM public.security_sign_ins WHERE user_id = NEW.user_id)
              OR EXISTS (SELECT 1 FROM public.security_known_devices WHERE user_id = NEW.user_id)
              -- KAN-985b: an account that existed before KAN-985 shipped is never a silent baseline
              OR EXISTS (SELECT 1 FROM auth.users u
                          WHERE u.id = NEW.user_id AND u.created_at < timestamptz '2026-11-17 10:07:46+00');
    v_known   := EXISTS (SELECT 1 FROM public.security_known_devices
                          WHERE user_id = NEW.user_id AND kind = 'agent' AND device_key = v_dev.device_key);
    v_new     := v_history AND NOT v_known;

    INSERT INTO public.security_sign_ins
           (user_id, session_id, device_label, device_key, signed_in_at, is_new_device, state)
    VALUES (NEW.user_id, NEW.id, v_dev.device_label, v_dev.device_key, COALESCE(NEW.created_at, now()),
            v_new, CASE WHEN v_new THEN 'new' ELSE 'known' END)
    ON CONFLICT (session_id) DO NOTHING
    RETURNING id INTO v_id;

    INSERT INTO public.security_known_devices (user_id, kind, device_key, source)
    VALUES (NEW.user_id, 'agent', v_dev.device_key, 'sign_in')
    ON CONFLICT (user_id, kind, device_key) DO UPDATE SET last_seen_at = now();

    IF v_id IS NOT NULL AND v_new THEN
      PERFORM public.security_send_sign_in_notice(v_id);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'kan985 security_on_session_created: % (%)', SQLERRM, SQLSTATE;
  END;
  RETURN NULL;
END;
$function$;

-- 5. (b) first-installation baseline only from a pre-ship session row or a brand-new account --------------------------
CREATE OR REPLACE FUNCTION public.rpc_security_register_sign_in(p_installation_id text, p_platform text DEFAULT NULL::text, p_device_label text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid       uuid := auth.uid();
  v_sid       uuid;
  v_label     text;
  r           public.security_sign_ins%ROWTYPE;
  v_ua        text;
  v_dev       record;
  v_has_inst  boolean;
  v_inst_kn   boolean;
  v_baseline  boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'rpc_security_register_sign_in: not authenticated' USING ERRCODE = '42501';
  END IF;
  BEGIN
    v_sid := NULLIF(auth.jwt() ->> 'session_id', '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    v_sid := NULL;
  END;
  IF v_sid IS NULL THEN
    RAISE EXCEPTION 'rpc_security_register_sign_in: no session in the token' USING ERRCODE = '42501';
  END IF;
  IF p_installation_id IS NULL OR btrim(p_installation_id) = '' OR p_installation_id LIKE 'legacy:%'
     OR char_length(p_installation_id) > 200 THEN
    RAISE EXCEPTION 'rpc_security_register_sign_in: invalid installation id' USING ERRCODE = '22023';
  END IF;
  IF p_platform IS NOT NULL
     AND p_platform NOT IN ('android', 'iOS', 'macOS', 'web', 'linux', 'windows', 'fuchsia') THEN
    RAISE EXCEPTION 'rpc_security_register_sign_in: invalid platform %', p_platform USING ERRCODE = '22023';
  END IF;
  v_label := NULLIF(left(btrim(regexp_replace(COALESCE(p_device_label, ''), '[[:cntrl:]]', '', 'g')), 80), '');

  SELECT * INTO r FROM public.security_sign_ins WHERE session_id = v_sid FOR UPDATE;

  IF NOT FOUND THEN
    SELECT s.user_agent INTO v_ua FROM auth.sessions s WHERE s.id = v_sid AND s.user_id = v_uid;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'rpc_security_register_sign_in: session is not active' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_dev FROM public.security_device_from_agent(v_ua);
    INSERT INTO public.security_sign_ins
           (user_id, session_id, installation_id, platform, device_label, device_key, signed_in_at, state)
    VALUES (v_uid, v_sid, p_installation_id, p_platform, COALESCE(v_label, v_dev.device_label), v_dev.device_key,
            COALESCE((SELECT s.created_at FROM auth.sessions s WHERE s.id = v_sid), now()), 'known')
    ON CONFLICT (session_id) DO NOTHING;
    INSERT INTO public.security_known_devices (user_id, kind, device_key, source)
    VALUES (v_uid, 'installation', p_installation_id, 'sign_in')
    ON CONFLICT (user_id, kind, device_key) DO UPDATE SET last_seen_at = now();
    SELECT * INTO r FROM public.security_sign_ins WHERE session_id = v_sid;
    RETURN jsonb_build_object('sign_in_id', r.id, 'state', r.state, 'is_new_device', r.is_new_device);
  END IF;

  IF r.user_id <> v_uid THEN
    RAISE EXCEPTION 'rpc_security_register_sign_in: session does not belong to the caller' USING ERRCODE = '42501';
  END IF;

  IF r.installation_id IS NULL THEN
    v_has_inst := EXISTS (SELECT 1 FROM public.security_known_devices
                           WHERE user_id = v_uid AND kind = 'installation');
    v_inst_kn  := EXISTS (SELECT 1 FROM public.security_known_devices
                           WHERE user_id = v_uid AND kind = 'installation' AND device_key = p_installation_id);
    -- KAN-985b: a first installation is a silent baseline only for a session that predates KAN-985 (seeded row)
    -- or for an account created after it shipped
    v_baseline := r.signed_in_at < timestamptz '2026-11-17 10:07:46+00'
               OR EXISTS (SELECT 1 FROM auth.users u
                           WHERE u.id = v_uid AND u.created_at >= timestamptz '2026-11-17 10:07:46+00');

    UPDATE public.security_sign_ins
       SET installation_id = p_installation_id,
           platform        = COALESCE(p_platform, platform),
           device_label    = COALESCE(v_label, device_label)
     WHERE id = r.id;

    IF r.state = 'known' AND NOT v_inst_kn AND (v_has_inst OR NOT v_baseline) THEN
      UPDATE public.security_sign_ins SET is_new_device = true, state = 'new' WHERE id = r.id;
      PERFORM public.security_send_sign_in_notice(r.id);
    ELSIF r.notification_id IS NOT NULL AND v_label IS NOT NULL THEN
      UPDATE public.notifications
         SET args = COALESCE(args, '{}'::jsonb) || jsonb_build_object('device', v_label, 'platform', p_platform)
       WHERE id = r.notification_id;
    END IF;

    INSERT INTO public.security_known_devices (user_id, kind, device_key, source)
    VALUES (v_uid, 'installation', p_installation_id, 'sign_in')
    ON CONFLICT (user_id, kind, device_key) DO UPDATE SET last_seen_at = now();
  END IF;

  SELECT * INTO r FROM public.security_sign_ins WHERE id = r.id;
  RETURN jsonb_build_object('sign_in_id', r.id, 'state', r.state, 'is_new_device', r.is_new_device);
END;
$function$;

-- 6. "Not me" never signs the caller's own device out of push --------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_security_not_me(p_sign_in_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid      uuid := auth.uid();
  v_sid      text := auth.jwt() ->> 'session_id';
  r          public.security_sign_ins%ROWTYPE;
  v_my_inst  text;
  v_my_key   text;
  v_same     boolean;
  v_targets  uuid[];
  v_revoked  integer;
  v_nids     uuid[];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'rpc_security_not_me: not authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO r FROM public.security_sign_ins WHERE id = p_sign_in_id AND user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'rpc_security_not_me: sign-in not found' USING ERRCODE = 'P0002';
  END IF;
  IF r.session_id::text = v_sid THEN
    RAISE EXCEPTION 'rpc_security_not_me: this is the current device; sign out instead' USING ERRCODE = '22023';
  END IF;

  -- the caller's own device, from the ledger row of the current session
  SELECT l.installation_id, l.device_key INTO v_my_inst, v_my_key
    FROM public.security_sign_ins l
   WHERE l.user_id = v_uid AND l.session_id::text = v_sid;
  v_same := r.installation_id IS NOT NULL AND r.installation_id = v_my_inst;

  -- another installation: every session it holds; the caller's own installation: only that one old session
  IF r.installation_id IS NOT NULL AND NOT v_same THEN
    SELECT array_agg(l.session_id) INTO v_targets
      FROM public.security_sign_ins l
     WHERE l.user_id = v_uid AND l.installation_id = r.installation_id
       AND l.session_id::text IS DISTINCT FROM v_sid;
  END IF;
  v_targets := array_append(COALESCE(v_targets, '{}'::uuid[]), r.session_id);

  DELETE FROM auth.sessions s WHERE s.user_id = v_uid AND s.id = ANY (v_targets)
     AND s.id::text IS DISTINCT FROM v_sid;
  GET DIAGNOSTICS v_revoked = ROW_COUNT;

  IF r.installation_id IS NOT NULL AND NOT v_same THEN
    DELETE FROM public.fcm_tokens WHERE user_id = v_uid AND installation_id = r.installation_id;
    DELETE FROM public.security_known_devices
     WHERE user_id = v_uid AND kind = 'installation' AND device_key = r.installation_id;
  ELSIF r.installation_id IS NULL AND r.device_key IS DISTINCT FROM v_my_key THEN
    DELETE FROM public.security_known_devices
     WHERE user_id = v_uid AND kind = 'agent' AND device_key = r.device_key;
  END IF;

  WITH upd AS (
    UPDATE public.security_sign_ins l
       SET state = 'secured', secured_at = now()
     WHERE l.user_id = v_uid AND l.session_id = ANY (v_targets) AND l.state <> 'secured'
    RETURNING l.notification_id)
  SELECT array_agg(notification_id) FILTER (WHERE notification_id IS NOT NULL) INTO v_nids FROM upd;

  IF v_nids IS NOT NULL THEN
    PERFORM public.security_resolve_notice(n, 'secured') FROM unnest(v_nids) AS n;
  END IF;

  RETURN jsonb_build_object(
    'sign_in_id',               r.id,
    'state',                    'secured',
    'revoked_sessions',         v_revoked,
    'signed_out_installation',  CASE WHEN v_same THEN NULL ELSE r.installation_id END,
    'kept_current_device',      v_same,
    'route_to_password_change', true);
END;
$function$;

-- 7. Known families follow the collapse: anyone who had an other:* family knows other:client ------------------------
INSERT INTO public.security_known_devices (user_id, kind, device_key, source, first_seen_at, last_seen_at)
SELECT k.user_id, 'agent', 'other:client', 'seed', min(k.first_seen_at), max(k.last_seen_at)
  FROM public.security_known_devices k
 WHERE k.kind = 'agent' AND k.device_key LIKE 'other:%' AND k.device_key <> 'other:client'
 GROUP BY k.user_id
ON CONFLICT (user_id, kind, device_key) DO NOTHING;

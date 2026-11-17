-- KAN-985 [W1-B7] Security notices (Epic KAN-973).
--
-- New sign-in, password change and email change notices from real auth data (F-16), with "This was me" / "Not me".
--
-- Objects (all new, owned by KAN-985):
--   * public.security_sign_ins        sign-in ledger; owner-readable (RLS), written only by the functions below
--   * public.security_known_devices   known installations / user-agent families per user; no client access (T-020)
--   * public.security_device_from_agent(text)          user_agent -> (device_key, device_label); internal
--   * public.security_send_sign_in_notice(uuid)        internal sender (notify_v2, stable dedupe key)
--   * public.security_resolve_notice(uuid, text)       internal: marks the inbox row resolved
--   * public.security_on_session_created()  + trigger security_on_session_created   AFTER INSERT ON auth.sessions
--   * public.security_on_auth_user_updated() + trigger security_on_auth_user_updated AFTER UPDATE ON auth.users
--   * public.rpc_security_register_sign_in(text, text, text)   app binds its installation to the current session
--   * public.rpc_security_sign_ins(integer)                    read RPC (own rows)
--   * public.rpc_security_confirm_sign_in(uuid)                "This was me"
--   * public.rpc_security_not_me(uuid)                         "Not me": sign out that installation / session only
--   * activates security.new_signin, security.password_changed, security.email_changed (can_mute false,
--     breaks_quiet true, set by KAN-974 and asserted here)
--
-- Detection, why a trigger on auth.sessions: a session row is inserted once per sign-in (password, OTP, OAuth) and
-- never on a token refresh, so "refresh on a known device does not notify" holds by construction. Hosted Supabase has
-- no after-sign-in auth hook; the custom-access-token hook fires on every refresh. auth.users already carries two
-- triggers on this project, so triggers on the auth schema are a working pattern here.
--
-- "New device": a new installation for that user (W0-4), or, for a client that never binds an installation (curl,
-- a script, another browser), a user-agent family (browser + OS, version-free) the user has never used.
-- Baselines: a user with no history (first sign-in, sign-up) is never notified; the first installation a user ever
-- binds is a baseline too, so the first sign-in after this ships does not flood existing users.
--
-- Privacy: no IP is copied anywhere. auth.sessions keeps its own ip (Supabase-managed). There is no IP-to-place
-- source on this project (no table, no extension), so place_city / place_country stay NULL.
-- No sequences: every key is a uuid.
--
-- Not touched: notify_v2, notify_v2_render, process_notification_event, emit_event, trg_push_on_notification_insert
-- (KAN-979), notification_aggregation_rules (KAN-980), membership objects (KAN-982), fcm_tokens structure and its
-- RPCs (KAN-977). rpc_security_not_me deletes the fcm_tokens row of the signed-out installation (data, not structure)
-- so that device stops receiving pushes.

-- 1. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure))
       <> '5310b3d74bb3e1c1c6b9277c6804e184' THEN
    RAISE EXCEPTION 'kan985 pre-image: notify_v2 changed since the claim';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('security.new_signin','security.password_changed','security.email_changed')
         AND is_active = false AND can_mute = false AND breaks_quiet = true
         AND default_priority::text = 'high' AND 'push' = ANY (default_channels)) <> 3 THEN
    RAISE EXCEPTION 'kan985 pre-image: the three security kinds are not in the expected inactive state';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notifications WHERE kind_key LIKE 'security.%') THEN
    RAISE EXCEPTION 'kan985 pre-image: security notifications already exist (another sender?)';
  END IF;
  IF to_regclass('public.security_sign_ins') IS NOT NULL OR to_regclass('public.security_known_devices') IS NOT NULL THEN
    RAISE EXCEPTION 'kan985 pre-image: a security ledger table already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND (p.proname LIKE 'security\_%' OR p.proname LIKE 'rpc\_security\_%')) THEN
    RAISE EXCEPTION 'kan985 pre-image: a security_* function already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal
               AND tgrelid IN ('auth.sessions'::regclass, 'auth.users'::regclass)
               AND tgname LIKE 'security\_%') THEN
    RAISE EXCEPTION 'kan985 pre-image: a security_* trigger already exists on auth';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'fcm_tokens' AND column_name = 'installation_id') THEN
    RAISE EXCEPTION 'kan985 pre-image: fcm_tokens.installation_id (KAN-977) is missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'auth' AND table_name = 'sessions' AND column_name = 'user_agent') THEN
    RAISE EXCEPTION 'kan985 pre-image: auth.sessions.user_agent is missing';
  END IF;
END
$guard$;

-- 2. Tables ----------------------------------------------------------------------------------------------------------
CREATE TABLE public.security_sign_ins (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  session_id       uuid        NOT NULL UNIQUE,   -- auth.sessions.id; no FK, the row outlives a revoked session
  installation_id  text,                          -- set by rpc_security_register_sign_in; NULL for unbound clients
  platform         text,                          -- android | iOS | macOS | web | linux | windows | fuchsia
  device_label     text        NOT NULL,          -- "Chrome on macOS", "Dabbler app", or the app's own label
  device_key       text        NOT NULL,          -- version-free user-agent family, e.g. web:chrome:macos
  place_city       text,                          -- always NULL: no IP-to-place source exists on this project
  place_country    text,                          -- always NULL, same reason
  signed_in_at     timestamptz NOT NULL,
  is_new_device    boolean     NOT NULL DEFAULT false,
  state            text        NOT NULL DEFAULT 'known',
  notification_id  uuid        REFERENCES public.notifications (id) ON DELETE SET NULL,
  confirmed_at     timestamptz,
  secured_at       timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT security_sign_ins_state_chk CHECK (state IN ('known', 'new', 'confirmed', 'secured')),
  CONSTRAINT security_sign_ins_platform_chk CHECK (platform IS NULL OR platform IN
    ('android', 'iOS', 'macOS', 'web', 'linux', 'windows', 'fuchsia')),
  CONSTRAINT security_sign_ins_label_len_chk CHECK (char_length(device_label) BETWEEN 1 AND 80)
);
COMMENT ON TABLE public.security_sign_ins IS
  'KAN-985 sign-in ledger: one row per auth session. state: known (no notice), new (notice sent), confirmed '
  '("This was me"), secured ("Not me"). No IP stored; place_* NULL (no lookup source). Owner-readable only.';

CREATE INDEX security_sign_ins_user_time_idx ON public.security_sign_ins (user_id, signed_in_at DESC);
CREATE INDEX security_sign_ins_user_installation_idx ON public.security_sign_ins (user_id, installation_id)
  WHERE installation_id IS NOT NULL;
CREATE INDEX security_sign_ins_notification_idx ON public.security_sign_ins (notification_id)
  WHERE notification_id IS NOT NULL;

CREATE TABLE public.security_known_devices (
  user_id        uuid        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  kind           text        NOT NULL,
  device_key     text        NOT NULL,
  source         text        NOT NULL DEFAULT 'sign_in',
  first_seen_at  timestamptz NOT NULL DEFAULT now(),
  last_seen_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, kind, device_key),
  CONSTRAINT security_known_devices_kind_chk CHECK (kind IN ('installation', 'agent')),
  CONSTRAINT security_known_devices_source_chk CHECK (source IN ('seed', 'sign_in'))
);
COMMENT ON TABLE public.security_known_devices IS
  'KAN-985 control data: installations and user-agent families each user has signed in from. '
  'No client access (T-020): the person it constrains cannot read or change it.';

ALTER TABLE public.security_sign_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_known_devices ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.security_sign_ins FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.security_known_devices FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.security_sign_ins TO authenticated;
GRANT ALL ON public.security_sign_ins TO service_role;
GRANT ALL ON public.security_known_devices TO service_role;

CREATE POLICY security_sign_ins_select_own ON public.security_sign_ins
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));
-- security_known_devices: RLS on, no policy, no grant to anon/authenticated.

-- 3. Device parsing --------------------------------------------------------------------------------------------------
CREATE FUNCTION public.security_device_from_agent(p_user_agent text, OUT device_key text, OUT device_label text)
  LANGUAGE plpgsql IMMUTABLE
  SET search_path TO ''
AS $function$
DECLARE
  v_ua  text := COALESCE(p_user_agent, '');
  v_os  text;
  v_br  text;
  v_tok text;
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
  v_tok := lower(substring(v_ua FROM '^([A-Za-z0-9._-]{1,40})'));
  device_key := 'other:' || COALESCE(NULLIF(v_tok, ''), 'unknown');
  device_label := 'Unknown device';
END;
$function$;

-- 4. Internal helpers ------------------------------------------------------------------------------------------------
-- Sends (or re-finds) the one new-sign-in notice of a ledger row. Dedupe key: security.new_signin:<session_id>.
CREATE FUNCTION public.security_send_sign_in_notice(p_sign_in_id uuid)
  RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER
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

-- Marks the inbox row of a ledger row resolved: args.state follows the ledger, the row is read.
CREATE FUNCTION public.security_resolve_notice(p_notification_id uuid, p_state text)
  RETURNS void
  LANGUAGE sql SECURITY DEFINER
  SET search_path TO ''
AS $function$
  UPDATE public.notifications
     SET args    = COALESCE(args, '{}'::jsonb) || jsonb_build_object('state', p_state, 'resolved_at', now()),
         is_read = true,
         read_at = COALESCE(read_at, now())
   WHERE id = p_notification_id;
$function$;

-- 5. Sign-in detection: AFTER INSERT ON auth.sessions ---------------------------------------------------------------
CREATE FUNCTION public.security_on_session_created()
  RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_dev     record;
  v_history boolean;
  v_known   boolean;
  v_new     boolean;
  v_id      uuid;
BEGIN
  -- A failure here must never block a sign-in.
  BEGIN
    SELECT * INTO v_dev FROM public.security_device_from_agent(NEW.user_agent);

    v_history := EXISTS (SELECT 1 FROM public.security_sign_ins WHERE user_id = NEW.user_id)
              OR EXISTS (SELECT 1 FROM public.security_known_devices WHERE user_id = NEW.user_id);
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

CREATE TRIGGER security_on_session_created
  AFTER INSERT ON auth.sessions
  FOR EACH ROW EXECUTE FUNCTION public.security_on_session_created();

-- 6. Password and email change: AFTER UPDATE ON auth.users ---------------------------------------------------------
-- Password: any change of encrypted_password to a non-empty value, except the first password of an account created
-- in the last 24 hours (accounts are passwordless at creation: strip_signup_password).
-- Email: a confirmed change of auth.users.email (GoTrue only writes email once the change is confirmed; a pending
-- change sits in email_change and does not notify).
-- Dedupe key: one notice per kind per user per transaction.
CREATE FUNCTION public.security_on_auth_user_updated()
  RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO ''
AS $function$
BEGIN
  BEGIN
    IF NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password
       AND COALESCE(NEW.encrypted_password, '') <> ''
       AND NOT (COALESCE(OLD.encrypted_password, '') = '' AND NEW.created_at > now() - interval '24 hours') THEN
      PERFORM public.notify_v2(
        NEW.id, 'security.password_changed',
        jsonb_build_object('changed_at', now()),
        'account', NEW.id, NULL,
        'auth.users:password:' || txid_current()::text,
        'security.password_changed:' || NEW.id::text || ':' || txid_current()::text,
        NULL, NULL);
    END IF;

    IF NEW.email IS DISTINCT FROM OLD.email AND OLD.email IS NOT NULL AND NEW.email IS NOT NULL THEN
      PERFORM public.notify_v2(
        NEW.id, 'security.email_changed',
        jsonb_build_object('changed_at', now()),
        'account', NEW.id, NULL,
        'auth.users:email:' || txid_current()::text,
        'security.email_changed:' || NEW.id::text || ':' || txid_current()::text,
        NULL, NULL);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'kan985 security_on_auth_user_updated: % (%)', SQLERRM, SQLSTATE;
  END;
  RETURN NULL;
END;
$function$;

CREATE TRIGGER security_on_auth_user_updated
  AFTER UPDATE OF encrypted_password, email ON auth.users
  FOR EACH ROW
  WHEN (OLD.encrypted_password IS DISTINCT FROM NEW.encrypted_password OR OLD.email IS DISTINCT FROM NEW.email)
  EXECUTE FUNCTION public.security_on_auth_user_updated();

-- 7. Client RPCs -----------------------------------------------------------------------------------------------------
-- The app calls this after every sign-in and on start (idempotent). It binds the installation to the current
-- session (auth.jwt() ->> 'session_id'); a first-seen installation of a user who already has one notifies.
CREATE FUNCTION public.rpc_security_register_sign_in(
    p_installation_id text,
    p_platform        text DEFAULT NULL,
    p_device_label    text DEFAULT NULL)
  RETURNS jsonb
  LANGUAGE plpgsql SECURITY DEFINER
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
    -- A session that predates KAN-985: record it as known, never notify.
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

    UPDATE public.security_sign_ins
       SET installation_id = p_installation_id,
           platform        = COALESCE(p_platform, platform),
           device_label    = COALESCE(v_label, device_label)
     WHERE id = r.id;

    IF r.state = 'known' AND v_has_inst AND NOT v_inst_kn THEN
      UPDATE public.security_sign_ins SET is_new_device = true, state = 'new' WHERE id = r.id;
      PERFORM public.security_send_sign_in_notice(r.id);
    ELSIF r.notification_id IS NOT NULL AND v_label IS NOT NULL THEN
      -- notice already sent from the user-agent path: give the inbox row the app's device label
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

-- Read RPC: the caller's own sign-ins, newest first. is_current = this session; is_active = session still exists.
CREATE FUNCTION public.rpc_security_sign_ins(p_limit integer DEFAULT 50)
  RETURNS TABLE (
    id uuid, session_id uuid, installation_id text, platform text, device_label text,
    place_city text, place_country text, signed_in_at timestamptz, is_new_device boolean, state text,
    notification_id uuid, confirmed_at timestamptz, secured_at timestamptz, is_current boolean, is_active boolean)
  LANGUAGE plpgsql STABLE SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_sid text := auth.jwt() ->> 'session_id';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'rpc_security_sign_ins: not authenticated' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT l.id, l.session_id, l.installation_id, l.platform, l.device_label,
           l.place_city, l.place_country, l.signed_in_at, l.is_new_device, l.state,
           l.notification_id, l.confirmed_at, l.secured_at,
           (l.session_id::text = v_sid),
           EXISTS (SELECT 1 FROM auth.sessions s WHERE s.id = l.session_id)
      FROM public.security_sign_ins l
     WHERE l.user_id = v_uid
     ORDER BY l.signed_in_at DESC
     LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
END;
$function$;

-- "This was me". Refused from the session the row describes: a confirmation has to come from another device,
-- otherwise whoever signed in could silence the notice (report section 3: tie it to a real check).
CREATE FUNCTION public.rpc_security_confirm_sign_in(p_sign_in_id uuid)
  RETURNS jsonb
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_sid text := auth.jwt() ->> 'session_id';
  r     public.security_sign_ins%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'rpc_security_confirm_sign_in: not authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO r FROM public.security_sign_ins WHERE id = p_sign_in_id AND user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'rpc_security_confirm_sign_in: sign-in not found' USING ERRCODE = 'P0002';
  END IF;
  IF r.state = 'secured' THEN
    RAISE EXCEPTION 'rpc_security_confirm_sign_in: this sign-in was already signed out' USING ERRCODE = '22023';
  END IF;
  IF r.session_id::text = v_sid AND r.state <> 'confirmed' THEN
    RAISE EXCEPTION 'rpc_security_confirm_sign_in: confirm from another device' USING ERRCODE = '42501';
  END IF;
  IF r.state <> 'confirmed' THEN
    UPDATE public.security_sign_ins SET state = 'confirmed', confirmed_at = now() WHERE id = r.id;
    IF r.notification_id IS NOT NULL THEN
      PERFORM public.security_resolve_notice(r.notification_id, 'confirmed');
    END IF;
  END IF;
  RETURN jsonb_build_object('sign_in_id', r.id, 'state', 'confirmed');
END;
$function$;

-- "Not me": signs out that installation only (every session the ledger ties to it), or that one session for an
-- unbound client. Never the caller's own session, never another device. Returns route_to_password_change = true.
CREATE FUNCTION public.rpc_security_not_me(p_sign_in_id uuid)
  RETURNS jsonb
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_uid      uuid := auth.uid();
  v_sid      text := auth.jwt() ->> 'session_id';
  r          public.security_sign_ins%ROWTYPE;
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

  IF r.installation_id IS NOT NULL THEN
    SELECT array_agg(l.session_id) INTO v_targets
      FROM public.security_sign_ins l
     WHERE l.user_id = v_uid AND l.installation_id = r.installation_id
       AND l.session_id::text IS DISTINCT FROM v_sid;
  END IF;
  v_targets := array_append(COALESCE(v_targets, '{}'::uuid[]), r.session_id);

  DELETE FROM auth.sessions s WHERE s.user_id = v_uid AND s.id = ANY (v_targets)
     AND s.id::text IS DISTINCT FROM v_sid;
  GET DIAGNOSTICS v_revoked = ROW_COUNT;

  IF r.installation_id IS NOT NULL THEN
    DELETE FROM public.fcm_tokens WHERE user_id = v_uid AND installation_id = r.installation_id;
    DELETE FROM public.security_known_devices
     WHERE user_id = v_uid AND kind = 'installation' AND device_key = r.installation_id;
  ELSE
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
    'signed_out_installation',  r.installation_id,
    'route_to_password_change', true);
END;
$function$;

-- 8. Grants ----------------------------------------------------------------------------------------------------------
-- A CREATE in public picks up pg_default_acl grants to anon by name: revoke PUBLIC, anon and authenticated explicitly.
REVOKE ALL ON FUNCTION public.security_device_from_agent(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.security_send_sign_in_notice(uuid)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.security_resolve_notice(uuid, text)     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.security_on_session_created()           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.security_on_auth_user_updated()         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_security_register_sign_in(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_security_sign_ins(integer)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_security_confirm_sign_in(uuid)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_security_not_me(uuid)               FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_security_register_sign_in(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_security_sign_ins(integer)                  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_security_confirm_sign_in(uuid)              TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_security_not_me(uuid)                       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.security_device_from_agent(text)                TO service_role;

-- 9. Seed: existing sessions are known (no flood on the first sign-in after this ships) -----------------------------
INSERT INTO public.security_sign_ins (user_id, session_id, device_label, device_key, signed_in_at, state)
SELECT s.user_id, s.id, d.device_label, d.device_key, COALESCE(s.created_at, now()), 'known'
  FROM auth.sessions s
 CROSS JOIN LATERAL public.security_device_from_agent(s.user_agent) d
ON CONFLICT (session_id) DO NOTHING;

INSERT INTO public.security_known_devices (user_id, kind, device_key, source, first_seen_at, last_seen_at)
SELECT s.user_id, 'agent', d.device_key, 'seed', min(COALESCE(s.created_at, now())), max(COALESCE(s.created_at, now()))
  FROM auth.sessions s
 CROSS JOIN LATERAL public.security_device_from_agent(s.user_agent) d
 GROUP BY s.user_id, d.device_key
ON CONFLICT (user_id, kind, device_key) DO NOTHING;

-- Real installations already registered (KAN-977); legacy:* rows carry no installation and are skipped.
INSERT INTO public.security_known_devices (user_id, kind, device_key, source, first_seen_at, last_seen_at)
SELECT f.user_id, 'installation', f.installation_id, 'seed', min(f.created_at), max(f.last_seen_at)
  FROM public.fcm_tokens f
 WHERE f.installation_id NOT LIKE 'legacy:%'
 GROUP BY f.user_id, f.installation_id
ON CONFLICT (user_id, kind, device_key) DO NOTHING;

-- 10. Activate the three security kinds (flags asserted in the guard: can_mute false, breaks_quiet true, high) -----
UPDATE public.notification_kinds
   SET is_active = true
 WHERE key IN ('security.new_signin', 'security.password_changed', 'security.email_changed');

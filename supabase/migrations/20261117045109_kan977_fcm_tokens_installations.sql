-- KAN-977 [W0-4] Devices: fcm_tokens becomes one row per installation.
--
-- Before: unique (user_id, platform), so a second device on the same platform replaced the first.
-- After:  unique (user_id, installation_id). One user can have any number of devices.
--
-- Backward compatibility (old builds still run
--   from('fcm_tokens').upsert({user_id, token, platform, updated_at}, onConflict: 'user_id,platform')):
--   PostgREST turns that into INSERT ... ON CONFLICT (user_id, platform). Postgres resolves the conflict target
--   at plan time and needs a NON-partial unique index on exactly (user_id, platform). A partial index fails with
--   42P10 (checked live 2026-11-17). So unique_user_platform stays, and it becomes the legacy-slot arbiter:
--     * legacy rows (written by old builds, plus every row that existed before this migration):
--         platform = the OS, installation_id = 'legacy:' || platform. One per (user, platform), same as before.
--     * installation rows (written by rpc_register_push_token):
--         platform IS NULL, installation_id = the client's id. Unique (user_id, platform) ignores NULLs, so
--         any number of these can exist per user and platform.
--   device_platform is the real OS on every row and is the column to read from now on. platform is the
--   legacy slot only.
--
-- No duplicate sends: token is globally unique. Any write that carries a token held by another row
-- (another user after an account switch, or this device's old legacy row after an app upgrade) deletes that
-- other row first. The delete runs in a SECURITY DEFINER trigger, so it covers the RPC and the old-build upsert.

-- 0. Pre-image guard: refuse to run against anything but the shape read live on 2026-11-17 --------------------------
DO $guard$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'fcm_tokens' AND column_name = 'installation_id') THEN
    RAISE EXCEPTION 'KAN-977 guard: fcm_tokens.installation_id already exists';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.fcm_tokens'::regclass AND conname = 'unique_user_platform') THEN
    RAISE EXCEPTION 'KAN-977 guard: unique_user_platform missing';
  END IF;
  IF (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'fcm_tokens') <> 4 THEN
    RAISE EXCEPTION 'KAN-977 guard: expected 4 policies on fcm_tokens';
  END IF;
  IF EXISTS (SELECT token FROM public.fcm_tokens GROUP BY token HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'KAN-977 guard: duplicate tokens present, unique(token) would fail';
  END IF;
END
$guard$;

-- 1. New columns -----------------------------------------------------------------------------------------------------
ALTER TABLE public.fcm_tokens
  ADD COLUMN installation_id text,
  ADD COLUMN device_platform text,
  ADD COLUMN app_version     text,
  ADD COLUMN locale          text,
  ADD COLUMN os_permission   text,
  ADD COLUMN last_seen_at    timestamptz NOT NULL DEFAULT now();

-- 2. Backfill: every existing row is a legacy row. Keep updated_at as it was.
ALTER TABLE public.fcm_tokens DISABLE TRIGGER update_fcm_tokens_timestamp;
UPDATE public.fcm_tokens
   SET installation_id = 'legacy:' || platform,
       device_platform = platform,
       last_seen_at    = updated_at;
ALTER TABLE public.fcm_tokens ENABLE TRIGGER update_fcm_tokens_timestamp;

-- 3. Constraints -----------------------------------------------------------------------------------------------------
ALTER TABLE public.fcm_tokens
  ALTER COLUMN installation_id SET NOT NULL,
  ALTER COLUMN device_platform SET NOT NULL,
  ALTER COLUMN platform DROP NOT NULL,
  ADD CONSTRAINT fcm_tokens_device_platform_check CHECK (device_platform = ANY (ARRAY[
        'android'::text, 'iOS'::text, 'macOS'::text, 'web'::text, 'linux'::text, 'windows'::text, 'fuchsia'::text])),
  ADD CONSTRAINT fcm_tokens_installation_id_check CHECK (char_length(installation_id) BETWEEN 1 AND 128),
  ADD CONSTRAINT fcm_tokens_token_check           CHECK (char_length(token) BETWEEN 1 AND 4096),
  ADD CONSTRAINT fcm_tokens_os_permission_check   CHECK (os_permission IS NULL
                                                         OR os_permission IN ('granted', 'denied', 'provisional')),
  ADD CONSTRAINT fcm_tokens_app_version_check     CHECK (app_version IS NULL OR char_length(app_version) <= 64),
  ADD CONSTRAINT fcm_tokens_locale_check          CHECK (locale IS NULL OR char_length(locale) <= 35),
  -- platform is set exactly on legacy rows, and a legacy row's ids follow from it.
  ADD CONSTRAINT fcm_tokens_legacy_slot_check     CHECK (
        (platform IS NULL AND installation_id NOT LIKE 'legacy:%')
     OR (platform IS NOT NULL AND installation_id = 'legacy:' || platform AND device_platform = platform));

CREATE UNIQUE INDEX fcm_tokens_user_installation_key ON public.fcm_tokens (user_id, installation_id);
ALTER TABLE public.fcm_tokens
  ADD CONSTRAINT fcm_tokens_user_installation_key UNIQUE USING INDEX fcm_tokens_user_installation_key;

CREATE UNIQUE INDEX fcm_tokens_token_key ON public.fcm_tokens (token);
ALTER TABLE public.fcm_tokens ADD CONSTRAINT fcm_tokens_token_key UNIQUE USING INDEX fcm_tokens_token_key;
DROP INDEX public.idx_fcm_tokens_token;   -- superseded by fcm_tokens_token_key

COMMENT ON CONSTRAINT unique_user_platform ON public.fcm_tokens IS
  'KAN-977: legacy-slot arbiter for old builds that upsert with onConflict user_id,platform. Only legacy rows '
  'have platform set; installation rows have platform NULL, so this no longer limits devices per platform.';
COMMENT ON COLUMN public.fcm_tokens.platform IS
  'KAN-977: legacy slot only. Set on rows written by old builds (installation_id = legacy:<platform>), NULL on '
  'installation rows. Read device_platform for the OS.';
COMMENT ON COLUMN public.fcm_tokens.installation_id IS
  'KAN-977: client-generated id, stable per app installation. legacy:<platform> marks a row from an old build.';
COMMENT ON COLUMN public.fcm_tokens.device_platform IS 'KAN-977: the OS of this installation, on every row.';
COMMENT ON COLUMN public.fcm_tokens.os_permission IS
  'KAN-977: OS notification permission, granted | denied | provisional, or NULL if not yet asked or unknown.';
COMMENT ON COLUMN public.fcm_tokens.last_seen_at IS 'KAN-977: last register, refresh or legacy upsert.';

-- 4. Normalising trigger: keeps the legacy slot consistent and keeps each token on one row ----------------------
CREATE FUNCTION public.fcm_tokens_normalize()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.platform IS NOT NULL THEN
    -- Legacy write: an old build upserting on (user_id, platform), or an update to a legacy row.
    NEW.installation_id := 'legacy:' || NEW.platform;
    NEW.device_platform := NEW.platform;
  ELSIF NEW.installation_id IS NULL OR NEW.installation_id LIKE 'legacy:%' THEN
    RAISE EXCEPTION 'fcm_tokens: a row without platform needs a non-legacy installation_id'
      USING ERRCODE = '23514';
  END IF;

  NEW.last_seen_at := now();

  -- A token belongs to one installation of one user. Remove any other holder: another user's row after an
  -- account switch on a shared device, or this device's legacy row after it upgrades to a new build.
  DELETE FROM public.fcm_tokens f
   WHERE f.token = NEW.token
     AND (f.user_id, f.installation_id) IS DISTINCT FROM (NEW.user_id, NEW.installation_id);

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fcm_tokens_normalize() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER fcm_tokens_normalize
  BEFORE INSERT OR UPDATE ON public.fcm_tokens
  FOR EACH ROW EXECUTE FUNCTION public.fcm_tokens_normalize();

-- 5. RPCs ------------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.rpc_register_push_token(
  p_installation_id text,
  p_token           text,
  p_platform        text,
  p_app_version     text DEFAULT NULL,
  p_locale          text DEFAULT NULL,
  p_os_permission   text DEFAULT NULL)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_id  uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'rpc_register_push_token: not authenticated' USING ERRCODE = '42501';
  END IF;
  IF p_installation_id IS NULL OR btrim(p_installation_id) = '' OR p_installation_id LIKE 'legacy:%' THEN
    RAISE EXCEPTION 'rpc_register_push_token: invalid installation id' USING ERRCODE = '22023';
  END IF;
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RAISE EXCEPTION 'rpc_register_push_token: token is required' USING ERRCODE = '22023';
  END IF;
  IF p_platform IS NULL
     OR p_platform NOT IN ('android', 'iOS', 'macOS', 'web', 'linux', 'windows', 'fuchsia') THEN
    RAISE EXCEPTION 'rpc_register_push_token: invalid platform %', p_platform USING ERRCODE = '22023';
  END IF;
  IF p_os_permission IS NOT NULL AND p_os_permission NOT IN ('granted', 'denied', 'provisional') THEN
    RAISE EXCEPTION 'rpc_register_push_token: invalid os_permission %', p_os_permission USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.fcm_tokens AS f
         (user_id, installation_id, token, device_platform, app_version, locale, os_permission)
  VALUES (v_uid, p_installation_id, p_token, p_platform, p_app_version, p_locale, p_os_permission)
  ON CONFLICT (user_id, installation_id) DO UPDATE
     SET token           = EXCLUDED.token,
         device_platform = EXCLUDED.device_platform,
         app_version     = EXCLUDED.app_version,
         locale          = EXCLUDED.locale,
         os_permission   = EXCLUDED.os_permission
  RETURNING f.id INTO v_id;

  RETURN v_id;
END;
$function$;

CREATE FUNCTION public.rpc_unregister_push_token(p_installation_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_n   integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'rpc_unregister_push_token: not authenticated' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.fcm_tokens WHERE user_id = v_uid AND installation_id = p_installation_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n > 0;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_register_push_token(text, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_unregister_push_token(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_register_push_token(text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_unregister_push_token(text) TO authenticated;

-- 6. RLS: the owner manages only their own rows; authenticated only -----------------------------------------------
DROP POLICY "Users can view their own FCM tokens"   ON public.fcm_tokens;
DROP POLICY "Users can insert their own FCM tokens" ON public.fcm_tokens;
DROP POLICY "Users can update their own FCM tokens" ON public.fcm_tokens;
DROP POLICY "Users can delete their own FCM tokens" ON public.fcm_tokens;

CREATE POLICY fcm_tokens_owner_select ON public.fcm_tokens FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
CREATE POLICY fcm_tokens_owner_insert ON public.fcm_tokens FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY fcm_tokens_owner_update ON public.fcm_tokens FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY fcm_tokens_owner_delete ON public.fcm_tokens FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON TABLE public.fcm_tokens FROM anon;

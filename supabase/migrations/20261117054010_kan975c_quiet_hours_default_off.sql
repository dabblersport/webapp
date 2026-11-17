-- KAN-975 follow-up c: quiet hours default OFF until silent delivery lands (coordinator ruling 2026-11-17).
--
-- Why: trg_push_on_notification_insert (owned by KAN-979) still DROPS a push inside the quiet window. The current
-- client upserts notification_settings directly, so with the 0/480 column defaults of 20261117045159 every new row
-- would lose its pushes 00:00-08:00. Until KAN-979 switches that trigger to silent delivery (I-2):
--   * quiet_start_min / quiet_end_min default NULL (off); rpc_get_my_notification_settings creates rows from the
--     table defaults, so its rows are off too (function unchanged).
--   * is_quiet_hour treats a user with no row as off, matching the column defaults.
--   * rpc_update_my_notification_settings still gives 00:00-08:00 when the user switches quiet hours on with no
--     window: that is a user choice, not a default.
-- KAN-979 OWNS switching the default to 00:00-08:00 (column defaults 0 / 480 and is_quiet_hour's no-row branch) in
-- the same migration where silent delivery lands.
--
-- Rows reset: rows created or changed since 20261117045159 with exactly 0/480 that the user did not set.
-- Listed before this migration (2026-11-17): 0 such rows; the table has 1 row (b7487857..., quiet NULL, its
-- updated_at moved only because 20261117053604 renamed a category key). The guard aborts if any 0/480 row exists,
-- because a later 0/480 could be the user's own choice through the RPC and must be looked at by hand.

DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.is_quiet_hour(uuid,timestamptz)'::regprocedure))
       <> 'aab0369c87001da37a2c1384a91f9483' THEN
    RAISE EXCEPTION 'KAN-975c pre-image guard failed: is_quiet_hour changed';
  END IF;
  IF (SELECT pg_get_expr(d.adbin, d.adrelid) FROM pg_attrdef d JOIN pg_attribute a
         ON a.attrelid = d.adrelid AND a.attnum = d.adnum
      WHERE d.adrelid = 'public.notification_settings'::regclass AND a.attname = 'quiet_start_min') IS DISTINCT FROM '0'
  OR (SELECT pg_get_expr(d.adbin, d.adrelid) FROM pg_attrdef d JOIN pg_attribute a
         ON a.attrelid = d.adrelid AND a.attnum = d.adnum
      WHERE d.adrelid = 'public.notification_settings'::regclass AND a.attname = 'quiet_end_min') IS DISTINCT FROM '480' THEN
    RAISE EXCEPTION 'KAN-975c pre-image guard failed: quiet defaults are not 0/480';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_settings
              WHERE quiet_start_min = 0 AND quiet_end_min = 480
                AND (created_at >= '2026-11-17 04:51:59+00' OR updated_at >= '2026-11-17 04:51:59+00')) THEN
    RAISE EXCEPTION 'KAN-975c pre-image guard failed: a 0/480 row appeared since 20261117045159; list it and decide by hand';
  END IF;
END
$pre$;

ALTER TABLE public.notification_settings
  ALTER COLUMN quiet_start_min DROP DEFAULT,
  ALTER COLUMN quiet_end_min   DROP DEFAULT;

COMMENT ON COLUMN public.notification_settings.quiet_start_min IS
  'KAN-975: quiet hours start, minutes after local midnight (0-1439). NULL with quiet_end_min = quiet hours off. Default NULL (off) until KAN-979 lands silent delivery and sets 0 (00:00).';
COMMENT ON COLUMN public.notification_settings.quiet_end_min IS
  'KAN-975: quiet hours end (exclusive), minutes after local midnight. Must differ from start. Default NULL until KAN-979 sets 480 (08:00).';

CREATE OR REPLACE FUNCTION public.is_quiet_hour(p_user uuid, p_at timestamp with time zone DEFAULT now())
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_tz text;
  v_start int;
  v_end int;
  v_local int;
begin
  -- KAN-975: the one store is notification_settings.
  select ns.tz, ns.quiet_start_min, ns.quiet_end_min into v_tz, v_start, v_end
  from public.notification_settings ns where ns.user_id = p_user;

  if not found then
    -- No row yet: same as the column defaults, quiet hours off (KAN-975c). KAN-979 switches this to
    -- 'Asia/Dubai', 0, 480 together with the column defaults when silent delivery lands.
    return false;
  end if;

  if v_start is null or v_end is null or v_start = v_end then
    return false; -- quiet hours off
  end if;

  v_local := extract(hour from (coalesce(p_at, now()) at time zone coalesce(v_tz, 'Asia/Dubai')))::int * 60
           + extract(minute from (coalesce(p_at, now()) at time zone coalesce(v_tz, 'Asia/Dubai')))::int;

  if v_start < v_end then
    return v_local >= v_start and v_local < v_end;    -- same-day window, e.g. 13:00-15:00
  else
    return v_local >= v_start or v_local < v_end;     -- across midnight, e.g. 23:00-07:00
  end if;
end;
$function$;

DO $post$
DECLARE v_bad text := '';
BEGIN
  IF EXISTS (SELECT 1 FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
              WHERE d.adrelid = 'public.notification_settings'::regclass
                AND a.attname IN ('quiet_start_min', 'quiet_end_min')) THEN
    v_bad := v_bad || ' quiet-default-still-set';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.is_quiet_hour(uuid,timestamptz)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    v_bad := v_bad || ' is_quiet_hour-acl-changed';
  END IF;
  IF public.is_quiet_hour(gen_random_uuid(), '2026-11-17 01:00 Asia/Dubai') THEN
    v_bad := v_bad || ' no-row-still-quiet';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-975c post assert failed:%', v_bad;
  END IF;
END
$post$;

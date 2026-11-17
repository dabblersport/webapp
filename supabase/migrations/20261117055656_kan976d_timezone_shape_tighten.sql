-- KAN-976d: follow-up from the KAN-976 review (Jira KAN-976 comment 16424, backend-6).
--
-- The kan976c shape ^(UTC|[A-Z][A-Za-z]+(/[A-Za-z0-9_+-]+)+)$ let POSIX-like names through: 'Asia/Dubai+4' (Postgres
-- reads it as a POSIX spec and accepts it) and 'Etc/GMT+4' / 'Etc/GMT+99' (sign reversed). The new shape
--   ^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$
-- allows only 'UTC' or Area/Location[/Location] where every part starts upper-case and holds letters, '_' and '-'
-- (America/Port-au-Prince, America/North_Dakota/New_Salem). No digits, no '+', so Etc/GMT±N is rejected.
--   1. event_timezone uses the new shape (body from pg_get_functiondef on the live kan976c version; attributes and ACL
--      kept by CREATE OR REPLACE). The guarded AT TIME ZONE probe stays.
--   2. venues.timezone gets CHECK venues_timezone_shape_chk with the same rule, so a bad zone cannot be stored.
--      Checked live before writing: 384 of 384 venues pass (all 'Asia/Dubai'); no app or edge-function writer of the
--      column was found. The guard below re-counts and aborts on any failing row.
-- Pre-image guard: event_timezone body is the kan976c one; the constraint does not exist; every venue passes.
-- Post asserts: attributes, ACL, new regex in the body, constraint present and validated.
-- Live test: supabase/tests/notifications_v2/kan976_event_change_signal.sql (T16-T21, P13 timing).

-- 1. pre-image guard ---------------------------------------------------------------------------------------------------
DO $pre$
DECLARE d text := pg_get_functiondef('public.event_timezone(uuid)'::regprocedure);
BEGIN
  IF position('''^(UTC|[A-Z][A-Za-z]+(/[A-Za-z0-9_+-]+)+)$''' IN d) = 0 THEN
    RAISE EXCEPTION 'kan976d pre: event_timezone body is not the 20261117054042 (kan976c) version';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.venues'::regclass AND conname = 'venues_timezone_shape_chk') THEN
    RAISE EXCEPTION 'kan976d pre: venues_timezone_shape_chk already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM public.venues WHERE timezone !~ '^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$') THEN
    RAISE EXCEPTION 'kan976d pre: % venue(s) fail the new shape',
      (SELECT count(*) FROM public.venues WHERE timezone !~ '^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$');
  END IF;
END $pre$;

-- 2. event_timezone ----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.event_timezone(p_event_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_found   boolean;
  v_venue   text;
  v_country text;
  v_tz      text;
BEGIN
  SELECT true, btrim(v.timezone), upper(btrim(a.country_code))
    INTO v_found, v_venue, v_country
    FROM public.events e
    LEFT JOIN public.venues        v  ON v.id  = e.venue_id
    LEFT JOIN public.geo_locations gl ON gl.id = e.geo_location_id
    LEFT JOIN public.areas         a  ON a.id  = coalesce(e.area_id, gl.area_id)
   WHERE e.id = p_event_id;

  IF v_found IS NULL THEN
    RETURN NULL;
  END IF;

  -- 'UTC' or Area/Location[/Location], every part upper-case first, letters/_/- only: no POSIX, no Etc/GMT±N.
  -- The probe then rejects a well-shaped name Postgres does not know.
  IF v_venue ~ '^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$' THEN
    BEGIN
      PERFORM now() AT TIME ZONE v_venue;
      RETURN v_venue;
    EXCEPTION WHEN invalid_parameter_value THEN
      NULL;  -- unknown zone: fall through to the area
    END;
  END IF;

  v_tz := CASE v_country
            WHEN 'AE' THEN 'Asia/Dubai'
            WHEN 'SA' THEN 'Asia/Riyadh'
            WHEN 'QA' THEN 'Asia/Qatar'
            WHEN 'KW' THEN 'Asia/Kuwait'
            WHEN 'BH' THEN 'Asia/Bahrain'
            WHEN 'OM' THEN 'Asia/Muscat'
          END;

  RETURN coalesce(v_tz, 'Asia/Dubai');
END
$function$;

-- 3. constraint on the stored value ------------------------------------------------------------------------------------
ALTER TABLE public.venues
  ADD CONSTRAINT venues_timezone_shape_chk
  CHECK (timezone ~ '^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$');

-- 4. post asserts ------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  f oid := 'public.event_timezone(uuid)'::regprocedure;
  d text := pg_get_functiondef('public.event_timezone(uuid)'::regprocedure);
BEGIN
  IF NOT (SELECT prosecdef AND provolatile = 's' AND proconfig = ARRAY['search_path=""'] FROM pg_proc WHERE oid = f)
     OR (SELECT proacl::text FROM pg_proc WHERE oid = f) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR position('''^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$''' IN d) = 0
     OR position('[A-Za-z0-9_+-]' IN d) > 0 THEN
    RAISE EXCEPTION 'kan976d post: event_timezone attributes, ACL or body not as intended';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.venues'::regclass
                  AND conname = 'venues_timezone_shape_chk' AND contype = 'c' AND convalidated) THEN
    RAISE EXCEPTION 'kan976d post: venues_timezone_shape_chk missing or not validated';
  END IF;
END $post$;

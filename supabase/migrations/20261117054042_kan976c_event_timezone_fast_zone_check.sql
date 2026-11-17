-- KAN-976c: PEER re-review fix (Jira KAN-976 comment 16414, backend-6).
--
-- 20261117053118 (kan976b) made event_timezone check the venue zone with EXISTS on pg_catalog.pg_timezone_names. That
-- view reads the whole tz database on every call: 54 ms per call, 16.8 s for 315 events (measured live 2026-11-17).
-- The scheduler (KAN-983) and the producers (KAN-981) call it once per event, so that is too slow.
--
-- Replacement (backend-6's shape): the zone must match
--   ^(UTC|[A-Z][A-Za-z]+(/[A-Za-z0-9_+-]+)+)$
-- i.e. 'UTC' or an Area/Location name. Then `now() AT TIME ZONE` must accept it, checked inside a
-- BEGIN/EXCEPTION invalid_parameter_value block. Anything that fails either check falls through to the area map, then
-- 'Asia/Dubai'. Rejected by the shape: POSIX strings ('UTC+4', '+04'), abbreviations ('GST'), lowercase, empty, and
-- legacy names without a slash such as 'EST5EDT' (accepted by the reviewer). A name with the right shape that Postgres
-- does not know ('Mars/Olympus') is rejected by the probe.
-- Body authored from pg_get_functiondef on the live catalogue (the kan976b version). CREATE OR REPLACE keeps the owner,
-- attributes (plpgsql, STABLE, SECURITY DEFINER, search_path '') and the ACL (postgres, service_role only).
-- Pre-image guard: the live body is the kan976b one (uses pg_timezone_names, no shape regex).
-- Post asserts: attributes and ACL unchanged; body has the shape check and no pg_timezone_names.
-- Live test: supabase/tests/notifications_v2/kan976_event_change_signal.sql (T1-T13, P13 timing, N3 control).

-- 1. pre-image guard ---------------------------------------------------------------------------------------------------
DO $pre$
DECLARE d text := pg_get_functiondef('public.event_timezone(uuid)'::regprocedure);
BEGIN
  IF position('FROM pg_catalog.pg_timezone_names tz WHERE tz.name = btrim(v_venue)' IN d) = 0
     OR position('[A-Z][A-Za-z]+' IN d) > 0 THEN
    RAISE EXCEPTION 'kan976c pre: event_timezone body is not the 20261117053118 (kan976b) version';
  END IF;
END $pre$;

-- 2. event_timezone: shape check + guarded AT TIME ZONE probe ----------------------------------------------------------
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

  -- 'UTC' or an Area/Location name; POSIX strings, abbreviations, lowercase and empty fall through. The probe then
  -- rejects a well-shaped name Postgres does not know.
  IF v_venue ~ '^(UTC|[A-Z][A-Za-z]+(/[A-Za-z0-9_+-]+)+)$' THEN
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

-- 3. post asserts ------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  f oid := 'public.event_timezone(uuid)'::regprocedure;
  d text := pg_get_functiondef('public.event_timezone(uuid)'::regprocedure);
BEGIN
  IF NOT (SELECT prosecdef AND provolatile = 's' AND proconfig = ARRAY['search_path=""'] FROM pg_proc WHERE oid = f)
     OR has_function_privilege('anon', f, 'EXECUTE') OR has_function_privilege('authenticated', f, 'EXECUTE')
     OR NOT has_function_privilege('service_role', f, 'EXECUTE')
     OR (SELECT proacl::text FROM pg_proc WHERE oid = f) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR position('pg_timezone_names' IN d) > 0
     OR position('[A-Z][A-Za-z]+(/[A-Za-z0-9_+-]+)+' IN d) = 0 THEN
    RAISE EXCEPTION 'kan976c post: event_timezone attributes, ACL or body not as intended';
  END IF;
END $post$;

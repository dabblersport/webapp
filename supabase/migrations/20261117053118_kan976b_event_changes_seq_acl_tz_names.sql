-- KAN-976b: PEER fix for 20261117045201_kan976_event_change_signal (Jira KAN-976 comment 16410, backend-6).
--
-- 1. public.event_changes_id_seq was created with rwU for anon and authenticated (project default ACL), so a client
--    could setval() it and make every later tracked events UPDATE fail on the event_changes primary key. Revoke all
--    from PUBLIC, anon, authenticated. postgres (the trigger function's owner, which does the inserts) and
--    service_role keep theirs.
-- 2. event_timezone validated the venue zone with `now() AT TIME ZONE`, which also accepts POSIX strings such as
--    'UTC+4' (and gets their sign backwards). It now accepts only a name in pg_catalog.pg_timezone_names; anything
--    else falls through to the area map, then 'Asia/Dubai'. Body authored from pg_get_functiondef on the live
--    catalogue; CREATE OR REPLACE keeps the owner, attributes and ACL (postgres, service_role only).
-- Pre-image guard: the sequence ACL and the function body are as read live on 2026-11-17 before this fix.
-- Post asserts: no client privilege on the sequence; function attributes and ACL unchanged; body uses
--   pg_timezone_names.
-- Live test: supabase/tests/notifications_v2/kan976_event_change_signal.sql (probes S1, T7).

-- 1. pre-image guard ---------------------------------------------------------------------------------------------------
DO $pre$
BEGIN
  IF (SELECT relacl::text FROM pg_class WHERE oid = 'public.event_changes_id_seq'::regclass)
     IS DISTINCT FROM '{postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}' THEN
    RAISE EXCEPTION 'kan976b pre: event_changes_id_seq ACL is not the one read before the fix';
  END IF;
  IF position('PERFORM now() AT TIME ZONE btrim(v_venue);' IN pg_get_functiondef('public.event_timezone(uuid)'::regprocedure)) = 0
     OR position('pg_timezone_names' IN pg_get_functiondef('public.event_timezone(uuid)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'kan976b pre: event_timezone body is not the 20261117045201 version';
  END IF;
END $pre$;

-- 2. sequence ACL ------------------------------------------------------------------------------------------------------
REVOKE ALL ON SEQUENCE public.event_changes_id_seq FROM PUBLIC, anon, authenticated;

-- 3. event_timezone: zone must be a known IANA name ---------------------------------------------------------------------
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
  SELECT true, v.timezone, upper(btrim(a.country_code))
    INTO v_found, v_venue, v_country
    FROM public.events e
    LEFT JOIN public.venues        v  ON v.id  = e.venue_id
    LEFT JOIN public.geo_locations gl ON gl.id = e.geo_location_id
    LEFT JOIN public.areas         a  ON a.id  = coalesce(e.area_id, gl.area_id)
   WHERE e.id = p_event_id;

  IF v_found IS NULL THEN
    RETURN NULL;
  END IF;

  -- Only an IANA name Postgres lists counts; POSIX strings like 'UTC+4' and abbreviations fall through.
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names tz WHERE tz.name = btrim(v_venue)) THEN
    RETURN btrim(v_venue);
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

-- 4. post asserts ------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  s oid := 'public.event_changes_id_seq'::regclass;
  f oid := 'public.event_timezone(uuid)'::regprocedure;
BEGIN
  IF has_sequence_privilege('anon', s, 'USAGE') OR has_sequence_privilege('anon', s, 'SELECT')
     OR has_sequence_privilege('anon', s, 'UPDATE')
     OR has_sequence_privilege('authenticated', s, 'USAGE') OR has_sequence_privilege('authenticated', s, 'SELECT')
     OR has_sequence_privilege('authenticated', s, 'UPDATE')
     OR (SELECT relacl::text FROM pg_class WHERE oid = s) ~ '(^|[{,])=' THEN
    RAISE EXCEPTION 'kan976b post: a client role or PUBLIC still has a privilege on event_changes_id_seq';
  END IF;
  IF NOT (SELECT prosecdef AND provolatile = 's' AND proconfig = ARRAY['search_path=""'] FROM pg_proc WHERE oid = f)
     OR has_function_privilege('anon', f, 'EXECUTE') OR has_function_privilege('authenticated', f, 'EXECUTE')
     OR NOT has_function_privilege('service_role', f, 'EXECUTE')
     OR position('pg_timezone_names' IN pg_get_functiondef(f)) = 0 THEN
    RAISE EXCEPTION 'kan976b post: event_timezone attributes, ACL or body not as intended';
  END IF;
END $post$;

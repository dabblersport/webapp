-- KAN-1051: Profile -> Manage Sports failed with "permission denied for table sports (42501)".
-- Chain: INSERT/DELETE on sport_profiles -> statement trigger trg_sport_profiles_sync ->
-- trgfn_sport_profiles_sync() (INVOKER) -> recompute_sport_user_counts() (INVOKER) -> UPDATE public.sports.
-- authenticated has only SELECT on sports since KAN-86 (20260901190000), so the counter UPDATE ran as the
-- user and was denied. Fix: both functions SECURITY DEFINER (owner postgres), pinned search_path, and no
-- EXECUTE for PUBLIC/anon/authenticated (trigger firing does not check EXECUTE). No grant on sports.
-- Bodies taken verbatim from pg_get_functiondef on the live catalogue.
-- Rollback: supabase/rollbacks/20261126090000_kan1051_sport_counts_definer_rollback.sql
BEGIN;

CREATE OR REPLACE FUNCTION public.recompute_sport_user_counts()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.sports
  SET primary_user_count = 0, interested_user_count = 0
  WHERE true;

  -- primary sport count — explicit uuid::text cast avoids btrim(uuid) error
  UPDATE public.sports s
  SET primary_user_count = sub.cnt
  FROM (
    SELECT
      lower(trim(primary_sport::text)) AS sport_key,
      COUNT(*) AS cnt
    FROM public.profiles
    WHERE primary_sport IS NOT NULL
      AND is_active = true
    GROUP BY lower(trim(primary_sport::text))
  ) sub
  WHERE s.sport_key = sub.sport_key;

  -- interested sport count — sport_id is uuid vs uuid, no citext involved
  UPDATE public.sports s
  SET interested_user_count = sub.cnt
  FROM (
    SELECT sp.sport_id, COUNT(DISTINCT sp.profile_id) AS cnt
    FROM public.sport_profiles sp
    JOIN public.profiles p ON p.id = sp.profile_id
    WHERE p.is_active = true
    GROUP BY sp.sport_id
  ) sub
  WHERE s.id = sub.sport_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trgfn_sport_profiles_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.recompute_sport_user_counts();
  RETURN NULL;
END;
$function$;

ALTER FUNCTION public.recompute_sport_user_counts() OWNER TO postgres;
ALTER FUNCTION public.trgfn_sport_profiles_sync() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.recompute_sport_user_counts() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trgfn_sport_profiles_sync() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_sport_user_counts() TO service_role;
GRANT EXECUTE ON FUNCTION public.trgfn_sport_profiles_sync() TO service_role;

COMMIT;

-- KAN-1063 rollback: restores the pre-KAN-1063 body (live pg_get_functiondef, 2026-11-28).
CREATE OR REPLACE FUNCTION public.recompute_sport_user_counts()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.sports
  SET primary_user_count = 0, interested_user_count = 0, player_count = 0
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

  -- KAN-1059: interested = followers (profiles.interests)
  UPDATE public.sports s
  SET interested_user_count = sub.cnt
  FROM (
    SELECT i.sport_id, COUNT(DISTINCT p.id) AS cnt
    FROM public.profiles p
    CROSS JOIN LATERAL unnest(p.interests) AS i(sport_id)
    WHERE p.is_active = true
    GROUP BY i.sport_id
  ) sub
  WHERE s.id = sub.sport_id;

  -- KAN-1059: players = active (non-hidden) cards
  UPDATE public.sports s
  SET player_count = sub.cnt
  FROM (
    SELECT sp.sport_id, COUNT(DISTINCT sp.profile_id) AS cnt
    FROM public.sport_profiles sp
    JOIN public.profiles p ON p.id = sp.profile_id
    WHERE p.is_active = true AND sp.hidden_at IS NULL
    GROUP BY sp.sport_id
  ) sub
  WHERE s.id = sub.sport_id;
END;
$function$;

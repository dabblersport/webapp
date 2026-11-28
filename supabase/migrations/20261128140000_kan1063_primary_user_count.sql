-- KAN-1063: recompute_sport_user_counts() matched profiles.primary_sport (uuid) to sports.sport_key (text),
-- so primary_user_count was always 0. Compare on sports.id. Body otherwise from live pg_get_functiondef.
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

  -- KAN-1063: primary_sport is a uuid (sports.id); compare on id, not sport_key
  UPDATE public.sports s
  SET primary_user_count = sub.cnt
  FROM (
    SELECT primary_sport AS sport_id, COUNT(*) AS cnt
    FROM public.profiles
    WHERE primary_sport IS NOT NULL
      AND is_active = true
    GROUP BY primary_sport
  ) sub
  WHERE s.id = sub.sport_id;

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

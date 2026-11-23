-- Rollback for KAN-1033: restores the pre-fix grants and function body exactly.
GRANT SELECT ON public.v_game_card, public.v_my_games, public.v_meetup_list,
  public.v_challenge_card, public.v_recreate_candidates,
  public.kan718_games_compat, public.kan718_meetups_compat,
  public.v_recreate_quickpicks, public.v_potential_vibes_default
  TO anon;
GRANT SELECT ON public.v_potential_vibes_default TO authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_nearby_users(double precision, double precision, double precision, integer)
  TO PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO PUBLIC, anon;

CREATE OR REPLACE FUNCTION public.check_user_exists_by_identifier(identifier text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Check auth.users table for email or phone
  RETURN EXISTS (
    SELECT 1 
    FROM auth.users
    WHERE email = identifier
       OR phone = identifier
       OR phone = REPLACE(identifier, '+', '')
       OR CONCAT('+', phone) = identifier
  );
END;
$function$;

DROP TABLE IF EXISTS public.identifier_check_calls;

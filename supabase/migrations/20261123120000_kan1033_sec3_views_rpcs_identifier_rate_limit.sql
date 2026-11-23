-- KAN-1033 (SEC-3): close anon exposure on views and RPCs, rate-limit the
-- sign-in existence check. No view gets security_invoker (it would empty them).
-- Evidence: 7 days of edge_logs (2026-11-16..23) show no anon caller of any
-- object revoked here; browser rows without a role are CORS OPTIONS preflights.

-- 1. Views: anon loses SELECT; authenticated keeps it (the app reads them).
REVOKE SELECT ON public.v_game_card, public.v_my_games, public.v_meetup_list,
  public.v_challenge_card, public.v_recreate_candidates,
  public.kan718_games_compat, public.kan718_meetups_compat,
  public.v_recreate_quickpicks
  FROM anon;

-- v_potential_vibes_default lists users (user_id, username, display_name).
-- Nothing in lib/ or supabase/functions reads it: revoke anon and authenticated.
REVOKE SELECT ON public.v_potential_vibes_default FROM anon, authenticated;

-- 2. rpc_nearby_users: exact coordinates, no callers. service_role only.
REVOKE EXECUTE ON FUNCTION public.rpc_nearby_users(double precision, double precision, double precision, integer)
  FROM PUBLIC, anon, authenticated;

-- 3. is_admin(uuid): anon could enumerate admins. Keep authenticated.
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid) FROM PUBLIC, anon;

-- 4. Rate limit for check_user_exists_by_identifier: 10 calls per IP per 10 min.
CREATE TABLE IF NOT EXISTS public.identifier_check_calls (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ip text NOT NULL,
  called_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS identifier_check_calls_ip_called_at_idx
  ON public.identifier_check_calls (ip, called_at);
ALTER TABLE public.identifier_check_calls ENABLE ROW LEVEL SECURITY;
-- No policies, no grants: only the SECURITY DEFINER function touches it.
REVOKE ALL ON public.identifier_check_calls FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.check_user_exists_by_identifier(identifier text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ip text;
  v_calls int;
BEGIN
  -- First x-forwarded-for entry; no IP means no limit.
  v_ip := nullif(btrim(split_part(
    coalesce(current_setting('request.headers', true)::json->>'x-forwarded-for', ''),
    ',', 1)), '');

  IF v_ip IS NOT NULL THEN
    DELETE FROM public.identifier_check_calls
      WHERE called_at < now() - interval '10 minutes';
    SELECT count(*) INTO v_calls FROM public.identifier_check_calls
      WHERE ip = v_ip AND called_at >= now() - interval '10 minutes';
    IF v_calls >= 10 THEN
      RAISE EXCEPTION 'rate limit exceeded' USING ERRCODE = 'PT429';
    END IF;
    INSERT INTO public.identifier_check_calls (ip) VALUES (v_ip);
  END IF;

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

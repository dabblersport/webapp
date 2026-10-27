-- KAN-673: close KAN-646 finding F2 on public.rpc_create_sport_profile(uuid, uuid, text, integer).
--
-- Before: the legacy branch (persona_type = 'player') had no ownership test, so any caller could create a
-- sport profile for any player profile, and EXECUTE was granted to PUBLIC and anon.
-- After: only the owner (profiles.user_id = auth.uid()) of a player profile passes the legacy
-- branch; anyone else, and any non-player, gets ONE error: 42501 'sport_profile requires owned player profile'.
--
-- CTO ruling applied: same signature and void return, CREATE OR REPLACE only, SECURITY DEFINER with
-- search_path 'public', 'pg_temp', EXECUTE revoked from PUBLIC and anon, kept for authenticated and service_role.
-- The owned-contributor branch added by 20261026120000 is carried over unchanged so its behaviour stays.
-- Nothing else is touched. Applied by Ops; the team runs no live SQL.

CREATE OR REPLACE FUNCTION public.rpc_create_sport_profile(
  p_profile_id uuid,
  p_sport_id uuid,
  p_sport_key text,
  p_skill_level integer DEFAULT 1
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = p_profile_id AND persona_type = 'player' AND user_id = auth.uid())
     AND NOT EXISTS (SELECT 1 FROM public.profiles pc
                     WHERE pc.id = p_profile_id AND pc.persona_type = 'contributor' AND pc.is_active = true
                       AND pc.user_id = public.effective_actor_uid()
                       AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pc.id)) THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'sport_profile requires owned player profile';
  END IF;
  INSERT INTO public.sport_profiles (profile_id, sport, sport_id, skill_level)
  VALUES (p_profile_id, p_sport_key, p_sport_id, p_skill_level)
  ON CONFLICT (profile_id, sport) DO UPDATE SET skill_level = EXCLUDED.skill_level;
END;
$function$;

-- pg_default_acl grants anon by name on public, so revoking PUBLIC alone would leave anon able to execute.
REVOKE EXECUTE ON FUNCTION public.rpc_create_sport_profile(uuid, uuid, text, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.rpc_create_sport_profile(uuid, uuid, text, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_sport_profile(uuid, uuid, text, integer) TO authenticated, service_role;

-- Post-condition: assert the resulting ACL for every overload, not that the statements ran.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT p.oid FROM pg_proc p
           WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'rpc_create_sport_profile'
  LOOP
    IF has_function_privilege('anon', r.oid, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = r.oid AND a.grantee = 0)
       OR NOT has_function_privilege('authenticated', r.oid, 'EXECUTE')
       OR NOT has_function_privilege('service_role', r.oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'kan673_acl_postcondition_failed: %', r.oid::regprocedure;
    END IF;
  END LOOP;
END;
$$;

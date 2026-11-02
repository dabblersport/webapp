-- KAN-674: close KAN-646 finding F1. The organiser predicate reads persona_type, not profile_type.
--
-- Before: public.actor_is_organiser(uuid) tested profile_type = 'organiser'. profiles_profile_type_check never
-- allows that value (legacy organisers carry profile_type = 'business'), so the branch was dead and a persona_type
-- = 'organiser' profile was never an organiser. v_actor_context had the same dead test on both of its columns.
-- After: an active profile with persona_type = 'organiser' is an organiser, and organiser_profile_id /
-- player_profile_id in v_actor_context follow persona_type.
--
-- Ruling applied (CPO: an Organiser is a persona; CTO: CREATE OR REPLACE only). The body keeps the KAN-646
-- contributor branch (20261026120000 step 3: a contributor with an organiser row is an organiser) because probes
-- T1-T6 depend on it; only the dead profile_type = 'organiser' clause is replaced by persona_type = 'organiser'.
-- Signature (uuid) boolean, STABLE and SECURITY INVOKER are unchanged; search_path is 'public', 'pg_temp'.
--
-- Grants are NOT touched here: v_access_matrix (security_invoker, granted to anon) reaches this function through
-- can_create_game, so revoking anon EXECUTE would turn its empty result for anon into a permission error.
-- Nothing else is changed and nothing is removed. Applied by Ops; the team runs no live SQL.

CREATE OR REPLACE FUNCTION public.actor_is_organiser(p_profile_id uuid) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $function$
  select exists(
    select 1 from public.profiles
    where id = p_profile_id and is_active = true
      and (persona_type = 'organiser'
           or (persona_type = 'contributor'
               and exists (select 1 from public.organiser x where x.profile_id = p_profile_id)))
  )
$function$;

-- Same column list and order as baseline :25088; only player_profile_id and organiser_profile_id changed
-- (profile_type = 'player' / 'organiser' became persona_type = 'player' / 'organiser').
CREATE OR REPLACE VIEW public.v_actor_context WITH (security_invoker = 'true') AS
 WITH pref AS (
         SELECT user_actor_pref.preferred_actor_type
           FROM public.user_actor_pref
          WHERE (user_actor_pref.user_id = auth.uid())
        )
 SELECT ( SELECT pref.preferred_actor_type
           FROM pref) AS preferred_actor_type,
    ( SELECT profiles.id
           FROM public.profiles
          WHERE ((profiles.user_id = auth.uid()) AND (profiles.persona_type = 'player'::text) AND (profiles.is_active = true))
         LIMIT 1) AS player_profile_id,
    ( SELECT profiles.id
           FROM public.profiles
          WHERE ((profiles.user_id = auth.uid()) AND (profiles.persona_type = 'organiser'::text) AND (profiles.is_active = true))
         LIMIT 1) AS organiser_profile_id;

-- KAN-644 rollback (AUTHORED, NOT RUN; an APPLY that Operations runs). Rollback order: stop exposing the new
-- personas in clients/RPCs FIRST, then run this. It REFUSES while any contributor/partner row or any
-- onboarding_intention value exists, so it can never shrink the CHECK under live rows or rewrite them to player.
DO $$
DECLARE n_c bigint; n_p bigint; n_i bigint;
BEGIN
  SELECT count(*) FILTER (WHERE persona_type='contributor'), count(*) FILTER (WHERE persona_type='partner'),
         count(*) FILTER (WHERE onboarding_intention IS NOT NULL)
    INTO n_c, n_p, n_i FROM public.profiles;
  IF n_c + n_p + n_i > 0 THEN
    RAISE EXCEPTION 'KAN-644 rollback refused: contributor=%, partner=%, onboarding_intention set=%. Roll back exposure/code first; nothing was changed.', n_c, n_p, n_i;
  END IF;
END $$;

DROP TRIGGER IF EXISTS trg_contributor_sports_sp ON public.sport_profiles;
DROP TRIGGER IF EXISTS trg_contributor_sports_profiles ON public.profiles;
DROP TRIGGER IF EXISTS trg_unified_persona_guard_upd ON public.profiles;
DROP TRIGGER IF EXISTS trg_unified_persona_guard_ins ON public.profiles;
-- re-point the extension guards at the ORIGINAL, never-edited functions
CREATE OR REPLACE TRIGGER trg_player_profile_persona_guard BEFORE INSERT OR UPDATE ON public.player FOR EACH ROW EXECUTE FUNCTION public.trgfn_player_profile_persona_guard();
CREATE OR REPLACE TRIGGER trg_organiser_profile_persona_guard BEFORE INSERT OR UPDATE ON public.organiser FOR EACH ROW EXECUTE FUNCTION public.trgfn_organiser_profile_persona_guard();
CREATE OR REPLACE TRIGGER trg_host_profile_persona_guard BEFORE INSERT OR UPDATE ON public.host FOR EACH ROW EXECUTE FUNCTION public.trgfn_host_profile_persona_guard();
DROP FUNCTION IF EXISTS public.trgfn_contributor_sports_check();
DROP FUNCTION IF EXISTS public.trgfn_unified_persona_guard();
DROP FUNCTION IF EXISTS public.trgfn_player_persona_guard_v2();
DROP FUNCTION IF EXISTS public.trgfn_organiser_persona_guard_v2();
DROP FUNCTION IF EXISTS public.trgfn_host_persona_guard_v2();
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_onboarding_intention_persona_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_onboarding_intention_values_check;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS onboarding_intention;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_persona_type_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_persona_type_check
  CHECK (persona_type = ANY (ARRAY['player','organiser','host','socialiser']));

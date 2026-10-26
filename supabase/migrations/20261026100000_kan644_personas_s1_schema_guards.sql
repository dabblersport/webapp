-- KAN-644 Personas S1: additive Contributor/Partner schema, intention and single-profile guards.
-- AUTHORED, NOT APPLIED. Operations applies it under the existing controls (story 6).
--
-- Additive only. No existing row is rewritten, no old persona value is removed, no existing
-- function body is edited: the three extension guards are REPLACED BY NEW FUNCTIONS and the
-- triggers re-pointed, so rollback re-points them back to the untouched originals.
--
-- Error codes (RAISE EXCEPTION message, SQLSTATE P0001):
--   single_profile_required, persona_conversion_blocked, persona_write_via_rpc_only,
--   onboarding_intention_mismatch, contributor_sports_incomplete.

-- 1. persona_type: the four legacy values PLUS contributor and partner. profile_type untouched.
--    profiles_primary_sport_required_for_sport_personas is NOT touched (new personas need Primary too).
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_persona_type_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_persona_type_check
  CHECK (persona_type = ANY (ARRAY['player','organiser','host','socialiser','contributor','partner']));

-- 2. Independent intention preference. Nullable; legacy rows stay NULL (no backfill).
--    profiles.intention (NOT NULL, frozen by trg_block_legacy_persona_updates) is not used.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS onboarding_intention text;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_onboarding_intention_values_check
  CHECK (onboarding_intention IS NULL
         OR onboarding_intention IN ('connect_play','play_organise','organise','host_games'));
-- A set intention must match the persona: first three -> contributor, host_games -> partner,
-- legacy personas carry none. Incomplete unified rows (onboard is not true) may still be NULL.
ALTER TABLE public.profiles ADD CONSTRAINT profiles_onboarding_intention_persona_check
  CHECK (
    (onboarding_intention IS NULL AND NOT (persona_type IN ('contributor','partner') AND onboard IS TRUE))
    OR (persona_type = 'contributor' AND onboarding_intention IN ('connect_play','play_organise','organise'))
    OR (persona_type = 'partner' AND onboarding_intention = 'host_games')
  ) NOT VALID;
-- NOT VALID then VALIDATE: scans existing rows once (all legacy rows have NULL intention and pass).
ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_onboarding_intention_persona_check;

-- 3. Extension guards (new functions; same SET search_path as the originals).
CREATE OR REPLACE FUNCTION public.trgfn_player_persona_guard_v2() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = NEW.profile_id
                 AND p.persona_type IN ('player','contributor')) THEN
    RAISE EXCEPTION 'player.profile_id must reference a profiles row with persona_type = player or contributor';
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.trgfn_organiser_persona_guard_v2() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = NEW.profile_id
                 AND p.persona_type IN ('organiser','contributor')) THEN
    RAISE EXCEPTION 'organiser.profile_id must reference a profiles row with persona_type = organiser or contributor';
  END IF;
  RETURN NEW;
END $$;

-- Host: legacy aliases already supported (host, hoster) plus partner. Contributor is NOT accepted.
CREATE OR REPLACE FUNCTION public.trgfn_host_persona_guard_v2() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = NEW.profile_id
                 AND p.persona_type IN ('host','hoster','partner')) THEN
    RAISE EXCEPTION 'host.profile_id must reference a profiles row with persona_type = host or partner';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_player_profile_persona_guard ON public.player;
CREATE TRIGGER trg_player_profile_persona_guard BEFORE INSERT OR UPDATE ON public.player
  FOR EACH ROW EXECUTE FUNCTION public.trgfn_player_persona_guard_v2();
DROP TRIGGER IF EXISTS trg_organiser_profile_persona_guard ON public.organiser;
CREATE TRIGGER trg_organiser_profile_persona_guard BEFORE INSERT OR UPDATE ON public.organiser
  FOR EACH ROW EXECUTE FUNCTION public.trgfn_organiser_persona_guard_v2();
DROP TRIGGER IF EXISTS trg_host_profile_persona_guard ON public.host;
CREATE TRIGGER trg_host_profile_persona_guard BEFORE INSERT OR UPDATE ON public.host
  FOR EACH ROW EXECUTE FUNCTION public.trgfn_host_persona_guard_v2();

-- 4. One public profile per unified account. ONE lock discipline (reuse in story 2):
--    pg_advisory_xact_lock(hashtextextended('profiles:user:' || user_id, 0)).
--    All rows of the user are checked, inactive/historical included. Legacy-only accounts are
--    untouched; no UNIQUE(user_id) over history, nothing deleted or merged.
CREATE OR REPLACE FUNCTION public.trgfn_unified_persona_guard() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_new_unified boolean := NEW.persona_type IN ('contributor','partner');
  v_old_unified boolean := TG_OP = 'UPDATE' AND OLD.persona_type IN ('contributor','partner');
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('profiles:user:' || NEW.user_id::text, 0));
    IF v_new_unified AND current_user IN ('anon','authenticated') THEN
      RAISE EXCEPTION 'persona_write_via_rpc_only';
    END IF;
    IF v_new_unified THEN
      IF EXISTS (SELECT 1 FROM public.profiles WHERE user_id = NEW.user_id) THEN
        RAISE EXCEPTION 'single_profile_required';
      END IF;
    ELSIF EXISTS (SELECT 1 FROM public.profiles WHERE user_id = NEW.user_id
                  AND persona_type IN ('contributor','partner')) THEN
      RAISE EXCEPTION 'single_profile_required';
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE OF persona_type, onboarding_intention, user_id
  IF NEW.user_id IS DISTINCT FROM OLD.user_id AND (v_new_unified OR v_old_unified) THEN
    RAISE EXCEPTION 'single_profile_required';
  END IF;
  IF NEW.persona_type IS DISTINCT FROM OLD.persona_type THEN
    IF v_old_unified THEN
      RAISE EXCEPTION 'persona_conversion_blocked';        -- never downgrade or switch
    END IF;
    IF v_new_unified THEN
      -- legacy -> unified conversion is not an epic feature; only an unfinished sole row may be completed
      PERFORM pg_advisory_xact_lock(hashtextextended('profiles:user:' || NEW.user_id::text, 0));
      IF OLD.onboard IS TRUE OR current_user IN ('anon','authenticated')
         OR EXISTS (SELECT 1 FROM public.profiles WHERE user_id = NEW.user_id AND id <> NEW.id) THEN
        RAISE EXCEPTION 'persona_conversion_blocked';
      END IF;
    END IF;
  END IF;
  IF (v_new_unified OR v_old_unified)
     AND current_user IN ('anon','authenticated')
     AND (NEW.onboarding_intention IS DISTINCT FROM OLD.onboarding_intention
          OR NEW.persona_type IS DISTINCT FROM OLD.persona_type) THEN
    RAISE EXCEPTION 'persona_write_via_rpc_only';
  END IF;
  IF NEW.onboarding_intention IS DISTINCT FROM OLD.onboarding_intention
     AND current_user IN ('anon','authenticated') THEN
    RAISE EXCEPTION 'persona_write_via_rpc_only';           -- legacy rows too: intention is RPC-written
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_unified_persona_guard_ins BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.trgfn_unified_persona_guard();
CREATE TRIGGER trg_unified_persona_guard_upd
  BEFORE UPDATE OF persona_type, onboarding_intention, user_id ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.trgfn_unified_persona_guard();

-- 5. Completed Contributor sports rule, validated at transaction end (story 2 may insert the
--    profile, then sport_profiles / extensions, then mark onboard = true).
--    Following = profiles.interests (sport uuids); Practicing = sport_profiles.sport_id.
CREATE OR REPLACE FUNCTION public.trgfn_contributor_sports_check() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_pid uuid := CASE WHEN TG_TABLE_NAME = 'profiles' THEN NEW.id
                     WHEN TG_OP = 'DELETE' THEN OLD.profile_id ELSE NEW.profile_id END;
  p public.profiles%ROWTYPE;
BEGIN
  SELECT * INTO p FROM public.profiles WHERE id = v_pid;
  IF NOT FOUND OR p.persona_type <> 'contributor' OR p.onboard IS NOT TRUE THEN
    RETURN NULL;                                           -- legacy / partner / incomplete: no rule
  END IF;
  IF p.primary_sport IS NULL
     OR p.interests IS NULL OR NOT (p.interests @> ARRAY[p.primary_sport])
     OR NOT EXISTS (SELECT 1 FROM public.sport_profiles sp
                    WHERE sp.profile_id = p.id AND sp.sport_id = p.primary_sport)
     OR EXISTS (SELECT 1 FROM public.sport_profiles sp
                WHERE sp.profile_id = p.id AND NOT (p.interests @> ARRAY[sp.sport_id])) THEN
    RAISE EXCEPTION 'contributor_sports_incomplete';
  END IF;
  RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER trg_contributor_sports_profiles AFTER INSERT OR UPDATE ON public.profiles
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.trgfn_contributor_sports_check();
CREATE CONSTRAINT TRIGGER trg_contributor_sports_sp AFTER INSERT OR UPDATE OR DELETE ON public.sport_profiles
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.trgfn_contributor_sports_check();

-- 6. Hygiene: trigger functions are not callable RPCs (matches KAN-527); no grant added.
REVOKE EXECUTE ON FUNCTION public.trgfn_player_persona_guard_v2() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trgfn_organiser_persona_guard_v2() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trgfn_host_persona_guard_v2() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trgfn_unified_persona_guard() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trgfn_contributor_sports_check() FROM PUBLIC, anon, authenticated;

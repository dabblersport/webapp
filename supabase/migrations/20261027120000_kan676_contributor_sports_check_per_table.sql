-- KAN-676: trgfn_contributor_sports_check() resolved NEW.id and NEW.profile_id in one CASE, so
-- every profiles write (no profile_id column) and every sport_profiles write failed at COMMIT.
-- Fix: one IF branch per table (TG_TABLE_NAME), each touching only its own table's columns.
-- Everything else is unchanged from 20261026100000_kan644_personas_s1_schema_guards.sql section 5:
-- same signature, language, search_path, rule, error text, and trigger bindings (triggers untouched).
-- CREATE OR REPLACE only; no DROP.

CREATE OR REPLACE FUNCTION public.trgfn_contributor_sports_check() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_pid uuid;
  p public.profiles%ROWTYPE;
BEGIN
  IF TG_TABLE_NAME = 'profiles' THEN
    v_pid := NEW.id;
  ELSIF TG_TABLE_NAME = 'sport_profiles' THEN
    IF TG_OP = 'DELETE' THEN
      v_pid := OLD.profile_id;
    ELSE
      v_pid := NEW.profile_id;
    END IF;
  ELSE
    RETURN NULL;                                           -- not a table this rule is bound to
  END IF;

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

-- Re-assert hygiene: trigger function is not a callable RPC; no grant added.
REVOKE EXECUTE ON FUNCTION public.trgfn_contributor_sports_check() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.trgfn_contributor_sports_check()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.trgfn_contributor_sports_check()', 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-676: trgfn_contributor_sports_check must not be executable by anon/authenticated';
  END IF;
END $$;

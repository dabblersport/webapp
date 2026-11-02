-- KAN-644 fix (P0): public.trgfn_contributor_sports_check() — per-table NEW/OLD field access.
-- cto decision: dreq-0ca2aa6e.
--
-- WHAT: replaces the function body in place (CREATE OR REPLACE, same signature, same attributes:
--   RETURNS trigger, LANGUAGE plpgsql, SET search_path TO 'public','pg_temp', SECURITY INVOKER).
--   The only change is how v_pid is resolved: the DECLARE-time CASE is replaced by an IF/ELSIF
--   in the body. The sports rule and its exception text (contributor_sports_incomplete) are unchanged.
--
-- WHY: one function serves two constraint triggers (trg_contributor_sports_profiles on profiles,
--   trg_contributor_sports_sp on sport_profiles). The 20261026100000 version resolved
--   NEW.id / OLD.profile_id / NEW.profile_id inside one CASE expression, so PL/pgSQL fails with
--   `record "new" has no field "profile_id"` on a profiles row and `... no field "id"` on a
--   sport_profiles row. Both triggers are DEFERRABLE INITIALLY DEFERRED FOR EACH ROW, so every
--   profiles INSERT/UPDATE and sport_profiles INSERT/UPDATE/DELETE is at risk at COMMIT.
--   With IF/ELSIF each record field is referenced only in the branch for its own table.
--
-- SCOPE: this function only. No DROP, no trigger DDL, no data writes, no new grants.
--   CREATE OR REPLACE keeps the existing ACL ({postgres=X/postgres,service_role=X/postgres});
--   the REVOKE below re-asserts that PUBLIC/anon/authenticated hold nothing. service_role is untouched.

CREATE OR REPLACE FUNCTION public.trgfn_contributor_sports_check() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_pid uuid;
  p public.profiles%ROWTYPE;
BEGIN
  IF TG_TABLE_NAME = 'profiles' THEN
    v_pid := NEW.id;
  ELSIF TG_OP = 'DELETE' THEN
    v_pid := OLD.profile_id;
  ELSE
    v_pid := NEW.profile_id;
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

-- Trigger functions are not callable RPCs (matches KAN-527 / 20261026100000 section 6). No grant added.
REVOKE ALL ON FUNCTION public.trgfn_contributor_sports_check() FROM PUBLIC, anon, authenticated;

-- KAN-644 fix (P0) probes for public.trgfn_contributor_sports_check() (cto decision dreq-0ca2aa6e).
-- Run AFTER 20261027120000_kan644_fix_contributor_sports_check_branches.sql is applied, as postgres,
-- as ONE script. Everything runs in one transaction that ends in ROLLBACK: nothing persists.
-- The two constraint triggers are DEFERRABLE INITIALLY DEFERRED, so each case sets them IMMEDIATE
-- inside its own sub-block: the trigger fires at the end of each statement, inside the transaction,
-- and a failing case's writes AND its queued trigger events are discarded with that sub-block, so
-- one case cannot poison the next.
-- Output: one row per probe (ok true/false); the last statement raises if any probe failed.
-- Hook-safe: no drops, no auth-user writes, no commit, named column lists only. Fixture users are
-- existing auth users with NO profile (>= 5 needed; the DO block says so if fewer exist).
-- Fixture helpers are copied from supabase/tests/kan646_personas_s3/probes.sql (age = 30, real sport ids).
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);

CREATE FUNCTION pg_temp.chk(p_name text, p_cond boolean, p_detail text DEFAULT '') RETURNS void LANGUAGE sql AS $f$
  INSERT INTO _r VALUES (p_name, COALESCE(p_cond,false), p_detail) $f$;

CREATE TEMP TABLE _pool(id uuid, used boolean NOT NULL DEFAULT false);
INSERT INTO _pool(id) SELECT u.id FROM auth.users u WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = u.id) ORDER BY u.id LIMIT 10;
CREATE FUNCTION pg_temp.mk_user() RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  UPDATE _pool SET used = true WHERE id = (SELECT id FROM _pool WHERE NOT used ORDER BY id LIMIT 1) RETURNING id INTO v;
  IF v IS NULL THEN RAISE EXCEPTION 'kan644fix_probe_pool_exhausted: need more auth users without a profile'; END IF;
  RETURN v;
END $f$;
-- Contributor fixture, S2 order: profile (onboard=false) -> extension rows -> sport_profiles + Following -> onboard=true.
CREATE FUNCTION pg_temp.mk_contrib(p_user uuid, p_sport uuid, p_key text, p_player boolean DEFAULT true, p_org boolean DEFAULT true)
RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.profiles(user_id, profile_type, is_player, intention, username, display_name, age, persona_type,
                              onboarding_intention, primary_sport, preferred_sport, interests, onboard, is_active)
  VALUES (p_user, 'personal', true, 'player', 'probe_c_'||substr(md5(random()::text),1,12), 'Probe C', 30, 'contributor',
          'play_organise', p_sport, p_sport, ARRAY[p_sport], false, true)
  RETURNING id INTO v;
  IF p_player THEN INSERT INTO public.player(profile_id) VALUES (v); END IF;
  IF p_org THEN INSERT INTO public.organiser(profile_id, sport) VALUES (v, p_key); END IF;
  INSERT INTO public.sport_profiles(profile_id, sport, sport_id, skill_level) VALUES (v, p_key, p_sport, 1);
  UPDATE public.profiles SET onboard = true WHERE id = v;
  RETURN v;
END $f$;
CREATE FUNCTION pg_temp.mk_partner(p_user uuid, p_sport uuid, p_host boolean DEFAULT true)
RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.profiles(user_id, profile_type, is_player, intention, username, display_name, age, persona_type,
                              onboarding_intention, primary_sport, preferred_sport, interests, onboard, is_active)
  VALUES (p_user, 'venue', false, 'host', 'probe_p_'||substr(md5(random()::text),1,12), 'Probe P', 30, 'partner',
          'host_games', p_sport, p_sport, ARRAY[p_sport], false, true)
  RETURNING id INTO v;
  IF p_host THEN INSERT INTO public.host(profile_id) VALUES (v); END IF;
  UPDATE public.profiles SET onboard = true WHERE id = v;
  RETURN v;
END $f$;
CREATE FUNCTION pg_temp.mk_legacy(p_user uuid, p_persona text, p_sport uuid) RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO public.profiles(user_id, profile_type, username, display_name, age, persona_type, primary_sport, onboard, is_active)
  VALUES (p_user, CASE p_persona WHEN 'organiser' THEN 'business' WHEN 'host' THEN 'venue' ELSE 'personal' END,
          'probe_l_'||substr(md5(random()::text),1,12), 'Probe L', 30, p_persona, p_sport, true, true) RETURNING id $f$;

DO $$
DECLARE
  s1 uuid; k1 text; s2 uuid; k2 text;
  uA uuid; lA uuid; uB uuid; lB uuid; uC uuid; pC uuid; uD uuid; cD uuid; uE uuid; cE uuid;
BEGIN
  SELECT id, sport_key INTO s1, k1 FROM public.sports WHERE is_active ORDER BY sport_key LIMIT 1;
  SELECT id, sport_key INTO s2, k2 FROM public.sports WHERE is_active AND id <> s1 ORDER BY sport_key LIMIT 1;
  IF s2 IS NULL THEN RAISE EXCEPTION 'kan644fix_probe_precondition: need >= 2 active sports'; END IF;
  IF (SELECT count(*) FROM _pool) < 5 THEN RAISE EXCEPTION 'kan644fix_probe_pool_too_small: need >= 5 auth users without a profile, found %', (SELECT count(*) FROM _pool); END IF;

  -- Z catalogue: the fix is what is deployed ----------------------------------------------------------------
  PERFORM pg_temp.chk('Z1 deployed body is not the defective 20261026100000 body (md5 changed)',
    md5(pg_get_functiondef('public.trgfn_contributor_sports_check()'::regprocedure)) <> 'c9cb15016b1aecbda961d2c952306b98',
    md5(pg_get_functiondef('public.trgfn_contributor_sports_check()'::regprocedure)));
  PERFORM pg_temp.chk('Z2 deployed body has the per-table IF branch and no DECLARE-time CASE',
    (SELECT prosrc LIKE '%IF TG_TABLE_NAME = ''profiles'' THEN%' AND prosrc NOT LIKE '%CASE WHEN TG_TABLE_NAME%'
       FROM pg_proc WHERE oid = 'public.trgfn_contributor_sports_check()'::regprocedure));
  PERFORM pg_temp.chk('Z3 ACL unchanged: owner + service_role only',
    (SELECT proacl::text FROM pg_proc WHERE oid = 'public.trgfn_contributor_sports_check()'::regprocedure)
      = '{postgres=X/postgres,service_role=X/postgres}',
    (SELECT proacl::text FROM pg_proc WHERE oid = 'public.trgfn_contributor_sports_check()'::regprocedure));
  PERFORM pg_temp.chk('Z4 not executable by anon / authenticated',
    NOT has_function_privilege('anon', 'public.trgfn_contributor_sports_check()', 'EXECUTE')
    AND NOT has_function_privilege('authenticated', 'public.trgfn_contributor_sports_check()', 'EXECUTE'));
  PERFORM pg_temp.chk('Z5 attributes unchanged: plpgsql, invoker, search_path public, pg_temp',
    (SELECT l.lanname = 'plpgsql' AND NOT p.prosecdef AND p.proconfig = ARRAY['search_path=public, pg_temp']
       FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
      WHERE p.oid = 'public.trgfn_contributor_sports_check()'::regprocedure),
    (SELECT proconfig::text FROM pg_proc WHERE oid = 'public.trgfn_contributor_sports_check()'::regprocedure));
  PERFORM pg_temp.chk('Z6 both triggers still bound, deferrable initially deferred',
    (SELECT count(*) FROM pg_trigger t
      WHERE t.tgfoid = 'public.trgfn_contributor_sports_check()'::regprocedure
        AND t.tgname IN ('trg_contributor_sports_profiles','trg_contributor_sports_sp')
        AND t.tgdeferrable AND t.tginitdeferred) = 2);

  -- A: legacy player, profiles UPDATE ----------------------------------------------------------------------
  BEGIN
    SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp IMMEDIATE;
    uA := pg_temp.mk_user(); lA := pg_temp.mk_legacy(uA, 'player', s1);
    UPDATE public.profiles SET display_name = 'Probe L updated' WHERE id = lA;
    PERFORM pg_temp.chk('A1 legacy player profiles INSERT + UPDATE pass the immediate trigger', true);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('A1 legacy player profiles INSERT + UPDATE pass the immediate trigger', false, SQLERRM);
  END;
  SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp DEFERRED;

  -- B: legacy player, sport_profiles INSERT / UPDATE / DELETE ---------------------------------------------
  BEGIN
    SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp IMMEDIATE;
    uB := pg_temp.mk_user(); lB := pg_temp.mk_legacy(uB, 'player', s1);
    INSERT INTO public.sport_profiles(profile_id, sport, sport_id, skill_level) VALUES (lB, k1, s1, 1);
    PERFORM pg_temp.chk('B1 legacy player sport_profiles INSERT passes', true);
    UPDATE public.sport_profiles SET skill_level = 2 WHERE profile_id = lB AND sport_id = s1;
    PERFORM pg_temp.chk('B2 legacy player sport_profiles UPDATE passes', true);
    DELETE FROM public.sport_profiles WHERE profile_id = lB AND sport_id = s1;
    PERFORM pg_temp.chk('B3 legacy player sport_profiles DELETE passes (OLD branch)',
      NOT EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id = lB));
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('B0 legacy player sport_profiles INSERT/UPDATE/DELETE raised', false, SQLERRM);
  END;
  SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp DEFERRED;

  -- C: partner, profiles UPDATE ----------------------------------------------------------------------------
  BEGIN
    SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp IMMEDIATE;
    uC := pg_temp.mk_user(); pC := pg_temp.mk_partner(uC, s1);
    UPDATE public.profiles SET display_name = 'Probe P updated' WHERE id = pC;
    PERFORM pg_temp.chk('C1 partner profiles INSERT + onboard UPDATE + UPDATE pass', true);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('C1 partner profiles INSERT + onboard UPDATE + UPDATE pass', false, SQLERRM);
  END;
  SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp DEFERRED;

  -- D: onboarded contributor whose Following drops primary_sport -> contributor_sports_incomplete -----------
  BEGIN
    SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp IMMEDIATE;
    uD := pg_temp.mk_user(); cD := pg_temp.mk_contrib(uD, s1, k1);
    UPDATE public.profiles SET interests = ARRAY[s2] WHERE id = cD;   -- primary_sport s1 no longer in interests
    PERFORM pg_temp.chk('D1 contributor missing primary_sport in interests is refused', false, 'no error');
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.chk('D1 contributor missing primary_sport in interests is refused',
      SQLERRM LIKE '%contributor_sports_incomplete%', SQLERRM);
  END;
  SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp DEFERRED;

  -- E: complete contributor passes, including follow-up writes on both tables ------------------------------
  BEGIN
    SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp IMMEDIATE;
    uE := pg_temp.mk_user(); cE := pg_temp.mk_contrib(uE, s1, k1);
    PERFORM pg_temp.chk('E1 complete contributor is created and onboarded',
      (SELECT onboard AND interests @> ARRAY[primary_sport] FROM public.profiles WHERE id = cE)
      AND EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id = cE AND sport_id = s1));
    UPDATE public.profiles SET interests = ARRAY[s1, s2] WHERE id = cE;
    INSERT INTO public.sport_profiles(profile_id, sport, sport_id, skill_level) VALUES (cE, k2, s2, 1);
    UPDATE public.sport_profiles SET skill_level = 3 WHERE profile_id = cE AND sport_id = s2;
    DELETE FROM public.sport_profiles WHERE profile_id = cE AND sport_id = s2;
    PERFORM pg_temp.chk('E2 complete contributor profiles UPDATE + sport_profiles INSERT/UPDATE/DELETE pass', true);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('E0 complete contributor raised', false, SQLERRM);
  END;
  SET CONSTRAINTS trg_contributor_sports_profiles, trg_contributor_sports_sp DEFERRED;
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-644 fix probes FAILED: %', (SELECT string_agg(name,', ') FROM _r WHERE NOT ok); END IF; END $$;
ROLLBACK;

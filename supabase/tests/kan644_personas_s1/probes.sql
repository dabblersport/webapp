-- KAN-644 probes. Run AFTER the migration is applied, as postgres, in ONE transaction that ends in ROLLBACK
-- (nothing persists). Output: one row per probe, ok = true/false; the last statement raises if any probe failed.
-- Hook-clean by construction: no drops, no writes to the auth schema (fixture users are EXISTING auth users that
-- have no profile yet, picked read-only; every profile made for them lives only inside this transaction),
-- no bare star, no dynamic SQL (every probe is a static sub-block), no commit.
-- P9 (true concurrency) needs two sessions: see the manual block at the bottom.
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);
GRANT ALL ON _r TO authenticated;
CREATE POLICY kan644_probe_all ON public.profiles TO authenticated USING (true) WITH CHECK (true);

CREATE TEMP TABLE _pool(id uuid, used boolean NOT NULL DEFAULT false);
INSERT INTO _pool(id) SELECT u.id FROM auth.users u WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = u.id) ORDER BY u.id LIMIT 12;

CREATE FUNCTION pg_temp.mk_user() RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  UPDATE _pool SET used = true WHERE id = (SELECT id FROM _pool WHERE NOT used ORDER BY id LIMIT 1) RETURNING id INTO v;
  IF v IS NULL THEN RAISE EXCEPTION 'kan644_probe_pool_exhausted: need more auth users without a profile'; END IF;
  RETURN v;
END $f$;

CREATE FUNCTION pg_temp.mk_profile(p_user uuid, p_persona text, p_sport uuid, p_onboard boolean, p_active boolean DEFAULT true)
RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO public.profiles(user_id,profile_type,username,display_name,persona_type,primary_sport,onboard,is_active)
  VALUES (p_user,'personal','probe_'||substr(md5(random()::text),1,12),'Probe',p_persona,p_sport,p_onboard,p_active) RETURNING id $f$;

DO $$
DECLARE
  s1 uuid; s2 uuid;
  uc uuid := pg_temp.mk_user(); up uuid := pg_temp.mk_user(); ul uuid := pg_temp.mk_user();
  uh uuid := pg_temp.mk_user(); ui uuid := pg_temp.mk_user(); uz uuid := pg_temp.mk_user(); ua uuid := pg_temp.mk_user();
  pc uuid; pp uuid; pl uuid; ph uuid; pig uuid; legacy_before text;
BEGIN
  SELECT id INTO s1 FROM public.sports WHERE is_active ORDER BY sport_key LIMIT 1;
  SELECT id INTO s2 FROM public.sports WHERE is_active AND id <> s1 ORDER BY sport_key LIMIT 1;
  SELECT count(*)||md5(string_agg(p::text, '' ORDER BY id)) INTO legacy_before
    FROM public.profiles p WHERE persona_type IN ('player','organiser','host','socialiser') AND created_at < now();  -- now() = txn start: pre-existing rows only

  -- P1 value matrix
  pc := pg_temp.mk_profile(uc,'contributor',s1,false);
  BEGIN
    INSERT INTO public.profiles(user_id,profile_type,username,display_name,persona_type,primary_sport,onboard) VALUES (uz,'personal','probe_z','Probe','wizard',s1,false);
    INSERT INTO _r VALUES ('P1a unknown persona rejected', false, 'expected profiles_persona_type_check, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1a unknown persona rejected', SQLERRM LIKE '%profiles_persona_type_check%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention='nope' WHERE id=pc;
    INSERT INTO _r VALUES ('P1b bad intention key', false, 'expected profiles_onboarding_intention_values_check, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1b bad intention key', SQLERRM LIKE '%profiles_onboarding_intention_values_check%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention='host_games' WHERE id=pc;
    INSERT INTO _r VALUES ('P1c contributor+host_games rejected', false, 'expected profiles_onboarding_intention_persona_check, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1c contributor+host_games rejected', SQLERRM LIKE '%profiles_onboarding_intention_persona_check%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention='connect_play' WHERE id=pc;
    INSERT INTO _r VALUES ('P1d contributor connect_play ok', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1d contributor connect_play ok', false, SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention='play_organise' WHERE id=pc;
    INSERT INTO _r VALUES ('P1e contributor play_organise ok', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1e contributor play_organise ok', false, SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention='organise' WHERE id=pc;
    INSERT INTO _r VALUES ('P1f contributor organise ok', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1f contributor organise ok', false, SQLERRM);
  END;
  INSERT INTO _r VALUES ('P1g preference change does not change persona', COALESCE((SELECT persona_type FROM public.profiles WHERE id=pc) = 'contributor', false), '');
  pp := pg_temp.mk_profile(up,'partner',s1,false);
  BEGIN
    UPDATE public.profiles SET onboarding_intention='connect_play' WHERE id=pp;
    INSERT INTO _r VALUES ('P1h partner connect_play rejected', false, 'expected profiles_onboarding_intention_persona_check, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1h partner connect_play rejected', SQLERRM LIKE '%profiles_onboarding_intention_persona_check%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention='host_games' WHERE id=pp;
    INSERT INTO _r VALUES ('P1i partner host_games ok', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1i partner host_games ok', false, SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention=NULL, onboard=true WHERE id=pc;
    INSERT INTO _r VALUES ('P1j completed contributor w/o intention rejected', false, 'expected profiles_onboarding_intention_persona_check, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1j completed contributor w/o intention rejected', SQLERRM LIKE '%profiles_onboarding_intention_persona_check%', SQLERRM);
  END;
  pl := pg_temp.mk_profile(ul,'player',s1,true);
  BEGIN
    UPDATE public.profiles SET onboarding_intention='connect_play' WHERE id=pl;
    INSERT INTO _r VALUES ('P1k legacy player with intention rejected', false, 'expected profiles_onboarding_intention_persona_check, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P1k legacy player with intention rejected', SQLERRM LIKE '%profiles_onboarding_intention_persona_check%', SQLERRM);
  END;
  INSERT INTO _r VALUES ('P1l legacy player with NULL intention untouched', COALESCE(EXISTS (SELECT 1 FROM public.profiles WHERE id=pl AND onboarding_intention IS NULL), false), '');

  -- P2 extension ownership
  BEGIN
    INSERT INTO public.player(profile_id) VALUES (pc);
    INSERT INTO _r VALUES ('P2a contributor owns player row', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2a contributor owns player row', false, SQLERRM);
  END;
  BEGIN
    INSERT INTO public.organiser(profile_id,sport) VALUES (pc,(SELECT sport_key FROM public.sports WHERE id=s1));
    INSERT INTO _r VALUES ('P2b contributor owns organiser row (Primary sport key)', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2b contributor owns organiser row (Primary sport key)', false, SQLERRM);
  END;
  INSERT INTO _r VALUES ('P2c same profiles.id on both', COALESCE(EXISTS (SELECT 1 FROM public.player a JOIN public.organiser b USING (profile_id) WHERE a.profile_id=pc), false), '');
  BEGIN
    INSERT INTO public.player(profile_id) VALUES (pc);
    INSERT INTO _r VALUES ('P2d player uniqueness kept', false, 'expected player_profiles_profile_id_key, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2d player uniqueness kept', SQLERRM LIKE '%player_profiles_profile_id_key%', SQLERRM);
  END;
  BEGIN
    INSERT INTO public.organiser(profile_id,sport) VALUES (pc,(SELECT sport_key FROM public.sports WHERE id=s1));
    INSERT INTO _r VALUES ('P2e organiser (profile,sport) uniqueness kept', false, 'expected organiser_profiles_profile_sport_key, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2e organiser (profile,sport) uniqueness kept', SQLERRM LIKE '%organiser_profiles_profile_sport_key%', SQLERRM);
  END;
  BEGIN
    INSERT INTO public.host(profile_id) VALUES (pc);
    INSERT INTO _r VALUES ('P2f contributor cannot own host row', false, 'expected host.profile_id must reference, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2f contributor cannot own host row', SQLERRM LIKE '%host.profile_id must reference%', SQLERRM);
  END;
  BEGIN
    INSERT INTO public.host(profile_id) VALUES (pp);
    INSERT INTO _r VALUES ('P2g partner owns host row', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2g partner owns host row', false, SQLERRM);
  END;
  BEGIN
    INSERT INTO public.player(profile_id) VALUES (pp);
    INSERT INTO _r VALUES ('P2h partner cannot own player row', false, 'expected player.profile_id must reference, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2h partner cannot own player row', SQLERRM LIKE '%player.profile_id must reference%', SQLERRM);
  END;
  BEGIN
    INSERT INTO public.organiser(profile_id,sport) VALUES (pp,'x');
    INSERT INTO _r VALUES ('P2i partner cannot own organiser row', false, 'expected organiser.profile_id must reference, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2i partner cannot own organiser row', SQLERRM LIKE '%organiser.profile_id must reference%', SQLERRM);
  END;
  BEGIN
    INSERT INTO public.player(profile_id) VALUES (pl);
    INSERT INTO _r VALUES ('P2j legacy player still owns player row', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2j legacy player still owns player row', false, SQLERRM);
  END;
  BEGIN
    INSERT INTO public.organiser(profile_id,sport) VALUES (pl,'x');
    INSERT INTO _r VALUES ('P2k legacy player cannot own organiser row', false, 'expected organiser.profile_id must reference, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2k legacy player cannot own organiser row', SQLERRM LIKE '%organiser.profile_id must reference%', SQLERRM);
  END;
  ph := pg_temp.mk_profile(uh,'host',s1,true);
  BEGIN
    INSERT INTO public.host(profile_id) VALUES (ph);
    INSERT INTO _r VALUES ('P2l legacy host still owns host row', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P2l legacy host still owns host row', false, SQLERRM);
  END;

  -- P3 single-profile cardinality (inactive/historical rows included)
  BEGIN
    PERFORM pg_temp.mk_profile(uc,'contributor',s1,false,false);
    INSERT INTO _r VALUES ('P3a second row beside contributor rejected', false, 'expected single_profile_required, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3a second row beside contributor rejected', SQLERRM LIKE '%single_profile_required%', SQLERRM);
  END;
  BEGIN
    PERFORM pg_temp.mk_profile(uc,'partner',s1,false,false);
    INSERT INTO _r VALUES ('P3b inactive second row rejected', false, 'expected single_profile_required, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3b inactive second row rejected', SQLERRM LIKE '%single_profile_required%', SQLERRM);
  END;
  BEGIN
    PERFORM pg_temp.mk_profile(uc,'player',s1,true,false);
    INSERT INTO _r VALUES ('P3c legacy added beside contributor rejected', false, 'expected single_profile_required, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3c legacy added beside contributor rejected', SQLERRM LIKE '%single_profile_required%', SQLERRM);
  END;
  BEGIN
    PERFORM pg_temp.mk_profile(up,'organiser',s1,true,false);
    INSERT INTO _r VALUES ('P3d legacy added beside partner rejected', false, 'expected single_profile_required, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3d legacy added beside partner rejected', SQLERRM LIKE '%single_profile_required%', SQLERRM);
  END;
  -- legacy account with historical inactive rows: a new persona is refused, legacy rows untouched
  pig := pg_temp.mk_profile(ui,'player',s1,true,false);
  BEGIN
    PERFORM pg_temp.mk_profile(ui,'contributor',s1,false);
    INSERT INTO _r VALUES ('P3e unified beside inactive legacy row rejected', false, 'expected single_profile_required, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3e unified beside inactive legacy row rejected', SQLERRM LIKE '%single_profile_required%', SQLERRM);
  END;
  BEGIN
    PERFORM pg_temp.mk_profile(ui,'organiser',s1,true,true);
    INSERT INTO _r VALUES ('P3f legacy-only account may still add legacy (unchanged behaviour)', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3f legacy-only account may still add legacy (unchanged behaviour)', false, SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET persona_type='contributor' WHERE id=pl;
    INSERT INTO _r VALUES ('P3g legacy->contributor conversion of onboarded row rejected', false, 'expected persona_conversion_blocked, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3g legacy->contributor conversion of onboarded row rejected', SQLERRM LIKE '%persona_conversion_blocked%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET persona_type='player' WHERE id=pc;
    INSERT INTO _r VALUES ('P3h contributor->player downgrade rejected', false, 'expected persona_conversion_blocked, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3h contributor->player downgrade rejected', SQLERRM LIKE '%persona_conversion_blocked%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET persona_type='partner' WHERE id=pc;
    INSERT INTO _r VALUES ('P3i contributor->partner switch rejected', false, 'expected persona_conversion_blocked, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3i contributor->partner switch rejected', SQLERRM LIKE '%persona_conversion_blocked%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET user_id=ul WHERE id=pc;
    INSERT INTO _r VALUES ('P3j moving unified profile to another user rejected', false, 'expected single_profile_required, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P3j moving unified profile to another user rejected', SQLERRM LIKE '%single_profile_required%', SQLERRM);
  END;

  -- P4 direct client writes cannot bypass (role-based, not a GUC); RESET ROLE runs before the result row is written
  BEGIN
    SET LOCAL ROLE authenticated;
    INSERT INTO public.profiles(user_id,profile_type,username,display_name,persona_type,primary_sport,onboard) VALUES (ua,'personal','probe_a','Probe','contributor',s1,false);
    RESET ROLE;
    INSERT INTO _r VALUES ('P4a authenticated cannot create contributor', false, 'expected persona_write_via_rpc_only, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P4a authenticated cannot create contributor', SQLERRM LIKE '%persona_write_via_rpc_only%', SQLERRM);
  END;
  BEGIN
    SET LOCAL ROLE authenticated;
    UPDATE public.profiles SET onboarding_intention='organise' WHERE id=pc;
    RESET ROLE;
    INSERT INTO _r VALUES ('P4b authenticated cannot edit intention', false, 'expected persona_write_via_rpc_only, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P4b authenticated cannot edit intention', SQLERRM LIKE '%persona_write_via_rpc_only%', SQLERRM);
  END;
  BEGIN
    SET LOCAL ROLE authenticated;
    UPDATE public.profiles SET persona_type='player' WHERE id=pc;
    RESET ROLE;
    INSERT INTO _r VALUES ('P4c authenticated cannot edit unified persona', false, 'expected persona_write_via_rpc_only, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P4c authenticated cannot edit unified persona', SQLERRM LIKE '%persona_write_via_rpc_only%', SQLERRM);
  END;
  BEGIN
    SET LOCAL ROLE authenticated;
    UPDATE public.profiles SET persona_type='contributor' WHERE id=pl;
    RESET ROLE;
    INSERT INTO _r VALUES ('P4d authenticated cannot convert legacy', false, 'expected persona_conversion_blocked, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P4d authenticated cannot convert legacy', SQLERRM LIKE '%persona_conversion_blocked%', SQLERRM);
  END;
  BEGIN
    UPDATE public.profiles SET onboarding_intention='connect_play' WHERE id=pc;
    INSERT INTO _r VALUES ('P4e a SECURITY DEFINER-style (postgres) write is allowed', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P4e a SECURITY DEFINER-style (postgres) write is allowed', false, SQLERRM);
  END;

  -- P5 completed vs incomplete Contributor sports rules (checked at COMMIT; forced with SET CONSTRAINTS)
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    UPDATE public.profiles SET onboard=false WHERE id=pc;
    SET CONSTRAINTS ALL DEFERRED;
    INSERT INTO _r VALUES ('P5a incomplete contributor, no sports rows, passes', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5a incomplete contributor, no sports rows, passes', false, SQLERRM);
  END;
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    UPDATE public.profiles SET onboard=true WHERE id=pc;
    INSERT INTO _r VALUES ('P5b completing without Following/sport_profiles rejected', false, 'expected contributor_sports_incomplete, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5b completing without Following/sport_profiles rejected', SQLERRM LIKE '%contributor_sports_incomplete%', SQLERRM);
  END;
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    UPDATE public.profiles SET interests=ARRAY[s1]::uuid[], onboard=true WHERE id=pc;
    INSERT INTO _r VALUES ('P5c Following only (no sport_profiles) still rejected', false, 'expected contributor_sports_incomplete, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5c Following only (no sport_profiles) still rejected', SQLERRM LIKE '%contributor_sports_incomplete%', SQLERRM);
  END;
  INSERT INTO _r VALUES ('P5d Following alone created no stats row', COALESCE(NOT EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id=pc), false), '');
  BEGIN
    UPDATE public.profiles SET interests=ARRAY[s1]::uuid[] WHERE id=pc;
    INSERT INTO public.sport_profiles(profile_id,sport,sport_id,skill_level) VALUES (pc,(SELECT sport_key FROM public.sports WHERE id=s1),s1,1);
    SET CONSTRAINTS ALL IMMEDIATE;
    UPDATE public.profiles SET onboard=true WHERE id=pc;
    SET CONSTRAINTS ALL DEFERRED;
    INSERT INTO _r VALUES ('P5e Primary in Following + Primary sport_profiles, then complete: ok', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5e Primary in Following + Primary sport_profiles, then complete: ok', false, SQLERRM);
  END;
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    INSERT INTO public.sport_profiles(profile_id,sport,sport_id,skill_level) VALUES (pc,(SELECT sport_key FROM public.sports WHERE id=s2),s2,1);
    INSERT INTO _r VALUES ('P5f practicing outside Following rejected', false, 'expected contributor_sports_incomplete, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5f practicing outside Following rejected', SQLERRM LIKE '%contributor_sports_incomplete%', SQLERRM);
  END;
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    UPDATE public.profiles SET interests=ARRAY[s1,s2]::uuid[] WHERE id=pc;
    INSERT INTO _r VALUES ('P5g Following gains a second sport (no cap, no stats): ok', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5g Following gains a second sport (no cap, no stats): ok', false, SQLERRM);
  END;
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    UPDATE public.profiles SET interests=ARRAY[s2]::uuid[] WHERE id=pc;
    INSERT INTO _r VALUES ('P5h dropping Primary from Following rejected', false, 'expected contributor_sports_incomplete, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5h dropping Primary from Following rejected', SQLERRM LIKE '%contributor_sports_incomplete%', SQLERRM);
  END;
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    DELETE FROM public.sport_profiles WHERE profile_id=pc;
    INSERT INTO _r VALUES ('P5i deleting the Primary sport_profiles rejected', false, 'expected contributor_sports_incomplete, got success');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5i deleting the Primary sport_profiles rejected', SQLERRM LIKE '%contributor_sports_incomplete%', SQLERRM);
  END;
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    UPDATE public.profiles SET onboard=true, interests=NULL WHERE id IN (pp,pl);
    INSERT INTO _r VALUES ('P5j partner and legacy have no sports rule', true, 'ok');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('P5j partner and legacy have no sports rule', false, SQLERRM);
  END;

  -- P6 legacy rows unchanged
  INSERT INTO _r VALUES ('P6 no pre-existing legacy row changed (count+hash)', COALESCE((SELECT count(*)||md5(string_agg(p::text, '' ORDER BY id)) FROM public.profiles p WHERE persona_type IN ('player','organiser','host','socialiser') AND created_at < now()) IS NOT DISTINCT FROM legacy_before, false), '');
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-644 probes FAILED: %', (SELECT string_agg(name,', ') FROM _r WHERE NOT ok); END IF; END $$;
ROLLBACK;

-- Fixture users: the pool needs 7 existing auth users with no profile; mk_user() raises kan644_probe_pool_exhausted if fewer exist.
-- P9 concurrency (two psql sessions, then ROLLBACK both). Fixture: one user_id U with no profile rows.
--   S1: BEGIN; INSERT INTO public.profiles(... user_id=U, persona_type='contributor', onboard=false ...);   -- holds the user lock
--   S2: BEGIN; INSERT INTO public.profiles(... user_id=U, persona_type='partner',     onboard=false ...);   -- blocks
--   S1: COMMIT;   S2 then raises single_profile_required (it re-reads after the lock). Expect exactly 1 row for U.
--   Replay: re-running S1's INSERT in a new transaction raises single_profile_required.
-- Isolation note: the guard relies on READ COMMITTED (the Supabase default); it is not a SERIALIZABLE proof.

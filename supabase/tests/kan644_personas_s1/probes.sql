-- KAN-644 probes. Run AFTER the migration is applied, as postgres, in ONE transaction that ends in ROLLBACK
-- (nothing persists). Fixtures (auth.users, profiles, extensions) exist only inside it; no real row is read
-- or changed except SELECT sports ids. Output: one row per probe, ok = true/false; the last statement raises
-- if any probe failed. P9 (true concurrency) needs two sessions: see the manual block at the bottom.
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);
GRANT ALL ON _r TO authenticated;
CREATE POLICY kan644_probe_all ON public.profiles TO authenticated USING (true) WITH CHECK (true);

-- expect(name, sql, fragment): fragment NULL = must succeed; otherwise must fail with a message containing it.
CREATE FUNCTION pg_temp.expect(p_name text, p_sql text, p_msg text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    EXECUTE p_sql;
    INSERT INTO _r VALUES (p_name, p_msg IS NULL, CASE WHEN p_msg IS NULL THEN 'ok' ELSE 'expected '||p_msg||', got success' END);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (p_name, p_msg IS NOT NULL AND SQLERRM LIKE '%'||p_msg||'%', SQLERRM);
  END;
END $f$;

CREATE FUNCTION pg_temp.mk_user() RETURNS uuid LANGUAGE sql AS $f$
  WITH u AS (SELECT gen_random_uuid() id)
  INSERT INTO auth.users(id, instance_id, aud, role, email)
  SELECT id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated', id||'@probe.invalid' FROM u RETURNING id $f$;

CREATE FUNCTION pg_temp.mk_profile(p_user uuid, p_persona text, p_sport uuid, p_onboard boolean, p_active boolean DEFAULT true)
RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO public.profiles(user_id,profile_type,username,display_name,persona_type,primary_sport,onboard,is_active)
  VALUES (p_user,'personal','probe_'||substr(md5(random()::text),1,12),'Probe',p_persona,p_sport,p_onboard,p_active) RETURNING id $f$;

DO $$
DECLARE
  s1 uuid; s2 uuid; uc uuid := pg_temp.mk_user(); up uuid := pg_temp.mk_user(); ul uuid := pg_temp.mk_user();
  uh uuid := pg_temp.mk_user(); ui uuid := pg_temp.mk_user();
  pc uuid; pp uuid; pl uuid; ph uuid; pi uuid; legacy_before bigint; legacy_hash text;
BEGIN
  SELECT id INTO s1 FROM public.sports WHERE is_active ORDER BY sport_key LIMIT 1;
  SELECT id INTO s2 FROM public.sports WHERE is_active AND id <> s1 ORDER BY sport_key LIMIT 1;
  SELECT count(*), md5(string_agg(p::text, '' ORDER BY id)) INTO legacy_before, legacy_hash
    FROM public.profiles p WHERE persona_type IN ('player','organiser','host','socialiser') AND created_at < now();  -- now() = txn start: pre-existing rows only

  -- P1 value matrix -------------------------------------------------------------------------
  pc := pg_temp.mk_profile(uc,'contributor',s1,false);
  PERFORM pg_temp.expect('P1a unknown persona rejected',
    format('INSERT INTO public.profiles(user_id,profile_type,username,display_name,persona_type,primary_sport,onboard) VALUES (%L,''personal'',''probe_z'',''Probe'',''wizard'',%L,false)', pg_temp.mk_user(), s1),'profiles_persona_type_check');
  PERFORM pg_temp.expect('P1b bad intention key', format('UPDATE public.profiles SET onboarding_intention=''nope'' WHERE id=%L',pc),'profiles_onboarding_intention_values_check');
  PERFORM pg_temp.expect('P1c contributor+host_games rejected', format('UPDATE public.profiles SET onboarding_intention=''host_games'' WHERE id=%L',pc),'profiles_onboarding_intention_persona_check');
  PERFORM pg_temp.expect('P1d contributor connect_play ok', format('UPDATE public.profiles SET onboarding_intention=''connect_play'' WHERE id=%L',pc),NULL);
  PERFORM pg_temp.expect('P1e contributor play_organise ok', format('UPDATE public.profiles SET onboarding_intention=''play_organise'' WHERE id=%L',pc),NULL);
  PERFORM pg_temp.expect('P1f contributor organise ok', format('UPDATE public.profiles SET onboarding_intention=''organise'' WHERE id=%L',pc),NULL);
  PERFORM pg_temp.expect('P1g preference change does not change persona',
    format('DO $x$ BEGIN IF (SELECT persona_type FROM public.profiles WHERE id=%L)<>''contributor'' THEN RAISE EXCEPTION ''persona changed''; END IF; END $x$',pc),NULL);
  pp := pg_temp.mk_profile(up,'partner',s1,false);
  PERFORM pg_temp.expect('P1h partner connect_play rejected', format('UPDATE public.profiles SET onboarding_intention=''connect_play'' WHERE id=%L',pp),'profiles_onboarding_intention_persona_check');
  PERFORM pg_temp.expect('P1i partner host_games ok', format('UPDATE public.profiles SET onboarding_intention=''host_games'' WHERE id=%L',pp),NULL);
  PERFORM pg_temp.expect('P1j completed contributor w/o intention rejected', format('UPDATE public.profiles SET onboarding_intention=NULL, onboard=true WHERE id=%L',pc),'profiles_onboarding_intention_persona_check');
  pl := pg_temp.mk_profile(ul,'player',s1,true);
  PERFORM pg_temp.expect('P1k legacy player with intention rejected', format('UPDATE public.profiles SET onboarding_intention=''connect_play'' WHERE id=%L',pl),'profiles_onboarding_intention_persona_check');
  PERFORM pg_temp.expect('P1l legacy player with NULL intention untouched', format('SELECT 1 FROM public.profiles WHERE id=%L AND onboarding_intention IS NULL',pl),NULL);

  -- P2 extension ownership -------------------------------------------------------------------
  PERFORM pg_temp.expect('P2a contributor owns player row', format('INSERT INTO public.player(profile_id) VALUES (%L)',pc),NULL);
  PERFORM pg_temp.expect('P2b contributor owns organiser row (Primary sport key)',
    format('INSERT INTO public.organiser(profile_id,sport) VALUES (%L,(SELECT sport_key FROM public.sports WHERE id=%L))',pc,s1),NULL);
  PERFORM pg_temp.expect('P2c same profiles.id on both', format('SELECT 1 FROM public.player a JOIN public.organiser b USING (profile_id) WHERE a.profile_id=%L',pc),NULL);
  PERFORM pg_temp.expect('P2d player uniqueness kept', format('INSERT INTO public.player(profile_id) VALUES (%L)',pc),'player_profiles_profile_id_key');
  PERFORM pg_temp.expect('P2e organiser (profile,sport) uniqueness kept',
    format('INSERT INTO public.organiser(profile_id,sport) VALUES (%L,(SELECT sport_key FROM public.sports WHERE id=%L))',pc,s1),'organiser_profiles_profile_sport_key');
  PERFORM pg_temp.expect('P2f contributor cannot own host row', format('INSERT INTO public.host(profile_id) VALUES (%L)',pc),'host.profile_id must reference');
  PERFORM pg_temp.expect('P2g partner owns host row', format('INSERT INTO public.host(profile_id) VALUES (%L)',pp),NULL);
  PERFORM pg_temp.expect('P2h partner cannot own player row', format('INSERT INTO public.player(profile_id) VALUES (%L)',pp),'player.profile_id must reference');
  PERFORM pg_temp.expect('P2i partner cannot own organiser row', format('INSERT INTO public.organiser(profile_id,sport) VALUES (%L,''x'')',pp),'organiser.profile_id must reference');
  PERFORM pg_temp.expect('P2j legacy player still owns player row', format('INSERT INTO public.player(profile_id) VALUES (%L)',pl),NULL);
  PERFORM pg_temp.expect('P2k legacy player cannot own organiser row', format('INSERT INTO public.organiser(profile_id,sport) VALUES (%L,''x'')',pl),'organiser.profile_id must reference');
  ph := pg_temp.mk_profile(uh,'host',s1,true);
  PERFORM pg_temp.expect('P2l legacy host still owns host row', format('INSERT INTO public.host(profile_id) VALUES (%L)',ph),NULL);

  -- P3 single-profile cardinality (inactive/historical rows included) ------------------------
  PERFORM pg_temp.expect('P3a second row beside contributor rejected', format('SELECT pg_temp.mk_profile(%L,''contributor'',%L,false,false)',uc,s1),'single_profile_required');
  PERFORM pg_temp.expect('P3b inactive second row rejected',          format('SELECT pg_temp.mk_profile(%L,''partner'',%L,false,false)',uc,s1),'single_profile_required');
  PERFORM pg_temp.expect('P3c legacy added beside contributor rejected', format('SELECT pg_temp.mk_profile(%L,''player'',%L,true,false)',uc,s1),'single_profile_required');
  PERFORM pg_temp.expect('P3d legacy added beside partner rejected', format('SELECT pg_temp.mk_profile(%L,''organiser'',%L,true,false)',up,s1),'single_profile_required');
  -- legacy account with historical inactive rows: a new persona is refused, legacy rows untouched
  pi := pg_temp.mk_profile(ui,'player',s1,true,false);
  PERFORM pg_temp.expect('P3e unified beside inactive legacy row rejected', format('SELECT pg_temp.mk_profile(%L,''contributor'',%L,false)',ui,s1),'single_profile_required');
  PERFORM pg_temp.expect('P3f legacy-only account may still add legacy (unchanged behaviour)', format('SELECT pg_temp.mk_profile(%L,''organiser'',%L,true,true)',ui,s1),NULL);
  PERFORM pg_temp.expect('P3g legacy->contributor conversion of onboarded row rejected', format('UPDATE public.profiles SET persona_type=''contributor'' WHERE id=%L',pl),'persona_conversion_blocked');
  PERFORM pg_temp.expect('P3h contributor->player downgrade rejected', format('UPDATE public.profiles SET persona_type=''player'' WHERE id=%L',pc),'persona_conversion_blocked');
  PERFORM pg_temp.expect('P3i contributor->partner switch rejected', format('UPDATE public.profiles SET persona_type=''partner'' WHERE id=%L',pc),'persona_conversion_blocked');
  PERFORM pg_temp.expect('P3j moving unified profile to another user rejected', format('UPDATE public.profiles SET user_id=%L WHERE id=%L',ul,pc),'single_profile_required');

  -- P4 direct client writes cannot bypass (role-based, not a GUC) -----------------------------
  PERFORM pg_temp.expect('P4a authenticated cannot create contributor',
    format('SET LOCAL ROLE authenticated; INSERT INTO public.profiles(user_id,profile_type,username,display_name,persona_type,primary_sport,onboard) VALUES (%L,''personal'',''probe_a'',''Probe'',''contributor'',%L,false)',pg_temp.mk_user(),s1),'persona_write_via_rpc_only');
  PERFORM pg_temp.expect('P4b authenticated cannot edit intention', format('SET LOCAL ROLE authenticated; UPDATE public.profiles SET onboarding_intention=''organise'' WHERE id=%L',pc),'persona_write_via_rpc_only');
  PERFORM pg_temp.expect('P4c authenticated cannot edit unified persona', format('SET LOCAL ROLE authenticated; UPDATE public.profiles SET persona_type=''player'' WHERE id=%L',pc),'persona_write_via_rpc_only');
  PERFORM pg_temp.expect('P4d authenticated cannot convert legacy', format('SET LOCAL ROLE authenticated; UPDATE public.profiles SET persona_type=''contributor'' WHERE id=%L',pl),'persona_conversion_blocked');
  PERFORM pg_temp.expect('P4e a SECURITY DEFINER-style (postgres) write is allowed', format('UPDATE public.profiles SET onboarding_intention=''connect_play'' WHERE id=%L',pc),NULL);

  -- P5 completed vs incomplete Contributor sports rules (checked at COMMIT; forced with SET CONSTRAINTS) ----
  -- incomplete (onboard=false): anything goes
  PERFORM pg_temp.expect('P5a incomplete contributor, no sports rows, passes',
    format('SET CONSTRAINTS ALL IMMEDIATE; UPDATE public.profiles SET onboard=false WHERE id=%L; SET CONSTRAINTS ALL DEFERRED',pc),NULL);
  PERFORM pg_temp.expect('P5b completing without Following/sport_profiles rejected',
    format('SET CONSTRAINTS ALL IMMEDIATE; UPDATE public.profiles SET onboard=true WHERE id=%L',pc),'contributor_sports_incomplete');
  PERFORM pg_temp.expect('P5c Following only (no sport_profiles) still rejected',
    format('SET CONSTRAINTS ALL IMMEDIATE; UPDATE public.profiles SET interests=ARRAY[%L]::uuid[], onboard=true WHERE id=%L',s1,pc),'contributor_sports_incomplete');
  PERFORM pg_temp.expect('P5d Following alone created no stats row', format('DO $x$ BEGIN IF EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id=%L) THEN RAISE EXCEPTION ''stats row appeared''; END IF; END $x$',pc),NULL);
  PERFORM pg_temp.expect('P5e Primary in Following + Primary sport_profiles, then complete: ok',
    format('UPDATE public.profiles SET interests=ARRAY[%L]::uuid[] WHERE id=%L; INSERT INTO public.sport_profiles(profile_id,sport,sport_id,skill_level) VALUES (%L,(SELECT sport_key FROM public.sports WHERE id=%L),%L,1); SET CONSTRAINTS ALL IMMEDIATE; UPDATE public.profiles SET onboard=true WHERE id=%L; SET CONSTRAINTS ALL DEFERRED',s1,pc,pc,s1,s1,pc),NULL);
  PERFORM pg_temp.expect('P5f practicing outside Following rejected',
    format('SET CONSTRAINTS ALL IMMEDIATE; INSERT INTO public.sport_profiles(profile_id,sport,sport_id,skill_level) VALUES (%L,(SELECT sport_key FROM public.sports WHERE id=%L),%L,1)',pc,s2,s2),'contributor_sports_incomplete');
  PERFORM pg_temp.expect('P5g Following gains a second sport (no cap, no stats): ok',
    format('SET CONSTRAINTS ALL IMMEDIATE; UPDATE public.profiles SET interests=ARRAY[%L,%L]::uuid[] WHERE id=%L',s1,s2,pc),NULL);
  PERFORM pg_temp.expect('P5h dropping Primary from Following rejected',
    format('SET CONSTRAINTS ALL IMMEDIATE; UPDATE public.profiles SET interests=ARRAY[%L]::uuid[] WHERE id=%L',s2,pc),'contributor_sports_incomplete');
  PERFORM pg_temp.expect('P5i deleting the Primary sport_profiles rejected',
    format('SET CONSTRAINTS ALL IMMEDIATE; DELETE FROM public.sport_profiles WHERE profile_id=%L',pc),'contributor_sports_incomplete');
  PERFORM pg_temp.expect('P5j partner and legacy have no sports rule',
    format('SET CONSTRAINTS ALL IMMEDIATE; UPDATE public.profiles SET onboard=true, interests=NULL WHERE id IN (%L,%L)',pp,pl),NULL);

  -- P6 legacy rows unchanged -------------------------------------------------------------------
  PERFORM pg_temp.expect('P6 no pre-existing legacy row changed (count+hash)',
    format('DO $x$ BEGIN IF (SELECT count(*)||md5(string_agg(p::text, '''' ORDER BY id)) FROM public.profiles p WHERE persona_type IN (''player'',''organiser'',''host'',''socialiser'') AND created_at < now()) IS DISTINCT FROM %L THEN RAISE EXCEPTION ''legacy rows changed''; END IF; END $x$', legacy_before||legacy_hash),NULL);
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-644 probes FAILED: %', (SELECT string_agg(name,', ') FROM _r WHERE NOT ok); END IF; END $$;
ROLLBACK;

-- P9 concurrency (two psql sessions, then ROLLBACK both). Fixture: one user_id U with no profile rows.
--   S1: BEGIN; INSERT INTO public.profiles(... user_id=U, persona_type='contributor', onboard=false ...);   -- holds the user lock
--   S2: BEGIN; INSERT INTO public.profiles(... user_id=U, persona_type='partner',     onboard=false ...);   -- blocks
--   S1: COMMIT;   S2 then raises single_profile_required (it re-reads after the lock). Expect exactly 1 row for U.
--   Replay: re-running S1's INSERT in a new transaction raises single_profile_required.
-- Isolation note: the guard relies on READ COMMITTED (the Supabase default); it is not a SERIALIZABLE proof.

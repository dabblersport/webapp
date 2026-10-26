-- KAN-645 probes. Run AFTER KAN-644 and 20261026110000_kan645_rpc_onboard_unified_profile.sql are applied,
-- as postgres, in ONE transaction that ends in ROLLBACK (nothing persists; fixtures live only inside it).
-- Output: one row per probe (ok true/false); the last statement raises if any probe failed.
-- Hook-safe: no drops, no auth-user inserts, no commit. Fixture users = existing auth users with no profile (>= 20 needed; the DO block
-- says so if fewer exist). Two-session concurrency (P-C) is NOT run here: manual block at the bottom.
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);

-- expect(name, sql, fragment): fragment NULL = must succeed; otherwise must fail with a message containing it ('' = any failure).
CREATE FUNCTION pg_temp.expect(p_name text, p_sql text, p_msg text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    EXECUTE p_sql;
    INSERT INTO _r VALUES (p_name, p_msg IS NULL, CASE WHEN p_msg IS NULL THEN 'ok' ELSE 'expected '||p_msg||', got success' END);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES (p_name, p_msg IS NOT NULL AND SQLERRM LIKE '%'||p_msg||'%', SQLERRM);
  END;
END $f$;
CREATE FUNCTION pg_temp.chk(p_name text, p_cond boolean, p_detail text DEFAULT '') RETURNS void LANGUAGE sql AS $f$
  INSERT INTO _r VALUES (p_name, COALESCE(p_cond,false), p_detail) $f$;

-- No auth.users insert: fixture users are existing auth users that have NO profile yet (read-only pick of ids).
-- Every profile created for them lives only inside this transaction and is rolled back.
CREATE TEMP TABLE _pool(id uuid, used boolean NOT NULL DEFAULT false);
INSERT INTO _pool(id) SELECT u.id FROM auth.users u WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = u.id) ORDER BY u.id LIMIT 40;
CREATE FUNCTION pg_temp.mk_user() RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  UPDATE _pool SET used = true WHERE id = (SELECT id FROM _pool WHERE NOT used ORDER BY id LIMIT 1) RETURNING id INTO v;
  IF v IS NULL THEN RAISE EXCEPTION 'kan645_probe_pool_exhausted: need more auth users without a profile'; END IF;
  RETURN v;
END $f$;
CREATE FUNCTION pg_temp.as_user(p_user uuid) RETURNS void LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', json_build_object('sub', p_user, 'role','authenticated')::text, true),
         set_config('request.jwt.claim.sub', COALESCE(p_user::text,''), true) $f$;
CREATE FUNCTION pg_temp.mk_profile(p_user uuid, p_persona text, p_sport uuid, p_onboard boolean, p_active boolean DEFAULT true)
RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO public.profiles(user_id,profile_type,username,display_name,persona_type,primary_sport,onboard,is_active)
  VALUES (p_user,'personal','probe_'||substr(md5(random()::text),1,12),'Probe',p_persona,p_sport,p_onboard,p_active) RETURNING id $f$;
-- call(user, intention, username, sport, interests): runs the RPC as that user
CREATE FUNCTION pg_temp.call(p_user uuid, p_int text, p_un text, p_sport uuid, p_interests uuid[] DEFAULT NULL, p_name text DEFAULT 'Probe Name')
RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  PERFORM pg_temp.as_user(p_user);
  v := public.rpc_onboard_unified_profile(p_user, p_name, p_un, 25, 'male', p_int, p_sport, p_interests, NULL, 'Probe City');
  RETURN v;
END $f$;
-- forced-failure triggers (rolled back with the transaction). Inert unless the transaction-local setting
-- kan645.fail_on names the table they fire on; nothing has to be removed, the setting is just cleared.
CREATE FUNCTION public.kan645_probe_fail() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN
  IF current_setting('kan645.fail_on', true) = TG_TABLE_NAME THEN RAISE EXCEPTION 'kan645_forced_failure'; END IF;
  RETURN NEW;
END $f$;
CREATE TRIGGER kan645_force BEFORE INSERT ON public.player FOR EACH ROW EXECUTE FUNCTION public.kan645_probe_fail();
CREATE TRIGGER kan645_force BEFORE INSERT ON public.organiser FOR EACH ROW EXECUTE FUNCTION public.kan645_probe_fail();
CREATE TRIGGER kan645_force BEFORE INSERT ON public.sport_profiles FOR EACH ROW EXECUTE FUNCTION public.kan645_probe_fail();
CREATE TRIGGER kan645_force BEFORE INSERT ON public.host FOR EACH ROW EXECUTE FUNCTION public.kan645_probe_fail();
CREATE TRIGGER kan645_force BEFORE INSERT ON public.profile_tiers FOR EACH ROW EXECUTE FUNCTION public.kan645_probe_fail();
CREATE TRIGGER kan645_force BEFORE UPDATE OF onboard ON public.profiles FOR EACH ROW WHEN (NEW.onboard) EXECUTE FUNCTION public.kan645_probe_fail();

DO $$
DECLARE
  s1 uuid; s2 uuid; s3 uuid; k1 text;
  u uuid; v uuid; v2 uuid; i int; r record; tier text;
  ints text[] := ARRAY['connect_play','play_organise','organise','host_games'];
  tbls text[] := ARRAY['player','organiser','sport_profiles','host','profile_tiers'];
  t text; legacy_before text;
BEGIN
  SELECT id, sport_key INTO s1, k1 FROM public.sports WHERE is_active ORDER BY sport_key LIMIT 1;
  SELECT id INTO s2 FROM public.sports WHERE is_active AND id <> s1 ORDER BY sport_key LIMIT 1;
  SELECT id INTO s3 FROM public.sports WHERE is_active AND id NOT IN (s1,s2) ORDER BY sport_key LIMIT 1;
  IF (SELECT count(*) FROM _pool) < 20 THEN RAISE EXCEPTION 'kan645_probe_pool_too_small: need >= 20 auth users without a profile, found %', (SELECT count(*) FROM _pool); END IF;
  SELECT code INTO tier FROM public.tiers WHERE is_default LIMIT 1;
  SELECT count(*)||md5(string_agg(p::text,'' ORDER BY id)) INTO legacy_before FROM public.profiles p
    WHERE persona_type IN ('player','organiser','host','socialiser') AND created_at < now();

  -- P1 the four intentions: persona, intention, carriers, record set, defaults -----------------------
  FOR i IN 1..4 LOOP
    u := pg_temp.mk_user();
    v := pg_temp.call(u, ints[i], 'probe_p1_'||i||substr(md5(random()::text),1,6), s1, CASE WHEN i < 4 THEN ARRAY[s2,s3] ELSE NULL END);
    SELECT persona_type, onboarding_intention, onboard, is_active, primary_sport, preferred_sport, profile_type, is_player, intention, interests INTO r FROM public.profiles WHERE id = v;
    PERFORM pg_temp.chk('P1.'||i||' persona/intention/onboard', r.persona_type = CASE WHEN i<4 THEN 'contributor' ELSE 'partner' END
      AND r.onboarding_intention = ints[i] AND r.onboard AND r.is_active AND r.primary_sport = s1 AND r.preferred_sport = s1, ints[i]);
    PERFORM pg_temp.chk('P1.'||i||' exactly one profile row', (SELECT count(*) FROM public.profiles WHERE user_id=u) = 1);
    PERFORM pg_temp.chk('P1.'||i||' legacy carriers', (r.profile_type, r.is_player, r.intention) IS NOT DISTINCT FROM
      CASE WHEN i<4 THEN ROW('personal',true,'player') ELSE ROW('venue',false,'host') END, r.profile_type||'/'||r.is_player||'/'||r.intention);
    IF i < 4 THEN
      PERFORM pg_temp.chk('P1.'||i||' player+organiser on SAME profile id, organiser.sport=Primary key',
        (SELECT count(*) FROM public.player WHERE profile_id=v)=1 AND (SELECT count(*) FROM public.organiser WHERE profile_id=v AND sport=k1)=1
        AND (SELECT count(*) FROM public.organiser WHERE profile_id=v)=1);
      PERFORM pg_temp.chk('P1.'||i||' Primary sport_profiles row, skill 1, and ONLY that (Following-only sports get none)',
        (SELECT count(*) FROM public.sport_profiles WHERE profile_id=v)=1
        AND EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id=v AND sport_id=s1 AND sport=k1 AND skill_level=1));
      PERFORM pg_temp.chk('P1.'||i||' Following = Primary + extras, Primary first, distinct', r.interests = ARRAY[s1,s2,s3], r.interests::text);
      PERFORM pg_temp.chk('P1.'||i||' no host row', NOT EXISTS (SELECT 1 FROM public.host WHERE profile_id=v));
    ELSE
      PERFORM pg_temp.chk('P1.4 partner: host row with defaults, nothing else',
        EXISTS (SELECT 1 FROM public.host WHERE profile_id=v AND host_status='pending' AND verification_status IS NULL AND venues_managed=0 AND NOT is_suspended)
        AND NOT EXISTS (SELECT 1 FROM public.player WHERE profile_id=v) AND NOT EXISTS (SELECT 1 FROM public.organiser WHERE profile_id=v)
        AND NOT EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id=v));
    END IF;
    PERFORM pg_temp.chk('P1.'||i||' default tier only', tier IS NULL OR (SELECT count(*) FROM public.profile_tiers WHERE profile_id=v)=1
      AND EXISTS (SELECT 1 FROM public.profile_tiers WHERE profile_id=v AND tier_code=tier AND is_active));
    PERFORM pg_temp.chk('P1.'||i||' no organiser verification/commission escalation', i=4 OR NOT EXISTS
      (SELECT 1 FROM public.organiser WHERE profile_id=v AND (is_verified OR commission_value<>0 OR commission_type<>'percent' OR organiser_level<>1)));
  END LOOP;
  -- Following dedupe / Primary included even when omitted
  u := pg_temp.mk_user();
  v := pg_temp.call(u,'connect_play','probe_dd'||substr(md5(random()::text),1,6), s1, ARRAY[s2,s2,s1]);
  PERFORM pg_temp.chk('P1d Following distinct and includes Primary', (SELECT interests FROM public.profiles WHERE id=v) = ARRAY[s1,s2]);

  -- P2 inputs: each bad call fails with its code and leaves nothing behind ---------------------------
  u := pg_temp.mk_user();
  PERFORM pg_temp.as_user(u);
  PERFORM pg_temp.expect('P2a NULL intention', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2a'',25,''male'',NULL,%L)',u,s1),'invalid_onboarding_intention');
  PERFORM pg_temp.expect('P2b unknown intention', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2b'',25,''male'',''wizard'',%L)',u,s1),'invalid_onboarding_intention');
  PERFORM pg_temp.expect('P2c persona name is not an intention', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2c'',25,''male'',''contributor'',%L)',u,s1),'invalid_onboarding_intention');
  PERFORM pg_temp.expect('P2d legacy persona name is not an intention', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2d'',25,''male'',''player'',%L)',u,s1),'invalid_onboarding_intention');
  PERFORM pg_temp.expect('P2e other user id (IDOR)', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2e'',25,''male'',''connect_play'',%L)',pg_temp.mk_user(),s1),'access_denied');
  PERFORM pg_temp.expect('P2f NULL user id', format('SELECT public.rpc_onboard_unified_profile(NULL,''Probe'',''p2f'',25,''male'',''connect_play'',%L)',s1),'access_denied');
  PERFORM pg_temp.expect('P2g unknown sport', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2g'',25,''male'',''connect_play'',%L)',u,gen_random_uuid()),'invalid_sport');
  PERFORM pg_temp.expect('P2h missing Primary (contributor)', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2h'',25,''male'',''organise'')',u),'primary_sport_required');
  PERFORM pg_temp.expect('P2i missing Primary (partner)', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2i'',25,''male'',''host_games'')',u),'primary_sport_required');
  PERFORM pg_temp.expect('P2j unknown Following sport', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2j'',25,''male'',''connect_play'',%L,ARRAY[%L]::uuid[])',u,s1,gen_random_uuid()),'invalid_sport');
  PERFORM pg_temp.expect('P2k NULL element in Following', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2k'',25,''male'',''connect_play'',%L,ARRAY[NULL]::uuid[])',u,s1),'invalid_interests');
  PERFORM pg_temp.expect('P2l age below range', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2l'',5,''male'',''connect_play'',%L)',u,s1),'invalid_age');
  PERFORM pg_temp.expect('P2m display name too short', format('SELECT public.rpc_onboard_unified_profile(%L,''x'',''p2m'',25,''male'',''connect_play'',%L)',u,s1),'invalid_display_name');
  PERFORM pg_temp.expect('P2n username charset', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''bad name'',25,''male'',''connect_play'',%L)',u,s1),'invalid_username');
  PERFORM pg_temp.expect('P2o gender', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2o'',25,''robot'',''connect_play'',%L)',u,s1),'invalid_gender');
  PERFORM pg_temp.expect('P2p country', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2p'',25,''male'',''connect_play'',%L,NULL,''ZZZ'')',u,s1),'invalid_country');
  PERFORM set_config('request.jwt.claims','',true); PERFORM set_config('request.jwt.claim.sub','',true);
  PERFORM pg_temp.expect('P2q no auth context', format('SELECT public.rpc_onboard_unified_profile(%L,''Probe'',''p2q'',25,''male'',''connect_play'',%L)',u,s1),'access_denied');
  PERFORM pg_temp.chk('P2z nothing was created by any rejected call', NOT EXISTS (SELECT 1 FROM public.profiles WHERE user_id=u));

  -- P3 completed retry: same id, nothing reset/overwritten, stats preserved --------------------------
  u := pg_temp.mk_user();
  v := pg_temp.call(u,'connect_play','probe_p3'||substr(md5(random()::text),1,6), s1, ARRAY[s2]);
  UPDATE public.sport_profiles SET skill_level=4, xp_total=500 WHERE profile_id=v;
  UPDATE public.player SET player_xp_total=77, player_level=3 WHERE profile_id=v;
  UPDATE public.organiser SET organiser_level=3 WHERE profile_id=v;
  v2 := pg_temp.call(u,'organise','probe_other', s2, ARRAY[s3], 'Changed Name');
  PERFORM pg_temp.chk('P3a retry returns same id', v2 = v);
  PERFORM pg_temp.chk('P3b stored intention and identity not overwritten',
    EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND onboarding_intention='connect_play' AND display_name='Probe Name' AND primary_sport=s1 AND interests=ARRAY[s1,s2]));
  PERFORM pg_temp.chk('P3c earned stats preserved, no duplicates',
    EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id=v AND skill_level=4 AND xp_total=500) AND (SELECT count(*) FROM public.sport_profiles WHERE profile_id=v)=1
    AND EXISTS (SELECT 1 FROM public.player WHERE profile_id=v AND player_xp_total=77 AND player_level=3)
    AND EXISTS (SELECT 1 FROM public.organiser WHERE profile_id=v AND organiser_level=3) AND (SELECT count(*) FROM public.organiser WHERE profile_id=v)=1);
  PERFORM pg_temp.chk('P3d tier rows not duplicated', tier IS NULL OR (SELECT count(*) FROM public.profile_tiers WHERE profile_id=v)=1);
  PERFORM pg_temp.expect('P3e contributor cannot become partner by retry', format('SELECT pg_temp.call(%L,''host_games'',''p3e'',%L)',u,s1),'persona_change_not_supported');
  u := pg_temp.mk_user();
  v := pg_temp.call(u,'host_games','probe_p3f'||substr(md5(random()::text),1,6), s1);
  PERFORM pg_temp.expect('P3f partner cannot become contributor by retry', format('SELECT pg_temp.call(%L,''connect_play'',''p3f'',%L)',u,s1),'persona_change_not_supported');
  PERFORM pg_temp.chk('P3g partner retry same id and unchanged', pg_temp.call(u,'host_games','probe_p3g',s1) = v
    AND (SELECT count(*) FROM public.host WHERE profile_id=v)=1);

  -- P4 incomplete unified row resumes without changing persona ---------------------------------------
  u := pg_temp.mk_user();
  v := pg_temp.mk_profile(u,'contributor',s1,false);
  v2 := pg_temp.call(u,'play_organise','probe_p4'||substr(md5(random()::text),1,6), s1);
  PERFORM pg_temp.chk('P4a resumed same row, persona kept, intention set, now complete, full record set',
    v2 = v AND EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND persona_type='contributor' AND onboarding_intention='play_organise' AND onboard)
    AND EXISTS (SELECT 1 FROM public.player WHERE profile_id=v) AND EXISTS (SELECT 1 FROM public.organiser WHERE profile_id=v)
    AND EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id=v AND sport_id=s1));
  u := pg_temp.mk_user();
  v := pg_temp.mk_profile(u,'contributor',s1,false);
  PERFORM pg_temp.expect('P4b incomplete contributor + host_games = persona change', format('SELECT pg_temp.call(%L,''host_games'',''p4b'',%L)',u,s1),'persona_change_not_supported');
  PERFORM pg_temp.chk('P4c incomplete row left as it was', EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND persona_type='contributor' AND NOT onboard AND onboarding_intention IS NULL));

  -- P5 legacy / multiple rows: refused, untouched ----------------------------------------------------
  u := pg_temp.mk_user();
  v := pg_temp.mk_profile(u,'player',s1,true);
  PERFORM pg_temp.expect('P5a legacy profile', format('SELECT pg_temp.call(%L,''connect_play'',''p5a'',%L)',u,s1),'legacy_profile_requires_existing_flow');
  PERFORM pg_temp.chk('P5b legacy row untouched, no extension created', EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND persona_type='player' AND onboarding_intention IS NULL)
    AND (SELECT count(*) FROM public.profiles WHERE user_id=u)=1 AND NOT EXISTS (SELECT 1 FROM public.organiser WHERE profile_id=v));
  u := pg_temp.mk_user();
  PERFORM pg_temp.mk_profile(u,'player',s1,true,false);
  PERFORM pg_temp.mk_profile(u,'organiser',s1,true,true);
  PERFORM pg_temp.expect('P5c multiple (incl. inactive) rows', format('SELECT pg_temp.call(%L,''connect_play'',''p5c'',%L)',u,s1),'profile_migration_required');
  PERFORM pg_temp.chk('P5d multiple-row account unchanged', (SELECT count(*) FROM public.profiles WHERE user_id=u)=2);
  u := pg_temp.mk_user();
  v := pg_temp.call(u,'connect_play','probe_p5e'||substr(md5(random()::text),1,6), s1);
  PERFORM pg_temp.expect('P5e username already taken by another profile', format('SELECT pg_temp.call(%L,''connect_play'',%L,%L)',pg_temp.mk_user(),(SELECT username::text FROM public.profiles WHERE id=v),s1),'username_taken');

  -- P6 forced failure of each required insert leaves no partial record set --------------------------
  -- a failed call rolls back completely, so ONE user serves every iteration
  u := pg_temp.mk_user();
  FOREACH t IN ARRAY tbls LOOP
    FOR i IN 1..4 LOOP
      CONTINUE WHEN (t IN ('player','organiser','sport_profiles') AND i = 4) OR (t = 'host' AND i < 4) OR (t = 'profile_tiers' AND tier IS NULL);
      PERFORM set_config('kan645.fail_on', t, true);
      PERFORM pg_temp.expect('P6 '||t||' failure ('||ints[i]||')', format('SELECT pg_temp.call(%L,%L,%L,%L)',u,ints[i],'probe_p6'||t||i||substr(md5(random()::text),1,4),s1),'kan645_forced_failure');
      PERFORM set_config('kan645.fail_on', '', true);
      PERFORM pg_temp.chk('P6 '||t||'/'||ints[i]||' nothing left behind',
        NOT EXISTS (SELECT 1 FROM public.profiles WHERE user_id=u));
    END LOOP;
  END LOOP;
  -- failure at the final onboard=true step
  PERFORM set_config('kan645.fail_on', 'profiles', true);
  PERFORM pg_temp.expect('P6 final onboard=true failure', format('SELECT pg_temp.call(%L,''connect_play'',%L,%L)',u,'probe_p6z'||substr(md5(random()::text),1,5),s1),'kan645_forced_failure');
  PERFORM set_config('kan645.fail_on', '', true);
  PERFORM pg_temp.chk('P6 final-step failure left no profile and no onboard=true', NOT EXISTS (SELECT 1 FROM public.profiles WHERE user_id=u));
  -- replay after a failure succeeds cleanly (no duplicate, no reset)
  v := pg_temp.call(u,'connect_play','probe_p6r'||substr(md5(random()::text),1,5), s1);
  PERFORM pg_temp.chk('P6 replay after failure completes with one profile', (SELECT count(*) FROM public.profiles WHERE user_id=u)=1 AND EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND onboard));

  -- P7 legacy RPC compatibility and protection --------------------------------------------------------
  u := pg_temp.mk_user();
  PERFORM pg_temp.as_user(u);
  v := public.rpc_onboard_profile(u,'Legacy Probe','probe_p7a'||substr(md5(random()::text),1,5),30,'male','player',s1,NULL,NULL,NULL);
  PERFORM pg_temp.chk('P7a legacy-only user: old signature still onboards a player', EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND persona_type='player' AND onboarding_intention IS NULL));
  u := pg_temp.mk_user();
  v := pg_temp.call(u,'connect_play','probe_p7b'||substr(md5(random()::text),1,5), s1);
  PERFORM pg_temp.expect('P7b legacy RPC cannot downgrade a Contributor to player',
    format('SELECT public.rpc_onboard_profile(%L,''Legacy'',''probe_p7b2'',30,''male'',''player'',%L,NULL,NULL,NULL)',u,s1),'persona_conversion_blocked');
  PERFORM pg_temp.expect('P7c legacy RPC cannot create/convert to contributor',
    format('SELECT public.rpc_onboard_profile(%L,''Legacy'',''probe_p7c'',30,''male'',''contributor'',%L,NULL,NULL,NULL)',u,s1),'');
  PERFORM pg_temp.chk('P7d unified profile intact after legacy attempts', EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND persona_type='contributor' AND onboarding_intention='connect_play' AND onboard AND display_name='Probe Name')
    AND (SELECT count(*) FROM public.profiles WHERE user_id=u)=1);
  u := pg_temp.mk_user();
  PERFORM pg_temp.as_user(u);
  PERFORM pg_temp.expect('P7e legacy RPC cannot create a contributor for a new user',
    format('SELECT public.rpc_onboard_profile(%L,''Legacy'',''probe_p7e'',30,''male'',''contributor'',%L,NULL,NULL,NULL)',u,s1),'');
  PERFORM pg_temp.chk('P7f ...and left nothing', NOT EXISTS (SELECT 1 FROM public.profiles WHERE user_id=u));

  -- P8 signature, grants, definer discipline -----------------------------------------------------------
  PERFORM pg_temp.chk('P8a exact signature and return type', EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid='public.rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)'::regprocedure
    AND p.prorettype='uuid'::regtype AND pg_get_function_identity_arguments(p.oid) =
    'p_user_id uuid, p_display_name text, p_username text, p_age integer, p_gender text, p_onboarding_intention text, p_preferred_sport uuid, p_interests uuid[], p_country text, p_city text'));
  PERFORM pg_temp.chk('P8b SECURITY DEFINER with pinned search_path, owner postgres', EXISTS (SELECT 1 FROM pg_proc p WHERE p.proname='rpc_onboard_unified_profile'
    AND p.prosecdef AND pg_get_userbyid(p.proowner)='postgres' AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%')));
  PERFORM pg_temp.chk('P8c anon and PUBLIC cannot execute; authenticated and service_role can',
    NOT has_function_privilege('anon','public.rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)','EXECUTE')
    AND has_function_privilege('authenticated','public.rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)','EXECUTE')
    AND has_function_privilege('service_role','public.rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)','EXECUTE')
    AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.proname='rpc_onboard_unified_profile' AND a.grantee=0));
  PERFORM pg_temp.chk('P8d legacy rpc_onboard_profile signature unchanged', EXISTS (SELECT 1 FROM pg_proc WHERE proname='rpc_onboard_profile'
    AND pg_get_function_identity_arguments(oid) = 'p_user_id uuid, p_display_name text, p_username text, p_age integer, p_gender text, p_persona_type text, p_preferred_sport uuid, p_interests uuid[], p_country text, p_city text'));

  -- P9 an authenticated client role can call it (definer does the writes) ------------------------------
  u := pg_temp.mk_user();
  PERFORM pg_temp.as_user(u);
  SET LOCAL ROLE authenticated;
  v := public.rpc_onboard_unified_profile(u,'Probe Role','probe_p9'||substr(md5(random()::text),1,6),25,'female','organise',s1,NULL,NULL,NULL);
  RESET ROLE;
  PERFORM pg_temp.chk('P9 authenticated role onboards a contributor', EXISTS (SELECT 1 FROM public.profiles WHERE id=v AND persona_type='contributor' AND onboarding_intention='organise' AND onboard));

  -- P10 legacy rows unchanged ----------------------------------------------------------------------------
  PERFORM pg_temp.chk('P10 no pre-existing legacy row changed (count+hash)', (SELECT count(*)||md5(string_agg(p::text,'' ORDER BY id)) FROM public.profiles p
    WHERE persona_type IN ('player','organiser','host','socialiser') AND created_at < now()) IS NOT DISTINCT FROM legacy_before);
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-645 probes FAILED: %', (SELECT string_agg(name,', ') FROM _r WHERE NOT ok); END IF; END $$;
ROLLBACK;

-- P-C concurrency (two psql sessions as postgres, then ROLLBACK both). U = a fresh auth.users id with no profile.
--   Each session: BEGIN; SELECT set_config('request.jwt.claims', '{"sub":"<U>"}', true);
--   S1: SELECT public.rpc_onboard_unified_profile('<U>','Probe One','probe_c1',25,'male','connect_play','<sport>');   -- holds the user lock
--   S2: SELECT public.rpc_onboard_unified_profile('<U>','Probe One','probe_c1',25,'male','connect_play','<sport>');   -- blocks
--   S1: COMMIT;  S2 then returns S1's profile id (completed, compatible retry). Expect exactly 1 profiles row, 1 player, 1 organiser,
--   1 sport_profiles row for U.  Variant: S2 sends 'host_games' -> persona_change_not_supported; still exactly 1 row.
--   Isolation note: relies on READ COMMITTED (the Supabase default); not a SERIALIZABLE proof.

-- KAN-646 probes. Run AFTER KAN-644 (20261026100000) and 20261026120000_kan646_personas_s3_capabilities.sql
-- are applied, as postgres, in ONE transaction that ends in ROLLBACK (nothing persists).
-- Stands on S1 alone: rpc_onboard_unified_profile (S2) is never called. Contributor/Partner fixtures are
-- built here, in-transaction, as the migration owner, in S2's order: profile (onboard=false) -> extension
-- rows -> sport_profiles + Following (profiles.interests) -> onboard=true last.
-- KAN-678: P4 and L7..L7e call the 5-arg rpc_challenge_create (migration 20261027150000: apply it first).
-- Output: one row per probe (ok true/false); the last statement raises if any probe failed.
-- Hook-safe: no drops, no auth-user writes, no commit, named column lists only. Fixture users are
-- existing auth users with NO profile (>= 24 needed; the DO block says so if fewer exist).
-- Calls marked [auth] run under SET LOCAL ROLE authenticated, i.e. through the real client grant path.
BEGIN;
CREATE TEMP TABLE _r(name text, ok boolean, detail text);

CREATE FUNCTION pg_temp.chk(p_name text, p_cond boolean, p_detail text DEFAULT '') RETURNS void LANGUAGE sql AS $f$
  INSERT INTO _r VALUES (p_name, COALESCE(p_cond,false), p_detail) $f$;
-- q_as(sql): runs one statement as the authenticated role; returns its single value as text, or 'ERR:<message>'.
CREATE FUNCTION pg_temp.q_as(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    EXECUTE p_sql INTO v;
    EXECUTE 'RESET ROLE';
    RETURN COALESCE(v, '<null>');
  EXCEPTION WHEN OTHERS THEN
    RETURN 'ERR:' || SQLERRM;
  END;
END $f$;
-- q(sql): same, as the session role (postgres) with the JWT context already set.
CREATE FUNCTION pg_temp.q(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    EXECUTE p_sql INTO v;
    RETURN COALESCE(v, '<null>');
  EXCEPTION WHEN OTHERS THEN
    RETURN 'ERR:' || SQLERRM;
  END;
END $f$;
-- expect(name, got, want): want NULL = must not be an error; 'ERR:x' = must be an error containing x;
-- anything else = exact value.
CREATE FUNCTION pg_temp.expect(p_name text, p_got text, p_want text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO _r VALUES (p_name,
    CASE WHEN p_want IS NULL THEN p_got NOT LIKE 'ERR:%'
         WHEN p_want LIKE 'ERR:%' THEN p_got LIKE 'ERR:%' AND p_got LIKE '%' || substr(p_want, 5) || '%'
         ELSE p_got = p_want END,
    'got ' || p_got || ' / want ' || COALESCE(p_want, '<no error>')) $f$;

CREATE TEMP TABLE _pool(id uuid, used boolean NOT NULL DEFAULT false);
INSERT INTO _pool(id) SELECT u.id FROM auth.users u WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = u.id) ORDER BY u.id LIMIT 40;
CREATE FUNCTION pg_temp.mk_user() RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  UPDATE _pool SET used = true WHERE id = (SELECT id FROM _pool WHERE NOT used ORDER BY id LIMIT 1) RETURNING id INTO v;
  IF v IS NULL THEN RAISE EXCEPTION 'kan646_probe_pool_exhausted: need more auth users without a profile'; END IF;
  RETURN v;
END $f$;
CREATE FUNCTION pg_temp.as_user(p_user uuid) RETURNS void LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', json_build_object('sub', p_user, 'role','authenticated')::text, true),
         set_config('request.jwt.claim.sub', COALESCE(p_user::text,''), true) $f$;
-- Contributor fixture, S2 order. p_player / p_org choose which extension rows exist (negative fixtures).
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
-- Legacy fixture: the live carrier for each legacy persona (player/socialiser personal, organiser business, host venue).
CREATE FUNCTION pg_temp.mk_legacy(p_user uuid, p_persona text, p_sport uuid) RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO public.profiles(user_id, profile_type, username, display_name, age, persona_type, primary_sport, onboard, is_active)
  VALUES (p_user, CASE p_persona WHEN 'organiser' THEN 'business' WHEN 'host' THEN 'venue' ELSE 'personal' END,
          'probe_l_'||substr(md5(random()::text),1,12), 'Probe L', 30, p_persona, p_sport, true, true) RETURNING id $f$;

DO $$
DECLARE
  s1 uuid; k1 text; s2 uuid; k2 text; s3 uuid; k3 text; gs uuid; gv uuid;
  uA uuid; cA uuid; uB uuid; cB uuid; uC uuid; cC uuid; uD uuid; cD uuid;
  uNP uuid; cNP uuid; uNO uuid; cNO uuid; uNX uuid; cNX uuid; uIn uuid; cIn uuid;
  uP uuid; pP uuid; uPN uuid; pPN uuid; uNoProf uuid;
  uLP uuid; lP uuid; uLO uuid; lO uuid; uLH uuid; lH uuid; uLS uuid; lS uuid;
  g_org text; g_ply text; g_bad text; legacy_before text; r text;
  game_sig text := 'public.rpc_create_game(p_actor_type=>%L, p_sport_id=>%L, p_sport_variant_id=>%L, p_start_at=>now()+interval ''2 hours'', p_end_at=>now()+interval ''1 hour'', p_price_aed=>0)';
  meet_sig text := 'SELECT public.rpc_create_meetup(%L, %L, %L, ''Probe meetup'', p_location_name=>NULL, p_is_indoor=>true)';
BEGIN
  SELECT id, sport_key INTO s1, k1 FROM public.sports WHERE is_active ORDER BY sport_key LIMIT 1;
  SELECT id, sport_key INTO s2, k2 FROM public.sports WHERE is_active AND id <> s1 ORDER BY sport_key LIMIT 1;
  SELECT id, sport_key INTO s3, k3 FROM public.sports WHERE is_active AND id NOT IN (s1,s2) ORDER BY sport_key LIMIT 1;
  SELECT s.id, v.id INTO gs, gv FROM public.sports s JOIN public.sport_variants v ON v.sport_id = s.id
   WHERE s.is_active AND s.is_challenge_sport AND v.is_active ORDER BY s.sport_key, v.id LIMIT 1;
  IF (SELECT count(*) FROM _pool) < 24 THEN RAISE EXCEPTION 'kan646_probe_pool_too_small: need >= 24 auth users without a profile, found %', (SELECT count(*) FROM _pool); END IF;
  IF gs IS NULL THEN RAISE EXCEPTION 'kan646_probe_precondition: no active challenge sport with an active variant'; END IF;
  SELECT count(*)||md5(string_agg(p::text,'' ORDER BY p.id)) INTO legacy_before
    FROM public.profiles p WHERE p.persona_type IN ('player','organiser','host','socialiser') AND p.created_at < now();

  -- fixtures --------------------------------------------------------------------------------------------
  uA := pg_temp.mk_user(); cA := pg_temp.mk_contrib(uA, s1, k1);                 -- full contributor (organiser side)
  uB := pg_temp.mk_user(); cB := pg_temp.mk_contrib(uB, s1, k1);                 -- full contributor (joiner)
  uC := pg_temp.mk_user(); cC := pg_temp.mk_contrib(uC, s1, k1);                 -- full contributor (blocked)
  uD := pg_temp.mk_user(); cD := pg_temp.mk_contrib(uD, s1, k1);                 -- full contributor (frozen)
  uNP := pg_temp.mk_user(); cNP := pg_temp.mk_contrib(uNP, s1, k1, false, true); -- organiser row only
  uNO := pg_temp.mk_user(); cNO := pg_temp.mk_contrib(uNO, s1, k1, true, false); -- player row only
  uNX := pg_temp.mk_user(); cNX := pg_temp.mk_contrib(uNX, s1, k1, false, false);-- no extension rows
  uIn := pg_temp.mk_user(); cIn := pg_temp.mk_contrib(uIn, s1, k1);              -- will be inactive
  UPDATE public.profiles SET is_active = false WHERE id = cIn;
  uP := pg_temp.mk_user(); pP := pg_temp.mk_partner(uP, s1);                      -- partner with host row
  uPN := pg_temp.mk_user(); pPN := pg_temp.mk_partner(uPN, s1, false);            -- partner, no host row
  uNoProf := pg_temp.mk_user();                                                       -- authenticated, no profile
  uLP := pg_temp.mk_user(); lP := pg_temp.mk_legacy(uLP, 'player', s1);
  uLO := pg_temp.mk_user(); lO := pg_temp.mk_legacy(uLO, 'organiser', s1);
  uLH := pg_temp.mk_user(); lH := pg_temp.mk_legacy(uLH, 'host', s1);
  uLS := pg_temp.mk_user(); lS := pg_temp.mk_legacy(uLS, 'socialiser', s1);
  PERFORM pg_temp.chk('F0 fixtures: contributor A has player+organiser+sport_profile on ONE id and is onboarded',
    (SELECT onboard FROM public.profiles WHERE id = cA) AND EXISTS (SELECT 1 FROM public.player WHERE profile_id = cA)
    AND EXISTS (SELECT 1 FROM public.organiser WHERE profile_id = cA) AND EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id = cA AND sport_id = s1));

  -- T truth table (helpers, evaluated as owner) ----------------------------------------------------------
  PERFORM pg_temp.chk('T1 contributor full: player & organiser, not host', public.actor_is_player(cA) AND public.actor_is_organiser(cA) AND NOT public.actor_is_host(cA));
  PERFORM pg_temp.chk('T2 contributor without player row: not player', NOT public.actor_is_player(cNP) AND public.actor_is_organiser(cNP));
  PERFORM pg_temp.chk('T3 contributor without organiser row: not organiser', public.actor_is_player(cNO) AND NOT public.actor_is_organiser(cNO));
  PERFORM pg_temp.chk('T4 contributor without extension rows: nothing', NOT public.actor_is_player(cNX) AND NOT public.actor_is_organiser(cNX) AND NOT public.actor_is_host(cNX));
  PERFORM pg_temp.chk('T5 inactive contributor: nothing', NOT public.actor_is_player(cIn) AND NOT public.actor_is_organiser(cIn));
  PERFORM pg_temp.chk('T6 partner with host row: host only', public.actor_is_host(pP) AND NOT public.actor_is_player(pP) AND NOT public.actor_is_organiser(pP));
  PERFORM pg_temp.chk('T7 partner without host row: not host', NOT public.actor_is_host(pPN));
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.chk('T8a can_create_meetup: owner contributor yes', public.can_create_meetup(cA));
  PERFORM pg_temp.as_user(uNX);
  PERFORM pg_temp.chk('T8b can_create_meetup: contributor without extension rows no', NOT public.can_create_meetup(cNX));
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.chk('T8c can_create_meetup: partner no', NOT public.can_create_meetup(pP));
  PERFORM pg_temp.as_user(uB);
  PERFORM pg_temp.chk('T9 can_create_meetup: another owner''s contributor id is refused', NOT public.can_create_meetup(cA));
  PERFORM pg_temp.chk('T10 actor_can derived: contributor post/join_game/create_squad/host true; partner all false',
    public.actor_can(cA,'post') AND public.actor_can(cA,'join_game') AND public.actor_can(cA,'create_squad') AND public.actor_can(cA,'host')
    AND NOT public.actor_can(pP,'post') AND NOT public.actor_can(pP,'join_game') AND NOT public.actor_can(pP,'host'));

  -- A choose_actor: same id, extension required, owner only ------------------------------------------------
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('A1 contributor requests player -> own id [auth]', pg_temp.q_as('SELECT public.choose_actor(''player'')'), cA::text);
  PERFORM pg_temp.expect('A2 contributor requests organiser -> SAME id [auth]', pg_temp.q_as('SELECT public.choose_actor(''organiser'')'), cA::text);
  PERFORM pg_temp.expect('A3 default argument still player -> own id [auth]', pg_temp.q_as('SELECT public.choose_actor()'), cA::text);
  PERFORM pg_temp.expect('A4 contributor requests host -> refused [auth]', pg_temp.q_as('SELECT public.choose_actor(''host'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.expect('A5 partner requests host -> own id [auth]', pg_temp.q_as('SELECT public.choose_actor(''host'')'), pP::text);
  PERFORM pg_temp.expect('A6 partner requests player -> refused [auth]', pg_temp.q_as('SELECT public.choose_actor(''player'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.expect('A7 partner requests organiser -> refused [auth]', pg_temp.q_as('SELECT public.choose_actor(''organiser'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uPN);
  PERFORM pg_temp.expect('A8 partner without host row requests host -> refused', pg_temp.q_as('SELECT public.choose_actor(''host'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uNO);
  PERFORM pg_temp.expect('A9 contributor without organiser row requests organiser -> refused', pg_temp.q_as('SELECT public.choose_actor(''organiser'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uNP);
  PERFORM pg_temp.expect('A10 contributor without player row requests player -> refused', pg_temp.q_as('SELECT public.choose_actor(''player'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uIn);
  PERFORM pg_temp.expect('A11 inactive contributor -> refused', pg_temp.q_as('SELECT public.choose_actor(''player'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uNoProf);
  PERFORM pg_temp.expect('A12 caller with no profile never gets another owner''s id', pg_temp.q_as('SELECT public.choose_actor(''player'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uB);
  PERFORM pg_temp.expect('A13 contributor B gets B, never A', pg_temp.q_as('SELECT public.choose_actor(''organiser'')'), cB::text);
  PERFORM pg_temp.as_user(NULL);
  PERFORM pg_temp.expect('A14 no auth context -> not_authenticated', pg_temp.q('SELECT public.choose_actor(''player'')'), 'ERR:not_authenticated');
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('A15 unknown requested type -> refused', pg_temp.q_as('SELECT public.choose_actor(''wizard'')'), 'ERR:no_profile_of_requested_type');

  -- G game create (gate then a deterministic later error proves the gate was passed) ----------------------
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('G1 contributor as player passes gate [auth]', pg_temp.q_as('SELECT '||format(game_sig,'player',gs,gv)), 'ERR:invalid_time_range');
  PERFORM pg_temp.expect('G2 contributor as organiser passes gate [auth]', pg_temp.q_as('SELECT '||format(game_sig,'organiser',gs,gv)), 'ERR:invalid_time_range');
  PERFORM pg_temp.expect('G3 contributor literal type contributor -> persona_not_allowed', pg_temp.q_as('SELECT '||format(game_sig,'contributor',gs,gv)), 'ERR:persona_not_allowed');
  PERFORM pg_temp.as_user(uNO);
  PERFORM pg_temp.expect('G4 contributor without organiser row as organiser -> refused', pg_temp.q_as('SELECT '||format(game_sig,'organiser',gs,gv)), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.expect('G5 partner as host -> persona_not_allowed [auth]', pg_temp.q_as('SELECT '||format(game_sig,'host',gs,gv)), 'ERR:persona_not_allowed');
  PERFORM pg_temp.expect('G6 partner as player -> refused [auth]', pg_temp.q_as('SELECT '||format(game_sig,'player',gs,gv)), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('G7 price rule preserved for contributor (price NULL)', pg_temp.q_as(format('SELECT public.rpc_create_game(p_actor_type=>''organiser'', p_sport_id=>%L, p_sport_variant_id=>%L, p_start_at=>now()+interval ''1 day'', p_end_at=>now()+interval ''1 day 2 hours'')', gs, gv)), 'ERR:price_required');
  g_org := pg_temp.q_as(format('SELECT public.rpc_create_game(p_actor_type=>''organiser'', p_sport_id=>%L, p_sport_variant_id=>%L, p_title=>''Probe hosted'', p_start_at=>now()+interval ''1 day'', p_end_at=>now()+interval ''1 day 2 hours'', p_max_players=>20, p_price_aed=>0)', gs, gv));
  -- G8 asserts g_org is a real games row (a bare non-error text would pass for any value).
  PERFORM pg_temp.chk('G8 contributor creates a real game as organiser [auth]: g_org is a uuid that exists in games',
    g_org ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    AND EXISTS (SELECT 1 FROM public.games g WHERE g.id::text = g_org), g_org);
  PERFORM pg_temp.chk('G9 organiser request -> hosted, creator = SAME profile id, host roster row',
    EXISTS (SELECT 1 FROM public.games g WHERE g.id::text = g_org AND g.game_type = 'hosted' AND g.creator_profile_id = cA AND g.creator_user_id = uA)
    AND EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id::text = g_org AND r.profile_id = cA AND r.role = 'host'), g_org);
  g_ply := pg_temp.q_as(format('SELECT public.rpc_create_game(p_actor_type=>''player'', p_sport_id=>%L, p_sport_variant_id=>%L, p_start_at=>now()+interval ''1 day'', p_end_at=>now()+interval ''1 day 2 hours'', p_max_players=>20, p_price_aed=>0)', gs, gv));
  PERFORM pg_temp.chk('G10 player request on the SAME id -> casual', EXISTS (SELECT 1 FROM public.games g WHERE g.id::text = g_ply AND g.game_type = 'casual' AND g.creator_profile_id = cA), g_ply);

  -- J join / leave / roster, on the real game g_org ----------------------------------------------------------
  -- J1/J4 call the INVOKER function can_current_user_join_game through q (session role, JWT = B): public.games has RLS
  -- enabled and no SELECT policy (reads go through definer RPCs; kan595 note), so under SET LOCAL ROLE authenticated the
  -- function's own SELECT sees no row and answers reason not_found. rpc_join_game (definer, J2) reaches it the same way q does.
  PERFORM pg_temp.as_user(uB);
  PERFORM pg_temp.expect('J1 contributor B can join (precheck) [auth]', pg_temp.q(format('SELECT public.can_current_user_join_game(%L::uuid, ''player'')->>''cta''', g_org)), 'join');
  PERFORM pg_temp.expect('J2 contributor B joins [auth]', pg_temp.q_as(format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid)', g_org)), 'joined');
  PERFORM pg_temp.chk('J3 roster row is B''s SAME profile id as player', EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id::text = g_org AND r.profile_id = cB AND r.role = 'player' AND r.status = 'active'));
  PERFORM pg_temp.expect('J4 joined twice -> joined cta [auth]', pg_temp.q(format('SELECT public.can_current_user_join_game(%L::uuid, ''player'')->>''cta''', g_org)), 'joined');
  PERFORM pg_temp.expect('J5 contributor B leaves [auth]', pg_temp.q_as(format('SELECT public.rpc_leave_game(''player'', %L::uuid)', g_org)), 'left');
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('J6 creator cannot join own game', pg_temp.q_as(format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid)', g_org)), 'ERR:host');
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.expect('J7 partner cannot join [auth]', pg_temp.q_as(format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid)', g_org)), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uNP);
  PERFORM pg_temp.expect('J8 contributor without player row cannot join', pg_temp.q_as(format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid)', g_org)), 'ERR:no_profile_of_requested_type');
  INSERT INTO public.user_blocks(blocker_user_id, blocked_user_id) VALUES (uA, uC);
  PERFORM pg_temp.as_user(uC);
  PERFORM pg_temp.expect('J9 blocked contributor cannot join (block preserved)', pg_temp.q_as(format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid)', g_org)), 'ERR:not_visible');
  INSERT INTO public.user_freezes(user_id, is_frozen) VALUES (uD, true);
  PERFORM pg_temp.as_user(uD);
  PERFORM pg_temp.expect('J10 frozen contributor cannot join (freeze preserved)', pg_temp.q_as(format('SELECT public.can_current_user_join_game(%L::uuid, ''player'')->>''reason''', g_org)), 'frozen');
  PERFORM pg_temp.as_user(uLP);
  PERFORM pg_temp.expect('J11 legacy player still joins a contributor''s game [auth]', pg_temp.q_as(format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid)', g_org)), 'joined');
  UPDATE public.games SET is_cancelled = true WHERE id::text = g_ply;
  PERFORM pg_temp.as_user(uB);
  PERFORM pg_temp.expect('J12 cancelled game refuses contributor (lifecycle preserved)', pg_temp.q_as(format('SELECT result FROM public.rpc_join_game(''player'', %L::uuid)', g_ply)), 'ERR:cancelled');

  -- M meetup create (p_request_id NULL -> legacy_v2; location_name_required proves the gate was passed) -------
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('M1 contributor as player reaches location check [auth]', pg_temp.q_as(format(meet_sig,'player',s1,gv)), 'ERR:location_name_required');
  PERFORM pg_temp.expect('M2 contributor as organiser reaches location check [auth]', pg_temp.q_as(format(meet_sig,'organiser',s1,gv)), 'ERR:location_name_required');
  PERFORM pg_temp.expect('M3 free-meetup rule preserved for contributor', pg_temp.q_as(format('SELECT public.rpc_create_meetup(''organiser'', %L, %L, ''Paid'', p_meta=>''{"joining_rule":"paid"}''::jsonb, p_location_name=>''X'', p_is_indoor=>true)', s1, gv)), 'ERR:free_meetups_only');
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.expect('M4 partner as host -> persona_not_allowed [auth]', pg_temp.q_as(format(meet_sig,'host',s1,gv)), 'ERR:persona_not_allowed');
  PERFORM pg_temp.as_user(uNX);
  PERFORM pg_temp.expect('M5 contributor without extension rows -> refused', pg_temp.q_as(format(meet_sig,'player',s1,gv)), 'ERR:no_profile_of_requested_type');

  -- P post / challenge ---------------------------------------------------------------------------------------
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('P1 contributor posts as player, actor = SAME id [auth]', pg_temp.q_as('SELECT public.rpc_post_as(''player'', ''{}''::jsonb)->>''actor_profile_id'''), cA::text);
  PERFORM pg_temp.expect('P2 contributor posts as organiser, actor = SAME id [auth]', pg_temp.q_as('SELECT public.rpc_post_as(''organiser'', ''{}''::jsonb)->>''actor_profile_id'''), cA::text);
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.expect('P3 partner cannot post as host', pg_temp.q_as('SELECT public.rpc_post_as(''host'', ''{}''::jsonb)'), 'ERR:actor_not_allowed');
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('P4 contributor creates a challenge as organiser with an active sport key (KAN-678, 5-arg) [auth]', pg_temp.q_as(format('SELECT id FROM public.rpc_challenge_create(''organiser'', ''Probe challenge'', ''public'', %L, NULL)', k1)), NULL);
  PERFORM pg_temp.as_user(uNO);
  PERFORM pg_temp.expect('P5 contributor without organiser row cannot create a challenge', pg_temp.q_as('SELECT id FROM public.rpc_challenge_create(''organiser'', ''x'', ''public'', NULL)'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.expect('P6 partner cannot create a challenge', pg_temp.q_as('SELECT id FROM public.rpc_challenge_create(''host'', ''x'', ''public'', NULL)'), 'ERR:actor_type_invalid');

  -- S sport profile ------------------------------------------------------------------------------------------
  UPDATE public.profiles SET interests = ARRAY[s1, s2] WHERE id = cA;                       -- Following first (S1 rule)
  PERFORM pg_temp.as_user(uA);
  PERFORM pg_temp.expect('S1 owner contributor adds a Following sport profile [auth]', pg_temp.q_as(format('SELECT public.rpc_create_sport_profile(%L::uuid, %L::uuid, %L, 2)', cA, s2, k2)), NULL);
  PERFORM pg_temp.chk('S2 row exists on the SAME id', EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id = cA AND sport_id = s2 AND skill_level = 2));
  BEGIN
    SET CONSTRAINTS trg_contributor_sports_sp, trg_contributor_sports_profiles IMMEDIATE;
    PERFORM pg_temp.chk('S3 S1 deferred sports rule accepts it', true);
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('S3 S1 deferred sports rule accepts it', false, SQLERRM);
  END;
  SET CONSTRAINTS trg_contributor_sports_sp, trg_contributor_sports_profiles DEFERRED;
  BEGIN
    PERFORM public.rpc_create_sport_profile(cA, s3, k3, 1);
    SET CONSTRAINTS trg_contributor_sports_sp IMMEDIATE;
    PERFORM pg_temp.chk('S4 sport outside Following is refused by S1 rule', false, 'no error');
  EXCEPTION WHEN OTHERS THEN PERFORM pg_temp.chk('S4 sport outside Following is refused by S1 rule', SQLERRM LIKE '%contributor_sports_incomplete%', SQLERRM);
  END;
  SET CONSTRAINTS trg_contributor_sports_sp DEFERRED;
  PERFORM pg_temp.as_user(uB);
  PERFORM pg_temp.expect('S5 another owner cannot add to A''s contributor [auth]', pg_temp.q_as(format('SELECT public.rpc_create_sport_profile(%L::uuid, %L::uuid, %L, 5)', cA, s2, k2)), 'ERR:sport_profile requires owned player profile');
  PERFORM pg_temp.chk('S5b ...and A''s skill was not overwritten', EXISTS (SELECT 1 FROM public.sport_profiles WHERE profile_id = cA AND sport_id = s2 AND skill_level = 2));
  PERFORM pg_temp.as_user(uNP);
  PERFORM pg_temp.expect('S6 contributor without player row refused', pg_temp.q_as(format('SELECT public.rpc_create_sport_profile(%L::uuid, %L::uuid, %L, 1)', cNP, s1, k1)), 'ERR:sport_profile requires owned player profile');
  PERFORM pg_temp.as_user(uP);
  PERFORM pg_temp.expect('S7 partner refused', pg_temp.q_as(format('SELECT public.rpc_create_sport_profile(%L::uuid, %L::uuid, %L, 1)', pP, s1, k1)), 'ERR:sport_profile requires owned player profile');

  -- Q squads: unchanged (blocker B1). Contributor gets exactly what a live legacy player gets today. -----------
  PERFORM pg_temp.as_user(uA);
  r := pg_temp.q_as(format('SELECT public.rpc_squad_create(%L::uuid, %L, ''Probe squad'')', cA, k1));
  PERFORM pg_temp.as_user(uLP);
  PERFORM pg_temp.chk('Q1 rpc_squad_create: contributor result == legacy player result (both invalid_creator_role today, B1)',
    r LIKE 'ERR:%invalid_creator_role%' AND pg_temp.q_as(format('SELECT public.rpc_squad_create(%L::uuid, %L, ''Probe squad'')', lP, k1)) LIKE 'ERR:%invalid_creator_role%', r);

  -- L legacy control matrix (four personas, unchanged behaviour) -----------------------------------------
  PERFORM pg_temp.as_user(uLP);
  PERFORM pg_temp.expect('L1 legacy player: choose_actor exact', pg_temp.q_as('SELECT public.choose_actor(''player'')'), lP::text);
  PERFORM pg_temp.expect('L2 legacy player: game gate passed', pg_temp.q_as('SELECT '||format(game_sig,'player',gs,gv)), 'ERR:invalid_time_range');
  PERFORM pg_temp.chk('L3 legacy player: helpers', public.actor_is_player(lP) AND NOT public.actor_is_organiser(lP) AND NOT public.actor_is_host(lP));
  PERFORM pg_temp.as_user(uLO);
  PERFORM pg_temp.expect('L4 legacy organiser: choose_actor exact', pg_temp.q_as('SELECT public.choose_actor(''organiser'')'), lO::text);
  PERFORM pg_temp.expect('L5 legacy organiser: game gate passed', pg_temp.q_as('SELECT '||format(game_sig,'organiser',gs,gv)), 'ERR:invalid_time_range');
  PERFORM pg_temp.chk('L6 legacy organiser: actor_is_organiser true (F1 fixed) and not player', public.actor_is_organiser(lO) AND NOT public.actor_is_player(lO));
  PERFORM pg_temp.expect('L7 legacy organiser creates a challenge with an active sport key (F1 fixed, KAN-678 5-arg) [auth]', pg_temp.q_as(format('SELECT id FROM public.rpc_challenge_create(''organiser'', ''x'', ''public'', %L, NULL)', k1)), NULL);
  PERFORM pg_temp.expect('L7b legacy organiser: blank sport -> sport_required [auth]', pg_temp.q_as('SELECT id FROM public.rpc_challenge_create(''organiser'', ''x'', ''public'', ''  '', NULL)'), 'ERR:sport_required');
  PERFORM pg_temp.expect('L7c legacy organiser: NULL sport -> sport_required [auth]', pg_temp.q_as('SELECT id FROM public.rpc_challenge_create(''organiser'', ''x'', ''public'', NULL, NULL)'), 'ERR:sport_required');
  PERFORM pg_temp.expect('L7d legacy organiser: unknown sport key -> invalid_sport (existing trigger) [auth]', pg_temp.q_as('SELECT id FROM public.rpc_challenge_create(''organiser'', ''x'', ''public'', ''no_such_sport_kan678'', NULL)'), 'ERR:invalid_sport');
  PERFORM pg_temp.as_user(uLP);
  PERFORM pg_temp.expect('L7e legacy player still cannot create a challenge (5-arg) [auth]', pg_temp.q_as(format('SELECT id FROM public.rpc_challenge_create(''player'', ''x'', ''public'', %L, NULL)', k1)), 'ERR:organiser_required');
  PERFORM pg_temp.as_user(uLH);
  PERFORM pg_temp.expect('L8 legacy host: choose_actor exact', pg_temp.q_as('SELECT public.choose_actor(''host'')'), lH::text);
  PERFORM pg_temp.expect('L9 legacy host: game gate refuses', pg_temp.q_as('SELECT '||format(game_sig,'host',gs,gv)), 'ERR:persona_not_allowed');
  PERFORM pg_temp.chk('L10 legacy host: actor_is_host true, others false', public.actor_is_host(lH) AND NOT public.actor_is_player(lH));
  PERFORM pg_temp.as_user(uLS);
  PERFORM pg_temp.expect('L11 legacy socialiser: choose_actor exact', pg_temp.q_as('SELECT public.choose_actor(''socialiser'')'), lS::text);
  PERFORM pg_temp.expect('L12 legacy socialiser: player request refused', pg_temp.q_as('SELECT public.choose_actor(''player'')'), 'ERR:no_profile_of_requested_type');
  PERFORM pg_temp.expect('L13 legacy socialiser: meetup refused', pg_temp.q_as(format(meet_sig,'socialiser',s1,gv)), 'ERR:persona_not_allowed');
  PERFORM pg_temp.chk('L14 legacy socialiser: no capability', NOT public.actor_is_player(lS) AND NOT public.actor_is_organiser(lS) AND NOT public.actor_is_host(lS));
  PERFORM pg_temp.chk('L15 no pre-existing legacy profile changed (count+hash)', (SELECT count(*)||md5(string_agg(p::text,'' ORDER BY p.id))
    FROM public.profiles p WHERE p.persona_type IN ('player','organiser','host','socialiser') AND p.created_at < now()) IS NOT DISTINCT FROM legacy_before);

  -- R grants / signature diff against the pre-migration live values (read 2026-10-27) ----------------------
  PERFORM pg_temp.chk('R1 choose_actor ACL unchanged', (SELECT proacl::text FROM pg_proc WHERE oid='public.choose_actor(text)'::regprocedure)
    = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}');  -- anon removed by KAN-679 (applied live 2026-10-27)
  PERFORM pg_temp.chk('R2 helper ACLs unchanged (PUBLIC/anon were already granted; not expanded)',
    (SELECT bool_and(proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}') FROM pg_proc
      WHERE oid IN ('public.actor_is_player(uuid)'::regprocedure, 'public.actor_is_organiser(uuid)'::regprocedure, 'public.can_create_meetup(uuid)'::regprocedure)));
  PERFORM pg_temp.chk('R2b rpc_create_sport_profile ACL is the KAN-673 value: no PUBLIC, no anon; authenticated + service_role',
    (SELECT proacl::text FROM pg_proc WHERE oid='public.rpc_create_sport_profile(uuid,uuid,text,integer)'::regprocedure)
    = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}');
  PERFORM pg_temp.chk('R3 rpc_create_game_legacy_v2 still owner/service_role only', (SELECT proacl::text FROM pg_proc WHERE proname='rpc_create_game_legacy_v2')
    = '{postgres=X/postgres,service_role=X/postgres}');
  PERFORM pg_temp.chk('R4 actor_is_host: no PUBLIC, no anon; authenticated + service_role',
    NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid='public.actor_is_host(uuid)'::regprocedure AND (a.grantee = 0 OR a.grantee = 'anon'::regrole))
    AND NOT has_function_privilege('anon','public.actor_is_host(uuid)','EXECUTE')
    AND has_function_privilege('authenticated','public.actor_is_host(uuid)','EXECUTE'));
  PERFORM pg_temp.chk('R5 definer flags and search_path unchanged',
    (SELECT prosecdef FROM pg_proc WHERE oid='public.choose_actor(text)'::regprocedure)
    AND NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.actor_is_player(uuid)'::regprocedure)
    AND NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.actor_is_organiser(uuid)'::regprocedure)
    AND NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.can_create_meetup(uuid)'::regprocedure)
    AND (SELECT prosecdef FROM pg_proc WHERE oid='public.rpc_create_sport_profile(uuid,uuid,text,integer)'::regprocedure)
    AND (SELECT proconfig::text FROM pg_proc WHERE oid='public.choose_actor(text)'::regprocedure) = '{search_path=public}');
  PERFORM pg_temp.chk('R6 choose_actor default still player', pg_get_function_arguments('public.choose_actor(text)'::regprocedure) = 'p_profile_type text DEFAULT ''player''::text');
END $$;

SELECT name, ok, detail FROM _r ORDER BY name;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM _r WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-646 probes FAILED: %', (SELECT string_agg(name,', ') FROM _r WHERE NOT ok); END IF; END $$;
ROLLBACK;

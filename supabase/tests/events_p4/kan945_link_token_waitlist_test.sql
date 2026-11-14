-- KAN-945 item 1 live test: on a full link-policy game, taking a waitlist place with a token spends a use, the same
-- as joining does, so a single-use token waitlists one person and no more.
-- Runs on the hosted project as postgres (execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Every app-facing call runs AS authenticated (SET LOCAL ROLE + JWT claims) through rpc_join_game, the path the app
-- uses (refusal: message = cta, detail = reason).
-- Fixture: series occurrence a2205c27 (private, join_policy 'link', casual, host on the roster), un-cancelled and
-- filled inside the transaction (capacity 2 = host + one filler player). Six users U1..U6 picked live (active player
-- persona, not admin, not frozen, no blocks, not the host or filler, not on the roster or waitlist).
-- Expected GREEN after 20261113235541_kan945_link_token_waitlist_consumes.sql. RED before (observed): W1-W6; W7, W8 pass both ways.
--   W1 U1 + single-use token on the full game -> waitlisted, used 0->1             (RED: used stays 0)
--   W2 U2 + the same token -> refused not_visible/visibility_denied, not waitlisted (RED: waitlisted)
--   W3 U3 + 2-use token -> waitlisted, used 1                                       (RED: used 0)
--   W4 U3 again, same token -> waitlisted, used still 1 (a repeat does not spend a second use)
--   W5 U4 + 2-use token -> waitlisted, used 2                                       (RED: used 0)
--   W6 U5 + 2-use token -> refused, not waitlisted                                  (RED: waitlisted)
--   W7 non-full game (capacity 10): U6 + 2-use-fresh token -> joined, used 0->1 (unchanged path)
--   W8 rpc_join_game attributes/ACL unchanged: DEFINER, search_path=public, owner postgres
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k945_tap (n int PRIMARY KEY, ok boolean, label text NOT NULL, detail text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.k945_as(p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text; d text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    SET LOCAL ROLE authenticated;
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL;
    RESET ROLE;
    v := 'ERR ' || SQLSTATE || ' ' || SQLERRM || '/' || COALESCE(d, '');
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN COALESCE(v, '<null>');
END $f$;

DO $run$
DECLARE
  g uuid := 'a2205c27-9c73-4ecf-8847-03763be74679';
  host uuid; filler uuid; us uuid[];
  t1 uuid; t2 uuid; t3 uuid; v text;
  join_sql text := 'SELECT result FROM public.rpc_join_game(''player'', %L::uuid, %L::uuid)';
  denied   text := 'ERR P0001 not_visible/visibility_denied';
BEGIN
  SELECT e.creator_user_id INTO host FROM public.games gg JOIN public.events e ON e.id = gg.event_id WHERE gg.id = g;
  UPDATE public.events e SET is_cancelled = false, capacity = 2 FROM public.games gg WHERE gg.id = g AND e.id = gg.event_id;

  SELECT p.id INTO filler FROM public.profiles p
   WHERE p.persona_type = 'player' AND p.is_active AND p.user_id IS NOT NULL AND p.user_id <> host
     AND NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g AND r.profile_id = p.id)
   ORDER BY p.created_at DESC LIMIT 1;
  INSERT INTO public.game_roster(game_id, profile_id, role, status) VALUES (g, filler, 'player', 'active');

  SELECT array_agg(x.user_id ORDER BY x.created_at) INTO us FROM (
    SELECT p.user_id, p.created_at FROM public.profiles p
     WHERE p.persona_type = 'player' AND p.is_active AND p.user_id IS NOT NULL AND p.user_id <> host
       AND p.id <> filler
       AND NOT public.is_admin(p.user_id) AND NOT public.is_frozen(p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE p.user_id IN (b.blocker_user_id, b.blocked_user_id))
       AND NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g AND r.user_id = p.user_id)
       AND NOT EXISTS (SELECT 1 FROM public.game_waitlist w WHERE w.game_id = g AND w.user_id = p.user_id)
       AND (SELECT count(*) FROM public.profiles q WHERE q.user_id = p.user_id AND q.persona_type = 'player') = 1
     ORDER BY p.created_at LIMIT 6) x;
  IF host IS NULL OR filler IS NULL OR coalesce(array_length(us, 1), 0) < 6 OR public.game_slots_left(g) <> 0 THEN
    RAISE EXCEPTION 'fixture: host % filler % users % slots %', host, filler, us, public.game_slots_left(g);
  END IF;

  t1 := pg_temp.k945_as(host, format('SELECT public.rpc_mint_join_link(%L::uuid, NULL, 1)::text', g))::uuid;
  t2 := pg_temp.k945_as(host, format('SELECT public.rpc_mint_join_link(%L::uuid, NULL, 2)::text', g))::uuid;
  t3 := pg_temp.k945_as(host, format('SELECT public.rpc_mint_join_link(%L::uuid, NULL, 2)::text', g))::uuid;

  -- W1 / W2 single-use token
  v := pg_temp.k945_as(us[1], format(join_sql, g, t1));
  v := v || ' used=' || (SELECT used_count FROM public.game_link_tokens WHERE token = t1);
  INSERT INTO k945_tap VALUES (1, v = 'waitlisted used=1', 'U1 + single-use token on full game: waitlisted, 1 use', v);
  v := pg_temp.k945_as(us[2], format(join_sql, g, t1));
  v := v || ' wl=' || (SELECT count(*) FROM public.game_waitlist WHERE game_id = g AND user_id = us[2])
       || ' used=' || (SELECT used_count FROM public.game_link_tokens WHERE token = t1);
  INSERT INTO k945_tap VALUES (2, v = denied || ' wl=0 used=1', 'U2 + same single-use token: refused, not waitlisted', v);

  -- W3..W6 two-use token
  v := pg_temp.k945_as(us[3], format(join_sql, g, t2));
  v := v || ' used=' || (SELECT used_count FROM public.game_link_tokens WHERE token = t2);
  INSERT INTO k945_tap VALUES (3, v = 'waitlisted used=1', 'U3 + 2-use token: waitlisted, 1 use', v);
  v := pg_temp.k945_as(us[3], format(join_sql, g, t2));
  v := v || ' used=' || (SELECT used_count FROM public.game_link_tokens WHERE token = t2);
  INSERT INTO k945_tap VALUES (4, v = 'waitlisted used=1', 'U3 repeat: still waitlisted, no second use', v);
  v := pg_temp.k945_as(us[4], format(join_sql, g, t2));
  v := v || ' used=' || (SELECT used_count FROM public.game_link_tokens WHERE token = t2);
  INSERT INTO k945_tap VALUES (5, v = 'waitlisted used=2', 'U4 + 2-use token: waitlisted, 2 uses', v);
  v := pg_temp.k945_as(us[5], format(join_sql, g, t2));
  v := v || ' wl=' || (SELECT count(*) FROM public.game_waitlist WHERE game_id = g AND user_id = us[5])
       || ' used=' || (SELECT used_count FROM public.game_link_tokens WHERE token = t2);
  INSERT INTO k945_tap VALUES (6, v = denied || ' wl=0 used=2', 'U5 + exhausted 2-use token: refused, not waitlisted', v);

  -- W7 non-full join unchanged
  UPDATE public.events e SET capacity = 10 FROM public.games gg WHERE gg.id = g AND e.id = gg.event_id;
  v := pg_temp.k945_as(us[6], format(join_sql, g, t3));
  v := v || ' used=' || (SELECT used_count FROM public.game_link_tokens WHERE token = t3);
  INSERT INTO k945_tap VALUES (7, v = 'joined used=1', 'U6 + token on non-full game: joined, 1 use', v);

  -- W8 attributes and ACL
  SELECT format('definer=%s cfg=%s owner=%s auth=%s', p.prosecdef, p.proconfig::text, p.proowner::regrole,
                has_function_privilege('authenticated', p.oid, 'EXECUTE'))
    INTO v FROM pg_proc p WHERE p.oid = 'public.rpc_join_game(text,uuid,uuid)'::regprocedure;
  INSERT INTO k945_tap VALUES (8, v = 'definer=t cfg={search_path=public} owner=postgres auth=t', 'rpc_join_game attributes', v);
END
$run$;

SELECT n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status, label, detail FROM k945_tap ORDER BY n;

ROLLBACK;

-- KAN-939 live test: a link-policy game (private visibility, join_policy 'link') can be seen and joined by a second
-- account that holds a valid token from rpc_mint_join_link. Without, with a wrong, or with an expired/exhausted token
-- the game stays invisible and unjoinable, and nothing about it is returned.
-- Runs on the hosted project as postgres (execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Every app-facing call runs AS authenticated (SET LOCAL ROLE + JWT claims). Refusals are read from rpc_join_game,
-- the path the app uses (message = cta, detail = reason). can_current_user_join_game is SECURITY INVOKER and is only
-- reached through rpc_join_game (definer), so T3 evaluates it in that context: U's claims, definer role.
-- Fixture: series occurrence a2205c27 (the game from the report), un-cancelled inside the transaction; a second
-- cancelled link game for the cancelled refusal; a live public open game for the control path; and a second user U
-- picked live (active player persona, not admin, not frozen, no blocks, not the host, not on any of the rosters).
-- Expected (GREEN after 20261113233039_kan939_link_token_view_join.sql). RED before: T2, T3, T8, T9, T12 (and the
-- card-RPC half of T4-T7, T10, T11, where the function is missing).
--   T1  host mints a token (rpc_mint_join_link)                                       -> uuid
--   T2  U + token: rpc_game_card_by_link returns the one card row                    (RED: 42883 missing)
--   T3  U + token: decision cta join_with_link                                       (RED: not_visible)
--   T4  U, no token: rpc_join_game not_visible/visibility_denied, card RPC 0 rows, v_game_card 0 rows
--   T5  U, wrong token: not_visible/visibility_denied, card RPC 0 rows
--   T6  U, expired token: not_visible/visibility_denied, card RPC 0 rows
--   T7  U, exhausted token (max_uses reached): not_visible/visibility_denied, card RPC 0 rows
--   T8  U + token: rpc_join_game -> joined, token used_count +1; v_game_card now shows it (roster member)
--   T9  U + valid token on a cancelled link game -> cancelled/cancelled (later refusals unchanged; RED: not_visible)
--   T10 host blocks U, valid token -> not_visible/visibility_denied, card RPC 0 rows (block still wins)
--   T11 public open game, no token: U joins (control path unchanged); card RPC with a random token -> 0 rows
--   T12 rpc_game_card_by_link: authenticated may execute, anon and PUBLIC may not; SECURITY DEFINER, search_path pinned
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k939_tap (n int PRIMARY KEY, ok boolean, label text NOT NULL, detail text) ON COMMIT DROP;

-- As <uid>: run p_sql (one text value). p_role true = SET LOCAL ROLE authenticated; false = claims only (definer
-- context). Errors come back as 'ERR <sqlstate> <message>/<detail>'.
CREATE FUNCTION pg_temp.k939_as(p_uid uuid, p_sql text, p_role boolean DEFAULT true) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text; d text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    IF p_role THEN SET LOCAL ROLE authenticated; END IF;
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
  g_cancel uuid; host uuid; host2 uuid; pub uuid; pub_host uuid; u uuid;
  t uuid; t_exp uuid; t_used uuid; t_cancel uuid; v text; used0 int; used1 int;
  card_sql text := 'SELECT count(*)::text || '':'' || COALESCE(max(id::text), '''') FROM public.rpc_game_card_by_link(%L::uuid, %L::uuid)';
  dec_sql  text := 'SELECT d->>''cta'' || ''/'' || COALESCE(d->>''reason'', '''') FROM public.can_current_user_join_game(%L::uuid, ''player'', %L::uuid) d';
  join_sql text := 'SELECT result FROM public.rpc_join_game(''player'', %L::uuid, %L::uuid)';
  vis_sql  text := 'SELECT count(*)::text FROM public.v_game_card WHERE id = %L::uuid';
  denied   text := 'ERR P0001 not_visible/visibility_denied';
BEGIN
  SELECT e.creator_user_id INTO host FROM public.games gg JOIN public.events e ON e.id = gg.event_id WHERE gg.id = g;
  UPDATE public.events e SET is_cancelled = false FROM public.games gg WHERE gg.id = g AND e.id = gg.event_id;

  SELECT gg.id, e.creator_user_id INTO g_cancel, host2
    FROM public.games gg JOIN public.events e ON e.id = gg.event_id AND e.event_type = 'game'
   WHERE e.join_policy = 'link' AND e.is_cancelled AND e.start_at > now() AND gg.id <> g LIMIT 1;

  SELECT gg.id, e.creator_user_id INTO pub, pub_host
    FROM public.games gg JOIN public.events e ON e.id = gg.event_id AND e.event_type = 'game'
   WHERE e.listing_visibility = 'public' AND e.join_policy = 'open' AND NOT e.is_cancelled
     AND e.start_at > now() + interval '1 hour' AND public.game_slots_left(gg.id) > 0
   ORDER BY e.start_at LIMIT 1;

  SELECT p.user_id INTO u FROM public.profiles p
   WHERE p.persona_type = 'player' AND p.is_active AND p.user_id IS NOT NULL
     AND p.user_id NOT IN (host, host2, pub_host)
     AND NOT public.is_admin(p.user_id) AND NOT public.is_frozen(p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE p.user_id IN (b.blocker_user_id, b.blocked_user_id))
     AND NOT EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id IN (g, g_cancel, pub) AND r.user_id = p.user_id)
     AND NOT EXISTS (SELECT 1 FROM public.game_waitlist w WHERE w.game_id IN (g, g_cancel, pub) AND w.user_id = p.user_id)
   ORDER BY p.created_at LIMIT 1;
  IF host IS NULL OR g_cancel IS NULL OR pub IS NULL OR u IS NULL THEN
    RAISE EXCEPTION 'fixture missing: host % cancel % pub % u %', host, g_cancel, pub, u;
  END IF;

  -- T1 host mints (plus an expired and an exhausted token for T6/T7)
  v := pg_temp.k939_as(host, format('SELECT public.rpc_mint_join_link(%L::uuid)::text', g));
  BEGIN t := v::uuid; EXCEPTION WHEN OTHERS THEN t := NULL; END;
  INSERT INTO k939_tap VALUES (1, t IS NOT NULL, 'host mints a join link', v);
  t_exp := pg_temp.k939_as(host, format('SELECT public.rpc_mint_join_link(%L::uuid)::text', g))::uuid;
  UPDATE public.game_link_tokens SET expires_at = now() - interval '1 minute' WHERE token = t_exp;
  t_used := pg_temp.k939_as(host, format('SELECT public.rpc_mint_join_link(%L::uuid, NULL, 1)::text', g))::uuid;
  UPDATE public.game_link_tokens SET used_count = 1 WHERE token = t_used;

  -- T2 / T3 with the token
  v := pg_temp.k939_as(u, format(card_sql, g, t));
  INSERT INTO k939_tap VALUES (2, v = '1:' || g, 'U + token sees the card', v);
  v := pg_temp.k939_as(u, format(dec_sql, g, t), false);
  INSERT INTO k939_tap VALUES (3, v = 'join_with_link/', 'U + token: decision join_with_link', v);

  -- T4 no token
  v := pg_temp.k939_as(u, format(join_sql, g, NULL)) || ' | ' || pg_temp.k939_as(u, format(card_sql, g, NULL))
       || ' | ' || pg_temp.k939_as(u, format(vis_sql, g));
  INSERT INTO k939_tap VALUES (4, v = denied || ' | 0: | 0', 'U without token: refused, no row', v);

  -- T5 wrong token
  v := pg_temp.k939_as(u, format(join_sql, g, gen_random_uuid())) || ' | ' || pg_temp.k939_as(u, format(card_sql, g, gen_random_uuid()));
  INSERT INTO k939_tap VALUES (5, v = denied || ' | 0:', 'U with wrong token: refused, no row', v);

  -- T6 expired token
  v := pg_temp.k939_as(u, format(join_sql, g, t_exp)) || ' | ' || pg_temp.k939_as(u, format(card_sql, g, t_exp));
  INSERT INTO k939_tap VALUES (6, v = denied || ' | 0:', 'U with expired token: refused, no row', v);

  -- T7 exhausted token
  v := pg_temp.k939_as(u, format(join_sql, g, t_used)) || ' | ' || pg_temp.k939_as(u, format(card_sql, g, t_used));
  INSERT INTO k939_tap VALUES (7, v = denied || ' | 0:', 'U with exhausted token: refused, no row', v);

  -- T8 join with the token; one use consumed; the plain view now shows the game to U as a roster member
  SELECT used_count INTO used0 FROM public.game_link_tokens WHERE token = t;
  v := pg_temp.k939_as(u, format(join_sql, g, t));
  SELECT used_count INTO used1 FROM public.game_link_tokens WHERE token = t;
  v := v || ' used ' || COALESCE(used0::text, '?') || '->' || COALESCE(used1::text, '?') || ' view ' || pg_temp.k939_as(u, format(vis_sql, g));
  INSERT INTO k939_tap VALUES (8, v = 'joined used 0->1 view 1', 'U + token joins; one use consumed', v);

  -- T9 cancelled link game with a valid token: the cancelled refusal still applies
  t_cancel := pg_temp.k939_as(host2, format('SELECT public.rpc_mint_join_link(%L::uuid)::text', g_cancel))::uuid;
  v := pg_temp.k939_as(u, format(join_sql, g_cancel, t_cancel));
  INSERT INTO k939_tap VALUES (9, v = 'ERR P0001 cancelled/cancelled', 'valid token on cancelled game: cancelled', v);

  -- T10 a block still wins over a valid token
  INSERT INTO public.user_blocks(blocker_user_id, blocked_user_id) VALUES (host2, u);
  v := pg_temp.k939_as(u, format(join_sql, g_cancel, t_cancel)) || ' | ' || pg_temp.k939_as(u, format(card_sql, g_cancel, t_cancel));
  INSERT INTO k939_tap VALUES (10, v = denied || ' | 0:', 'blocked + valid token: refused, no row', v);

  -- T11 public game path unchanged
  v := pg_temp.k939_as(u, format(join_sql, pub, NULL)) || ' | ' || pg_temp.k939_as(u, format(card_sql, pub, gen_random_uuid()));
  INSERT INTO k939_tap VALUES (11, v IN ('joined | 0:', 'waitlisted | 0:'), 'public open game joins without token; card RPC needs a token', v);

  -- T12 ACL and attributes
  SELECT format('auth=%s anon=%s public=%s definer=%s cfg=%s owner=%s',
                has_function_privilege('authenticated', p.oid, 'EXECUTE'),
                has_function_privilege('anon', p.oid, 'EXECUTE'),
                COALESCE(p.proacl::text LIKE '%{=X%' OR p.proacl::text LIKE '%,=X%', true),
                p.prosecdef, p.proconfig::text, p.proowner::regrole)
    INTO v FROM pg_proc p WHERE p.oid = to_regprocedure('public.rpc_game_card_by_link(uuid,uuid)');
  INSERT INTO k939_tap VALUES (12, v = 'auth=t anon=f public=f definer=t cfg={"search_path=public, pg_temp"} owner=postgres',
                               'card RPC ACL and attributes', COALESCE(v, 'function missing'));
END
$run$;

SELECT n, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status, label, detail FROM k939_tap ORDER BY n;

ROLLBACK;

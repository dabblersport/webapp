-- KAN-917 (KAN-714 chain stage W, KAN-866 follow-up; Epic KAN-708, Events P4):
-- public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid) stops READING the
-- games columns that KAN-866 (20261111120000_kan719b_drop_client_read_games_columns.sql) removes. Its writes to games
-- are not touched.
--
-- WHERE THE BODY COMES FROM. 20261030130000_kan694_rpc_series_edit_cancel.sql:35 created public.rpc_edit_game_series_occurrence;
-- 20261030140000 only checks it exists and pins grants; 20261103110000_kan712_cutover.sql:109 wrapped it (kan712_wrap_rpc,
-- lock spec game:p_game_id): the body was renamed to rpc_edit_game_series_occurrence_kan712_inner (owner-only EXECUTE) and
-- a generated public wrapper of the same signature took the name. 20261104101400_kan714_b14_series_rpc_reads.sql:264-312
-- replaced the body (unwrap -> CREATE OR REPLACE -> rewrap) and is the latest text: its post-pin
-- md5(pg_get_functiondef) = 5adf6e028e5a3407a145e014620f7757, reproduced locally from that text after the rename.
-- 20261104110300_kan718_d07_series_occurrence_unique.sql is newer but does NOT redefine it (it adds
-- kan718_series_occurrence_guard() and its triggers only, and names this RPC in a comment). No later file names it.
-- md5(prosrc) of the pre-image is 37c172cd1396ae272c4dd0555e883cf9.
--
-- THE PUBLIC TWIN public.rpc_edit_game_series_occurrence(...) is the KAN-712 generated wrapper (B14 pin
-- be3938f0b159dc143078453459882869): set_config kan712.contract, PERFORM ... FROM public.events e WHERE e.id = $1
-- AND e.event_type = 'game' FOR UPDATE, then calls this inner. It reads no games column, so it is NOT touched here.
--
-- WHY. KAN-866 removes 22 games columns (creator_profile_id, creator_user_id, title, start_at, end_at, capacity,
-- listing_visibility, join_policy, is_cancelled, cancelled_at, cancelled_reason, sport_id, area_id, geo_location_id,
-- venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id, created_at, updated_at).
-- READ RULE (QA ruling): a mention stays on games only as the bare SET target or a FOR UPDATE target; every other
-- mention is a read and moves to public.events e. Measured on the pre-image, every mention of the 22:
--   SELECT ... INTO g: e.is_cancelled, e.start_at, e.end_at (select list) and e.creator_user_id = v_uid (WHERE) already
--     read events (B14); FOR UPDATE OF g0 is the lock target and stays. g0.id / g0.series_id / g0.event_id: not in the 22.
--   g.is_cancelled, g.start_at (x3), g.end_at (x1): fields of the plpgsql RECORD g filled from e above, not games reads.
--   UPDATE public.games SET: title, start_at, end_at, capacity, updated_at as SET targets stay (updated_at = now());
--     RHS COALESCE(p_title, title) and COALESCE(p_capacity, capacity) READ games  -> e.title, e.capacity (the 2 changes).
--   WHERE id = g.id: id is not in the 22. venue_space_id is not in the 22 (left bare, as before; events has no such column).
--
-- WHAT. UPDATE public.games g1 SET ... FROM public.events e WHERE e.id = g1.event_id AND e.event_type = 'game'
-- AND g1.id = g.id, with the two fallbacks reading e. The alias is g1, not g: g is the function's RECORD variable and a
-- table alias g would be an ambiguous reference in PL/pgSQL. events.id is its primary key, so the join matches at most
-- one row, and the SELECT above already proved the parent exists: the same row is updated, exactly as before, while games
-- and events agree (KAN-711 parity). Unchanged: every SET target, venue_space_id = COALESCE(p_venue_space_id,
-- venue_space_id), series_id not in the SET (T-099), FOR UPDATE OF g0, the unique_violation -> occurrence_time_taken
-- handler, the not_authenticated / not_host_or_not_found / occurrence_not_editable / occurrence_time_invalid /
-- occurrence_capacity_invalid checks and the result jsonb; one comment line is added. Signature, defaults, RETURNS jsonb,
-- LANGUAGE plpgsql, VOLATILE, SECURITY DEFINER, SET search_path TO 'public', 'pg_temp' are unchanged; CREATE OR REPLACE
-- keeps oid, owner and ACL. No DROP, no CASCADE, no GRANT/REVOKE, no ALTER OWNER, no table, column, policy, trigger or
-- row touched.
--
-- ONLY WHERE PRESENT. If the inner is absent this migration raises a notice and does nothing.
--
-- T-058 SUBSTITUTE. Production is not read here. The guard pins md5(prosrc) to the pre-image above and refuses on
-- drift; re-author from pg_get_functiondef if it fires. The post check pins the new body and asserts that no read of
-- the 22 remains (no games-alias-qualified mention; a bare mention only as a SET target);
-- post md5(prosrc) eb1a06eb5a534c778530ddbc6ee549ca, md5(pg_get_functiondef) 1ae1bbf4f6fc68d1ef994b1c6592ae0d.
-- No BEGIN/COMMIT: the Supabase CLI runs each migration in one transaction (with psql use --single-transaction).
--
-- Applied live 2026-11-13 by backend-1 via execute_sql (TH-079). Live proof: supabase/tests/events_p4/kan714_w_rpc_edit_game_series_occurrence_kan712_inner_live_test.sql. Local proof:
--   supabase/tests/events_p4/kan714_w_rpc_edit_game_series_occurrence_kan712_inner_test.sql
--
-- ROLLBACK (after COMMIT). Run uncommented, in one transaction, as postgres. Pre-image, as pg_get_functiondef gives it
-- for 20261104101400:264-312 after the KAN-712 rename (md5(prosrc) 37c172cd1396ae272c4dd0555e883cf9,
-- md5(pg_get_functiondef) 5adf6e028e5a3407a145e014620f7757):
-- KAN917-ROLLBACK-BEGIN
-- CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_occurrence_kan712_inner(p_game_id uuid, p_title text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid)
--  RETURNS jsonb
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public', 'pg_temp'
-- AS $function$
-- DECLARE
--   v_uid uuid; g record; v_players int; v_start timestamptz; v_end timestamptz;
-- BEGIN
--   v_uid := public.effective_actor_uid();
--   IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;
--
--   -- KAN-733: owner, cancel state, start and end come from the events parent; the games row is still locked.
--   SELECT g0.id, g0.series_id, e.is_cancelled, e.start_at, e.end_at INTO g
--     FROM public.games g0
--     JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
--    WHERE g0.id = p_game_id AND g0.series_id IS NOT NULL AND e.creator_user_id = v_uid
--      FOR UPDATE OF g0;
--   IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;
--   IF g.is_cancelled OR g.start_at <= now() THEN
--     RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_not_editable';
--   END IF;
--
--   v_start := COALESCE(p_start_at, g.start_at);
--   v_end := COALESCE(p_end_at, v_start + (g.end_at - g.start_at));
--   IF v_start <= now() OR v_end <= v_start THEN
--     RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_invalid';
--   END IF;
--   IF p_capacity IS NOT NULL THEN
--     SELECT count(*) INTO v_players FROM public.game_roster r
--      WHERE r.game_id = g.id AND r.status = 'active' AND r.role IN ('player', 'sub');
--     IF p_capacity < 2 OR p_capacity > 64 OR p_capacity < v_players THEN
--       RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_capacity_invalid';
--     END IF;
--   END IF;
--
--   BEGIN
--     UPDATE public.games
--        SET title = COALESCE(p_title, title), start_at = v_start, end_at = v_end,
--            capacity = COALESCE(p_capacity, capacity), venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
--            updated_at = now()
--      WHERE id = g.id;   -- series_id deliberately not in the SET list (T-099)
--   EXCEPTION WHEN unique_violation THEN
--     RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_taken';
--   END;
--
--   RETURN jsonb_build_object('game_id', g.id, 'series_id', g.series_id);
-- END;
-- $function$;
-- KAN917-ROLLBACK-END

DO $kan917$
DECLARE
  c_sig  constant text := 'public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)';
  c_pre  constant text := '37c172cd1396ae272c4dd0555e883cf9';
  c_post constant text := 'eb1a06eb5a534c778530ddbc6ee549ca';
  c_cols constant text[] := '{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                              join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                              venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}';
  v_oid  oid;
  v_md5  text;
  v_before jsonb;
  v_after  jsonb;
  v_src  text;
  v_alt  text;
  v_bad  text;
BEGIN
  v_oid := to_regprocedure(c_sig);
  IF v_oid IS NULL THEN
    RAISE NOTICE 'KAN-917: rpc_edit_game_series_occurrence_kan712_inner absent; nothing to convert';
    RETURN;
  END IF;

  SELECT md5(prosrc) INTO v_md5 FROM pg_proc WHERE oid = v_oid;
  IF v_md5 <> c_pre THEN
    RAISE EXCEPTION 'KAN-917 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
      c_sig, v_md5, c_pre;
  END IF;

  SELECT jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    INTO v_before FROM pg_proc p WHERE p.oid = v_oid;
  IF NOT (v_before->>'secdef')::boolean THEN
    RAISE EXCEPTION 'KAN-917 pre: % is SECURITY INVOKER; stop and re-measure', c_sig;
  END IF;

  EXECUTE $ddl$
CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_occurrence_kan712_inner(p_game_id uuid, p_title text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; g record; v_players int; v_start timestamptz; v_end timestamptz;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  -- KAN-733: owner, cancel state, start and end come from the events parent; the games row is still locked.
  SELECT g0.id, g0.series_id, e.is_cancelled, e.start_at, e.end_at INTO g
    FROM public.games g0
    JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
   WHERE g0.id = p_game_id AND g0.series_id IS NOT NULL AND e.creator_user_id = v_uid
     FOR UPDATE OF g0;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;
  IF g.is_cancelled OR g.start_at <= now() THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_not_editable';
  END IF;

  v_start := COALESCE(p_start_at, g.start_at);
  v_end := COALESCE(p_end_at, v_start + (g.end_at - g.start_at));
  IF v_start <= now() OR v_end <= v_start THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_invalid';
  END IF;
  IF p_capacity IS NOT NULL THEN
    SELECT count(*) INTO v_players FROM public.game_roster r
     WHERE r.game_id = g.id AND r.status = 'active' AND r.role IN ('player', 'sub');
    IF p_capacity < 2 OR p_capacity > 64 OR p_capacity < v_players THEN
      RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_capacity_invalid';
    END IF;
  END IF;

  BEGIN
    -- KAN-917: the title / capacity fallbacks read the events parent e (authoritative); SET targets unchanged.
    UPDATE public.games g1
       SET title = COALESCE(p_title, e.title), start_at = v_start, end_at = v_end,
           capacity = COALESCE(p_capacity, e.capacity), venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
           updated_at = now()
      FROM public.events e
     WHERE e.id = g1.event_id AND e.event_type = 'game'
       AND g1.id = g.id;   -- series_id deliberately not in the SET list (T-099)
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_taken';
  END;

  RETURN jsonb_build_object('game_id', g.id, 'series_id', g.series_id);
END;
$function$
$ddl$;

  -- Post-conditions. Same oid (replaced in place), the authored body, unchanged attributes, no KAN-866 column read.
  IF to_regprocedure(c_sig) IS DISTINCT FROM v_oid THEN
    RAISE EXCEPTION 'KAN-917 post: % is not the same function oid after CREATE OR REPLACE', c_sig;
  END IF;
  SELECT md5(prosrc) INTO v_md5 FROM pg_proc WHERE oid = v_oid;
  IF v_md5 <> c_post THEN
    RAISE EXCEPTION 'KAN-917 post: % body md5 is %, expected %', c_sig, v_md5, c_post;
  END IF;
  SELECT jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    INTO v_after FROM pg_proc p WHERE p.oid = v_oid;
  IF v_after IS DISTINCT FROM v_before THEN
    RAISE EXCEPTION 'KAN-917 post: % attributes changed: % -> %', c_sig, v_before, v_after;
  END IF;
  -- Reads of the 22, comments stripped. (a) qualified by an alias bound to games ("games g0", "games g1");
  -- (b) bare, i.e. not after "." or a word character, and not a SET target ("<col> ="). e.<col> is events and g.<col> is
  -- the RECORD filled from events; neither matches.
  SELECT regexp_replace(prosrc, '--[^\n]*', '', 'g') INTO v_src FROM pg_proc WHERE oid = v_oid;
  v_alt := array_to_string(c_cols, '|');
  SELECT string_agg(DISTINCT hit, ', ') INTO v_bad FROM (
    SELECT lower(m[1] || '.' || m[2]) AS hit
      FROM regexp_matches(v_src, '\m([a-z_][a-z0-9_]*)\.(' || v_alt || ')\M', 'gi') m
     WHERE lower(m[1]) IN (SELECT lower(a[1]) FROM regexp_matches(v_src, '\mgames\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') a)
    UNION ALL
    SELECT 'bare ' || lower(m[1])
      FROM regexp_matches(v_src, '(?<![.\w])(' || v_alt || ')\M(?!\s*=)', 'gi') m) s;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-917 post: % still reads KAN-866 games column(s): %', c_sig, v_bad;
  END IF;
END
$kan917$;

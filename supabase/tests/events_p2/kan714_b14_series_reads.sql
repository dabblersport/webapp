-- KAN-733 (KAN-714 piece B14) — the series RPCs (rpc_edit_game_series_occurrence, rpc_edit_game_series_future,
-- rpc_cancel_game_series) read host, start, end and cancel state from public.events. All three are KAN-712-wrapped;
-- the migration changes their bodies via kan712_unwrap_rpc -> replace -> kan712_wrap_rpc, so the wrappers (D-*-wrapper,
-- S-*) must come back byte-identical and only the *_kan712_inner bodies differ. LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end.
--
-- Output: PASS|id|detail or FAIL|id|detail, then #SUMMARY|expect=|pass=|fail=, plus #PLAN| / #FINGERPRINT| lines.
-- Variable :expect selects which image is asserted:
--   post (default) — 20261104101400_kan714_b14_series_rpc_reads.sql applied.
--   pre            — legacy pre-image (no migration, or after rollback_kan714_b14.sql).
-- RED/GREEN protocol:
--   chain without migration, expect=post -> FAIL lines (D, P, X)          RED
--   chain without migration, expect=pre  -> 0 FAIL
--   chain with migration,    expect=post -> 0 FAIL                        GREEN
--   migration + rollback,    expect=pre  -> 0 FAIL, #FINGERPRINT| equal to the pre-migration DB
--
-- Groups: S shape/attributes, D definitions, L legacy parity (result + resulting series state, every RPC, success and
--         error paths), B non-host / anon / wrong-kind literals, Q (series_id, start_at) uniqueness, C counts / no
--         doubling, P provenance (events-only edits in replica mode), A access (events closed, inners closed),
--         K KAN-712 unwrap/wrap round-trip equivalence, X EXPLAIN shape.
-- Seed (rolled back): one weekly series of 4 future occurrences hosted by a1 (created through rpc_create_game_series
-- as authenticated), player a2 joined on occurrence 2, and an existing meetup (71400000-...-000000000190).
\set ON_ERROR_STOP 1
\set occ_post 5adf6e028e5a3407a145e014620f7757
\set occ_pre  76a813d1110538c2f3be870b65ead001
\set fut_post 58f7c53c076699063f4868ec6a461928
\set fut_pre  f10269f818183d9a3eb7289cbcff03a2
\set can_post 3efd11063a2140fadb93bfa50ea493c6
\set can_pre  ec5ee9a4f81371da8f49d57f0147eea4
\set occ_w ff5fc97a110d512d95e68702c4875377
\set fut_w ae0eb67d40f150276cca5e8d9483d812
\set can_w 5dfc8373693466514bcfca3e169aa932
\set a1 00000000-0000-0000-0000-0000000000a1
\set a2 00000000-0000-0000-0000-0000000000a2
\set a3 00000000-0000-0000-0000-0000000000a3
\set meetup 71400000-0000-0000-0001-000000000190
\if :{?expect}
\else
  \set expect post
\endif
BEGIN;
SELECT set_config('kan733.expect', :'expect', true);
SET LOCAL TimeZone = 'UTC';
CREATE TEMP TABLE res (n serial, id text, ok boolean, detail text);

CREATE FUNCTION pg_temp.post() RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('kan733.expect') = 'post' $$;
CREATE FUNCTION pg_temp.img(p_post text, p_pre text) RETURNS text LANGUAGE sql AS $$ SELECT CASE WHEN pg_temp.post() THEN p_post ELSE p_pre END $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_got text, p_want text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, ok, detail)
  VALUES (p_id, p_got IS NOT DISTINCT FROM p_want, 'got=' || coalesce(p_got, '<null>') || ' want=' || coalesce(p_want, '<null>'))
$$;
-- The state a series RPC can change: the series row and every occurrence (games + events), ids left out so rows the
-- generator creates with gen_random_uuid() compare by content. Also the occurrence count.
CREATE FUNCTION pg_temp.state(p_series uuid) RETURNS text LANGUAGE sql AS $$
  SELECT 'n=' || (SELECT count(*) FROM public.games WHERE series_id = p_series) || ' md5=' || md5(
    coalesce((SELECT (to_jsonb(s) - 'updated_at')::text FROM public.game_series s WHERE s.id = p_series), '') ||
    coalesce((SELECT string_agg(((to_jsonb(g) - 'id' - 'event_id') || (to_jsonb(e) - 'id' - 'search_tsv'))::text, '|'
                                ORDER BY g.start_at, g.title)
                FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id
               WHERE g.series_id = p_series), ''))
$$;
-- One call in a subtransaction that is ALWAYS rolled back. p_setup runs first as postgres with
-- session_replication_role = replica (an events-only edit: no mirror, no guard, no trigger fires). Then p_sql runs
-- under p_role (NULL = stay postgres) with JWT sub p_uid. Then p_after runs as postgres. Returns
-- '<result> |after=<p_after result>' or 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.run(p_role text, p_uid uuid, p_setup text, p_sql text, p_after text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; a text;
BEGIN
  BEGIN
    IF p_setup IS NOT NULL THEN
      PERFORM set_config('session_replication_role', 'replica', true);
      EXECUTE p_setup;
      PERFORM set_config('session_replication_role', 'origin', true);
    END IF;
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_sql INTO v;
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    IF p_after IS NOT NULL THEN EXECUTE p_after INTO a; v := coalesce(v, '<null>') || ' |after=' || coalesce(a, '<null>'); END IF;
    RAISE EXCEPTION 'kan733-rollback';
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    IF SQLERRM <> 'kan733-rollback' THEN v := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('session_replication_role', 'origin', true);
  RETURN coalesce(v, '<null>');
END $$;
CREATE FUNCTION pg_temp.plan(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE l text; o text := '';
BEGIN
  FOR l IN EXECUTE 'EXPLAIN (COSTS OFF) ' || p_sql LOOP o := o || l || E'\n'; END LOOP;
  RETURN o;
END $$;
CREATE FUNCTION pg_temp.cnt(p_hay text, p_re text) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM regexp_matches(p_hay, p_re, 'g')
$$;
CREATE FUNCTION pg_temp.norm(p text) RETURNS text LANGUAGE sql AS $$
  SELECT btrim(regexp_replace(regexp_replace(p, '--[^\n]*', '', 'g'), '\s+', ' ', 'g'))
$$;

-- Data fingerprint of every table the series RPCs read or write, BEFORE this script seeds anything.
SELECT '#FINGERPRINT|' || md5(
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.games x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.events x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.game_series x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.game_roster x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.meetups x)) AS fingerprint;

-- ---------------------------------------------------------------- S: shape and attributes (identical pre and post)
CREATE TEMP TABLE fns (k text, fn text, args text, inner_fn boolean);
INSERT INTO fns VALUES
 ('occ',   'rpc_edit_game_series_occurrence', 'p_game_id uuid, p_title text, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_capacity integer, p_venue_space_id uuid', false),
 ('fut',   'rpc_edit_game_series_future', 'p_series_id uuid, p_title text, p_capacity integer, p_start_time_local time without time zone, p_duration_minutes integer, p_venue_space_id uuid, p_ends_on date, p_clear_ends_on boolean', false),
 ('can',   'rpc_cancel_game_series', 'p_series_id uuid, p_reason text', false),
 ('occ-i', 'rpc_edit_game_series_occurrence_kan712_inner', 'p_game_id uuid, p_title text, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_capacity integer, p_venue_space_id uuid', true),
 ('fut-i', 'rpc_edit_game_series_future_kan712_inner', 'p_series_id uuid, p_title text, p_capacity integer, p_start_time_local time without time zone, p_duration_minutes integer, p_venue_space_id uuid, p_ends_on date, p_clear_ends_on boolean', true),
 ('can-i', 'rpc_cancel_game_series_kan712_inner', 'p_series_id uuid, p_reason text', true);
SELECT pg_temp.chk('S-' || f.k || '-' || k.k, k.got, k.want)
  FROM fns f
  CROSS JOIN LATERAL (SELECT p.* FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = f.fn) p
  CROSS JOIN LATERAL (VALUES
     ('n',      (SELECT count(*) FROM pg_proc q WHERE q.pronamespace = 'public'::regnamespace AND q.proname = f.fn)::text, '1'),
     ('args',   pg_get_function_identity_arguments(p.oid), f.args),
     ('result', pg_get_function_result(p.oid), 'jsonb'),
     ('secdef', p.prosecdef::text, 'true'),
     ('vol',    p.provolatile::text, 'v'),
     ('owner',  pg_get_userbyid(p.proowner), 'postgres'),
     ('lang',   (SELECT lanname FROM pg_language l WHERE l.oid = p.prolang)::text, 'plpgsql'),
     ('config', p.proconfig::text, CASE WHEN f.inner_fn THEN '{"search_path=public, pg_temp"}' ELSE '{"search_path=\"\"",kan712.contract=on}' END),
     ('acl',    p.proacl::text, CASE WHEN f.inner_fn THEN '{postgres=X/postgres}' ELSE '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' END)
  ) k(k, got, want)
 ORDER BY f.k, k.k;
-- KAN-712 control rows exactly as recorded (wrapped, not bare).
SELECT pg_temp.chk('S-wrapped-' || n, (SELECT inner_name || ' ' || lock_spec || ' ' || original_acl::text FROM public.kan712_wrapped_rpcs w WHERE w.name = n),
       want)
  FROM (VALUES ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_occurrence_kan712_inner game:p_game_id {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
               ('rpc_edit_game_series_future', 'rpc_edit_game_series_future_kan712_inner series:p_series_id {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
               ('rpc_cancel_game_series', 'rpc_cancel_game_series_kan712_inner series:p_series_id {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}')) t(n, want);
-- events posture
SELECT pg_temp.chk('S-events-closed',
       (SELECT relrowsecurity::text || relforcerowsecurity::text || (SELECT count(*) FROM pg_policy WHERE polrelid = 'public.events'::regclass)::text
               || has_table_privilege('anon', 'public.events', 'SELECT')::text || has_table_privilege('authenticated', 'public.events', 'SELECT')::text
          FROM pg_class WHERE oid = 'public.events'::regclass), 'truetrue0falsefalse');

-- ---------------------------------------------------------------- D: definitions (image under test)
SELECT pg_temp.chk('D-occ-inner', md5(pg_get_functiondef('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)'::regprocedure)), pg_temp.img(:'occ_post', :'occ_pre'));
SELECT pg_temp.chk('D-fut-inner', md5(pg_get_functiondef('public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time,integer,uuid,date,boolean)'::regprocedure)), pg_temp.img(:'fut_post', :'fut_pre'));
SELECT pg_temp.chk('D-can-inner', md5(pg_get_functiondef('public.rpc_cancel_game_series_kan712_inner(uuid,text)'::regprocedure)), pg_temp.img(:'can_post', :'can_pre'));
SELECT pg_temp.chk('D-occ-wrapper', md5(pg_get_functiondef('public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)'::regprocedure)), :'occ_w');
SELECT pg_temp.chk('D-fut-wrapper', md5(pg_get_functiondef('public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean)'::regprocedure)), :'fut_w');
SELECT pg_temp.chk('D-can-wrapper', md5(pg_get_functiondef('public.rpc_cancel_game_series(uuid,text)'::regprocedure)), :'can_w');
SELECT pg_temp.chk('D-untouched-' || fn, md5(pg_get_functiondef(fn::regprocedure)), md)
  FROM (VALUES ('public.fn_generate_game_series_occurrences(uuid)', '9502f276a2158bf9f57b6130a796ae29'),
               ('public.fn_generate_game_series_occurrences_kan712_inner(uuid)', '382e19ce66e66b1b0660f50163de36e3'),
               ('public.rpc_cancel_game(uuid,text)', 'bf9763ac173e917cab60949d801e86f2')) t(fn, md);

-- ---------------------------------------------------------------- legacy: the pre-image inner bodies, verbatim, in pg_temp
CREATE FUNCTION pg_temp.legacy_occ(p_game_id uuid, p_title text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; g public.games%ROWTYPE; v_players int; v_start timestamptz; v_end timestamptz;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO g FROM public.games WHERE id = p_game_id AND series_id IS NOT NULL AND creator_user_id = v_uid FOR UPDATE;
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
    UPDATE public.games
       SET title = COALESCE(p_title, title), start_at = v_start, end_at = v_end,
           capacity = COALESCE(p_capacity, capacity), venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
           updated_at = now()
     WHERE id = g.id;   -- series_id deliberately not in the SET list (T-099)
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_taken';
  END;

  RETURN jsonb_build_object('game_id', g.id, 'series_id', g.series_id);
END;
$function$;

CREATE FUNCTION pg_temp.legacy_fut(p_series_id uuid, p_title text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_start_time_local time without time zone DEFAULT NULL::time without time zone, p_duration_minutes integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid, p_ends_on date DEFAULT NULL::date, p_clear_ends_on boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_updated int := 0; v_cancelled int := 0;
  v_kept uuid[] := '{}'; v_time_changed boolean; v_topup int := 0; v_start timestamptz;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO s FROM public.game_series WHERE id = p_series_id AND creator_user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;
  IF s.status <> 'active' THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'series_not_active'; END IF;
  IF p_capacity IS NOT NULL AND (p_capacity < 2 OR p_capacity > 64) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_capacity_invalid';
  END IF;
  IF p_duration_minutes IS NOT NULL AND (p_duration_minutes <= 0 OR p_duration_minutes > 1440) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_invalid';
  END IF;
  IF p_ends_on IS NOT NULL AND p_ends_on < s.starts_on THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_invalid';
  END IF;

  v_time_changed := (p_start_time_local IS NOT NULL AND p_start_time_local <> s.start_time_local)
                 OR (p_duration_minutes IS NOT NULL AND p_duration_minutes <> s.duration_minutes);

  UPDATE public.game_series
     SET title = COALESCE(p_title, title), capacity = COALESCE(p_capacity, capacity),
         start_time_local = COALESCE(p_start_time_local, start_time_local),
         duration_minutes = COALESCE(p_duration_minutes, duration_minutes),
         venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
         ends_on = CASE WHEN p_clear_ends_on THEN NULL ELSE COALESCE(p_ends_on, ends_on) END,
         updated_at = now()
   WHERE id = s.id
   RETURNING * INTO s;

  FOR g IN
    SELECT id, start_at,
           EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS has_players
      FROM public.games
     WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false)
     ORDER BY start_at
       FOR UPDATE
  LOOP
    IF g.has_players THEN
      v_kept := v_kept || g.id;   -- never rewritten silently; returned to the client
    ELSIF s.ends_on IS NOT NULL AND (g.start_at AT TIME ZONE s.timezone)::date > s.ends_on THEN
      PERFORM public.rpc_cancel_game(g.id, 'series_ended_earlier');
      v_cancelled := v_cancelled + 1;
    ELSE
      v_start := ((g.start_at AT TIME ZONE s.timezone)::date + s.start_time_local) AT TIME ZONE s.timezone;
      UPDATE public.games
         SET title = s.title, capacity = s.capacity, venue_space_id = s.venue_space_id,
             start_at = v_start, end_at = v_start + make_interval(mins => s.duration_minutes), updated_at = now()
       WHERE id = g.id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  -- Top up the rolling window. Skipped when the time of day changed and a joined row kept its old time, because the
  -- generator matches existing rows by exact start_at and would add a second game on that day.
  IF NOT (v_time_changed AND cardinality(v_kept) > 0) THEN
    v_topup := public.fn_generate_game_series_occurrences(s.id);
  END IF;

  RETURN jsonb_build_object(
    'series_id', s.id, 'updated', v_updated, 'cancelled_after_end_date', v_cancelled, 'created', v_topup,
    'topup_skipped', (v_time_changed AND cardinality(v_kept) > 0),
    'kept_with_players', to_jsonb(v_kept));
END;
$function$;

CREATE FUNCTION pg_temp.legacy_can(p_series_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_cancelled int := 0; v_players int := 0; v_past int;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO s FROM public.game_series WHERE id = p_series_id AND creator_user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;

  UPDATE public.game_series SET status = 'ended', updated_at = now() WHERE id = s.id;

  FOR g IN
    SELECT id, (SELECT count(DISTINCT r.user_id) FROM public.game_roster r
                 WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS players
      FROM public.games
     WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false)
     ORDER BY start_at
       FOR UPDATE
  LOOP
    PERFORM public.rpc_cancel_game(g.id, COALESCE(p_reason, 'series_cancelled'));
    v_cancelled := v_cancelled + 1;
    v_players := v_players + g.players;
  END LOOP;

  SELECT count(*) INTO v_past FROM public.games WHERE series_id = s.id AND start_at <= now();

  RETURN jsonb_build_object('series_id', s.id, 'status', 'ended', 'cancelled', v_cancelled,
                            'player_notifications', v_players, 'past_kept', v_past);
END;
$function$;

SELECT pg_temp.chk('D-legacy-equals-pre-' || k, md5(replace(pg_get_functiondef(('pg_temp.legacy_' || k || a)::regprocedure),
                   'FUNCTION pg_temp.legacy_' || k || '(', 'FUNCTION public.' || n || '(')),
                   md)
  FROM (VALUES ('occ', '(uuid,text,timestamptz,timestamptz,integer,uuid)', 'rpc_edit_game_series_occurrence_kan712_inner', :'occ_pre'),
               ('fut', '(uuid,text,integer,time,integer,uuid,date,boolean)', 'rpc_edit_game_series_future_kan712_inner', :'fut_pre'),
               ('can', '(uuid,text)', 'rpc_cancel_game_series_kan712_inner', :'can_pre')) t(k, a, n, md);

-- ---------------------------------------------------------------- seed (rolled back with everything else)
SELECT set_config('request.jwt.claim.sub', :'a1', true);
SET LOCAL ROLE authenticated;
SELECT public.rpc_create_game_series('player', '00000000-0000-0000-0000-0000000000e1', NULL, '00000000-0000-0000-0000-0000000000d1',
       '00000000-0000-0000-0000-0000000000c1', (current_date + 7), '18:00', 60, 'UTC', 'weekly', 10, 'B14 series', NULL, NULL,
       'public', 'open', 4, 0) AS s \gset
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT max(id::text) FILTER (WHERE rn = 1) AS o1, max(id::text) FILTER (WHERE rn = 2) AS o2,
       max(id::text) FILTER (WHERE rn = 3) AS o3, max(id::text) FILTER (WHERE rn = 4) AS o4,
       max(start_at::text) FILTER (WHERE rn = 1) AS o1_start, count(*) AS n_occ
  FROM (SELECT id, start_at, row_number() OVER (ORDER BY start_at) rn FROM public.games WHERE series_id = :'s') t \gset
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
VALUES (:'o2', :'a2', '00000000-0000-0000-0000-0000000000b2', 'player', 'active');
SELECT pg_temp.chk('seed-occurrences', :'n_occ', '4');
SELECT pg_temp.chk('seed-meetup-is-meetup', (SELECT event_type FROM public.events WHERE id = :'meetup'), 'meetup');
SELECT format('pg_temp.state(%L)', :'s') AS st \gset
SELECT 'SELECT pg_temp.state(' || quote_literal(:'s') || ')' AS after_st \gset

-- ---------------------------------------------------------------- L: legacy parity — result and resulting state
-- Every call: live public wrapper vs the legacy body, both as postgres with the same JWT sub, each in its own
-- rolled-back subtransaction against the same database.
CREATE TEMP TABLE calls (id text, uid uuid, live text, legacy text);
INSERT INTO calls VALUES
 ('occ-title',        :'a1', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => %L)::text', :'o1', 'Renamed'),
                             format('SELECT pg_temp.legacy_occ(%L, p_title => %L)::text', :'o1', 'Renamed')),
 ('occ-start-only',   :'a1', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => %L::timestamptz + interval ''1 hour'')::text', :'o3', :'o1_start'),
                             format('SELECT pg_temp.legacy_occ(%L, p_start_at => %L::timestamptz + interval ''1 hour'')::text', :'o3', :'o1_start')),
 ('occ-capacity',     :'a1', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_capacity => 12)::text', :'o2'),
                             format('SELECT pg_temp.legacy_occ(%L, p_capacity => 12)::text', :'o2')),
 ('occ-capacity-bad', :'a1', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_capacity => 1)::text', :'o2'),
                             format('SELECT pg_temp.legacy_occ(%L, p_capacity => 1)::text', :'o2')),
 ('occ-time-past',    :'a1', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => now() - interval ''1 day'')::text', :'o1'),
                             format('SELECT pg_temp.legacy_occ(%L, p_start_at => now() - interval ''1 day'')::text', :'o1')),
 ('occ-time-taken',   :'a1', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => %L)::text', :'o2', :'o1_start'),
                             format('SELECT pg_temp.legacy_occ(%L, p_start_at => %L)::text', :'o2', :'o1_start')),
 ('fut-title',        :'a1', format('SELECT public.rpc_edit_game_series_future(%L, p_title => %L)::text', :'s', 'New'),
                             format('SELECT pg_temp.legacy_fut(%L, p_title => %L)::text', :'s', 'New')),
 ('fut-time',         :'a1', format('SELECT public.rpc_edit_game_series_future(%L, p_start_time_local => ''19:30'', p_duration_minutes => 90)::text', :'s'),
                             format('SELECT pg_temp.legacy_fut(%L, p_start_time_local => ''19:30'', p_duration_minutes => 90)::text', :'s')),
 ('fut-ends-on',      :'a1', format('SELECT public.rpc_edit_game_series_future(%L, p_ends_on => current_date + 15)::text', :'s'),
                             format('SELECT pg_temp.legacy_fut(%L, p_ends_on => current_date + 15)::text', :'s')),
 ('fut-cap-bad',      :'a1', format('SELECT public.rpc_edit_game_series_future(%L, p_capacity => 99)::text', :'s'),
                             format('SELECT pg_temp.legacy_fut(%L, p_capacity => 99)::text', :'s')),
 ('can',              :'a1', format('SELECT public.rpc_cancel_game_series(%L)::text', :'s'),
                             format('SELECT pg_temp.legacy_can(%L)::text', :'s')),
 ('can-reason',       :'a1', format('SELECT public.rpc_cancel_game_series(%L, %L)::text', :'s', 'rain'),
                             format('SELECT pg_temp.legacy_can(%L, %L)::text', :'s', 'rain')),
 ('can-ended-series', :'a2', format('SELECT public.rpc_cancel_game_series(%L)::text', '00000000-0000-0000-0000-0000000000f1'),
                             format('SELECT pg_temp.legacy_can(%L)::text', '00000000-0000-0000-0000-0000000000f1')),
 -- B: non-host, joined player, anon, a meetup id, an unknown id
 ('B-occ-nonhost',    :'a3', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''x'')::text', :'o1'),
                             format('SELECT pg_temp.legacy_occ(%L, p_title => ''x'')::text', :'o1')),
 ('B-occ-player',     :'a2', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''x'')::text', :'o2'),
                             format('SELECT pg_temp.legacy_occ(%L, p_title => ''x'')::text', :'o2')),
 ('B-occ-anon',       NULL,  format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''x'')::text', :'o1'),
                             format('SELECT pg_temp.legacy_occ(%L, p_title => ''x'')::text', :'o1')),
 ('B-occ-meetup',     :'a1', format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''x'')::text', :'meetup'),
                             format('SELECT pg_temp.legacy_occ(%L, p_title => ''x'')::text', :'meetup')),
 ('B-occ-unknown',    :'a1', 'SELECT public.rpc_edit_game_series_occurrence(gen_random_uuid(), p_title => ''x'')::text',
                             'SELECT pg_temp.legacy_occ(gen_random_uuid(), p_title => ''x'')::text'),
 ('B-fut-nonhost',    :'a3', format('SELECT public.rpc_edit_game_series_future(%L, p_title => ''x'')::text', :'s'),
                             format('SELECT pg_temp.legacy_fut(%L, p_title => ''x'')::text', :'s')),
 ('B-fut-anon',       NULL,  format('SELECT public.rpc_edit_game_series_future(%L, p_title => ''x'')::text', :'s'),
                             format('SELECT pg_temp.legacy_fut(%L, p_title => ''x'')::text', :'s')),
 ('B-can-nonhost',    :'a3', format('SELECT public.rpc_cancel_game_series(%L)::text', :'s'),
                             format('SELECT pg_temp.legacy_can(%L)::text', :'s')),
 ('B-can-player',     :'a2', format('SELECT public.rpc_cancel_game_series(%L)::text', :'s'),
                             format('SELECT pg_temp.legacy_can(%L)::text', :'s')),
 ('B-can-anon',       NULL,  format('SELECT public.rpc_cancel_game_series(%L)::text', :'s'),
                             format('SELECT pg_temp.legacy_can(%L)::text', :'s')),
 ('B-can-meetup',     :'a1', format('SELECT public.rpc_cancel_game_series(%L)::text', :'meetup'),
                             format('SELECT pg_temp.legacy_can(%L)::text', :'meetup'));
CREATE TEMP TABLE outc AS
SELECT id, pg_temp.run(NULL, uid, NULL, live, :'after_st') AS live_out, pg_temp.run(NULL, uid, NULL, legacy, :'after_st') AS legacy_out
  FROM calls;
SELECT pg_temp.chk(CASE WHEN id LIKE 'B-%' THEN id ELSE 'L-' || id END, live_out, legacy_out) FROM outc ORDER BY id;
-- the error literals themselves (unchanged contract with the app)
SELECT pg_temp.chk('B-literal-' || id, live_out, want)
  FROM outc JOIN (VALUES ('B-occ-nonhost', 'ERR P0001 not_host_or_not_found'), ('B-occ-player', 'ERR P0001 not_host_or_not_found'),
                         ('B-occ-anon', 'ERR P0001 not_authenticated'), ('B-occ-meetup', 'ERR P0001 not_host_or_not_found'),
                         ('B-occ-unknown', 'ERR P0001 not_host_or_not_found'), ('B-fut-nonhost', 'ERR P0001 not_host_or_not_found'),
                         ('B-fut-anon', 'ERR P0001 not_authenticated'), ('B-can-nonhost', 'ERR P0001 not_host_or_not_found'),
                         ('B-can-player', 'ERR P0001 not_host_or_not_found'), ('B-can-anon', 'ERR P0001 not_authenticated'),
                         ('B-can-meetup', 'ERR P0001 not_host_or_not_found'),
                         ('occ-capacity-bad', 'ERR P0001 occurrence_capacity_invalid'), ('occ-time-past', 'ERR P0001 occurrence_time_invalid'),
                         ('fut-cap-bad', 'ERR P0001 series_capacity_invalid')) w(i, want) ON w.i = outc.id;
-- success paths really succeeded (a parity of two identical errors would prove nothing)
SELECT pg_temp.chk('L-success-' || id, (live_out NOT LIKE 'ERR%' AND live_out LIKE '{%')::text, 'true')
  FROM outc WHERE id IN ('occ-title', 'occ-start-only', 'occ-capacity', 'fut-title', 'fut-time', 'fut-ends-on', 'can', 'can-reason', 'can-ended-series');
-- and they changed something (the state after differs from the state before)
SELECT pg_temp.chk('L-changed-' || id, (split_part(live_out, ' |after=', 2) <> pg_temp.state(:'s'))::text, 'true')
  FROM outc WHERE id IN ('occ-title', 'occ-start-only', 'occ-capacity', 'fut-title', 'fut-time', 'fut-ends-on', 'can', 'can-reason');
-- the results themselves (kept_with_players carries a seeded id, so this pins shape AND values)
SELECT pg_temp.chk('L-shape-' || id, split_part(live_out, ' |after=', 1), want)
  FROM outc JOIN (VALUES
     ('occ-title', jsonb_build_object('game_id', :'o1'::uuid, 'series_id', :'s'::uuid)::text),
     ('can', jsonb_build_object('series_id', :'s'::uuid, 'status', 'ended', 'cancelled', 4, 'player_notifications', 1, 'past_kept', 0)::text),
     ('fut-title', jsonb_build_object('series_id', :'s'::uuid, 'updated', 3, 'cancelled_after_end_date', 0, 'created', 0,
                                      'topup_skipped', false, 'kept_with_players', jsonb_build_array(:'o2'::uuid))::text)) w(i, want) ON w.i = outc.id;

-- ---------------------------------------------------------------- Q: (series_id, start_at) uniqueness still enforced
SELECT pg_temp.chk('Q-occ-time-taken', (SELECT live_out FROM outc WHERE id = 'occ-time-taken'), 'ERR P0001 occurrence_time_taken');
SELECT pg_temp.chk('Q-direct-games', left(pg_temp.run(NULL, NULL, NULL,
         format('UPDATE public.games SET start_at = %L WHERE id = %L RETURNING 1', :'o1_start', :'o2'), NULL), 9), 'ERR 23505');
SELECT pg_temp.chk('Q-direct-events', left(pg_temp.run(NULL, NULL, NULL,
         format('UPDATE public.events SET start_at = %L WHERE id = %L RETURNING 1', :'o1_start', :'o2'), NULL), 9), 'ERR 23505');
SELECT pg_temp.chk('Q-no-dup-after-' || id, split_part(pg_temp.run(NULL, :'a1'::uuid, NULL, live,
         format('SELECT (count(*) - count(DISTINCT start_at))::text FROM public.games WHERE series_id = %L', :'s')), ' |after=', 2), '0')
  FROM calls WHERE id IN ('fut-time', 'fut-title', 'occ-start-only');

-- ---------------------------------------------------------------- C: counts and no doubling
SELECT pg_temp.chk('C-occurrences-' || id, split_part(pg_temp.run(NULL, :'a1'::uuid, NULL, live,
         format('SELECT (SELECT count(*) FROM public.games WHERE series_id = %1$L) || ''/'' || (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = ''game'' WHERE g.series_id = %1$L)', :'s')), ' |after=', 2),
       split_part(pg_temp.run(NULL, :'a1'::uuid, NULL, legacy,
         format('SELECT (SELECT count(*) FROM public.games WHERE series_id = %1$L) || ''/'' || (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = ''game'' WHERE g.series_id = %1$L)', :'s')), ' |after=', 2))
  FROM calls WHERE id IN ('fut-title', 'fut-time', 'fut-ends-on', 'can');
SELECT pg_temp.chk('C-cancel-counts-' || k, (split_part((SELECT live_out FROM outc WHERE id = 'can'), ' |after=', 1)::jsonb ->> k),
       (split_part((SELECT legacy_out FROM outc WHERE id = 'can'), ' |after=', 1)::jsonb ->> k))
  FROM unnest(ARRAY['cancelled', 'player_notifications', 'past_kept']) k;
SELECT pg_temp.chk('C-ended-series-past-kept', split_part((SELECT live_out FROM outc WHERE id = 'can-ended-series'), ' |after=', 1)::jsonb ->> 'past_kept',
       (SELECT count(*)::text FROM public.games WHERE series_id = '00000000-0000-0000-0000-0000000000f1' AND start_at <= now()));

-- ---------------------------------------------------------------- P: provenance — events-only edits (replica mode,
-- rolled back), then the live RPC. post: the events value decides; pre: the games value decides.
CREATE TEMP TABLE prov (id text, uid uuid, setup text, sql text, after text, want_post text, want_pre text);
INSERT INTO prov VALUES
 -- events says the occurrence is cancelled; games says it is not
 ('P-occ-cancelled', :'a1', format('UPDATE public.events SET is_cancelled = true WHERE id = %L', :'o1'),
   format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''p'')::text', :'o1'), NULL,
   'ERR P0001 occurrence_not_editable', jsonb_build_object('game_id', :'o1'::uuid, 'series_id', :'s'::uuid)::text),
 -- events says a3 hosts the occurrence; games says a1
 ('P-occ-host-a3', :'a3', format('UPDATE public.events SET creator_user_id = %L WHERE id = %L', :'a3', :'o1'),
   format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''p'')::text', :'o1'), NULL,
   jsonb_build_object('game_id', :'o1'::uuid, 'series_id', :'s'::uuid)::text, 'ERR P0001 not_host_or_not_found'),
 ('P-occ-host-a1', :'a1', format('UPDATE public.events SET creator_user_id = %L WHERE id = %L', :'a3', :'o1'),
   format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''p'')::text', :'o1'), NULL,
   'ERR P0001 not_host_or_not_found', jsonb_build_object('game_id', :'o1'::uuid, 'series_id', :'s'::uuid)::text),
 -- events says the occurrence already started; games says it is in the future
 ('P-occ-started', :'a1', format('UPDATE public.events SET start_at = now() - interval ''1 hour'' WHERE id = %L', :'o1'),
   format('SELECT public.rpc_edit_game_series_occurrence(%L, p_title => ''p'')::text', :'o1'), NULL,
   'ERR P0001 occurrence_not_editable', jsonb_build_object('game_id', :'o1'::uuid, 'series_id', :'s'::uuid)::text),
 -- events says the occurrence lasts 2h; games says 1h: a start-only edit keeps the events duration
 ('P-occ-duration', :'a1', format('UPDATE public.events SET end_at = start_at + interval ''2 hours'' WHERE id = %L', :'o3'),
   format('SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => %L::timestamptz + interval ''1 hour'')::text', :'o3', :'o1_start'),
   format('SELECT (end_at - start_at)::text FROM public.events WHERE id = %L', :'o3'),
   jsonb_build_object('game_id', :'o3'::uuid, 'series_id', :'s'::uuid)::text || ' |after=02:00:00',
   jsonb_build_object('game_id', :'o3'::uuid, 'series_id', :'s'::uuid)::text || ' |after=01:00:00'),
 -- future edit: events says o3 is cancelled (skipped), and o1's host is a3 (so a1's host row counts as a player: kept)
 ('P-fut-cancelled', :'a1', format('UPDATE public.events SET is_cancelled = true WHERE id = %L', :'o3'),
   format('SELECT (public.rpc_edit_game_series_future(%L, p_title => ''p'') ->> ''updated'')', :'s'), NULL, '2', '3'),
 ('P-fut-host', :'a1', format('UPDATE public.events SET creator_user_id = %L WHERE id = %L', :'a3', :'o1'),
   format('SELECT (public.rpc_edit_game_series_future(%L, p_title => ''p'') -> ''kept_with_players'')::text', :'s'), NULL,
   jsonb_build_array(:'o1'::uuid, :'o2'::uuid)::text, jsonb_build_array(:'o2'::uuid)::text),
 ('P-fut-start-past', :'a1', format('UPDATE public.events SET start_at = now() - interval ''1 hour'' WHERE id = %L', :'o4'),
   format('SELECT (public.rpc_edit_game_series_future(%L, p_title => ''p'') ->> ''updated'')', :'s'), NULL, '2', '3'),
 -- cancel: events says o4 already happened (kept as past, not cancelled), o3 is cancelled (skipped)
 ('P-can-start-past', :'a1', format('UPDATE public.events SET start_at = now() - interval ''1 hour'' WHERE id = %L', :'o4'),
   format('SELECT (public.rpc_cancel_game_series(%L) - ''series_id'' - ''status'')::text', :'s'), NULL,
   '{"cancelled": 3, "past_kept": 1, "player_notifications": 1}', '{"cancelled": 4, "past_kept": 0, "player_notifications": 1}'),
 ('P-can-cancelled', :'a1', format('UPDATE public.events SET is_cancelled = true WHERE id = %L', :'o3'),
   format('SELECT (public.rpc_cancel_game_series(%L) ->> ''cancelled'')', :'s'), NULL, '3', '4'),
 -- cancel: events says a2 hosts o2, so a2 is not a player there and a1 (host row) is
 ('P-can-host', :'a1', format('UPDATE public.events SET creator_user_id = %L WHERE id = %L', :'a3', :'o1'),
   format('SELECT (public.rpc_cancel_game_series(%L) ->> ''player_notifications'')', :'s'), NULL, '2', '1');
SELECT pg_temp.chk(id, pg_temp.run(NULL, uid, setup, sql, after), pg_temp.img(want_post, want_pre)) FROM prov ORDER BY id;
-- the setup really is events-only: games still holds the legacy value inside the same step
SELECT pg_temp.chk('P-setup-events-only', pg_temp.run(NULL, NULL, format('UPDATE public.events SET is_cancelled = true WHERE id = %L', :'o1'),
         format('SELECT g.is_cancelled::text || ''/'' || e.is_cancelled::text FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = %L', :'o1'), NULL),
       'false/true');

-- ---------------------------------------------------------------- A: access
-- an authenticated host gets exactly what the postgres-run call returns
SELECT pg_temp.chk('A-authenticated-' || c.id, pg_temp.run('authenticated', c.uid, NULL, c.live, :'after_st'), o.live_out)
  FROM calls c JOIN outc o USING (id) WHERE c.id IN ('occ-title', 'fut-title', 'can', 'B-occ-nonhost', 'B-can-nonhost');
SELECT pg_temp.chk('A-anon-wrapper', left(pg_temp.run('anon', NULL, NULL, format('SELECT public.rpc_cancel_game_series(%L)::text', :'s'), NULL), 9), 'ERR 42501');
SELECT pg_temp.chk('A-authenticated-inner-' || n, left(pg_temp.run('authenticated', :'a1'::uuid, NULL,
         format('SELECT public.%s(%L)::text', n, CASE WHEN n LIKE '%occurrence%' THEN :'o1' ELSE :'s' END), NULL), 9), 'ERR 42501')
  FROM unnest(ARRAY['rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner', 'rpc_cancel_game_series_kan712_inner']) n;
SELECT pg_temp.chk('A-authenticated-events', left(pg_temp.run('authenticated', :'a1'::uuid, NULL, 'SELECT count(*)::text FROM public.events', NULL), 9), 'ERR 42501');

-- ---------------------------------------------------------------- K: KAN-712 unwrap -> wrap round trip (rolled back)
-- The contract's own path (the one the migration and the rollback use) regenerates a wrapper identical to the
-- installed one (byte for byte, same ACL) and leaves the inner body as it is.
CREATE TEMP TABLE k_before AS
  SELECT p.proname::text AS fn, md5(pg_get_functiondef(p.oid)) AS md, p.proacl::text AS acl, p.proconfig::text AS cfg
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                       'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner', 'rpc_cancel_game_series_kan712_inner');
SAVEPOINT k;
SELECT count(*) AS k_unwrapped FROM (SELECT public.kan712_unwrap_rpc(w.name, w.identity_args) FROM public.kan712_wrapped_rpcs w
 WHERE w.name IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series')) z \gset
SELECT count(*) AS k_wrapped FROM (SELECT public.kan712_wrap_rpc(f::regprocedure, l) FROM (VALUES
   ('public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)', 'game:p_game_id'),
   ('public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean)', 'series:p_series_id'),
   ('public.rpc_cancel_game_series(uuid,text)', 'series:p_series_id')) t(f, l)) z \gset
SELECT string_agg(p.proname || '=' || md5(pg_get_functiondef(p.oid)) || ' ' || p.proacl::text || ' ' || p.proconfig::text, '; ' ORDER BY p.proname) AS k_after
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                     'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner', 'rpc_cancel_game_series_kan712_inner') \gset
ROLLBACK TO SAVEPOINT k;
SELECT pg_temp.chk('K-unwrapped-wrapped', :'k_unwrapped' || '/' || :'k_wrapped', '3/3');
SELECT pg_temp.chk('K-roundtrip-wrappers-and-inners', :'k_after',
       (SELECT string_agg(fn || '=' || md || ' ' || acl || ' ' || cfg, '; ' ORDER BY fn) FROM k_before));
SELECT pg_temp.chk('K-rolled-back', (SELECT count(*) FROM k_before b
                                      WHERE md5(pg_get_functiondef(to_regproc('public.' || b.fn))) = b.md)::text, '6');

-- ---------------------------------------------------------------- X: EXPLAIN shape — no new per-row SubPlans
CREATE TEMP TABLE xs (id text, fn regprocedure, pre_frag text, post_frag text, pre_sql text, post_sql text);
INSERT INTO xs VALUES
 ('occ-lock', 'public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)',
  'SELECT * INTO g FROM public.games WHERE id = p_game_id AND series_id IS NOT NULL AND creator_user_id = v_uid FOR UPDATE;',
  'SELECT g0.id, g0.series_id, e.is_cancelled, e.start_at, e.end_at INTO g FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = ''game'' WHERE g0.id = p_game_id AND g0.series_id IS NOT NULL AND e.creator_user_id = v_uid FOR UPDATE OF g0;',
  'SELECT * FROM public.games WHERE id = @g AND series_id IS NOT NULL AND creator_user_id = @u FOR UPDATE',
  'SELECT g0.id, g0.series_id, e.is_cancelled, e.start_at, e.end_at FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = ''game'' WHERE g0.id = @g AND g0.series_id IS NOT NULL AND e.creator_user_id = @u FOR UPDATE OF g0'),
 ('fut-loop', 'public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time,integer,uuid,date,boolean)',
  'WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false) ORDER BY start_at FOR UPDATE LOOP IF g.has_players',
  'JOIN public.events e ON e.id = games.event_id AND e.event_type = ''game'' WHERE games.series_id = s.id AND e.start_at > now() AND NOT COALESCE(e.is_cancelled, false) ORDER BY e.start_at FOR UPDATE OF games LOOP IF g.has_players',
  'SELECT id, start_at, EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS has_players FROM public.games WHERE series_id = @s AND start_at > now() AND NOT COALESCE(is_cancelled, false) ORDER BY start_at FOR UPDATE',
  'SELECT games.id, e.start_at, EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> e.creator_user_id) AS has_players FROM public.games JOIN public.events e ON e.id = games.event_id AND e.event_type = ''game'' WHERE games.series_id = @s AND e.start_at > now() AND NOT COALESCE(e.is_cancelled, false) ORDER BY e.start_at FOR UPDATE OF games'),
 ('can-loop', 'public.rpc_cancel_game_series_kan712_inner(uuid,text)',
  'WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false) ORDER BY start_at FOR UPDATE LOOP PERFORM',
  'JOIN public.events e ON e.id = games.event_id AND e.event_type = ''game'' WHERE games.series_id = s.id AND e.start_at > now() AND NOT COALESCE(e.is_cancelled, false) ORDER BY e.start_at FOR UPDATE OF games LOOP PERFORM',
  'SELECT id, (SELECT count(DISTINCT r.user_id) FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS players FROM public.games WHERE series_id = @s AND start_at > now() AND NOT COALESCE(is_cancelled, false) ORDER BY start_at FOR UPDATE',
  'SELECT games.id, (SELECT count(DISTINCT r.user_id) FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> e.creator_user_id) AS players FROM public.games JOIN public.events e ON e.id = games.event_id AND e.event_type = ''game'' WHERE games.series_id = @s AND e.start_at > now() AND NOT COALESCE(e.is_cancelled, false) ORDER BY e.start_at FOR UPDATE OF games'),
 ('can-past', 'public.rpc_cancel_game_series_kan712_inner(uuid,text)',
  'SELECT count(*) INTO v_past FROM public.games WHERE series_id = s.id AND start_at <= now();',
  'SELECT count(*) INTO v_past FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = ''game'' WHERE g0.series_id = s.id AND e.start_at <= now();',
  'SELECT count(*) FROM public.games WHERE series_id = @s AND start_at <= now()',
  'SELECT count(*) FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = ''game'' WHERE g0.series_id = @s AND e.start_at <= now()');
SELECT pg_temp.chk('X-' || id || '-installed', (position(pg_temp.img(post_frag, pre_frag) IN pg_temp.norm(p.prosrc)) > 0)::text, 'true')
  FROM xs JOIN pg_proc p ON p.oid = xs.fn ORDER BY id;
SELECT pg_temp.chk('X-' || id || '-other-image-absent', (position(pg_temp.img(pre_frag, post_frag) IN pg_temp.norm(p.prosrc)) > 0)::text, 'false')
  FROM xs JOIN pg_proc p ON p.oid = xs.fn ORDER BY id;
CREATE TEMP TABLE xp AS
SELECT id,
       pg_temp.plan(replace(replace(replace(pre_sql,  '@g', quote_literal(:'o1') || '::uuid'), '@u', quote_literal(:'a1') || '::uuid'), '@s', quote_literal(:'s') || '::uuid')) AS pre_plan,
       pg_temp.plan(replace(replace(replace(post_sql, '@g', quote_literal(:'o1') || '::uuid'), '@u', quote_literal(:'a1') || '::uuid'), '@s', quote_literal(:'s') || '::uuid')) AS post_plan
  FROM xs;
SELECT '#PLAN|' || id || '|pre|subplans=' || pg_temp.cnt(pre_plan, 'SubPlan') || '|events=' || pg_temp.cnt(pre_plan, ' on events ')
       || '|post|subplans=' || pg_temp.cnt(post_plan, 'SubPlan') || '|events=' || pg_temp.cnt(post_plan, ' on events ')
  FROM xp ORDER BY id;
SELECT pg_temp.chk('X-' || id || '-subplans-equal', pg_temp.cnt(post_plan, 'SubPlan')::text, pg_temp.cnt(pre_plan, 'SubPlan')::text) FROM xp ORDER BY id;
SELECT pg_temp.chk('X-' || id || '-events-scanned-once', pg_temp.cnt(post_plan, ' on events ')::text, '1') FROM xp ORDER BY id;
SELECT pg_temp.chk('X-' || id || '-no-events-subplan', (post_plan ~ 'SubPlan[^\n]*\n(\s+->[^\n]*\n)*?\s+->\s+[^\n]* on events ')::text, 'false') FROM xp ORDER BY id;

-- ---------------------------------------------------------------- report
SELECT CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END || '|' || id || '|' || detail FROM res ORDER BY n;
SELECT '#SUMMARY|expect=' || current_setting('kan733.expect') || '|pass=' || count(*) FILTER (WHERE ok) || '|fail=' || count(*) FILTER (WHERE NOT ok) FROM res;
ROLLBACK;

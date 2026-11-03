-- KAN-733 (KAN-714 piece B14, Epic KAN-708) — the series RPCs of 20261030130000_kan694_rpc_series_edit_cancel.sql
-- read their SHARED game facts (host, start, end, cancel state) from public.events.
--
-- AUTHORED, NOT APPLIED. Local proof only: supabase/tests/events_p2/kan714_b14_series_reads.sql.
-- Rollback: supabase/tests/events_p2/rollback_kan714_b14.sql (restores the pre-images below, verbatim).
--
-- KAN-712: ALL THREE RPCs ARE WRAPPED (kan712_wrapped_rpcs rows; KAN712_CONTRACT.md manifest rows 6-8). The public
-- name is the generated wrapper (SECURITY DEFINER, search_path '', kan712.contract=on) that takes the events row
-- locks first and then calls <name>_kan712_inner, which IS the original body renamed (kan712_wrap_rpc, T-058).
-- This migration therefore never touches a public name: no bare CREATE OR REPLACE of a wrapper. It replaces ONLY
-- the three *_kan712_inner bodies, in place. CREATE OR REPLACE keeps each inner's oid, owner (postgres) and ACL
-- ({postgres=X/postgres}: no API role can call an inner), so the wrapper, its ACL, its lock statement and the
-- kan712_wrapped_rpcs rows (wrapped_at included) stay byte-identical — asserted below. The contract's own
-- kan712_unwrap_rpc + kan712_wrap_rpc round trip yields the same wrapper text (it is generated from signature and
-- attributes only, never from the body), proved in the test (group K), but it DROPs the wrapper and deletes and
-- re-inserts the control row; this piece is no-DROP / no-data-mutation, so the in-place inner path is used.
--
-- PRE-IMAGE: authored from pg_get_functiondef of the *_kan712_inner functions on the KAN-713 stage catalogue
-- (T-058), not from the migration file. Their bodies equal 20261030130000 lines 35-221 (only the name differs).
--
-- SCOPE, per function (every function in 20261030130000; nothing else is defined there):
--   rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)
--       REPOINTED. The host check (creator_user_id), is_cancelled, start_at and end_at of the occurrence come from
--       events; the games row is still locked (FOR UPDATE OF g0). g changes from games%ROWTYPE to a record of
--       (id, series_id, is_cancelled, start_at, end_at): only those fields were ever read. series_id stays on games
--       (subtype-only column). Errors, their order and the result jsonb verbatim.
--   rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time,integer,uuid,date,boolean)
--       REPOINTED. The occurrence loop: start_at, is_cancelled and the host (for "joined player" = roster user who is
--       not the host) come from events; games rows still locked (FOR UPDATE OF games). Series template reads stay on
--       game_series (not an events subtype). The top-up call and the result jsonb verbatim.
--   rpc_cancel_game_series_kan712_inner(uuid,text)
--       REPOINTED. The occurrence loop as above (player count excludes the host from events), and past_kept counts
--       occurrences by events.start_at. Status write, rpc_cancel_game calls and the result jsonb verbatim.
--   WRITES ARE NOT TOUCHED: every UPDATE public.games / public.game_series statement, and every call to
--   rpc_cancel_game / fn_generate_game_series_occurrences, is the pre-image verbatim (KAN-712 write contract: the
--   guard routes a games shared-field UPDATE through events under kan712.contract=on). The SET-list expressions
--   COALESCE(p_x, <games column>) are part of those write statements and are left as they are. No dual write.
--   The three public wrappers: UNCHANGED, pinned. fn_generate_game_series_occurrences and rpc_cancel_game: not in
--   20261030130000, UNCHANGED, pinned.
--
-- UNIQUENESS: the occurrence invariant (series_id, start_at) is enforced by games_series_id_start_at_key and by the
-- KAN-718 guard on events (kan718_series_occurrence_unique). Both are untouched; the occurrence edit still maps a
-- unique_violation to 'occurrence_time_taken' (test group Q).
-- JOIN: games g JOIN events e ON e.id = g.event_id AND e.event_type = 'game'. events.id is the PK, so 1:0..1. The stage
-- guard proves exactly one game parent for every games row and that the four shared columns read here agree today,
-- so the INNER JOIN loses and doubles nothing and results are equal.
-- ACCESS (E4): all six functions (3 wrappers, 3 inners) are SECURITY DEFINER, owner postgres (superuser: reads events
-- past FORCE RLS). None is SECURITY INVOKER, so authenticated callers keep working. public.events stays FORCE RLS,
-- zero policies, no API grants. No grant is added or changed.
--
-- No DROP, no CASCADE, no data mutation, no grant change. Single transaction.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_n int;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-733: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-733: public.events missing (KAN-710 not applied)';
  END IF;

  -- KAN-712 stage B (cutover), KAN-713 and KAN-718 markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_after_delete'),
      ('public.events',  'trg_kan713_events_location'),
      ('public.games',   'trg_kan713_games_a_location'),
      ('public.games',   'trg_kan713_games_b_joining'),
      ('public.games',   'trg_kan713_games_c_venue_geo'),
      ('public.meetups', 'trg_kan713_meetups_a_location'),
      ('public.meetups', 'trg_kan713_meetups_b_joining'),
      ('public.events',  'trg_kan718_events_series_occurrence'),
      ('public.games',   'trg_kan718_games_series_occurrence')) AS t(rel, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.rel::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      v_missing := v_missing || (r.rel || '.' || r.tg);
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    v_missing := v_missing || 'public.kan712_wrapped_rpcs'::text;
  END IF;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    v_missing := v_missing || 'public.kan713_meetup_visible(uuid)'::text;
  END IF;
  IF to_regclass('public.games_series_id_start_at_key') IS NULL THEN
    v_missing := v_missing || 'public.games_series_id_start_at_key'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'KAN-733: prerequisite stage missing: %', array_to_string(v_missing, ', ');
  END IF;

  -- All three ARE KAN-712-wrapped, exactly as KAN-712 recorded them: only the inner may be replaced in place.
  EXECUTE $q$SELECT count(*) FROM public.kan712_wrapped_rpcs w
              WHERE (w.name, w.inner_name, w.lock_spec, w.original_owner::regrole::text, w.original_acl::text) IN (
                ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_occurrence_kan712_inner', 'game:p_game_id',
                 'postgres', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
                ('rpc_edit_game_series_future', 'rpc_edit_game_series_future_kan712_inner', 'series:p_series_id',
                 'postgres', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
                ('rpc_cancel_game_series', 'rpc_cancel_game_series_kan712_inner', 'series:p_series_id',
                 'postgres', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'))$q$ INTO v_n;
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'KAN-733: the three series RPCs are not wrapped as KAN-712 recorded them (% of 3) — re-assess', v_n;
  END IF;

  -- events still closed to the API.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR NOT (SELECT relforcerowsecurity AND relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-733: public.events is no longer closed (policy or API grant present) — re-assess';
  END IF;

  -- Every games row has exactly one parent of event_type game (INNER JOIN loses and doubles nothing) ...
  IF EXISTS (SELECT 1 FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-733: a games row has no events parent of event_type game';
  END IF;
  -- ... and the four shared columns read here agree (the compat mirror holds; a disagreement would change results).
  IF EXISTS (SELECT 1 FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE (e.creator_user_id, e.start_at, e.end_at, e.is_cancelled)
                    IS DISTINCT FROM (g.creator_user_id, g.start_at, g.end_at, g.is_cancelled)) THEN
    RAISE EXCEPTION 'KAN-733: events disagrees with games on a shared column read here — reconcile first';
  END IF;

  -- All six stay SECURITY DEFINER and their owners read events past FORCE RLS (E4: no INVOKER caller of events).
  FOR r IN SELECT p.oid::regprocedure::text AS fn, p.proowner AS own, p.prosecdef FROM pg_proc p
            WHERE p.pronamespace = 'public'::regnamespace
              AND p.proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                                'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner',
                                'rpc_cancel_game_series_kan712_inner') LOOP
    IF NOT r.prosecdef THEN
      RAISE EXCEPTION 'KAN-733: % is not SECURITY DEFINER; reading events would break API callers — stop', r.fn;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = r.own AND (rolsuper OR rolbypassrls)) THEN
      RAISE EXCEPTION 'KAN-733: owner of % cannot bypass RLS on public.events', r.fn;
    END IF;
  END LOOP;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins: md5 of pg_get_functiondef. The three inners must be the pre-image (an already-applied state fails
--    here); the three wrappers, the generator pair and rpc_cancel_game are left untouched and pinned.
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)', '76a813d1110538c2f3be870b65ead001'),
      ('public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time,integer,uuid,date,boolean)',   'f10269f818183d9a3eb7289cbcff03a2'),
      ('public.rpc_cancel_game_series_kan712_inner(uuid,text)',                                               'ec5ee9a4f81371da8f49d57f0147eea4'),
      ('public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)',              'ff5fc97a110d512d95e68702c4875377'),
      ('public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean)',                'ae0eb67d40f150276cca5e8d9483d812'),
      ('public.rpc_cancel_game_series(uuid,text)',                                                            '5dfc8373693466514bcfca3e169aa932'),
      ('public.fn_generate_game_series_occurrences(uuid)',                                                    '9502f276a2158bf9f57b6130a796ae29'),
      ('public.fn_generate_game_series_occurrences_kan712_inner(uuid)',                                       '382e19ce66e66b1b0660f50163de36e3'),
      ('public.rpc_cancel_game(uuid,text)',                                                                   'bf9763ac173e917cab60949d801e86f2')) AS t(fn, md)
  LOOP
    IF to_regprocedure(r.fn) IS NULL THEN
      RAISE EXCEPTION 'KAN-733 pin: % missing', r.fn;
    END IF;
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-733 pin: % definition drifted (md5 % expected %) — already applied, or the pre-image moved',
        r.fn, v, r.md;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                        'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner',
                        'rpc_cancel_game_series_kan712_inner')) <> 6 THEN
    RAISE EXCEPTION 'KAN-733 pin: an overload of a series function in scope exists — re-assess';
  END IF;
END
$pins$;

-- Attribute capture for the post-conditions (ON COMMIT DROP: nothing persists).
CREATE TEMP TABLE kan733_pre ON COMMIT DROP AS
  SELECT p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig,
         pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS res
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                       'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner',
                       'rpc_cancel_game_series_kan712_inner');
CREATE TEMP TABLE kan733_pre_wrapped ON COMMIT DROP AS
  SELECT w::text AS row_text FROM public.kan712_wrapped_rpcs w;
CREATE TEMP TABLE kan733_pre_events ON COMMIT DROP AS
  SELECT relacl::text AS acl, relrowsecurity, relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Functions — the three *_kan712_inner bodies only
-- ---------------------------------------------------------------------------------------------------------
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

CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_future_kan712_inner(p_series_id uuid, p_title text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_start_time_local time without time zone DEFAULT NULL::time without time zone, p_duration_minutes integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid, p_ends_on date DEFAULT NULL::date, p_clear_ends_on boolean DEFAULT false)
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
    -- KAN-733: start, cancel state and host come from the events parent; the games rows are still locked.
    SELECT games.id, e.start_at,
           EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> e.creator_user_id) AS has_players
      FROM public.games
      JOIN public.events e ON e.id = games.event_id AND e.event_type = 'game'
     WHERE games.series_id = s.id AND e.start_at > now() AND NOT COALESCE(e.is_cancelled, false)
     ORDER BY e.start_at
       FOR UPDATE OF games
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

CREATE OR REPLACE FUNCTION public.rpc_cancel_game_series_kan712_inner(p_series_id uuid, p_reason text DEFAULT NULL::text)
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
    -- KAN-733: start, cancel state and host come from the events parent; the games rows are still locked.
    SELECT games.id, (SELECT count(DISTINCT r.user_id) FROM public.game_roster r
                       WHERE r.game_id = games.id AND r.user_id <> e.creator_user_id) AS players
      FROM public.games
      JOIN public.events e ON e.id = games.event_id AND e.event_type = 'game'
     WHERE games.series_id = s.id AND e.start_at > now() AND NOT COALESCE(e.is_cancelled, false)
     ORDER BY e.start_at
       FOR UPDATE OF games
  LOOP
    PERFORM public.rpc_cancel_game(g.id, COALESCE(p_reason, 'series_cancelled'));
    v_cancelled := v_cancelled + 1;
    v_players := v_players + g.players;
  END LOOP;

  SELECT count(*) INTO v_past
    FROM public.games g0
    JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
   WHERE g0.series_id = s.id AND e.start_at <= now();

  RETURN jsonb_build_object('series_id', s.id, 'status', 'ended', 'cancelled', v_cancelled,
                            'player_notifications', v_players, 'past_kept', v_past);
END;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text;
BEGIN
  -- Exact new inner definitions; wrappers, generator pair and rpc_cancel_game byte-identical.
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)', '5adf6e028e5a3407a145e014620f7757'),
      ('public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time,integer,uuid,date,boolean)',   '58f7c53c076699063f4868ec6a461928'),
      ('public.rpc_cancel_game_series_kan712_inner(uuid,text)',                                               '3efd11063a2140fadb93bfa50ea493c6'),
      ('public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)',              'ff5fc97a110d512d95e68702c4875377'),
      ('public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean)',                'ae0eb67d40f150276cca5e8d9483d812'),
      ('public.rpc_cancel_game_series(uuid,text)',                                                            '5dfc8373693466514bcfca3e169aa932'),
      ('public.fn_generate_game_series_occurrences(uuid)',                                                    '9502f276a2158bf9f57b6130a796ae29'),
      ('public.fn_generate_game_series_occurrences_kan712_inner(uuid)',                                       '382e19ce66e66b1b0660f50163de36e3'),
      ('public.rpc_cancel_game(uuid,text)',                                                                   'bf9763ac173e917cab60949d801e86f2')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-733 post: % definition md5 % (expected %)', r.fn, v, r.md;
    END IF;
  END LOOP;

  -- oid, signature, result, owner, ACL, SECURITY DEFINER, volatility, search_path identical for all six.
  IF EXISTS (SELECT 1 FROM pg_temp.kan733_pre p LEFT JOIN pg_proc c ON c.oid = p.oid
              WHERE c.oid IS NULL OR c.proowner <> p.proowner OR c.proacl::text IS DISTINCT FROM p.acl
                 OR c.prosecdef <> p.prosecdef OR c.provolatile <> p.provolatile
                 OR c.proconfig IS DISTINCT FROM p.proconfig
                 OR pg_get_function_identity_arguments(c.oid) <> p.args
                 OR pg_get_function_result(c.oid) <> p.res)
     OR (SELECT count(*) FROM pg_temp.kan733_pre) <> 6 THEN
    RAISE EXCEPTION 'KAN-733 post: oid / signature / owner / ACL / SECURITY DEFINER / volatility / search_path changed';
  END IF;
  -- No overload appeared; no API role can call an inner.
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                        'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner',
                        'rpc_cancel_game_series_kan712_inner')) <> 6
     OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                 WHERE p.pronamespace = 'public'::regnamespace
                   AND p.proname IN ('rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner',
                                     'rpc_cancel_game_series_kan712_inner')
                   AND a.grantee <> p.proowner) THEN
    RAISE EXCEPTION 'KAN-733 post: overload count changed or an inner became callable by a non-owner';
  END IF;
  -- KAN-712 control rows byte-identical (wrapped_at included).
  IF EXISTS (SELECT row_text FROM pg_temp.kan733_pre_wrapped
             EXCEPT SELECT w::text FROM public.kan712_wrapped_rpcs w)
     OR EXISTS (SELECT w::text FROM public.kan712_wrapped_rpcs w
                EXCEPT SELECT row_text FROM pg_temp.kan733_pre_wrapped) THEN
    RAISE EXCEPTION 'KAN-733 post: kan712_wrapped_rpcs changed';
  END IF;

  -- events still closed to the API, attributes identical.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT')
     OR EXISTS (SELECT 1 FROM pg_temp.kan733_pre_events p, pg_class c
                 WHERE c.oid = 'public.events'::regclass
                   AND (c.relacl::text IS DISTINCT FROM p.acl OR NOT c.relrowsecurity OR NOT c.relforcerowsecurity)) THEN
    RAISE EXCEPTION 'KAN-733 post: public.events opened to the API or its posture changed';
  END IF;
END
$post$;

COMMIT;

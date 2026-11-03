-- KAN-733 (KAN-714 piece B14) — ROLLBACK of 20261104101400_kan714_b14_series_rpc_reads.sql.
-- LOCAL THROWAWAY POSTGRES ONLY. One transaction. No DROP, no CASCADE, no data mutation, no grant change.
-- Restores the pre-images of the three KAN-712 inner bodies verbatim (pg_get_functiondef of the KAN-713 stage
-- catalogue) through the same KAN712_CONTRACT.md path the migration uses: kan712_unwrap_rpc -> CREATE OR REPLACE of
-- the unwrapped public name -> kan712_wrap_rpc with the recorded lock_spec. The KAN-712 wrapper is regenerated and
-- asserted identical to its pre-image (md5, ACL, kan712.contract=on); inner oids, owners and ACLs are unchanged;
-- kan712_wrapped_rpcs is identical except wrapped_at of the three rows; every other wrapped RPC is byte-identical.
-- Must run BEFORE any KAN-712 rollback (which renames the inners back); if the inners no longer exist it refuses.
-- Refuses unless ALL THREE live inner definitions are exactly the migration's post-images, so a second run, a partial
-- state, or a run against a DB that never had the migration raises instead of rewriting anything.
-- Verify afterwards with: psql -v expect=pre -f supabase/tests/events_p2/kan714_b14_series_reads.sql
\set ON_ERROR_STOP 1
BEGIN;

DO $guard$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)', '5adf6e028e5a3407a145e014620f7757'),
      ('public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time,integer,uuid,date,boolean)',   '58f7c53c076699063f4868ec6a461928'),
      ('public.rpc_cancel_game_series_kan712_inner(uuid,text)',                                               '3efd11063a2140fadb93bfa50ea493c6')) AS t(fn, md)
  LOOP
    IF to_regprocedure(r.fn) IS NULL THEN
      RAISE EXCEPTION 'KAN-733 rollback refused: % missing (KAN-712 already rolled back?)', r.fn;
    END IF;
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-733 rollback refused: % md5 % is not the B14 post-image % (not applied, already rolled back, or drifted)', r.fn, v, r.md;
    END IF;
  END LOOP;
END $guard$;

CREATE TEMP TABLE kan733_rb_attr ON COMMIT DROP AS
  SELECT p.oid::regprocedure::text AS sig, p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig, pg_get_function_result(p.oid) AS res
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                       'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner',
                       'rpc_cancel_game_series_kan712_inner');
CREATE TEMP TABLE kan733_rb_wrapped ON COMMIT DROP AS
  SELECT CASE WHEN w.name IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series')
              THEN (to_jsonb(w) - 'wrapped_at')::text ELSE to_jsonb(w)::text END AS row_text
    FROM public.kan712_wrapped_rpcs w;
CREATE TEMP TABLE kan733_rb_others ON COMMIT DROP AS
  SELECT p.oid::regprocedure::text AS sig, md5(pg_get_functiondef(p.oid)) AS md, p.proacl::text AS acl
    FROM public.kan712_wrapped_rpcs w
    JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname IN (w.name, w.inner_name)
                  AND pg_get_function_identity_arguments(p.oid) = w.identity_args
   WHERE w.name NOT IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series');
CREATE TEMP TABLE kan733_rb_wrap ON COMMIT DROP AS
  SELECT w.name, w.identity_args, w.lock_spec FROM public.kan712_wrapped_rpcs w
   WHERE w.name IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series');

DO $unwrap$
DECLARE r record;
BEGIN
  IF (SELECT count(*) FROM kan733_rb_wrap) <> 3 THEN RAISE EXCEPTION 'KAN-733 rollback: expected 3 recorded rows'; END IF;
  FOR r IN SELECT * FROM kan733_rb_wrap ORDER BY name LOOP
    PERFORM public.kan712_unwrap_rpc(r.name, r.identity_args);
  END LOOP;
END $unwrap$;

CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_occurrence(p_game_id uuid, p_title text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid)
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

CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_future(p_series_id uuid, p_title text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_start_time_local time without time zone DEFAULT NULL::time without time zone, p_duration_minutes integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid, p_ends_on date DEFAULT NULL::date, p_clear_ends_on boolean DEFAULT false)
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

CREATE OR REPLACE FUNCTION public.rpc_cancel_game_series(p_series_id uuid, p_reason text DEFAULT NULL::text)
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

DO $wrap$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM kan733_rb_wrap ORDER BY name LOOP
    PERFORM public.kan712_wrap_rpc(
      (SELECT p.oid FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = r.name
          AND pg_get_function_identity_arguments(p.oid) = r.identity_args)::regprocedure, r.lock_spec);
  END LOOP;
END $wrap$;

DO $post$
DECLARE r record; v text; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)', '76a813d1110538c2f3be870b65ead001'),
      ('public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time,integer,uuid,date,boolean)',   'f10269f818183d9a3eb7289cbcff03a2'),
      ('public.rpc_cancel_game_series_kan712_inner(uuid,text)',                                               'ec5ee9a4f81371da8f49d57f0147eea4'),
      ('public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)',              'ff5fc97a110d512d95e68702c4875377'),
      ('public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean)',                'ae0eb67d40f150276cca5e8d9483d812'),
      ('public.rpc_cancel_game_series(uuid,text)',                                                            '5dfc8373693466514bcfca3e169aa932')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-733 rollback post: % md5 % is not the pre-image %', r.fn, v, r.md;
    END IF;
  END LOOP;
  -- inners keep their oid; wrappers are regenerated, so they are matched by signature.
  SELECT count(*) INTO n FROM kan733_rb_attr a JOIN pg_proc p ON p.oid = to_regprocedure(a.sig)
   WHERE (a.sig NOT LIKE '%\_kan712\_inner(%' OR p.oid = a.oid) AND p.proowner = a.proowner AND p.proacl::text IS NOT DISTINCT FROM a.acl AND p.prosecdef = a.prosecdef
     AND p.provolatile = a.provolatile AND p.proconfig IS NOT DISTINCT FROM a.proconfig AND pg_get_function_result(p.oid) = a.res;
  IF n <> 6 THEN RAISE EXCEPTION 'KAN-733 rollback post: oid/owner/ACL/SECURITY DEFINER/volatility/search_path/result changed'; END IF;
  SELECT count(*) INTO n FROM pg_proc WHERE pronamespace = 'public'::regnamespace
     AND proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series',
                     'rpc_edit_game_series_occurrence_kan712_inner', 'rpc_edit_game_series_future_kan712_inner',
                     'rpc_cancel_game_series_kan712_inner');
  IF n <> 6 THEN RAISE EXCEPTION 'KAN-733 rollback post: % functions (overload appeared or one is missing)', n; END IF;
  CREATE TEMP TABLE kan733_rb_now ON COMMIT DROP AS
    SELECT CASE WHEN w.name IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series')
                THEN (to_jsonb(w) - 'wrapped_at')::text ELSE to_jsonb(w)::text END AS row_text
      FROM public.kan712_wrapped_rpcs w;
  IF EXISTS (SELECT row_text FROM kan733_rb_wrapped EXCEPT SELECT row_text FROM kan733_rb_now)
     OR EXISTS (SELECT row_text FROM kan733_rb_now EXCEPT SELECT row_text FROM kan733_rb_wrapped) THEN
    RAISE EXCEPTION 'KAN-733 rollback post: kan712_wrapped_rpcs changed';
  END IF;
  -- The wrapper is back: kan712.contract=on, calls its inner, ACL = recorded original ACL.
  IF (SELECT count(*) FROM public.kan712_wrapped_rpcs w JOIN pg_proc p
         ON p.pronamespace = 'public'::regnamespace AND p.proname = w.name
        AND pg_get_function_identity_arguments(p.oid) = w.identity_args
       WHERE w.name IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series')
         AND 'kan712.contract=on' = ANY (p.proconfig) AND p.prosrc LIKE '%public.' || w.inner_name || '(%'
         AND p.proacl::text IS NOT DISTINCT FROM w.original_acl::text) <> 3 THEN
    RAISE EXCEPTION 'KAN-733 rollback post: a series RPC is not wrapped again as KAN-712 recorded it';
  END IF;
  IF EXISTS (SELECT 1 FROM kan733_rb_others o
              WHERE to_regprocedure(o.sig) IS NULL
                 OR md5(pg_get_functiondef(to_regprocedure(o.sig))) IS DISTINCT FROM o.md
                 OR (SELECT proacl::text FROM pg_proc WHERE oid = to_regprocedure(o.sig)) IS DISTINCT FROM o.acl) THEN
    RAISE EXCEPTION 'KAN-733 rollback post: another KAN-712-wrapped RPC changed';
  END IF;
END $post$;

COMMIT;

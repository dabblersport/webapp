-- KAN-694 fix cycle: the generator never creates a second occurrence on a local date that already has one.
--
-- STATUS: AUTHORED, NOT APPLIED. Memphis applies it AFTER 20261030130000_kan694_rpc_series_edit_cancel.sql
-- (execute_sql only, never apply_migration). Project wtncuzcskpigqpmnxwws only. No DROP, no data change, no games row touched.
-- Forward-only replace: the previous body of fn_generate_game_series_occurrences is the one in
-- 20261030120000_kan693_rpc_create_game_series.sql; re-running that CREATE OR REPLACE restores it (not part of rollback_kan694.sql).
--
-- Defect (probe F7, CTO ruling dreq-216a029a): the generator matched an existing occurrence only by exact start_at. After a
-- time-of-day change that leaves a joined row at its old time, an end-date-only edit (or the scheduled run) did not see that row
-- and created a second occurrence, at the new time, on the same day.
--
-- Normative rule: the generator never creates an occurrence on a local calendar date (in the series timezone) that already holds
-- a non-cancelled row of the same series, whatever its time. That date still counts once toward the rolling window
-- (occurrences_ahead, via v_future) and once toward the 52-slot cap (v_n). Nothing is created past ends_on. Rows with joined
-- players are never touched by the generator. The exact start_at check stays as well, for cancelled rows: they hold the unique
-- index (series_id, start_at) and must not be re-created.
-- Signature, SECURITY DEFINER, search_path and grants are unchanged. rpc_edit_game_series_future is unchanged: its skip guard
-- is now redundant but harmless, and probe F6 still asserts topup_skipped.

DO $pre$
BEGIN
  IF to_regprocedure('public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean)') IS NULL
     OR to_regprocedure('public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)') IS NULL
     OR to_regprocedure('public.rpc_cancel_game_series(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN694 fix pre-check: 20261030130000_kan694_rpc_series_edit_cancel.sql is not applied';
  END IF;
  IF to_regprocedure('public.fn_generate_game_series_occurrences(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN694 fix pre-check: fn_generate_game_series_occurrences missing; apply KAN-693 first';
  END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.fn_generate_game_series_occurrences(p_series_id uuid DEFAULT NULL)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_persona text; v_step int; v_n int; v_day date; v_start timestamptz; v_end timestamptz;
  v_future int; v_created int := 0; v_prev_sub text; v_gid uuid;
BEGIN
  FOR s IN
    SELECT * FROM public.game_series
     WHERE status = 'active' AND (p_series_id IS NULL OR id = p_series_id)
     ORDER BY id
       FOR UPDATE   -- serialises two generators on the same series
  LOOP
    SELECT persona_type INTO v_persona FROM public.profiles WHERE id = s.creator_profile_id;
    v_step := CASE WHEN s.rrule LIKE '%INTERVAL=2%' THEN 14 ELSE 7 END;

    SELECT count(*) INTO v_future FROM public.games g
     WHERE g.series_id = s.id AND g.start_at > now() AND NOT COALESCE(g.is_cancelled, false);

    v_n := 0;
    WHILE v_n < 52 AND v_future < s.occurrences_ahead LOOP   -- 52 = hard cap on occurrence slots per series
      v_day := s.starts_on + (v_n * v_step);
      EXIT WHEN s.ends_on IS NOT NULL AND v_day > s.ends_on;
      v_n := v_n + 1;   -- the slot is consumed even when its date is already held (counts once toward the cap)
      v_start := (v_day + s.start_time_local) AT TIME ZONE s.timezone;
      v_end := v_start + make_interval(mins => s.duration_minutes);
      CONTINUE WHEN v_start <= now();
      -- A kept row on this local date (any time) already counts in v_future; do not add a second one.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.games g
                             WHERE g.series_id = s.id AND NOT COALESCE(g.is_cancelled, false)
                               AND (g.start_at AT TIME ZONE s.timezone)::date = v_day);
      -- Cancelled rows keep their (series_id, start_at) slot in the unique index; never re-create them.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.games g WHERE g.series_id = s.id AND g.start_at = v_start);

      v_prev_sub := current_setting('request.jwt.claim.sub', true);
      PERFORM set_config('request.jwt.claim.sub', s.creator_user_id::text, true);
      v_gid := public.rpc_create_game(
        v_persona, s.sport_id, s.sport_variant_id, s.title, s.venue_space_id, v_start, v_end, 0,
        s.listing_visibility, s.join_policy, NULL, NULL, NULL, NULL, false, false, NULL, NULL,
        s.geo_location_id, s.area_id, NULL, NULL, NULL, s.capacity, 0::numeric, NULL);
      PERFORM set_config('request.jwt.claim.sub', COALESCE(v_prev_sub, ''), true);
      UPDATE public.games SET series_id = s.id WHERE id = v_gid;
      v_future := v_future + 1;
      v_created := v_created + 1;
    END LOOP;
  END LOOP;
  RETURN v_created;
END;
$function$;

ALTER FUNCTION public.fn_generate_game_series_occurrences(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_generate_game_series_occurrences(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_generate_game_series_occurrences(uuid) TO service_role;

DO $post$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
              WHERE p.proname IN ('rpc_create_game_series', 'fn_generate_game_series_occurrences',
                                  'rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series')
                AND p.pronamespace = 'public'::regnamespace
                AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)) THEN
    RAISE EXCEPTION 'KAN694 fix post-check: a series function is executable by PUBLIC or anon';
  END IF;
END
$post$;

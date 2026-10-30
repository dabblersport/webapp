-- KAN-693 (B2): rpc_create_game_series and the N-ahead occurrence generator.
--
-- STATUS: AUTHORED, NOT APPLIED. Memphis applies it AFTER 20261027120000_kan671_game_series.sql (KAN-671, B1),
-- execute_sql only, never apply_migration. Project wtncuzcskpigqpmnxwws only. Additive: no DROP, no existing column touched.
-- Live check 2026-10-30 (read-only): game_series absent, games.series_id absent, 0 policies, no KAN-671 migration row,
-- so this file depends on KAN-671 and refuses to run without it (pre-check below).
--
-- Decisions (T-099, epic KAN-692 v1): occurrences are ordinary games rows with games.series_id; weekly or every-2-weeks
-- only; occurrences_ahead default 4; null ends_on = runs until ended, only the rolling window exists; hard cap 52
-- occurrences per series; paid games blocked.
--
-- Every occurrence is created by the EXISTING public.rpc_create_game (validation, kan440 persona gate, host roster row):
-- there is no parallel insert path. The generator has no session, so for the duration of each call it sets the
-- transaction-local request.jwt.claim.sub to the series creator (what effective_actor_uid() reads) and restores it.

DO $pre$
BEGIN
  IF to_regclass('public.game_series') IS NULL THEN
    RAISE EXCEPTION 'KAN693 pre-check: public.game_series missing; apply 20261027120000_kan671_game_series.sql first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'games' AND column_name = 'series_id') THEN
    RAISE EXCEPTION 'KAN693 pre-check: public.games.series_id missing (KAN-671 not applied)';
  END IF;
END
$pre$;

-- rpc_create_game needs a variant; KAN-671's table does not store one. Additive nullable column.
ALTER TABLE public.game_series ADD COLUMN IF NOT EXISTS sport_variant_id uuid;
COMMENT ON COLUMN public.game_series.sport_variant_id IS 'KAN-693: the sport variant passed to rpc_create_game for every occurrence.';

-- Idempotency: one occurrence per (series, start). Partial, so one-off games are untouched.
CREATE UNIQUE INDEX IF NOT EXISTS games_series_id_start_at_key
  ON public.games (series_id, start_at) WHERE series_id IS NOT NULL;

-- Generator: keeps occurrences_ahead future, non-cancelled games per active series. Idempotent.
-- p_series_id NULL = every active series (cron / Memphis). Returns the number of games created.
-- Not callable by clients: service_role only (rpc_create_game_series calls it internally).
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
      v_n := v_n + 1;
      v_start := (v_day + s.start_time_local) AT TIME ZONE s.timezone;
      v_end := v_start + make_interval(mins => s.duration_minutes);
      CONTINUE WHEN v_start <= now();
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

-- Creator RPC. Host = effective_actor_uid(); no caller-supplied identity. p_frequency: 'weekly' | 'biweekly'.
-- Paid games are blocked in v1 (p_price_aed must be null or 0). Creates the series row, then its first occurrences.
CREATE OR REPLACE FUNCTION public.rpc_create_game_series(
  p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_geo_location_id uuid, p_area_id uuid,
  p_starts_on date, p_start_time_local time, p_duration_minutes integer, p_timezone text, p_frequency text,
  p_capacity integer, p_title text DEFAULT NULL, p_venue_space_id uuid DEFAULT NULL, p_ends_on date DEFAULT NULL,
  p_listing_visibility text DEFAULT 'public', p_join_policy text DEFAULT 'open',
  p_occurrences_ahead integer DEFAULT 4, p_price_aed numeric DEFAULT 0)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; v_pid uuid; v_sid uuid; v_rrule text;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;
  v_pid := public.choose_actor(p_actor_type);   -- raises no_profile_of_requested_type
  IF COALESCE(p_price_aed, 0) <> 0 THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_paid_not_supported';
  END IF;
  v_rrule := CASE p_frequency WHEN 'weekly' THEN 'FREQ=WEEKLY' WHEN 'biweekly' THEN 'FREQ=WEEKLY;INTERVAL=2'
             ELSE NULL END;
  IF v_rrule IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'series_frequency_invalid'; END IF;
  IF p_starts_on IS NULL OR p_start_time_local IS NULL OR p_duration_minutes IS NULL OR p_timezone IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_required';
  END IF;

  INSERT INTO public.game_series (creator_user_id, creator_profile_id, sport_id, sport_variant_id, venue_space_id,
         geo_location_id, area_id, title, capacity, listing_visibility, join_policy, start_time_local,
         duration_minutes, rrule, timezone, starts_on, ends_on, occurrences_ahead)
  VALUES (v_uid, v_pid, p_sport_id, p_sport_variant_id, p_venue_space_id, p_geo_location_id, p_area_id, p_title,
          p_capacity, p_listing_visibility, p_join_policy, p_start_time_local, p_duration_minutes, v_rrule,
          p_timezone, p_starts_on, p_ends_on, p_occurrences_ahead)
  RETURNING id INTO v_sid;

  PERFORM public.fn_generate_game_series_occurrences(v_sid);
  RETURN v_sid;
END;
$function$;

ALTER FUNCTION public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time,integer,text,text,integer,text,uuid,date,text,text,integer,numeric) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time,integer,text,text,integer,text,uuid,date,text,text,integer,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time,integer,text,text,integer,text,uuid,date,text,text,integer,numeric) TO authenticated, service_role;

DO $post$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
              WHERE p.proname IN ('rpc_create_game_series', 'fn_generate_game_series_occurrences')
                AND p.pronamespace = 'public'::regnamespace
                AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)) THEN
    RAISE EXCEPTION 'KAN693 post-check: a series function is executable by PUBLIC or anon';
  END IF;
END
$post$;

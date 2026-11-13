-- KAN-914 (Epic KAN-714): public.fn_generate_game_series_occurrences_kan712_inner -- verbatim record of the live body; a no-op on apply.
--
-- The live body already reads start_at / is_cancelled from public.kan714_games_read (events-backed),
-- and its only public.games reference is the write UPDATE public.games SET series_id = ... (series_id is a
-- games-only column, not among the 22). This migration records the live body in the repo and changes nothing.
--
-- The CREATE OR REPLACE below is pg_get_functiondef of the live function on 2026-11-13 (T-058), byte-exact:
-- md5(prosrc) 3ac00133f33a11047aed47caa0865907, md5(pg_get_functiondef) 7338260d4d3292367eac2e8bdc4365a0. CREATE OR REPLACE keeps oid, owner and ACL
-- ({postgres=X/postgres}). The guard refuses on drift; the post check asserts the functiondef md5 and ACL unchanged.
-- ROLLBACK: none needed (the body is unchanged).
-- Test: supabase/tests/events_p4/kan714_w_fn_generate_game_series_occurrences_kan712_inner_live_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.fn_generate_game_series_occurrences_kan712_inner(uuid)');
begin
  if v_oid is null then raise exception 'KAN-914 pre: fn_generate_game_series_occurrences_kan712_inner absent'; end if;
  if (select md5(prosrc) from pg_proc where oid = v_oid) <> '3ac00133f33a11047aed47caa0865907' then
    raise exception 'KAN-914 pre: pre-image drift on fn_generate_game_series_occurrences_kan712_inner; re-author from pg_get_functiondef';
  end if;
end
$guard$;

CREATE OR REPLACE FUNCTION public.fn_generate_game_series_occurrences_kan712_inner(p_series_id uuid DEFAULT NULL::uuid)
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

    SELECT count(*) INTO v_future FROM public.kan714_games_read g
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
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g
                             WHERE g.series_id = s.id AND NOT COALESCE(g.is_cancelled, false)
                               AND (g.start_at AT TIME ZONE s.timezone)::date = v_day);
      -- Cancelled rows keep their (series_id, start_at) slot in the unique index; never re-create them.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g WHERE g.series_id = s.id AND g.start_at = v_start);

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

do $post$
declare v_oid oid := to_regprocedure('public.fn_generate_game_series_occurrences_kan712_inner(uuid)');
begin
  if md5(pg_get_functiondef(v_oid)) <> '7338260d4d3292367eac2e8bdc4365a0' then
    raise exception 'KAN-914 post: functiondef md5 changed';
  end if;
  if (select proacl::text from pg_proc where oid = v_oid) <> '{postgres=X/postgres}' then
    raise exception 'KAN-914 post: ACL changed';
  end if;
end
$post$;

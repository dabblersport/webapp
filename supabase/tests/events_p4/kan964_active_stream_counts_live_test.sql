-- KAN-964 live test: public.active_stream count columns (migration 20261116072130_kan964_active_stream_counts).
-- One DO block. It always ends in RAISE EXCEPTION, so everything it creates (a temp table, a pg_temp copy of the
-- pre-image function, the user_status upserts that make player_joined rows appear) rolls back.
-- Counts are read as `authenticated` with a real profile's JWT sub and asserted as the owner against direct queries
-- on game_roster / meetup_rsvps / venue_spaces / events (authenticated has no SELECT on events).
-- Page identity: the pre-image body is rebuilt from the live prosrc by cutting out the two KAN-964 fragments (its md5
-- must equal the pre-image prosrc md5 f9856861dc4e69f39209b3cf75634feb), created as pg_temp.k964_pre with the
-- pre-image return type, and its rows are compared with the first 15 columns of the live function, same viewer, for
-- page 1, page 2 (keyset), every type filter and a city filter.
-- Expected: ERROR 'KAN-964 PASS ...'. Any failed probe yields 'KAN-964 FAIL ...' with the list.
-- v_neg := true is the negative control: expectations count every roster row / every RSVP / every space and expect
-- 0 instead of NULL, the identity probe compares against the pre-image called with a different city, and the anon
-- probe runs as authenticated. Those probes then FAIL.
DO $t$
DECLARE
  v_neg      boolean := false;
  v_viewer   uuid;
  v_fail     text[] := '{}';
  v_info     text := '';
  v_src      text;
  v_pre      text;
  v_i        int;
  v_j        int;
  v_n        int;
  v_bad      int;
  t          text;
  p1         record;
  c_types    text[] := ARRAY['player_joined','venue_added','game_created','game_started','game_ended',
                             'meetup_created','meetup_started','meetup_completed'];
  c_sel      text := E',\n         cn.participant_count, cn.capacity, cn.space_count  -- KAN-964';
  c_lat0     text := '    -- KAN-964: Active card counts';
  c_lat1     text := E'    ) cn ON true\n';
BEGIN
  -- 0. rebuild the pre-image as pg_temp.k964_pre
  SELECT p.prosrc INTO v_src FROM pg_proc p
   WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  v_pre := replace(v_src, c_sel, '');
  v_i := position(c_lat0 IN v_pre);
  v_j := position(c_lat1 IN v_pre);
  IF v_i = 0 OR v_j <= v_i THEN RAISE EXCEPTION 'KAN-964 FAIL: KAN-964 fragments not found in live prosrc'; END IF;
  v_pre := left(v_pre, v_i - 1) || substr(v_pre, v_j + length(c_lat1));
  IF md5(v_pre) <> 'f9856861dc4e69f39209b3cf75634feb' THEN
    RAISE EXCEPTION 'KAN-964 FAIL: rebuilt pre-image md5 % <> f9856861dc4e69f39209b3cf75634feb', md5(v_pre);
  END IF;
  EXECUTE format($f$CREATE FUNCTION pg_temp.k964_pre(p_event_types text[] DEFAULT NULL, p_city text DEFAULT NULL, p_limit integer DEFAULT 30, p_before timestamptz DEFAULT NULL, p_before_type text DEFAULT NULL, p_before_entity uuid DEFAULT NULL)
    RETURNS TABLE(event_type text, event_at timestamptz, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text,
                  actor_display_name text, actor_avatar_url text, detail text, start_at timestamptz, end_at timestamptz,
                  is_live boolean, sport_names_en text[], sport_names_ar text[])
    LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS %L$f$, v_pre);

  CREATE TEMP TABLE _k964 ON COMMIT DROP AS
    SELECT ''::text AS lbl, s.* FROM public.active_stream() s WHERE false;
  GRANT ALL ON _k964 TO authenticated;

  -- player_joined is empty on live data (no visible profile); make active personal profiles visible (rolled back).
  INSERT INTO public.user_status (user_id, is_benched, hide_in_search)
  SELECT DISTINCT p.user_id, false, false
    FROM public.profiles p
   WHERE p.profile_type = 'personal' AND p.is_active AND p.user_id IS NOT NULL
  ON CONFLICT (user_id) DO UPDATE SET is_benched = false, hide_in_search = false;

  SELECT p.user_id INTO v_viewer
    FROM public.profiles p
   WHERE p.profile_type = 'personal' AND p.user_id IS NOT NULL
   ORDER BY p.created_at LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_viewer, 'role', 'authenticated')::text, true);

  -- calls, as authenticated
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k964 SELECT 'p1', s.* FROM public.active_stream(NULL, NULL, 50) s;
  FOREACH t IN ARRAY c_types LOOP
    INSERT INTO _k964 SELECT 'type:' || t, s.* FROM public.active_stream(ARRAY[t], NULL, 50) s;
  END LOOP;
  EXECUTE 'RESET ROLE';

  -- 1. counts per type against direct queries; NULLs where specified
  FOREACH t IN ARRAY c_types LOOP
    SELECT count(*),
           count(*) FILTER (WHERE
             CASE k.entity_kind
               WHEN 'game' THEN
                 k.participant_count IS DISTINCT FROM (
                   SELECT count(*)::int FROM public.game_roster gr JOIN public.games g ON g.id = gr.game_id
                    WHERE gr.game_id = k.entity_id
                      AND (v_neg OR (gr.status = 'active'
                                     AND (gr.role = 'player' OR (gr.role = 'host' AND g.game_type IN ('hosted', 'casual'))))))
                 OR k.capacity IS DISTINCT FROM (SELECT e.capacity FROM public.games g JOIN public.events e ON e.id = g.event_id
                                                  WHERE g.id = k.entity_id)
                 OR k.space_count IS DISTINCT FROM CASE WHEN v_neg THEN 0 END
               WHEN 'meetup' THEN
                 k.participant_count IS DISTINCT FROM (
                   SELECT count(*)::int FROM public.meetup_rsvps r
                    WHERE r.meetup_id = k.entity_id AND (v_neg OR r.status = 'going'))
                 OR k.capacity IS DISTINCT FROM (SELECT e.capacity FROM public.meetups m JOIN public.events e ON e.id = m.event_id
                                                  WHERE m.id = k.entity_id)
                 OR k.space_count IS DISTINCT FROM CASE WHEN v_neg THEN 0 END
               WHEN 'venue' THEN
                 k.participant_count IS DISTINCT FROM CASE WHEN v_neg THEN 0 END
                 OR k.capacity IS DISTINCT FROM CASE WHEN v_neg THEN 0 END
                 OR k.space_count IS DISTINCT FROM (
                   SELECT count(*)::int FROM public.venue_spaces vs
                    WHERE vs.venue_id = k.entity_id AND (v_neg OR vs.is_active))
               ELSE  -- profile
                 k.participant_count IS DISTINCT FROM CASE WHEN v_neg THEN 0 END
                 OR k.capacity IS DISTINCT FROM CASE WHEN v_neg THEN 0 END
                 OR k.space_count IS DISTINCT FROM CASE WHEN v_neg THEN 0 END
             END)
      INTO v_n, v_bad
      FROM _k964 k WHERE k.lbl = 'type:' || t;
    v_info := v_info || format('%s=%s; ', t, v_n);
    IF v_n = 0 THEN v_fail := v_fail || format('%s: no rows', t); END IF;
    IF v_bad > 0 THEN v_fail := v_fail || format('%s: %s rows with wrong counts', t, v_bad); END IF;
  END LOOP;
  -- the counts are not trivially zero / NULL
  SELECT count(*) INTO v_n FROM _k964 WHERE lbl LIKE 'type:game%' AND participant_count > 0 AND capacity > 0;
  v_info := v_info || format('games_with_counts=%s; ', v_n);
  IF v_n = 0 THEN v_fail := v_fail || 'games: no row with participant_count>0 and capacity>0'::text; END IF;
  SELECT count(*) INTO v_n FROM _k964 WHERE lbl LIKE 'type:meetup%' AND participant_count > 0;
  IF v_n = 0 THEN v_fail := v_fail || 'meetups: no row with participant_count>0'::text; END IF;
  SELECT count(*) INTO v_n FROM _k964 WHERE lbl = 'type:venue_added' AND space_count > 0;
  v_info := v_info || format('venues_with_spaces=%s; ', v_n);
  IF v_n = 0 THEN v_fail := v_fail || 'venues: no row with space_count>0'::text; END IF;

  -- 2. page identity with the pre-image (first 15 columns), same viewer; as the owner (both are evaluated as
  --    postgres: the live function is SECURITY DEFINER, the pg_temp copy runs as the caller).
  SELECT event_at, event_type, entity_id INTO p1 FROM _k964 WHERE lbl = 'p1'
   ORDER BY event_at, event_type, entity_id OFFSET 39 LIMIT 1;   -- the 11th row from the top of page 1
  DECLARE
    v_new text[]; v_old text[]; v_case text; v_args text;
    c_cases text[] := ARRAY['NULL, NULL, 50', 'NULL, NULL, 10', 'NULL, ''Dubai'', 50', 'NULL, NULL, 10, $1, $2, $3']
                      || ARRAY(SELECT format('ARRAY[%L], NULL, 50', x) FROM unnest(c_types) x);
  BEGIN
    FOREACH v_case IN ARRAY c_cases LOOP
      EXECUTE format('SELECT array_agg(row(s.event_type,s.event_at,s.entity_kind,s.entity_id,s.actor_profile_id,s.city,s.title,'
                     's.actor_display_name,s.actor_avatar_url,s.detail,s.start_at,s.end_at,s.is_live,s.sport_names_en,'
                     's.sport_names_ar)::text) FROM public.active_stream(%s) s', v_case)
        INTO v_new USING p1.event_at, p1.event_type, p1.entity_id;
      v_args := CASE WHEN v_neg AND v_case = 'NULL, NULL, 50' THEN 'NULL, ''Abu Dhabi'', 50' ELSE v_case END;
      EXECUTE format('SELECT array_agg(s::text) FROM pg_temp.k964_pre(%s) s', v_args)
        INTO v_old USING p1.event_at, p1.event_type, p1.entity_id;
      IF v_new IS DISTINCT FROM v_old THEN
        v_fail := v_fail || format('identity (%s): new %s rows vs pre %s rows differ', v_case,
                                   coalesce(cardinality(v_new), 0), coalesce(cardinality(v_old), 0));
      END IF;
      IF v_case = 'NULL, NULL, 50' THEN v_info := v_info || format('page1_rows=%s; ', coalesce(cardinality(v_new), 0)); END IF;
    END LOOP;
  END;

  -- 3. anon gets 42501
  IF NOT v_neg THEN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    EXECUTE 'SET LOCAL ROLE anon';
  ELSE
    EXECUTE 'SET LOCAL ROLE authenticated';
  END IF;
  BEGIN
    PERFORM count(*) FROM public.active_stream(NULL, NULL, 5);
    v_fail := v_fail || 'anon: call succeeded, expected 42501'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'RESET ROLE';

  IF cardinality(v_fail) = 0 THEN
    RAISE EXCEPTION 'KAN-964 PASS (neg=%): %', v_neg, v_info;
  ELSE
    RAISE EXCEPTION 'KAN-964 FAIL (neg=%) % failures: % | %', v_neg, cardinality(v_fail), array_to_string(v_fail, ' || '), v_info;
  END IF;
END
$t$;

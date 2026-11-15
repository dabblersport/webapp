-- KAN-957 live test: public.active_stream card fields (migration 20261115211330_kan957_active_stream_card_fields).
-- One DO block. It always ends in RAISE EXCEPTION, so everything it writes (a temp table and one user_blocks row)
-- rolls back, as do the user_status rows it upserts. Calls run as `authenticated` with a real profile's JWT sub; results land in a temp table and are
-- asserted as the owner (authenticated has no SELECT on events, so joins to the base tables run after RESET ROLE).
-- Expected: ERROR 'KAN-957 PASS ...'. Any failed probe yields 'KAN-957 FAIL ...' with the list.
-- v_neg := true is the negative control: the block row is not inserted, the anon probe runs as authenticated, and
-- the city probe filters Sharjah while checking for Dubai. Those three probes then FAIL (seen 2026-11-16).
DO $t$
DECLARE
  v_neg      boolean := false;
  v_viewer   uuid;
  v_creator  uuid;
  v_fail     text[] := '{}';
  v_n        int;
  v_bad      int;
  v_info     text := '';
  t          text;
  c_types    text[] := ARRAY['player_joined','venue_added','game_created','game_started','game_ended',
                             'meetup_created','meetup_started','meetup_completed'];
  c_games    text[] := ARRAY['game_created','game_started','game_ended'];
  p1         record;
  v_ids1     text[];
  v_ids2     text[];
  v_ids20    text[];
BEGIN
  CREATE TEMP TABLE _k957 ON COMMIT DROP AS
    SELECT ''::text AS lbl, s.* FROM public.active_stream() s WHERE false;
  GRANT ALL ON _k957 TO authenticated;

  -- Live data has no publicly visible profile (no user_status row => hide_in_search defaults true), so
  -- player_joined is empty for everyone. Make active personal profiles visible inside this rolled-back block
  -- so the player_joined branch, and the block probe against a creator's own player row, are exercised.
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
  INSERT INTO _k957 SELECT 'all', s.* FROM public.active_stream(NULL, NULL, 50) s;
  FOREACH t IN ARRAY c_types LOOP
    INSERT INTO _k957 SELECT 'type:' || t, s.* FROM public.active_stream(ARRAY[t], NULL, 50) s;
  END LOOP;
  INSERT INTO _k957 SELECT 'games', s.* FROM public.active_stream(c_games, NULL, 50) s;
  INSERT INTO _k957 SELECT 'city', s.* FROM public.active_stream(NULL, CASE WHEN v_neg THEN 'Sharjah' ELSE 'dubai ' END, 50) s;
  INSERT INTO _k957 SELECT 'abudhabi', s.* FROM public.active_stream(NULL, 'Abu Dhabi', 50) s;
  INSERT INTO _k957 SELECT 'p1', s.* FROM public.active_stream(NULL, NULL, 10) s;
  INSERT INTO _k957 SELECT 'p20', s.* FROM public.active_stream(NULL, NULL, 20) s;
  SELECT event_at, event_type, entity_id INTO p1 FROM _k957 WHERE lbl = 'p1'
   ORDER BY event_at, event_type, entity_id LIMIT 1;
  INSERT INTO _k957 SELECT 'p2', s.* FROM public.active_stream(NULL, NULL, 10, p1.event_at, p1.event_type, p1.entity_id) s;
  EXECUTE 'RESET ROLE';

  -- 1. unfiltered and per type: card fields filled per type
  SELECT count(*) INTO v_n FROM _k957 WHERE lbl = 'all';
  v_info := v_info || format('unfiltered=%s; ', v_n);
  IF v_n = 0 THEN v_fail := v_fail || 'unfiltered returned 0 rows'::text; END IF;
  FOREACH t IN ARRAY c_types LOOP
    SELECT count(*),
           count(*) FILTER (WHERE
             k.event_type <> t
             OR k.sport_names_en IS NULL OR k.sport_names_ar IS NULL
             OR cardinality(k.sport_names_en) <> cardinality(k.sport_names_ar)
             OR k.is_live IS NULL
             OR k.actor_display_name IS DISTINCT FROM ap.display_name
             OR k.actor_avatar_url IS DISTINCT FROM ap.avatar_url
             OR CASE
                  WHEN t = 'player_joined' THEN
                    k.actor_profile_id IS NULL OR k.detail IS NOT NULL
                    OR k.start_at IS NOT NULL OR k.end_at IS NOT NULL OR k.is_live
                    OR cardinality(k.sport_names_en) <> (SELECT count(*) FROM public.sports s, public.profiles pp
                                                         WHERE pp.id = k.entity_id
                                                           AND (s.id = pp.primary_sport OR s.id = pp.preferred_sport
                                                                OR s.id = ANY (pp.interests)))
                  WHEN t = 'venue_added' THEN
                    k.actor_profile_id IS NOT NULL OR k.actor_display_name IS NOT NULL
                    OR k.detail IS DISTINCT FROM (SELECT a.name FROM public.venues v JOIN public.areas a ON a.id = v.area_id
                                                  WHERE v.id = k.entity_id)
                    OR k.start_at IS NOT NULL OR k.end_at IS NOT NULL OR k.is_live
                  ELSE
                    k.detail IS DISTINCT FROM COALESCE(vn.name_en, ar.name)
                    OR k.start_at IS DISTINCT FROM e.start_at
                    OR k.end_at IS DISTINCT FROM CASE WHEN k.entity_kind = 'meetup' THEN COALESCE(e.end_at, e.start_at) ELSE e.end_at END
                    OR k.is_live IS DISTINCT FROM (e.start_at <= now() AND now() < k.end_at)
                    OR k.actor_profile_id IS DISTINCT FROM e.creator_profile_id
                    OR k.sport_names_en IS DISTINCT FROM COALESCE((SELECT ARRAY[s.name_en] FROM public.sports s WHERE s.id = e.sport_id), '{}')
                    OR k.sport_names_ar IS DISTINCT FROM COALESCE((SELECT ARRAY[s.name_ar] FROM public.sports s WHERE s.id = e.sport_id), '{}')
                END)
      INTO v_n, v_bad
      FROM _k957 k
      LEFT JOIN public.profiles ap ON ap.id = k.actor_profile_id
      LEFT JOIN public.games g ON k.entity_kind = 'game' AND g.id = k.entity_id
      LEFT JOIN public.meetups m ON k.entity_kind = 'meetup' AND m.id = k.entity_id
      LEFT JOIN public.events e ON e.id = COALESCE(g.event_id, m.event_id)
      LEFT JOIN public.venues vn ON vn.id = e.venue_id
      LEFT JOIN public.areas ar ON ar.id = e.area_id
     WHERE k.lbl = 'type:' || t;
    v_info := v_info || format('%s=%s; ', t, v_n);
    IF v_n = 0 THEN v_fail := v_fail || format('%s: no rows', t); END IF;
    IF v_bad > 0 THEN v_fail := v_fail || format('%s: %s rows with wrong card fields', t, v_bad); END IF;
  END LOOP;
  -- sports actually populated (not empty everywhere)
  SELECT count(*) INTO v_n FROM _k957 WHERE lbl = 'type:venue_added' AND cardinality(sport_names_en) > 0;
  IF v_n = 0 THEN v_fail := v_fail || 'venue_added: no row with sports'::text; END IF;
  SELECT count(*) INTO v_n FROM _k957 WHERE lbl = 'games' AND cardinality(sport_names_ar) > 0;
  IF v_n = 0 THEN v_fail := v_fail || 'games: no row with AR sports'::text; END IF;
  SELECT count(*) INTO v_n FROM _k957 WHERE lbl LIKE 'type:%' AND is_live;
  v_info := v_info || format('live=%s; ', v_n);

  -- 2. type filter
  SELECT count(*), count(*) FILTER (WHERE NOT (event_type = ANY (c_games))) INTO v_n, v_bad FROM _k957 WHERE lbl = 'games';
  IF v_n = 0 OR v_bad > 0 THEN v_fail := v_fail || format('type filter: n=%s off-type=%s', v_n, v_bad); END IF;

  -- 3. city filter
  SELECT count(*), count(*) FILTER (WHERE lower(city) IS DISTINCT FROM 'dubai') INTO v_n, v_bad FROM _k957 WHERE lbl = 'city';
  v_info := v_info || format('dubai=%s; ', v_n);
  IF v_n = 0 OR v_bad > 0 THEN v_fail := v_fail || format('city filter: n=%s non-Dubai=%s', v_n, v_bad); END IF;
  SELECT count(*), count(*) FILTER (WHERE lower(city) IS DISTINCT FROM 'abu dhabi') INTO v_n, v_bad FROM _k957 WHERE lbl = 'abudhabi';
  IF v_bad > 0 THEN v_fail := v_fail || format('city filter Abu Dhabi: %s other-city rows', v_bad); END IF;

  -- 4. keyset paging: p1(10) || p2(10 after p1's last) = p20, no overlap
  SELECT array_agg(event_type || '/' || entity_id ORDER BY event_at DESC, event_type DESC, entity_id DESC) INTO v_ids1 FROM _k957 WHERE lbl = 'p1';
  SELECT array_agg(event_type || '/' || entity_id ORDER BY event_at DESC, event_type DESC, entity_id DESC) INTO v_ids2 FROM _k957 WHERE lbl = 'p2';
  SELECT array_agg(event_type || '/' || entity_id ORDER BY event_at DESC, event_type DESC, entity_id DESC) INTO v_ids20 FROM _k957 WHERE lbl = 'p20';
  IF cardinality(v_ids1) <> 10 OR cardinality(v_ids2) <> 10 OR v_ids1 && v_ids2 OR (v_ids1 || v_ids2) IS DISTINCT FROM v_ids20 THEN
    v_fail := v_fail || 'keyset paging mismatch'::text;
  END IF;

  -- 5. block: a game creator visible to the viewer is blocked; nothing of theirs stays visible
  SELECT e.creator_user_id INTO v_creator
    FROM _k957 k JOIN public.games g ON g.id = k.entity_id JOIN public.events e ON e.id = g.event_id
   WHERE k.lbl = 'games' AND e.creator_user_id IS DISTINCT FROM v_viewer
   LIMIT 1;
  IF v_creator IS NULL THEN v_fail := v_fail || 'block: no visible creator to block'::text; END IF;
  IF NOT v_neg THEN
    INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (v_viewer, v_creator);
  END IF;
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k957 SELECT 'blocked_all', s.* FROM public.active_stream(NULL, NULL, 50) s;
  INSERT INTO _k957 SELECT 'blocked_games', s.* FROM public.active_stream(c_games, NULL, 50) s;
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_n
    FROM _k957 k
    LEFT JOIN public.profiles ap ON ap.id = k.actor_profile_id
    LEFT JOIN public.games g ON k.entity_kind = 'game' AND g.id = k.entity_id
    LEFT JOIN public.events e ON e.id = g.event_id
   WHERE k.lbl IN ('blocked_all', 'blocked_games') AND (ap.user_id = v_creator OR e.creator_user_id = v_creator);
  IF v_n > 0 THEN v_fail := v_fail || format('block: %s rows of the blocked creator still visible', v_n); END IF;

  -- 6. anon gets 42501
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
    RAISE EXCEPTION 'KAN-957 PASS (neg=%): %', v_neg, v_info;
  ELSE
    RAISE EXCEPTION 'KAN-957 FAIL (neg=%) % failures: % | %', v_neg, cardinality(v_fail), array_to_string(v_fail, ' || '), v_info;
  END IF;
END
$t$;

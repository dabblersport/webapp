-- KAN-967 live test: public.active_stream new event types (migration 20261116154732_kan967_active_stream_honours).
-- One DO block. It always ends in RAISE EXCEPTION, so everything it seeds (two test areas in cities 'K967-A' and
-- 'K967-B', venues, spaces, bookings, photos, game events + games + roster, ratings, venue_rating_events, hashtags,
-- posts, a block, user_status rows, profile city edits) and the pg_temp pre-image copy roll back.
-- Calls run as `authenticated` with a real personal profile's JWT sub (the viewer); seeding runs as the owner.
-- Probes (TAP-style ok/not ok lines in the result message):
--   identity   the pre-image body is rebuilt from the live prosrc by cutting out the KAN-967 fragments (md5 must equal
--              the pre-image prosrc 7247ff6bcb188596689971c432c88ac3), created as pg_temp.k967_pre, and its rows are
--              compared with the live function's first 18 columns for page 1, page 2 (keyset), each old type and a
--              city; the 10 new columns are NULL on every old-type row.
--   keyset     paging in 7s through the whole stream: no duplicate (type, entity), strictly descending keys, first 50
--              equal one 50-row call.
--   rules      trending_sport (>= 3 games, >= 10 %, prev 0 = 100, top 2 per city, cancelled ignored),
--              trending_hashtag (today, fallback to yesterday per city, banned / unapproved / invisible ignored,
--              top 2), player_week/month (>= 3 games, games x avg rating, neutral 3.0, one per city, stats exactly
--              games/rating/hosted, a block hides the card without promoting a runner-up), venue_week/month (games,
--              rating tiebreak, one per city, stats bookings/games/rating, photo by sort_order), venue_rating (actor,
--              stars, aggregate avg/count, quote, rated_game_at, hidden rater excluded), venue_day never emitted.
--   filters    the client families (trending / players / venues) return only their types and include the new ones.
--   anon       anon cannot execute.
-- Expected: ERROR 'KAN-967 PASS ...'. v_neg := true is the negative control: every rule expectation is inverted
-- (the excluded rows are expected, the winners swapped, anon expected to succeed), so the run must end 'KAN-967 FAIL'.
DO $t$
DECLARE
  v_neg     boolean := false;
  v_fail    text[] := '{}';
  v_ok      text[] := '{}';
  v_src     text;
  v_pre     text;
  v_i       int;
  v_j       int;
  v_n       int;
  v_m       int;
  v_x       text;
  v_y       text;
  r         record;
  t         text;
  c_types   text[] := ARRAY['player_joined','venue_added','game_created','game_started','game_ended',
                            'meetup_created','meetup_started','meetup_completed'];
  c_new     text[] := ARRAY['trending_sport','trending_hashtag','player_week','player_month','venue_week',
                            'venue_month','venue_rating'];
  c_begin   text := '  -- KAN-967 BEGIN new branches';
  c_end     text := '  -- KAN-967 END new branches';
  pf        uuid[];    -- profile ids: [1] viewer, [2..7] players
  uf        uuid[];    -- their user ids
  sp        uuid[];    -- 5 sports; sp[5] is the honour games' sport
  a_a uuid := gen_random_uuid(); a_b uuid := gen_random_uuid();
  v1 uuid := gen_random_uuid(); v2 uuid := gen_random_uuid(); v3 uuid := gen_random_uuid(); v4 uuid := gen_random_uuid();
  s1 uuid := gen_random_uuid();
  h1 uuid := gen_random_uuid(); h2 uuid := gen_random_uuid(); h3 uuid := gen_random_uuid();
  h4 uuid := gen_random_uuid(); h5 uuid := gen_random_uuid();
  v_geo     uuid;
  v_kind    public.posts.kind%TYPE;
  wk_ps timestamptz; wk_pe timestamptz; mo_ps timestamptz; mo_pe timestamptz; today0 timestamptz;
  g_wk uuid[] := '{}'; g_mo uuid[] := '{}'; g uuid;
  k int;
BEGIN
  -- 0. rebuild the pre-image as pg_temp.k967_pre ------------------------------------------------------------------
  SELECT p.prosrc INTO v_src FROM pg_proc p
   WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  v_pre := replace(v_src, 'ev0 AS (', 'ev AS (');
  v_i := position(c_begin IN v_pre);
  v_j := position(c_end IN v_pre);
  IF v_i = 0 OR v_j <= v_i THEN RAISE EXCEPTION 'KAN-967 FAIL: KAN-967 block markers not found in live prosrc'; END IF;
  v_j := v_j + position(E'\n' IN substr(v_pre, v_j));          -- through the END line's newline
  v_pre := left(v_pre, v_i - 1) || substr(v_pre, v_j);
  v_pre := replace(v_pre, ', ev.metric_value DESC NULLS LAST, ev.city  -- KAN-967 tiebreak', '');
  v_pre := regexp_replace(v_pre, E'cn\\.space_count,  -- KAN-964\\n[^\\n]*-- KAN-967\\n[^\\n]*-- KAN-967',
                          'cn.space_count  -- KAN-964');
  v_pre := replace(v_pre, E'\n          OR (pg.entity_kind = ''sport'' AND s.id = pg.entity_id)  -- KAN-967', '');
  IF md5(v_pre) <> '7247ff6bcb188596689971c432c88ac3' THEN
    RAISE EXCEPTION 'KAN-967 FAIL: rebuilt pre-image md5 % <> 7247ff6bcb188596689971c432c88ac3', md5(v_pre);
  END IF;
  EXECUTE format($f$CREATE FUNCTION pg_temp.k967_pre(p_event_types text[] DEFAULT NULL, p_city text DEFAULT NULL, p_limit integer DEFAULT 30, p_before timestamptz DEFAULT NULL, p_before_type text DEFAULT NULL, p_before_entity uuid DEFAULT NULL)
    RETURNS TABLE(event_type text, event_at timestamptz, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text,
                  actor_display_name text, actor_avatar_url text, detail text, start_at timestamptz, end_at timestamptz,
                  is_live boolean, sport_names_en text[], sport_names_ar text[],
                  participant_count integer, capacity integer, space_count integer)
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS %L$f$, v_pre);
  GRANT EXECUTE ON FUNCTION pg_temp.k967_pre(text[], text, integer, timestamptz, text, uuid) TO authenticated;

  -- 1. seed ---------------------------------------------------------------------------------------------------------
  SELECT array_agg(id ORDER BY created_at, id), array_agg(user_id ORDER BY created_at, id) INTO pf, uf
    FROM (SELECT DISTINCT ON (p.user_id) p.id, p.user_id, p.created_at
            FROM public.profiles p
           WHERE p.profile_type = 'personal' AND p.user_id IS NOT NULL AND p.is_active
             AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.profile_id = p.id)
             AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.creator_profile_id = p.id)
             AND NOT EXISTS (SELECT 1 FROM public.profiles q WHERE q.user_id = p.user_id AND q.id <> p.id)
           ORDER BY p.user_id, p.created_at) x
   LIMIT 7;
  pf := pf[1:7]; uf := uf[1:7];
  IF cardinality(pf) < 7 THEN RAISE EXCEPTION 'KAN-967 FAIL: need 7 free personal profiles, found %', cardinality(pf); END IF;
  SELECT array_agg(id ORDER BY ord) INTO sp FROM (SELECT id, row_number() OVER (ORDER BY is_active DESC, name_en, id) AS ord FROM public.sports ORDER BY is_active DESC, name_en, id LIMIT 5) s;  -- sp[1..4] active (venue_spaces refuses inactive)
  SELECT geo_location_id INTO v_geo FROM public.venues WHERE geo_location_id IS NOT NULL LIMIT 1;
  v_kind := 'original';

  today0 := date_trunc('day', now() AT TIME ZONE 'Asia/Dubai') AT TIME ZONE 'Asia/Dubai';
  wk_pe  := date_trunc('week', now() AT TIME ZONE 'Asia/Dubai') AT TIME ZONE 'Asia/Dubai';
  wk_ps  := (date_trunc('week', now() AT TIME ZONE 'Asia/Dubai') - interval '7 days') AT TIME ZONE 'Asia/Dubai';
  mo_pe  := date_trunc('month', now() AT TIME ZONE 'Asia/Dubai') AT TIME ZONE 'Asia/Dubai';
  mo_ps  := (date_trunc('month', now() AT TIME ZONE 'Asia/Dubai') - interval '1 month') AT TIME ZONE 'Asia/Dubai';

  -- everyone visible; players live in K967-A except pf[6] (K967-B); pf[7] is hidden (hide_in_search)
  INSERT INTO public.user_status (user_id, is_benched, hide_in_search)
  SELECT u, false, (u = uf[7]) FROM unnest(uf) u
  ON CONFLICT (user_id) DO UPDATE SET is_benched = false, hide_in_search = excluded.hide_in_search;
  UPDATE public.profiles SET city = CASE WHEN id = pf[6] THEN 'K967-B' ELSE 'K967-A' END WHERE id = ANY (pf[2:7]);

  INSERT INTO public.areas (id, country, city, name, center_lat, center_lng, district)
  VALUES (a_a, 'AE', 'K967-A', 'K967 Area A', 25.2, 55.3, 'K967'), (a_b, 'AE', 'K967-B', 'K967 Area B', 25.3, 55.4, 'K967');
  INSERT INTO public.venues (id, name_en, geo_location_id, area_id, rating, rating_count, is_active)
  VALUES (v1, 'K967 V1', v_geo, a_a, 3.0, 10, true), (v2, 'K967 V2', v_geo, a_a, 4.9, 50, true),
         (v3, 'K967 V3', v_geo, a_b, 4.0, 5, true),  (v4, 'K967 V4', v_geo, a_b, 4.5, 7, true);
  INSERT INTO public.venue_spaces (id, venue_id, sport_id) VALUES (s1, v1, sp[1]);
  INSERT INTO public.venue_bookings (venue_space_id, starts_at, ends_at, source_type, status, created_by)
  VALUES (s1, wk_ps + interval '1 day', wk_ps + interval '1 day 1 hour', 'manual', 'confirmed', uf[1]),
         (s1, wk_ps + interval '2 day', wk_ps + interval '2 day 1 hour', 'manual', 'confirmed', uf[1]),
         (s1, wk_ps + interval '3 day', wk_ps + interval '3 day 1 hour', 'manual', 'cancelled', uf[1]),
         (s1, wk_ps - interval '1 day', wk_ps - interval '23 hours', 'manual', 'confirmed', uf[1]);   -- outside the week
  INSERT INTO public.venue_photos (venue_id, url, sort_order)
  VALUES (v1, 'https://k967.test/second.jpg', 2), (v1, 'https://k967.test/first.jpg', 1);

  -- trending sport seeds: events only (no games row), city A: sp1 4/1 (300), sp2 3/1 (200), sp3 3/2 (50), sp4 3/3 (0);
  -- city B: sp1 3/0 (prev 0 -> 100), sp4 2/0 + 2 cancelled (below 3).
  FOR r IN SELECT * FROM (VALUES (a_a, 1, 4, 1), (a_a, 2, 3, 1), (a_a, 3, 3, 2), (a_a, 4, 3, 3),
                                 (a_b, 1, 3, 0), (a_b, 4, 2, 0)) x(area, si, n_now, n_prev) LOOP
    FOR k IN 1 .. r.n_now + r.n_prev LOOP
      INSERT INTO public.events (capacity, geo_location_id, id, event_type, creator_profile_id, creator_user_id, start_at, end_at, area_id, sport_id, title)
      VALUES (10, v_geo, gen_random_uuid(), 'game', pf[1], uf[1],
              CASE WHEN k <= r.n_now THEN now() - interval '2 days' - k * interval '1 minute'
                   ELSE now() - interval '9 days' - k * interval '1 minute' END,
              CASE WHEN k <= r.n_now THEN now() - interval '2 days' ELSE now() - interval '9 days' END,
              r.area, sp[r.si], 'K967 trend');
    END LOOP;
  END LOOP;
  INSERT INTO public.events (capacity, geo_location_id, id, event_type, creator_profile_id, creator_user_id, start_at, end_at, area_id, sport_id, title, is_cancelled)
  SELECT 10, v_geo, gen_random_uuid(), 'game', pf[1], uf[1], now() - interval '1 day', now() - interval '23 hours', a_b, sp[4], 'K967 cancelled', true
    FROM generate_series(1, 2);

  -- honour games: last week, 4 games at v1 (city A) hosted by pf[2]; month: 3 games at v2 in the previous month.
  --   week roster: pf[2] in all 4, pf[3] in games 1-3 (rated 5), pf[4] in 2 games, pf[6] (city B) in games 1-3,
  --   pf[7] (hidden) in all 4.  month roster: pf[4] in all 3.
  FOR k IN 1 .. 4 LOOP
    g := gen_random_uuid();
    INSERT INTO public.events (capacity, geo_location_id, id, event_type, creator_profile_id, creator_user_id, start_at, end_at, area_id, sport_id, venue_id, title)
    VALUES (10, v_geo, g, 'game', pf[2], uf[2], wk_ps + k * interval '1 day', wk_ps + k * interval '1 day' + interval '1 hour', a_a, sp[5], v1, 'K967 week');
    INSERT INTO public.games (id, event_id) VALUES (g, g);
    g_wk := g_wk || g;
  END LOOP;
  -- city B venues: v3 and v4 one game each (tie on games -> rating decides v4)
  FOR r IN SELECT * FROM (VALUES (v3), (v4)) x(vid) LOOP
    g := gen_random_uuid();
    INSERT INTO public.events (capacity, geo_location_id, id, event_type, creator_profile_id, creator_user_id, start_at, end_at, area_id, sport_id, venue_id, title)
    VALUES (10, v_geo, g, 'game', pf[6], uf[6], wk_ps + interval '1 day', wk_ps + interval '1 day 1 hour', a_b, sp[5], r.vid, 'K967 weekB');
    INSERT INTO public.games (id, event_id) VALUES (g, g);
  END LOOP;
  -- v2 has 1 game this week (higher rating than v1, fewer games -> v1 wins the week)
  g := gen_random_uuid();
  INSERT INTO public.events (capacity, geo_location_id, id, event_type, creator_profile_id, creator_user_id, start_at, end_at, area_id, sport_id, venue_id, title)
  VALUES (10, v_geo, g, 'game', pf[5], uf[5], wk_ps + interval '2 day', wk_ps + interval '2 day 1 hour', a_a, sp[5], v2, 'K967 weekV2');
  INSERT INTO public.games (id, event_id) VALUES (g, g);
  FOR k IN 1 .. 3 LOOP
    g := gen_random_uuid();
    INSERT INTO public.events (capacity, geo_location_id, id, event_type, creator_profile_id, creator_user_id, start_at, end_at, area_id, sport_id, venue_id, title)
    VALUES (10, v_geo, g, 'game', pf[5], uf[5], mo_ps + k * interval '1 day', mo_ps + k * interval '1 day' + interval '1 hour', a_a, sp[5], v2, 'K967 month');
    INSERT INTO public.games (id, event_id) VALUES (g, g);
    g_mo := g_mo || g;
  END LOOP;
  INSERT INTO public.game_roster (game_id, profile_id, role, status)
  SELECT gid, pf[2], 'player', 'active' FROM unnest(g_wk) gid
  UNION ALL SELECT gid, pf[3], 'player', 'active' FROM unnest(g_wk[1:3]) gid
  UNION ALL SELECT gid, pf[4], 'player', 'active' FROM unnest(g_wk[1:2]) gid
  UNION ALL SELECT gid, pf[7], 'player', 'active' FROM unnest(g_wk) gid
  UNION ALL SELECT gid, pf[4], 'player', 'active' FROM unnest(g_mo) gid;
  -- pf[6] (city B) in 3 games: the city B games are 2, so use week games 1-3 (city of the PLAYER decides)
  INSERT INTO public.game_roster (game_id, profile_id, role, status)
  SELECT gid, pf[6], 'player', 'active' FROM unnest(g_wk[1:3]) gid;
  -- pf[3] rated 5 in each of its 3 games -> 3 x 5 = 15 beats pf[2] 4 x 3.0 (neutral) = 12
  INSERT INTO public.ratings (rater_user_id, context_type, context_id, target_type, target_user_id, stars)
  SELECT uf[2], 'game', gid, 'user', uf[3], 5 FROM unnest(g_wk[1:3]) gid;

  -- venue ratings: pf[3] rates v1 (facility 4, staff 5; normalised mean 4.5), pf[7] (hidden) rates v2
  INSERT INTO public.venue_rating_events (game_id, venue_id, rater_user_id, rater_profile_id, scores, comment, created_at)
  VALUES (g_wk[1], v1, uf[3], pf[3], '{"facility":4,"staff":5}', 'K967 great courts', now() - interval '1 hour'),
         (g_mo[1], v2, uf[7], pf[7], '{"facility":5}', 'K967 hidden', now() - interval '1 hour');

  -- hashtags and posts
  INSERT INTO public.hashtags (id, tag, display_tag, slug, is_approved, is_banned)
  VALUES (h1, 'k967one', 'K967One', 'k967one', true, false), (h2, 'k967two', 'K967Two', 'k967two', true, false),
         (h3, 'k967three', 'K967Three', 'k967three', true, false), (h4, 'k967banned', 'K967Banned', 'k967banned', true, true),
         (h5, 'k967unapp', 'K967Unapp', 'k967unapp', false, false);
  CREATE TEMP TABLE _k967_posts (pid uuid, hid uuid) ON COMMIT DROP;
  -- city A today: h1 x3, h2 x2, h3 x1, h4 x5 (banned), h5 x5 (unapproved), h2 x5 private by pf[4] (invisible)
  -- city B: none today; yesterday h3 x2, h1 x1
  FOR r IN SELECT * FROM (VALUES (h1, 3, 'K967-A', 0, 'public', 2), (h2, 2, 'K967-A', 0, 'public', 2),
                                 (h3, 1, 'K967-A', 0, 'public', 2), (h4, 5, 'K967-A', 0, 'public', 2),
                                 (h5, 5, 'K967-A', 0, 'public', 2), (h2, 5, 'K967-A', 0, 'private', 4),
                                 (h3, 2, 'K967-B', 1, 'public', 2), (h1, 1, 'K967-B', 1, 'public', 2))
                     x(hid, n, city, days_ago, vis, au) LOOP
    FOR k IN 1 .. r.n LOOP
      WITH ins AS (
        INSERT INTO public.posts (author_profile_id, author_user_id, kind, visibility, venue_id, posted_from_city, body, created_at)
        VALUES (pf[r.au], uf[r.au], v_kind, r.vis, v1, r.city, 'K967 post',
                CASE WHEN r.days_ago = 0 THEN LEAST(now(), today0 + interval '1 second') ELSE today0 - interval '12 hours' END)
        RETURNING id)
      INSERT INTO _k967_posts SELECT id, r.hid FROM ins;
    END LOOP;
  END LOOP;
  INSERT INTO public.post_hashtags (post_id, hashtag_id) SELECT pid, hid FROM _k967_posts;

  -- 2. calls, as authenticated ---------------------------------------------------------------------------------------
  CREATE TEMP TABLE _k967 ON COMMIT DROP AS SELECT ''::text AS lbl, s.* FROM public.active_stream() s WHERE false;
  CREATE TEMP TABLE _k967o ON COMMIT DROP AS SELECT ''::text AS lbl, s.* FROM pg_temp.k967_pre() s WHERE false;
  GRANT ALL ON _k967, _k967o TO authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uf[1], 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k967  SELECT 'p1', s.* FROM public.active_stream(c_types, NULL, 50) s;
  INSERT INTO _k967o SELECT 'p1', s.* FROM pg_temp.k967_pre(NULL, NULL, 50) s;
  SELECT * INTO r FROM _k967 WHERE lbl = 'p1' ORDER BY event_at, event_type, entity_id LIMIT 1;   -- last row of p1
  INSERT INTO _k967  SELECT 'p2', s.* FROM public.active_stream(c_types, NULL, 50, r.event_at, r.event_type, r.entity_id) s;
  INSERT INTO _k967o SELECT 'p2', s.* FROM pg_temp.k967_pre(NULL, NULL, 50, r.event_at, r.event_type, r.entity_id) s;
  FOREACH t IN ARRAY c_types LOOP
    INSERT INTO _k967  SELECT 'type:' || t, s.* FROM public.active_stream(ARRAY[t], NULL, 50) s;
    INSERT INTO _k967o SELECT 'type:' || t, s.* FROM pg_temp.k967_pre(ARRAY[t], NULL, 50) s;
  END LOOP;
  INSERT INTO _k967  SELECT 'city', s.* FROM public.active_stream(c_types, 'dubai', 50) s;
  INSERT INTO _k967o SELECT 'city', s.* FROM pg_temp.k967_pre(NULL, 'dubai', 50) s;
  INSERT INTO _k967 SELECT 'A', s.* FROM public.active_stream(c_new || ARRAY['venue_day'], 'K967-A', 50) s;
  INSERT INTO _k967 SELECT 'B', s.* FROM public.active_stream(c_new || ARRAY['venue_day'], 'k967-b', 50) s;
  INSERT INTO _k967 SELECT 'all', s.* FROM public.active_stream(NULL, NULL, 50) s;
  INSERT INTO _k967 SELECT 'fam:trending', s.* FROM public.active_stream(ARRAY['trending_sport','trending_hashtag'], NULL, 50) s;
  INSERT INTO _k967 SELECT 'fam:players', s.* FROM public.active_stream(ARRAY['player_joined','player_week','player_month'], 'K967-A', 50) s;
  INSERT INTO _k967 SELECT 'fam:venues', s.* FROM public.active_stream(ARRAY['venue_added','venue_week','venue_month','venue_rating','venue_day'], 'K967-A', 50) s;
  -- keyset walk, pages of 7
  r := NULL;
  FOR k IN 1 .. 200 LOOP
    IF r IS NULL THEN
      INSERT INTO _k967 SELECT 'walk' || lpad(k::text, 3, '0'), s.* FROM public.active_stream(NULL, NULL, 7) s;
    ELSE
      INSERT INTO _k967 SELECT 'walk' || lpad(k::text, 3, '0'), s.* FROM public.active_stream(NULL, NULL, 7, r.event_at, r.event_type, r.entity_id) s;
    END IF;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXIT WHEN v_n < 7;
    SELECT * INTO r FROM _k967 WHERE lbl = 'walk' || lpad(k::text, 3, '0') ORDER BY event_at, event_type, entity_id LIMIT 1;
  END LOOP;
  EXECUTE 'RESET ROLE';
  -- a block between the viewer and the city B week winner pf[6] (applied after the main calls)
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (uf[1], uf[6]);
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO _k967 SELECT 'Bblock', s.* FROM public.active_stream(ARRAY['player_week'], 'K967-B', 50) s;
  EXECUTE 'RESET ROLE';

  -- 3. probes --------------------------------------------------------------------------------------------------------
  -- identity: old-type rows, 18 columns, equal to the pre-image for p1, p2, each type, city
  FOR t IN SELECT DISTINCT lbl FROM _k967o LOOP
    SELECT count(*) INTO v_n FROM (
      (SELECT event_type, event_at, entity_kind, entity_id, actor_profile_id, city, title, actor_display_name, actor_avatar_url,
              detail, start_at, end_at, is_live, sport_names_en, sport_names_ar, participant_count, capacity, space_count
         FROM _k967 WHERE lbl = t
       EXCEPT ALL
       SELECT event_type, event_at, entity_kind, entity_id, actor_profile_id, city, title, actor_display_name, actor_avatar_url,
              detail, start_at, end_at, is_live, sport_names_en, sport_names_ar, participant_count, capacity, space_count
         FROM _k967o WHERE lbl = t)
      UNION ALL
      (SELECT event_type, event_at, entity_kind, entity_id, actor_profile_id, city, title, actor_display_name, actor_avatar_url,
              detail, start_at, end_at, is_live, sport_names_en, sport_names_ar, participant_count, capacity, space_count
         FROM _k967o WHERE lbl = t
       EXCEPT ALL
       SELECT event_type, event_at, entity_kind, entity_id, actor_profile_id, city, title, actor_display_name, actor_avatar_url,
              detail, start_at, end_at, is_live, sport_names_en, sport_names_ar, participant_count, capacity, space_count
         FROM _k967 WHERE lbl = t)) d;
    SELECT count(*) INTO v_m FROM _k967o WHERE lbl = t;
    IF v_n = 0 THEN v_ok := v_ok || format('identity %s (%s rows)', t, v_m);
    ELSE v_fail := v_fail || format('identity %s: %s differing rows', t, v_n); END IF;
  END LOOP;
  SELECT count(*) INTO v_n FROM _k967o WHERE lbl = 'p1';
  IF v_n = 0 THEN v_fail := v_fail || 'identity p1 is empty (vacuous)'::text; END IF;
  SELECT count(*) INTO v_n FROM _k967
   WHERE event_type = ANY (c_types)
     AND (metric_kind IS NOT NULL OR metric_value IS NOT NULL OR period_start IS NOT NULL OR stats IS NOT NULL
          OR rating IS NOT NULL OR rating_count IS NOT NULL OR photo_url IS NOT NULL OR quote IS NOT NULL
          OR rated_game_at IS NOT NULL OR venue_rating_avg IS NOT NULL);
  IF v_n = 0 THEN v_ok := v_ok || 'new columns NULL on old types'::text; ELSE v_fail := v_fail || format('new columns set on %s old rows', v_n); END IF;

  -- keyset walk
  SELECT count(*), count(DISTINCT (event_type, entity_id)) INTO v_n, v_m FROM _k967 WHERE lbl LIKE 'walk%';
  IF v_n = v_m AND v_n > 50 THEN v_ok := v_ok || format('keyset walk %s rows, no duplicate', v_n);
  ELSE v_fail := v_fail || format('keyset walk rows %s distinct %s', v_n, v_m); END IF;
  SELECT count(*) INTO v_n FROM (
    SELECT (event_at, event_type, entity_id) AS k1,
           lag((event_at, event_type, entity_id)) OVER (ORDER BY lbl, event_at DESC, event_type DESC, entity_id DESC) AS k0
      FROM _k967 WHERE lbl LIKE 'walk%') x WHERE NOT (x.k0 > x.k1);
  IF v_n = 0 THEN v_ok := v_ok || 'keyset strictly descending'::text; ELSE v_fail := v_fail || format('keyset not descending at %s rows', v_n); END IF;
  SELECT count(*) INTO v_n FROM (
    (SELECT event_type, entity_id FROM _k967 WHERE lbl = 'all'
      EXCEPT SELECT event_type, entity_id FROM (SELECT * FROM _k967 WHERE lbl LIKE 'walk%' ORDER BY event_at DESC, event_type DESC, entity_id DESC LIMIT 50) w)) d;
  IF v_n = 0 THEN v_ok := v_ok || 'walk first 50 = one 50-row call'::text; ELSE v_fail := v_fail || format('walk vs 50-row call: %s missing', v_n); END IF;

  -- trending_sport
  SELECT string_agg(s.idx::text || '=' || k.metric_value::text, ',' ORDER BY k.metric_value DESC) INTO v_x
    FROM _k967 k JOIN LATERAL (SELECT i AS idx FROM generate_subscripts(sp, 1) i WHERE sp[i] = k.entity_id) s ON true
   WHERE k.lbl = 'A' AND k.event_type = 'trending_sport';
  v_y := CASE WHEN v_neg THEN '1=300.0,2=200.0,3=50.0' ELSE '1=300.0,2=200.0' END;
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || format('trending_sport A top 2 >=10%%: %s', v_x);
  ELSE v_fail := v_fail || format('trending_sport A got %s want %s', v_x, v_y); END IF;
  SELECT string_agg(s.idx::text || '=' || k.metric_value::text || '/' || k.metric_kind || '/' || k.title || '/' || array_length(k.sport_names_en, 1) || '/' ||
                    (k.event_at = today0)::text, ',') INTO v_x
    FROM _k967 k JOIN LATERAL (SELECT i AS idx FROM generate_subscripts(sp, 1) i WHERE sp[i] = k.entity_id) s ON true
   WHERE k.lbl = 'B' AND k.event_type = 'trending_sport';
  SELECT '1=100/games_growth_pct/' || name_en || '/1/true' INTO v_y FROM public.sports WHERE id = sp[1];
  IF v_neg THEN v_y := v_y || ',4=100/games_growth_pct/x/1/true'; END IF;
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || 'trending_sport B prev 0 = 100, <3 and cancelled ignored, event_at today 00:00 Dubai'::text;
  ELSE v_fail := v_fail || format('trending_sport B got %s want %s', v_x, v_y); END IF;
  SELECT count(*), max(city) INTO v_n, v_x FROM _k967 WHERE lbl = 'all' AND event_type = 'trending_sport' AND entity_id = sp[1];
  IF v_n = 1 AND v_x = 'K967-A' THEN v_ok := v_ok || 'trending_sport all-cities: one row, highest growth city'::text;
  ELSE v_fail := v_fail || format('trending_sport all-cities sp1 rows %s city %s', v_n, v_x); END IF;

  -- trending_hashtag
  SELECT string_agg(k.title || '/' || k.detail || '/' || k.metric_kind || '/' || k.metric_value::text, ',' ORDER BY k.metric_value DESC) INTO v_x
    FROM _k967 k WHERE k.lbl = 'A' AND k.event_type = 'trending_hashtag';
  v_y := CASE WHEN v_neg THEN '#K967Two/k967two/posts_today/7,#K967One/k967one/posts_today/3'
              ELSE '#K967One/k967one/posts_today/3,#K967Two/k967two/posts_today/2' END;
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || format('trending_hashtag A today top 2, banned/unapproved/private ignored: %s', v_x);
  ELSE v_fail := v_fail || format('trending_hashtag A got %s want %s', v_x, v_y); END IF;
  SELECT string_agg(k.title || '/' || k.metric_kind || '/' || k.metric_value::text, ',' ORDER BY k.metric_value DESC) INTO v_x
    FROM _k967 k WHERE k.lbl = 'B' AND k.event_type = 'trending_hashtag';
  v_y := CASE WHEN v_neg THEN '#K967Three/posts_today/2,#K967One/posts_today/1'
              ELSE '#K967Three/posts_yesterday/2,#K967One/posts_yesterday/1' END;
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || 'trending_hashtag B falls back to yesterday'::text;
  ELSE v_fail := v_fail || format('trending_hashtag B got %s want %s', v_x, v_y); END IF;

  -- player_week / player_month
  SELECT string_agg(k.event_type || ':' || array_position(pf, k.entity_id) || '/' || (k.actor_profile_id = k.entity_id)::text
                    || '/' || k.period_start || '/' || (k.event_at = CASE k.event_type WHEN 'player_week' THEN wk_pe ELSE mo_pe END)::text
                    || '/' || k.stats::text || '/' || COALESCE(k.rating::text, 'null') || '/' || k.rating_count, ' ; ' ORDER BY k.event_type DESC) INTO v_x
    FROM _k967 k WHERE k.lbl = 'A' AND k.event_type IN ('player_week', 'player_month');
  v_y := format('player_week:%s/true/%s/true/[{"key": "games", "value": 3}, {"key": "rating", "value": 5.0}, {"key": "hosted", "value": 0}]/5.0/3'
                || ' ; player_month:4/true/%s/true/[{"key": "games", "value": 3}, {"key": "rating", "value": 3.0}, {"key": "hosted", "value": 0}]/null/0',
                CASE WHEN v_neg THEN 2 ELSE 3 END, wk_ps AT TIME ZONE 'Asia/Dubai', mo_ps AT TIME ZONE 'Asia/Dubai');
  v_y := replace(v_y, ' 00:00:00', '');
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || 'player_week A = pf3 (3x5.0 beats 4x3.0 neutral; hidden pf7 and 2-game pf4 out), player_month A = pf4 neutral, stats exact'::text;
  ELSE v_fail := v_fail || format('players A got %s want %s', v_x, v_y); END IF;
  SELECT count(*) FILTER (WHERE event_type = 'player_week' AND entity_id = pf[6]), count(*) FILTER (WHERE event_type = 'player_week')
    INTO v_n, v_m FROM _k967 WHERE lbl = 'B';
  IF v_n = 1 AND v_m = 1 THEN v_ok := v_ok || 'player_week one per city (B = pf6)'::text;
  ELSE v_fail := v_fail || format('player_week B pf6 %s of %s', v_n, v_m); END IF;
  SELECT count(*) INTO v_n FROM _k967 WHERE lbl = 'Bblock';
  v_m := CASE WHEN v_neg THEN 1 ELSE 0 END;
  IF v_n = v_m THEN v_ok := v_ok || 'blocked winner hidden, no runner-up promoted'::text;
  ELSE v_fail := v_fail || format('Bblock rows %s', v_n); END IF;

  -- venue_week / venue_month
  SELECT string_agg(k.event_type || ':' || k.title || '/' || k.stats::text || '/' || k.rating || '/' || k.rating_count || '/'
                    || COALESCE(k.photo_url, 'null') || '/' || COALESCE(k.space_count::text, 'null') || '/' || k.period_start,
                    ' ; ' ORDER BY k.event_type DESC) INTO v_x
    FROM _k967 k WHERE k.lbl = 'A' AND k.event_type IN ('venue_week', 'venue_month');
  v_y := format('venue_week:%s ; venue_month:K967 V2/[{"key": "bookings", "value": 0}, {"key": "games", "value": 3}, {"key": "rating", "value": 4.9}]/4.9/50/null/0/%s',
                CASE WHEN v_neg THEN 'K967 V2' ELSE 'K967 V1' END
                || '/[{"key": "bookings", "value": 2}, {"key": "games", "value": 4}, {"key": "rating", "value": 3.0}]/3.0/10/https://k967.test/first.jpg/1/'
                || (wk_ps AT TIME ZONE 'Asia/Dubai')::date::text,
                (mo_ps AT TIME ZONE 'Asia/Dubai')::date::text);
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || 'venue_week A = V1 (games beat rating), venue_month A = V2, stats/photo/spaces exact'::text;
  ELSE v_fail := v_fail || format('venues A got %s want %s', v_x, v_y); END IF;
  SELECT string_agg(k.title, ',') INTO v_x FROM _k967 k WHERE k.lbl = 'B' AND k.event_type = 'venue_week';
  v_y := CASE WHEN v_neg THEN 'K967 V3' ELSE 'K967 V4' END;
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || 'venue_week B tie on games -> rating tiebreak V4'::text;
  ELSE v_fail := v_fail || format('venue_week B got %s want %s', v_x, v_y); END IF;

  -- venue_rating
  SELECT string_agg(k.title || '/' || array_position(pf, k.actor_profile_id) || '/' || k.rating || '/' || k.venue_rating_avg || '/' || k.rating_count
                    || '/' || k.quote || '/' || (k.rated_game_at = wk_ps + interval '1 day')::text, ',') INTO v_x
    FROM _k967 k WHERE k.lbl = 'A' AND k.event_type = 'venue_rating';
  SELECT 'K967 V1/3/4.5/' || composite_score || '/1/K967 great courts/true' INTO v_y FROM public.venue_rating_aggregate WHERE venue_id = v1;
  IF v_neg THEN v_y := v_y || ',K967 V2/7/5.0/x/1/K967 hidden/false'; END IF;
  IF v_x IS NOT DISTINCT FROM v_y THEN v_ok := v_ok || format('venue_rating: %s (hidden rater excluded)', v_x);
  ELSE v_fail := v_fail || format('venue_rating got %s want %s', v_x, v_y); END IF;

  -- venue_day never; every new type fired at least once
  SELECT count(*) INTO v_n FROM _k967 WHERE event_type = 'venue_day';
  IF v_n = 0 THEN v_ok := v_ok || 'venue_day not emitted'::text; ELSE v_fail := v_fail || format('venue_day rows %s', v_n); END IF;
  SELECT array_agg(t0 ORDER BY t0) INTO v_x FROM unnest(c_new) t0 WHERE NOT EXISTS (SELECT 1 FROM _k967 WHERE lbl IN ('A','B') AND event_type = t0);
  IF v_x IS NULL THEN v_ok := v_ok || 'all 7 new types fired'::text; ELSE v_fail := v_fail || format('types never fired: %s', v_x); END IF;

  -- filters (client families)
  SELECT count(*) FILTER (WHERE event_type NOT IN ('trending_sport','trending_hashtag')),
         count(DISTINCT event_type) INTO v_n, v_m FROM _k967 WHERE lbl = 'fam:trending';
  IF v_n = 0 AND v_m = 2 THEN v_ok := v_ok || 'family trending'::text; ELSE v_fail := v_fail || format('family trending stray %s types %s', v_n, v_m); END IF;
  SELECT count(*) FILTER (WHERE event_type NOT IN ('player_joined','player_week','player_month')),
         count(DISTINCT event_type) FILTER (WHERE event_type IN ('player_week','player_month')) INTO v_n, v_m FROM _k967 WHERE lbl = 'fam:players';
  IF v_n = 0 AND v_m = 2 THEN v_ok := v_ok || 'family players + city'::text; ELSE v_fail := v_fail || format('family players stray %s honours %s', v_n, v_m); END IF;
  SELECT count(*) FILTER (WHERE event_type NOT IN ('venue_added','venue_week','venue_month','venue_rating','venue_day')),
         count(DISTINCT event_type) FILTER (WHERE event_type IN ('venue_week','venue_month','venue_rating')) INTO v_n, v_m FROM _k967 WHERE lbl = 'fam:venues';
  IF v_n = 0 AND v_m = 3 THEN v_ok := v_ok || 'family venues + city'::text; ELSE v_fail := v_fail || format('family venues stray %s new %s', v_n, v_m); END IF;
  SELECT count(*) INTO v_n FROM _k967 WHERE lbl IN ('A','B') AND lower(city) <> lower(CASE lbl WHEN 'A' THEN 'K967-A' ELSE 'K967-B' END);
  IF v_n = 0 THEN v_ok := v_ok || 'city filter'::text; ELSE v_fail := v_fail || format('city filter stray %s', v_n); END IF;

  -- anon denied
  BEGIN
    IF v_neg THEN EXECUTE 'SET LOCAL ROLE authenticated'; ELSE EXECUTE 'SET LOCAL ROLE anon'; END IF;
    PERFORM count(*) FROM public.active_stream(NULL, NULL, 1);
    EXECUTE 'RESET ROLE';
    v_fail := v_fail || 'anon executed active_stream'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    v_ok := v_ok || 'anon denied (42501)'::text;
  END;
  EXECUTE 'RESET ROLE';

  IF cardinality(v_fail) = 0 THEN
    RAISE EXCEPTION 'KAN-967 PASS (neg=%) % ok: %', v_neg, cardinality(v_ok), array_to_string(v_ok, ' | ');
  ELSE
    RAISE EXCEPTION 'KAN-967 FAIL (neg=%) % failures: % || ok: %', v_neg, cardinality(v_fail), array_to_string(v_fail, ' || '), array_to_string(v_ok, ' | ');
  END IF;
END
$t$;

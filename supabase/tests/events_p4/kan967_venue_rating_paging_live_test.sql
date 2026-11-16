-- KAN-967 follow-up live test: a venue with several ratings appears ONCE across keyset pages of 1 row
-- (migration 20261116161156_kan967_venue_rating_newest). One DO block, always ends in RAISE EXCEPTION, so every seed rolls back.
-- Seeds a test area (city 'K967-P') and venue with three ratings: visible rater A at now-3h, visible rater B at now-2h,
-- hidden rater C (hide_in_search) at now-1h. As `authenticated`, it pages active_stream(['venue_rating'], 'K967-P', 1)
-- with the keyset cursor until a page is empty.
-- Expected 'KAN-967P PASS': exactly 1 row for the venue, and it is B's rating (the newest VISIBLE one; C's newer
-- hidden rating must not mask it), event_at = B's created_at.
-- v_neg := true is the negative control: it expects the pre-fix behaviour (2 rows, A and B), so it must end FAIL.
-- Run against the pre-fix function, the v_neg := false run FAILs with 2 rows (the defect).
DO $t$
DECLARE
  v_neg  boolean := false;
  pf     uuid[];
  uf     uuid[];
  a_p    uuid := gen_random_uuid();
  ven    uuid := gen_random_uuid();
  g      uuid := gen_random_uuid();
  v_geo  uuid;
  v_sp   uuid;
  r      record;
  v_n    int;
  k      int;
  v_got  text;
  v_want text;
BEGIN
  SELECT array_agg(id ORDER BY created_at, id), array_agg(user_id ORDER BY created_at, id) INTO pf, uf
    FROM (SELECT DISTINCT ON (p.user_id) p.id, p.user_id, p.created_at
            FROM public.profiles p
           WHERE p.profile_type = 'personal' AND p.user_id IS NOT NULL AND p.is_active
             AND NOT EXISTS (SELECT 1 FROM public.profiles q WHERE q.user_id = p.user_id AND q.id <> p.id)
           ORDER BY p.user_id, p.created_at) x;
  pf := pf[1:4]; uf := uf[1:4];   -- [1] viewer, [2] rater A, [3] rater B, [4] hidden rater C
  IF cardinality(pf) < 4 THEN RAISE EXCEPTION 'KAN-967P FAIL: need 4 personal profiles'; END IF;
  SELECT geo_location_id INTO v_geo FROM public.venues WHERE geo_location_id IS NOT NULL LIMIT 1;
  SELECT id INTO v_sp FROM public.sports ORDER BY is_active DESC, name_en, id LIMIT 1;

  INSERT INTO public.user_status (user_id, is_benched, hide_in_search)
  SELECT u, false, (u = uf[4]) FROM unnest(uf) u
  ON CONFLICT (user_id) DO UPDATE SET is_benched = false, hide_in_search = excluded.hide_in_search;
  INSERT INTO public.areas (id, country, city, name, center_lat, center_lng, district)
  VALUES (a_p, 'AE', 'K967-P', 'K967 Area P', 25.2, 55.3, 'K967');
  INSERT INTO public.venues (id, name_en, geo_location_id, area_id, is_active) VALUES (ven, 'K967 VP', v_geo, a_p, true);
  INSERT INTO public.events (capacity, geo_location_id, id, event_type, creator_profile_id, creator_user_id, start_at, end_at, area_id, sport_id, venue_id, title)
  VALUES (10, v_geo, g, 'game', pf[2], uf[2], now() - interval '1 day', now() - interval '23 hours', a_p, v_sp, ven, 'K967 paging');
  INSERT INTO public.games (id, event_id) VALUES (g, g);
  INSERT INTO public.venue_rating_events (game_id, venue_id, rater_user_id, rater_profile_id, scores, comment, created_at)
  VALUES (g, ven, uf[2], pf[2], '{"facility":3}', 'K967 A', now() - interval '3 hours'),
         (g, ven, uf[3], pf[3], '{"facility":4}', 'K967 B', now() - interval '2 hours'),
         (g, ven, uf[4], pf[4], '{"facility":5}', 'K967 C hidden', now() - interval '1 hour');

  CREATE TEMP TABLE _k967p ON COMMIT DROP AS SELECT 0 AS pg_no, s.* FROM public.active_stream() s WHERE false;
  GRANT ALL ON _k967p TO authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uf[1], 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := NULL;
  FOR k IN 1 .. 20 LOOP
    IF r IS NULL THEN
      INSERT INTO _k967p SELECT k, s.* FROM public.active_stream(ARRAY['venue_rating'], 'K967-P', 1) s;
    ELSE
      INSERT INTO _k967p SELECT k, s.* FROM public.active_stream(ARRAY['venue_rating'], 'K967-P', 1, r.event_at, r.event_type, r.entity_id) s;
    END IF;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXIT WHEN v_n = 0;
    SELECT * INTO r FROM _k967p WHERE pg_no = k;
  END LOOP;
  EXECUTE 'RESET ROLE';

  SELECT string_agg(pg_no || ':' || quote, ',' ORDER BY pg_no) INTO v_got FROM _k967p WHERE entity_id = ven;
  v_want := CASE WHEN v_neg THEN '1:K967 B,2:K967 A' ELSE '1:K967 B' END;
  SELECT count(*) INTO v_n FROM _k967p p JOIN public.venue_rating_events e ON e.venue_id = ven AND e.comment = 'K967 B'
   WHERE p.entity_id = ven AND p.event_at = e.created_at;
  IF v_got IS NOT DISTINCT FROM v_want AND v_n = 1 THEN
    RAISE EXCEPTION 'KAN-967P PASS (neg=%): venue on pages % (newest visible rating, hidden newer one ignored, event_at = its created_at)', v_neg, v_got;
  ELSE
    RAISE EXCEPTION 'KAN-967P FAIL (neg=%): venue rows by page % want % (event_at match %)', v_neg, v_got, v_want, v_n;
  END IF;
END
$t$;

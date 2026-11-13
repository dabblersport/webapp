-- KAN-931 + KAN-933 (backend) live proof for supabase/migrations/20261113225433_kan931_broken_functions.sql and 20261113225507_kan933_unified_search_route_host_private.sql. Runs on wtncuzcskpigqpmnxwws as postgres (execute_sql), BEGIN ... ROLLBACK.
-- Every probe calls as role authenticated with JWT claims for user a3ba3271-3556-4b4e-b15d-bc0851f8a64b (host) or
-- 18e15813-52bc-4f03-9a30-25dc6441223d (other), each in its own subtransaction; errors are captured, not raised.
-- Fixtures (all undone by ROLLBACK): a mutual follow between the two users' profiles; two of the host's cancelled
-- private games (one plain, one series occurrence) un-cancelled and retitled 'Kan933zq hostprobe'.
-- RED before the migrations: are_synced/getnearbymeetups raise, the two dead functions exist, the host finds no
-- private game, the meetup route is '/meetup/'. GREEN after: every row ok.
BEGIN;
SET LOCAL client_min_messages = warning;
CREATE TEMP TABLE k931_tap (n int PRIMARY KEY, ok boolean, label text, detail text) ON COMMIT DROP;

-- Run v_sql as authenticated for v_uid; return the first column as text, or 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.k931_as(v_uid uuid, v_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    EXECUTE v_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    v := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  RETURN v;
END $f$;

DO $t$
DECLARE
  host uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  hostp uuid := '5eeb4305-9277-458e-a56f-a5ed77e3f208';
  oth uuid := '18e15813-52bc-4f03-9a30-25dc6441223d';
  othp uuid := 'b73c920d-5276-44ea-bda4-a52bceb79aed';
  v text; v2 text; mq text; mid uuid; pre text;
BEGIN
  -- T0 the search function differs from the pinned pre-image by exactly the two KAN-933 edits
  SELECT md5(replace(replace(prosrc,
      E'AND (e.listing_visibility = ''public''\n               OR (auth.uid() IS NOT NULL AND e.creator_user_id = auth.uid()))\n          AND e.is_cancelled = FALSE\n          AND g.is_cancelled = FALSE',
      E'AND e.listing_visibility = ''public'' AND e.is_cancelled = FALSE\n          AND g.listing_visibility = ''public'' AND g.is_cancelled = FALSE'),
      '''/meetups/'' || m.id', '''/meetup/'' || e.id'))
    INTO pre FROM pg_proc WHERE oid = 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure;
  INSERT INTO k931_tap VALUES (0, pre = '4fb01f55aca1997e1ecf5d3dfb77135b', 'search body = pre-image + the two edits', pre);

  -- T1/T2 dead functions are gone
  INSERT INTO k931_tap VALUES (1, to_regprocedure('public.rpc_search_entities(text,text[],text,integer)') IS NULL, 'rpc_search_entities dropped', NULL);
  INSERT INTO k931_tap VALUES (2, to_regprocedure('public.rpc_meetup_visible()') IS NULL, 'rpc_meetup_visible dropped', NULL);

  -- T3 getnearbymeetups as authenticated: no error, finds the Abu Dhabi upcoming meetup, shape parses
  v := pg_temp.k931_as(host, $q$SELECT count(*)::text || ' ' || bool_and(id IS NOT NULL AND title IS NOT NULL AND starts_at > now()
         AND lat IS NOT NULL AND lng IS NOT NULL AND distance_m <= 10000)::text
       FROM public.getnearbymeetups(24.4187276, 54.337424, 10000)$q$);
  INSERT INTO k931_tap VALUES (3, v NOT LIKE 'ERR%' AND split_part(v,' ',1)::int >= 1 AND split_part(v,' ',2) = 'true', 'getnearbymeetups runs as authenticated', v);

  -- T4..T6 are_synced: mutual follow true, one-way false, self false
  DELETE FROM public.profile_follows WHERE (follower_profile_id, following_profile_id) IN ((hostp, othp), (othp, hostp));
  INSERT INTO public.profile_follows (follower_profile_id, following_profile_id) VALUES (hostp, othp), (othp, hostp);
  v := pg_temp.k931_as(host, format('SELECT public.are_synced(%L, %L)::text', host, oth));
  INSERT INTO k931_tap VALUES (4, v = 'true', 'are_synced mutual follow = true', v);
  DELETE FROM public.profile_follows WHERE follower_profile_id = othp AND following_profile_id = hostp;
  v := pg_temp.k931_as(host, format('SELECT public.are_synced(%L, %L)::text', host, oth));
  INSERT INTO k931_tap VALUES (5, v = 'false', 'are_synced one-way follow = false', v);
  v := pg_temp.k931_as(host, format('SELECT public.are_synced(%L, %L)::text', host, host));
  INSERT INTO k931_tap VALUES (6, v = 'false', 'are_synced self = false', v);

  -- S1/S2 host sees own private games (plain + series occurrence); another user does not
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL, title = 'Kan933zq hostprobe'
   WHERE id IN ('96949cc9-270e-4e61-9af4-8a9b296fb75e', 'c5c3270d-0601-4910-9b4e-e733d6935578');
  v := pg_temp.k931_as(host, $q$SELECT jsonb_array_length(public.rpc_unified_search_sectioned('Kan933zq')->'games')::text$q$);
  INSERT INTO k931_tap VALUES (7, v = '2', 'host finds own private game + series occurrence', v);
  v := pg_temp.k931_as(oth, $q$SELECT jsonb_array_length(public.rpc_unified_search_sectioned('Kan933zq')->'games')::text$q$);
  INSERT INTO k931_tap VALUES (8, v = '0', 'other user does not', v);

  -- S3 meetup route is /meetups/<meetups.id>
  SELECT e.title, m.id INTO mq, mid FROM public.meetups m JOIN public.events e ON e.id = m.event_id
   WHERE e.listing_visibility = 'public' AND NOT e.is_cancelled AND e.search_tsv @@ plainto_tsquery('simple', unaccent(e.title))
   ORDER BY e.created_at LIMIT 1;
  v := pg_temp.k931_as(host, format($q$SELECT r->>'route' FROM jsonb_array_elements(public.rpc_unified_search_sectioned(%L)->'meetups') r
                                       WHERE r->>'entity_id' = %L$q$, mq, mid));
  INSERT INTO k931_tap VALUES (9, v = '/meetups/' || mid, 'meetup route /meetups/<id>', v);
END $t$;

SELECT string_agg(n || ' ' || CASE WHEN ok THEN 'ok' ELSE 'NOT OK' END || ' ' || label || coalesce(' [' || detail || ']', ''), E'\n' ORDER BY n)
       || E'\n' || CASE WHEN bool_and(ok) THEN 'ALL GREEN' ELSE 'RED: ' || count(*) FILTER (WHERE NOT ok) || ' failing' END AS result
FROM k931_tap;
ROLLBACK;

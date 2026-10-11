-- KAN-492 probe pack for 20261011170000_kan492_posts_set_geo_no_fixed_fallback.sql
--
-- !!! RUN ONLY INSIDE BEGIN/ROLLBACK ON A NON-PRODUCTION DATABASE (Supabase branch or a local
-- !!! scratch Postgres loaded with the migration history). NEVER ON LIVE DATA
-- !!! (wtncuzcskpigqpmnxwws). The file opens a transaction and ends with ROLLBACK itself.
--
-- Falsifiability: run it BEFORE the migration -> probes (c), (d) and (f) must FAIL (baseline
-- PATH 4/5 stamps the fixed area and overwrites geo; on a baseline schema (c) fails on NOT NULL
-- or on the fallback area). Then apply the migration and run again -> every probe PASSES.
-- Each probe RAISEs on failure, so the first failure aborts with its name.
--
-- Fixtures are fabricated rows with fixed ids prefixed 492; columns follow the baseline schema.
-- Syntax and fixture completeness are UNVERIFIED (no Postgres available to the author); if a
-- fixture INSERT fails on a live-only constraint, fill the missing column, do not drop the probe.
\set ON_ERROR_STOP on
BEGIN;

-- Fixtures ---------------------------------------------------------------------------------
INSERT INTO auth.users(id, email) VALUES
  ('49200000-0000-0000-0000-0000000000a1','author-nocoords@kan492.test'),
  ('49200000-0000-0000-0000-0000000000a2','author-coords@kan492.test');

-- Three areas far apart, each with one geo_location (the trigger's nearest-area lookup uses
-- geo_locations per area). FB is a decoy "first active area": is_active, is_verified, and its
-- id sorts FIRST — it is exactly what baseline PATH 5 would pick.
INSERT INTO public.areas(id, country, city, name, center_lat, center_lng, district, is_active, is_verified) VALUES
  ('00000000-0000-0000-0000-000000000492','AE','Dubai','KAN492 Fallback Decoy', 25.10, 55.30, 'FB', true, true),
  ('49200000-0000-0000-0000-00000000000a','AE','Abu Dhabi','KAN492 Area A', 24.45, 54.38, 'A', true, false),
  ('49200000-0000-0000-0000-00000000000b','AE','Sharjah','KAN492 Area B', 25.35, 55.40, 'B', true, false),
  ('49200000-0000-0000-0000-00000000000c','AE','Ras Al Khaimah','KAN492 Area C', 25.79, 55.94, 'C', true, false);
INSERT INTO public.geo_locations(id, location, geohash, area_id) VALUES
  ('49200000-0000-0000-0000-0000000001fb', ST_SetSRID(ST_MakePoint(55.30,25.10),4326)::geography,'k492fb','00000000-0000-0000-0000-000000000492'),
  ('49200000-0000-0000-0000-00000000010a', ST_SetSRID(ST_MakePoint(54.38,24.45),4326)::geography,'k492a','49200000-0000-0000-0000-00000000000a'),
  ('49200000-0000-0000-0000-00000000010b', ST_SetSRID(ST_MakePoint(55.40,25.35),4326)::geography,'k492b','49200000-0000-0000-0000-00000000000b'),
  ('49200000-0000-0000-0000-00000000010c', ST_SetSRID(ST_MakePoint(55.94,25.79),4326)::geography,'k492c','49200000-0000-0000-0000-00000000000c');
INSERT INTO public.venues(id, name_en, geo_location_id, area_id) VALUES
  ('49200000-0000-0000-0000-0000000002aa','KAN492 Venue in A','49200000-0000-0000-0000-00000000010a','49200000-0000-0000-0000-00000000000a');
INSERT INTO public.profiles(id, user_id, profile_type, username, display_name, age, persona_type, latitude, longitude) VALUES
  ('49200000-0000-0000-0000-0000000003a1','49200000-0000-0000-0000-0000000000a1','personal','kan492_nocoords','KAN492 NoCoords',30,'socialiser',NULL,NULL),
  ('49200000-0000-0000-0000-0000000003a2','49200000-0000-0000-0000-0000000000a2','personal','kan492_coords','KAN492 Coords',30,'socialiser',25.80,55.95);  -- next to C

DO $$
DECLARE
  r record;
  A  constant uuid := '49200000-0000-0000-0000-00000000000a';
  B  constant uuid := '49200000-0000-0000-0000-00000000000b';
  C  constant uuid := '49200000-0000-0000-0000-00000000000c';
  FB constant uuid := '00000000-0000-0000-0000-000000000492';
  P_NO  constant uuid := '49200000-0000-0000-0000-0000000003a1';
  P_YES constant uuid := '49200000-0000-0000-0000-0000000003a2';
  v_id uuid;
BEGIN
  -- Precondition: the decoy really is the baseline PATH 5 pick on this database, so (f) can fail.
  SELECT a.id INTO v_id FROM areas a WHERE a.is_active ORDER BY a.is_verified DESC, a.id LIMIT 1;
  IF v_id <> FB THEN
    RAISE NOTICE 'NOTE: first-active-area on this DB is %, not the decoy; (f) also checks that id.', v_id;
  END IF;

  -- (a) venue in area A -> area A, place name kept
  INSERT INTO posts(author_profile_id, author_display_name, kind, visibility, venue_id, location_name)
  VALUES (P_NO,'KAN492 NoCoords','moment','public','49200000-0000-0000-0000-0000000002aa','KAN492 Venue in A')
  RETURNING * INTO r;
  IF r.area_id IS DISTINCT FROM A OR r.location_name IS DISTINCT FROM 'KAN492 Venue in A' THEN
    RAISE EXCEPTION 'FAIL (a): area=% name=%', r.area_id, r.location_name; END IF;
  RAISE NOTICE 'PASS (a) venue -> area A, name kept';

  -- (b) explicit area B, no venue/game/coords -> B kept
  INSERT INTO posts(author_profile_id, author_display_name, kind, visibility, area_id)
  VALUES (P_YES,'KAN492 Coords','moment','public',B) RETURNING * INTO r;
  IF r.area_id IS DISTINCT FROM B THEN RAISE EXCEPTION 'FAIL (b): area=%', r.area_id; END IF;
  RAISE NOTICE 'PASS (b) explicit area_id B kept';

  -- (c) no place, profile without coordinates -> NULL
  INSERT INTO posts(author_profile_id, author_display_name, kind, visibility)
  VALUES (P_NO,'KAN492 NoCoords','moment','public') RETURNING * INTO r;
  IF r.area_id IS NOT NULL OR r.geo_lat IS NOT NULL OR r.geo_lng IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL (c): area=% lat=% lng=%', r.area_id, r.geo_lat, r.geo_lng; END IF;
  RAISE NOTICE 'PASS (c) no place + no profile coords -> area NULL, geo NULL';

  -- (d) no place, profile with coordinates near C -> C, geo NOT overwritten (stays NULL)
  INSERT INTO posts(author_profile_id, author_display_name, kind, visibility)
  VALUES (P_YES,'KAN492 Coords','moment','public') RETURNING * INTO r;
  IF r.area_id IS DISTINCT FROM C OR r.geo_lat IS NOT NULL OR r.geo_lng IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL (d): area=% lat=% lng=%', r.area_id, r.geo_lat, r.geo_lng; END IF;
  RAISE NOTICE 'PASS (d) author real area C, post geo not overwritten';

  -- (e) update of body does not change area_id (use the (b) post: area B, while its author's
  --     profile is near C — a re-stamp would move it to C)
  UPDATE posts SET body = 'edited' WHERE author_profile_id = P_YES AND area_id = B RETURNING * INTO r;
  IF r.area_id IS DISTINCT FROM B THEN RAISE EXCEPTION 'FAIL (e): area after body edit=%', r.area_id; END IF;
  RAISE NOTICE 'PASS (e) body edit kept area B';

  -- (f) no fixture post carries the first-active-area fallback
  SELECT a.id INTO v_id FROM areas a WHERE a.is_active ORDER BY a.is_verified DESC, a.id LIMIT 1;
  IF EXISTS (SELECT 1 FROM posts WHERE author_profile_id IN (P_NO,P_YES) AND area_id IN (FB, v_id)) THEN
    RAISE EXCEPTION 'FAIL (f): a probe post got the first-active-area fallback'; END IF;
  RAISE NOTICE 'PASS (f) no fixed-area fallback stamped';
END $$;

ROLLBACK;

-- KAN-621 probes for public.rpc_sport_overview. AUTHORED, NOT EXECUTED (no Postgres on the authoring machine).
-- Run on a scratch/branch database as a role that can SET LOCAL ROLE (postgres). Everything is seeded inside ONE
-- transaction that ends in ROLLBACK, so no row remains. Never run on production data.
-- Each probe writes pass|FAIL|SKIPPED to _p621; SKIPPED means a fixture was missing (e.g. a trigger on auth.users or
-- profiles rejected the seed) and is NOT a pass.
BEGIN;
CREATE TEMP TABLE _p621(probe text, result text, detail text) ON COMMIT DROP;
GRANT ALL ON _p621 TO authenticated;

DO $seed$
DECLARE
  v_sport uuid; v_sport2 uuid; c1 text; c2 text; a1 uuid; a2 uuid; g1 uuid; g2 uuid;
  uA uuid := gen_random_uuid(); uB uuid := gen_random_uuid(); uC uuid := gen_random_uuid(); uD uuid := gen_random_uuid(); uE uuid := gen_random_uuid();
  pA uuid := gen_random_uuid(); pB uuid := gen_random_uuid(); pC uuid := gen_random_uuid(); pD uuid := gen_random_uuid(); pE uuid := gen_random_uuid();
BEGIN
  SELECT id INTO v_sport  FROM public.sports ORDER BY id LIMIT 1;
  SELECT id INTO v_sport2 FROM public.sports WHERE id <> v_sport ORDER BY id LIMIT 1;
  SELECT code INTO c1 FROM public.ref_cities ORDER BY code LIMIT 1;
  SELECT code INTO c2 FROM public.ref_cities WHERE code <> c1 ORDER BY code LIMIT 1;
  IF v_sport IS NULL OR c1 IS NULL OR c2 IS NULL THEN
    INSERT INTO _p621 VALUES ('SEED','SKIPPED','need >=2 sports and >=2 ref_cities'); RETURN;
  END IF;
  -- two areas in two different cities, each with a geo point
  INSERT INTO public.areas(country,city,name,district,center_lat,center_lng,city_code) VALUES ('UAE','c1','kan621-a1','d1',25.0,55.0,c1) RETURNING id INTO a1;
  INSERT INTO public.areas(country,city,name,district,center_lat,center_lng,city_code) VALUES ('UAE','c2','kan621-a2','d2',24.4,54.4,c2) RETURNING id INTO a2;
  INSERT INTO public.geo_locations(location,geohash,area_id) VALUES (ST_SetSRID(ST_MakePoint(55.0,25.0),4326)::geography,'kan621a',a1) RETURNING id INTO g1;
  INSERT INTO public.geo_locations(location,geohash,area_id) VALUES (ST_SetSRID(ST_MakePoint(54.4,24.4),4326)::geography,'kan621b',a2) RETURNING id INTO g2;
  -- five users/profiles: A = caller, B = follows sport and is followed by A, C = follows sport only,
  -- D = follows sport and is blocked by A, E = does NOT have the sport.
  INSERT INTO auth.users(id,aud,role,email) SELECT u,'authenticated','authenticated',u||'@kan621.test' FROM unnest(ARRAY[uA,uB,uC,uD,uE]) u;
  INSERT INTO public.profiles(id,user_id,profile_type,username,display_name,age,persona_type,primary_sport,interests) VALUES
    (pA,uA,'personal','kan621a','Probe A',30,'player',v_sport,NULL),
    (pB,uB,'personal','kan621b','Probe B',30,'player',v_sport,ARRAY[v_sport,v_sport]),  -- sport listed twice: must count once
    (pC,uC,'personal','kan621c','Probe C',30,'player',v_sport,ARRAY[v_sport]),
    (pD,uD,'personal','kan621d','Probe D',30,'player',v_sport,ARRAY[v_sport]),
    (pE,uE,'personal','kan621e','Probe E',30,'player',v_sport,ARRAY[v_sport2]);
  INSERT INTO public.profile_follows(follower_profile_id,following_profile_id) VALUES (pA,pB),(pA,pD),(pA,pE);
  INSERT INTO public.user_blocks(blocker_user_id,blocked_user_id) VALUES (uA,uD);
  -- news: 1 in city 1, 1 in city 2, 1 with no area
  INSERT INTO public.news(sport_id,area_id,status,published_at) VALUES (v_sport,a1,'published',now()-interval '1 hour'),(v_sport,a2,'published',now()-interval '1 hour'),(v_sport,NULL,'published',now()-interval '1 hour');
  PERFORM set_config('kan621.sport',v_sport::text,true); PERFORM set_config('kan621.c1',c1,true); PERFORM set_config('kan621.c2',c2,true);
  PERFORM set_config('kan621.uA',uA::text,true); PERFORM set_config('kan621.uB',uB::text,true);
  PERFORM set_config('kan621.uC',uC::text,true); PERFORM set_config('kan621.uD',uD::text,true);
  PERFORM set_config('kan621.uB',uB::text,true); PERFORM set_config('kan621.pB',pB::text,true); PERFORM set_config('kan621.pD',pD::text,true);
  PERFORM set_config('kan621.a1',a1::text,true); PERFORM set_config('kan621.a2',a2::text,true);
  PERFORM set_config('kan621.g1',g1::text,true); PERFORM set_config('kan621.g2',g2::text,true);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO _p621 VALUES ('SEED','SKIPPED',SQLERRM);
END $seed$;

-- Counts are asserted as DELTAS (after seeding minus before seeding) so rows already in the database do not matter.
-- _b621 = before, _a621 = after; scope c1 / c2 = city, all = no city.
CREATE TEMP TABLE _b621(scope text, games_next7 bigint, meetups_next7 bigint, posts bigint, venues bigint, spaces bigint) ON COMMIT DROP;
CREATE TEMP TABLE _a621(scope text, games_next7 bigint, meetups_next7 bigint, posts bigint, venues bigint, spaces bigint) ON COMMIT DROP;
GRANT ALL ON _b621 TO authenticated;
GRANT ALL ON _a621 TO authenticated;

SELECT set_config('request.jwt.claim.sub', current_setting('kan621.uA', true), true);
SET LOCAL ROLE authenticated;
INSERT INTO _b621 SELECT 'c1', games_next7, meetups_next7, posts, venues, spaces FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, current_setting('kan621.c1')) WHERE current_setting('kan621.sport', true) IS NOT NULL;
INSERT INTO _b621 SELECT 'c2', games_next7, meetups_next7, posts, venues, spaces FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, current_setting('kan621.c2')) WHERE current_setting('kan621.sport', true) IS NOT NULL;
INSERT INTO _b621 SELECT 'all', games_next7, meetups_next7, posts, venues, spaces FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, NULL) WHERE current_setting('kan621.sport', true) IS NOT NULL;
RESET ROLE;

-- Venues and spaces are seeded AFTER the before-snapshot so P3 can assert deltas: ven1 in city 1 with 3 active
-- spaces of the sport, ven2 in city 2 with 1 space. Expected deltas: city 1 = +1 venue / +3 spaces, city 2 = +1 / +1.
DO $venues$
DECLARE s uuid := current_setting('kan621.sport')::uuid; a1 uuid := current_setting('kan621.a1')::uuid; a2 uuid := current_setting('kan621.a2')::uuid;
  g1 uuid := current_setting('kan621.g1')::uuid; g2 uuid := current_setting('kan621.g2')::uuid;
  ven1 uuid := gen_random_uuid(); ven2 uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.venues(id,name_en,geo_location_id,area_id) VALUES (ven1,'kan621 v1',g1,a1),(ven2,'kan621 v2',g2,a2);
  INSERT INTO public.venue_spaces(venue_id,sport_id) VALUES (ven1,s),(ven1,s),(ven1,s),(ven2,s);
  PERFORM set_config('kan621.venues_ok','1',true);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO _p621 VALUES ('SEED_venues','SKIPPED',SQLERRM);
END $venues$;

-- Seeds for games, meetups and posts. Each block is independent: a trigger or constraint that rejects the seed
-- leaves a SKIPPED row for that table (flag kan621.<t>_ok stays unset) and the other tables are still probed.
-- Matrix per table (sport = the probe sport): 2 qualifying rows in city 1 (+1 day, +3 days), 1 qualifying in city 2
-- (+2 days), and negatives in city 1: cancelled / more than 7 days out / already started / not public / creator
-- blocked by the caller. Posts have no start time; their negatives are followers-only, deleted, hidden by admin,
-- expired and blocked author.
DO $games$
DECLARE s uuid := current_setting('kan621.sport')::uuid; a1 uuid := current_setting('kan621.a1')::uuid; a2 uuid := current_setting('kan621.a2')::uuid;
  g1 uuid := current_setting('kan621.g1')::uuid; g2 uuid := current_setting('kan621.g2')::uuid;
  pB uuid := current_setting('kan621.pB')::uuid; uB uuid := current_setting('kan621.uB')::uuid;
  pD uuid := current_setting('kan621.pD')::uuid; uD uuid := current_setting('kan621.uD')::uuid;
BEGIN
  INSERT INTO public.games(creator_profile_id,creator_user_id,start_at,end_at,capacity,sport_id,geo_location_id,area_id,listing_visibility,is_cancelled) VALUES
    (pB,uB, now()+interval '1 day',  now()+interval '1 day 1 hour',  10,s,g1,a1,'public',  false),
    (pB,uB, now()+interval '3 days', now()+interval '3 days 1 hour', 10,s,g1,a1,'public',  false),
    (pB,uB, now()+interval '2 days', now()+interval '2 days 1 hour', 10,s,g2,a2,'public',  false),
    (pB,uB, now()+interval '1 day',  now()+interval '1 day 1 hour',  10,s,g1,a1,'public',  true),   -- cancelled
    (pB,uB, now()+interval '10 days',now()+interval '10 days 1 hour',10,s,g1,a1,'public',  false),  -- outside 7 days
    (pB,uB, now()-interval '1 day',  now()-interval '23 hours',      10,s,g1,a1,'public',  false),  -- already started
    (pB,uB, now()+interval '1 day',  now()+interval '1 day 1 hour',  10,s,g1,a1,'private', false),  -- not public
    (pD,uD, now()+interval '1 day',  now()+interval '1 day 1 hour',  10,s,g1,a1,'public',  false);  -- creator blocked by A
  PERFORM set_config('kan621.games_ok','1',true);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO _p621 VALUES ('SEED_games','SKIPPED',SQLERRM);
END $games$;

DO $meetups$
DECLARE s uuid := current_setting('kan621.sport')::uuid; a1 uuid := current_setting('kan621.a1')::uuid; a2 uuid := current_setting('kan621.a2')::uuid;
  g1 uuid := current_setting('kan621.g1')::uuid; g2 uuid := current_setting('kan621.g2')::uuid;
  pB uuid := current_setting('kan621.pB')::uuid; uB uuid := current_setting('kan621.uB')::uuid;
  pD uuid := current_setting('kan621.pD')::uuid; uD uuid := current_setting('kan621.uD')::uuid;
BEGIN
  INSERT INTO public.meetups(creator_profile_id,creator_user_id,host_actor_id,title,start_at,sport_id,geo_location_id,area_id,listing_visibility,is_cancelled) VALUES
    (pB,uB,pB,'kan621 m ok1', now()+interval '1 day',  s,g1,a1,'public', false),
    (pB,uB,pB,'kan621 m ok2', now()+interval '3 days', s,g1,a1,'public', false),
    (pB,uB,pB,'kan621 m ok3', now()+interval '2 days', s,g2,a2,'public', false),
    (pB,uB,pB,'kan621 m canc',now()+interval '1 day',  s,g1,a1,'public', true),    -- cancelled
    (pB,uB,pB,'kan621 m far', now()+interval '10 days',s,g1,a1,'public', false),   -- outside 7 days
    (pB,uB,pB,'kan621 m past',now()-interval '1 day',  s,g1,a1,'public', false),   -- already started
    (pB,uB,pB,'kan621 m hid', now()+interval '1 day',  s,g1,a1,'hidden', false),   -- not public
    (pD,uD,pD,'kan621 m blk', now()+interval '1 day',  s,g1,a1,'public', false);   -- creator blocked by A
  PERFORM set_config('kan621.meetups_ok','1',true);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO _p621 VALUES ('SEED_meetups','SKIPPED',SQLERRM);
END $meetups$;

-- posts: some author triggers read auth.uid(), so the seed runs as the author (user B).
SELECT set_config('request.jwt.claim.sub', current_setting('kan621.uB', true), true);
DO $posts$
DECLARE s uuid := current_setting('kan621.sport')::uuid; a1 uuid := current_setting('kan621.a1')::uuid; a2 uuid := current_setting('kan621.a2')::uuid;
  g1 uuid := current_setting('kan621.g1')::uuid; g2 uuid := current_setting('kan621.g2')::uuid;
  pB uuid := current_setting('kan621.pB')::uuid; uB uuid := current_setting('kan621.uB')::uuid;
  pD uuid := current_setting('kan621.pD')::uuid; uD uuid := current_setting('kan621.uD')::uuid;
BEGIN
  INSERT INTO public.posts(author_profile_id,author_user_id,kind,visibility,body,geo_lat,geo_lng,geo_location_id,area_id,author_display_name,
                           sport_id,origin_type,post_type,is_deleted,is_hidden_admin,expires_at) VALUES
    (pB,uB,'original','public',   'kan621 p ok1',25.0,55.0,g1,a1,'Probe B',s,'manual','dab',false,false,NULL),
    (pB,uB,'original','public',   'kan621 p ok2',25.0,55.0,g1,a1,'Probe B',s,'manual','dab',false,false,now()+interval '1 day'),
    (pB,uB,'original','public',   'kan621 p ok3',24.4,54.4,g2,a2,'Probe B',s,'manual','dab',false,false,NULL),          -- other city: still counts
    (pB,uB,'original','followers','kan621 p fol',25.0,55.0,g1,a1,'Probe B',s,'manual','dab',false,false,NULL),          -- not public
    (pB,uB,'original','public',   'kan621 p del',25.0,55.0,g1,a1,'Probe B',s,'manual','dab',true, false,NULL),          -- deleted
    (pB,uB,'original','public',   'kan621 p hid',25.0,55.0,g1,a1,'Probe B',s,'manual','dab',false,true, NULL),          -- hidden by admin
    (pB,uB,'original','public',   'kan621 p exp',25.0,55.0,g1,a1,'Probe B',s,'manual','dab',false,false,now()-interval '1 hour'), -- expired
    (pD,uD,'original','public',   'kan621 p blk',25.0,55.0,g1,a1,'Probe D',s,'manual','dab',false,false,NULL);          -- author blocked by A
  PERFORM set_config('kan621.posts_ok','1',true);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO _p621 VALUES ('SEED_posts','SKIPPED',SQLERRM);
END $posts$;

-- after snapshot, as caller A
SELECT set_config('request.jwt.claim.sub', current_setting('kan621.uA', true), true);
SET LOCAL ROLE authenticated;
INSERT INTO _a621 SELECT 'c1', games_next7, meetups_next7, posts, venues, spaces FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, current_setting('kan621.c1')) WHERE current_setting('kan621.sport', true) IS NOT NULL;
INSERT INTO _a621 SELECT 'c2', games_next7, meetups_next7, posts, venues, spaces FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, current_setting('kan621.c2')) WHERE current_setting('kan621.sport', true) IS NOT NULL;
INSERT INTO _a621 SELECT 'all', games_next7, meetups_next7, posts, venues, spaces FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, NULL) WHERE current_setting('kan621.sport', true) IS NOT NULL;
RESET ROLE;

-- act as the authenticated caller A (the role stays authenticated until the anon probe)
SELECT set_config('request.jwt.claim.sub', current_setting('kan621.uA', true), true);
SET LOCAL ROLE authenticated;

-- P2 (criterion 2): followers counts a profile with the sport once, excludes one without it and the blocked one.
-- Seeded followers of the sport: B (listed twice), C, D (blocked by A). A and E are not followers. Expect B + C = 2
-- from the seeded rows; the all-database figure is compared with a direct count.
INSERT INTO _p621
SELECT 'P2_followers_distinct_and_blocked',
  CASE WHEN o.followers = (SELECT count(*) FROM public.profiles p WHERE p.interests @> ARRAY[current_setting('kan621.sport')::uuid]
                             AND NOT public.is_blocked(current_setting('kan621.uA')::uuid, p.user_id)) THEN 'pass' ELSE 'FAIL' END,
  'followers='||o.followers
FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, NULL) o
WHERE current_setting('kan621.sport', true) IS NOT NULL;

-- P3 (criterion 3): the seeded venue with 3 spaces adds 1 venue and 3 spaces in city 1, and the other adds 1 + 1 in
-- city 2 (deltas against the before-snapshot, so existing rows do not matter). A venue is never summed with its spaces.
INSERT INTO _p621
SELECT 'P3_venue_vs_spaces',
  CASE WHEN current_setting('kan621.venues_ok', true) IS DISTINCT FROM '1' THEN 'SKIPPED'
       WHEN max(a.venues-b.venues) FILTER (WHERE a.scope='c1')=1 AND max(a.spaces-b.spaces) FILTER (WHERE a.scope='c1')=3
        AND max(a.venues-b.venues) FILTER (WHERE a.scope='c2')=1 AND max(a.spaces-b.spaces) FILTER (WHERE a.scope='c2')=1
        AND max(a.venues-b.venues) FILTER (WHERE a.scope='all')=2 AND max(a.spaces-b.spaces) FILTER (WHERE a.scope='all')=4
       THEN 'pass' ELSE 'FAIL' END,
  coalesce(string_agg(a.scope||' venues/spaces=+'||(a.venues-b.venues)||'/+'||(a.spaces-b.spaces), ' ' ORDER BY a.scope),'no rows')
FROM _a621 a JOIN _b621 b USING (scope);

-- P4 (criterion 4): a city count never exceeds the all-cities count, and the sum over cities does not exceed it.
-- posts is excluded from the sum: it is not city-scoped by design.
INSERT INTO _p621
SELECT 'P4_city_scope_le_total',
  CASE WHEN c1.venues <= t.venues AND c1.spaces <= t.spaces AND c1.news <= t.news AND c1.games_next7 <= t.games_next7 AND c1.meetups_next7 <= t.meetups_next7
        AND (SELECT coalesce(sum(r.venues),0) FROM public.ref_cities rc, LATERAL public.rpc_sport_overview(current_setting('kan621.sport')::uuid, rc.code) r) <= t.venues
        AND (SELECT coalesce(sum(r.spaces),0) FROM public.ref_cities rc, LATERAL public.rpc_sport_overview(current_setting('kan621.sport')::uuid, rc.code) r) <= t.spaces
        AND (SELECT coalesce(sum(r.news),0)   FROM public.ref_cities rc, LATERAL public.rpc_sport_overview(current_setting('kan621.sport')::uuid, rc.code) r) <= t.news
       THEN 'pass' ELSE 'FAIL' END,
  'total venues/spaces/news='||t.venues||'/'||t.spaces||'/'||t.news
FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, NULL) t,
     public.rpc_sport_overview(current_setting('kan621.sport')::uuid, current_setting('kan621.c1')) c1
WHERE current_setting('kan621.sport', true) IS NOT NULL;

-- P5a (criterion 5): mutual followers = people A follows who follow the sport (B only: C is not followed, D is blocked,
-- E lacks the sport); at most 3; only display_name, avatar_url, username keys.
INSERT INTO _p621
SELECT 'P5a_mutual_only_followed_not_blocked',
  CASE WHEN jsonb_array_length(o.mutual_followers) = 1 AND o.mutual_followers->0->>'username' = 'kan621b'
        AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(o.mutual_followers->0) k) = ARRAY['avatar_url','display_name','username']
       THEN 'pass' ELSE 'FAIL' END,
  o.mutual_followers::text
FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, NULL) o
WHERE current_setting('kan621.sport', true) IS NOT NULL;

-- P5b: unknown sport id returns zeros and an empty array, no error.
INSERT INTO _p621
SELECT 'P5b_unknown_sport_zeros',
  CASE WHEN o.followers=0 AND o.games_next7=0 AND o.meetups_next7=0 AND o.venues=0 AND o.spaces=0 AND o.posts=0 AND o.news=0
        AND o.mutual_followers = '[]'::jsonb THEN 'pass' ELSE 'FAIL' END,
  o.mutual_followers::text
FROM public.rpc_sport_overview(gen_random_uuid(), NULL) o;

-- P6 (games): window, cancelled, visibility, blocked creator and city scope. Seeded: 2 in city 1, 1 in city 2.
-- Expected deltas: city 1 = 2, city 2 = 1, all cities = 3.
INSERT INTO _p621
SELECT 'P6_games_next7',
  CASE WHEN current_setting('kan621.games_ok', true) IS DISTINCT FROM '1' THEN 'SKIPPED'
       WHEN max(a.games_next7-b.games_next7) FILTER (WHERE a.scope='c1')=2
        AND max(a.games_next7-b.games_next7) FILTER (WHERE a.scope='c2')=1
        AND max(a.games_next7-b.games_next7) FILTER (WHERE a.scope='all')=3 THEN 'pass' ELSE 'FAIL' END,
  coalesce(string_agg(a.scope||'='||(a.games_next7-b.games_next7), ' ' ORDER BY a.scope),'no rows')
FROM _a621 a JOIN _b621 b USING (scope);

-- P7 (meetups): same matrix as P6. Expected deltas: city 1 = 2, city 2 = 1, all = 3.
INSERT INTO _p621
SELECT 'P7_meetups_next7',
  CASE WHEN current_setting('kan621.meetups_ok', true) IS DISTINCT FROM '1' THEN 'SKIPPED'
       WHEN max(a.meetups_next7-b.meetups_next7) FILTER (WHERE a.scope='c1')=2
        AND max(a.meetups_next7-b.meetups_next7) FILTER (WHERE a.scope='c2')=1
        AND max(a.meetups_next7-b.meetups_next7) FILTER (WHERE a.scope='all')=3 THEN 'pass' ELSE 'FAIL' END,
  coalesce(string_agg(a.scope||'='||(a.meetups_next7-b.meetups_next7), ' ' ORDER BY a.scope),'no rows')
FROM _a621 a JOIN _b621 b USING (scope);

-- P8 (posts): public, live, not expired, author not blocked; NOT city-scoped, so the delta is the same (3) for
-- city 1, city 2 and all cities (two seeded rows in city 1 and one in city 2 all count).
INSERT INTO _p621
SELECT 'P8_posts_not_city_scoped',
  CASE WHEN current_setting('kan621.posts_ok', true) IS DISTINCT FROM '1' THEN 'SKIPPED'
       WHEN max(a.posts-b.posts) FILTER (WHERE a.scope='c1')=3
        AND max(a.posts-b.posts) FILTER (WHERE a.scope='c2')=3
        AND max(a.posts-b.posts) FILTER (WHERE a.scope='all')=3 THEN 'pass' ELSE 'FAIL' END,
  coalesce(string_agg(a.scope||'='||(a.posts-b.posts), ' ' ORDER BY a.scope),'no rows')
FROM _a621 a JOIN _b621 b USING (scope);

-- P5c: anon is refused. The role is switched back BEFORE anything is written to _p621: anon has no privilege on
-- the temp table, so the result is carried out of the anon block in a transaction-local setting.
RESET ROLE;
SET LOCAL ROLE anon;
DO $anon$ BEGIN
  PERFORM * FROM public.rpc_sport_overview(gen_random_uuid(), NULL);
  PERFORM set_config('kan621.anon','called',true);
EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('kan621.anon','42501',true);
END $anon$;
RESET ROLE;
INSERT INTO _p621 VALUES ('P5c_anon_denied',
  CASE WHEN current_setting('kan621.anon', true) = '42501' THEN 'pass' ELSE 'FAIL' END,
  coalesce(current_setting('kan621.anon', true), 'no result'));

SELECT * FROM _p621 ORDER BY probe;
ROLLBACK;

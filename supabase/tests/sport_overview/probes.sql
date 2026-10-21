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
  ven1 uuid := gen_random_uuid(); ven2 uuid := gen_random_uuid();
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
  -- venues: ven1 in city 1 with 3 active spaces of the sport; ven2 in city 2 with 1 space
  INSERT INTO public.venues(id,name_en,geo_location_id,area_id) VALUES (ven1,'kan621 v1',g1,a1),(ven2,'kan621 v2',g2,a2);
  INSERT INTO public.venue_spaces(venue_id,sport_id) VALUES (ven1,v_sport),(ven1,v_sport),(ven1,v_sport),(ven2,v_sport);
  -- news: 1 in city 1, 1 in city 2, 1 with no area
  INSERT INTO public.news(sport_id,area_id,status,published_at) VALUES (v_sport,a1,'published',now()-interval '1 hour'),(v_sport,a2,'published',now()-interval '1 hour'),(v_sport,NULL,'published',now()-interval '1 hour');
  PERFORM set_config('kan621.sport',v_sport::text,true); PERFORM set_config('kan621.c1',c1,true); PERFORM set_config('kan621.c2',c2,true);
  PERFORM set_config('kan621.uA',uA::text,true); PERFORM set_config('kan621.uB',uB::text,true);
  PERFORM set_config('kan621.uC',uC::text,true); PERFORM set_config('kan621.uD',uD::text,true);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO _p621 VALUES ('SEED','SKIPPED',SQLERRM);
END $seed$;

-- act as the authenticated caller A
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

-- P3 (criterion 3): the venue with 3 spaces counts 1 venue and 3 spaces in its city, and 1 + 1 in the other.
INSERT INTO _p621
SELECT 'P3_venue_vs_spaces',
  CASE WHEN c1.spaces >= 3 AND c1.venues >= 1 AND c2.venues >= 1 AND c2.spaces >= 1 AND c1.venues < c1.spaces THEN 'pass' ELSE 'FAIL' END,
  'c1 venues/spaces='||c1.venues||'/'||c1.spaces||' c2='||c2.venues||'/'||c2.spaces
FROM public.rpc_sport_overview(current_setting('kan621.sport')::uuid, current_setting('kan621.c1')) c1,
     public.rpc_sport_overview(current_setting('kan621.sport')::uuid, current_setting('kan621.c2')) c2
WHERE current_setting('kan621.sport', true) IS NOT NULL;

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

-- P5c: anon is refused.
RESET ROLE;
SET LOCAL ROLE anon;
DO $anon$ BEGIN
  PERFORM * FROM public.rpc_sport_overview(gen_random_uuid(), NULL);
  INSERT INTO _p621 VALUES ('P5c_anon_denied','FAIL','anon call succeeded');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO _p621 VALUES ('P5c_anon_denied','pass','42501');
END $anon$;
RESET ROLE;

SELECT * FROM _p621 ORDER BY probe;
ROLLBACK;

-- KAN-906 (KAN-714 chain stage R, KAN-866 follow-up): proof for
-- supabase/migrations/20261111120800_kan714_r_rpc_get_nearby_games_kan712_inner.sql.
-- public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text) (the 5-arg overload) must read
-- none of the 22 games columns KAN-866 removes, and must return exactly what the B04 body returned.
--
-- READ-ONLY. pgTAP. One transaction, ROLLBACK at the end: the seed rows, the function replacement and the temp
-- tables all roll back. pgTAP under plain psql exits 0 even on "not ok": read the TAP lines, or use pg_prove.
--
-- HARNESS. Local throwaway Postgres only (never Supabase). The database must already hold the tables the body reads
-- and the 5-arg overload exactly as B04 defines it (20261104100400_kan714_b04_rpc_nearby_following.sql:236-324,
-- md5(prosrc) 63e5a660f80100f02e2674db40b58a3a). It was run on a stub schema (games with all 22 KAN-866 columns,
-- events, geo_locations, sports, sport_variants, venue_spaces, venues, game_roster, profile_verifications,
-- organiser, favorites, blocks/follows/squad_members behind is_blocked / can_view_with_scope, auth.uid() from
-- request.jwt.claims, PostGIS st_* stubbed) because the seed below inserts plain rows; on the full chain the
-- KAN-712 triggers and FKs would need a different seed.
--
-- Run:
--   psql -X -v ON_ERROR_STOP=1 -d <throwaway db> -f supabase/tests/events_p4/kan714_r_rpc_get_nearby_games_kan712_inner_test.sql
-- RED control (migration not applied): add -v mig=/dev/null. S5 and S6 must fail; S1-S4b and S7-S9 stay ok.
--
-- What it checks. The seed covers each branch of the visibility predicate: a public game, a private game, a
-- squad-scoped game, a followers game, a blocked creator's public game, the caller's own private game, plus a
-- cancelled and an out-of-radius game. For five callers (anon, a squad member/follower who blocked a creator, the
-- blocked creator, a stranger with a private game, the host) and three argument sets, the B04 output is captured,
-- the migration is applied with \ir, the calls are repeated and compared with EXCEPT both ways.
--
-- Read-only LIVE DIFF for Memphis (after apply). Returns no row when the 5-arg is absent (B04: expected on live).
-- When present it must return one row: body_md5 = 8ba97b088c722df60f863eca264c4de0, games_cols =
-- {event_id,game_type,id,squad_id,sport_variant_id,venue_space_id}, removed_cols = {}, prosecdef = t,
-- provolatile = s, proconfig = {"search_path=public, pg_temp"}:
--   WITH f AS (SELECT p.* FROM pg_proc p
--               WHERE p.oid = to_regprocedure('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)')),
--        c AS (SELECT DISTINCT lower(m[1]) AS col FROM f, regexp_matches(f.prosrc, '\mg\.([a-z_][a-z0-9_]*)', 'gi') m)
--   SELECT md5(f.prosrc) AS body_md5,
--          (SELECT array_agg(col ORDER BY col) FROM c) AS games_cols,
--          (SELECT coalesce(array_agg(col ORDER BY col), '{}') FROM c
--            WHERE col = ANY ('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
--                               join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,
--                               geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,
--                               created_at,updated_at}')) AS removed_cols,
--          f.prosecdef, f.provolatile, f.proconfig, pg_get_function_result(f.oid) AS result
--     FROM f;
\set ON_ERROR_STOP 1
\if :{?mig}
\else
\set mig ../../migrations/20261111120800_kan714_r_rpc_get_nearby_games_kan712_inner.sql
\endif
BEGIN;
SELECT plan(10);

CREATE TEMP VIEW k906_removed (col) AS
  SELECT unnest('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                  join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                  venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]);
CREATE TEMP VIEW k906_fn AS
  SELECT p.* FROM pg_proc p
   WHERE p.oid = to_regprocedure('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)');
-- Aliases bound to games in the body ("games g", "public.games g", "games AS g").
CREATE TEMP VIEW k906_alias (a) AS
  SELECT DISTINCT lower(m[1])
    FROM k906_fn f, regexp_matches(f.prosrc, '(?:public\.)?\mgames\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') m;
CREATE TEMP VIEW k906_cols (col) AS
  SELECT DISTINCT lower(m[1])
    FROM k906_fn f, k906_alias al, regexp_matches(f.prosrc, '\m' || al.a || '\.([a-z_][a-z0-9_]*)', 'gi') m;

-- Pre-image attributes and body, before the migration.
CREATE TEMP TABLE k906_pre AS
  SELECT oid, md5(prosrc) AS body_md5, prosecdef, provolatile, proconfig, proowner, proacl::text AS acl,
         pg_get_function_result(oid) AS res, pg_get_function_identity_arguments(oid) AS idargs,
         pg_get_function_arguments(oid) AS args
    FROM k906_fn;

-- Seed. games and events carry the same shared values (KAN-711 parity, which KAN-866 assumes).
INSERT INTO public.sports VALUES ('00000000-0000-0000-0000-00000000005a', 'football', 'Football', 'kura');
INSERT INTO public.geo_locations VALUES
  ('00000000-0000-0000-0000-0000000001a1', '{55.2700,25.2000}'),
  ('00000000-0000-0000-0000-0000000001a2', '{55.2750,25.2030}'),
  ('00000000-0000-0000-0000-0000000001a3', '{56.5000,26.5000}');  -- far: outside the radius
INSERT INTO public.venues VALUES ('00000000-0000-0000-0000-0000000002a1', 'Venue One');
INSERT INTO public.blocks VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');  -- A blocks B
INSERT INTO public.follows VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000f');  -- A follows P
INSERT INTO public.squad_members VALUES ('00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-00000000000a');

-- id suffix, creator, visibility, squad, geo, cancelled, price, start offset
CREATE TEMP TABLE k906_seed (n int, creator uuid, vis text, squad uuid, geo uuid, cancelled bool, price numeric, hrs int);
INSERT INTO k906_seed VALUES
  (1, '00000000-0000-0000-0000-00000000000f', 'public',    null, '00000000-0000-0000-0000-0000000001a1', false, 20, 24),
  (2, '00000000-0000-0000-0000-00000000000f', 'private',   null, '00000000-0000-0000-0000-0000000001a1', false, 10, 30),
  (3, '00000000-0000-0000-0000-00000000000f', 'private',   '00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-0000000001a2', false, 30, 36),
  (4, '00000000-0000-0000-0000-00000000000f', 'followers', null, '00000000-0000-0000-0000-0000000001a2', false, 40, 42),
  (5, '00000000-0000-0000-0000-00000000000b', 'public',    null, '00000000-0000-0000-0000-0000000001a1', false, 15, 48),
  (6, '00000000-0000-0000-0000-00000000000c', 'private',   null, '00000000-0000-0000-0000-0000000001a2', false, 25, 54),
  (7, '00000000-0000-0000-0000-00000000000f', 'public',    null, '00000000-0000-0000-0000-0000000001a1', true,  5,  60),
  (8, '00000000-0000-0000-0000-00000000000f', 'public',    null, '00000000-0000-0000-0000-0000000001a3', false, 5,  66);
INSERT INTO public.events (id, event_type, title, start_at, end_at, capacity, min_skill, max_skill, listing_visibility,
                           join_policy, is_cancelled, sport_id, creator_profile_id, creator_user_id, geo_location_id,
                           venue_id, joining_rule, cost_cover)
  SELECT ('00000000-0000-0000-0000-0000000e000' || n)::uuid, 'game', 'Game ' || n, now() + make_interval(hours => hrs),
         now() + make_interval(hours => hrs + 2), 10, 1, 5, vis, 'open', cancelled,
         '00000000-0000-0000-0000-00000000005a', creator, creator, geo, '00000000-0000-0000-0000-0000000002a1',
         'anyone', 'split'
    FROM k906_seed;
INSERT INTO public.games (id, event_id, game_type, price_aed, squad_id, creator_profile_id, creator_user_id, title,
                          start_at, end_at, capacity, listing_visibility, join_policy, is_cancelled, sport_id,
                          geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover)
  SELECT ('00000000-0000-0000-0000-0000000a000' || s.n)::uuid, e.id, 'hosted', s.price, s.squad, e.creator_profile_id,
         e.creator_user_id, e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.join_policy,
         e.is_cancelled, e.sport_id, e.geo_location_id, e.venue_id, e.min_skill, e.max_skill, e.joining_rule,
         e.cost_cover
    FROM k906_seed s JOIN public.events e ON e.id = ('00000000-0000-0000-0000-0000000e000' || s.n)::uuid;
INSERT INTO public.game_roster VALUES
  ('00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-00000000000f', 'active', 'host'),
  ('00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-00000000000a', 'active', 'player');
INSERT INTO public.favorites VALUES ('00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-00000000000a');

-- Callers x argument sets. caller '' = anon (auth.uid() null).
CREATE TEMP TABLE k906_calls (caller text, sport uuid, sort text);
INSERT INTO k906_calls
  SELECT c, s, o
    FROM unnest('{"",00000000-0000-0000-0000-00000000000a,00000000-0000-0000-0000-00000000000b,00000000-0000-0000-0000-00000000000c,00000000-0000-0000-0000-00000000000f}'::text[]) c,
         (VALUES (null::uuid, 'distance'), ('00000000-0000-0000-0000-00000000005a'::uuid, 'distance'), (null::uuid, 'start')) a(s, o);

CREATE TEMP TABLE k906_out_pre  (caller text, sport uuid, sort text, r jsonb);
CREATE TEMP TABLE k906_out_post (caller text, sport uuid, sort text, r jsonb);

CREATE FUNCTION pg_temp.k906_capture(p_target text) RETURNS void LANGUAGE plpgsql AS $$
declare k record;
begin
  for k in select * from k906_calls loop
    perform set_config('request.jwt.claims', json_build_object('sub', k.caller)::text, true);
    execute format('insert into %I select $1, $2, $3, to_jsonb(x) from public.rpc_get_nearby_games(25.2000, 55.2700, 10000, $2, $3) x',
                   p_target) using k.caller, k.sport, k.sort;
  end loop;
  perform set_config('request.jwt.claims', '', true);
end $$;

SELECT pg_temp.k906_capture('k906_out_pre');

\ir :mig

SELECT pg_temp.k906_capture('k906_out_post');

SELECT has_function('public', 'rpc_get_nearby_games',
  ARRAY['double precision', 'double precision', 'integer', 'uuid', 'text'],
  'S1 the 5-arg rpc_get_nearby_games exists');

SELECT is((SELECT body_md5 FROM k906_pre), '63e5a660f80100f02e2674db40b58a3a',
  'S2 the pre-image is the B04 5-arg body (20261104100400:236-324)');

SELECT ok((SELECT count(DISTINCT r->>'id') FROM k906_out_pre) >= 5
          AND EXISTS (SELECT 1 FROM k906_out_pre WHERE caller = '' AND r->>'id' = '00000000-0000-0000-0000-0000000a0001')
          AND NOT EXISTS (SELECT 1 FROM k906_out_pre WHERE caller = '' AND r->>'id' <> '00000000-0000-0000-0000-0000000a0001'
                                                      AND r->>'id' <> '00000000-0000-0000-0000-0000000a0005')
          AND NOT EXISTS (SELECT 1 FROM k906_out_pre WHERE caller = '00000000-0000-0000-0000-00000000000a'
                                                      AND r->>'id' = '00000000-0000-0000-0000-0000000a0005')
          AND EXISTS (SELECT 1 FROM k906_out_pre WHERE caller = '00000000-0000-0000-0000-00000000000a'
                                                  AND r->>'id' = '00000000-0000-0000-0000-0000000a0003')
          AND EXISTS (SELECT 1 FROM k906_out_pre WHERE caller = '00000000-0000-0000-0000-00000000000c'
                                                  AND r->>'id' = '00000000-0000-0000-0000-0000000a0006'),
  'S3 the seed exercises the predicate (anon sees public only; blocked game hidden from blocker; squad and own-private visible)');

SELECT is_empty($$ SELECT * FROM k906_out_pre EXCEPT ALL SELECT * FROM k906_out_post $$,
  'S4a no row returned by the B04 body is lost after KAN-906 (15 calls)');
SELECT is_empty($$ SELECT * FROM k906_out_post EXCEPT ALL SELECT * FROM k906_out_pre $$,
  'S4b no row is gained after KAN-906 (15 calls)');

SELECT is((SELECT coalesce(array_agg(col ORDER BY col), '{}') FROM k906_cols WHERE col IN (SELECT col FROM k906_removed)),
  '{}'::text[], 'S5 the body reads none of the 22 KAN-866 games columns');

SELECT is((SELECT md5(prosrc) FROM k906_fn), '8ba97b088c722df60f863eca264c4de0',
  'S6 the body is the KAN-906 one (md5 pinned)');

SELECT is((SELECT row(oid, pg_get_function_result(oid), pg_get_function_identity_arguments(oid), pg_get_function_arguments(oid))::text FROM k906_fn),
          (SELECT row(oid, res, idargs, args)::text FROM k906_pre),
  'S7 same oid, result type, identity arguments and defaults');

SELECT is((SELECT row(prosecdef, provolatile, proconfig, proowner, proacl::text)::text FROM k906_fn),
          (SELECT row(prosecdef, provolatile, proconfig, proowner, acl)::text FROM k906_pre),
  'S8 SECURITY DEFINER, volatility, search_path, owner and ACL unchanged');

SELECT ok((SELECT prosecdef AND provolatile = 's' AND proconfig = '{"search_path=public, pg_temp"}' FROM k906_fn),
  'S9 prosecdef = t, provolatile = s, proconfig = {search_path=public, pg_temp}');

SELECT * FROM finish();
ROLLBACK;

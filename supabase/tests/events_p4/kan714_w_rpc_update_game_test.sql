-- KAN-912 (KAN-714 chain stage W, KAN-866 follow-up): proof for
-- supabase/migrations/20261111121400_kan714_w_rpc_update_game.sql.
-- public.rpc_update_game_kan712_inner (17 args) must read none of the 22 games columns KAN-866 removes, and must
-- return and write exactly what the 20261008140000:283-354 body (renamed by 20261103110000) returned and wrote.
--
-- READ-ONLY. pgTAP. One transaction, ROLLBACK at the end: the seed rows, the function replacement and the temp
-- objects all roll back. pgTAP under plain psql exits 0 even on "not ok": read the TAP lines, or use pg_prove.
--
-- HARNESS. Local throwaway Postgres only (never Supabase). The database must already hold the tables the body
-- touches and the inner exactly as the chain leaves it (md5(prosrc) 4529d87f1cbb5b5ff856fa39f33bb75f, owner-only
-- EXECUTE). It was run on a stub schema (events and games with the KAN-710 / baseline column types, game_roster,
-- auth.uid() from request.jwt.claims, public.is_admin(uuid) over a stub admin table, no KAN-712 triggers), because
-- the seed below inserts plain rows; on the full chain the KAN-712 guard, FKs and NOT NULLs need a different seed.
--
-- Run:
--   psql -X -v ON_ERROR_STOP=1 -d <throwaway db> -f supabase/tests/events_p4/kan714_w_rpc_update_game_test.sql
-- RED control (migration not applied): add -v mig=/dev/null. W6, W7 and W11-W13 must fail; the rest stay ok.
--
-- What it checks. Eight cases, each run on the pre-image and again after \ir of the migration: a cancelled game,
-- an ended game, a non-host caller, an admin caller (not the host, p_max_players below the roster count), the host
-- happy path (every parameter set), a missing id, the host with every optional parameter NULL (the COALESCE
-- fallbacks), and the host with p_clear_venue / p_clear_skill. games and events are seeded with identical values.
-- Each case is a round trip: call, then read the resulting games row, then roll the subtransaction back, so every
-- case starts from the same seed. Outcomes and rows are compared with EXCEPT both ways. W11-W13 run on the
-- migrated body only, on three extra games whose events row DIFFERS from the games row, and show the reads come
-- from events: they fail on the pre-image by construction.
--
-- Read-only LIVE DIFF for Memphis (after apply). It must return one row: body_md5 =
-- 6638b5cfed53f133eed91385f72284a5, games_cols = {allow_spectators,allows_waitlist,event_id,id,rules,venue_space_id},
-- removed_cols = {}, prosecdef = t, provolatile = v, proconfig = {search_path=public}, acl = {postgres=X/postgres}.
-- Before apply it returns body_md5 = 4529d87f1cbb5b5ff856fa39f33bb75f and removed_cols =
-- {capacity,creator_user_id,end_at,is_cancelled,join_policy,listing_visibility,max_skill,min_skill,title}:
--   WITH f AS (SELECT p.* FROM pg_proc p
--               WHERE p.oid = to_regprocedure('public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)')),
--        c AS (SELECT DISTINCT lower(m[1]) AS col FROM f, regexp_matches(f.prosrc, '\mg\.([a-z_][a-z0-9_]*)', 'gi') m)
--   SELECT md5(f.prosrc) AS body_md5,
--          (SELECT array_agg(col ORDER BY col) FROM c) AS games_cols,
--          (SELECT coalesce(array_agg(col ORDER BY col), '{}') FROM c
--            WHERE col = ANY ('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
--                               join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,
--                               geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,
--                               created_at,updated_at}')) AS removed_cols,
--          f.prosecdef, f.provolatile, f.proconfig, f.proacl, pg_get_function_result(f.oid) AS result
--     FROM f;
\set ON_ERROR_STOP 1
\if :{?mig}
\else
\set mig ../../migrations/20261111121400_kan714_w_rpc_update_game.sql
\endif
BEGIN;
SELECT plan(13);

CREATE TEMP VIEW k912_removed (col) AS
  SELECT unnest('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                  join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                  venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]);
CREATE TEMP VIEW k912_fn AS
  SELECT p.* FROM pg_proc p
   WHERE p.oid = to_regprocedure('public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)');
-- Aliases bound to games in the body ("games g", "public.games g", "games AS g").
CREATE TEMP VIEW k912_alias (a) AS
  SELECT DISTINCT lower(m[1])
    FROM k912_fn f, regexp_matches(f.prosrc, '(?:public\.)?\mgames\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') m;
CREATE TEMP VIEW k912_cols (col) AS
  SELECT DISTINCT lower(m[1])
    FROM k912_fn f, k912_alias al, regexp_matches(f.prosrc, '\m' || al.a || '\.([a-z_][a-z0-9_]*)', 'gi') m;

-- Pre-image attributes and body, before the migration.
CREATE TEMP TABLE k912_pre AS
  SELECT oid, md5(prosrc) AS body_md5, prosecdef, provolatile, proconfig, proowner, proacl::text AS acl,
         pg_get_function_result(oid) AS res, pg_get_function_identity_arguments(oid) AS idargs,
         pg_get_function_arguments(oid) AS args
    FROM k912_fn;

-- Seed. Users: h host, x stranger, a admin. Games: 1 open, 2 cancelled, 3 ended, 4-6 divergent (W11-W13 only).
INSERT INTO public.k912_admins VALUES ('00000000-0000-0000-0000-00000000000a');
INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at, capacity,
                           listing_visibility, join_policy, is_cancelled, min_skill, max_skill, joining_rule, cost_cover)
VALUES
  ('00000000-0000-0000-0000-0000000e0001', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Open game', now() + interval '1 day', now() + interval '1 day 2 hours', 10, 'public', 'open', false, 2, 8, 'free', 'free'),
  ('00000000-0000-0000-0000-0000000e0002', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Cancelled game', now() + interval '1 day', now() + interval '1 day 2 hours', 10, 'public', 'open', true, null, null, 'free', 'free'),
  ('00000000-0000-0000-0000-0000000e0003', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Ended game', now() - interval '1 day', now() - interval '22 hours', 10, 'public', 'open', false, null, null, 'free', 'free'),
  ('00000000-0000-0000-0000-0000000e0004', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Events title', now() + interval '1 day', now() + interval '1 day 2 hours', 20, 'followers', 'request', false, 4, 9, 'free', 'free'),
  ('00000000-0000-0000-0000-0000000e0005', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Events cancelled', now() + interval '1 day', now() + interval '1 day 2 hours', 10, 'public', 'open', true, null, null, 'free', 'free'),
  ('00000000-0000-0000-0000-0000000e0006', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000cc',
   'Events creator', now() + interval '1 day', now() + interval '1 day 2 hours', 10, 'public', 'open', false, null, null, 'free', 'free');
-- games mirror events exactly (game id = event id), plus game-only columns.
INSERT INTO public.games (id, event_id, game_type, title, creator_profile_id, creator_user_id, venue_space_id, start_at,
                          end_at, capacity, listing_visibility, join_policy, allow_spectators, min_skill, max_skill, rules,
                          is_cancelled, allows_waitlist, joining_rule, cost_cover, price_aed)
  SELECT e.id, e.id, 'casual', e.title, e.creator_profile_id, e.creator_user_id, '00000000-0000-0000-0000-0000000005a1',
         e.start_at, e.end_at, e.capacity, e.listing_visibility, e.join_policy, false, e.min_skill, e.max_skill,
         '{"note": "seed"}'::jsonb, e.is_cancelled, false, e.joining_rule, e.cost_cover, 10
    FROM public.events e;
-- W11-W13: break parity on games 4-6 only, so a read from g and a read from e give different answers.
UPDATE public.games SET title = 'Games title', capacity = 6, listing_visibility = 'public', join_policy = 'open',
                        min_skill = 1, max_skill = 3
 WHERE id = '00000000-0000-0000-0000-0000000e0004';
UPDATE public.games SET is_cancelled = false WHERE id = '00000000-0000-0000-0000-0000000e0005';
UPDATE public.games SET creator_user_id = '00000000-0000-0000-0000-00000000000f' WHERE id = '00000000-0000-0000-0000-0000000e0006';
INSERT INTO public.game_roster (game_id, user_id, role, status) VALUES
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-00000000000f', 'host', 'active'),
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000000b1', 'player', 'active'),
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000000b2', 'player', 'active'),
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000000b3', 'player', 'left');

-- Cases: n, caller, game. 1-8 compared pre/post; 11-13 post only.
CREATE TEMP TABLE k912_cases (n int PRIMARY KEY, label text, caller uuid, gid uuid);
INSERT INTO k912_cases VALUES
  (1,  'cancelled game, host',          '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0002'),
  (2,  'ended game, host',              '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0003'),
  (3,  'non-host caller',               '00000000-0000-0000-0000-0000000000cc', '00000000-0000-0000-0000-0000000e0001'),
  (4,  'admin caller',                  '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000e0001'),
  (5,  'host happy path',               '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (6,  'missing id',                    '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0009'),
  (7,  'host, optional params NULL',    '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (8,  'host, clear venue and skill',   '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (11, 'divergent fallbacks, host',     '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0004'),
  (12, 'events cancelled, games not',   '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0005'),
  (13, 'events creator differs, caller is the events creator',
                                        '00000000-0000-0000-0000-0000000000cc', '00000000-0000-0000-0000-0000000e0006');

CREATE FUNCTION pg_temp.k912_call(p_n int, p_gid uuid) RETURNS text LANGUAGE plpgsql AS $$
declare
  s timestamptz := now() + interval '2 days';
  f constant text := 'public.rpc_update_game_kan712_inner';
begin
  -- args: game, start, end, title, venue_space, clear_venue, visibility, join_policy, spectators, waitlist,
  --       min_skill, max_skill, clear_skill, rules, min_players, max_players, price
  if p_n in (1, 2, 3, 6) then
    return public.rpc_update_game_kan712_inner(p_gid, s, s + interval '2 hours', 'Renamed', null, false, null, null,
             null, null, null, null, false, null, null, null, 10);
  elsif p_n = 4 then
    return public.rpc_update_game_kan712_inner(p_gid, s, s + interval '2 hours', null, null, false, null, null,
             null, null, null, null, false, null, null, 2, 0);
  elsif p_n = 5 then
    return public.rpc_update_game_kan712_inner(p_gid, s, s + interval '90 minutes', 'New title',
             '00000000-0000-0000-0000-0000000005a2', false, 'followers', 'request', true, true, 3, 7, false,
             '{"surface": "grass"}'::jsonb, 2, 12, 25.555);
  elsif p_n in (7, 11, 12, 13) then
    return public.rpc_update_game_kan712_inner(p_gid, s, s + interval '2 hours', '', null, false, null, null,
             null, null, null, null, false, null, null, null, 5);
  elsif p_n = 8 then
    return public.rpc_update_game_kan712_inner(p_gid, s, s + interval '2 hours', null, '00000000-0000-0000-0000-0000000005a3',
             true, null, null, null, null, 4, 6, true, null, null, null, 5);
  end if;
  raise exception 'k912: no case %', p_n;
end $$;

-- Round trip per case: call, read the resulting games row, roll the subtransaction back (custom SQLSTATE).
-- On an error the row read is the untouched seed row (or NULL for a missing id).
CREATE FUNCTION pg_temp.k912_capture(p_out text, p_ns int[]) RETURNS void LANGUAGE plpgsql AS $$
declare
  k   record;
  v_ret text;
  v_row jsonb;
begin
  for k in select * from k912_cases where n = any (p_ns) order by n loop
    v_ret := null; v_row := null;
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', k.caller)::text, true);
      v_ret := pg_temp.k912_call(k.n, k.gid);
      select to_jsonb(g) into v_row from public.games g where g.id = k.gid;
      raise exception using errcode = 'P0K91', message = 'k912_reset';
    exception
      when sqlstate 'P0K91' then null;
      when others then
        v_ret := 'ERROR ' || sqlstate || ' ' || sqlerrm;
        select to_jsonb(g) into v_row from public.games g where g.id = k.gid;
    end;
    execute format('insert into %I values ($1, $2, $3)', p_out) using k.n, v_ret, v_row;
  end loop;
  perform set_config('request.jwt.claims', '', true);
end $$;

CREATE TEMP TABLE k912_out_pre  (n int, ret text, r jsonb);
CREATE TEMP TABLE k912_out_post (n int, ret text, r jsonb);
CREATE TEMP TABLE k912_out_probe (n int, ret text, r jsonb);

SELECT pg_temp.k912_capture('k912_out_pre', '{1,2,3,4,5,6,7,8}');

\ir :mig

SELECT pg_temp.k912_capture('k912_out_post', '{1,2,3,4,5,6,7,8}');
SELECT pg_temp.k912_capture('k912_out_probe', '{11,12,13}');

SELECT has_function('public', 'rpc_update_game_kan712_inner',
  ARRAY['uuid', 'timestamp with time zone', 'timestamp with time zone', 'text', 'uuid', 'boolean', 'text', 'text',
        'boolean', 'boolean', 'integer', 'integer', 'boolean', 'jsonb', 'integer', 'integer', 'numeric'],
  'W1 the 17-arg rpc_update_game_kan712_inner exists');

SELECT is((SELECT body_md5 FROM k912_pre), '4529d87f1cbb5b5ff856fa39f33bb75f',
  'W2 the pre-image is the 20261008140000:283-354 body, renamed by 20261103110000');

SELECT ok((SELECT count(*) FROM k912_out_pre WHERE n IN (1, 2, 3, 6) AND ret = 'ERROR P0001 not_host_or_not_found') = 4
          AND (SELECT count(*) FROM k912_out_pre WHERE n IN (4, 5, 7, 8) AND ret = 'updated') = 4
          AND (SELECT r @> '{"title": "New title", "listing_visibility": "followers", "join_policy": "request",
                             "min_skill": 3, "max_skill": 7, "capacity": 12, "price_aed": 25.56,
                             "venue_space_id": "00000000-0000-0000-0000-0000000005a2",
                             "rules": {"surface": "grass", "min_players": 2, "max_players": 12}}'::jsonb
                 FROM k912_out_pre WHERE n = 5)
          AND (SELECT r @> '{"title": "Open game", "capacity": 10, "min_skill": 2, "max_skill": 8,
                             "listing_visibility": "public", "join_policy": "open"}'::jsonb FROM k912_out_pre WHERE n = 7)
          AND (SELECT (r->>'capacity')::int = 3 FROM k912_out_pre WHERE n = 4)
          AND (SELECT r->'venue_space_id' = 'null' AND r->'min_skill' = 'null' FROM k912_out_pre WHERE n = 8)
          AND (SELECT r IS NULL FROM k912_out_pre WHERE n = 6),
  'W3 the seed exercises every case on the pre-image (4 x not_host_or_not_found, 4 x updated with the expected rows)');

SELECT is_empty($$ SELECT n, ret, r FROM k912_out_pre EXCEPT ALL SELECT n, ret, r FROM k912_out_post $$,
  'W4 no outcome or resulting row of the pre-image is lost after KAN-912 (8 cases)');
SELECT is_empty($$ SELECT n, ret, r FROM k912_out_post EXCEPT ALL SELECT n, ret, r FROM k912_out_pre $$,
  'W5 no outcome or resulting row is gained after KAN-912 (8 cases)');

SELECT is((SELECT coalesce(array_agg(col ORDER BY col), '{}') FROM k912_cols WHERE col IN (SELECT col FROM k912_removed)),
  '{}'::text[], 'W6 the body reads none of the 22 KAN-866 games columns through a games alias');

SELECT is((SELECT md5(prosrc) FROM k912_fn), '6638b5cfed53f133eed91385f72284a5',
  'W7 the body is the KAN-912 one (md5 pinned)');

SELECT is((SELECT row(oid, pg_get_function_result(oid), pg_get_function_identity_arguments(oid), pg_get_function_arguments(oid))::text FROM k912_fn),
          (SELECT row(oid, res, idargs, args)::text FROM k912_pre),
  'W8 same oid, result type, identity arguments and defaults');

SELECT is((SELECT row(prosecdef, provolatile, proconfig, proowner, proacl::text)::text FROM k912_fn),
          (SELECT row(prosecdef, provolatile, proconfig, proowner, acl)::text FROM k912_pre),
  'W9 SECURITY DEFINER, volatility, search_path, owner and ACL unchanged');

SELECT ok((SELECT prosecdef AND provolatile = 'v' AND proconfig = '{search_path=public}' AND pg_get_function_result(oid) = 'text'
             FROM k912_fn),
  'W10 prosecdef = t, provolatile = v, proconfig = {search_path=public}, returns text');

SELECT ok((SELECT ret = 'updated'
                  AND r @> '{"title": "Events title", "capacity": 20, "listing_visibility": "followers",
                             "join_policy": "request", "min_skill": 4, "max_skill": 9}'::jsonb
             FROM k912_out_probe WHERE n = 11),
  'W11 COALESCE fallbacks read events (games row diverged: title, capacity, visibility, join policy, skills)');
SELECT is((SELECT ret FROM k912_out_probe WHERE n = 12), 'ERROR P0001 not_host_or_not_found',
  'W12 the cancelled predicate reads events.is_cancelled (games says not cancelled)');
SELECT is((SELECT ret FROM k912_out_probe WHERE n = 13), 'updated',
  'W13 the host predicate reads events.creator_user_id (games names another creator)');

SELECT * FROM finish();
ROLLBACK;

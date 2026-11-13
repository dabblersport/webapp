-- SUPERSEDED 2026-11-13 by KAN-718 (20261113052438_kan718_writers_series.sql): the S7 md5s below are the KAN-917 body;
-- live is now the KAN-718 body. Point-in-time proof of its own migration; the current proof is
-- kan718_writers_equality_live_test.sql.
-- KAN-917 (KAN-714 chain stage W, KAN-866 follow-up): proof for
-- supabase/migrations/20261111121900_kan714_w_rpc_edit_game_series_occurrence_kan712_inner.sql.
-- public.rpc_edit_game_series_occurrence_kan712_inner must read none of the 22 games columns KAN-866 removes, and must
-- return and write exactly what the 20261104101400:264-312 body (B14, renamed by kan712_wrap_rpc) returned and wrote.
--
-- READ-ONLY. pgTAP. One transaction, ROLLBACK at the end: the seed rows, the function replacement and the temp
-- objects all roll back. pgTAP under plain psql exits 0 even on "not ok": read the TAP lines, or use pg_prove.
--
-- HARNESS. Local throwaway Postgres only (never Supabase). The database must already hold the tables the body
-- touches and the inner exactly as the chain leaves it (md5(prosrc) 37c172cd1396ae272c4dd0555e883cf9,
-- md5(pg_get_functiondef) 5adf6e028e5a3407a145e014620f7757, owner-only EXECUTE). It was run on a STUB schema (events
-- with the KAN-710 column types; game_series; games with series_id, event_id, venue_space_id and the 22 columns;
-- the games_series_id_start_at_key partial unique index; game_roster; public.effective_actor_uid() from
-- request.jwt.claims; no KAN-712 triggers and no generated wrapper), because the seed below inserts plain rows; on the
-- full chain the KAN-712 guard, the KAN-718 occurrence guard, FKs and NOT NULLs need a different seed.
--
-- Run:
--   psql -X -v ON_ERROR_STOP=1 -d <throwaway db> -f supabase/tests/events_p4/kan714_w_rpc_edit_game_series_occurrence_kan712_inner_test.sql
-- RED control (migration not applied): add -v mig=/dev/null. S6, S7, S11 and S12 must fail; the rest stay ok.
--
-- What it checks. Ten cases, each run on the pre-image and again after \ir of the migration: the host editing title and
-- capacity (non-NULL), the host with every parameter NULL (title / capacity fall back to the old value), a non-host
-- caller, a cancelled occurrence, a past occurrence, a slot already taken (occurrence_time_taken), a capacity below the
-- roster (occurrence_capacity_invalid), a start in the past (occurrence_time_invalid), no caller (not_authenticated)
-- and a missing id. games and events are seeded with identical values. Each case is a round trip: call, read the
-- resulting games row, roll the subtransaction back, so every case starts from the same seed. Outcomes and rows are
-- compared with EXCEPT both ways. S11-S12 run on the migrated body only, on an occurrence whose events row DIFFERS from
-- its games row (title, capacity), and show the fallbacks read events: they fail on the pre-image by construction.
--
-- Read-only LIVE DIFF for Memphis (run before and after apply). After apply it must return one row:
--   inner_src_md5 = eb1a06eb5a534c778530ddbc6ee549ca, inner_def_md5 = 1ae1bbf4f6fc68d1ef994b1c6592ae0d,
--   reads_22 = {}, prosecdef = t, provolatile = v, proconfig = {"search_path=public, pg_temp"}, acl = {postgres=X/postgres},
--   result = jsonb, twin_def_md5 = be3938f0b159dc143078453459882869 (the generated wrapper, untouched).
-- Before apply: inner_src_md5 = 37c172cd1396ae272c4dd0555e883cf9, inner_def_md5 = 5adf6e028e5a3407a145e014620f7757,
--   reads_22 = {"bare capacity","bare title"}, everything else identical.
--   WITH f AS (SELECT p.*, regexp_replace(p.prosrc, '--[^\n]*', '', 'g') AS src FROM pg_proc p
--               WHERE p.oid = to_regprocedure('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)')),
--        k AS (SELECT 'creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at'::text AS alt),
--        h AS (SELECT lower(m[1] || '.' || m[2]) AS hit FROM f, k, regexp_matches(f.src, '\m([a-z_][a-z0-9_]*)\.(' || k.alt || ')\M', 'gi') m
--               WHERE lower(m[1]) IN (SELECT lower(a[1]) FROM f, regexp_matches(f.src, '\mgames\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') a)
--              UNION
--              SELECT 'bare ' || lower(m[1]) FROM f, k, regexp_matches(f.src, '(?<![.\w])(' || k.alt || ')\M(?!\s*=)', 'gi') m)
--   SELECT md5(f.prosrc) AS inner_src_md5, md5(pg_get_functiondef(f.oid)) AS inner_def_md5,
--          (SELECT coalesce(array_agg(hit ORDER BY hit), '{}') FROM h) AS reads_22,
--          f.prosecdef, f.provolatile, f.proconfig, f.proacl AS acl, pg_get_function_result(f.oid) AS result,
--          md5(pg_get_functiondef(to_regprocedure('public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)'))) AS twin_def_md5
--     FROM f;
\set ON_ERROR_STOP 1
\if :{?mig}
\else
\set mig ../../migrations/20261111121900_kan714_w_rpc_edit_game_series_occurrence_kan712_inner.sql
\endif
BEGIN;
SELECT plan(12);

CREATE TEMP VIEW k917_fn AS
  SELECT p.*, regexp_replace(p.prosrc, '--[^\n]*', '', 'g') AS src FROM pg_proc p
   WHERE p.oid = to_regprocedure('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)');
-- Reads of the 22 (comments stripped): qualified by an alias bound to games, or bare and not a SET target.
CREATE TEMP VIEW k917_reads (hit) AS
  WITH k AS (SELECT 'creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at'::text AS alt)
  SELECT lower(m[1] || '.' || m[2]) FROM k917_fn f, k, regexp_matches(f.src, '\m([a-z_][a-z0-9_]*)\.(' || k.alt || ')\M', 'gi') m
   WHERE lower(m[1]) IN (SELECT lower(a[1]) FROM k917_fn f2, regexp_matches(f2.src, '\mgames\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') a)
  UNION
  SELECT 'bare ' || lower(m[1]) FROM k917_fn f, k, regexp_matches(f.src, '(?<![.\w])(' || k.alt || ')\M(?!\s*=)', 'gi') m;

-- Pre-image attributes and body, before the migration.
CREATE TEMP TABLE k917_pre AS
  SELECT oid, md5(prosrc) AS body_md5, md5(pg_get_functiondef(oid)) AS def_md5, prosecdef, provolatile, proconfig,
         proowner, proacl::text AS acl, pg_get_function_result(oid) AS res,
         pg_get_function_identity_arguments(oid) AS idargs, pg_get_function_arguments(oid) AS args,
         (SELECT coalesce(array_agg(hit ORDER BY hit), '{}') FROM k917_reads) AS reads
    FROM k917_fn;

-- Seed. Users: ...0f host, ...cc stranger. Series ...5e1. Occurrences (game id = event id):
--   e0001 open, 3 active players; e0002 cancelled; e0003 past; e0004 open (its slot is the time_taken target);
--   e0005 open, games row DIVERGES from events on title and capacity (S11-S12 only).
INSERT INTO public.game_series (id) VALUES ('00000000-0000-0000-0000-0000000005e1');
INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at, capacity,
                           listing_visibility, join_policy, is_cancelled, joining_rule, cost_cover, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-0000000e0001', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Occurrence 1', now() + interval '2 days', now() + interval '2 days 2 hours', 10, 'public', 'open', false, 'free', 'free',
   now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-0000000e0002', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Occurrence 2 cancelled', now() + interval '9 days', now() + interval '9 days 2 hours', 10, 'public', 'open', true, 'free', 'free',
   now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-0000000e0003', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Occurrence 3 past', now() - interval '5 days', now() - interval '5 days' + interval '2 hours', 10, 'public', 'open', false, 'free', 'free',
   now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-0000000e0004', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Occurrence 4', now() + interval '16 days', now() + interval '16 days 2 hours', 10, 'public', 'open', false, 'free', 'free',
   now() - interval '7 days', now() - interval '7 days'),
  ('00000000-0000-0000-0000-0000000e0005', 'game', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000f',
   'Events title', now() + interval '23 days', now() + interval '23 days 2 hours', 20, 'public', 'open', false, 'free', 'free',
   now() - interval '7 days', now() - interval '7 days');
-- games mirror events exactly, plus game-only columns.
INSERT INTO public.games (id, event_id, series_id, title, creator_profile_id, creator_user_id, venue_space_id, start_at,
                          end_at, capacity, listing_visibility, join_policy, is_cancelled, joining_rule, cost_cover,
                          created_at, updated_at)
  SELECT e.id, e.id, '00000000-0000-0000-0000-0000000005e1', e.title, e.creator_profile_id, e.creator_user_id,
         '00000000-0000-0000-0000-0000000005a1', e.start_at, e.end_at, e.capacity, e.listing_visibility, e.join_policy,
         e.is_cancelled, e.joining_rule, e.cost_cover, e.created_at, e.updated_at
    FROM public.events e;
-- S11-S12: break parity on e0005 only, so a read from games and a read from events give different answers.
UPDATE public.games SET title = 'Games title', capacity = 6 WHERE id = '00000000-0000-0000-0000-0000000e0005';
INSERT INTO public.game_roster (game_id, user_id, role, status) VALUES
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-00000000000f', 'host', 'active'),
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000000b1', 'player', 'active'),
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000000b2', 'player', 'active'),
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000000b3', 'sub', 'active'),
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000000b4', 'player', 'left');

-- Cases: n, caller, game. 1-10 compared pre/post; 11-12 post only.
CREATE TEMP TABLE k917_cases (n int PRIMARY KEY, label text, caller uuid, gid uuid);
INSERT INTO k917_cases VALUES
  (1,  'host edits title + capacity (non-NULL)', '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (2,  'host, every parameter NULL',             '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (3,  'non-host caller',                        '00000000-0000-0000-0000-0000000000cc', '00000000-0000-0000-0000-0000000e0001'),
  (4,  'cancelled occurrence',                   '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0002'),
  (5,  'past occurrence',                        '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0003'),
  (6,  'slot taken by e0004',                    '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (7,  'capacity below roster (3)',              '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (8,  'start in the past',                      '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0001'),
  (9,  'no caller',                              NULL,                                   '00000000-0000-0000-0000-0000000e0001'),
  (10, 'missing id',                             '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0009'),
  (11, 'divergent, title + capacity NULL',       '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0005'),
  (12, 'divergent, title NULL, capacity set',    '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000e0005');

CREATE FUNCTION pg_temp.k917_call(p_n int, p_gid uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
declare
  s timestamptz := now() + interval '3 days';
begin
  -- args: game, title, start, end, capacity, venue_space
  if p_n = 1 then
    return public.rpc_edit_game_series_occurrence_kan712_inner(p_gid, 'New title', s, s + interval '90 minutes', 12,
             '00000000-0000-0000-0000-0000000005a2');
  elsif p_n in (2, 3, 4, 5, 9, 10, 11) then
    return public.rpc_edit_game_series_occurrence_kan712_inner(p_gid, null, null, null, null, null);
  elsif p_n = 6 then
    return public.rpc_edit_game_series_occurrence_kan712_inner(p_gid, null,
             (select start_at from public.events where id = '00000000-0000-0000-0000-0000000e0004'), null, null, null);
  elsif p_n = 7 then
    return public.rpc_edit_game_series_occurrence_kan712_inner(p_gid, null, null, null, 2, null);
  elsif p_n = 8 then
    return public.rpc_edit_game_series_occurrence_kan712_inner(p_gid, null, now() - interval '1 hour', null, null, null);
  elsif p_n = 12 then
    return public.rpc_edit_game_series_occurrence_kan712_inner(p_gid, null, null, null, 8, null);
  end if;
  raise exception 'k917: no case %', p_n;
end $$;

-- Round trip per case: call, read the resulting games row, roll the subtransaction back (custom SQLSTATE).
-- On an error the row read is the untouched seed row (or NULL for a missing id).
CREATE FUNCTION pg_temp.k917_capture(p_out text, p_ns int[]) RETURNS void LANGUAGE plpgsql AS $$
declare
  k     record;
  v_ret text;
  v_row jsonb;
begin
  for k in select * from k917_cases where n = any (p_ns) order by n loop
    v_ret := null; v_row := null;
    begin
      perform set_config('request.jwt.claims', coalesce(json_build_object('sub', k.caller)::text, ''), true);
      v_ret := pg_temp.k917_call(k.n, k.gid)::text;
      select to_jsonb(g) into v_row from public.games g where g.id = k.gid;
      raise exception using errcode = 'P0K91', message = 'k917_reset';
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

CREATE TEMP TABLE k917_out_pre   (n int, ret text, r jsonb);
CREATE TEMP TABLE k917_out_post  (n int, ret text, r jsonb);
CREATE TEMP TABLE k917_out_probe (n int, ret text, r jsonb);

SELECT pg_temp.k917_capture('k917_out_pre', '{1,2,3,4,5,6,7,8,9,10}');

\ir :mig

SELECT pg_temp.k917_capture('k917_out_post', '{1,2,3,4,5,6,7,8,9,10}');
SELECT pg_temp.k917_capture('k917_out_probe', '{11,12}');

SELECT has_function('public', 'rpc_edit_game_series_occurrence_kan712_inner',
  ARRAY['uuid', 'text', 'timestamp with time zone', 'timestamp with time zone', 'integer', 'uuid'],
  'S1 rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid) exists');

SELECT is((SELECT body_md5 || ' ' || def_md5 FROM k917_pre),
  '37c172cd1396ae272c4dd0555e883cf9 5adf6e028e5a3407a145e014620f7757',
  'S2 the pre-image is the 20261104101400:264-312 body renamed by kan712_wrap_rpc (B14 post-pin reproduced)');

SELECT ok((SELECT ret = '{"game_id": "00000000-0000-0000-0000-0000000e0001", "series_id": "00000000-0000-0000-0000-0000000005e1"}'
                  AND r @> '{"title": "New title", "capacity": 12, "venue_space_id": "00000000-0000-0000-0000-0000000005a2"}'::jsonb
             FROM k917_out_pre WHERE n = 1)
          AND (SELECT r @> '{"title": "Occurrence 1", "capacity": 10, "venue_space_id": "00000000-0000-0000-0000-0000000005a1"}'::jsonb
                  AND ret LIKE '{"game_id"%' FROM k917_out_pre WHERE n = 2)
          AND (SELECT ret FROM k917_out_pre WHERE n = 3)  = 'ERROR P0001 not_host_or_not_found'
          AND (SELECT ret FROM k917_out_pre WHERE n = 4)  = 'ERROR P0001 occurrence_not_editable'
          AND (SELECT ret FROM k917_out_pre WHERE n = 5)  = 'ERROR P0001 occurrence_not_editable'
          AND (SELECT ret FROM k917_out_pre WHERE n = 6)  = 'ERROR P0001 occurrence_time_taken'
          AND (SELECT ret FROM k917_out_pre WHERE n = 7)  = 'ERROR P0001 occurrence_capacity_invalid'
          AND (SELECT ret FROM k917_out_pre WHERE n = 8)  = 'ERROR P0001 occurrence_time_invalid'
          AND (SELECT ret FROM k917_out_pre WHERE n = 9)  = 'ERROR P0001 not_authenticated'
          AND (SELECT ret = 'ERROR P0001 not_host_or_not_found' AND r IS NULL FROM k917_out_pre WHERE n = 10),
  'S3 the seed exercises every case on the pre-image (2 x updated with the expected rows, 8 x the expected error)');

SELECT is_empty($$ SELECT n, ret, r FROM k917_out_pre EXCEPT ALL SELECT n, ret, r FROM k917_out_post $$,
  'S4 no outcome or resulting row of the pre-image is lost after KAN-917 (10 cases)');
SELECT is_empty($$ SELECT n, ret, r FROM k917_out_post EXCEPT ALL SELECT n, ret, r FROM k917_out_pre $$,
  'S5 no outcome or resulting row is gained after KAN-917 (10 cases)');

SELECT is((SELECT coalesce(array_agg(hit ORDER BY hit), '{}') FROM k917_reads), '{}'::text[],
  'S6 the body reads none of the 22 KAN-866 columns (no games-alias mention, bare only as a SET target)');

SELECT is((SELECT md5(prosrc) || ' ' || md5(pg_get_functiondef(oid)) FROM k917_fn),
  'eb1a06eb5a534c778530ddbc6ee549ca 1ae1bbf4f6fc68d1ef994b1c6592ae0d', 'S7 the body is the KAN-917 one (md5 pinned)');

SELECT is((SELECT row(oid, pg_get_function_result(oid), pg_get_function_identity_arguments(oid), pg_get_function_arguments(oid))::text FROM k917_fn),
          (SELECT row(oid, res, idargs, args)::text FROM k917_pre),
  'S8 same oid, result type, identity arguments and defaults');

SELECT is((SELECT row(prosecdef, provolatile, proconfig, proowner, proacl::text)::text FROM k917_fn),
          (SELECT row(prosecdef, provolatile, proconfig, proowner, acl)::text FROM k917_pre),
  'S9 SECURITY DEFINER, volatility, search_path, owner and ACL unchanged');

SELECT ok((SELECT prosecdef AND provolatile = 'v' AND proconfig = '{"search_path=public, pg_temp"}'
                  AND pg_get_function_result(oid) = 'jsonb' FROM k917_fn)
          AND (SELECT reads = '{"bare capacity","bare title"}' FROM k917_pre),
  'S10 prosecdef = t, provolatile = v, search_path public, pg_temp, returns jsonb; the probe saw the two pre-image reads');

SELECT ok((SELECT ret LIKE '{"game_id"%' AND r @> '{"title": "Events title", "capacity": 20}'::jsonb
             FROM k917_out_probe WHERE n = 11),
  'S11 NULL title / capacity fall back to events (games row diverged: Games title / 6)');
SELECT ok((SELECT ret LIKE '{"game_id"%' AND r @> '{"title": "Events title", "capacity": 8}'::jsonb
             FROM k917_out_probe WHERE n = 12),
  'S12 NULL title falls back to events.title while p_capacity is applied');

SELECT * FROM finish();
ROLLBACK;

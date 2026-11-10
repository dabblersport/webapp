-- KAN-714 RESULT-PARITY SNAPSHOT. LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end.
--
-- Prints one sorted line per (reader, case, actor):  reader|case|actor|n=<rows>|<md5 of the full output>
-- Run on the SAME database BEFORE KAN-714, AFTER KAN-714, and AFTER rollback_kan714.sql; `diff` of the three
-- outputs must be empty (KAN714_CONTRACT.md section 3). Errors are captured as ERR <sqlstate>.
--
-- Every repointed reader is called, plus the two named UNCHANGED/EXCEPTION ones (v_game_rating, rpc_meetup_my).
-- Two hashes per set-returning reader:
--   *  "sorted": the full output ordered by every column (multiset equality: same rows, same duplicates);
--   *  "natural": the output in the reader's OWN order (ORDER BY inside the view / function), which is part of
--      the contract. Keyset pages over equal start_at (groups of 5 share one instant) use ORDER BY start_at, id.
-- Actors: anon; authenticated a1 owner, a2 non-member, a3 admin, a4 member, a5 follower+friend, a6 follower
-- BLOCKED by a1, a7 invitee/waitlisted (privacy: hides game history), a9 uid without a profile;
-- service_role with no uid and as a1.
\set ON_ERROR_STOP 1



BEGIN;
CREATE TEMP TABLE snap (reader text, cs text, actor text, val text);

CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE;
    RESET ROLE;
    v := 'ERR ' || s;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;

-- Wrap a row source as "n=<count>|<md5>" in the given order.
CREATE FUNCTION pg_temp.h(p_src text, p_order text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT format('SELECT ''n='' || count(*) || ''|'' || md5(coalesce(string_agg(t::text, E''\n'' ORDER BY %s), '''')) FROM (%s) t', p_order, p_src)
$$;
-- Natural order: number the rows as the reader returns them.
CREATE FUNCTION pg_temp.hn(p_src text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT format('SELECT ''n='' || count(*) || ''|'' || md5(coalesce(string_agg(t::text, E''\n'' ORDER BY rn), '''')) FROM (SELECT row_number() OVER () AS rn, s AS t FROM (%s) s) t', p_src)
$$;

CREATE TEMP TABLE actors (actor text, role text, uid uuid);
INSERT INTO actors VALUES
  ('anon', 'anon', NULL),
  ('a1', 'authenticated', '00000000-0000-0000-0000-0000000000a1'), ('a2', 'authenticated', '00000000-0000-0000-0000-0000000000a2'),
  ('a3', 'authenticated', '00000000-0000-0000-0000-0000000000a3'), ('a4', 'authenticated', '00000000-0000-0000-0000-0000000000a4'),
  ('a5', 'authenticated', '00000000-0000-0000-0000-0000000000a5'), ('a6', 'authenticated', '00000000-0000-0000-0000-0000000000a6'),
  ('a7', 'authenticated', '00000000-0000-0000-0000-0000000000a7'), ('a9', 'authenticated', '00000000-0000-0000-0000-0000000000a9'),
  ('svc', 'service_role', NULL), ('svc-a1', 'service_role', '00000000-0000-0000-0000-0000000000a1');

-- Sample ids: the KAN-713 matrix rows, bulk rows of every visibility/cancel state, a missing id, a cross-type id.
CREATE TEMP TABLE mids AS
  SELECT id FROM public.meetups WHERE id::text LIKE '71300000%'
  UNION ALL SELECT id FROM public.meetups WHERE id::text LIKE '71400000%' AND right(id::text, 3)::int BETWEEN 1 AND 12
  UNION ALL SELECT id FROM public.meetups WHERE id = '71400000-0000-0000-0001-000000000050'   -- next 7 days
  UNION ALL SELECT id FROM public.meetups WHERE id = '71400000-0000-0000-0001-000000000017'   -- cancelled
  UNION ALL SELECT '00000000-0000-0000-0000-00000000dead'::uuid
  UNION ALL SELECT '71300000-0000-0000-0000-000000000001'::uuid;                              -- a game id
CREATE TEMP TABLE gids AS
  SELECT array_agg(id ORDER BY id) AS ids FROM (
    SELECT id FROM public.games WHERE id::text LIKE '71300000%'
    UNION ALL (SELECT id FROM public.games WHERE id::text LIKE '71400000%' ORDER BY id LIMIT 196)) x;
GRANT SELECT ON mids, gids TO anon, authenticated, service_role;

CREATE TEMP TABLE cases (reader text, cs text, q text);
INSERT INTO cases VALUES
  ('v_game_card', 'sorted', pg_temp.h('SELECT * FROM public.v_game_card', 't::text')),
  ('v_game_card', 'dup', 'SELECT count(*) - count(DISTINCT id) FROM public.v_game_card'),
  ('v_game_card', 'keyset-p1', pg_temp.h('SELECT * FROM public.v_game_card WHERE start_at >= ''2030-01-01'' ORDER BY start_at, id LIMIT 25', 't.start_at, t.id')),
  ('v_game_card', 'keyset-p2', pg_temp.h('SELECT * FROM public.v_game_card WHERE (start_at, id) > (''2030-01-01 05:00+00'', ''71400000-0000-0000-0000-000000000027'') ORDER BY start_at, id LIMIT 25', 't.start_at, t.id')),
  ('v_game_card', 'filter-public-open', pg_temp.h('SELECT id, title, start_at FROM public.v_game_card WHERE listing_visibility = ''public'' AND join_policy = ''open'' AND NOT is_cancelled', 't::text')),
  ('v_game_card', 'by-id', pg_temp.h('SELECT * FROM public.v_game_card WHERE id = ''71300000-0000-0000-0000-000000000002''', 't::text')),
  ('v_my_games', 'sorted', pg_temp.h('SELECT * FROM public.v_my_games', 't::text')),
  ('v_my_games', 'keyset-p1', pg_temp.h('SELECT * FROM public.v_my_games ORDER BY start_at, id, my_roster_status LIMIT 30', 't.start_at, t.id, t.my_roster_status')),
  ('v_meetup_list', 'sorted', pg_temp.h('SELECT * FROM public.v_meetup_list', 't::text')),
  -- natural order = the view's ORDER BY key sequence. Pre-KAN-714 the order inside equal keys was undefined;
  -- KAN-714 adds an id tie-break, so only the key sequence is a parity property (rows are covered by 'sorted').
  ('v_meetup_list', 'natural', pg_temp.hn('SELECT coalesce(updated_at, created_at) AS k FROM public.v_meetup_list')),
  ('v_meetup_list', 'ties', 'SELECT count(*) FROM (SELECT coalesce(updated_at, created_at) k FROM public.v_meetup_list GROUP BY 1 HAVING count(*) > 1) t'),
  ('v_meetup_list', 'dup', 'SELECT count(*) - count(DISTINCT id) FROM public.v_meetup_list'),
  ('v_meetup_list', 'keyset-p1', pg_temp.h('SELECT * FROM public.v_meetup_list WHERE start_at >= ''2030-01-01'' ORDER BY start_at, id LIMIT 25', 't.start_at, t.id')),
  ('v_meetup_counts', 'sorted', pg_temp.h('SELECT * FROM public.v_meetup_counts', 't::text')),
  ('meetup_counts', 'sample', pg_temp.h('SELECT m.id, c.* FROM pg_temp.mids m CROSS JOIN LATERAL public.meetup_counts(m.id) c', 't::text')),
  ('v_rateable_after_game', 'sorted', pg_temp.h('SELECT * FROM public.v_rateable_after_game', 't::text')),
  ('v_host_weekly_metrics', 'sorted', pg_temp.h('SELECT * FROM public.v_host_weekly_metrics', 't::text')),
  ('v_game_rating', 'sorted', pg_temp.h('SELECT * FROM public.v_game_rating', 't::text')),
  ('rpc_meetup_card', 'sample', pg_temp.h('SELECT m.id, pg_temp.card(m.id) AS card FROM pg_temp.mids m', 't::text')),
  ('rpc_meetup_attendees', 'sample', pg_temp.h('SELECT m.id, pg_temp.att(m.id, NULL, 200, 0) AS a FROM pg_temp.mids m', 't::text')),
  ('rpc_meetup_attendees', 'page-going', pg_temp.h('SELECT m.id, pg_temp.att(m.id, ''going'', 2, 1) AS a FROM pg_temp.mids m', 't::text')),
  ('rpc_games_following_joined', 'sample', pg_temp.h('SELECT * FROM public.rpc_games_following_joined((SELECT ids FROM pg_temp.gids))', 't::text')),
  ('rpc_sport_overview', 'all', pg_temp.h('SELECT * FROM public.rpc_sport_overview(''00000000-0000-0000-0000-0000000000e1'')', 't::text')),
  ('rpc_sport_overview', 'dxb', pg_temp.h('SELECT * FROM public.rpc_sport_overview(''00000000-0000-0000-0000-0000000000e1'', ''DXB'')', 't::text')),
  ('rpc_meetup_my', 'call', pg_temp.h('SELECT * FROM public.rpc_meetup_my()', 't::text'));

-- Per-id error capture for the two RPCs that raise per row (not_allowed / meetup_not_found are part of the contract).
CREATE FUNCTION pg_temp.card(p uuid) RETURNS text LANGUAGE plpgsql AS $$
BEGIN RETURN public.rpc_meetup_card(p)::text;
EXCEPTION WHEN OTHERS THEN RETURN 'ERR ' || SQLSTATE || ' ' || SQLERRM; END $$;
CREATE FUNCTION pg_temp.att(p uuid, s text, l int, o int) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN SELECT string_agg(a::text, ';' ORDER BY rn) INTO v FROM (SELECT row_number() OVER () rn, a FROM public.rpc_meetup_attendees(p, s, l, o) a) x;
  RETURN coalesce(v, '<none>');
EXCEPTION WHEN OTHERS THEN RETURN 'ERR ' || SQLSTATE || ' ' || SQLERRM; END $$;
GRANT EXECUTE ON FUNCTION pg_temp.card(uuid), pg_temp.att(uuid, text, int, int) TO anon, authenticated, service_role;

INSERT INTO snap SELECT c.reader, c.cs, a.actor, pg_temp.as_(a.role, a.uid, c.q) FROM cases c CROSS JOIN actors a;

SELECT reader || '|' || cs || '|' || actor || '|' || val FROM snap ORDER BY reader, cs, actor;
SELECT '#LINES ' || count(*) || ' ERR ' || count(*) FILTER (WHERE val LIKE 'ERR%') FROM snap;
ROLLBACK;

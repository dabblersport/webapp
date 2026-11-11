-- KAN-925 (KAN-714 stage R, KAN-866 follow-up): public.rpc_sport_overview(uuid,text) must not read any of the 22
-- games columns that KAN-866 removes. KAN-925 needs no migration: since B07
-- (20261104100700_kan714_b07_sport_overview_counts.sql:189-271) the function reads every shared column from
-- public.events (e.sport_id, e.is_cancelled, e.listing_visibility, e.start_at, e.creator_user_id, e.area_id), and
-- its only read of public.games is at :214-215, games_next7: count(DISTINCT g.id) FROM public.games g
-- JOIN public.events e ON e.id = g.event_id. This is the regression guard.
--
-- READ-ONLY. pgTAP. One transaction, ROLLBACK at the end; it writes nothing but session TEMP views.
-- pgTAP under plain psql exits 0 even on "not ok": read the TAP lines, or run it with pg_prove.
-- plpgsql records no pg_depend edges to the columns it reads, so the check is on prosrc: it finds the alias(es)
-- bound to public.games in the body and lists every <alias>.<column> reference. A bare column grep would be wrong:
-- the body legitimately reads e.start_at, e.sport_id and so on from public.events.
-- The md5 pins the body to B07; any redefinition fails S1 and must re-justify this guard.
--
-- Run (local throwaway Postgres with pgTAP loaded and the function built from B07 :189-272):
--   psql -X -v ON_ERROR_STOP=1 -d <throwaway db> -f supabase/tests/events_p4/kan714_r_rpc_sport_overview_test.sql
--
-- Read-only live check for Memphis (must return one row: body_md5 = e7eb361a30f342e9e98df7b944638787,
-- games_cols = {event_id,id}, removed_cols = {}, prosecdef = t, provolatile = s,
-- proconfig = {"search_path=public, pg_temp"}):
--   WITH f AS (SELECT p.* FROM pg_proc p WHERE p.oid = 'public.rpc_sport_overview(uuid,text)'::regprocedure),
--        al AS (SELECT DISTINCT lower(m[1]) AS a FROM f,
--                 regexp_matches(f.prosrc, 'public\.games\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') m),
--        c AS (SELECT DISTINCT lower(m[1]) AS col FROM f, al,
--                regexp_matches(f.prosrc, '\m' || al.a || '\.([a-z_][a-z0-9_]*)', 'gi') m)
--   SELECT md5(f.prosrc) AS body_md5,
--          (SELECT array_agg(col ORDER BY col) FROM c) AS games_cols,
--          (SELECT coalesce(array_agg(col ORDER BY col), '{}') FROM c
--            WHERE col = ANY ('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
--                               join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,
--                               geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,
--                               created_at,updated_at}')) AS removed_cols,
--          f.prosecdef, f.provolatile, f.proconfig
--     FROM f;
\set ON_ERROR_STOP 1
BEGIN;
SELECT plan(10);

CREATE TEMP VIEW k925_removed (col) AS
  SELECT unnest('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                  join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                  venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]);

CREATE TEMP VIEW k925_fn AS
  SELECT p.* FROM pg_proc p WHERE p.oid = to_regprocedure('public.rpc_sport_overview(uuid,text)');

-- Aliases bound to public.games in the body ("public.games g", "public.games AS g").
CREATE TEMP VIEW k925_alias (a) AS
  SELECT DISTINCT lower(m[1])
    FROM k925_fn f, regexp_matches(f.prosrc, 'public\.games\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') m;

-- Every <games alias>.<column> the body references.
CREATE TEMP VIEW k925_cols (col) AS
  SELECT DISTINCT lower(m[1])
    FROM k925_fn f, k925_alias al, regexp_matches(f.prosrc, '\m' || al.a || '\.([a-z_][a-z0-9_]*)', 'gi') m;

SELECT has_function('public', 'rpc_sport_overview', ARRAY['uuid', 'text'],
  'S0 public.rpc_sport_overview(uuid,text) exists');

SELECT is((SELECT md5(prosrc) FROM k925_fn), 'e7eb361a30f342e9e98df7b944638787',
  'S1 rpc_sport_overview body is the B07 body (20261104100700:189-272)');

SELECT is((SELECT count(DISTINCT col)::int FROM k925_removed), 22,
  'S2 the KAN-866 list holds 22 distinct column names');

-- Sanity: the alias probe finds the games alias, so an empty intersection below is not vacuous.
SELECT set_eq('SELECT a FROM k925_alias', ARRAY['g'],
  'S3 sanity: the body binds exactly one alias to public.games, g');

SELECT ok(EXISTS (SELECT 1 FROM k925_cols WHERE col = 'event_id'),
  'S4 sanity: the column probe sees g.event_id');

SELECT is_empty(
  $$SELECT col FROM k925_cols WHERE col IN (SELECT col FROM k925_removed) ORDER BY col$$,
  'S5 KAN-925: rpc_sport_overview reads none of the 22 KAN-866 games columns through games');

SELECT set_eq('SELECT col FROM k925_cols', ARRAY['event_id', 'id'],
  'S6 the only games columns rpc_sport_overview reads are id and event_id');

SELECT ok((SELECT prosecdef FROM k925_fn), 'S7 rpc_sport_overview is still SECURITY DEFINER');

SELECT is((SELECT provolatile::text FROM k925_fn), 's', 'S8 rpc_sport_overview is still STABLE');

SELECT is((SELECT proconfig FROM k925_fn), ARRAY['search_path=public, pg_temp'],
  'S9 rpc_sport_overview search_path is still public, pg_temp');

SELECT * FROM finish();
ROLLBACK;

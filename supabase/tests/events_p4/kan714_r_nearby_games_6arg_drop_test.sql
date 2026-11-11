-- KAN-910 (KAN-714 chain stage R): 20261111121200_kan714_r_nearby_games_6arg_drop.sql drops exactly
-- public.nearby_games(double precision, double precision, integer, text, integer, integer) and nothing else.
--
-- pgTAP. One transaction, ROLLBACK at the end: the migration is applied INSIDE this transaction (\ir below) and
-- rolled back with it, so the database is left as it was. pgTAP under plain psql exits 0 even on "not ok": read
-- the TAP lines, or run it with pg_prove.
-- LOCAL THROWAWAY POSTGRES ONLY. It refuses a database that has the Supabase "storage" or "supabase_functions"
-- schema. Never run it against a remote project.
--
-- Run (database with pgTAP loaded, the 6-arg nearby_games and the rpc_get_nearby_games family installed from the
-- repo's latest definitions, check_function_bodies off for the install):
--   psql -X -v ON_ERROR_STOP=1 -d <throwaway db> -f supabase/tests/events_p4/kan714_r_nearby_games_6arg_drop_test.sql
-- RED control: -v mig=/dev/null applies nothing in place of the migration; T4-T6 must fail (T7 holds either way).
--
-- Tests
--   BEFORE the migration
--     T1 the 6-arg nearby_games exists.
--     T2 its md5(prosrc) is one of the two bodies the migration's guard accepts (baseline / 20261105110000).
--     T3 sanity: the snapshot of the OTHER *nearby_games* functions is not empty and holds the app's
--        rpc_get_nearby_games(..., numeric), so the "untouched" check below is not vacuous.
--   (migration applied)
--   AFTER
--     T4 the 6-arg nearby_games is absent.
--     T5 no function named nearby_games remains under any signature (the 6-arg was the only overload).
--     T6 every other public function whose name contains nearby_games has the same oid, signature, md5(prosrc)
--        and proacl as before (set equality, both directions).
--     T7 rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric) keeps its oid.
\set ON_ERROR_STOP 1

DO $local$ BEGIN
  IF to_regnamespace('storage') IS NOT NULL OR to_regnamespace('supabase_functions') IS NOT NULL THEN
    RAISE EXCEPTION 'kan714_r_nearby_games_6arg_drop_test: refusing to run on what looks like a Supabase database';
  END IF;
END $local$;

BEGIN;
SELECT plan(7);

CREATE TEMP TABLE k910_before AS
  SELECT p.oid, p.oid::regprocedure::text AS sig, md5(p.prosrc) AS h, coalesce(p.proacl::text, '') AS acl
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname LIKE '%nearby\_games%'
     AND p.oid IS DISTINCT FROM
         to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)');

SELECT has_function('public', 'nearby_games',
  ARRAY['double precision','double precision','integer','text','integer','integer'],
  'T1 before: public.nearby_games 6-arg exists');

SELECT ok((SELECT md5(prosrc) FROM pg_proc
            WHERE oid = to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)'))
          IN ('19b0a6c0ce028c4273f46ece71713d9a', '4132dec168331c547f299f1cccd04804'),
  'T2 before: 6-arg md5(prosrc) is a body the drift guard accepts');

SELECT ok((SELECT count(*) FROM k910_before) > 0
          AND EXISTS (SELECT 1 FROM k910_before
                       WHERE sig = 'rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'),
  'T3 sanity: other *nearby_games* functions snapshotted, including rpc_get_nearby_games(..., numeric)');

-- Apply the migration in this transaction.
\if :{?mig}
\i :mig
\else
\ir ../../migrations/20261111121200_kan714_r_nearby_games_6arg_drop.sql
\endif

SELECT hasnt_function('public', 'nearby_games',
  ARRAY['double precision','double precision','integer','text','integer','integer'],
  'T4 after: public.nearby_games 6-arg is absent');

SELECT is((SELECT count(*)::int FROM pg_proc
            WHERE pronamespace = 'public'::regnamespace AND proname = 'nearby_games'), 0,
  'T5 after: no public.nearby_games under any signature');

SELECT set_eq(
  $$SELECT p.oid, p.oid::regprocedure::text AS sig, md5(p.prosrc) AS h, coalesce(p.proacl::text, '') AS acl
      FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE '%nearby\_games%'$$,
  $$SELECT oid, sig, h, acl FROM k910_before$$,
  'T6 after: every other *nearby_games* function is untouched (oid, signature, md5(prosrc), proacl)');

SELECT is(to_regprocedure('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'),
          (SELECT oid::regprocedure FROM k910_before
            WHERE sig = 'rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'),
  'T7 after: rpc_get_nearby_games(..., numeric) keeps its oid');

SELECT * FROM finish();
ROLLBACK;

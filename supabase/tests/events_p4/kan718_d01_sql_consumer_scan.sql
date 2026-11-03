-- KAN-769 (KAN-718 D01, Epic KAN-708, Events P4) — SQL consumer scan for the slated legacy columns.
--
-- Companion: supabase/tests/events_p4/KAN718_D01_SQL_CONSUMERS.md (verdict table and reasoning).
-- Evidence only. No migration, no fix. Nothing persists in either mode.
--
-- SLATED SET. No exact KAN-718 drop list exists in the repository. The set is DERIVED from the KAN-734 (B15)
-- shared-column token list (kan714_b15_coverage_probe.sql, k734_shared), intersected with the columns that
-- actually exist on public.games / public.meetups in the database being scanned. On the local build that is
-- 21 games columns + 19 meetups columns = 40 (table, column) pairs.
--
-- Modes (psql -v mode=...):
--   scan  (default)  READ ONLY transaction, catalogue SELECTs only, no temp objects, ends in ROLLBACK.
--                    Prints one verdict row per slated column. This is the form ops may run read-only on
--                    production later; it has NOT been run there (production is read-only to this seat and
--                    a hook refuses execute_sql). It asserts nothing.
--   test             LOCAL throwaway databases only: refuses unless current_database() starts with
--                    'kan769' or 'k769'. Runs negative controls (planted consumers must be detected, an
--                    events-only reader must not be), asserts the local catalogue verdicts and the B15
--                    anchors, then the seed scenario S1-S5. Ends with NOTICE 'KAN-769 PROBE ALL PASS'.
--
-- What counts as a consumer of (table, column), per detection path:
--   pg_depend   exact: views (pg_rewrite), triggers (UPDATE OF / WHEN), RLS policies, constraints, indexes,
--               generated/default expressions of OTHER columns, SQL-standard function bodies, publication
--               column lists, extended statistics. deptype 'n' blocks a plain DROP COLUMN; 'a' is dropped with it.
--   alias       plpgsql/sql body: <alias>.<column> where <alias> binds that table (FROM games g, g games%rowtype,
--               public.games.<column>). Textual (same heuristic as B15 C6, made table-aware).
--   new/old     a trigger function attached to that table reading NEW.<column> / OLD.<column>.
--   whole-row   %rowtype, NULL::games, SELECT * [INTO x] FROM games, games.*, to_jsonb(NEW)/row_to_json(NEW)
--               in a trigger function on that table, a table-typed argument/result, a column typed as the
--               table's row type, a view with a whole-row dependency. Counted for every column of the table.
--   dynamic     a body that uses EXECUTE and names the table. Cannot be resolved; counted for every column.
--   loose       body names the table and the bare column word appears unqualified. Heuristic and noisy
--               (over-reports, never under-reports what it covers); counted, labelled, never a "retired" proof.
--   transitive  (reported, not in the verdict count) functions that call a direct function consumer up to depth 3,
--               triggers that execute one, views/policies that call one (pg_depend on pg_proc).
-- Not covered (see the .md): edge functions, Dart/web clients (PostgREST selects), realtime subscribers,
-- objects in pg_catalog/information_schema, languages other than plpgsql/sql, SQL built outside function bodies.
\set ON_ERROR_STOP 1
\if :{?mode}
\else
\set mode scan
\endif
SELECT (:'mode' = 'test') AS k769_test, (:'mode' NOT IN ('scan', 'test')) AS k769_badmode \gset
\if :k769_badmode
DO $$ BEGIN RAISE EXCEPTION 'KAN-769: unknown mode (use scan or test)'; END $$;
\endif

\if :k769_test
DO $g$ BEGIN
  IF current_database() !~ '^(kan769|k769)' THEN
    RAISE EXCEPTION 'KAN-769: test mode writes (rolled back) and runs only on a local throwaway database named kan769*/k769*; got %', current_database();
  END IF;
END $g$;
\set k769_into 'CREATE TEMP TABLE k769_v AS'
-- shapes and fingerprints recorded before anything runs (temp, session-local)
CREATE TEMP TABLE k769_shape0 AS
SELECT c.relname::text AS rel, string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) AS shape
  FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
 WHERE c.relnamespace = 'public'::regnamespace AND c.relname IN ('games', 'meetups', 'events', 'v_game_card', 'v_meetup_list', 'v_my_games')
 GROUP BY 1;
CREATE TEMP TABLE k769_fp AS
SELECT (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) g,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) m,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) e;
GRANT SELECT ON k769_fp, k769_shape0 TO PUBLIC;
BEGIN;
-- Negative controls, planted inside a transaction that is rolled back. The detector must fire on N1-N3, N5, N6
-- and must NOT fire on N4.
CREATE FUNCTION public.k769_neg_reader() RETURNS timestamptz LANGUAGE plpgsql AS $n$
BEGIN RETURN (SELECT g.start_at FROM public.games g ORDER BY g.id LIMIT 1); END $n$;                 -- N1 alias read
CREATE VIEW public.k769_neg_view AS SELECT m.id, m.capacity FROM public.meetups m;                     -- N2 view dep
CREATE POLICY k769_neg_pol ON public.games AS RESTRICTIVE FOR SELECT TO PUBLIC USING (cost_cover IS NOT NULL OR true); -- N3 policy
CREATE FUNCTION public.k769_neg_events() RETURNS timestamptz LANGUAGE plpgsql AS $n$
BEGIN RETURN (SELECT e.start_at FROM public.events e ORDER BY e.id LIMIT 1); END $n$;                -- N4 events-only: must NOT flag
CREATE FUNCTION public.k769_neg_caller() RETURNS timestamptz LANGUAGE sql AS $n$
SELECT public.k769_neg_reader() $n$;                                                                  -- N5 transitive
CREATE FUNCTION public.k769_neg_dyn() RETURNS bigint LANGUAGE plpgsql AS $n$
DECLARE n bigint; BEGIN EXECUTE 'SELECT count(*) FROM public.' || 'games' INTO n; RETURN n; END $n$;  -- N6 dynamic
\else
\set k769_into ''
BEGIN TRANSACTION READ ONLY;
\endif

:k769_into
WITH RECURSIVE
slated AS (
  SELECT c.oid AS tbl, c.relname::text AS t, a.attnum, a.attname::text AS col, c.reltype
    FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
   WHERE c.oid IN (to_regclass('public.games'), to_regclass('public.meetups'))
     AND a.attname = ANY (ARRAY['title','creator_profile_id','creator_user_id','start_at','end_at','capacity',
       'listing_visibility','join_policy','rsvp_policy','min_skill','max_skill','is_cancelled','cancelled_at','cancelled_reason',
       'sport_id','geo_location_id','area_id','venue_id','joining_rule','cost_cover','request_id','search_tsv'])),
tbls AS (SELECT DISTINCT tbl, t, reltype FROM slated),
fn AS (
  SELECT p.oid, p.oid::regprocedure::text AS ident, p.proname::text AS name,
         regexp_replace(coalesce(p.prosrc, ''), '--[^\n]*', '', 'g') AS src
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_language l ON l.oid = p.prolang
   WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND n.nspname !~ '^pg_toast' AND l.lanname IN ('plpgsql', 'sql')),
al AS (
  SELECT f.oid, lower(m[1]) AS t, lower(m[2]) AS a
    FROM fn f, regexp_matches(f.src, '\m(?:public\.)?(games|meetups)\s+(?:as\s+)?([A-Za-z_][A-Za-z0-9_]*)', 'gi') m
   WHERE lower(m[2]) NOT IN ('where','on','join','left','right','inner','set','using','for','order','group','limit','union','returning','select',
     'values','when','then','and','or','as','cross','full','natural','lateral','into','except','having','window','offset','fetch','default','loop','is')
  UNION SELECT f.oid, lower(m[2]), lower(m[1]) FROM fn f, regexp_matches(f.src, '\m([A-Za-z_][A-Za-z0-9_]*)\s+(?:public\.)?(games|meetups)(?:%rowtype)?\s*;', 'gi') m
  UNION SELECT f.oid, lower(m[1]), lower(m[1]) FROM fn f, regexp_matches(f.src, '\m(?:public\.)?(games|meetups)\.', 'gi') m),
direct AS (
  -- pg_depend (exact)
  SELECT s.t, s.col,
         CASE d.classid WHEN 'pg_rewrite'::regclass THEN 'view' WHEN 'pg_trigger'::regclass THEN 'trigger'
           WHEN 'pg_policy'::regclass THEN 'policy' WHEN 'pg_constraint'::regclass THEN 'constraint'
           WHEN 'pg_class'::regclass THEN 'index' WHEN 'pg_attrdef'::regclass THEN 'default/generated'
           WHEN 'pg_proc'::regclass THEN 'function' WHEN 'pg_publication_rel'::regclass THEN 'publication'
           ELSE d.classid::regclass::text END AS kind,
         CASE WHEN d.classid = 'pg_proc'::regclass THEN d.objid::regprocedure::text
              ELSE pg_describe_object(d.classid, d.objid, d.objsubid) END AS ident,
         'pg_depend:' || d.deptype::text AS how
    FROM pg_depend d JOIN slated s ON d.refclassid = 'pg_class'::regclass AND d.refobjid = s.tbl AND d.refobjsubid = s.attnum
   WHERE NOT (d.classid = 'pg_attrdef'::regclass AND (SELECT ad.adnum FROM pg_attrdef ad WHERE ad.oid = d.objid) = s.attnum)
  UNION
  -- publication column lists, read directly as well (PG15+)
  SELECT s.t, s.col, 'publication', pg_describe_object('pg_publication_rel'::regclass, pr.oid, 0), 'prattrs'
    FROM pg_publication_rel pr JOIN slated s ON pr.prrelid = s.tbl AND s.attnum = ANY (pr.prattrs::int2[])
  UNION
  -- alias.column in a function body
  SELECT s.t, s.col, 'function', f.ident, 'alias'
    FROM al a JOIN fn f ON f.oid = a.oid JOIN slated s ON s.t = a.t
   WHERE f.src ~* ('\m' || a.a || '\.' || s.col || '\M')
  UNION
  -- NEW/OLD.column in a trigger function attached to the table
  SELECT s.t, s.col, 'function', f.ident, 'new/old'
    FROM pg_trigger tg JOIN fn f ON f.oid = tg.tgfoid JOIN slated s ON s.tbl = tg.tgrelid
   WHERE NOT tg.tgisinternal AND f.src ~* ('\m(new|old)\.' || s.col || '\M')
  UNION
  -- whole-row use in a body
  SELECT s.t, s.col, 'function', f.ident, 'whole-row'
    FROM fn f JOIN slated s ON f.src ~* ('\m(public\.)?' || s.t || '%rowtype')
      OR f.src ~* ('null::(public\.)?' || s.t || '\M') OR f.src ~* ('\m(public\.)?' || s.t || '\.\*')
      OR f.src ~* ('\mselect\s+\*\s+(into\s+[A-Za-z_][A-Za-z0-9_]*\s+)?from\s+(public\.)?' || s.t || '\M')
  UNION
  SELECT s.t, s.col, 'function', f.ident, 'whole-row NEW/OLD'
    FROM pg_trigger tg JOIN fn f ON f.oid = tg.tgfoid JOIN slated s ON s.tbl = tg.tgrelid
   WHERE NOT tg.tgisinternal AND (f.src ~* '(to_jsonb|to_json|row_to_json|hstore|jsonb_populate_record|json_populate_record)\s*\(\s*(new|old)\M'
                                  OR f.src ~* '\m(new|old)\.\*')
  UNION
  -- table-typed signature, table-typed column, whole-row view dependency
  SELECT s.t, s.col, 'composite', p.oid::regprocedure::text || ' -> ' || pg_get_function_result(p.oid), 'signature'
    FROM pg_proc p JOIN slated s ON p.prorettype = s.reltype OR s.reltype = ANY (p.proargtypes::oid[]) OR s.reltype = ANY (coalesce(p.proallargtypes, '{}'))
  UNION
  SELECT s.t, s.col, 'composite', a.attrelid::regclass || '.' || a.attname, 'typed column'
    FROM pg_attribute a JOIN slated s ON a.atttypid = s.reltype WHERE NOT a.attisdropped
  UNION
  SELECT s.t, s.col, 'view', pg_describe_object(d.classid, d.objid, 0), 'whole-row pg_depend'
    FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid JOIN slated s ON d.refobjid = s.tbl
   WHERE d.classid = 'pg_rewrite'::regclass AND d.refobjsubid = 0 AND r.ev_class <> d.refobjid
  UNION
  -- a view or policy that passes a whole row of the table to a table-typed function (pg_depend records no
  -- column dependency for that; kan711_events_parity is the local case)
  SELECT s.t, s.col, CASE dp.classid WHEN 'pg_rewrite'::regclass THEN 'view' ELSE 'policy' END,
         pg_describe_object(dp.classid, dp.objid, 0), 'whole-row arg to ' || p.proname
    FROM pg_depend dp JOIN pg_proc p ON dp.refclassid = 'pg_proc'::regclass AND dp.refobjid = p.oid
    JOIN slated s ON s.reltype = ANY (p.proargtypes::oid[])
   WHERE dp.classid IN ('pg_rewrite'::regclass, 'pg_policy'::regclass)
  UNION
  -- dynamic SQL in a body that names the table
  SELECT s.t, s.col, 'function', f.ident, 'dynamic'
    FROM fn f JOIN slated s ON f.src ~* '\mexecute\M' AND f.src ~* ('\m' || s.t || '\M')
  UNION
  -- loose: body names the table and the bare (unqualified) column word appears
  SELECT s.t, s.col, 'function', f.ident, 'loose'
    FROM fn f JOIN slated s ON f.src ~* ('\m(public\.)?' || s.t || '\M(?!\s*\()') AND f.src ~* ('(?<![.A-Za-z0-9_])' || s.col || '\M')),
d1 AS (  -- one row per (column, object), how-list merged
  SELECT t, col, kind, ident, string_agg(DISTINCT how, '+' ORDER BY how) AS how,
         bool_and(how = 'loose') AS loose_only
    FROM direct GROUP BY 1, 2, 3, 4),
dfn AS (SELECT DISTINCT d.t, d.col, f.oid, f.name FROM d1 d JOIN fn f ON f.ident = split_part(d.ident, ' -> ', 1)
            WHERE d.kind IN ('function', 'composite') AND NOT d.loose_only),
calls AS (
  SELECT DISTINCT cr.oid AS caller, ce.oid AS callee
    FROM fn cr JOIN fn ce ON cr.oid <> ce.oid AND position(ce.name IN cr.src) > 0 AND cr.src ~* ('\m' || ce.name || '\s*\(')),
tr(t, col, oid, depth, via) AS (
  SELECT d.t, d.col, c.caller, 1, d.name FROM dfn d JOIN calls c ON c.callee = d.oid
  UNION
  SELECT tr.t, tr.col, c.caller, tr.depth + 1, tr.via FROM tr JOIN calls c ON c.callee = tr.oid WHERE tr.depth < 3),
trans AS (
  SELECT tr.t, tr.col, f.ident || ' (calls ' || tr.via || ')' AS ident
    FROM tr JOIN fn f ON f.oid = tr.oid
   WHERE NOT EXISTS (SELECT 1 FROM d1 WHERE d1.t = tr.t AND d1.col = tr.col AND d1.ident = f.ident)
  UNION
  SELECT d.t, d.col, pg_describe_object('pg_trigger'::regclass, tg.oid, 0) || ' executes ' || d.name
    FROM dfn d JOIN pg_trigger tg ON tg.tgfoid = d.oid AND NOT tg.tgisinternal
  UNION
  SELECT d.t, d.col, pg_describe_object(dp.classid, dp.objid, 0) || ' calls ' || d.name
    FROM dfn d JOIN pg_depend dp ON dp.refclassid = 'pg_proc'::regclass AND dp.refobjid = d.oid
   WHERE dp.classid IN ('pg_rewrite'::regclass, 'pg_policy'::regclass))
SELECT s.t, s.col,
       CASE WHEN count(d1.ident) = 0 THEN 'no-remaining-consumer' ELSE 'pending' END AS verdict,
       count(d1.ident) AS n_direct,
       count(d1.ident) FILTER (WHERE d1.kind = 'view') AS n_view,
       count(d1.ident) FILTER (WHERE d1.kind = 'trigger') AS n_trigger,
       count(d1.ident) FILTER (WHERE d1.kind = 'policy') AS n_policy,
       count(d1.ident) FILTER (WHERE d1.kind = 'function' AND NOT d1.loose_only) AS n_function,
       count(d1.ident) FILTER (WHERE d1.loose_only) AS n_loose,
       count(d1.ident) FILTER (WHERE d1.kind NOT IN ('view', 'trigger', 'policy', 'function')) AS n_other,
       (SELECT count(*) FROM trans x WHERE x.t = s.t AND x.col = s.col) AS n_transitive,
       coalesce(string_agg(d1.kind || ':' || d1.ident || ' [' || d1.how || ']', ' ; ' ORDER BY d1.kind, d1.ident), '') AS direct,
       coalesce((SELECT string_agg(x.ident, ' ; ' ORDER BY x.ident) FROM trans x WHERE x.t = s.t AND x.col = s.col), '') AS transitive
  FROM slated s LEFT JOIN d1 ON d1.t = s.t AND d1.col = s.col
 GROUP BY s.t, s.col
 ORDER BY s.t, s.col;

\if :k769_test
DO $c$
DECLARE
  v text; n int;
  -- B15 (KAN-734) C6 residual set, C7 rowtype set, C8 composite set, C10 dynamic set, verbatim from
  -- events_p2/kan714_b15_coverage_probe.sql. D01 must find every one of them as a direct consumer.
  b15 text[] := ARRAY['_can_view_game(uuid)', '_can_view_game_for_join(uuid)', '_is_game_host(uuid)',
    '_slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)', '_user_hosted_game(uuid,uuid)',
    'active_stream(text[],text,integer,timestamp with time zone,text,uuid)', 'can_current_user_join_game(uuid,text,uuid)',
    'can_current_user_rsvp_meetup(uuid,uuid)', 'fn_generate_game_series_occurrences(uuid)', 'game_slots_left(uuid)',
    'kan712_events_compat_mirror()', 'meetup_counts(uuid)', 'rpc_get_activity_feed(text,integer,timestamp with time zone)',
    'rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', 'rpc_meetup_cancel(uuid)',
    -- rpc_meetup_my(): RETIRED by KAN-785 (migration 20261104110400); removed from B15 C6, so no longer an anchor (30 -> 29).
    'rpc_rate_game(uuid,uuid,jsonb,text)', 'rpc_rate_user(uuid,uuid,uuid,jsonb,text)', 'rpc_rate_venue(uuid,uuid,uuid,jsonb,text)',
    'rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)',
    'rpc_edit_game_series_future(uuid,text,integer,time without time zone,integer,uuid,date,boolean)',
    'rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)',
    'rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)',
    'rpc_meetup_update(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)',
    'rpc_update_game(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)',
    'rpc_update_game_legacy_v1(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer)',
    'kan711_events_map_game(games)', 'kan711_events_map_meetup(meetups)',
    'admin_cleanup_user_data(uuid,boolean)', 'kan711_events_backfill_batch(text,integer)'];
  b text;
BEGIN
  -- N1-N6 negative controls (planted objects exist only in this rolled-back transaction)
  IF NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'games' AND col = 'start_at' AND direct LIKE '%function:k769_neg_reader() [alias]%') THEN
    RAISE EXCEPTION 'KAN-769 N1 FAIL: planted alias reader of games.start_at not detected'; END IF;
  IF NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'meetups' AND col = 'capacity' AND direct LIKE '%view:rule _RETURN on view k769_neg_view [pg_depend:n]%') THEN
    RAISE EXCEPTION 'KAN-769 N2 FAIL: planted view on meetups.capacity not detected'; END IF;
  IF NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'games' AND col = 'cost_cover' AND direct LIKE '%policy:policy k769_neg_pol on table games%') THEN
    RAISE EXCEPTION 'KAN-769 N3 FAIL: planted RLS policy on games.cost_cover not detected'; END IF;
  IF EXISTS (SELECT 1 FROM k769_v WHERE direct LIKE '%k769_neg_events()%' OR transitive LIKE '%k769_neg_events()%') THEN
    RAISE EXCEPTION 'KAN-769 N4 FAIL: an events-only reader was flagged as a legacy consumer (false positive)'; END IF;
  IF NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'games' AND col = 'start_at' AND transitive LIKE '%k769_neg_caller() (calls k769_neg_reader)%') THEN
    RAISE EXCEPTION 'KAN-769 N5 FAIL: transitive caller of the planted reader not detected'; END IF;
  IF NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'games' AND col = 'capacity' AND direct LIKE '%function:k769_neg_dyn() [dynamic]%') THEN
    RAISE EXCEPTION 'KAN-769 N6 FAIL: planted dynamic-SQL reader of games not detected'; END IF;
  RAISE NOTICE 'KAN-769 N1-N6 PASS: planted alias reader, view, RLS policy, transitive caller and dynamic reader detected; events-only reader not flagged';

  -- V1 the slated set is the derived 40 pairs (21 games + 19 meetups)
  SELECT count(*) INTO n FROM k769_v;
  IF n <> 40 OR (SELECT count(*) FROM k769_v WHERE t = 'games') <> 21 THEN
    RAISE EXCEPTION 'KAN-769 V1 FAIL: slated set has % pairs (expected 40 = 21 games + 19 meetups)', n; END IF;
  RAISE NOTICE 'KAN-769 V1 PASS: 40 slated (table, column) pairs derived from the B15 shared set';

  -- V2 every B15 consumer is still found (D01 is a superset of B15's residual/rowtype/composite/dynamic sets)
  FOREACH b IN ARRAY b15 LOOP
    -- a KAN-712-wrapped RPC is found through its _kan712_inner body (B15 used the same effective-body rule)
    IF NOT EXISTS (SELECT 1 FROM k769_v WHERE direct LIKE '%:' || b || '%' OR direct LIKE '%:' || regexp_replace(b, '\(', '_kan712_inner(') || '%') THEN
      RAISE EXCEPTION 'KAN-769 V2 FAIL: B15 consumer % not found by the D01 scan', b; END IF;
  END LOOP;
  RAISE NOTICE 'KAN-769 V2 PASS: all % B15 anchors (C6 residual, C7 rowtype, C8 composite, C10 dynamic) found', array_length(b15, 1);

  -- V3 the KAN-711 parity view, the KAN-712 compat mirror and the KAN-716 publication consume shared columns
  IF NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'games' AND col = 'start_at' AND direct LIKE '%view kan711_events_parity%')
     OR NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'meetups' AND col = 'title' AND direct LIKE '%kan712_events_compat_mirror()%')
     OR NOT EXISTS (SELECT 1 FROM k769_v WHERE t = 'games' AND col = 'start_at' AND direct LIKE '%publication:%supabase_realtime%') THEN
    RAISE EXCEPTION 'KAN-769 V3 FAIL: an infrastructure anchor (parity view / compat mirror / realtime column list) is missing'; END IF;
  RAISE NOTICE 'KAN-769 V3 PASS: parity view, compat mirror and realtime publication column list are consumers';

  -- V4 local verdict: every slated column is pending (none may be reported retired)
  SELECT string_agg(t || '.' || col, ' ') INTO v FROM k769_v WHERE verdict <> 'pending';
  IF v IS NOT NULL THEN RAISE EXCEPTION 'KAN-769 V4 FAIL: column(s) with no detected consumer on the local build: %', v; END IF;
  SELECT min(n_direct - n_loose) INTO n FROM k769_v;
  IF n < 1 THEN RAISE EXCEPTION 'KAN-769 V4 FAIL: a column is pending on loose matches only'; END IF;
  RAISE NOTICE 'KAN-769 V4 PASS: 40/40 pending; every column has >= % non-heuristic consumer(s); direct total %, transitive total %',
    n, (SELECT sum(n_direct) FROM k769_v), (SELECT sum(n_transitive) FROM k769_v);
END $c$;
ROLLBACK;

DO $z$ BEGIN
  IF to_regprocedure('public.k769_neg_reader()') IS NOT NULL OR to_regclass('public.k769_neg_view') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'k769_neg_pol') THEN
    RAISE EXCEPTION 'KAN-769 N0 FAIL: planted negative-control objects survived ROLLBACK'; END IF;
  RAISE NOTICE 'KAN-769 N0 PASS: planted objects gone after ROLLBACK';
END $z$;

-- ---------------------------------------------------------------------------------------------
-- Scenario S1-S5: one game + one meetup through the ordinary legacy INSERT path, read back through the
-- legacy-shaped surfaces as owner, stranger, blocked user and anon. Everything rolls back.
-- ---------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.k769_as(p_uid uuid, p_sql text) RETURNS bigint LANGUAGE plpgsql AS $f$
DECLARE n bigint; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
  EXECUTE 'SET LOCAL ROLE ' || CASE WHEN p_uid IS NULL THEN 'anon' ELSE 'authenticated' END;
  EXECUTE p_sql INTO n;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN n; END $f$;
CREATE FUNCTION pg_temp.k769_shape_diff() RETURNS text LANGUAGE sql AS $f$
  SELECT string_agg(s.rel, ' ') FROM k769_shape0 s
   WHERE s.shape IS DISTINCT FROM (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
                                     FROM pg_attribute a WHERE a.attrelid = ('public.' || s.rel)::regclass AND a.attnum > 0 AND NOT a.attisdropped) $f$;

BEGIN;
DO $s$
DECLARE
  stranger uuid := '00000000-0000-0000-0000-00000000dead';
  blocked  uuid := '00000000-0000-0000-0000-0000000000a6';
  owner    uuid := '00000000-0000-0000-0000-0000000000a1';
  gid uuid := '76900000-0000-0000-0000-000000000001';
  mid uuid := '76900000-0000-0000-0000-00000000f001';
  q_gc text := $q$SELECT count(*) FROM public.v_game_card$q$;
  q_ml text := $q$SELECT count(*) FROM public.v_meetup_list$q$;
  q_gn text := $q$SELECT count(*) FROM public.v_game_card WHERE id::text LIKE '76900000%'$q$;
  q_mn text := $q$SELECT count(*) FROM public.v_meetup_list WHERE id::text LIKE '76900000%'$q$;
  q_my text := $q$SELECT count(*) FROM public.v_my_games WHERE id::text LIKE '76900000%'$q$;
  q_dup text := $q$SELECT (SELECT count(*) - count(DISTINCT id) FROM public.v_game_card) + (SELECT count(*) - count(DISTINCT id) FROM public.v_meetup_list)$q$;
  b record; a record; x bigint; v text;
BEGIN
  SELECT pg_temp.k769_as(stranger, q_gc) s_gc, pg_temp.k769_as(blocked, q_gc) b_gc, pg_temp.k769_as(NULL, q_gc) n_gc,
         pg_temp.k769_as(stranger, q_ml) s_ml, pg_temp.k769_as(blocked, q_ml) b_ml, pg_temp.k769_as(NULL, q_ml) n_ml INTO b;

  -- S1 seed one game and one meetup through the legacy INSERT path
  INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, sport_id, geo_location_id, area_id, price_aed, min_skill, max_skill)
  VALUES (gid, 'D01 game', '00000000-0000-0000-0000-0000000000b1', owner, '2031-02-01T10:00:00+04', '2031-02-01T11:30:00+04', 10, 'public',
          '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 0, 1, 5);
  INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object('id', mid, 'event_id', NULL, 'request_id', NULL,
      'title', 'D01 meetup', 'start_at', '2031-02-03T10:00:00+04', 'end_at', NULL, 'listing_visibility', 'public'))).*
    FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';
  IF (SELECT count(*) FROM public.events WHERE id IN (gid, mid)) <> 2
     OR (SELECT event_id FROM public.games WHERE id = gid) IS DISTINCT FROM gid OR (SELECT event_id FROM public.meetups WHERE id = mid) IS DISTINCT FROM mid THEN
    RAISE EXCEPTION 'KAN-769 S1 FAIL: seed did not produce exactly one linked events parent per row'; END IF;
  RAISE NOTICE 'KAN-769 S1 PASS: 1 game + 1 meetup seeded through the legacy path; each has exactly one events parent, id kept';

  -- S2 legacy shapes unchanged: tables and legacy views keep their columns; seeded legacy values equal the parent
  v := pg_temp.k769_shape_diff();
  IF v IS NOT NULL THEN RAISE EXCEPTION 'KAN-769 S2 FAIL: shape changed: %', v; END IF;
  IF EXISTS (SELECT 1 FROM public.games g JOIN public.events e ON e.id = g.id WHERE g.id = gid
              AND (g.title, g.start_at, g.end_at, g.capacity, g.listing_visibility, g.creator_user_id)
                  IS DISTINCT FROM (e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.creator_user_id))
     OR EXISTS (SELECT 1 FROM public.meetups m JOIN public.events e ON e.id = m.id WHERE m.id = mid
              AND (m.title, m.start_at, m.end_at, m.capacity, m.listing_visibility, m.creator_user_id)
                  IS DISTINCT FROM (e.title, e.start_at, e.end_at, e.capacity, e.listing_visibility, e.creator_user_id)) THEN
    RAISE EXCEPTION 'KAN-769 S2 FAIL: seeded legacy value differs from its events parent'; END IF;
  RAISE NOTICE 'KAN-769 S2 PASS: % legacy shapes (games, meetups, events, v_game_card, v_meetup_list, v_my_games) unchanged; legacy values = parent', (SELECT count(*) FROM k769_shape0);

  -- S3 rows not doubled; counts equal legacy
  IF pg_temp.k769_as(stranger, q_dup) <> 0 OR pg_temp.k769_as(owner, q_dup) <> 0 THEN
    RAISE EXCEPTION 'KAN-769 S3 FAIL: duplicate ids in v_game_card/v_meetup_list'; END IF;
  IF (SELECT count(*) FROM public.events WHERE event_type = 'game') <> (SELECT count(*) FROM public.games)
     OR (SELECT count(*) FROM public.events WHERE event_type = 'meetup') <> (SELECT count(*) FROM public.meetups) THEN
    RAISE EXCEPTION 'KAN-769 S3 FAIL: events per type <> legacy row counts'; END IF;
  SELECT pg_temp.k769_as(stranger, q_gc) s_gc, pg_temp.k769_as(blocked, q_gc) b_gc, pg_temp.k769_as(NULL, q_gc) n_gc,
         pg_temp.k769_as(stranger, q_ml) s_ml, pg_temp.k769_as(blocked, q_ml) b_ml, pg_temp.k769_as(NULL, q_ml) n_ml INTO a;
  IF a.s_gc - b.s_gc <> 1 OR a.s_ml - b.s_ml <> 1 OR pg_temp.k769_as(owner, q_gn) <> 1 OR pg_temp.k769_as(owner, q_mn) <> 1
     OR pg_temp.k769_as(owner, q_my) <> 1 THEN
    RAISE EXCEPTION 'KAN-769 S3 FAIL: stranger delta game % meetup %, owner game % meetup % my % (expected 1 each)',
      a.s_gc - b.s_gc, a.s_ml - b.s_ml, pg_temp.k769_as(owner, q_gn), pg_temp.k769_as(owner, q_mn), pg_temp.k769_as(owner, q_my); END IF;
  RAISE NOTICE 'KAN-769 S3 PASS: no duplicate ids; events per type = legacy counts (% games, % meetups); stranger +1/+1, owner 1/1, v_my_games 1',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups);

  -- S4 non-owner and blocked user see nothing extra
  IF a.b_gc <> b.b_gc OR a.b_ml <> b.b_ml OR pg_temp.k769_as(blocked, q_gn) <> 0 OR pg_temp.k769_as(blocked, q_mn) <> 0
     OR pg_temp.k769_as(stranger, q_my) <> 0 OR pg_temp.k769_as(blocked, q_my) <> 0
     OR a.n_gc - b.n_gc > 1 OR a.n_ml - b.n_ml > 1 THEN
    RAISE EXCEPTION 'KAN-769 S4 FAIL: blocked/non-owner sees extra rows (blocked games %->%, meetups %->%)', b.b_gc, a.b_gc, b.b_ml, a.b_ml; END IF;
  RAISE NOTICE 'KAN-769 S4 PASS: user blocked by the owner sees neither new row; non-owners see none in v_my_games; anon at most the public rows';
END $s$;
ROLLBACK;

-- S5 rollback leaves data fingerprints and shapes intact
DO $r$ DECLARE v text; BEGIN
  IF (SELECT g FROM k769_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t)
     OR (SELECT m FROM k769_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t)
     OR (SELECT e FROM k769_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) THEN
    RAISE EXCEPTION 'KAN-769 S5 FAIL: games/meetups/events fingerprint changed after ROLLBACK'; END IF;
  v := pg_temp.k769_shape_diff();
  IF v IS NOT NULL THEN RAISE EXCEPTION 'KAN-769 S5 FAIL: shape changed after ROLLBACK: %', v; END IF;
  RAISE NOTICE 'KAN-769 S5 PASS: games/meetups/events md5 fingerprints and legacy shapes identical after ROLLBACK';
  RAISE NOTICE 'KAN-769 PROBE ALL PASS';
END $r$;
\else
ROLLBACK;
\endif

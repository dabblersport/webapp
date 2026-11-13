-- KAN-782 (KAN-719 Z05, Epic KAN-708): fallback-to-old-column inventory and the Z05 no-op proof.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY (the guard refuses a Supabase-shaped database and any DB not named k782*/kan782*).
--
-- WHAT IT PROVES. Z05 (supabase/migrations/20261105100100_kan719_z05_remove_fallbacks.sql) may remove only a
-- fallback that the KAN-781 Z04 postcheck shows is unused. A "fallback" here is code in a public function or view
-- that reads public.events AND a slated legacy games/meetups column (a column outside the D06 retained list):
--   HTP      an has_table_privilege('public.events','SELECT') switch whose ELSE branch reads the legacy column
--            (KAN-727 B08 / KAN-773 D04 "client fallback branch");
--   DUAL     an intersection read: legacy predicate AND the same predicate on events (KAN-713 "legacy conjunct");
--   COALESCE coalesce(e.x, g.x) / coalesce(g.x, e.x) style value fallback;
--   HELD     reads only a HARD homeless column (meetups.description/location_name/is_indoor, Z01 gate G6): no
--            events home exists, so it is not a fallback at all; listed so it cannot be mistaken for one.
-- Expected inventory on this chain (pre-Z01 and post-Z01-local alike): 6 HTP + 9 DUAL + 1 HELD + 0 COALESCE, every
-- one LIVE (EXECUTE granted to anon/authenticated/service_role). All 15 HTP/DUAL entries are KAN-781 S2 FAILs
-- (live functions reading removed columns) -> not removable here; owner kan714 parent reads (PM/cto). So the
-- removable set is EMPTY and Z05 must change nothing.
--
-- SECTIONS (each records PASS/FAIL lines; one summary line; raises on any FAIL):
--   MIG  applying Z05 changes no catalogue object and no row (fingerprint before = after, inside the transaction)
--   SHP  legacy shapes: games, meetups, kan718_games_compat, kan718_meetups_compat column names/order/types unchanged
--   CNT  counts: unchanged; no row doubled (count = count(distinct id)); compat = table; events = games + meetups
--   VIS  owner, stranger, blocked user, anon and service_role see the same id sets (tables + compat) after Z05
--   INV  the fallback inventory equals the expected list exactly (missing entry = a live fallback was removed;
--        extra entry = a fallback was (re)introduced); no COALESCE fallback exists
--   LIV  every inventory entry is LIVE; removable (not LIVE) set is empty; the HTP ELSE branch is the path a client
--        takes (authenticated has no events SELECT) and game_slots_left as authenticated proves it executes: an
--        integer pre-Z01, 42703 post-Z01 (the KAN-781 M4 finding)
--   R    after ROLLBACK the catalogue + data fingerprint equals the one taken before the run
--
-- Run (repository root):  psql -X -h <socket> -p <port> -U postgres -d k782... -v ON_ERROR_STOP=1 -P pager=off \
--      -v mig=supabase/migrations/20261105100100_kan719_z05_remove_fallbacks.sql -f supabase/tests/events_p4/kan719_z05_fallbacks.sql
\set ON_ERROR_STOP 1
SET client_min_messages = warning;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-782: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k782|kan782)' THEN
    RAISE EXCEPTION 'KAN-782: database % is not a KAN-782 throwaway database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-782: run as a superuser'; END IF;
END $g$;
\if :{?mig}
\else
  \echo 'KAN-782 Z05 TEST FAIL: -v mig=<path to the Z05 migration> is required'
  SELECT 1/0 AS kan782_no_mig;
\endif

-- Catalogue + data fingerprint (public functions with body/ACL, games/meetups/events columns, triggers, policies,
-- public relations, and the games/meetups/events rows).
CREATE FUNCTION pg_temp.k782_fp() RETURNS text LANGUAGE sql AS $f$
SELECT md5(concat_ws('#',
 (SELECT string_agg(p.oid::regprocedure::text || md5(pg_get_functiondef(p.oid)) || coalesce(p.proacl::text, ''), '|' ORDER BY 1)
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'),
 (SELECT string_agg(attrelid::regclass::text || '.' || attname || format_type(atttypid, atttypmod), ',' ORDER BY 1)
    FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped),
 (SELECT string_agg(tgrelid::regclass::text || tgname || tgenabled::text, ',' ORDER BY 1) FROM pg_trigger WHERE NOT tgisinternal),
 (SELECT string_agg(polname || coalesce(pg_get_expr(polqual, polrelid), ''), ',' ORDER BY 1) FROM pg_policy),
 (SELECT string_agg(relname || coalesce(relacl::text, ''), ',' ORDER BY 1) FROM pg_class WHERE relnamespace = 'public'::regnamespace),
 (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t),
 (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t),
 (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t)))
$f$;

-- p_sql (returning one text) as an API role; any error becomes 'ERR <sqlstate> <message>' (pattern of KAN-781).
CREATE FUNCTION pg_temp.k782_as(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; st text; m text; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN json_build_object('role', p_role)::text
                                                ELSE json_build_object('sub', p_uid, 'role', p_role)::text END, true);
  BEGIN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO r;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    RESET ROLE; r := 'ERR ' || st || ' ' || m;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN coalesce(r, '<null>'); END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.k782_as(text, uuid, text) TO anon, authenticated, service_role;

SELECT set_config('k782.fp0', pg_temp.k782_fp(), false) IS NOT NULL AS fp0_taken;

BEGIN;
CREATE TEMP TABLE k782_result(sec text, verdict text, detail text);
CREATE TEMP TABLE k782_who(label text, role text, uid uuid);
INSERT INTO k782_who VALUES
  ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'),
  ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'),
  ('blocked', 'authenticated', '00000000-0000-0000-0000-0000000000a6'),
  ('anon', 'anon', NULL),
  ('service_role', 'service_role', NULL);
GRANT SELECT ON k782_who TO anon, authenticated, service_role;

-- Slated legacy columns: every games/meetups column outside the D06 retained list (k774_retained). Constant, so the
-- inventory reads the same in the pre-Z01 state (columns present) and the post-Z01 state (columns absent).
CREATE TEMP TABLE k782_slated(tbl text, col text, held boolean DEFAULT false);
INSERT INTO k782_slated(tbl, col) SELECT 'games', unnest('{title,creator_profile_id,creator_user_id,start_at,end_at,capacity,listing_visibility,join_policy,min_skill,max_skill,is_cancelled,cancelled_at,cancelled_reason,created_at,updated_at,search_tsv,sport_id,geo_location_id,area_id,venue_id,joining_rule,cost_cover,request_id}'::text[])
UNION ALL SELECT 'meetups', unnest('{creator_profile_id,creator_user_id,title,description,listing_visibility,rsvp_policy,capacity,start_at,end_at,is_cancelled,created_at,updated_at,search_tsv,geo_location_id,sport_id,area_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,location_name,is_indoor,request_id}'::text[]);
UPDATE k782_slated SET held = true WHERE tbl = 'meetups' AND col IN ('description', 'location_name', 'is_indoor');

-- Expected inventory (sig, class). Every HTP/DUAL row is a KAN-781 S2 FAIL; owner kan714 parent reads (PM/cto).
CREATE TEMP TABLE k782_expected(sig text, cls text);
INSERT INTO k782_expected VALUES
  ('_can_view_game_for_join(uuid)', 'HTP'),
  ('_recent_activity_score(uuid,integer)', 'HTP'),
  ('_slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)', 'HTP'),
  ('_user_hosted_game(uuid,uuid)', 'HTP'),
  ('game_is_joinable(uuid)', 'HTP'),
  ('game_slots_left(uuid)', 'HTP'),
  ('_can_view_game(uuid)', 'DUAL'),
  ('_is_game_host(uuid)', 'DUAL'),
  ('active_stream(text[],text,integer,timestamp with time zone,text,uuid)', 'DUAL'),
  ('rpc_get_activity_feed(text,integer,timestamp with time zone)', 'DUAL'),
  ('rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', 'DUAL'),
  ('rpc_rate_game(uuid,uuid,jsonb,text)', 'DUAL'),
  ('rpc_rate_user(uuid,uuid,uuid,jsonb,text)', 'DUAL'),
  ('rpc_rate_venue(uuid,uuid,uuid,jsonb,text)', 'DUAL'),
  ('rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)', 'DUAL'),
  ('rpc_meetup_card(uuid,text)', 'HELD');

-- Inventory builder (functions + views). Comment-stripped bodies; alias resolution as KAN-781 S2.
CREATE FUNCTION pg_temp.k782_inventory() RETURNS TABLE(sig text, cls text, live boolean, cols text) LANGUAGE sql AS $f$
WITH fn AS (
  SELECT p.oid, p.oid::regprocedure::text AS sig,
         regexp_replace(regexp_replace(coalesce(p.prosrc, ''), '/\*([^*]|\*+[^*/])*\*+/', '', 'g'), '--[^\n]*', '', 'g') AS src,
         (EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgfoid = p.oid AND NOT t.tgisinternal)
          OR has_function_privilege('anon', p.oid, 'EXECUTE') OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
          OR has_function_privilege('service_role', p.oid, 'EXECUTE')) AS live
    FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
   WHERE p.pronamespace = 'public'::regnamespace AND l.lanname IN ('sql', 'plpgsql')
     AND p.proname !~ '^(k7\d\d_ref_|b\d\d_ref_|harness_|k78\d_)'
  UNION ALL
  SELECT c.oid, 'view ' || c.relname, pg_get_viewdef(c.oid),
         has_table_privilege('anon', c.oid, 'SELECT') OR has_table_privilege('authenticated', c.oid, 'SELECT')
          OR has_table_privilege('service_role', c.oid, 'SELECT')
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('v', 'm')),
al AS (
  SELECT DISTINCT f.oid, lower(m[1]) AS tbl, lower(coalesce(nullif(m[2], ''), m[1])) AS alias
    FROM fn f, regexp_matches(f.src,
      '\m(?:from|join|update|into)\s+(?:only\s+)?(?:public\.)?(games|meetups)\M(?:\s+(?:as\s+)?(?!(?:where|on|set|join|left|right|inner|cross|using|group|order|limit|returning|for|select|values|union|natural|full|lateral|and|or|having|window|except|intersect|offset|fetch|then|end|loop|into)\M)([a-z_][a-z0-9_]*))?', 'gi') m),
hit AS (
  SELECT DISTINCT f.oid, s.tbl, s.col, s.held FROM fn f JOIN al a ON a.oid = f.oid JOIN k782_slated s ON s.tbl = a.tbl
   WHERE f.src ~* ('\m(' || a.alias || '|' || a.tbl || ')\.' || s.col || '\M'))
SELECT f.sig,
       CASE WHEN f.src ~* 'coalesce\s*\([^()]*\m(e|ev|events)\.[a-z_]+\s*,\s*(g|m|games|meetups)\.[a-z_]+'
              OR f.src ~* 'coalesce\s*\([^()]*\m(g|m|games|meetups)\.[a-z_]+\s*,\s*(e|ev|events)\.[a-z_]+' THEN 'COALESCE'
            WHEN f.src ~* 'has_table_privilege\s*\(\s*''public\.events''' THEN 'HTP'
            WHEN bool_and(h.held) THEN 'HELD'
            ELSE 'DUAL' END,
       f.live, string_agg(h.tbl || '.' || h.col, ',' ORDER BY h.tbl, h.col)
  FROM fn f JOIN hit h ON h.oid = f.oid
 WHERE f.src ~* '\m(from|join)\s+(only\s+)?(public\.)?events\M'
 GROUP BY f.sig, f.src, f.live
$f$;

-- Shapes / counts / visibility, measured the same way before and after Z05.
CREATE FUNCTION pg_temp.k782_shape() RETURNS TABLE(rel text, shape text) LANGUAGE sql AS $f$
  SELECT c.relname::text, string_agg(a.attname || ' ' || format_type(a.atttypid, a.atttypmod), ', ' ORDER BY a.attnum)
    FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
   WHERE c.relnamespace = 'public'::regnamespace AND c.relname IN ('games', 'meetups', 'kan718_games_compat', 'kan718_meetups_compat')
   GROUP BY c.relname $f$;
CREATE FUNCTION pg_temp.k782_count() RETURNS TABLE(rel text, n bigint, nd bigint) LANGUAGE sql AS $f$
  SELECT 'games', count(*), count(DISTINCT id) FROM public.games UNION ALL
  SELECT 'meetups', count(*), count(DISTINCT id) FROM public.meetups UNION ALL
  SELECT 'events', count(*), count(DISTINCT id) FROM public.events UNION ALL
  SELECT 'kan718_games_compat', count(*), count(DISTINCT id) FROM public.kan718_games_compat UNION ALL
  SELECT 'kan718_meetups_compat', count(*), count(DISTINCT id) FROM public.kan718_meetups_compat $f$;
CREATE FUNCTION pg_temp.k782_vis() RETURNS TABLE(who text, rel text, ids text) LANGUAGE plpgsql AS $f$
DECLARE w record; t text; BEGIN
  FOR w IN SELECT * FROM k782_who LOOP
    FOREACH t IN ARRAY ARRAY['games', 'meetups', 'kan718_games_compat', 'kan718_meetups_compat'] LOOP
      who := w.label; rel := t;
      ids := pg_temp.k782_as(w.role, w.uid,
        format('SELECT count(*) || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.%I', t));
      RETURN NEXT;
    END LOOP;
  END LOOP; END $f$;

CREATE TEMP TABLE k782_inv0 AS SELECT * FROM pg_temp.k782_inventory();
CREATE TEMP TABLE k782_shp0 AS SELECT * FROM pg_temp.k782_shape();
CREATE TEMP TABLE k782_cnt0 AS SELECT * FROM pg_temp.k782_count();
CREATE TEMP TABLE k782_vis0 AS SELECT * FROM pg_temp.k782_vis();
SELECT set_config('k782.fp_in', pg_temp.k782_fp(), true) IS NOT NULL AS fp_in_taken;

-- ===================================== apply Z05 =====================================
SAVEPOINT k782_mig;
\i :mig

-- MIG
DO $m$ DECLARE fp text := pg_temp.k782_fp(); f0 text := current_setting('k782.fp_in'); BEGIN
  INSERT INTO k782_result VALUES ('MIG', CASE WHEN fp = f0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN fp = f0 THEN format('Z05 changed no catalogue object and no row (fingerprint %s)', fp)
         ELSE format('Z05 changed the catalogue or data: %s -> %s', f0, fp) END);
END $m$;

-- SHP
INSERT INTO k782_result
SELECT 'SHP', CASE WHEN a.shape IS NOT DISTINCT FROM b.shape THEN 'PASS' ELSE 'FAIL' END,
       format('%s: %s', coalesce(a.rel, b.rel), CASE WHEN a.shape IS NOT DISTINCT FROM b.shape THEN 'legacy shape unchanged (' || md5(coalesce(b.shape, '')) || ')' ELSE 'shape changed' END)
  FROM k782_shp0 a FULL JOIN pg_temp.k782_shape() b USING (rel);
INSERT INTO k782_result SELECT 'SHP', 'FAIL', 'compat projection missing: ' || r
  FROM unnest(ARRAY['kan718_games_compat', 'kan718_meetups_compat']) r WHERE to_regclass('public.' || r) IS NULL;

-- CNT
INSERT INTO k782_result
SELECT 'CNT', CASE WHEN a.n = b.n AND b.n = b.nd THEN 'PASS' ELSE 'FAIL' END,
       format('%s: %s rows before, %s after, %s distinct ids', a.rel, a.n, b.n, b.nd)
  FROM k782_cnt0 a JOIN pg_temp.k782_count() b USING (rel);
DO $c$ DECLARE g bigint; m bigint; e bigint; gc bigint; mc bigint; BEGIN
  SELECT n INTO g FROM pg_temp.k782_count() WHERE rel = 'games';
  SELECT n INTO m FROM pg_temp.k782_count() WHERE rel = 'meetups';
  SELECT n INTO e FROM pg_temp.k782_count() WHERE rel = 'events';
  SELECT n INTO gc FROM pg_temp.k782_count() WHERE rel = 'kan718_games_compat';
  SELECT n INTO mc FROM pg_temp.k782_count() WHERE rel = 'kan718_meetups_compat';
  INSERT INTO k782_result VALUES ('CNT', CASE WHEN gc = g AND mc = m AND e = g + m THEN 'PASS' ELSE 'FAIL' END,
    format('compat = legacy (games %s/%s, meetups %s/%s); events %s = games + meetups %s', gc, g, mc, m, e, g + m));
  INSERT INTO k782_result VALUES ('CNT', CASE WHEN (SELECT count(*) FROM public.games WHERE id = '78100000-0000-0000-0000-000000000001') = 1
                                                AND (SELECT count(*) FROM public.meetups WHERE id = '78100000-0000-0000-0000-00000000f001') = 1 THEN 'PASS' ELSE 'FAIL' END,
    'seeded game 78100000-...0001 and seeded meetup 78100000-...f001 present exactly once');
END $c$;

-- VIS
INSERT INTO k782_result
SELECT 'VIS', CASE WHEN a.ids = b.ids AND a.ids NOT LIKE 'ERR %' THEN 'PASS' ELSE 'FAIL' END,
       format('%s on %s: %s -> %s', a.who, a.rel, a.ids, b.ids)
  FROM k782_vis0 a JOIN pg_temp.k782_vis() b USING (who, rel);

-- INV
CREATE TEMP TABLE k782_inv1 AS SELECT * FROM pg_temp.k782_inventory();
INSERT INTO k782_result
SELECT 'INV', CASE WHEN x.sig IS NULL THEN 'FAIL' WHEN i.sig IS NULL THEN 'FAIL' WHEN i.cls <> x.cls THEN 'FAIL' ELSE 'PASS' END,
       CASE WHEN i.sig IS NULL THEN format('%s [%s] expected but MISSING: a live fallback was removed or rewritten', x.sig, x.cls)
            WHEN x.sig IS NULL THEN format('%s [%s] reads %s: UNEXPECTED fallback (introduced or reintroduced)', i.sig, i.cls, i.cols)
            WHEN i.cls <> x.cls THEN format('%s: class %s, expected %s', i.sig, i.cls, x.cls)
            ELSE format('%s [%s] reads %s', i.sig, i.cls, i.cols) END
  FROM k782_inv1 i FULL JOIN k782_expected x USING (sig);
INSERT INTO k782_result SELECT 'INV', CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       format('%s COALESCE-style value fallbacks (expected 0)', count(*)) FROM k782_inv1 WHERE cls = 'COALESCE';
INSERT INTO k782_result SELECT 'INV', CASE WHEN (SELECT count(*) FROM k782_inv0) = (SELECT count(*) FROM k782_inv1)
                                          AND NOT EXISTS (SELECT * FROM k782_inv0 EXCEPT SELECT * FROM k782_inv1) THEN 'PASS' ELSE 'FAIL' END,
       format('inventory before Z05 (%s) = after Z05 (%s)', (SELECT count(*) FROM k782_inv0), (SELECT count(*) FROM k782_inv1));

-- LIV
INSERT INTO k782_result SELECT 'LIV', CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN count(*) = 0 THEN format('removable (not LIVE) fallbacks: 0 of %s; every entry is EXECUTE/SELECT-granted to an API role', (SELECT count(*) FROM k782_inv1))
            ELSE 'not LIVE (would be removable, Z05 must handle it): ' || string_agg(sig, ', ') END
  FROM k782_inv1 WHERE NOT live;
INSERT INTO k782_result VALUES ('LIV',
  CASE WHEN NOT has_table_privilege('authenticated', 'public.events', 'SELECT') AND NOT has_table_privilege('anon', 'public.events', 'SELECT') THEN 'PASS' ELSE 'FAIL' END,
  format('HTP ELSE (legacy) branch is the client path: events SELECT authenticated=%s anon=%s',
         has_table_privilege('authenticated', 'public.events', 'SELECT'), has_table_privilege('anon', 'public.events', 'SELECT')));
DO $l$ DECLARE r text; post boolean; BEGIN
  post := NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'capacity' AND NOT attisdropped);
  r := pg_temp.k782_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
         $s$SELECT public.game_slots_left('78100000-0000-0000-0000-000000000001')::text$s$);
  INSERT INTO k782_result VALUES ('LIV',
    CASE WHEN (NOT post AND r ~ '^[0-9]+$') OR (post AND r LIKE 'ERR 42703 %capacity%') THEN 'PASS' ELSE 'FAIL' END,
    format('game_slots_left as authenticated (%s state) -> %s: the legacy branch executes for a client caller (LIVE)',
           CASE WHEN post THEN 'post-Z01' ELSE 'pre-Z01' END, r));
END $l$;

SELECT sec || ' ' || verdict || ': ' || detail AS line FROM k782_result
 ORDER BY array_position(ARRAY['MIG', 'SHP', 'CNT', 'VIS', 'INV', 'LIV'], sec), verdict DESC, detail;
SELECT count(*) FILTER (WHERE verdict = 'FAIL') AS nfail,
       coalesce(string_agg(DISTINCT sec, ',') FILTER (WHERE verdict = 'FAIL'), '') AS failsec,
       count(*) AS nchk FROM k782_result \gset
ROLLBACK;
SET client_min_messages = notice;
SELECT set_config('k782.nfail', :'nfail', false) IS NOT NULL AND set_config('k782.failsec', :'failsec', false) IS NOT NULL
   AND set_config('k782.nchk', :'nchk', false) IS NOT NULL AS summary_taken;

-- R
DO $r$ BEGIN
  IF pg_temp.k782_fp() <> current_setting('k782.fp0') THEN RAISE EXCEPTION 'KAN-782 Z05 TEST FAIL: R catalogue+data fingerprint changed after ROLLBACK'; END IF;
  RAISE NOTICE 'R PASS: catalogue+data fingerprint after ROLLBACK = before the run (%)', current_setting('k782.fp0');
END $r$;
DO $s$ BEGIN
  IF current_setting('k782.nfail')::int > 0 THEN RAISE EXCEPTION 'KAN-782 Z05 TEST FAIL: % failing check(s) in section(s) %', current_setting('k782.nfail'), current_setting('k782.failsec'); END IF;
  RAISE NOTICE 'KAN-782 Z05 TEST PASS: % checks + R; fallback inventory 6 HTP + 9 DUAL + 1 HELD + 0 COALESCE, all LIVE; removable set empty; Z05 a no-op', current_setting('k782.nchk');
END $s$;

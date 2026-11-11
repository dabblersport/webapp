#!/usr/bin/env bash
# KAN-866 (F11, KAN-719b) LOCAL PROOF. LOCAL THROWAWAY POSTGRES 16 ONLY. NEVER POINT THIS AT SUPABASE.
#
# Proves supabase/migrations/20261111120000_kan719b_drop_client_read_games_columns.sql on the tracked chain that
# build_kan851.sh / kan865_export_own_game_history_test.sql use (harnesses kan711/712/713/714, then migrations
# 20261101140000, 20261102110000, 20261102120000 + backfill, 20261103100000). 3010 games rows.
#
#   RED 0  k866        the real chain as built: the gate refuses (P3 views, triggers, constraints, indexes; P4
#                      function bodies) and nothing changes: 22 columns present, no backup table.
#   PREREQ k866_green  a copy where every object the gate names is removed BY THIS TEST (a stand-in for the
#                      prerequisite work that must retire them; see the report). Not part of the migration.
#   RED 1  k866_green  + a view reading games.title: refused at P3, naming the view.
#   RED 2  k866_green  + a plpgsql function reading games.title: refused at P4, naming the function.
#   GREEN  k866_green  the migration applies: 22 columns absent, id/event_id kept, backup rows = games rows, the
#                      backup holds exactly the pre-drop values (md5 of every row), 22 pre-DROP NOTICE counts.
#   RERUN  k866_green  a second run refuses at P1 and P5.
#   ROLLBACK           the KAN866-ROLLBACK block, extracted from the migration file itself, restores every column
#                      with its type, NOT NULL and default, and every value (same md5 as before the drop).
#
# Usage (from the repository root):
#   bash supabase/tests/events_p4/kan866_drop_client_read_games_columns_test.sh <new-datadir> <port>
# The cluster is stopped and the datadir removed on exit.
set -euo pipefail

DATADIR="${1:?usage: kan866_drop_client_read_games_columns_test.sh <new-datadir> <port>}"
PORT="${2:?usage: kan866_drop_client_read_games_columns_test.sh <new-datadir> <port>}"
[ "$PORT" != 5432 ] || { echo "kan866: refusing port 5432" >&2; exit 1; }
[ ! -e "$DATADIR" ] || { echo "kan866: $DATADIR already exists; refusing" >&2; exit 1; }
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
M=supabase/migrations
MIG="$ROOT/$M/20261111120000_kan719b_drop_client_read_games_columns.sql"
SOCK="$DATADIR.sock"

mkdir -p "$SOCK"
cleanup() {
  if [ -f "$DATADIR/postmaster.pid" ]; then pg_ctl -D "$DATADIR" stop -m fast >/dev/null 2>&1 || true; fi
  rm -rf -- "$DATADIR" "$DATADIR.log" "$SOCK"
}
trap cleanup EXIT

initdb -D "$DATADIR" -U pgboot -A trust --no-instructions >/dev/null
pg_ctl -D "$DATADIR" -o "-p $PORT -k $SOCK -c listen_addresses=''" -l "$DATADIR.log" -w start >/dev/null
boot() { psql -X -q -v ON_ERROR_STOP=1 -h "$SOCK" -p "$PORT" -U pgboot -d postgres "$@"; }
boot -c 'CREATE ROLE postgres LOGIN SUPERUSER CREATEROLE CREATEDB BYPASSRLS' -c 'CREATE DATABASE k866 OWNER postgres'

DB=k866
q()   { psql -X -q -v ON_ERROR_STOP=1 -h "$SOCK" -p "$PORT" -U postgres -d "$DB" "$@"; }
qt()  { q -tA "$@"; }
run() { q -f "$ROOT/$1" >/dev/null; }

q -c "DO \$g\$ BEGIN
  IF current_database() !~ '^k866' THEN RAISE EXCEPTION 'kan866: refusing database %', current_database(); END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'kan866: this looks like a Supabase database; refusing';
  END IF; END \$g\$;"

echo "== build tracked chain [k866]"
for f in supabase/tests/events_p1/local_harness_kan711.sql supabase/tests/events_p1/local_seed_kan711.sql \
         supabase/tests/events_p2/local_harness_kan712.sql supabase/tests/events_p2_kan713/local_harness_kan713.sql \
         supabase/tests/events_p2_kan714/local_harness_kan714.sql \
         $M/20261101140000_kan710_events_parent_schema.sql $M/20261102110000_kan711_events_mirror_triggers.sql \
         $M/20261102120000_kan711_events_backfill.sql; do
  run "$f"
done
q -c 'CALL public.kan711_events_backfill_run();' -c 'SELECT public.kan711_events_validate_links();' >/dev/null 2>&1
run $M/20261103100000_kan712_events_write_contract.sql
echo "   games rows: $(qt -c 'SELECT count(*) FROM public.games')"

COLS="creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at"
present() { qt -c "SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND NOT attisdropped AND attname = ANY('{$COLS}')"; }
backup()  { qt -c "SELECT to_regclass('public.games_kan866_dropped_cols_backup') IS NOT NULL"; }
shape()   { qt -c "SELECT md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull || ':' || coalesce(pg_get_expr(d.adbin, d.adrelid), '-'), ',' ORDER BY a.attname))
                    FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
                   WHERE a.attrelid = 'public.games'::regclass AND NOT a.attisdropped AND a.attname = ANY('{$COLS}')"; }
ROWHASH="SELECT md5(string_agg(row(id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy, min_skill, max_skill, is_cancelled, cancelled_at, cancelled_reason, created_at, updated_at, sport_id, geo_location_id, area_id, venue_id, joining_rule, cost_cover, request_id)::text, '|' ORDER BY id))"

PASS=0; FAIL=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; PASS=$((PASS+1)); else echo "FAIL - $1 (got '$2', want '$3')"; FAIL=$((FAIL+1)); fi; }
apply() { psql -X -q -v ON_ERROR_STOP=1 --single-transaction -h "$SOCK" -p "$PORT" -U postgres -d "$DB" -f "$MIG" 2>&1; }

echo "== RED 0 [k866] the real chain: the gate must refuse"
check "R0 before: 22 target columns present" "$(present)" 22
if OUT="$(apply)"; then check "R0 migration refused" applied refused; else check "R0 migration refused" refused refused; fi
echo "$OUT" | grep -o 'KAN-866 gate refused.*' | cut -c1-600
for p in P3 P4; do check "R0 refusal names $p" "$(echo "$OUT" | grep -c "$p ")" 1; done
check "R0 after refusal: still 22 columns" "$(present)" 22
check "R0 after refusal: no backup table" "$(backup)" f
echo "   P3 dependents on the real chain:"; echo "$OUT" | grep -o 'P3 objects still depend[^|]*' | tr ';' '\n' | sed 's/^ */     /' | head -100
echo "   P4 functions on the real chain:";  echo "$OUT" | grep -o 'P4 function bodies[^|]*' | tr ';' '\n' | sed 's/^ */     /' | head -60

boot -c 'CREATE DATABASE k866_green OWNER postgres TEMPLATE k866'
DB=k866_green
echo "== PREREQ [k866_green] remove every object the gate names (test stand-in for the prerequisite work)"
q <<'SQL'
CREATE SCHEMA kan866_t;
-- One pass: try to drop each named object; an object something else still needs is retried next pass.
CREATE FUNCTION kan866_t.strip_pass() RETURNS int LANGUAGE plpgsql AS $f$
DECLARE r record; n int := 0;
  cols text[] := '{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}';
  rx text := '\m(' || array_to_string(cols, '|') || ')\M';
BEGIN
  FOR r IN
    WITH dep AS (
      SELECT d.classid, d.objid FROM pg_depend d JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
       WHERE d.refclassid = 'pg_class'::regclass AND d.refobjid = 'public.games'::regclass AND a.attname = ANY(cols)
         AND d.classid <> 'pg_attrdef'::regclass),
    viewdeps AS (  -- views over the views found above
      SELECT DISTINCT rw2.ev_class FROM dep JOIN pg_rewrite rw ON dep.classid = 'pg_rewrite'::regclass AND rw.oid = dep.objid
        JOIN pg_depend d2 ON d2.refclassid = 'pg_class'::regclass AND d2.refobjid = rw.ev_class AND d2.classid = 'pg_rewrite'::regclass
        JOIN pg_rewrite rw2 ON rw2.oid = d2.objid AND rw2.ev_class <> rw.ev_class)
    SELECT format('DROP VIEW %s', rw.ev_class::regclass) s FROM dep JOIN pg_rewrite rw ON dep.classid = 'pg_rewrite'::regclass AND rw.oid = dep.objid
    UNION SELECT format('DROP VIEW %s', ev_class::regclass) FROM viewdeps
    UNION SELECT format('DROP TRIGGER %I ON %s', t.tgname, t.tgrelid::regclass) FROM dep JOIN pg_trigger t ON dep.classid = 'pg_trigger'::regclass AND t.oid = dep.objid
    UNION SELECT format('ALTER TABLE %s DROP CONSTRAINT %I', c.conrelid::regclass, c.conname) FROM dep JOIN pg_constraint c ON dep.classid = 'pg_constraint'::regclass AND c.oid = dep.objid
    UNION SELECT format('DROP INDEX %s', i.oid::regclass) FROM dep JOIN pg_class i ON dep.classid = 'pg_class'::regclass AND i.oid = dep.objid AND i.relkind = 'i'
    UNION SELECT format('DROP POLICY %I ON %s', p.polname, p.polrelid::regclass) FROM dep JOIN pg_policy p ON dep.classid = 'pg_policy'::regclass AND p.oid = dep.objid
    UNION SELECT format('DROP TRIGGER %I ON %s', t.tgname, t.tgrelid::regclass)
      FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE NOT t.tgisinternal AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'kan866_t')
       AND (p.prosrc ~* '\mgames\M' OR t.tgrelid = 'public.games'::regclass) AND p.prosrc ~* rx
    UNION SELECT format('DROP POLICY %I ON %s', pol.polname, pol.polrelid::regclass)  -- policies calling a named function
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      JOIN pg_depend d ON d.refclassid = 'pg_proc'::regclass AND d.refobjid = p.oid AND d.classid = 'pg_policy'::regclass
      JOIN pg_policy pol ON pol.oid = d.objid
     WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'kan866_t')
       AND (p.prosrc ~* '\mgames\M' OR EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.games'::regclass AND t.tgfoid = p.oid))
       AND p.prosrc ~* rx
    UNION SELECT format('DROP VIEW %s', rw.ev_class::regclass)  -- views calling a named function
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      JOIN pg_depend d ON d.refclassid = 'pg_proc'::regclass AND d.refobjid = p.oid AND d.classid = 'pg_rewrite'::regclass
      JOIN pg_rewrite rw ON rw.oid = d.objid
     WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'kan866_t')
       AND (p.prosrc ~* '\mgames\M' OR EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.games'::regclass AND t.tgfoid = p.oid))
       AND p.prosrc ~* rx
    UNION SELECT format('DROP FUNCTION %s', p.oid::regprocedure)
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'kan866_t')
       AND NOT EXISTS (SELECT 1 FROM pg_depend e WHERE e.classid = 'pg_proc'::regclass AND e.objid = p.oid AND e.deptype = 'e')
       AND (p.prosrc ~* '\mgames\M' OR EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.games'::regclass AND t.tgfoid = p.oid))
       AND p.prosrc ~* rx
  LOOP
    BEGIN EXECUTE r.s; n := n + 1; EXCEPTION WHEN dependent_objects_still_exist OR undefined_object OR undefined_table THEN NULL; END;
  END LOOP;
  RETURN n;
END $f$;
DO $d$ DECLARE i int; k int; total int := 0; BEGIN
  FOR i IN 1..20 LOOP k := kan866_t.strip_pass(); total := total + k; EXIT WHEN k = 0; END LOOP;
  RAISE NOTICE 'kan866 PREREQ: % objects removed', total;
END $d$;
DROP FUNCTION kan866_t.strip_pass();
SQL
q -c "CREATE TABLE kan866_t.snap AS $ROWHASH h FROM public.games"
SNAP="$(qt -c 'SELECT h FROM kan866_t.snap')"; SHAPE0="$(shape)"
echo "   pre-drop row md5 $SNAP; column-shape md5 $SHAPE0"

echo "== RED 1 [k866_green] a view still reads games.title"
q -c 'CREATE VIEW public.kan866_probe_v AS SELECT id, title FROM public.games'
if OUT="$(apply)"; then check "R1 refused" applied refused; else check "R1 refused" refused refused; fi
echo "$OUT" | grep -o 'KAN-866 gate refused.*' | cut -c1-300
check "R1 names the view at P3" "$(echo "$OUT" | grep -c 'P3 objects still depend.*view kan866_probe_v')" 1
check "R1 still 22 columns" "$(present)" 22
q -c 'DROP VIEW public.kan866_probe_v'

echo "== RED 2 [k866_green] a plpgsql function still reads games.title"
q -c 'CREATE FUNCTION public.kan866_probe_f(uuid) RETURNS text LANGUAGE plpgsql AS $$ BEGIN RETURN (SELECT g.title FROM public.games g WHERE g.id = $1); END $$'
if OUT="$(apply)"; then check "R2 refused" applied refused; else check "R2 refused" refused refused; fi
echo "$OUT" | grep -o 'KAN-866 gate refused.*' | cut -c1-300
check "R2 names the function at P4" "$(echo "$OUT" | grep -c 'P4 function bodies.*kan866_probe_f(uuid)')" 1
check "R2 still 22 columns" "$(present)" 22
check "R2 no backup table" "$(backup)" f
q -c 'DROP FUNCTION public.kan866_probe_f(uuid)'

echo "== GREEN [k866_green] apply"
N0="$(qt -c 'SELECT count(*) FROM public.games')"
if OUT="$(apply)"; then check "G applied" applied applied; else check "G applied" failed applied; echo "$OUT"; fi
echo "$OUT" | grep -E 'NOTICE' | sed 's/^psql:[^ ]* NOTICE: */   /'
check "G 22 pre-DROP non-null NOTICE lines" "$(echo "$OUT" | grep -c 'pre-DROP non-null games\.')" 22
check "G after: 0 target columns" "$(present)" 0
check "G id and event_id kept" "$(qt -c "SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND NOT attisdropped AND attname IN ('id','event_id')")" 2
check "G games row count unchanged" "$(qt -c 'SELECT count(*) FROM public.games')" "$N0"
check "G backup rows = games rows" "$(qt -c 'SELECT count(*) FROM public.games_kan866_dropped_cols_backup')" "$N0"
check "G backup values = pre-drop values (md5)" "$(qt -c "$ROWHASH FROM public.games_kan866_dropped_cols_backup")" "$SNAP"
check "G backup RLS on" "$(qt -c "SELECT relrowsecurity FROM pg_class WHERE oid = 'public.games_kan866_dropped_cols_backup'::regclass")" t
check "G backup no grant to anon/authenticated/PUBLIC" "$(qt -c "SELECT count(*) FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) x WHERE c.oid = 'public.games_kan866_dropped_cols_backup'::regclass AND x.grantee IN (0, (SELECT oid FROM pg_roles WHERE rolname = 'anon'), (SELECT oid FROM pg_roles WHERE rolname = 'authenticated'))")" 0
check "G no other games column dropped (remaining columns = the non-target columns before)" "$(qt -c "SELECT string_agg(attname, ',' ORDER BY attname) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped")" \
  "$(DB=k866 qt -c "SELECT string_agg(attname, ',' ORDER BY attname) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped AND attname <> ALL('{$COLS}')")"
check "G meetups untouched" "$(qt -c "SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped")" \
  "$(DB=k866 qt -c "SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped")"

echo "== RERUN [k866_green] a second run must refuse"
if OUT="$(apply)"; then check "RR refused" applied refused; else check "RR refused" refused refused; fi
check "RR refusal names P1 and P5" "$(echo "$OUT" | grep -c 'P1 target column missing.*P5 ')" 1

echo "== ROLLBACK [k866_green] the block from the migration file"
sed -n '/^-- KAN866-ROLLBACK-BEGIN$/,/^-- KAN866-ROLLBACK-END$/p' "$MIG" | sed '1d;$d' | sed 's/^-- \{0,1\}//' > "$DATADIR.rollback.sql"
echo "   rollback block: $(wc -l < "$DATADIR.rollback.sql" | tr -d ' ') lines"
if OUT="$(psql -X -q -v ON_ERROR_STOP=1 --single-transaction -h "$SOCK" -p "$PORT" -U postgres -d "$DB" -f "$DATADIR.rollback.sql" 2>&1)"; then
  check "RB applied" applied applied; else check "RB applied" failed applied; echo "$OUT"; fi
rm -f "$DATADIR.rollback.sql"
check "RB 22 columns back" "$(present)" 22
check "RB type, NOT NULL and default identical (shape md5)" "$(shape)" "$SHAPE0"
check "RB every value restored (row md5)" "$(qt -c "$ROWHASH FROM public.games")" "$SNAP"
check "RB no user trigger left disabled" "$(qt -c "SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND NOT tgisinternal AND tgenabled = 'D'")" 0

echo "== RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

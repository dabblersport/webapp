#!/usr/bin/env bash
# KAN-851 LOCAL CHAIN BUILD + TEST. LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Applies the events chain through step 6 (as build_kan850.sh: bootstrap superuser `pgboot`, owner role `postgres`),
# then, with postgres DEMOTED to NOSUPERUSER CREATEROLE BYPASSRLS as on production:
#   20261103104000 (KAN-851 capture), 20261103105000 (6c), 20261103110000 (step 7).
# Evidence it prints:
#   RED 1  the test (T1-T3) fails on a copy taken before the capture (the function does not exist).
#   RED 2  on a copy with the capture, step 7 as it stands on origin/Alpha (no allowlist entry) fails at 4d naming
#          run_seed_meetup_template(uuid,jsonb).
#   GREEN  the capture, 6c and step 7 (this branch) apply; then the test, T1-T4 (T4 calls the function as service_role).
# Databases: k851 (green), k851_pre (before the capture), k851_red (capture + 6c, step 7 refused).
#
# Usage (from the repository root):
#   bash supabase/tests/events_p4/build_kan851.sh <new-datadir> <port> [<base-ref for RED 2, default origin/Alpha>]
# Stop and delete afterwards:
#   pg_ctl -D <datadir> stop -m fast && rm -rf <datadir> <datadir>.log <datadir>.fixtures
set -euo pipefail

DATADIR="${1:?usage: build_kan851.sh <new-datadir> <port> [base-ref]}"
PORT="${2:?usage: build_kan851.sh <new-datadir> <port> [base-ref]}"
BASE="${3:-origin/Alpha}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
M=supabase/migrations
E=supabase/tests/events_p2
T=supabase/tests/events_p4/kan851_run_seed_meetup_template_test.sql
CAP=20261103104000_kan851_capture_run_seed_meetup_template.sql

[ ! -e "$DATADIR" ] || { echo "build_kan851: $DATADIR already exists; refusing" >&2; exit 1; }
[ "$PORT" != 5432 ] || { echo "build_kan851: refusing port 5432" >&2; exit 1; }

FIX="$DATADIR.fixtures"
mkdir -p "$FIX"
git -C "$ROOT" show "$BASE:$M/20261103110000_kan712_cutover.sql" > "$FIX/step7_base.sql"
grep -q "'run_seed_meetup_template'" "$FIX/step7_base.sql" \
  && { echo "build_kan851: $BASE step 7 already allowlists run_seed_meetup_template; RED 2 impossible" >&2; exit 1; }

initdb -D "$DATADIR" -U pgboot -A trust --no-instructions >/dev/null
pg_ctl -D "$DATADIR" -o "-p $PORT -k /tmp -c listen_addresses=''" -l "$DATADIR.log" -w start >/dev/null
boot() { psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U pgboot -d postgres "$@"; }
boot -c 'CREATE ROLE postgres LOGIN SUPERUSER CREATEROLE CREATEDB BYPASSRLS'
boot -c 'CREATE DATABASE k851 OWNER postgres'
promote() { boot -c 'ALTER ROLE postgres SUPERUSER' >/dev/null; }
demote()  { boot -c 'ALTER ROLE postgres NOSUPERUSER CREATEROLE BYPASSRLS' >/dev/null
            echo "   (postgres: $(boot -tA -c "SELECT 'rolsuper=' || rolsuper FROM pg_roles WHERE rolname = 'postgres'"))"; }

DB=k851
psql_db() { psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d "$DB" "$@"; }
run() { echo "== [$DB] $1"; psql_db "${@:2}" -f "$ROOT/$1"; }

psql_db -c "DO \$g\$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'build_kan851: this looks like a Supabase database; refusing';
  END IF; END \$g\$;"

run supabase/tests/events_p1/local_harness_kan711.sql
run supabase/tests/events_p1/local_seed_kan711.sql
run $E/local_harness_kan712.sql
run supabase/tests/events_p2_kan713/local_harness_kan713.sql
run supabase/tests/events_p2_kan714/local_harness_kan714.sql
run $M/20261101140000_kan710_events_parent_schema.sql
run $M/20261102110000_kan711_events_mirror_triggers.sql
run $M/20261102120000_kan711_events_backfill.sql
psql_db -c 'CALL public.kan711_events_backfill_run();' -c 'SELECT public.kan711_events_validate_links();' >/dev/null
run $M/20261103100000_kan712_events_write_contract.sql

boot -c 'CREATE DATABASE k851_pre OWNER postgres TEMPLATE k851'
echo "== RED 1 [k851_pre] test before the capture (must fail at T1)"
if OUT="$(DB=k851_pre psql_db -v skip_call=1 -f "$ROOT/$T" 2>&1)"; then
  echo "$OUT"; echo "build_kan851: RED 1 did not fail" >&2; exit 1
fi
echo "$OUT" | tail -2

demote
run $M/$CAP
promote
boot -c 'CREATE DATABASE k851_red OWNER postgres TEMPLATE k851'

demote
DB=k851_red
run $M/20261103105000_kan844_kan712_contract_flag_set_config.sql
echo "== RED 2 [$DB] step 7 from $BASE (no allowlist entry), capture present (must fail at 4d)"
if OUT="$(psql_db -f "$FIX/step7_base.sql" 2>&1)"; then
  echo "$OUT"; echo "build_kan851: RED 2 step 7 did not fail" >&2; exit 1
fi
echo "$OUT" | grep 'ERROR'
echo "$OUT" | grep -q 'KAN-712 post: unclassified writers of games/meetups: run_seed_meetup_template(uuid,jsonb)$' \
  || { echo "build_kan851: RED 2 failed for another reason" >&2; exit 1; }

DB=k851
echo "== GREEN [$DB] 6c + step 7 (this branch), postgres demoted"
run $M/20261103105000_kan844_kan712_contract_flag_set_config.sql
run $M/20261103110000_kan712_cutover.sql
promote
echo "== GREEN [$DB] test T1-T4"
psql -X -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d k851 -f "$ROOT/$T"
demote
echo "build_kan851: PASS on port $PORT"

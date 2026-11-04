#!/usr/bin/env bash
# KAN-728 LOCAL CHAIN BUILDER. LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Creates a BRAND NEW PostgreSQL cluster in <datadir> (refuses if it exists), starts it on <port> with the
# socket in /tmp, creates database k728 and loads the pre-image chain the B09 test runs on, from tracked files only:
#   1  supabase/tests/events_p1/local_harness_kan711.sql
#   2  supabase/tests/events_p1/local_seed_kan711.sql
#   3  supabase/tests/events_p2/local_harness_kan712.sql
#   4  supabase/tests/events_p2_kan713/local_harness_kan713.sql
#   5  supabase/tests/events_p2_kan714/local_harness_kan714.sql
#   6  supabase/migrations/20261101140000_kan710_events_parent_schema.sql            (KAN-710)
#   7  supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql          (KAN-711 1/2)
#   8  supabase/migrations/20261102120000_kan711_events_backfill.sql                 (KAN-711 2/2)
#   9  CALL public.kan711_events_backfill_run(); SELECT public.kan711_events_validate_links();
#  10  supabase/migrations/20261103100000_kan712_events_write_contract.sql           (KAN-712 stage A)
#  11  supabase/migrations/20261103110000_kan712_cutover.sql                         (KAN-712 stage B)
#  12  supabase/migrations/20261104100000_kan713_access_helpers.sql                  (KAN-713 1/2)
#  13  supabase/migrations/20261104110000_kan713_location_triggers.sql               (KAN-713 2/2)
#  14  supabase/migrations/20261104110300_kan718_d07_series_occurrence_unique.sql    (KAN-718)
#  15  supabase/tests/events_p2/local_harness_kan728.sql                             (B09 pre-image functions)
# It does NOT apply the B09 migration; the RED/GREEN steps are in the header of
# supabase/tests/events_p2/kan714_b09_booking_conflicts.sql.
#
# Usage (from the repository root):
#   bash supabase/tests/events_p2/build_kan728.sh /tmp/kan728b_pg 54728
# Stop afterwards:
#   pg_ctl -D /tmp/kan728b_pg stop -m fast
set -euo pipefail

DATADIR="${1:?usage: build_kan728.sh <new-datadir> <port>}"
PORT="${2:?usage: build_kan728.sh <new-datadir> <port>}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

if [ -e "$DATADIR" ]; then
  echo "build_kan728: $DATADIR already exists; refusing (brand new throwaway cluster only)" >&2
  exit 1
fi

initdb -D "$DATADIR" -U postgres -A trust --no-instructions >/dev/null
pg_ctl -D "$DATADIR" -o "-p $PORT -k /tmp -c listen_addresses=''" -l "$DATADIR.log" -w start >/dev/null
createdb -h /tmp -p "$PORT" -U postgres k728

run() { echo "== $1"; psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d k728 -f "$ROOT/$1" >/dev/null; }

run supabase/tests/events_p1/local_harness_kan711.sql
run supabase/tests/events_p1/local_seed_kan711.sql
run supabase/tests/events_p2/local_harness_kan712.sql
run supabase/tests/events_p2_kan713/local_harness_kan713.sql
run supabase/tests/events_p2_kan714/local_harness_kan714.sql
run supabase/migrations/20261101140000_kan710_events_parent_schema.sql
run supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql
run supabase/migrations/20261102120000_kan711_events_backfill.sql
echo "== KAN-711 backfill + validate"
psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d k728 \
  -c 'CALL public.kan711_events_backfill_run();' -c 'SELECT public.kan711_events_validate_links();' >/dev/null
run supabase/migrations/20261103100000_kan712_events_write_contract.sql
run supabase/migrations/20261103105000_kan844_kan712_contract_flag_set_config.sql
run supabase/migrations/20261103110000_kan712_cutover.sql
run supabase/migrations/20261104100000_kan713_access_helpers.sql
run supabase/migrations/20261104110000_kan713_location_triggers.sql
run supabase/migrations/20261104110300_kan718_d07_series_occurrence_unique.sql
run supabase/tests/events_p2/local_harness_kan728.sql
echo "build_kan728: pre-image chain ready on port $PORT, database k728"

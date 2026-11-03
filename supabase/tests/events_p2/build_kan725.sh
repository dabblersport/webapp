#!/usr/bin/env bash
# KAN-725 LOCAL CHAIN BUILDER. LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Creates a BRAND NEW PostgreSQL cluster in <datadir> (refuses if it exists), starts it on <port> with the
# socket in /tmp, creates database k725 and loads the pre-image chain the KAN-725 (B06) test runs on, in this order:
#   1  supabase/tests/events_p1/local_harness_kan711.sql
#   2  supabase/tests/events_p1/local_seed_kan711.sql
#   3  supabase/tests/events_p2/local_harness_kan712.sql
#   4  supabase/tests/events_p2_kan713/local_harness_kan713.sql
#   5  supabase/migrations/20261101140000_kan710_events_parent_schema.sql            (KAN-710)
#   6  supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql          (KAN-711 1/2)
#   7  supabase/migrations/20261102120000_kan711_events_backfill.sql                 (KAN-711 2/2)
#   8  CALL public.kan711_events_backfill_run(); SELECT public.kan711_events_validate_links();
#   9  supabase/migrations/20261103100000_kan712_events_write_contract.sql           (KAN-712 stage A)
#  10  supabase/migrations/20261103110000_kan712_cutover.sql                         (KAN-712 stage B)
#  11  supabase/migrations/20261104100000_kan713_access_helpers.sql                  (KAN-713 1/2)
#  12  supabase/migrations/20261104110000_kan713_location_triggers.sql               (KAN-713 2/2)
#  13  supabase/migrations/20261104110300_kan718_d07_series_occurrence_unique.sql    (KAN-718)
#  14  supabase/tests/events_p2/local_harness_kan725.sql                             (B06 pre-image RPCs + stand-ins)
# It does NOT apply the B06 migration; the RED/GREEN steps are in the header of
# supabase/tests/events_p2/kan714_b06_meetup_reads.sql.
#
# Usage (from the repository root):
#   bash supabase/tests/events_p2/build_kan725.sh /tmp/kan725_pg 54725
# Stop afterwards:
#   pg_ctl -D /tmp/kan725_pg stop -m fast
set -euo pipefail

DATADIR="${1:?usage: build_kan725.sh <new-datadir> <port>}"
PORT="${2:?usage: build_kan725.sh <new-datadir> <port>}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

if [ -e "$DATADIR" ]; then
  echo "build_kan725: $DATADIR already exists; refusing (brand new throwaway cluster only)" >&2
  exit 1
fi

initdb -D "$DATADIR" -U postgres -A trust --no-instructions >/dev/null
pg_ctl -D "$DATADIR" -o "-p $PORT -k /tmp -c listen_addresses=''" -l "$DATADIR.log" -w start >/dev/null
createdb -h /tmp -p "$PORT" -U postgres k725

run() { echo "== $1"; psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d k725 -f "$ROOT/$1"; }

run supabase/tests/events_p1/local_harness_kan711.sql
run supabase/tests/events_p1/local_seed_kan711.sql
run supabase/tests/events_p2/local_harness_kan712.sql
run supabase/tests/events_p2_kan713/local_harness_kan713.sql
run supabase/migrations/20261101140000_kan710_events_parent_schema.sql
run supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql
run supabase/migrations/20261102120000_kan711_events_backfill.sql
echo "== KAN-711 backfill + validate"
psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d k725 \
  -c 'CALL public.kan711_events_backfill_run();' -c 'SELECT public.kan711_events_validate_links();'
run supabase/migrations/20261103100000_kan712_events_write_contract.sql
run supabase/migrations/20261103110000_kan712_cutover.sql
run supabase/migrations/20261104100000_kan713_access_helpers.sql
run supabase/migrations/20261104110000_kan713_location_triggers.sql
run supabase/migrations/20261104110300_kan718_d07_series_occurrence_unique.sql
run supabase/tests/events_p2/local_harness_kan725.sql
echo "build_kan725: pre-image chain ready on port $PORT, database k725"

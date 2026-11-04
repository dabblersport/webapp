#!/usr/bin/env bash
# KAN-791: apply the Events migration chain to the local stack's database.
# LOCAL THROWAWAY PG16 ONLY. Called by start.sh after GoTrue has created the real auth schema.
#
# The order is the one the KAN-789 clean proof validated (build789.sh): stub harnesses, the
# KAN-710..718 parent chain, B01..B14 with the B15 shape snapshot before each B migration (KAN-716),
# the realtime publication (KAN-716) and the KAN-785 retirement. Probes and tests are NOT run here.
#
# One local transform, on a COPY of the harness (the repository file is untouched):
#   supabase/tests/events_p1/local_harness_kan711.sql:38
#     "CREATE TABLE auth.users (id uuid PRIMARY KEY);"  ->  "CREATE TABLE IF NOT EXISTS auth.users ..."
#   because GoTrue has already created the real auth.users. The harness also replaces auth.uid() with a
#   request.jwt.claim.sub-only stub; stack_shim.sql restores the Supabase definition afterwards.
#
# Usage: apply_chain.sh <psql-host> <port> <db> <applied-list-file>
set -euo pipefail
HOST="$1"; PORT="$2"; DB="$3"; LIST="$4"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="$(dirname "$LIST")/chain_src"
rm -rf "$WORK"; mkdir -p "$WORK"
cp -R "$ROOT/supabase" "$WORK/"
W="$WORK/supabase"; E="$W/tests/events_p2"; B15="$E/kan714_b15_coverage_probe.sql"
sed -i '' 's/^CREATE TABLE auth\.users (id uuid PRIMARY KEY);/CREATE TABLE IF NOT EXISTS auth.users (id uuid PRIMARY KEY);/' \
  "$W/tests/events_p1/local_harness_kan711.sql"
grep -q '^CREATE TABLE IF NOT EXISTS auth\.users' "$W/tests/events_p1/local_harness_kan711.sql" \
  || { echo "apply_chain: auth.users transform did not apply" >&2; exit 1; }

P=(psql -X -q -v ON_ERROR_STOP=1 -h "$HOST" -p "$PORT" -U postgres -d "$DB")
STEP="$(dirname "$LIST")/chain_step.log"
: > "$LIST"
r() { # <label> <psql args...>
  local label="$1"; shift
  "${P[@]}" "$@" > "$STEP" 2>&1 || { echo "apply_chain FAILED at: $label" >&2; tail -20 "$STEP" >&2; exit 1; }
  echo "$label" >> "$LIST"
}
f() { r "$1" -f "$W/$1"; }
snap() { "${P[@]}" -v mode=snapshot -f "$B15" > "$STEP" 2>&1 || { echo "apply_chain FAILED at B15 snapshot" >&2; tail -20 "$STEP" >&2; exit 1; }; }
m() { # <B number 01..14> [extra psql args]
  local n="$1"; shift
  local file; file="$(cd "$W" && ls migrations/2026110410"${n}"00_kan714_b*.sql)"
  snap
  r "$file" "$@" -f "$W/$file"
}

f tests/events_p1/local_harness_kan711.sql
f tests/events_p1/local_seed_kan711.sql
f tests/events_p2/local_harness_kan712.sql
f tests/events_p2_kan713/local_harness_kan713.sql
f tests/events_p2_kan714/local_harness_kan714.sql
f migrations/20261101140000_kan710_events_parent_schema.sql
f migrations/20261102110000_kan711_events_mirror_triggers.sql
f migrations/20261102120000_kan711_events_backfill.sql
r "CALL public.kan711_events_backfill_run(200); SELECT public.kan711_events_validate_links();" \
  -c "CALL public.kan711_events_backfill_run(200)" -c "SELECT public.kan711_events_validate_links()"
f migrations/20261103100000_kan712_events_write_contract.sql
f migrations/20261103104000_kan851_capture_run_seed_meetup_template.sql
f migrations/20261103105000_kan844_kan712_contract_flag_set_config.sql
f migrations/20261103110000_kan712_cutover.sql
f migrations/20261104100000_kan713_access_helpers.sql
f migrations/20261104110000_kan713_location_triggers.sql
f migrations/20261104110300_kan718_d07_series_occurrence_unique.sql
f tests/events_p2/local_harness_kan724.sql
r "tests/events_p2/kan714_b16_perf_pagination.sql (mode=before: nearby stand-ins + KAN-735 fixture)" \
  -v mode=before -f "$E/kan714_b16_perf_pagination.sql"
python3 -I "$HERE/b11_fixture.py" "$W/migrations" > "$WORK/b11_fixture.sql"
m 01; m 02; m 03; m 04; m 05; m 06; m 07
r "tests/events_p2/kan714_b08_capacity_join.sql (mode=harness)" -v mode=harness -f "$E/kan714_b08_capacity_join.sql"; m 08
f tests/events_p2/local_harness_kan728.sql; m 09
r "tests/events_p2/kan714_b10_settle_game.sql (fixture_only=1)" -v fixture_only=1 -f "$E/kan714_b10_settle_game.sql"; m 10
r "b11 pre-image fixture (scripts/local_stack/b11_fixture.py)" -f "$WORK/b11_fixture.sql"
PGOPTIONS="-c check_function_bodies=off" m 11
f tests/events_p2/local_harness_kan731.sql; m 12
r "tests/events_p2/kan714_b13_analytics_export.sql (fixture_only=1)" -v fixture_only=1 -f "$E/kan714_b13_analytics_export.sql"; m 13
m 14
snap
r "CREATE PUBLICATION supabase_realtime (platform-managed on Supabase; created empty here)" -c "CREATE PUBLICATION supabase_realtime"
f migrations/20261104102000_kan716_events_realtime_publication.sql
f migrations/20261104110400_kan785_retire_rpc_meetup_my.sql
rm -rf "$WORK"
echo "apply_chain: $(wc -l < "$LIST" | tr -d ' ') steps applied"

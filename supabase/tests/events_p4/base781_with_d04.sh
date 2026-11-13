#!/usr/bin/env bash
# KAN-860 (KAN-718 F7): the KAN-781 judge chain + KAN-718 D04, from TRACKED files only.
# LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Source: the KAN-781 judge's untracked builder base781_with_d04.sh (Thebes review evidence
#   agent/state/runtime/review-evidence/KAN-781/judge-04740e4f/base781_with_d04.sh, byte-identical apart from
#   port/paths to KAN-807/judge-97e5e6df/base.sh, the chain the kan807 test was judged on). Same steps, same order.
#   Changes from that copy, each because the original read an untracked file or a fixed path:
#     - creates its own BRAND NEW cluster (refuses an existing datadir) on <port>, socket /tmp, instead of a fixed
#       job directory;
#     - B11 pre-images from the tracked scripts/local_stack/b11_fixture.py (the KAN-791 copy of the same helper);
#     - rpc_meetup_rsvp pre-image for KAN-786 cut VERBATIM from the repository (as the judge's harness786.sh and
#       build_kan810.sh do): 20260912190747_kan180...sql CREATE OR REPLACE statement + 20260915120000:740-741 grants;
#     - local_harness_kan772.sql refuses any database not named k772*: the chain is built in k772_base781 and the
#       callers take copies (createdb -T), instead of sed-editing the harness;
#     - 20261103104000 (KAN-851 capture) and 20261103105000 (KAN-844 6c) are applied between the KAN-712 write
#       contract and the cutover, in filename order: they were authored after the judged run and the cutover on
#       this tree expects them (build_kan788.sh / apply_chain.sh apply them in the same slot).
#
# Result: database k772_base781 (chain + D04) and k781base (the same chain WITHOUT harness772/D04), on <port>.
#
# Usage (from the repository root):
#   bash supabase/tests/events_p4/base781_with_d04.sh /tmp/<new-datadir> <port>
# Stop and delete afterwards:
#   pg_ctl -D <datadir> stop -m fast && rm -rf <datadir> <datadir>.log <datadir>.fixtures
set -euo pipefail

DATADIR="${1:?usage: base781_with_d04.sh <new-datadir> <port>}"
PORT="${2:?usage: base781_with_d04.sh <new-datadir> <port>}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
M=supabase/migrations
E=supabase/tests/events_p2

case "$DATADIR" in
  /tmp/*|/private/tmp/*) ;;
  *) echo "base781_with_d04: datadir must be under /tmp (throwaway cluster only)" >&2; exit 1 ;;
esac
[ ! -e "$DATADIR" ] || { echo "base781_with_d04: $DATADIR already exists; refusing" >&2; exit 1; }
[ "$PORT" != 5432 ] || { echo "base781_with_d04: refusing port 5432" >&2; exit 1; }

FIX="$DATADIR.fixtures"
mkdir -p "$FIX"
initdb -D "$DATADIR" -U postgres -A trust --no-instructions >/dev/null
pg_ctl -D "$DATADIR" -o "-p $PORT -k /tmp -c listen_addresses=''" -l "$DATADIR.log" -w start >/dev/null

DB=k781base
createdb -h /tmp -p "$PORT" -U postgres "$DB"
psql_db() { psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d "$DB" "$@"; }
run() { echo "== [$DB] $1"; psql_db "${@:2}" -f "$ROOT/$1" >/dev/null; }

psql_db -c "DO \$g\$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'base781_with_d04: this looks like a Supabase database; refusing';
  END IF; END \$g\$;"

for f in supabase/tests/events_p1/local_harness_kan711.sql supabase/tests/events_p1/local_seed_kan711.sql \
         $E/local_harness_kan712.sql supabase/tests/events_p2_kan713/local_harness_kan713.sql \
         supabase/tests/events_p2_kan714/local_harness_kan714.sql \
         $M/20261101140000_kan710_events_parent_schema.sql $M/20261102110000_kan711_events_mirror_triggers.sql \
         $M/20261102120000_kan711_events_backfill.sql; do run $f; done
echo "== [$DB] KAN-711 backfill + validate"
psql_db -c "CALL public.kan711_events_backfill_run(200)" -c "SELECT public.kan711_events_validate_links()" >/dev/null
for f in 20261103100000_kan712_events_write_contract.sql 20261103104000_kan851_capture_run_seed_meetup_template.sql \
         20261103105000_kan844_kan712_contract_flag_set_config.sql 20261103110000_kan712_cutover.sql \
         20261104100000_kan713_access_helpers.sql 20261104110000_kan713_location_triggers.sql \
         20261104110300_kan718_d07_series_occurrence_unique.sql; do run $M/$f; done
run $E/local_harness_kan724.sql
run $E/kan714_b16_perf_pagination.sql -v mode=before
python3 -I "$ROOT/scripts/local_stack/b11_fixture.py" "$ROOT/$M" > "$FIX/b11_fixture.sql"
m() { local f; f=$(cd "$ROOT" && ls $M/2026110410"$1"00_kan714_b*.sql); run "$f" "${@:2}"; }
# STAND-IN for B03's KAN-853 pin (v_game_rating md5 92d98259 = composite_score numeric(3,2), the baseline type,
# 20260829080500:22788). The KAN-714 harness types it plain numeric (md5 98e6f13a), so B03 refuses on the judged
# chain as it stands on Alpha. Give the harness table the baseline type and re-create the harness view verbatim
# (local_harness_kan714.sql:565-577); the drop is of a view in this throwaway database only.
{ echo 'BEGIN;'
  echo 'DROP VIEW public.v_game_rating;'
  echo 'ALTER TABLE public.game_rating_aggregate ALTER COLUMN composite_score TYPE numeric(3,2);'
  sed -n 565,577p "$ROOT/supabase/tests/events_p2_kan714/local_harness_kan714.sql"
  echo 'COMMIT;'; } > "$FIX/v_game_rating_numeric32.sql"
m 01; m 02
echo "== [$DB] v_game_rating stand-in ($FIX/v_game_rating_numeric32.sql)"; psql_db -f "$FIX/v_game_rating_numeric32.sql" >/dev/null
m 03; m 04; m 05; m 06; m 07
run $E/kan714_b08_capacity_join.sql -v mode=harness; m 08
run $E/local_harness_kan728.sql; m 09
run $E/kan714_b10_settle_game.sql -v fixture_only=1; m 10
echo "== [$DB] b11 pre-image fixture ($FIX/b11_fixture.sql)"; psql_db -f "$FIX/b11_fixture.sql" >/dev/null
PGOPTIONS="-c check_function_bodies=off" m 11
run $E/local_harness_kan731.sql; m 12
run $E/kan714_b13_analytics_export.sql -v fixture_only=1; m 13
m 14
run $M/20261104110400_kan785_retire_rpc_meetup_my.sql
K180=$M/20260912190747_kan180_finding_b_meetup_rsvp_identity_and_profile_derivation.sql
{ echo '-- GENERATED by base781_with_d04.sh, LOCAL ONLY. VERBATIM rpc_meetup_rsvp pre-image for 20261104110500.'
  sed -n '/^CREATE OR REPLACE FUNCTION public.rpc_meetup_rsvp(/,/^\$function\$;$/p' "$ROOT/$K180"
  sed -n 740,741p "$ROOT/$M/20260915120000_meetups_hardening.sql"; } > "$FIX/rsvp_preimage.sql"
grep -q 'rpc_meetup_rsvp(uuid, text, uuid, uuid) TO authenticated, service_role' "$FIX/rsvp_preimage.sql"
echo "== [$DB] rpc_meetup_rsvp pre-image ($FIX/rsvp_preimage.sql)"; psql_db -f "$FIX/rsvp_preimage.sql" >/dev/null
run $M/20261104110500_kan786_meetup_leave.sql
echo "== [$DB] CREATE PUBLICATION supabase_realtime (platform-managed on Supabase; created empty here)"
psql_db -c "CREATE PUBLICATION supabase_realtime" >/dev/null
run $M/20261104102000_kan716_events_realtime_publication.sql
echo "base781: $DB built"

createdb -h /tmp -p "$PORT" -U postgres -T k781base k772_base781
DB=k772_base781
run supabase/tests/events_p4/local_harness_kan772.sql
run $M/20261104110100_kan718_d04_last_shared_field_reads.sql
echo "base781+D04: $DB built on port $PORT (socket /tmp)"

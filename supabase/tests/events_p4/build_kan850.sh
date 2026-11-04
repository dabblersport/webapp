#!/usr/bin/env bash
# KAN-850 LOCAL CHAIN BUILD, applying role NOT a superuser. LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Production applies migrations as Supabase's `postgres`, which is rolsuper = false (CREATEROLE, BYPASSRLS, owns the
# public objects). Every other local builder here runs as the bootstrap superuser `postgres`, which is why a
# function-level SET kan712.contract clause passed locally and failed on production with 42501. This builder:
#   * initdb with a separate bootstrap superuser `pgboot` (the bootstrap superuser cannot be demoted), then creates
#     role `postgres` (the KAN-712 guard trusts current_user = 'postgres' by NAME, so the owner must be named postgres);
#   * applies harnesses and every migration outside KAN-850's scope with postgres promoted to SUPERUSER (as the
#     existing builders do), and the five in scope with postgres DEMOTED to NOSUPERUSER CREATEROLE BYPASSRLS:
#       20261103105000 (6c), 20261103110000 (step 7), 20261104101400 (B14), 20261104110800 (KAN-809),
#       20261104112000 (KAN-810);
#   * C2 evidence, demoted: before 6c the step-7 probe (wrap rpc_update_game inside BEGIN .. ROLLBACK) must FAIL 42501
#     (RED, the production defect), after 6c it must succeed (GREEN), then step 7 is applied for real.
# Chain = supabase/tests/events_p2/build_kan788.sh chain A (database k788, 6c inserted after step 6) then the
# build_kan810.sh pieces on a copy k772_kan850 (through 20261104110500), then KAN-809 and KAN-810 on k772_kan850.
# B04 (build_kan788 chain B, separate database) is not part of this chain: nothing in KAN-850's scope touches it.
# Databases left: k788 (through B14), k772_kan850 (through KAN-810), k810_kan850 (copy of k772_kan850, for the KAN-810
# test, which refuses databases not named k810*). postgres is left DEMOTED at the end.
#
# Usage (from the repository root):
#   bash supabase/tests/events_p4/build_kan850.sh <new-datadir> <port>
# Stop and delete afterwards:
#   pg_ctl -D <datadir> stop -m fast && rm -rf <datadir> <datadir>.log <datadir>.fixtures
set -euo pipefail

DATADIR="${1:?usage: build_kan850.sh <new-datadir> <port>}"
PORT="${2:?usage: build_kan850.sh <new-datadir> <port>}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
M=supabase/migrations
E=supabase/tests/events_p2

if [ -e "$DATADIR" ]; then
  echo "build_kan850: $DATADIR already exists; refusing (brand new throwaway cluster only)" >&2
  exit 1
fi
[ "$PORT" != 5432 ] || { echo "build_kan850: refusing port 5432" >&2; exit 1; }

ORDER=(
  20261101140000_kan710_events_parent_schema.sql
  20261102110000_kan711_events_mirror_triggers.sql
  20261102120000_kan711_events_backfill.sql
  20261103100000_kan712_events_write_contract.sql
  20261103105000_kan844_kan712_contract_flag_set_config.sql
  20261103110000_kan712_cutover.sql
  20261104100000_kan713_access_helpers.sql
  20261104110000_kan713_location_triggers.sql
  20261104100100_kan714_b01_views_game_card_my_games.sql
  20261104100200_kan714_b02_views_meetup_list_counts.sql
  20261104100300_kan714_b03_views_rating_host_metrics.sql
  20261104100500_kan714_b05_search_filter_indexes.sql
  20261104100600_kan714_b06_rpc_meetup_reads.sql
  20261104100700_kan714_b07_sport_overview_counts.sql
  20261104100800_kan714_b08_capacity_join_rating_checks.sql
  20261104100900_kan714_b09_booking_conflicts_hold.sql
  20261104101000_kan714_b10_settle_game_reads.sql
  20261104101100_kan714_b11_msg_functions.sql
  20261104101200_kan714_b12_feed_notifications_stream.sql
  20261104101300_kan714_b13_analytics_admin_export_cleanup.sql
  20261104101400_kan714_b14_series_rpc_reads.sql
  20261104102000_kan716_events_realtime_publication.sql
  20261104110100_kan718_d04_last_shared_field_reads.sql
  20261104110200_kan718_d05_old_client_compat_projection.sql
  20261104110300_kan718_d07_series_occurrence_unique.sql
  20261104110400_kan785_retire_rpc_meetup_my.sql
  20261104110500_kan786_meetup_leave.sql
  20261104110800_kan809_update_game_stale_guard.sql
  20261104112000_kan810_cancel_game_idempotent.sql
)

FIX="$DATADIR.fixtures"
mkdir -p "$FIX"
# 20261104112000 (KAN-810) is left out of the order check, as build_kan810.sh leaves it out: it requires baseline
# rpc_cancel_game (20260829080500, never in a chain order; the harness supplies it) and the step-7 inner it creates.
printf '%s\n' "${ORDER[@]}" | grep -v '^20261104112000_' > "$FIX/order.txt"
echo "== order check (all but KAN-810)"
python3 "$ROOT/scripts/check_migration_apply_order.py" --order "$FIX/order.txt"

initdb -D "$DATADIR" -U pgboot -A trust --no-instructions >/dev/null
pg_ctl -D "$DATADIR" -o "-p $PORT -k /tmp -c listen_addresses=''" -l "$DATADIR.log" -w start >/dev/null
boot() { psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U pgboot -d postgres "$@"; }
boot -c 'CREATE ROLE postgres LOGIN SUPERUSER CREATEROLE CREATEDB BYPASSRLS'
boot -c 'CREATE DATABASE k788 OWNER postgres'

promote() { boot -c 'ALTER ROLE postgres SUPERUSER' >/dev/null; }
demote()  { boot -c 'ALTER ROLE postgres NOSUPERUSER CREATEROLE BYPASSRLS' >/dev/null
            echo "   (postgres: $(boot -tA -c "SELECT 'rolsuper=' || rolsuper || ' createrole=' || rolcreaterole || ' bypassrls=' || rolbypassrls FROM pg_roles WHERE rolname = 'postgres'"))"; }

DB=k788
psql_db() { psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d "$DB" "$@"; }
run() { echo "== [$DB] $1"; psql_db "${@:2}" -f "$ROOT/$1"; }
NEXT=0
mig() {
  local want="${ORDER[$NEXT]:-}"
  if [ "$1" != "$want" ]; then
    echo "build_kan850: step $1 is not ORDER[$NEXT] ($want); refusing" >&2
    exit 1
  fi
  NEXT=$((NEXT + 1))
  run "$M/$1"
}
mig_nonsuper() { demote; mig "$1"; promote; }

# Local throwaway only: no Supabase roles or schemas.
psql_db -c "DO \$g\$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'build_kan850: this looks like a Supabase database; refusing';
  END IF; END \$g\$;"

# b11 msg pre-images: identical to build_kan788.sh (verbatim by line range, two marked stand-ins).
ext_fn() { awk -v s="$2" 'NR>=s{print; if (NR>s && $0 ~ /^\$[a-z_]*\$;?$/) {exit}}' "$ROOT/$M/$1"; }
{
  sed -n 16,22p "$ROOT/$M/20261013150000_kan505_msg_registry.sql"
  sed -n 27,34p "$ROOT/$M/20261013150000_kan505_msg_registry.sql" | sed 's| REFERENCES public.game_roster (id)||'
  sed -n 36,37p "$ROOT/$M/20261013160800_kan547_msg_my_conversations.sql"
  sed -n 57,78p "$ROOT/$M/20261013160900_kan560_msg_dm_conversations.sql"
  sed -n 50,61p "$ROOT/$M/20261017130000_kan558_msg_meetup_chat.sql"
  sed -n 9,13p "$ROOT/$M/20261013150100_kan505_msg_access_allowlist.sql"
  cat <<'SQL'
CREATE OR REPLACE VIEW public.v_profile_public WITH (security_barrier = true, security_invoker = true) AS
  SELECT p.id, p.display_name, p.avatar_url
    FROM public.profiles p WHERE p.is_active = true;
SET check_function_bodies = off;
SQL
  ext_fn 20261017130000_kan558_msg_meetup_chat.sql 64
  ext_fn 20261017130000_kan558_msg_meetup_chat.sql 236
  ext_fn 20261017140000_kan559_msg_my_conversations_meetup_id.sql 17
  ext_fn 20261017120000_kan563_msg_game_conversation.sql 27
  sed -n 90,115p "$ROOT/$M/20261013160900_kan560_msg_dm_conversations.sql"
} > "$FIX/msg_preimage.sql"

step7_probe() {  # the CTO ruling's step-7 probe: one wrap inside a transaction that is rolled back
  psql -X -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d "$DB" \
    -c 'BEGIN' -c "SELECT current_user, (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) AS rolsuper" \
    -c "SELECT public.kan712_wrap_rpc(p.oid::regprocedure, 'game:p_game_id') FROM pg_proc p
          WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'rpc_update_game'" -c 'ROLLBACK' 2>&1
}

run supabase/tests/events_p1/local_harness_kan711.sql
run supabase/tests/events_p1/local_seed_kan711.sql
run $E/local_harness_kan712.sql
run supabase/tests/events_p2_kan713/local_harness_kan713.sql
run supabase/tests/events_p2_kan714/local_harness_kan714.sql
mig 20261101140000_kan710_events_parent_schema.sql
mig 20261102110000_kan711_events_mirror_triggers.sql
mig 20261102120000_kan711_events_backfill.sql
echo "== [$DB] KAN-711 backfill + validate"
psql_db -c 'CALL public.kan711_events_backfill_run();' -c 'SELECT public.kan711_events_validate_links();' >/dev/null
mig 20261103100000_kan712_events_write_contract.sql

echo "== [$DB] C2 RED: step-7 probe with the 20261103100000 generator, applying role demoted (must fail 42501)"
demote
if OUT="$(step7_probe)"; then
  echo "$OUT"; echo "build_kan850: RED probe did NOT fail; the non-superuser setup does not reproduce production" >&2; exit 1
fi
echo "$OUT"
echo "$OUT" | grep -q 'permission denied to set parameter "kan712.contract"' \
  || { echo "build_kan850: RED probe failed for another reason" >&2; exit 1; }
promote

demote; mig 20261103105000_kan844_kan712_contract_flag_set_config.sql
echo "== [$DB] C2 GREEN: step-7 probe after 6c, applying role demoted (must succeed)"
step7_probe
mig 20261103110000_kan712_cutover.sql
promote

mig 20261104100000_kan713_access_helpers.sql
mig 20261104110000_kan713_location_triggers.sql
mig 20261104100100_kan714_b01_views_game_card_my_games.sql
mig 20261104100200_kan714_b02_views_meetup_list_counts.sql
mig 20261104100300_kan714_b03_views_rating_host_metrics.sql
run $E/local_harness_kan724.sql
mig 20261104100500_kan714_b05_search_filter_indexes.sql
mig 20261104100600_kan714_b06_rpc_meetup_reads.sql
mig 20261104100700_kan714_b07_sport_overview_counts.sql
run $E/kan714_b08_capacity_join.sql -v mode=harness
mig 20261104100800_kan714_b08_capacity_join_rating_checks.sql
run $E/local_harness_kan728.sql
mig 20261104100900_kan714_b09_booking_conflicts_hold.sql
run $E/kan714_b10_settle_game.sql -v fixture_only=1
mig 20261104101000_kan714_b10_settle_game_reads.sql
run $E/local_harness_kan731.sql
echo "== [$DB] b11 msg pre-images (generated, $FIX/msg_preimage.sql)"
psql_db -f "$FIX/msg_preimage.sql"
mig 20261104101100_kan714_b11_msg_functions.sql
mig 20261104101200_kan714_b12_feed_notifications_stream.sql
run $E/kan714_b13_analytics_export.sql -v fixture_only=1
mig 20261104101300_kan714_b13_analytics_admin_export_cleanup.sql
mig_nonsuper 20261104101400_kan714_b14_series_rpc_reads.sql

# ---- build_kan810.sh pieces on a copy named k772_* (local_harness_kan772.sql refuses other names)
boot -c 'CREATE DATABASE k772_kan850 OWNER postgres TEMPLATE k788'
DB=k772_kan850
echo "== [$DB] CREATE PUBLICATION supabase_realtime (platform-managed on Supabase; created empty here)"
psql_db -c 'CREATE PUBLICATION supabase_realtime'
mig 20261104102000_kan716_events_realtime_publication.sql
run supabase/tests/events_p4/local_harness_kan772.sql
mig 20261104110100_kan718_d04_last_shared_field_reads.sql
mig 20261104110200_kan718_d05_old_client_compat_projection.sql
mig 20261104110300_kan718_d07_series_occurrence_unique.sql
mig 20261104110400_kan785_retire_rpc_meetup_my.sql
{
  echo '-- GENERATED by build_kan850.sh, LOCAL ONLY. VERBATIM rpc_meetup_rsvp pre-image for 20261104110500.'
  echo 'SET check_function_bodies = off;'
  sed -n 116,206p "$ROOT/$M/20260912190747_kan180_finding_b_meetup_rsvp_identity_and_profile_derivation.sql"
  sed -n 740,741p "$ROOT/$M/20260915120000_meetups_hardening.sql"
} > "$FIX/rsvp_preimage.sql"
echo "== [$DB] rpc_meetup_rsvp pre-image (generated, $FIX/rsvp_preimage.sql)"
psql_db -f "$FIX/rsvp_preimage.sql"
mig 20261104110500_kan786_meetup_leave.sql
boot -c 'CREATE DATABASE k772_kan850_pre809 OWNER postgres TEMPLATE k772_kan850'
mig_nonsuper 20261104110800_kan809_update_game_stale_guard.sql
mig_nonsuper 20261104112000_kan810_cancel_game_idempotent.sql
[ "$NEXT" -eq "${#ORDER[@]}" ] || { echo "build_kan850: applied $NEXT of ${#ORDER[@]}" >&2; exit 1; }

boot -c 'CREATE DATABASE k810_kan850 OWNER postgres TEMPLATE k772_kan850'
demote
echo "build_kan850: ${#ORDER[@]} migrations applied on port $PORT; 6c, step 7, B14, KAN-809, KAN-810 as rolsuper=false postgres"

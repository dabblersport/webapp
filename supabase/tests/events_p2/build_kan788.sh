#!/usr/bin/env bash
# KAN-788 FRESH-CLUSTER APPLY-ORDER PROOF. LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# Creates a BRAND NEW PostgreSQL cluster in <datadir> (refuses if it exists), starts it on <port> with the socket in
# /tmp, and applies every KAN-713 and KAN-714 migration in the decided order (KAN788_APPLY_ORDER.md): KAN-713
# location triggers right after KAN-713 access helpers, BEFORE the KAN-714 B files, which is the order production
# applied them in. Filename order puts 20261104110000 after 20261104100100..101400 and stops at B03 with
# 'KAN-722: prerequisite stage missing'.
#
# Before touching the cluster it runs scripts/check_migration_apply_order.py on the migration order below; the build
# refuses if that check fails. Every migration step must match the next entry of ORDER, so the list that was checked
# is the list that was applied.
#
# Two databases, because the B04 fixture and the KAN-714 harness both define public.geometry differently:
#   k788   chain A: harnesses, KAN-710..713, every KAN-714 B file except B04
#   k788b  chain B: harnesses without the KAN-714 harness, KAN-710..713, B04
# Fixture notes:
#   - B11 needs msg_* pre-images no tracked harness provides. They are cut VERBATIM from the repository's own
#     migrations by line range (below), with two marked stand-ins: no 'REFERENCES public.game_roster (id)' (the
#     harness game_roster has no id) and a reduced v_profile_public (the harness profiles lacks the baseline columns).
#     Generated into <datadir>.fixtures/, never committed.
#   - local_harness_kan725.sql is not loaded: it refuses on the KAN-714 harness chain and B06 does not need it.
#
# Usage (from the repository root):
#   bash supabase/tests/events_p2/build_kan788.sh /tmp/kan788_pg 54788
# Stop afterwards:
#   pg_ctl -D /tmp/kan788_pg stop -m fast
set -euo pipefail

DATADIR="${1:?usage: build_kan788.sh <new-datadir> <port>}"
PORT="${2:?usage: build_kan788.sh <new-datadir> <port>}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
M=supabase/migrations
E=supabase/tests/events_p2

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
  20261104100400_kan714_b04_rpc_nearby_following.sql
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
)

if [ -e "$DATADIR" ]; then
  echo "build_kan788: $DATADIR already exists; refusing (brand new throwaway cluster only)" >&2
  exit 1
fi

FIX="$DATADIR.fixtures"
mkdir -p "$FIX"
printf '%s\n' "${ORDER[@]}" > "$FIX/order.txt"
echo "== order check"
python3 "$ROOT/scripts/check_migration_apply_order.py" --order "$FIX/order.txt"

initdb -D "$DATADIR" -U postgres -A trust --no-instructions >/dev/null
pg_ctl -D "$DATADIR" -o "-p $PORT -k /tmp -c listen_addresses=''" -l "$DATADIR.log" -w start >/dev/null
createdb -h /tmp -p "$PORT" -U postgres k788
createdb -h /tmp -p "$PORT" -U postgres k788b

DB=k788
psql_db() { psql -X -q -v ON_ERROR_STOP=1 -h /tmp -p "$PORT" -U postgres -d "$DB" "$@"; }
run() { echo "== [$DB] $1"; psql_db "${@:2}" -f "$ROOT/$1"; }
NEXT=0
mig() {  # apply the next migration of ORDER; refuse anything out of sequence
  local want="${ORDER[$NEXT]:-}"
  if [ "$1" != "$want" ]; then
    echo "build_kan788: step $1 is not ORDER[$NEXT] ($want); refusing" >&2
    exit 1
  fi
  NEXT=$((NEXT + 1))
  run "$M/$1"
}
skip() { NEXT=$((NEXT + 1)); }  # this ORDER entry is applied on the other database

# b11 msg pre-images, verbatim by line range from the repository's own migrations
ext_fn() { awk -v s="$2" 'NR>=s{print; if (NR>s && $0 ~ /^\$[a-z_]*\$;?$/) {exit}}' "$ROOT/$M/$1"; }
{
  sed -n 16,22p "$ROOT/$M/20261013150000_kan505_msg_registry.sql"
  # STAND-IN: the harness game_roster has no id column
  sed -n 27,34p "$ROOT/$M/20261013150000_kan505_msg_registry.sql" | sed 's| REFERENCES public.game_roster (id)||'
  sed -n 36,37p "$ROOT/$M/20261013160800_kan547_msg_my_conversations.sql"
  sed -n 57,78p "$ROOT/$M/20261013160900_kan560_msg_dm_conversations.sql"
  sed -n 50,61p "$ROOT/$M/20261017130000_kan558_msg_meetup_chat.sql"
  sed -n 9,13p "$ROOT/$M/20261013150100_kan505_msg_access_allowlist.sql"
  cat <<'SQL'
-- STAND-IN (not verbatim): v_profile_public is baseline 20260829080500:25961-25973; the harness profiles table lacks
-- the baseline columns and fn_is_benched, so only the columns b11 msg_my_conversations reads are projected.
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

base_chain() {  # harnesses + KAN-710..713, both databases
  run supabase/tests/events_p1/local_harness_kan711.sql
  run supabase/tests/events_p1/local_seed_kan711.sql
  run $E/local_harness_kan712.sql
  run supabase/tests/events_p2_kan713/local_harness_kan713.sql
  if [ "$DB" = k788 ]; then run supabase/tests/events_p2_kan714/local_harness_kan714.sql; fi
  mig 20261101140000_kan710_events_parent_schema.sql
  mig 20261102110000_kan711_events_mirror_triggers.sql
  mig 20261102120000_kan711_events_backfill.sql
  echo "== [$DB] KAN-711 backfill + validate"
  psql_db -c 'CALL public.kan711_events_backfill_run();' -c 'SELECT public.kan711_events_validate_links();' >/dev/null
  mig 20261103100000_kan712_events_write_contract.sql
  mig 20261103105000_kan844_kan712_contract_flag_set_config.sql
  mig 20261103110000_kan712_cutover.sql
  mig 20261104100000_kan713_access_helpers.sql
  mig 20261104110000_kan713_location_triggers.sql
}

# ---- chain A: k788
base_chain
mig 20261104100100_kan714_b01_views_game_card_my_games.sql
mig 20261104100200_kan714_b02_views_meetup_list_counts.sql
mig 20261104100300_kan714_b03_views_rating_host_metrics.sql
skip  # B04 on k788b
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
run $E/local_harness_kan731.sql  # also gives B11 its profiles.created_at and game_roster.joined_at columns
echo "== [$DB] b11 msg pre-images (generated, $FIX/msg_preimage.sql)"
psql_db -f "$FIX/msg_preimage.sql"
mig 20261104101100_kan714_b11_msg_functions.sql
mig 20261104101200_kan714_b12_feed_notifications_stream.sql
run $E/kan714_b13_analytics_export.sql -v fixture_only=1
mig 20261104101300_kan714_b13_analytics_admin_export_cleanup.sql
mig 20261104101400_kan714_b14_series_rpc_reads.sql
[ "$NEXT" -eq "${#ORDER[@]}" ] || { echo "build_kan788: chain A applied $NEXT of ${#ORDER[@]}" >&2; exit 1; }

# ---- chain B: k788b (B04 on a chain without the KAN-714 harness)
DB=k788b
NEXT=0
base_chain
for _ in 1 2 3; do skip; done  # B01..B03 on k788
run $E/kan714_b04_nearby_following.sql -v mode=harness
mig 20261104100400_kan714_b04_rpc_nearby_following.sql

echo "build_kan788: all ${#ORDER[@]} KAN-710..714 migrations applied in the decided order on port $PORT (k788 + k788b)"

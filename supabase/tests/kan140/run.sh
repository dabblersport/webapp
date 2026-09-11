#!/usr/bin/env bash
# KAN-140 AC2/AC3 probe pack -- pre/post falsifiability run.
#
# Builds a throwaway local Postgres, loads the FULL migration history up to
# (but excluding) KAN-140's own migration -- reconstructing the CURRENT live
# schema exactly, same discipline as supabase/tests/kan128/run.sh -- runs the
# probe pack BEFORE the fix (must fail on public.bookings), applies KAN-140's
# migration, and runs the SAME pack again (must pass). Nothing here touches
# wtncuzcskpigqpmnxwws.
#
# Two repo migration files are deliberately EXCLUDED from the load, because
# neither has ever been applied to production (confirmed against the live
# ledger, 2026-09-11):
#   - 20260910090000_kan130_kan131_wallets_owner_and_platform_identity_migration.sql
#     (superseded gated file; KAN-131 landed alone under T-072 instead)
#   - kan186_profile_fk_cascade_part_a.sql (no version prefix -- held, unapplied)
# Loading either would fabricate a schema state production never had.
#
#   usage: bash supabase/tests/kan140/run.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIG="$HERE/../../migrations"
C=kan140pg
FIX_FILE="20260911174052_kan140_trgfn_payment_to_ledger_venue_resolution.sql"
EXCLUDE_PATTERN='^(20260910090000_kan130_kan131_wallets_owner_and_platform_identity_migration\.sql|kan186_profile_fk_cascade_part_a\.sql)$'

docker rm -f "$C" >/dev/null 2>&1 || true
docker run -d --name "$C" -e POSTGRES_PASSWORD=pg supabase/postgres:15.8.1.060 >/dev/null
for _ in $(seq 1 90); do docker exec "$C" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 2; done

docker cp "$HERE/00_harness_prelude.sql" "$C:/tmp/00.sql" >/dev/null
docker cp "$HERE/10_fixtures.sql"        "$C:/tmp/10.sql" >/dev/null
docker cp "$HERE/20_probe.sql"           "$C:/tmp/20.sql" >/dev/null

psql_() { docker exec -u postgres "$C" psql "$@"; }

psql_ -q -v ON_ERROR_STOP=1 -f /tmp/00.sql >/dev/null

# ---------------------------------------------------- load history up to KAN-140
echo "Loading full migration history up to (excluding) KAN-140's own migration..."
i=0
while IFS= read -r f; do
  [[ "$(basename "$f")" == "$FIX_FILE" ]] && break
  docker cp "$f" "$C:/tmp/mig_$i.sql" >/dev/null
  errs="$(psql_ -q -f "/tmp/mig_$i.sql" 2>&1 | grep -cE '^ERROR' || true)"
  if [[ "$errs" -ne 0 ]]; then
    echo "FAIL: $(basename "$f") produced $errs error(s) loading into the harness." >&2
    docker exec -u postgres "$C" psql -f "/tmp/mig_$i.sql" 2>&1 | grep -E '^ERROR' >&2 || true
    exit 1
  fi
  i=$((i + 1))
done < <(find "$MIG" -maxdepth 1 -name '*.sql' -exec basename {} \; \
          | grep -vE "$EXCLUDE_PATTERN" | sort | sed "s#^#$MIG/#")
echo "Loaded $i pre-KAN-140 migration(s), 0 errors."

psql_ -q -v ON_ERROR_STOP=1 -f /tmp/10.sql

echo "=============== PRE-FIX (must FAIL on public.bookings) ==============="
psql_ -f /tmp/20.sql 2>&1 | grep -E "OBSERVED|CONSEQUENCE" | sed 's/^psql[^ ]* NOTICE:  //'

echo
echo "Applying KAN-140's own migration..."
docker cp "$MIG/$FIX_FILE" "$C:/tmp/kan140.sql" >/dev/null
psql_ -q -v ON_ERROR_STOP=1 -f /tmp/kan140.sql >/dev/null

echo
echo "=============== POST-FIX (must PASS, all three ledger rows) =========="
psql_ -f /tmp/20.sql 2>&1 | grep -E "OBSERVED|CONSEQUENCE" | sed 's/^psql[^ ]* NOTICE:  //'

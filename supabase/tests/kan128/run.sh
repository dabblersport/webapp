#!/usr/bin/env bash
# KAN-128 AC 3 probe pack — pre/post falsifiability run.
#
# Builds a throwaway local Postgres, loads the baseline schema into it, runs the
# probe pack BEFORE the migration (every probe must fail), applies the migration,
# and runs the SAME pack again (every runnable probe must pass). Nothing here
# touches wtncuzcskpigqpmnxwws.
#
# Base image is supabase/postgres, which ships the supabase roles, the auth
# schema, auth.users and auth.uid() — so the harness differs from the deployed
# database only in the extensions the --schema-only dump omits (see
# 00_harness_prelude.sql) and in the platform tables no probe touches.
#
#   usage: bash supabase/tests/kan128/run.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIG="$HERE/../../migrations"
C=kan128pg

docker rm -f "$C" >/dev/null 2>&1 || true
docker run -d --name "$C" -e POSTGRES_PASSWORD=pg supabase/postgres:15.8.1.060 >/dev/null
for _ in $(seq 1 90); do docker exec "$C" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 2; done

docker cp "$HERE/00_harness_prelude.sql" "$C:/tmp/00.sql" >/dev/null
docker cp "$HERE/10_fixtures.sql"        "$C:/tmp/10.sql" >/dev/null
docker cp "$HERE/20_probes.sql"          "$C:/tmp/20.sql" >/dev/null
docker cp "$MIG/20260829080500_baseline_schema.sql" "$C:/tmp/baseline.sql" >/dev/null
docker cp "$MIG/20260909090000_kan128_ledger_unique_keys_and_on_conflict.sql" "$C:/tmp/kan128.sql" >/dev/null

psql_() { docker exec -u postgres "$C" psql "$@"; }

psql_ -q -v ON_ERROR_STOP=1 -f /tmp/00.sql >/dev/null
echo "baseline load errors: $(psql_ -q -f /tmp/baseline.sql 2>&1 | grep -cE '^ERROR' || true)"
psql_ -q -v ON_ERROR_STOP=1 -f /tmp/10.sql >/dev/null

echo "=============== PRE-MIGRATION (every probe must FAIL) ==============="
psql_ -f /tmp/20.sql 2>&1 | grep -E "OBSERVED|CONSEQUENCE" | sed 's/^psql[^ ]* NOTICE:  //'

psql_ -q -c "alter table public.wallet_ledger disable trigger trg_wallet_ledger_recalc;
             delete from public.wallet_ledger; delete from public.financial_ledger;
             alter table public.wallet_ledger enable trigger trg_wallet_ledger_recalc;"
psql_ -q -v ON_ERROR_STOP=1 -f /tmp/kan128.sql >/dev/null

echo "=============== POST-MIGRATION (every runnable probe must PASS) ====="
psql_ -f /tmp/20.sql 2>&1 | grep -E "OBSERVED|CONSEQUENCE" | sed 's/^psql[^ ]* NOTICE:  //'

echo "=============== admin_wallet_adjust ACL (expect authenticated + service_role only)"
psql_ -tAc "select proacl from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and proname='admin_wallet_adjust'"

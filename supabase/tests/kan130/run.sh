#!/usr/bin/env bash
# KAN-130 probe pack — pre/post falsifiability run.
#
# Builds a throwaway local Postgres, loads the LIVE public schema of
# wtncuzcskpigqpmnxwws into it, runs the probe pack BEFORE the migration (the
# falsifiable probes must fail), applies the migration, and runs the SAME pack
# again (every runnable probe must pass).
#
# NOTHING HERE WRITES TO wtncuzcskpigqpmnxwws. The only remote operation is
# `supabase db dump`, which is read-only. Every DDL and DML statement in this
# run executes inside a disposable container.
#
# WHY THE LIVE SCHEMA AND NOT 20260829080500_baseline_schema.sql
# The repo's migration ledger and the remote's have diverged: 25 of 28 repo
# migration files are unknown to the remote, and several remote versions were
# applied through MCP and exist in no repo file. So neither "baseline" nor
# "baseline + the repo files" reconstructs the deployed database. A live dump
# is the only base that does. This is the same reason T-058 requires function
# bodies to be authored from the live catalogue rather than from migration text.
#
#   usage:  bash supabase/tests/kan130/run.sh
#           KAN130_LIVE_SCHEMA=/path/to/live_public.sql bash .../run.sh
#
# The second form reuses a dump already taken (and is what to use from a
# worktree, which is not `supabase link`ed — take the dump from the integration
# checkout, then point this at it).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIG="$HERE/../../migrations"
KAN130_SQL="$MIG/20260910090000_kan130_kan131_wallets_owner_and_platform_identity_migration.sql"
C=kan130pg
IMG=supabase/postgres:15.8.1.060

if [[ -z "${KAN130_LIVE_SCHEMA:-}" ]]; then
  KAN130_LIVE_SCHEMA="$(mktemp -t kan130_live_XXXX).sql"
  echo "--- taking a READ-ONLY live schema dump of wtncuzcskpigqpmnxwws"
  supabase db dump --schema public -f "$KAN130_LIVE_SCHEMA"
fi
echo "--- live schema base: $KAN130_LIVE_SCHEMA ($(wc -l < "$KAN130_LIVE_SCHEMA") lines)"

[[ -f "$KAN130_SQL" ]] || { echo "missing migration: $KAN130_SQL" >&2; exit 1; }

docker rm -f "$C" >/dev/null 2>&1 || true
docker run -d --name "$C" -e POSTGRES_PASSWORD=pg "$IMG" >/dev/null
# pg_isready goes green BEFORE the image's own init scripts have finished
# creating pg_graphql / pg_net / PostgREST plumbing. Loading a schema into that
# window leaves pg_graphql half-built, and its DDL event trigger then aborts
# every subsequent statement with "could not open relation with OID ..." from
# graphql.increment_schema_version. That is a harness race, not a finding about
# the migration -- so wait for the init to be OBSERVABLY complete, not merely
# for the socket to answer.
for _ in $(seq 1 90); do docker exec "$C" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 2; done
for _ in $(seq 1 60); do
  [[ "$(docker exec -u postgres "$C" psql -XAtc \
        "select count(*) from pg_extension where extname in ('pg_graphql','pg_net','pgcrypto')" \
        2>/dev/null)" == "3" ]] && break
  sleep 2
done
sleep 3

docker cp "$HERE/00_harness_prelude.sql" "$C:/tmp/00.sql" >/dev/null
docker cp "$KAN130_LIVE_SCHEMA"          "$C:/tmp/live.sql" >/dev/null
docker cp "$HERE/10_fixtures.sql"        "$C:/tmp/10.sql" >/dev/null
docker cp "$HERE/20_probes.sql"          "$C:/tmp/20.sql" >/dev/null
docker cp "$KAN130_SQL"                  "$C:/tmp/kan130.sql" >/dev/null

psql_() { docker exec -u postgres "$C" psql "$@"; }

psql_ -q -v ON_ERROR_STOP=1 -f /tmp/00.sql >/dev/null
echo "live schema load errors: $(psql_ -q -f /tmp/live.sql 2>&1 | grep -cE '^ERROR' || true)"
psql_ -q -v ON_ERROR_STOP=1 -f /tmp/10.sql >/dev/null

echo
echo "=============== PRE-MIGRATION (the falsifiable probes must FAIL) ==========="
{ psql_ -f /tmp/20.sql 2>&1 | grep -E "OBSERVED|CONSEQUENCE|EXPECT:|NOTE:|^ *(wallets|function|inbound)" || true; } \
  | sed 's/^psql[^ ]* NOTICE:  //'

echo
echo "--- applying 20260910090000_kan130_kan131_... (one transaction)"
psql_ -q -v ON_ERROR_STOP=1 -f /tmp/kan130.sql

echo
echo "=============== POST-MIGRATION (every runnable probe must PASS) ==========="
{ psql_ -f /tmp/20.sql 2>&1 | grep -E "OBSERVED|CONSEQUENCE|EXPECT:|NOTE:|^ *(wallets|function|inbound)" || true; } \
  | sed 's/^psql[^ ]* NOTICE:  //'

echo
echo "=============== FULL CATALOGUE ASSERTIONS (post) =========================="
{ psql_ -f /tmp/20.sql 2>&1 | sed -n '/CATALOGUE ASSERTIONS/,$p' | grep -vE "OBSERVED|NOTICE" || true; }

echo
echo "--- container '$C' left running for inspection; remove with: docker rm -f $C"

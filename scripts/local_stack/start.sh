#!/usr/bin/env bash
# KAN-791: start the local app-level stack — throwaway PG16 + Events chain + PostgREST + GoTrue + Realtime.
# LOCAL THROWAWAY ONLY. No Docker, no supabase CLI, no hosted service, never the production project.
#
#   bash scripts/local_stack/start.sh            # start, or reuse a healthy running stack
#   bash scripts/local_stack/start.sh --restart  # tear down whatever is there, then start fresh
#
# Location: $KAN791_HOME (default $TMPDIR/kan791). Prints base URLs and dev keys at the end, and writes
# them to $KAN791_HOME/run/stack.env (chmod 600) so smoke.sh and other tests can `source` it.
# The JWT secret is generated fresh on every start and exists only under $KAN791_HOME/run.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

RESTART=0
[ "${1:-}" = "--restart" ] && RESTART=1

print_state() {
  # shellcheck disable=SC1090
  . "$STATE"
  cat <<EOF

KAN-791 local stack (KAN791_HOME=$KAN791_HOME)
  Postgres   postgresql://postgres@127.0.0.1:$PG_PORT/$DBNAME   (socket dir $SOCK)
  PostgREST  $POSTGREST_URL        (admin $POSTGREST_ADMIN_URL/ready)
  GoTrue     $GOTRUE_URL         (health $GOTRUE_URL/health)
  Realtime   $REALTIME_STATUS  ${REALTIME_URL:-}  tenant=${REALTIME_TENANT:-}
             ${REALTIME_NOTE:-}
  anon key         $ANON_KEY
  service_role key $SERVICE_KEY
  env file   $STATE   (source it; contains the per-run JWT secret)
EOF
}

# ---------------------------------------------------------------- idempotency: reuse or restart
stack_healthy() {
  [ -f "$STATE" ] || return 1
  # shellcheck disable=SC1090
  . "$STATE"
  "$PG_BIN/pg_isready" -q -h "$SOCK" -p "$PG_PORT" || return 1
  curl -fsS -o /dev/null "$POSTGREST_ADMIN_URL/ready" || return 1
  curl -fsS -o /dev/null "$GOTRUE_URL/health" || return 1
  if [ "$REALTIME_STATUS" = "RUNNING" ]; then
    curl -fsS -o /dev/null "$REALTIME_URL/healthcheck" || return 1
  fi
  return 0
}

if [ "$RESTART" = 0 ] && stack_healthy; then
  log "a healthy stack is already running; reusing it (use --restart for a fresh one)"
  print_state
  exit 0
fi
if [ -e "$RUN" ]; then
  log "existing run directory is stale, partial or restart requested; tearing it down first"
  bash "$HERE/teardown.sh"
fi

# ---------------------------------------------------------------- components (cached under $DL)
mkdir -p "$DL"
ensure_postgrest() {
  [ -x "$POSTGREST_BIN" ] && return 0
  log "downloading PostgREST $POSTGREST_VERSION (release binary)"
  mkdir -p "$DL/postgrest"
  curl -fsSL -o "$DL/postgrest.tar.xz" \
    "https://github.com/PostgREST/postgrest/releases/download/$POSTGREST_VERSION/postgrest-$POSTGREST_VERSION-macos-aarch64.tar.xz"
  tar -xJf "$DL/postgrest.tar.xz" -C "$DL/postgrest"
}
ensure_gotrue() {
  [ -x "$GOTRUE_BIN" ] && return 0
  log "downloading GoTrue (supabase/auth) $GOTRUE_VERSION (release binary + migrations)"
  mkdir -p "$GOTRUE_DIR"
  curl -fsSL -o "$DL/auth.tar.gz" \
    "https://github.com/supabase/auth/releases/download/$GOTRUE_VERSION/auth-$GOTRUE_VERSION-darwin-arm64.tar.gz"
  tar -xzf "$DL/auth.tar.gz" -C "$GOTRUE_DIR"
}
ensure_wal2json() {
  [ -f "$WAL2JSON_DIR/wal2json.dylib" ] && return 0
  log "building wal2json $WAL2JSON_TAG from source (not installed; loaded through dynamic_library_path)"
  git clone -q -c advice.detachedHead=false --depth 1 --branch "$WAL2JSON_TAG" https://github.com/eulerto/wal2json.git "$WAL2JSON_DIR"
  make -C "$WAL2JSON_DIR" PG_CONFIG="$PG_BIN/pg_config" >/dev/null
}
ensure_realtime() { # returns 1 with REALTIME_NOTE set if Realtime cannot be built here
  [ -x "$REALTIME_REL/bin/realtime" ] && return 0
  if ! command -v mix >/dev/null 2>&1; then
    REALTIME_NOTE="Elixir/Erlang not installed (mix not on PATH); Realtime needs them to build. brew install elixir"
    return 1
  fi
  log "building Realtime $REALTIME_VERSION from source (MIX_ENV=prod mix release); takes several minutes"
  [ -d "$REALTIME_SRC" ] || git clone -q -c advice.detachedHead=false --depth 1 --branch "$REALTIME_VERSION" \
    https://github.com/supabase/realtime.git "$REALTIME_SRC"
  if ! ( cd "$REALTIME_SRC" && export MIX_ENV=prod HEX_HOME="$DL/hex" MIX_HOME="$DL/mixhome" \
         && mix local.hex --force && mix local.rebar --force && mix deps.get --only prod \
         && mix compile && mix release --overwrite ) > "$DL/realtime_build.log" 2>&1; then
    REALTIME_NOTE="Realtime build failed; see $DL/realtime_build.log: $(tail -1 "$DL/realtime_build.log")"
    return 1
  fi
}
ensure_postgrest
ensure_gotrue
ensure_wal2json
REALTIME_NOTE=""
REALTIME_OK=1
ensure_realtime || REALTIME_OK=0

# libpq for the PostgREST macOS binary (linked against /opt/homebrew/opt/libpq, absent here).
export DYLD_LIBRARY_PATH="$("$PG_BIN/pg_config" --libdir)${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

# ---------------------------------------------------------------- per-run secret, ports, keys
mkdir -p "$RUN" "$SOCK" "$LOGS" "$PIDS"
chmod 700 "$RUN"
JWT_SECRET="$(openssl rand -hex 32)"
PG_PORT="$(free_port)"; PGRST_PORT="$(free_port)"; PGRST_ADMIN_PORT="$(free_port)"
GOTRUE_PORT="$(free_port)"; RT_PORT="$(free_port)"; RT_GENRPC_PORT="$(free_port)"; RT_EPMD_PORT="$(free_port)"
NOW="$(date +%s)"; EXP=$((NOW + 10 * 365 * 24 * 3600))
ANON_KEY="$(make_jwt "$JWT_SECRET" "{\"iss\":\"kan791-local\",\"role\":\"anon\",\"iat\":$NOW,\"exp\":$EXP}")"
SERVICE_KEY="$(make_jwt "$JWT_SECRET" "{\"iss\":\"kan791-local\",\"role\":\"service_role\",\"iat\":$NOW,\"exp\":$EXP}")"

# ---------------------------------------------------------------- Postgres 16
log "initdb PG16 at $PGDATA_DIR, port $PG_PORT (wal_level=logical)"
"$PG_BIN/initdb" -D "$PGDATA_DIR" -U postgres -A trust --no-instructions >/dev/null
cat >> "$PGDATA_DIR/postgresql.conf" <<EOF
# KAN-791 local stack
port = $PG_PORT
listen_addresses = '127.0.0.1'
unix_socket_directories = '$SOCK'
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10
max_connections = 200
dynamic_library_path = '\$libdir:$WAL2JSON_DIR'
# This PG16 build only allows listed libraries as logical decoding output plugins (default
# 'pgoutput, test_decoding'). Realtime's postgres_changes decodes with wal2json.
output_plugin_libraries = 'pgoutput, test_decoding, wal2json'
EOF
"$PG_BIN/pg_ctl" -D "$PGDATA_DIR" -l "$LOGS/postgres.log" -w start >/dev/null
head -1 "$PGDATA_DIR/postmaster.pid" > "$PIDS/postgres.pid"
PSQL=("$PG_BIN/psql" -X -q -v ON_ERROR_STOP=1 -h "$SOCK" -p "$PG_PORT" -U postgres -d "$DBNAME")
"${PSQL[@]}" -f "$HERE/stack_roles.sql" >/dev/null

# ---------------------------------------------------------------- GoTrue env (also runs its migrations)
DB_URL="postgres://postgres@127.0.0.1:$PG_PORT/$DBNAME?sslmode=disable"
GOTRUE_ENV=(env -i PATH="$PATH" HOME="$HOME" \
    GOTRUE_DB_DRIVER=postgres DATABASE_URL="$DB_URL&search_path=auth" GOTRUE_DB_NAMESPACE=auth \
    GOTRUE_DB_MIGRATIONS_PATH="$GOTRUE_DIR/migrations" \
    GOTRUE_API_HOST=127.0.0.1 PORT="$GOTRUE_PORT" API_EXTERNAL_URL="http://127.0.0.1:$GOTRUE_PORT" \
    GOTRUE_SITE_URL="http://127.0.0.1:3000" GOTRUE_URI_ALLOW_LIST="*" \
    GOTRUE_JWT_SECRET="$JWT_SECRET" GOTRUE_JWT_EXP=3600 GOTRUE_JWT_AUD=authenticated \
    GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated GOTRUE_JWT_ADMIN_ROLES=service_role \
    GOTRUE_DISABLE_SIGNUP=false GOTRUE_EXTERNAL_EMAIL_ENABLED=true GOTRUE_MAILER_AUTOCONFIRM=true \
    GOTRUE_EXTERNAL_PHONE_ENABLED=false GOTRUE_SMS_AUTOCONFIRM=false \
    GOTRUE_RATE_LIMIT_EMAIL_SENT=1000 GOTRUE_LOG_LEVEL=info)
log "GoTrue $GOTRUE_VERSION: running its auth-schema migrations"
( cd "$GOTRUE_DIR" && "${GOTRUE_ENV[@]}" "$GOTRUE_BIN" migrate ) > "$LOGS/gotrue_migrate.log" 2>&1 \
  || { tail -20 "$LOGS/gotrue_migrate.log" >&2; die "GoTrue migrate failed"; }

# ---------------------------------------------------------------- the Events chain
log "applying the Events migration chain (several minutes)"
bash "$HERE/apply_chain.sh" "$SOCK" "$PG_PORT" "$DBNAME" "$RUN/applied_chain.txt" >&2
"${PSQL[@]}" -f "$HERE/stack_shim.sql" >/dev/null

# ---------------------------------------------------------------- PostgREST
log "starting PostgREST $POSTGREST_VERSION on $PGRST_PORT"
# Not through env(1) or nohup(1): both are SIP-protected and strip DYLD_LIBRARY_PATH.
( trap '' HUP
  export PGRST_DB_URI="postgres://authenticator@127.0.0.1:$PG_PORT/$DBNAME?sslmode=disable" \
    PGRST_DB_SCHEMAS="public,local_stack" PGRST_DB_ANON_ROLE=anon PGRST_JWT_SECRET="$JWT_SECRET" \
    PGRST_SERVER_HOST=127.0.0.1 PGRST_SERVER_PORT="$PGRST_PORT" \
    PGRST_ADMIN_SERVER_HOST=127.0.0.1 PGRST_ADMIN_SERVER_PORT="$PGRST_ADMIN_PORT" \
    PGRST_DB_CHANNEL_ENABLED=true PGRST_LOG_LEVEL=info
  exec "$POSTGREST_BIN" ) > "$LOGS/postgrest.log" 2>&1 < /dev/null &
echo $! > "$PIDS/postgrest.pid"

# ---------------------------------------------------------------- GoTrue
log "starting GoTrue $GOTRUE_VERSION on $GOTRUE_PORT"
( cd "$GOTRUE_DIR" && trap '' HUP && exec "${GOTRUE_ENV[@]}" "$GOTRUE_BIN" serve ) > "$LOGS/gotrue.log" 2>&1 < /dev/null &
echo $! > "$PIDS/gotrue.pid"

wait_http "http://127.0.0.1:$PGRST_ADMIN_PORT/ready" 60 || { tail -20 "$LOGS/postgrest.log" >&2; die "PostgREST not ready"; }
log "PostgREST ready"
wait_http "http://127.0.0.1:$GOTRUE_PORT/health" 60 || { tail -20 "$LOGS/gotrue.log" >&2; die "GoTrue not healthy"; }
log "GoTrue healthy"

# ---------------------------------------------------------------- Realtime
REALTIME_STATUS="NOT_RUN"; REALTIME_TENANT="realtime-dev"; REALTIME_URL=""
RT_ENV=(env -i PATH="$PATH" HOME="$HOME" LANG=en_US.UTF-8 \
    APP_NAME=realtime NODE_NAME=kan791rt MIX_ENV=prod PORT="$RT_PORT" REALTIME_IP_VERSION=ipv4 \
    DB_HOST=127.0.0.1 DB_PORT="$PG_PORT" DB_USER=postgres DB_PASSWORD=postgres DB_NAME="$DBNAME" \
    DB_AFTER_CONNECT_QUERY='SET search_path TO _realtime' DB_ENC_KEY="$(printf '%s' "$JWT_SECRET" | cut -c1-16)" \
    API_JWT_SECRET="$JWT_SECRET" METRICS_JWT_SECRET="$JWT_SECRET" SECRET_KEY_BASE="$JWT_SECRET$JWT_SECRET" \
    SELF_HOST_TENANT_NAME="$REALTIME_TENANT" SEED_SELF_HOST=true RUN_JANITOR=false \
    ERL_AFLAGS="-proto_dist inet_tcp" ERL_EPMD_PORT="$RT_EPMD_PORT" DNS_NODES="" CLUSTER_STRATEGIES=POSTGRES \
    GEN_RPC_TCP_SERVER_PORT="$RT_GENRPC_PORT" GEN_RPC_TCP_CLIENT_PORT="$RT_GENRPC_PORT" GEN_RPC_SOCKET_IP=127.0.0.1 \
    RELEASE_TMP="$RUN/realtime_tmp" LOG_LEVEL=info)
if [ "$REALTIME_OK" = 1 ]; then
  mkdir -p "$RUN/realtime_tmp"
  "${PSQL[@]}" -f "$HERE/realtime_prep.sql" >/dev/null
  log "Realtime $REALTIME_VERSION: metadata migrations + self-host tenant seed"
  if "${RT_ENV[@]}" "$REALTIME_REL/bin/migrate" > "$LOGS/realtime_migrate.log" 2>&1 \
     && "${RT_ENV[@]}" "$REALTIME_REL/bin/realtime" eval 'Realtime.Release.seeds(Realtime.Repo)' > "$LOGS/realtime_seed.log" 2>&1 \
     && [ "$("${PSQL[@]}" -At -c "SELECT count(*) FROM _realtime.tenants WHERE external_id = '$REALTIME_TENANT'")" = 1 ] \
     && [ "$("${PSQL[@]}" -At -c "SELECT count(*) > 0 FROM realtime.schema_migrations")" = t ]; then
    log "starting Realtime on $RT_PORT"
    ( trap '' HUP; exec "${RT_ENV[@]}" "$REALTIME_REL/bin/realtime" start ) > "$LOGS/realtime.log" 2>&1 < /dev/null &
    echo $! > "$PIDS/realtime.pid"
    if wait_http "http://127.0.0.1:$RT_PORT/healthcheck" 90; then
      REALTIME_STATUS="RUNNING"; REALTIME_URL="http://127.0.0.1:$RT_PORT"
      log "Realtime healthy"
    else
      REALTIME_NOTE="Realtime did not answer /healthcheck in 90s: $(tail -3 "$LOGS/realtime.log" | tr '\n' ' ')"
    fi
  else
    REALTIME_NOTE="Realtime migrate/seed failed: $(tail -3 "$LOGS"/realtime_migrate.log "$LOGS"/realtime_seed.log 2>/dev/null | tr '\n' ' ')"
  fi
fi
[ "$REALTIME_STATUS" = "RUNNING" ] || log "Realtime NOT RUN: $REALTIME_NOTE"

# ---------------------------------------------------------------- state file
umask 077
cat > "$STATE" <<EOF
# KAN-791 local stack state. Per-run values; regenerated on every start. NEVER COMMIT.
KAN791_HOME='$KAN791_HOME'
PG_PORT='$PG_PORT'
PG_SOCK='$SOCK'
PG_DB='$DBNAME'
PG_URL='postgresql://postgres@127.0.0.1:$PG_PORT/$DBNAME'
POSTGREST_URL='http://127.0.0.1:$PGRST_PORT'
POSTGREST_ADMIN_URL='http://127.0.0.1:$PGRST_ADMIN_PORT'
GOTRUE_URL='http://127.0.0.1:$GOTRUE_PORT'
REALTIME_STATUS='$REALTIME_STATUS'
REALTIME_URL='$REALTIME_URL'
REALTIME_TENANT='$REALTIME_TENANT'
REALTIME_EPMD_PORT='$RT_EPMD_PORT'
REALTIME_NOTE='$(printf '%s' "$REALTIME_NOTE" | tr -d "'")'
JWT_SECRET='$JWT_SECRET'
ANON_KEY='$ANON_KEY'
SERVICE_KEY='$SERVICE_KEY'
EOF
print_state

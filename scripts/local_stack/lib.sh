# shellcheck shell=bash
# KAN-791 local app-level stack: shared settings. Sourced by start.sh, teardown.sh and smoke.sh.
# LOCAL THROWAWAY ONLY. Nothing here may ever point at a hosted Supabase project.

# Where everything lives. Never inside the repository.
#   KAN791_HOME/dl   downloads, binaries and builds (a cache; kept between runs, never data)
#   KAN791_HOME/run  the running stack: PG data dir, sockets, logs, pids, per-run secret (deleted by teardown)
KAN791_HOME="${KAN791_HOME:-${TMPDIR:-/tmp}/kan791}"
KAN791_HOME="${KAN791_HOME%/}"
DL="$KAN791_HOME/dl"
RUN="$KAN791_HOME/run"
PGDATA_DIR="$RUN/pgdata"
SOCK="$RUN/sock"
LOGS="$RUN/logs"
PIDS="$RUN/pids"
STATE="$RUN/stack.env"          # ports, URLs, the per-run JWT secret and keys. chmod 600, never committed.

PG_BIN="${PG_BIN:-/opt/homebrew/opt/postgresql@16/bin}"
GO_BIN="${GO_BIN:-/usr/local/go/bin/go}"
DBNAME=postgres

# Pinned component versions.
POSTGREST_VERSION=v16.5
GOTRUE_VERSION=v2.197.0
REALTIME_VERSION=v2.152.0
WAL2JSON_TAG=wal2json_2_6

POSTGREST_BIN="$DL/postgrest/postgrest"
GOTRUE_DIR="$DL/auth"
GOTRUE_BIN="$GOTRUE_DIR/auth"
REALTIME_SRC="$DL/realtime-src"
REALTIME_REL="$REALTIME_SRC/_build/prod/rel/realtime"
WAL2JSON_DIR="$DL/wal2json-src"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

log() { printf '[local_stack] %s\n' "$*" >&2; }
die() { printf '[local_stack] ERROR: %s\n' "$*" >&2; exit 1; }

# A free TCP port on 127.0.0.1 that is not 5432.
free_port() {
  python3 -I -c '
import socket
while True:
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close()
    if p != 5432: print(p); break'
}

pid_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }

# HS256 JWT signed with the per-run secret. $1 = secret, $2 = JSON payload.
make_jwt() {
  python3 -I -c '
import base64, hmac, hashlib, json, sys
b = lambda x: base64.urlsafe_b64encode(x).rstrip(b"=").decode()
h = b(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
p = b(json.dumps(json.loads(sys.argv[2]), separators=(",", ":")).encode())
s = b(hmac.new(sys.argv[1].encode(), (h + "." + p).encode(), hashlib.sha256).digest())
print(h + "." + p + "." + s)' "$1" "$2"
}

# Wait until $1 (curl args after it) returns HTTP 2xx, up to $2 seconds.
wait_http() {
  local url="$1" secs="$2"; shift 2
  local i=0
  while [ "$i" -lt "$secs" ]; do
    if curl -fsS -o /dev/null "$@" "$url" 2>/dev/null; then return 0; fi
    i=$((i + 1)); sleep 1
  done
  return 1
}

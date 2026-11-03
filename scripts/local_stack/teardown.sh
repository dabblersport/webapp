#!/usr/bin/env bash
# KAN-791: tear down the local stack. Idempotent: a second run finds nothing and says so.
#   bash scripts/local_stack/teardown.sh
# Stops Realtime, GoTrue, PostgREST (tracked PIDs, then a sweep for anything still running from
# $KAN791_HOME), stops the PG16 cluster, deletes $KAN791_HOME/run (data dir, logs, secret), and
# verifies that no stack process and no run/data directory remains. The download cache ($KAN791_HOME/dl)
# holds binaries only and is kept; pass --purge-cache to delete it as well.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

stop_pid() { # <name> <pid>
  local name="$1" pid="$2" i=0
  pid_alive "$pid" || return 0
  log "stopping $name (pid $pid)"
  kill -TERM "$pid" 2>/dev/null
  while pid_alive "$pid" && [ "$i" -lt 20 ]; do sleep 0.5; i=$((i + 1)); done
  pid_alive "$pid" && { log "$name did not exit on TERM; KILL"; kill -KILL "$pid" 2>/dev/null; }
  return 0
}

# Processes whose command line contains this stack's home. Scoped: nothing else on the machine matches.
stack_procs() { pgrep -f -- "$KAN791_HOME/" 2>/dev/null || true; }

if [ -d "$PIDS" ]; then
  for n in realtime gotrue postgrest; do
    [ -f "$PIDS/$n.pid" ] && stop_pid "$n" "$(cat "$PIDS/$n.pid")"
  done
fi
EPMD_PORT=""
[ -f "$STATE" ] && EPMD_PORT="$(sed -n "s/^REALTIME_EPMD_PORT='\(.*\)'$/\1/p" "$STATE")"

if [ -f "$PGDATA_DIR/postmaster.pid" ]; then
  log "stopping PG16 cluster at $PGDATA_DIR"
  "$PG_BIN/pg_ctl" -D "$PGDATA_DIR" -m fast -w stop >/dev/null 2>&1 \
    || "$PG_BIN/pg_ctl" -D "$PGDATA_DIR" -m immediate -w stop >/dev/null 2>&1 || true
fi

# Sweep: anything still running from this stack's home (beam children, heart, a crashed restart).
for pid in $(stack_procs); do stop_pid "stack process" "$pid"; done
# The epmd that Realtime's Erlang VM started on this stack's private port.
if [ -n "$EPMD_PORT" ]; then
  # epmd -daemon does not carry the port on its command line; find it by its listening socket.
  for pid in $(lsof -nP -t -iTCP:"$EPMD_PORT" -sTCP:LISTEN 2>/dev/null); do
    stop_pid "epmd (port $EPMD_PORT)" "$pid"
  done
  ERL_EPMD_PORT="$EPMD_PORT" epmd -kill >/dev/null 2>&1 || true
fi

if [ -e "$RUN" ]; then
  log "deleting $RUN"
  rm -rf "$RUN"
fi
if [ "${1:-}" = "--purge-cache" ] && [ -e "$DL" ]; then
  log "deleting download cache $DL"
  rm -rf "$DL"
fi

# ---------------------------------------------------------------- verify
FAIL=0
LEFT="$(stack_procs)"
if [ -n "$LEFT" ]; then
  log "FAIL: stack processes remain:"; ps -o pid=,command= -p "$(echo "$LEFT" | paste -sd, -)" >&2; FAIL=1
fi
if [ -n "$EPMD_PORT" ] && lsof -nP -iTCP:"$EPMD_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  log "FAIL: epmd still listening on $EPMD_PORT"; FAIL=1
fi
if [ -e "$RUN" ]; then log "FAIL: $RUN still exists"; FAIL=1; fi
if [ "$FAIL" = 0 ]; then
  log "teardown OK: no stack process, no run/data directory under $KAN791_HOME"
fi
exit "$FAIL"

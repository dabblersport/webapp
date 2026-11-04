#!/usr/bin/env bash
# KAN-860 (KAN-718 F7): the KAN-807 proof, from TRACKED files only.
# LOCAL THROWAWAY POSTGRES ONLY. NEVER POINT THIS AT SUPABASE.
#
# kan807_d04_residual_test.sql runs "on a database cloned from the KAN-781 judge chain + D04 (base781_with_d04.sh)".
#   1. supabase/tests/events_p4/base781_with_d04.sh: brand new cluster, that chain, database k772_base781;
#   2. a copy named k807t (the test refuses any database not named k788*/k807*);
#   3. the test, which itself runs the pre / pre_z01 / migrations (20261104110900 + 20261104111000) / post / post_z01
#      phases and must end "KAN-807: ALL PASS".
# The KAN-807 judge (Thebes review evidence KAN-807/judge-97e5e6df/run.sh) also ran 110600_kan799, 110700_kan800 and
# 110800_kan803 on its copy; each refused at its own pre-image guard and changed nothing (its build.log), so they
# are not run here.
#
# Usage (from the repository root):
#   bash supabase/tests/events_p4/build_kan807.sh /tmp/<new-datadir> <port>
# Stop and delete afterwards:
#   pg_ctl -D <datadir> stop -m fast && rm -rf <datadir> <datadir>.log <datadir>.fixtures
set -euo pipefail

DATADIR="${1:?usage: build_kan807.sh <new-datadir> <port>}"
PORT="${2:?usage: build_kan807.sh <new-datadir> <port>}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

bash "$ROOT/supabase/tests/events_p4/base781_with_d04.sh" "$DATADIR" "$PORT"
createdb -h /tmp -p "$PORT" -U postgres -T k772_base781 k807t
echo "== [k807t] kan807_d04_residual_test.sql"
OUT="$(cd "$ROOT" && psql -X -h /tmp -p "$PORT" -U postgres -d k807t -v ON_ERROR_STOP=1 -P pager=off \
         -f supabase/tests/events_p4/kan807_d04_residual_test.sql 2>&1)" || { echo "$OUT" | tail -20; exit 1; }
echo "$OUT" | grep -oE 'KAN-807 [A-Z0-9/]+ (PASS|FAIL).*|KAN-807: ALL PASS'
echo "$OUT" | grep -qx 'KAN-807: ALL PASS' || { echo "build_kan807: test did not end ALL PASS" >&2; exit 1; }
echo "build_kan807: PASS on port $PORT"

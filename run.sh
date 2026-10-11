#!/usr/bin/env bash
#
# Launch the Dabbler app with the required environment injected.
#
# OPTIONAL. After the one-time setup in docs/LOCAL_RUN.md
# (scripts/setup_local_env.sh), plain `flutter run -d <device-id>` works and
# this wrapper is not needed. It still passes the values explicitly via
# --dart-define-from-file, which takes precedence over the local selection.
#
# Any extra args are passed through, e.g.:
#   ./run.sh                       # default device picker
#   ./run.sh -d <device-id>        # specific device
#   ./run.sh --profile             # profile mode
#
set -euo pipefail

# Always operate from the project root (where .env lives), regardless of CWD.
cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "error: .env not found in project root ($(pwd))." >&2
  echo "       Copy .env.example to .env and fill in the values." >&2
  exit 1
fi

exec flutter run --dart-define-from-file=.env "$@"

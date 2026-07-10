#!/usr/bin/env bash
#
# Launch the Dabbler app with the required environment injected.
#
# The app reads SUPABASE_URL / SUPABASE_ANON_KEY / APP_NAME (and other keys)
# from --dart-define. `.env` is intentionally NOT bundled as a Flutter asset
# (it holds real secrets), so a plain `flutter run` boots with empty values,
# Environment.load() throws, and the app hangs on the native splash screen.
#
# Use this instead of `flutter run`. Any extra args are passed through, e.g.:
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

#!/bin/sh
set -eu

# A local client-config selection must never ship in a deployed build.
bash scripts/check_no_local_env.sh

# Fail fast if required env vars are missing
test -n "${SUPABASE_URL:-}" || { echo "ERROR: Missing SUPABASE_URL"; exit 1; }
test -n "${SUPABASE_ANON_KEY:-}" || { echo "ERROR: Missing SUPABASE_ANON_KEY"; exit 1; }
test -n "${APP_NAME:-}" || { echo "ERROR: Missing APP_NAME"; exit 1; }
test -n "${ENVIRONMENT:-}" || { echo "ERROR: Missing ENVIRONMENT"; exit 1; }

# Install Flutter (stable) — cached across builds if $HOME persists
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_HOME"
fi
PATH="$FLUTTER_HOME/bin:$PATH"
export PATH

flutter --version
flutter pub get

# Ensure .env exists as an empty file (required by pubspec asset entry)
: > .env

flutter build web --release \
  --base-href / \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_NAME="$APP_NAME" \
  --dart-define=ENVIRONMENT="$ENVIRONMENT" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}" \
  --dart-define=MESSAGING_API_BASE_URL="${MESSAGING_API_BASE_URL:-}"

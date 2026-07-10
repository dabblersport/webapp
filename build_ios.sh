#!/usr/bin/env bash
#
# Build a release IPA for TestFlight / App Store with the CURRENT .env baked in.
#
# Use this (or an equivalent CI step) for EVERY store build — not a bare
# `flutter build ipa`, which ships empty/stale backend config. This is the
# release-mode sibling of run.sh.
#
# Any extra args are passed through to `flutter build ipa`, e.g.:
#   ./build_ios.sh
#   ./build_ios.sh --export-options-plist=ios/ExportOptions.plist
#
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "error: .env not found in project root ($(pwd))." >&2
  echo "       Copy .env.example to .env and fill in the values." >&2
  exit 1
fi

# Surface which Supabase backend we're about to bake, so a dev/prod mix-up is
# caught BEFORE uploading (this is exactly the bug that once shipped a stale,
# now-paused project to TestFlight).
url="$(grep -E '^SUPABASE_URL=' .env | head -1 | cut -d= -f2-)"
url="${url%\"}"; url="${url#\"}"; url="${url%\'}"; url="${url#\'}"
envname="$(grep -E '^ENVIRONMENT=' .env | head -1 | cut -d= -f2-)"
envname="${envname%\"}"; envname="${envname#\"}"
ref="$(printf '%s' "$url" | sed -E 's#https?://([a-z0-9]+)\..*#\1#')"

echo "──────────────────────────────────────────────────────────"
echo "  Baking Supabase project ref : ${ref:-<unknown>}"
echo "  ENVIRONMENT                 : ${envname:-<unset>}"
echo "  SUPABASE_URL                : ${url:-<unset>}"
echo "──────────────────────────────────────────────────────────"

# Keep the Xcode-archive path in sync too (so a plain Product > Archive bakes
# the same values as this command).
./scripts/gen_dart_defines.sh

exec flutter build ipa --dart-define-from-file=.env "$@"

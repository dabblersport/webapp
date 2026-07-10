#!/usr/bin/env bash
#
# Regenerate ios/Flutter/DartDefines.xcconfig from .env so that ANY iOS build —
# including a plain Xcode "Product > Archive" — bakes the CURRENT Supabase
# backend (and other secrets) via --dart-define, instead of a stale/empty value.
#
# Why this exists: a bare Xcode Archive passes NO Flutter dart-defines. The app
# then boots with empty SUPABASE_URL/ANON_KEY (or whatever a past `flutter build`
# happened to leave in Generated.xcconfig), which once shipped a TestFlight build
# frozen to an old, now-paused Supabase project. This file is regenerated from
# .env at build time and appended AFTER Generated.xcconfig via $(inherited), so
# it augments Flutter's own DART_DEFINES rather than replacing them.
#
# The output file is gitignored (it contains real secrets) — never commit it.
set -euo pipefail

# Xcode runs scheme pre-actions and script phases with a stripped-down PATH,
# so the external tools below (base64, grep, cut, sed, tr) can resolve to
# "command not found" (exit 127). Guarantee the standard system paths.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
ENV_FILE="$ROOT/.env"
OUT="$ROOT/ios/Flutter/DartDefines.xcconfig"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "warning: .env not found at $ENV_FILE — skipping DartDefines.xcconfig." >&2
  echo "         (\`flutter build ipa --dart-define-from-file=.env\` still bakes secrets;" >&2
  echo "          a raw Xcode Archive would ship WITHOUT them.)" >&2
  exit 0
fi

csv=""
count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"                       # strip trailing CR (CRLF files)
  [[ -z "$line" || "$line" == \#* ]] && continue
  line="${line#export }"                     # tolerate `export KEY=...`
  [[ "$line" != *"="* ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  key="$(printf '%s' "$key" | tr -d '[:space:]')"
  [[ -z "$key" ]] && continue
  val="${val%\"}"; val="${val#\"}"           # strip surrounding double quotes
  val="${val%\'}"; val="${val#\'}"           # strip surrounding single quotes
  enc="$(printf '%s' "$key=$val" | base64 | tr -d '\n')"
  if [[ -z "$csv" ]]; then csv="$enc"; else csv="$csv,$enc"; fi
  count=$((count + 1))
done < "$ENV_FILE"

{
  echo "// AUTO-GENERATED from .env by scripts/gen_dart_defines.sh — DO NOT EDIT, DO NOT COMMIT."
  echo "// Appends .env secrets to Flutter's own DART_DEFINES so Xcode archives bake the current backend."
  echo "DART_DEFINES=\$(inherited),$csv"
} > "$OUT"

echo "Wrote ${OUT#$ROOT/} ($count defines from .env)."

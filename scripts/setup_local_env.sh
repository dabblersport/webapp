#!/usr/bin/env bash
#
# One-time local setup so plain `flutter run -d <device-id>` works.
#
# Copies your local client configuration into assets/config/local.env (gitignored),
# which debug/profile runs read when no --dart-define values are supplied.
#
#   scripts/setup_local_env.sh                  # from ./.env
#   scripts/setup_local_env.sh --from <file>    # switch to another selection
#   scripts/setup_local_env.sh --check          # report key NAMES present/missing
#   scripts/setup_local_env.sh --clear          # remove the local selection
#
# Only an allowlist of client-safe keys is copied; every other key is dropped.
# Only key names are ever printed, never values.
set -euo pipefail

cd "$(dirname "$0")/.."
TARGET="assets/config/local.env"
SOURCE=".env"
MODE="write"
REQUIRED=(SUPABASE_URL SUPABASE_ANON_KEY APP_NAME ENVIRONMENT)
# The only keys ever copied into assets/config/local.env (client-safe).
ALLOWED=(SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_PUBLISHABLE_KEY APP_NAME ENVIRONMENT GOOGLE_WEB_CLIENT_ID)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) SOURCE="${2:?--from needs a file}"; shift 2 ;;
    --check) MODE="check"; shift ;;
    --clear) MODE="clear"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

has_key() { grep -Eq "^[[:space:]]*(export[[:space:]]+)?$2[[:space:]]*=[[:space:]]*[^[:space:]#]" "$1"; }

report() {
  local file="$1" missing=()
  for k in "${REQUIRED[@]}"; do
    if has_key "$file" "$k"; then echo "  ok       $k"; else echo "  MISSING  $k"; missing+=("$k"); fi
  done
  [[ ${#missing[@]} -eq 0 ]]
}

case "$MODE" in
  clear)
    rm -f "$TARGET"; echo "Removed $TARGET (plain flutter run will now show the setup message)."; exit 0 ;;
  check)
    if [[ ! -f "$TARGET" ]]; then echo "No local selection: $TARGET does not exist." >&2; exit 1; fi
    echo "Local selection ($TARGET):"; report "$TARGET" || exit 1; exit 0 ;;
esac

if [[ ! -f "$SOURCE" ]]; then
  echo "error: $SOURCE not found." >&2
  echo "       Copy .env.example to .env and fill in the client values, or pass --from <file>." >&2
  exit 1
fi
echo "Checking $SOURCE:"
if ! report "$SOURCE"; then
  echo "error: required keys are missing from $SOURCE (names above)." >&2
  exit 1
fi
mkdir -p "$(dirname "$TARGET")"
: > "$TARGET"
kept=() dropped=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  line="${line#export }"
  [[ "$line" != *"="* ]] && continue
  key="${line%%=*}"; key="${key//[[:space:]]/}"
  allowed=0
  for a in "${ALLOWED[@]}"; do [[ "$key" == "$a" ]] && allowed=1; done
  if [[ $allowed -eq 1 ]]; then
    printf '%s\n' "$line" >> "$TARGET"; kept+=("$key")
  else
    dropped+=("$key")
  fi
done < "$SOURCE"
chmod 600 "$TARGET"
echo "Kept (client-safe):  ${kept[*]:-none}"
echo "Dropped (not copied): ${dropped[*]:-none}"
echo "Wrote $TARGET. Now run: flutter run -d <device-id>"

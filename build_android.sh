#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -f .env ]]; then
  echo 'Missing .env release configuration' >&2
  exit 1
fi
if [[ ! -f android/key.properties ]]; then
  echo 'Missing Android release signing configuration' >&2
  exit 1
fi
exec flutter build appbundle --release --dart-define-from-file=.env "$@"

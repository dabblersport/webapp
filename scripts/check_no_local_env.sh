#!/usr/bin/env bash
#
# Fails when a local client-config selection is present in the build tree.
# Release and CI builds must take their configuration from --dart-define, never
# from assets/config/local.env (which would be bundled into the app / served on
# web). Run this at the start of any release or CI build.
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ -e assets/config/local.env ]]; then
  echo "ERROR: assets/config/local.env exists in the build tree." >&2
  echo "       Release and CI builds must not bundle a local configuration file." >&2
  echo "       Remove it (scripts/setup_local_env.sh --clear) or build from a clean checkout," >&2
  echo "       and pass configuration with --dart-define. See docs/LOCAL_RUN.md." >&2
  exit 1
fi

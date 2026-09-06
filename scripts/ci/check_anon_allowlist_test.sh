#!/usr/bin/env bash
# Self-test for the KAN-61 allowlist diff logic. Runs entirely offline
# against fixture data — no database connection, no production access — so
# it can be run in this sandbox to prove the gate actually catches a
# newly introduced anon-readable definer view, per KAN-61 acceptance
# criterion "prove it fails, not just that it passes."
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./anon_allowlist_diff.sh
source "$SCRIPT_DIR/anon_allowlist_diff.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fixture: the real allowlist as landed in docs/SCHEMA.md §2f.
cat > "$TMP/allowlist.txt" <<'EOF'
geography_columns
geometry_columns
username_registry_public
v_challenge_card
v_game_card
v_meetup_list
v_my_games
v_potential_vibes_default
v_rateable_after_game
v_recreate_candidates
v_recreate_quickpicks
v_space_slots_today
EOF

fail=0

echo "--- Test 1: live set is a subset of the allowlist -> must PASS ---"
cp "$TMP/allowlist.txt" "$TMP/live_clean.txt"
if anon_allowlist_diff "$TMP/live_clean.txt" "$TMP/allowlist.txt"; then
  echo "PASS: gate correctly allowed the known-good set."
else
  echo "FAIL: gate rejected a set identical to the allowlist." >&2
  fail=1
fi
echo

echo "--- Test 2: a deliberately introduced anon-readable definer view -> must FAIL ---"
cp "$TMP/allowlist.txt" "$TMP/live_leak.txt"
echo "v_deliberately_introduced_leak" >> "$TMP/live_leak.txt"
if anon_allowlist_diff "$TMP/live_leak.txt" "$TMP/allowlist.txt"; then
  echo "FAIL: gate passed a live set containing an unlisted view. This defeats the point of KAN-61." >&2
  fail=1
else
  echo "PASS: gate correctly rejected the unlisted view (exit code $?)."
fi
echo

if [[ "$fail" -eq 0 ]]; then
  echo "Self-test result: BOTH cases behaved correctly."
  exit 0
else
  echo "Self-test result: FAILED — see above." >&2
  exit 1
fi

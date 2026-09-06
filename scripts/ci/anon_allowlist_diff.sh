#!/usr/bin/env bash
# Shared diff logic for the KAN-61 anon-reachability allowlist gate.
# Extracted so it can be exercised by check_anon_allowlist_test.sh without a
# database connection, and reused unchanged by check_anon_allowlist.sh against
# the live catalogue.
#
# Usage: anon_allowlist_diff <live_views_file> <allowlist_file>
#   <live_views_file>: one view name per line — anon-readable views in
#     public currently lacking security_invoker (the live catalogue result).
#   <allowlist_file>:  one view name per line — the reviewed allowlist from
#     docs/SCHEMA.md §2f.
#
# Exits 0 if every live view is in the allowlist. Exits 1 and prints the
# offending view names otherwise.
anon_allowlist_diff() {
  local live_file="$1"
  local allowlist_file="$2"

  local extra
  extra="$(comm -23 <(sort -u "$live_file") <(sort -u "$allowlist_file"))"

  if [[ -n "$extra" ]]; then
    echo "FAIL: anon-readable view(s) without security_invoker are not on the SCHEMA.md §2f allowlist:" >&2
    echo "$extra" | sed 's/^/  - /' >&2
    echo "" >&2
    echo "Either this is a new leak (fix it — add security_invoker or revoke anon SELECT)," >&2
    echo "or it is an intentional addition that needs cto review and a SCHEMA.md §2f update." >&2
    return 1
  fi

  echo "OK: all $(wc -l < "$live_file" | tr -d ' ') anon-readable definer view(s) are on the allowlist."
  return 0
}

# Allow sourcing (functions only) or direct execution (self-check with argv).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 2 ]]; then
    echo "usage: $0 <live_views_file> <allowlist_file>" >&2
    exit 2
  fi
  anon_allowlist_diff "$1" "$2"
fi

#!/usr/bin/env bash
# Operator-only script — KAN-119. Never shipped in the app, never imported
# by anything under lib/ or supabase/functions/**, never runs in CI/CD.
# Run manually, from a trusted operator machine, with the project's
# service-role key set only in the environment for the duration of the
# call — never hardcoded here, never committed anywhere.
#
# cto's ruling (KAN-119 comment 10496): mint a magic link via the GoTrue
# admin API instead of building any new auth path. This uses the app's own
# magic-link flow — the link is obtained through the admin API instead of
# email, nothing new is added to production, and QA ends up testing the
# real login path rather than a code path no user ever takes.
#
# Usage:
#   SUPABASE_URL=<project URL> SUPABASE_SERVICE_ROLE_KEY=<service role key> \
#     ./qa_magic_link.sh link
#
#   SUPABASE_URL=<project URL> SUPABASE_SERVICE_ROLE_KEY=<service role key> \
#     ./qa_magic_link.sh cleanup
#
# `link` prints the action_link to stdout and nothing else. It is a live
# credential that authenticates as the QA account — do not redirect it to
# a file that gets committed, paste it into a Jira comment, a commit
# message, Slack, or any log. Hand it to whoever needs it the same way any
# other secret is handed over, and let it expire rather than reusing it.
#
# `cleanup` is a one-time action: it deletes the three QA accounts that
# were sitting around untracked before this ticket (KAN-119 comment
# 10496 — "pick one, document which, and delete the rest"). Safe to
# re-run; deleting an already-deleted user 404s and the script continues.

set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL (the project URL, not a client key)}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY — never hardcode this}"

# The one QA account this script mints links for, going forward. Chosen
# 2026-09-01 (KAN-119): already onboarded (persona_type = player,
# onboard = true — so QA lands past the onboarding flow, in the actual
# app), zero rows in public.admins / public.app_admins / public.role_grants
# — scoped as a plain user, not an admin. A second, separately-justified
# account is the right move if QA ever needs to test admin surfaces; this
# one should not be widened for that.
QA_EMAIL="seed_test_001@dabbler.internal"

# The three accounts being retired — looked up live on 2026-09-01 and
# pinned here so `cleanup` is idempotent and doesn't depend on a query
# surviving future account churn. None had a profiles row (never
# onboarded) and none had signed in more than once.
RETIRE_IDS=(
  "9d7a5636-de79-4b6d-aff5-4e66ab20a2f9"  # qa-smoke-test-20260831@example.com
  "19a7fe1e-272b-42a3-857d-d6ed9b1bdd35"  # qa-smoke-test2-20260831@example.com
  "e405898b-23ea-4309-8f08-cba28172f094"  # qa-familiarization-test@example.com
)

cmd="${1:-}"

case "$cmd" in
  link)
    curl -sS -X POST "${SUPABASE_URL}/auth/v1/admin/generate_link" \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"magiclink\",\"email\":\"${QA_EMAIL}\"}" \
    | python3 -c 'import sys, json
d = json.load(sys.stdin)
link = d.get("action_link") or d.get("properties", {}).get("action_link")
print(link if link else json.dumps(d))'
    ;;
  cleanup)
    for id in "${RETIRE_IDS[@]}"; do
      echo "Deleting auth user ${id} ..." >&2
      curl -sS -X DELETE "${SUPABASE_URL}/auth/v1/admin/users/${id}" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        -o /dev/null -w "  -> HTTP %{http_code}\n"
    done
    ;;
  *)
    echo "Usage: $0 {link|cleanup}" >&2
    exit 1
    ;;
esac

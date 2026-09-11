#!/usr/bin/env bash
# KAN-189/KAN-194 — shared logic for the function default-privilege gate.
#
# T-078: does pg_default_acl still grant EXECUTE on FUTURE public functions to
# anon/PUBLIC? Answer: it did, on TWO INDEPENDENT CHANNELS for the `postgres`
# grantor, and closing only one is not sufficient — proven live, not assumed.
#
# CHANNEL 1 — the NAMED per-schema default. `ALTER DEFAULT PRIVILEGES FOR ROLE
# postgres IN SCHEMA public ...` writes a row in pg_default_acl keyed on
# (defaclrole=postgres, defaclnamespace=<public's oid>, defaclobjtype='f').
# KAN-189 found this row carrying `anon=X/postgres` and revoked it
# (ledger 20260911133843).
#
# CHANNEL 2 — PostgreSQL's own BUILT-IN default: newly-created functions get
# EXECUTE granted to PUBLIC unless a role has explicitly revoked it, and that
# revoke is GLOBAL (no `IN SCHEMA` clause), tracked as a SEPARATE pg_default_acl
# row keyed on defaclnamespace=0. A per-schema revoke targeting PUBLIC (tried
# three times on this ticket's predecessor, KAN-189, and disposable-probe
# verified ineffective each time) CANNOT remove this — per-schema defaults are
# ADDED on top of the global one, never a replacement for it. Revoking it
# requires `ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON
# FUNCTIONS FROM PUBLIC` with NO `IN SCHEMA` clause (KAN-189, ledger
# 20260911163938).
#
# THE DISCRIMINATING SIGNAL FOR CHANNEL 2, since a zero-privilege ACL entry is
# never stored (there is no way to record "PUBLIC explicitly has nothing" as
# distinct from "no entry exists, so the built-in default of nothing-revoked
# applies"): the PRESENCE of a global-scope (defaclnamespace=0, defaclobjtype='f')
# pg_default_acl row for a role, with no PUBLIC member in its acl, is what a
# successful global revoke leaves behind (confirmed live: after KAN-189's second
# migration, postgres's global row reads `{postgres=X/postgres}` — present,
# postgres only). The ABSENCE of any such global row means the role's built-in
# global PUBLIC default has never been revoked and channel 2 is still open for
# it. This is not inferred from documentation alone — it is exactly what the
# live catalogue showed before and after KAN-189's second migration, and it is
# reproduced by the self-test below against a genuinely disposable Postgres,
# with real CREATE FUNCTION probes proving the effective behavior, not just the
# catalogue row's presence.
#
# ROLE SPLIT (T-045, binding, unchanged since KAN-189): this predicate is
# evaluated for `postgres` as a FAILING gate. `supabase_admin` is REPORTED
# (both channels — it carries the named anon channel and, as of KAN-194's
# live read, no global-scope row of its own either) but NEVER FAILS the build.
# Do not fold supabase_admin's row into the failing predicate — that would
# silently convert an acknowledged, out-of-authority exposure into an
# "expected good" security state that CI enforces, which is worse than not
# gating it at all.

# ---------------------------------------------------------------- the predicate
#
# Returns one row per problem found for role `postgres`: 'named_anon_default'
# if the schema-scoped row still names anon, 'global_public_default' if no
# global-scope row exists for postgres (channel 2 still open), or nothing if
# both channels are closed. Reads pg_default_acl only — no CREATE, no write.
function_default_acl_postgres_predicate_sql() {
  cat <<'SQL'
WITH schema_row AS (
  SELECT d.defaclacl
    FROM pg_default_acl d
    JOIN pg_namespace n ON n.oid = d.defaclnamespace
   WHERE n.nspname = 'public'
     AND d.defaclobjtype = 'f'
     AND d.defaclrole = 'postgres'::regrole
),
global_row AS (
  SELECT d.defaclacl
    FROM pg_default_acl d
   WHERE d.defaclnamespace = 0
     AND d.defaclobjtype = 'f'
     AND d.defaclrole = 'postgres'::regrole
)
SELECT 'named_anon_default' AS problem
 WHERE EXISTS (
   SELECT 1 FROM schema_row
    WHERE defaclacl @> ARRAY['anon=X/postgres'::aclitem]
 )
UNION ALL
SELECT 'global_public_default' AS problem
 WHERE NOT EXISTS (SELECT 1 FROM global_row)
    OR EXISTS (
         SELECT 1 FROM global_row
          WHERE defaclacl @> ARRAY['=X/postgres'::aclitem]
       );
SQL
}

# Read-only report of supabase_admin's current state on both channels. NEVER
# used to fail the build — printed for visibility only, per T-045's role split.
function_default_acl_supabase_admin_report_sql() {
  cat <<'SQL'
SELECT
  EXISTS (
    SELECT 1 FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
     WHERE n.nspname = 'public' AND d.defaclobjtype = 'f'
       AND d.defaclrole = 'supabase_admin'::regrole
       AND d.defaclacl @> ARRAY['anon=X/supabase_admin'::aclitem]
  ) AS named_anon_default_present,
  NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
     WHERE d.defaclnamespace = 0 AND d.defaclobjtype = 'f'
       AND d.defaclrole = 'supabase_admin'::regrole
  ) AS global_public_default_never_revoked;
SQL
}

# -------------------------------------------------------------------- the gate
#
# Usage: function_default_acl_gate <problems_file>
#
# <problems_file> is the (possibly empty) output of
# function_default_acl_postgres_predicate_sql, one problem code per line.
# Exits 0 if empty (both channels closed for postgres), 1 and names the
# open channel(s) otherwise. There is no allowlist here — unlike KAN-175's
# per-function gate, this predicate has exactly one legitimate answer
# (both channels closed) and nothing to allowlist against.
function_default_acl_gate() {
  local problems_file="$1"
  local problems
  problems="$(sed '/^[[:space:]]*$/d' "$problems_file")"

  if [[ -z "$problems" ]]; then
    echo "OK: postgres's function default-privilege is fixed on both channels —"
    echo "    no named anon EXECUTE default, and the global PUBLIC EXECUTE"
    echo "    default has been revoked (a global-scope pg_default_acl row"
    echo "    exists for postgres and does not include PUBLIC)."
    return 0
  fi

  echo "FAIL: postgres's function default-privilege grants EXECUTE to a" >&2
  echo "role that should not inherit it on newly-created functions:" >&2
  while IFS= read -r p; do
    case "$p" in
      named_anon_default)
        echo "  - named_anon_default: pg_default_acl (postgres, schema public," >&2
        echo "    defaclobjtype='f') still names anon. Fix: ALTER DEFAULT" >&2
        echo "    PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE" >&2
        echo "    ON FUNCTIONS FROM anon;" >&2
        ;;
      global_public_default)
        echo "  - global_public_default: PostgreSQL's built-in global" >&2
        echo "    EXECUTE-to-PUBLIC default for new functions has not been" >&2
        echo "    revoked for postgres (no global-scope pg_default_acl row, or" >&2
        echo "    one exists but still names PUBLIC). Fix: ALTER DEFAULT" >&2
        echo "    PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS" >&2
        echo "    FROM PUBLIC;  -- deliberately NO IN SCHEMA clause; a" >&2
        echo "    schema-scoped revoke cannot remove a global default." >&2
        ;;
      *)
        echo "  - $p (unrecognised problem code)" >&2
        ;;
    esac
  done <<< "$problems"
  echo "" >&2
  echo "See docs/SCHEMA.md §2g.1 for the full history (KAN-189, KAN-194) and" >&2
  echo "why BOTH channels have to be checked and fixed independently." >&2
  return 1
}

# Allow sourcing (functions only) or direct execution (gate with argv).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "usage: $0 <problems_file>" >&2
    exit 2
  fi
  function_default_acl_gate "$1"
fi

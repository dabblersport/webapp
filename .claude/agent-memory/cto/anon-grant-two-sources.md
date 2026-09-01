---
name: anon-grant-two-sources
description: anon EXECUTE can come from PUBLIC (=X/) or an explicit anon=X ACL entry, or BOTH — read proacl per function; do not generalise one function's shape to another.
metadata:
  type: reference
---

`has_function_privilege('anon', fn, 'EXECUTE') = true` does not tell you where
the grant came from. Read `pg_proc.proacl` directly. Two independent sources:

- `=X/postgres` — the PUBLIC grant, which anon inherits. `REVOKE ... FROM anon`
  is a **no-op** against this.
- `anon=X/postgres` — an explicit grant. `REVOKE ... FROM PUBLIC` alone leaves
  this standing.

Both can be present at once, and were, measured 2026-08-29:

- `create_seed_user` (all 4 overloads) — `{=X/postgres,postgres=X/postgres,service_role=X/postgres}`. PUBLIC only, no `anon=X`.
- `get_user_fcm_tokens`, `get_profile_by_id` — `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}`. **Both** sources.

So the KAN-79 finding "the grant is via PUBLIC, revoking from anon is a no-op"
is true for `create_seed_user` and **false** for the other two. It was carried
into the KAN-81 and KAN-82 migration headers as if general. The SQL happened to
be right (`REVOKE ... FROM PUBLIC, anon` names both), but the reasoning would
have produced a broken migration if applied consistently.

**Rule:** a revoke must name both, every time — `FROM PUBLIC, anon`. Verify by
re-reading `proacl` after, not by `has_function_privilege` alone.

Related: [[definer-rpc-exposure]], [[create-or-replace-view-resets-invoker]].

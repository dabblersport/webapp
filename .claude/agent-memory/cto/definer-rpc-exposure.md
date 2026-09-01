---
name: definer-rpc-exposure
description: Every SECURITY DEFINER function in public is a PostgREST RPC with EXECUTE to PUBLIC plus anon and authenticated; revoking EXECUTE hard-errors any invoker view that calls it
metadata:
  type: project
---

**A `SECURITY DEFINER` helper in `public` is an anon-callable API endpoint**, not just
an internal function. PostgREST exposes it as RPC, and Supabase's ACL is
`{=X/postgres, postgres=X, anon=X, authenticated=X, service_role=X}` — a PUBLIC grant
*plus* explicit anon/authenticated grants.

Measured 2026-08-29 on `circle_member_count(uuid)` (added by kan56b): anon called it
directly and got the member count of a private circle, bypassing the invoker view
that was supposed to gate it.

**Revoking EXECUTE is a trap.** All measured in rolled-back transactions:

- `REVOKE FROM authenticated` alone — no effect (PUBLIC grant remains)
- `REVOKE FROM PUBLIC` alone — no effect (explicit authenticated grant remains)
- `REVOKE FROM PUBLIC, anon, authenticated` — anon denied, but a legitimate member's
  read of the invoker view dies with **42501 permission denied**, because a
  `security_invoker` view calls the function *as the caller*. It does not degrade to
  NULL; it raises.
- `REVOKE FROM PUBLIC, anon` — works: anon oracle closed, view still returns 0 rows
  for anon, no error. Leaves authenticated able to enumerate.

**How to apply:** when approving any definer helper, ask who can call it *outside* the
view. Prefer authorizing **inside** the function (return NULL unless the caller owns /
is a member of / the row is public) over fighting the grant matrix — it needs no
REVOKE and cannot break an invoker view. Tracked as KAN-77, which also asks for a
census of definer functions in `public` taking an id parameter.

**Never read an ACL by eye.** `create_seed_user`'s ACL is
`{=X/postgres, postgres=X, service_role=X}` with no explicit anon grant — and anon can
still execute it, because `=X` is the PUBLIC grant. Use
`has_function_privilege('anon', oid, 'EXECUTE')`. This same trap made two of my own
REVOKE attempts look like no-ops.

Now written up as `docs/CONVENTIONS.md` §6d — cite that rather than this note.

See [[create-or-replace-view-resets-invoker]], [[jwt-profile-id-claim-trap]],
[[seed-helper-anon-callable]].

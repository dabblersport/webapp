---
name: absent-control-vs-real-control
description: Before relaxing any constraint (NOT NULL, a missing RLS policy, a failing check), verify nothing else in the path is silently relying on it as security rather than data integrity — same shape as T-012's zero-policy tables, now also T-043.
metadata:
  type: feedback
---

A constraint that looks like plain data integrity can actually be the only thing
stopping an unauthenticated/unbounded write — check what fails *because* of it
before removing it, not just what it's named for.

**Why:** KAN-109 (T-043, 2026-09-01): `analytics_events.user_id NOT NULL` was
blocking a legitimate pre-auth analytics event, so the fix looked like a pure
DROP NOT NULL. But `rpc_track_event` (SECURITY DEFINER, EXECUTE granted to
`anon`) had no rate limit, no event-name validation, no payload cap — the NOT
NULL was, by accident, the only thing stopping unauthenticated unbounded writes.
Dropping it alone would have converted "anon writes fail by luck" into "anon
writes succeed without limit, arbitrary event, arbitrary JSONB, forever." cto
flagged this as the third instance that week of the same failure mode as
[[security-definer-rpc-census]]'s zero-policy tables (T-012): something
protected by an *absent* thing rather than a real control, which fails open
the moment someone fixes the unrelated defect sitting in front of it.

**How to apply:** Before authoring any migration that removes/loosens a
constraint (NOT NULL, a CHECK, a missing policy that happened to deny-by-default,
a broken function that happened to always error), read every SECURITY DEFINER
function or code path that touches the column/table and ask "what does this
allow once the blocker is gone, for the roles that can already reach it?" If
the answer is "unrestricted access for a role that shouldn't have it," the fix
ships as constraint-removal-plus-replacement-control in the *same* migration,
never as two changes. Also: gating the Dart/client call site is not a security
alternative to a DB-level fix when the RPC is directly callable with the public
anon/publishable key — that only changes what your own client sends, not what
anyone else can send. Worth stating explicitly when proposing a client-side fix
to cto so it isn't miscategorized as a control.

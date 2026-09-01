---
name: rls-policy-count-is-not-permission
description: A base relation having >=1 RLS policy does not mean SELECT is ever permitted — a policy can be ALL/deny-all or author-only-ALL and still block the exact caller a view flip is meant to serve. Always test the actual SELECT outcome, not the policy count.
metadata:
  type: feedback
---

**Before flipping a definer view to `security_invoker`, don't just count policies on each base
relation — simulate the actual caller and confirm real rows come back.** `T-029`'s split rule
("every base relation has ≥1 policy ⇒ safe to flip") is necessary but not sufficient.

**Why:** on KAN-56 (2026-08-29), cto's T-029 ruled FLIP for `v_mod_queue_open` and `v_circle_feed`
because their base relations each had ≥1 policy. Live simulation found both would have shipped
broken:
- `moderation_reports` has 2 policies — `mr_block_dml` (cmd=ALL, `USING false`, a blanket deny)
  and `mr_self_insert` (INSERT only). Neither ever permits SELECT, for anyone, including a real
  admin. `SET LOCAL ROLE authenticated; SELECT count(*) FROM moderation_reports` → **0**. The flip
  would have zeroed the admin moderation queue permanently.
- `post_circles` has 1 policy — cmd=ALL, `USING is_post_owner(...)` — written for INSERT/UPDATE/
  DELETE by the post's author, but because it's ALL it also gates SELECT. No policy admits "I'm a
  circle member." Tested against a real circle post as a non-author profile: **0** rows. Silent
  until a second member ever posts to a circle, then the circle feed collapses to "only my own
  posts" for everyone else.

Both would have passed T-029's stated test (policy count > 0) and both fail in practice.

**How to apply:** for any invoker-flip candidate, run the actual query as the intended caller in a
rolled-back transaction (`BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.profile_id', ...); SELECT count(*) FROM <base_relation> WHERE <realistic predicate>; ROLLBACK;`)
before trusting a flip. If it comes back 0 for a caller who should legitimately see rows, the base
relation needs a real permitting policy first (mirror an existing analogous policy — e.g.
`is_admin(auth.uid())` for admin-only tables, matching every `admin_*`/`rpc_admin_*` function in
this schema; or mirror the parent entity's own SELECT predicate, as done for `post_circles`
mirroring `circles_select` exactly) — not just a bare flip. See [[invoker-flip-join-trap]] for the
sibling lesson (INNER JOIN drops whole rows when a joined relation's RLS blocks it) — this is the
same family of bug: verify structure, not summary statistics, before flipping.

**Also worth checking separately:** a view can have zero per-caller filtering in its own body (no
`WHERE auth.uid()`-style clause at all) even when its base tables have real policies —
`v_safety_overview` was a bare aggregate with no WHERE, so any `authenticated` caller (not just
admins) could read it. `REVOKE FROM authenticated` alone would fix the leak by breaking the
feature; the real fix is scoping the view body itself (`WHERE is_admin(auth.uid())`, same pattern
as `v_user_badges_summary`) and keeping it definer.

Related: [[invoker-flip-join-trap]] (cto's memory), `docs/DECISIONS.md` T-029.

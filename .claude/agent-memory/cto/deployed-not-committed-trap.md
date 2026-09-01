---
name: deployed-not-committed-trap
description: "Commit N is live" claims in this session are routinely false — agents leave work uncommitted by standing rule, and main lags Canary by dozens of commits; check git refs, never a DB-side equivalence proof
metadata:
  type: feedback
---

Before applying any migration whose precondition is "the Dart/client change is live",
verify with git refs — `git show origin/main:<file>` and `git show origin/Canary:<file>` —
never from a ticket comment, and never from a DB-side old-vs-new equivalence proof.

**Why:** KAN-87, 2026-08-31. The migration dropping `creator_user_id` from `v_game_card`
was dispatched to me as ready, with task-auditor stating the precondition "has been
satisfied since 2026-08-30". It was not. Measured:

```
local HEAD     fd4df5a   creator_profile_id.eq.${args.profileId}   ← fix, unpushed
origin/Canary  8acb16b   creator_user_id.eq.${args.userId}         ← OLD
origin/main              creator_user_id.eq.${args.userId}         ← OLD
origin/main..origin/Canary = 32 commits
```

Three compounding causes, all still active in this session:
1. **The standing sprint rule tells feature agents to leave work uncommitted.** Every
   flutter-feature-agent comment said "left uncommitted" — yet later readers treated the
   work as shipped. Correct code in a dirty working tree is not deployed code.
2. **A DB-side equivalence proof is not a deployment.** flutter-feature-agent ran the old
   filter vs the new filter against prod and got identical 11-row sets. That proves the
   *rewrite is correct*. It says nothing about which code is *serving traffic*. Two
   downstream agents read it as precondition-satisfied.
3. **`main` lags `Canary` badly and nobody watches the gap.** Canary-only verification
   is insufficient for a destructive schema change: `main` is what real users run.
   The constraint on dropping a column is the *oldest deployed reader*, not the newest.

**How to apply:** For any drop/rename of a column, RPC arg, or view output, enumerate
every deployed reader by checking `origin/main` AND `origin/Canary` — not the working
tree, not the ticket. If either lags, refuse the apply and hand the ticket to
`version-control` for the push + PR, not back to the feature agent (whose work is done).

Failure mode when this is missed: PostgREST renders `or=(col.eq.X)` into `WHERE col = X`;
a missing column is SQLSTATE 42703 → HTTP 400. The screen breaks outright — the migration
header's warning about "silently wrong results" understates it.

Related: [[g002-bypass-2026-08-29]] (the mirror-image error — a "pending" migration that
was already live), [[verification-lessons]], [[create-or-replace-view-resets-invoker]].

---
name: duplicate-work-same-file-collisions
description: Two tickets dispatched the same day can both touch one file with opposite fixes; the later agent silently overwrites the earlier, and neither knows. How to reconcile.
metadata:
  type: project
---

Parallel ticket dispatch produces same-file collisions with no warning to either agent.
Confirmed twice on 2026-08-31: KAN-63/KAN-74 (competing `find_slots` migrations) and
KAN-63 item 3 / KAN-47 item 1 (`profile_avatar_screen.dart` — agent-18 repaired it,
agent-20 deleted it 75 min later and won by running last).

**Why:** agents run without visibility into each other's working-tree edits, and
uncommitted work is invisible in `git log`. The loser's change vanishes entirely —
`HEAD` still shows the *original* state, so nothing records that a fix ever existed.

**How to apply:**
- Establish which version is live with `git status --porcelain` + `git show HEAD:<path>`
  *before* reading either ticket. A ticket comment claiming a fix is not evidence the
  fix is in the tree.
- Reconcile on merit, never on recency. Verify the surviving version's load-bearing
  claim line-by-line — in the avatar case, that `/profile/edit` really did cover all
  three defects (it did: `_uploadAvatarBytes`, `profile_edit_screen.dart:187`,
  `_selectDsAvatar`).
- Deleting an orphan beats repairing it when a *reachable* screen already implements
  the same mechanism. A correct fix on the wrong artifact leaves two implementations
  to keep in sync. See [[dead-and-wired-router-controller]] for when "orphaned" is
  wrong — judge reachability per entry point, not per file.
- Comment on **both** tickets, naming which won and why, so the losing ticket's trail
  does not read as unfinished work someone later "restores".
- Neither agent earns rework for a collision they could not see.

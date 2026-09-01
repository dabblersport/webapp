---
name: measure-head-not-worktree
description: Always state whether a code measurement came from HEAD or the working tree, and check the grant AND the row count for a Postgres view — two traps that each produced a wrong headline.
metadata:
  type: feedback
---

Two measurement traps, both caught on 2026-09-01 (run 4, KAN-39). Each would have produced a
confidently wrong headline.

## 1. A working-tree measurement is not a statement about the product

**Rule: every code figure must say whether it came from `HEAD` or the working tree, and any
audit must run `git diff HEAD --stat` before quoting a single LOC or file count.**

**Why:** on 2026-09-01 the tree held **109 uncommitted files in `lib/`, +594/−30,762**. Measured
naively, `lib/features/rewards/` had collapsed from 20,545 LOC to 691 and the headline read
"resolved". It was resolved *on one machine's disk* — never committed, never pushed to `Canary`,
never built by Cloudflare, never seen by CI. `lib/` was 833 `.dart` files at `HEAD` and 781 in the
tree. Reporting the tree figure as the state of the product would have told the PO a deletion had
shipped when nothing had. Compounding it, `Canary` was 32 commits ahead of `main` — **two**
undeployed layers.

**How to apply:** run `git status --porcelain` and `git diff HEAD --stat -- lib` in the Orient
phase, before any scan. If the tree is dirty, say so in the header of the report and label every
figure. `git ls-tree -r HEAD --name-only lib | grep -c '\.dart$'` gives the HEAD-side number to
compare against. The corollary matters too: a QA pass over a deployed build does **not** clear an
uncommitted tree, and saying so is part of the finding.

See [[audit-run2-inventory-2026-08-27]], [[reachability-method]].

## 2. For a Postgres view, the grant proves nothing on its own

**Rule: to judge whether a view leaks, check the `reloptions` AND the empirical row count as role
`anon`. Never the grant alone. And never test for SECURITY DEFINER by looking for a reloption.**

**Why:** `v_notifications_feed` and `v_notifications_ranked` still hold an `anon` SELECT grant, and
a grants query alone reads as run 1's #1 CRITICAL still being open. It is not — both now carry
`security_invoker=on`, so RLS on `notifications` applies to the caller, and
`set local role anon; select count(*)` returns **0** (was 609 rows across 49 recipients). The grant
is harmless.

The inverse trap is worse. `where 'security_definer=true' = any(c.reloptions)` returns **0** and
looks like a clean bill of health, because SECURITY DEFINER is the Postgres **default** for a view
and stores no reloption at all. The correct measure is `total_views − security_invoker views`
= 71 − 22 = **49**. This is the same class of error that made run 1 understate the security surface
by 2× (25 definer / really 49; 8 anon-exposed / really 19).

**How to apply:** three queries, always together — `pg_class.reloptions`, the grant, and
`set local role anon; select count(*)`. The row count is the one that settles it. Read-only
throughout; never write to production.

See [[audit-false-positives]], [[INDEX]] §0.

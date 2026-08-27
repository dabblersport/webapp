---
name: audit-run2-inventory-2026-08-27
description: Run-2 application inventory headline numbers at commit 5f92904 — report deltas against these, and the four run-1 facts they corrected.
metadata:
  type: project
---

Application inventory, 2026-08-27, commit `5f92904`, branch `Canary`. Full detail in
`docs/PROJECT_STATE.md` Part II (§13–§20); lookup rows in [[index]] §11b.

**Headline:** 267 non-generated files / **69,612 LOC** not import-reachable from
`lib/main.dart`. 101 screen classes (74 route-referenced, 2 push-only, 7 orphaned public,
18 private helpers). 90 GoRoutes. **23 user flows traced, 19 complete end to end.**

**Why:** the run-1 dead-code figure (21 orphan screen classes / 6,213 LOC) counted only
screen classes with no external reference. It missed transitively-dead subtrees entirely.
The import-BFS measure is ~11× larger and is the one to quote.

**How to apply:** report deltas against 69,612 LOC / 267 files, not against the run-1
figures. Re-measure with `.claude/jobs/*/tmp/reach.py` before any deletion decision.

**Four run-1 facts this run corrected** — all four were in [[index]] and had propagated:
1. Live game composer is `lib/features/misc/...`, not `features/games/`.
2. `get_nearby_posts` is dead, not live.
3. Nothing in rewards is live — `enableRewards = false` gates route *and* modal.
4. Route constants unused: 65 of 195, not 54 of 133.

Two of those (1, 4) came from measuring a narrower population than the claim described —
the same failure mode as decision 020. See [[audit-false-positives]].

**The four flows that do not work:** chat (advertised, placeholder), Circles (no entry
point), rewards (flag off), 7-step game wizard (dead). Findings INV-01…INV-08.

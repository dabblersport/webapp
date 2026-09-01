---
name: shared-working-tree-staging-hazard
description: Multiple agents share this repo's working directory and git index concurrently — a plain `git add <my files>` can still sweep in whatever another agent already staged
metadata:
  type: feedback
---

**This repo's working tree and git index are shared live across concurrently-running
agents** (cto, backend-owner, flutter-feature-agent, notifications-specialist,
master-analyst, task-auditor, etc. all operate on the same checkout in this multi-agent
session). `git add <specific files>` only adds those paths, but `git commit` with no
pathspec commits **the entire index**, including anything another agent staged (via their
own `git add` or `git rm`) between your `git status` check and your `git commit` call.

**Why this matters:** hit this twice in one KAN-61/KAN-72 session (2026-08-29). First time,
`git commit` after staging 7 intended files also committed 38 unrelated file renames
(`supabase/schema/migrations/**` → `archive/**`) that another agent had staged concurrently
— caught before push via `git show --stat HEAD`, fixed with `git reset HEAD~1` (mixed) which
safely unstages without touching any file content, then re-staged only the intended files
and recommitted. Second time, staging one already-modified file (`scripts/ci/README.md`)
still swept in 7 `supabase/.temp/**` deletions someone else had staged — this time already
pushed before being caught. It turned out harmless (a deliberate, correct untracking of
Supabase CLI scratch files per `docs/CONTRACT.md`'s own "UNOWNED — do not edit or commit"
line, files remained on disk, `supabase/.gitignore` already covered them going forward) but
it was luck, not verification.

**How to apply:** immediately before every `git commit` in this repo — not just the
first one in a session — run `git diff --cached --stat` (or `--name-status`) and confirm
every listed file is one you intentionally staged. If anything unexpected appears, `git
reset <path>` it back out before committing. Don't trust a `git status --porcelain | grep`
filtered to your own files as a substitute — it hides exactly the kind of stray staged
content this hazard produces. For a file mixed with another agent's live WIP (not just
staged-but-uncommitted — actively being edited on disk), stage a composed blob via
`git hash-object -w` + `git update-index --cacheinfo` instead of editing the live working
copy, so your hunk lands without disturbing theirs (used successfully for `docs/SCHEMA.md`
here, which `master-analyst` was concurrently rewriting).

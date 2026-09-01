---
name: uncommitted-but-applied-migration
description: A migration can be verified live-applied in production (via execute_sql/list_migrations) while its .sql file sits untracked in git for a full day or more — check git ls-files, not just disk presence.
metadata:
  type: feedback
---

A migration file existing on disk with correct SQL, and even being confirmed **applied** in
production (via `mcp__supabase__list_migrations` showing the matching version, or a live
`execute_sql` check), does not mean it is committed. Found on KAN-79 (2026-08-30): the
`kan79_drop_create_seed_user.sql` migration was applied to prod on 2026-08-29 and fully
verified live (function dropped, 404 on REST, row counts sane) — but `git ls-files` returned
nothing for it and `git status` showed it `??` (untracked) a full day later, alongside three
sibling migrations from the same session (kan78, kan81, kan82).

**Why: this is the concrete form of the CFG-02 finding** (`docs/PROJECT_STATE.md`) — "no
repo-authored way to rebuild the schema." Every G-002 direct-apply migration is a candidate for
this gap, because G-002's controls (claim-comment-first, verify-and-post-back) never require a
git commit as one of the four conditions — they compensate for the schema-reproducibility gap,
they don't close it.

**How to apply:** on any ticket that authored and applied a Supabase migration (especially under
G-002), run `git ls-files supabase/migrations/<name>.sql` and `git status --short` on the
migrations directory before passing Gate 1. A verified-live production fix still passes on its
own merits (the vulnerability is closed, independently verified) — but flag the uncommitted file
explicitly as a non-blocking finding routed to `version-control`, don't silently accept "the file
exists in the repo" as proof it's *in* the repo. See also [[git-committed-vs-working-tree]].

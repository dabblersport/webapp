---
name: skills-install-three-locations
description: Installing an external skill writes to THREE places — .claude/skills/, .agents/skills/ and skills-lock.json; only the first two matter and .agents/ is now gitignored as residue
metadata:
  type: project
---

Discovered 2026-08-27 while committing the leadership-layer work.

Installing a skill from an external source (`mattpocock/skills` via
`skills-lock.json`, `sourceType: github`) writes to **three** locations:

1. `.claude/skills/<name>/` — **the one Claude Code actually reads.**
2. `.agents/skills/<name>/` — a **byte-identical duplicate** of a subset.
   Real directories, not symlinks; `cmp` clean on every `SKILL.md`.
3. `skills-lock.json` — repo root. Records `source`, `sourceType`,
   `skillPath` and `computedHash` per skill. **No install target**, which is
   why the lockfile cannot tell you which of the two directories is live.

**Resolved 2026-08-27 by the team lead:** `.agents/` is **installer residue
for our toolchain** — most likely the cross-tool convention other agent
runners (Codex, Cursor) read. Proof was not config but behaviour: all 12
skills are registered and callable from `.claude/skills/`, and `.agents/` is
referenced in no config file. It is now **gitignored** (`.gitignore:34`,
beside `.claude/worktrees/`) — kept on disk, kept out of history, because a
byte-identical duplicate invites editing one copy and forgetting the other,
and this repo is public. **Revisit only if we run Codex or Cursor here**;
that is the case where it earns committing, and the decision should be made
then for that reason rather than by default.

`skills-lock.json` **does** belong in the same commit as the skills it
describes — it is their manifest, and committing skills without it leaves
the lockfile describing a state the repo does not have.

**Why this still matters:** a commit brief that enumerates `.claude/skills/`
alone silently omits the lockfile. On 2026-08-27 the brief listed only
`.claude/skills/` and undercounted it as 34 directories when there were 38.

**How to apply:** when committing or removing skills, reconcile the count
against `git status --porcelain | grep '^?? \.claude/skills/' | wc -l`
rather than a number in the brief — the lead confirmed theirs was written
from memory and that following the written instruction over the number was
correct. Include `skills-lock.json`. Expect `.agents/` to stay invisible now
that it is ignored.

See [[record-the-fact-not-a-pointer]] — this entry was first written with
the `.agents/` question stated as open, then updated when it was answered,
rather than left pointing at a decision made elsewhere.

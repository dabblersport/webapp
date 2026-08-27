---
name: skills-install-three-locations
description: Installing an external skill writes to THREE places — .claude/skills/, .agents/skills/ and skills-lock.json — so a commit brief naming only .claude/skills/ is always incomplete
metadata:
  type: project
---

Discovered 2026-08-27 while committing the leadership-layer work.

Installing a skill from an external source (`mattpocock/skills` via
`skills-lock.json`, `sourceType: github`) writes to **three** locations:

1. `.claude/skills/<name>/` — the directory Claude Code reads.
2. `.agents/skills/<name>/` — a **byte-identical duplicate** of a subset.
   Real directories, not symlinks; `SKILL.md` files diff clean.
3. `skills-lock.json` — repo root. Records `source`, `sourceType`,
   `skillPath` and `computedHash` per skill.

None of the three is gitignored.

**Why this matters:** a commit brief that enumerates `.claude/skills/` — the
obvious location — silently omits the other two. Committing the skill
directories without `skills-lock.json` leaves the lockfile describing a state
the repo does not have. On 2026-08-27 the brief listed only `.claude/skills/`
and undercounted it as 34 directories when there were 38; the four unlisted
were all from this installer.

**How to apply:** whenever a task commits or removes skills, check all three
locations before staging, and reconcile the count against
`git status --porcelain | grep '^?? \.claude/skills/' | wc -l` rather than
trusting a number in the brief. Include `skills-lock.json` in the same commit
as the skills it describes. `.agents/` is still **undecided** — as of
2026-08-27 it was left uncommitted and the question of whether any runtime
reads from it was put to the team lead and not answered before that task
closed. Do not assume it is residue; ask again.

See [[record-the-fact-not-a-pointer]] for why the unresolved half of this is
stated as unresolved rather than quietly dropped.

---
name: git-committed-vs-working-tree
description: A doc edit cited as evidence for a decision (e.g. a DECISIONS.md entry) may exist only in the uncommitted working tree, not in any commit — check both separately.
metadata:
  type: feedback
---

When a ticket or agent comment cites a specific governance-doc entry (e.g. `docs/DECISIONS.md`
T-034) as evidence, don't assume the file being present and correct on disk means it's actually
in version control. Run `git show HEAD:<path> | grep <marker>` to confirm the cited entry is
committed, separately from confirming it's present in the working tree (`grep <marker> <path>`).

Found on [[KAN-61]] (2026-08-29): the shared working tree had `docs/DECISIONS.md` and
`docs/SCHEMA.md` both modified-but-uncommitted at review time. The *enforced artifacts* (CI
workflow, scripts, and the SCHEMA.md §2f allowlist block itself) were already committed in an
earlier commit (`8c82caf`/`6bc3818`), so the ticket's acceptance criteria were still met — but
the specific DECISIONS.md entry (`T-034`) the review comment leaned on for Gate 2 context
existed only in the uncommitted tree. The agent who wrote it (`cto`) had already flagged this
gap in-thread ("that edit is uncommitted ... version-control to commit it"), which is why it
didn't need to be an independent finding — but if that flag hadn't been there, this would have
been an easy false pass: citing a decision as authoritative context without checking it was
actually persisted.

**Why:** In a session with many concurrent agents sharing one working tree (see
[[concurrent-auditors-race]]), "the file says X" and "the repo says X" are different claims.
Only a commit is durable — a working-tree edit can be lost, overwritten by another agent's
edit to the same file, or simply never land if nobody commits it.

**How to apply:** When Gate 2 evidence comes from a DECISIONS.md/SCHEMA.md/CONTRACT.md entry,
always check `git show HEAD:<file> | grep <the specific entry/marker>` before citing it as
settled context — not just that the file exists and contains the text right now. If it's only
in the working tree, note it in the verdict (as informational, not necessarily a fail — check
whether any AC actually depends on the entry being committed vs. just being true).

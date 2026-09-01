---
name: decision-renumbering-t016-t020
description: T-016 was renumbered to T-020 (blocklist/orphan-table ruling); grepping "T-016" lands on the unrelated analytics entry and makes a settled decision look unmade
metadata:
  type: project
---

`docs/DECISIONS.md` has **two** things that were once called `T-016`. The KAN-68 /
orphan-table ruling ("a control's data is never readable by the people it constrains")
was renumbered to **`T-020`** on 2026-08-28 after colliding with an earlier analytics
entry that kept the `T-016` number.

**Why:** a task brief reached me on 2026-08-31 asking me to *decide* KAN-68 FIX-vs-DELETE.
It was already decided (FIX) on 2026-08-28. Whoever wrote the brief almost certainly
grepped `T-016`, hit the analytics entry, saw nothing about blocklists, and concluded the
ruling did not exist.

**How to apply:** never conclude a decision is unmade from a number search alone — grep the
*subject* (`blocklist`, `context_rating_config`) as well. See
[[verification-lessons]]: a grep for a literal proves nothing in this repo. Before
"deciding" anything a brief hands you, check whether you already ruled on it; re-litigating
your own settled ruling is worse than not ruling at all. Related: [[cto-own-ruling-corrections]].

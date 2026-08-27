---
name: record-the-fact-not-a-pointer
description: Never write "see below" or a forward reference for a fact not yet established — state the unknown in the field itself, and say what its absence means
metadata:
  type: feedback
---

In a status entry, **a field must contain the fact, never a pointer to it.**
Never write "see the result recorded below" for something not yet
established.

**Why:** on 2026-08-27 I closed a `docs/status/version-control.md` entry with
`**Not verified:** See the deploy result recorded below` while the Cloudflare
build was still running. Nothing was ever written below. The PO caught it:
**an empty field reads as unfinished, but a pointer reads as done.** A dangling
forward reference passes a skim in a way a blank never would, so an unfinished
record looked like a finished one — in the one file whose stated purpose is to
record that exact answer, directly under its own rule that a green push is not
a green deploy.

**How to apply:** when a fact is not yet established at the moment of writing,
put the uncertainty *in the field*:

> **Deploy:** PENDING AT TIME OF WRITING — build still `in_progress`. Not
> verified. Superseded by the entry above once concluded; **if no later entry
> exists, the deploy was never confirmed.**

The PO singled out that last clause as the part worth keeping: it makes the
*absence* of a follow-up legible. A reader who finds no later entry learns
something definite instead of having to guess whether the check happened and
went unrecorded. Use that pattern whenever a session may close before a fact
lands.

"Could not determine, here is what I tried and what access I lack" is a
**complete** entry, not a failed one. Any of succeeded / failed / undetermined
is acceptable. The forward reference is not.

See [[deploy-verification-channels]] for what to actually check before the
field can be filled, and [[canary-pipeline-incident]] for the same shape of
error one layer down — a success signal that was never evidence of the thing
it appeared to confirm.

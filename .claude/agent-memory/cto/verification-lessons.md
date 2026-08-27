---
name: verification-lessons
description: Method failures caught during KAN-39 — how grep counts mislead here, and the "dead code vs landmine" distinction that changes a fix.
metadata:
  type: feedback
---

Lessons from the KAN-39 cross-review with `master-analyst`. Every disagreement we had was
about **method**, never about reality — filters, definitions, and one causal claim.

**A grep count is not a population count, one level deeper than decision `020`:** a number whose
*filter* is unrecorded is not a measurement, it's a memory. `master-analyst`'s line, and it is
better than decision `020` itself. Three figures collapsed under this in one session — "233
colours" (reproducible only under an unrecorded filter), my own 866, and 25-vs-24 throws.

**Concrete traps found in this repo:**
- `grep -c UnimplementedError` on `settings_repository_impl.dart` returns 25; **24** are real
  throws. Line 14 is a doc comment that contains the word `throw`.
- Throw sites here are both `throw X;` statements **and** `) => throw X(...)` arrow bodies.
  Anchoring to `^\s*throw` finds only a third of them.
- `grep -rn "SomeClass("` matches the class's **own constructor declaration**. A single hit in
  its own file means *never constructed*, not "constructed once".
- Counting `Either` by `grep -rl fpdart` gives 17 and is wrong; the symbol grep gives 31,
  because `profile` uses a hand-written `Either`.

**Dead code vs landmine — the distinction that changes the fix.** I called
`SettingsRepositoryImpl` dead code; it is constructed, injected, and watched by 16 files. Live
code with unimplemented methods is a **landmine on a wired path** — it compiles, autocompletes,
and throws at runtime for the next person who extends it. Dead code gets deleted; a landmine
needs the *interface* shrunk too, or it just moves up a layer.

**Bound a claim to what you measured.** I quoted a nine-month exposure window from local git;
local history had been re-initialised (`555b378`), so the Analyst recorded it as an unverified
claim rather than repeat it. Correct call. It reproduces via
`gh api repos/dabblersport/webapp/commits/<sha> --jq '.commit.author.date'` — **give the
origin-side command with the claim**, not a bare date.

**Why:** two independent reads converged on every fact and diverged only on method. That is the
good failure mode, and it only works if the command travels with the number.
**How to apply:** quote the command beside every count. Before calling something dead, check
whether it is *constructed and injected* — reachability of the class, not just of the method.

**Severity is a measurement too, and it fails the same way.** I classified a public keystore
password as a promotion blocker alongside two live user-harm defects. It isn't one — no user is
harmed by it today. **The test:** *if this fix took three weeks instead of an afternoon, would I
still hold launch?* If no, then cheapness is driving the label, not danger. That is a good reason
to sequence it first and a weak reason to call it a blocker.

**Overstatement and unverifiability are the same failure in opposite directions** — both remove
something from scrutiny. `master-analyst`'s G-001: "an assertion of unverifiability carries the
same burden as an assertion of fact, and it is the more dangerous of the two, because a wrong
fact invites challenge while 'we can't know that' closes the question." The corollary: an
overstated blocker gets discounted once, and the next real one gets discounted with it.

**Bound a severity claim to its mechanism.** "Signing key exposed" and "credential exposed,
artifact not" are materially different claims. Only the second was true — the keystore was never
committed in any ref or history, no encoded blob, and Android signing never runs in CI.

See [[load-bearing-measurements]], [[analyst-reconciliation]], [[kan39-launch-readiness]].
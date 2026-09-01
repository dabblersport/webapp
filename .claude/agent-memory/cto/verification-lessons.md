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

**Severity attaches to the COLUMN, not the view (2026-08-28).** `v_game_card` returns 216 rows
to `anon`, all `listing_visibility='public'` — correct public discovery for a game-finding app,
and MED. But the projection also carries `creator_user_id`, and
`SELECT count(*) FROM v_game_card WHERE creator_user_id IN (SELECT id FROM auth.users)` returns
**216 of 216** — the raw auth uid for 25 users, alongside a *separate* `creator_profile_id`.
Nobody decided to publish that; it leaked into a public projection. It is HIGH because it is a
**join key** across 27 anon-readable views, not for what it reveals alone. Grading a view as a
unit is what let eight of them sit in a "safe" bucket.

**Instruments that answer a NEARBY question convincingly** — the most expensive error class here,
hit twice in one day from opposite directions. `pg_depend` answers "is there a tracked
dependency", not "does any function use this table". String-matching `auth.uid()` in a view
definition answers "is the predicate mentioned", not "what does it return to `anon`". A
privilege is not an exposure; a predicate is not a protection. **The catalogue describes intent;
only the query establishes behaviour** — run it as `anon`, with a control in the same
transaction.

**Dead data is not dead code (T-016).** `T-007` deletes dead code by default. That does **not**
transfer to data: dead Dart is recoverable from git in one command; dropped config rows are
recoverable from nothing. For unreferenced tables — revoke the grants now (free, removes the
exposure), defer the drop indefinitely (irreversible, no urgency).

**A control's data must not be readable by those it constrains (T-016).** Fixing an RLS-blocked
blocklist with a read policy for `authenticated` "works" and destroys the control — users
download the banned terms and author around them. Use a DEFINER function plus revoked grants.
The generalisation: for config that *enforces* something, readability by the enforced party is
itself the vulnerability.

**A safety control that fails open is worse than an absent one**, because its existence implies
protection. Verify such controls as role `authenticated`, **never service role** — a service-role
test passes while production fails.

**Sizing a finding and characterising it are different passes — and finishing the first feels
like finishing (2026-08-28).** The notification leak was sized on day one at 609 rows / 49 users
and treated as scoped. Nobody asked what a single row *contained* — it carried 51 raw
`auth.users` UUIDs. I printed that column list myself in my own escalation and did not ask
either. Two independent readers looked at `to_user_id` and saw a leak's **size** rather than its
**shape**. After sizing an exposure, run a second pass over the column list asking what each
field *is*.

**Never bundle a privilege-only change with one that redefines an object.** `REVOKE` on views with
zero client references is verifiably risk-free; `CREATE OR REPLACE VIEW` dropping a column with
6 live read sites is not. Bundling destroys the risk-free property that let the urgent one ship
first. "Same file, same review" is the argument *against* folding, not for it.

**Protection by an ABSENT thing is the recurring defect class here — seen three times.** A
zero-policy table (T-012), a `NOT NULL` that made every anon write fail (T-043), an absent
INSERT policy on a bucket (T-030/KAN-75). In each, the system was safe by accident and failed
open the moment someone corrected an unrelated defect. **Ask of any control: is this a decision
or an accident?** If removing an unrelated constraint would open it, it is an accident.

**A guard can often be tested live with zero write risk** — because it raises *before* the write.
Verified KAN-109's allowlist and size cap directly against production; row count 56 before and
after. This is **stronger** than a rolled-back transaction, which still fires triggers and
consumes sequences. When the guard is the thing under test, live is the low-risk option; only
the success path needs a rollback or a branch.

**Before `CREATE OR REPLACE` on a live function, capture the current definition.**
`pg_get_functiondef` + save to `supabase/schema/rollback/`. One query turns "we broke onboarding"
into a one-statement restore. Also match column lists before `CREATE OR REPLACE VIEW` — it fails
outright on a dropped/renamed/reordered column, mid-migration.

**`CREATE OR REPLACE VIEW` silently resets `security_invoker` to off** (backend-owner's finding).
Grants survive; that reloption does not. Re-`ALTER` it in the same migration or a leak reopens.

**Default privileges: two grantors, only one alterable (T-045).** `ALTER DEFAULT PRIVILEGES FOR
ROLE x` needs MEMBER of `x`. `postgres` → yes (covers everything migrations create);
`supabase_admin` → no (`pg_has_role` MEMBER = false), so dashboard/tooling-created tables need a
convention plus per-table `REVOKE`, never a migration that cannot run.

**A migration file is immutable once applied (T-031).** Corrections ship as new migrations. Two
pre-flights that each catch this alone: does the object it creates already exist, and is its own
name already in the ledger.

See [[load-bearing-measurements]], [[analyst-reconciliation]], [[kan39-launch-readiness]].
**Concurrent seats collide in `DECISIONS.md` (2026-08-28).** Two CTO seats appended in one
session and both wrote `### T-012`. Before adding an entry, `grep -n "^### T-" docs/DECISIONS.md
| tail` — the file may have moved since you last read it. Renumber the *newer* entry, never the
one already cited in memory or tickets, and leave a numbering note saying what happened.
**A privilege is not an exposure (2026-08-28).** I counted `has_table_privilege('anon', …)` and
reported it as a leak count. Six of the 27 returned zero rows. **Counting the grant is not
observing the behaviour.** Symmetrically, `master-analyst` had certified 8 views safe by matching
the string `auth.uid()` in their definitions without querying one — two of those 8 were readable.
Same failure, opposite ends: **neither of us ran the view.** Establish a position by observing
behaviour, not by reading for a pattern.

**Reconciling your number against someone else's requires checking you measure the same thing.**
I "corrected" the Analyst's 19 with my 27 and amended `T-001` against a claim they never made —
19 was exposure, 27 was privilege. Comparing two of my *own* definitions felt like a
definitional-difference check and was not one.
**"X exists separately, so nothing reads Y" is an inference, not a check (2026-08-28).** Told the CPO
that dropping `creator_user_id` was a zero-risk column drop because `v_game_card` already carries
`creator_profile_id`. **Never grepped.** It has **6 live sites**, 3 of them query filters
(`game_history_providers.dart:79-80`, `supabase_games_datasource.dart:507`,
`sport_profile_view_provider.dart:264`). Would have broken game-history filtering and organiser
identity — and worse, would have destroyed B1a's one valuable property: it is the **only**
verifiably risk-free production change (**0 client refs across all 8 revoke-target views**). Never
bolt a client-regression risk onto a change whose value IS its reviewability. See `T-022`.

**Before recommending a column/table/view be dropped or changed, grep `lib/` for it.** Third
instance today of asserting from a nearby fact instead of the query.

**Say what you counted, not just how many (2026-08-28).** Twice in one day a "conflict" was two agents
counting different things correctly: 19 (exposure) vs 27 (privilege) on definer views; 3 (query-filter
sites) vs 6 (grep lines) on `creator_user_id`. **Neither pair was a disagreement.** Before treating a
number mismatch as an error, state both units — and before amending a decision against someone else's
figure, confirm it measures what yours does. Report as "N occurrences / M files / K call sites",
never a bare N.

**I named the 19-vs-27 trap and then walked into it one level down (2026-08-28).** Reconciled a
6-vs-3 count as "filters vs deserializers" — grouping by **call syntax** — and labelled the filter
group "what breaks". Two of the three queried the **base table**, which keeps the column. **The tell:
a reconciliation where both numbers are right is sometimes true and is always the most comfortable
conclusion available — which is exactly when it needs the most scrutiny.** I reached for it because it
resolved a dispute without anyone being wrong. **Name the question your instrument actually answers,
then check it against the question you asked.**

**The wildcard is invisible to the sweep that defines the axis (master-analyst, 2026-08-28).** I said
"`.from()` says who reads the view, `select()` says who reads the column" and proposed checking the
five column-list constants. **Two of the eight call bare `.select()`** — `game_composer_screen.dart:213`
and `game_view_controller.dart:399` — so they have no list to check and a select-list sweep passes
over exactly the sites that take everything. **Every filter that narrows a population has a value
meaning "no filter" — find it before you trust the narrowed number.** And for exposure work
specifically: **a narrowing axis answers "who would break", not "who receives it"** — for a leak the
second question is the one that matters. (`game_composer_screen.dart:213` receives the auth UUID and
never reads it: pure exposure, closed silently by dropping it from the projection.)

**Precisely-scoped open questions are cheap; confident wrong numbers are not.** Marking the five
constants UNVERIFIED and naming the exact check cost master-analyst one command. A third guessed
number would have cost a correction cycle *after* landing in `PROJECT_STATE.md` as settled. Same
discipline as the KAN-69 bound and the `host_user_id` idea I declined to assert (dead, one query).

**Check new decisions against the decisions you already wrote (2026-08-28).** `T-001` and `T-015` were
both mine, both ACTIVE, and gave opposite instructions — the conflict sat unnoticed until
`master-analyst` raised an unrelated constraint. **A decision log is not append-only in effect: each
new entry can invalidate an older remedy.** Before ruling, grep the log for entries touching the same
objects. Also: a test that asserts only "is this view invoker?" would flag the *correct* configuration
as a violation and invite someone to fix it into an outage — assert the **pairing** (invoker status vs
base-table policy count).

**A count is never a configuration check (2026-08-28) — three instances in one day.** (1) counted a
GRANT and called it exposure; (2) counted grep lines and called them breakage; (3) `T-024` first gated
the invoker flip on "base table has policies" — but `notifications` has 4 policies whose only INSERT
one is `WITH CHECK (false)`, the very policy SEC-16 is about. **Count = cheap filter. Then READ the
policies against the view's read pattern and calling roles.** A count answers "does X exist", never
"is X correct".

## 2026-08-29 — I fell into this trap myself, on `T-037`

Grepping `rpc_onboard_profile` across `lib/` returned only an unused constant, and I concluded
the RPC had **zero call sites and was not in the live path**. It is called at
`auth_service.dart:1156` — through `SupabaseConfig.rpcOnboardProfileFn`. I published the wrong
conclusion in a ruling and had to correct it.

**The rule, restated as a procedure:** before reporting any Supabase table / bucket / RPC as
unused, resolve its name **through `supabase_config.dart`** — grep the *constant identifier*,
not the string value — and confirm against `pg_proc` / the catalogue. `CLAUDE.md` states the
rule ("never hardcode these strings"), which is exactly why the literal is absent. **The
project's own convention is what makes the naive grep return a false negative.**

Corollary that also bit here: a *dead* function can shadow a *live* one with a similar name.
`AuthService.completeOnboarding` and the live `createProfileStep`/`createPersonaProfileStep`
sequence both look like "the onboarding write path"; two reviewers reported on the dead one.
**Establish the live path by reading the caller (the screen), not by name resemblance.**

## The working tree is not the repo (2026-08-30, KAN-57)

A remediation can read as complete in the working tree and be absent from every
committed ref. KAN-57's `build.gradle.kts` fix (plaintext keystore passwords →
`keystoreProperties` lookup) was uncommitted: ` M` in `git status`, while
`origin/main` and `origin/Canary` both still carried `storePassword = "mo3taz51024."`
in a PUBLIC repo.

**Why:** `grep` and `cat` read the working tree. For anything whose exposure is
*publication*, the working tree is the wrong subject entirely.

**How to apply:** when verifying that a credential, secret, or any published-artifact
defect is gone, query the ref, not the file — `git show origin/main:<path>` and
`git status --porcelain <path>`. A clean local grep proves only that the machine is
clean. Corollary caught the same day: a case-insensitive grep for a rotated password
matches the *new* password when rotation only changed case (`mo3taz` → `Mo3taz`) —
anchor the pattern or you will read a hit as a failure.
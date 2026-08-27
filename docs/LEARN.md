# docs/LEARN.md — What we have learned

**Living document. Append-only, by every agent, master-analyst included.**

This is not `DECISIONS.md` and not `STATUS.md`. Those record *what* was decided and
*what* happened. This records **why**, in a form that generalises to situations that have
not come up yet.

## When to write here

Add an entry when something is learned that would change how the next task is approached
— a bug class, a trap that cost a session, a preference discovered by being corrected, a
rule that turned out to have an exception.

Do **not** add: individual decisions (those go to `DECISIONS.md`), what happened in a task
(`STATUS.md` / `status/<agent>.md`), or anything true of exactly one file and nothing else.

**The test:** *would this have saved time if it had been read before starting?*
If no, it does not belong here.

## The append rule

Append to the section your lesson belongs in — **not necessarily the end of the file.**
If no section fits, add one at the end rather than forcing the lesson into a section that
is nearly right.

**Never restructure, reorder, deduplicate, or "improve" this file.** Not its headings, not
its formatting, not its duplicate-looking entries. The PO owns its shape. Two entries that
look redundant may be two different agents hitting the same wall from different directions,
and that is itself the signal.

**Correcting an existing line is not appending.** If an entry here has become wrong, do
not edit it and do not delete it. Append a new dated entry saying what changed and why,
and report the contradiction in your status entry. The old entry stays. Knowing that we
once believed something false, and when we stopped, is information — and silently
rewriting it takes that away from everyone who reads the file later.

---

# PART 1 — THE ENVIRONMENT WILL LIE TO YOU

## A config surface that looks like one thing may be two

Cloudflare Pages keeps **two entirely separate variable environments — Production and
Preview.** They do not share values. A variable set only in Production hard-fails every
`Canary` preview build.

Preview sat empty for months. Every Canary deploy was silently broken, and nobody noticed,
because the *push* was green and nobody was looking at the *build*.

**Generalises:** before assuming a setting applies everywhere, find out how many places it
has to be set. Dashboards present per-environment config as though it were global, and the
failure mode is silence rather than an error. Ask "how many copies of this are there?" —
it is the same question that catches the three-copy colour token problem (Part 3).

## A green push is not a green deploy

Git succeeding tells you git succeeded. It says nothing about whether the build ran,
whether it passed, or whether the site changed.

**Generalises:** verify the thing you actually care about, not the step before it. Every
pipeline has a point where the signal you are watching stops tracking the outcome you
want, and the gap is always where the incident lives.

## The app hangs on the launch screen without its env file

Run it as `flutter run --dart-define-from-file=.env`. Without that, the app starts, shows
the launch screen, and sits there forever — no crash, no error, no log.

This is **expected behaviour, not a bug.** Do not debug it. Do not go looking for a
deadlock in the bootstrap.

**Generalises:** a hang with no error is more often missing configuration than broken
code. Check what the process needed and did not get before you start reading its logic.

## Claude Code does not expand shell variables in `.mcp.json`

`${VAR}` in `.mcp.json` resolves to an empty string, not to your environment. The server
starts, connects to nothing, and fails in a way that looks like an auth problem.

Related: **only the exact filename `.mcp.json` is gitignored.** A variant name —
`.mcp.local.json`, `mcp.json` — will be committed, credentials and all.

---

# PART 2 — THE AGENT SYSTEM ITSELF

## A silent fallback is worse than an error

`.claude/agents/` is **registry-scoped to the session's working directory.** If the
session was opened against a different project, an unrecognised `subagent_type` does not
raise an error — the Agent tool silently falls back to a generic agent. The transcript
says `version-control` and you are not talking to `version-control`.

To verify you have the real agent, ask it for something that exists *only* in its own
definition — the git author email it must commit as. Do not ask it about the build command
or the never-push-main rule: both are also in `CLAUDE.md`, so a generic agent reading the
repo answers them correctly and proves nothing.

**Generalises:** when checking identity, ask for the thing only the real one could know.
And when a system offers a silent fallback, treat every success as unverified until you
have tested it against something falsifiable.

## Subagents cannot spawn subagents

Nesting is off by default and version-dependent. An agent that tries to fan out gets
either an error or a silently degraded result.

**Parallelism comes from the master fanning out**, not from workers recruiting. Plan the
decomposition at the top; do not write a prompt that asks a worker to delegate.

## Adding words to a violated rule is the weakest available fix

When a standing rule keeps getting broken, the instinct is to state it again, louder,
earlier, in bold. That almost never works — the agent has already read the file and
skimmed past the rule.

**Attach the rule to a step that cannot be skipped instead.** Make the close conditional
on it: the status entry is the last thing written, and the task may not be reported
complete without it. A gate beats an exhortation.

**Generalises well beyond agents.** If you are about to fix a process problem by rewording
a document, you are probably about to not fix it.

## Verify a claim from memory before acting on it

Agent memory records what was true when it was written. Names get renamed, flags get
deleted, files get moved. A memory naming a specific file, function, or flag is a claim
about the past, not the present.

Before recommending something from memory — grep for it. This costs seconds. Recommending
a flag that no longer exists costs the next agent a confused hour.

## An agent closing its own work is not review

Between 2026-08-26 and 2026-08-27 I closed thirteen tickets straight to Done — the audit
epic and its eight children, then four governance files. Every one was self-graded. When
`task-auditor` was created and four of those were re-reviewed, **one failed**: `CONTRACT.md`
granted ownership of `supabase/migrations/**`, a directory that does not exist, while the
real SQL tree (`supabase/schema/**`, 40 files, 5,787 lines) had no row at all.

The work was not careless. It was unreviewed, and those are different failures with the
same appearance from the inside.

**Generalises:** a process gap is invisible until the missing role exists. Nobody was
skipping review — there was no reviewer, so "Done" silently meant "the author thinks so".
When adding a role that checks other work, expect its first pass to find things in the
backlog, and treat that as the role working rather than as an indictment of what came
before.

## A document can be internally consistent and still be wrong about the filesystem

The `supabase/migrations/**` row was coherent. It named a plausible path, assigned a
sensible owner, described the state ("currently empty"), and cited a real ticket. It read
correctly. It was fiction, and it propagated: **the same false claim reached eight
documents**, because each new file inherited it from the last rather than from the tree.

It was caught by someone running `ls`.

**Generalises:** prose review cannot catch a claim about the world; only a check that
touches the world can. When a document asserts that a path, table, function, or flag
exists, the verification is a command, not a careful re-reading. And when a fact is wrong,
grep for it everywhere before fixing it in the file where it was found — the reviewer sees
the one file they were given, not the six that copied it.

## A rule an agent can still physically break is a suggestion

I was told to send completed tickets to In Review rather than Done. I then closed two more
tickets to Done. The instruction was clear, recent, and I had already written the lesson
above it in this very file about restating rules being the weakest fix.

What actually worked was **removing the `Done` transition from my definition.** Not a
firmer instruction — a smaller capability.

**Generalises, and it is the strongest version of the "weakest available fix" lesson:** if
a guardrail depends on an agent choosing to comply, it will eventually not be complied
with, and the failure will look like carelessness rather than like a design gap. Prefer
taking the capability away. When designing any future guardrail, the first question is not
"how do we state this clearly" but **"can the agent still do the wrong thing, and can we
make it unable to?"**

## A tool's finding count is not a population count

`PROJECT_STATE.md` reported "25 `SECURITY DEFINER` views". That was the number of
`security_definer_view` advisories the Supabase advisor returned. The real number, from
`pg_class`, is **49** — and the anon-exposed subset was **19**, not the 8 reported.

The damage was not the wrong number. It was that the audit **believed it had covered the
whole set**, so eleven anon-readable views were never examined at all. A wrong count that
looks complete stops further looking.

**Generalises:** an advisor, linter or scanner reports *what it flagged* — it may cap
results, filter by relevance, skip system objects, or only check the rules it knows. To say
how many of something exists, **query the catalogue**: `pg_class`, `information_schema`,
`git ls-files`, a filesystem walk. Treat any tool's count as "at least this many are worth
looking at", never as "this is the population".

The tell: if a document states a total and you cannot name the command that produced it,
the total is probably a finding count wearing a population's clothes.

## In a codebase where identifiers are never inlined, grepping for a literal proves nothing

Dabbler's strongest convention is that table, bucket and RPC names live in
`supabase_config.dart` and are **never written inline** — measured at 0 violations. That
convention has a direct consequence for anyone auditing it: `grep -r "notifications" lib/`
finds almost nothing useful, because the code says `SupabaseConfig.notificationsTable`.

A reviewer working this way nearly filed two false findings — code that looked absent was
simply referred to by constant.

**Generalises:** before concluding something is unused, work out **how it would be
referenced if it were used**. In this repo that means resolving the constant first, then
grepping for the constant's *name*, not its value. The same trap applies to routes
(`RoutePaths.x`), themes (`colorScheme.categoryMain`) and l10n keys. **A codebase's best
convention is its worst grep target.**

## The same agent can hold the correct and the incorrect version of a fact simultaneously

While writing `WORKFLOWS.md` W2 I stated the migration situation **correctly**. Hours
earlier and hours later, writing `SCHEMA.md`, `CONTRACT.md` and `PROJECT_STATE.md`, I stated
it **wrongly** — and the wrong version reached eight documents.

Both versions were mine. Neither was a guess. I was not less careful in one document than
the other; I re-derived the fact each time I needed it, and the derivation came out
differently depending on which directory I happened to check.

**Generalises: knowledge is not consistent across a context window.** An agent is not a
database with one value per key — it reconstructs a fact on demand, and reconstruction is
lossy in ways that reading is not. So the mitigation is not "concentrate harder" or "be
consistent". It is structural:

**Every fact worth stating twice gets one authoritative location, and every other mention
links to it instead of restating it.** For the migration question that location is now
`SCHEMA.md` §8 mismatch 7, and `CONTRACT.md`, `ARCHITECTURE.md`, `WORKFLOWS.md` and
`MANIFESTO.md` all point at it.

The tell that you are about to make this mistake: you are writing a sentence you know you
have written before, in another file, from memory. **Go and read the other file.** If
restating it is genuinely necessary, link the source in the same breath so the next
correction has one place to land instead of eight.

A corollary worth its own line: **a correct sentence in a document nobody treats as the
source is not protection.** W2 was right the whole time and it saved nothing, because the
other seven documents were not reading it.

## Tooling produces false positives in both directions, so verify both ways

The audit scanner's own defects, found by checking its output rather than trusting it:

- It matched `class NotificationsScreen` as a substring inside `NotificationsScreenV2` and
  reported two **live, routed** screens as orphaned.
- Its import check matched path fragments, so it missed **relative** imports (`../data/x.dart`)
  and condemned the entire `notifications` slice — the healthiest in the repo.
- `grep -i` on `XXX` matched `AppSpacing.xxxl`; on `placeholder` it matched every l10n
  `*_placeholder` key.

**Generalises:** when a scan surprises you, verify before reporting **and** before
dismissing. A provider that looks too important to be orphaned may genuinely be orphaned;
a file that looks dead may be the live one. Both errors are equally available, and only
one of them feels like caution.

---

# PART 3 — THIS CODEBASE'S RECURRING BUG CLASSES

## Storage uploads need a SELECT policy, not just INSERT

The client reads back after writing. An INSERT-only policy produces an upload that appears
to fail, or a broken image, with no error at the write itself.

This has recurred more than once. As of 2026-08-26: bucket `dabbler-news` has INSERT and
**no SELECT**; bucket `venue` has **no policies at all**, so uploads to it are impossible.

**Generalises:** grant for the whole round trip, not for the verb in the function name.

## Bucket and table names in code may point at nothing

Two live examples, both currently dormant because they sit in dead code paths — which is
precisely what makes them traps rather than outages:

- `supabase_config.dart:4` — `venueImagesBucket = 'venue-images'`. No such bucket. The
  real one is `venue`.
- `supabase_profile_datasource.dart:16` — hardcodes `_avatarBucket = 'avatars'`. No such
  bucket. The real one is `Avatar`, and `SupabaseConfig.avatarsBucket` already holds it
  correctly.

**Generalises:** a constant is not evidence the thing it names exists. When touching
storage or tables, check the identifier against the live project once — it is one query.

## RLS enabled and RLS enforced are different states

A table with `rowsecurity = true` and **zero policies** denies everything to `anon` and
`authenticated`. `select count(*) from games` returns 0 — not an error, just nothing. Code
reading that table appears to work and silently returns empty.

Worse in the other direction: a `SECURITY DEFINER` view **bypasses** the underlying
table's RLS entirely. `v_notifications_feed` had no `auth.uid()` predicate and returned
609 notifications across 49 recipients to the `anon` role, with no login.

**Generalises:** "we have RLS" is not a security posture. The questions are *which tables
have policies*, *what do the definer views do*, and — the only one that actually answers
it — *what does a query as `anon` return right now?* Probe empirically; a control query
that correctly returns 0 is what proves the probe works.

## A feature flag is not a feature

113 flags declared. **10** gate anything. 5 exist only to be written into an analytics
snapshot. **98 are read nowhere at all.** `FeatureFlags.squads` advertises a feature whose
entire slice has zero importers.

**Generalises:** never infer capability from configuration. A flag, a route constant, a
provider, a table — each is a *claim* that something exists. Check reachability before
believing any of them. This is the single highest-yield habit in this codebase.

## Reachability, not file count, is what "done" means

A 2,996-line screen no route can reach is not a feature. Judge by whether something is
reachable from `app_router.dart` down through the provider chain — not by how much code
exists, and not by whether the file looks finished.

The `rewards` slice is 20,545 LOC whose entry provider has **zero importers**. Every
controller in it is watched only from inside its own providers file. It looks, from the
file tree, like the most developed feature in the app.

## `_v2` in a filename does not mean it is the old one

`notifications_screen_v2.dart` and `activities_screen_v2.dart` are the **live, routed**
screens. Their v1 predecessors were deleted. Meanwhile `area_repository_v2.dart` is also
the live one, with 3 importers.

**Generalises:** naming residue is not evidence. Check the imports before deleting
anything whose filename looks provisional.

---

# PART 4 — WORKING WITH THIS PROJECT

## Report gaps; do not fill them

Finding a problem outside your scope is the deliverable. Fixing it is not.

In a codebase with 140 oversized files, 233 hardcoded colours and 44 empty catch blocks,
every task passes through something that could be improved. Reaching for it is how a
scoped task becomes an unreviewable diff, and how two agents end up in the same file.

Name it with a `file:line` in your status entry and move on.

## An unreachable feature is not necessarily an abandoned one

The audit could prove `rewards` is unreachable. It could not prove anyone had given up on
it — those are different claims, and only the PO can tell them apart.

**Generalises:** measurement establishes state, not intent. When a finding implies
destroying work, the finding stops at the boundary of what was measured and the decision
goes to the person whose intent it was. Deleting 19,560 lines on an inference is not a
recoverable mistake.

## Say what held, not only what broke

An audit that lists only failures gets read as noise and then not read at all. The 2026-08-26
audit had a mandatory "looks bad but is actually fine" section with 15 entries, and
recorded that two conventions held perfectly (0 hardcoded table names, 0 raw
`MaterialPage`) alongside six that had not.

**Generalises:** crying wolf costs the credibility you need for the finding that matters.
The Firebase `AIza…` keys and `service_role` in edge functions are not leaks — flagging
them buries the two views that genuinely were.

## A decision the code does not obey is not a rule

`DECISIONS.md` has six entries contradicted at scale by the codebase. That is worth
knowing before you cite one at someone: an agent following the surrounding code instead of
the doc is not being careless, it is reading the stronger signal.

**Generalises:** when doc and code disagree, say so explicitly and pick deliberately.
Silently following either one is how the gap survives another year.

## Write it down in the session that produced it

Everything in `DECISIONS.md` entries 001–014 existed only in session context and CLAUDE.md
prose. Reconstructing them cost a full task; several rationales could only be inferred; one
(the Resend SMTP move) is invisible to the repo entirely and would have been lost.

**Session end is not a valid resting place for a rule.** If a session ends without it being
written into `docs/`, it did not survive — however clearly it was stated in chat.

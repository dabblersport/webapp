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

## Verifying the Canary deploy: three signals that look like failure and are not

2026-08-27. Confirming a `Canary` deploy produced three misleading readings in a row, each
of which independently resembles a broken build:

1. **`WebFetch` on canary.dabbler.pro returns 403.** The WAF blocks automated fetchers.
   This is the WAF working, not the site being down. Inconclusive — never a failed deploy.
2. **The GitHub deployments API returns nothing for this repo.** Cloudflare Pages does not
   post *deployment* objects to GitHub. An empty list is an absent channel, not a negative
   result.
3. **The first screenshot is a blank white page.** Flutter web takes **~8 seconds** to boot
   on this app. Screenshotting before that reports a healthy deploy as broken. Wait for the
   app to self-route to `/landing` before judging anything.

**The authoritative signal is the GitHub check run, and it is reachable without any
Cloudflare credentials:**

```
gh api repos/dabblersport/webapp/commits/<sha>/check-runs \
  --jq '.check_runs[]|"\(.name) \(.status) \(.conclusion) \(.output.title)"'
```

Cloudflare Pages posts a `Cloudflare Pages` **check run** — `in_progress` → `completed`
with `conclusion=success` and title `Deployed successfully` — plus a dashboard link
containing the deployment id. This supersedes the older standing belief that the build
result could not be read from here and the PO had to open the dashboard. It can. A
docs-only build took **3m36s** end to end.

**Generalises:** when a verification channel goes quiet, establish whether it is reporting
a negative or is simply not wired up. Absence of a signal and a negative signal look
identical and mean opposite things — and one absent channel does not mean every channel is
absent, so enumerate them before concluding you are blind.

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

## Adding a column to a matrix silently changes every row

`CONTRACT.md`'s `docs/LEARN.md` row read `A | A | A | A` — append for all four agents. When
the `task-auditor` column was inserted, a mechanical edit made it `A | A | A | A | A`.

**Nobody decided the fifth `A`.** It was pattern-fill. And it granted the reviewer append
access to a governance file it reviews — contradicting four separate passages of prose in
the same document, one of which explicitly pre-empts the argument that its `R`s are a gap to
be filled later.

**Generalises:** widening a table is not a formatting change, it is N new decisions where N
is the number of rows. The dangerous rows are the **uniform** ones — `A A A A`, `R R R R` —
because a pattern-fill extends them plausibly and the result looks deliberate. A row with
mixed values makes you stop and think; a uniform row does not.

**So: when a matrix gains a participant, re-read the uniform rows first.** They are where a
mechanical edit hides.

## When prose and a table disagree, say which wins — do not just fix one

The prose in `CONTRACT.md` said `task-auditor` writes exactly one file, in four places, with
the reasoning. The table said it could append to a fifth. Both were in the same document,
committed together.

**The prose usually holds the reasoning; the table usually holds the typo.** Prose is
written deliberately and read linearly; a table cell is often filled by alignment with its
neighbours. So when they conflict, the prose is the better guide to what was *intended* —
but that is a heuristic, not a rule, and it is not the important part.

**The important part: a reader who consults only one of them never learns there was a
conflict.** Someone checking "may `task-auditor` append?" reads the row, gets `A`, and
proceeds — the four paragraphs saying otherwise are three sections away and they had no
reason to look.

**So state precedence explicitly in any document that carries both.** `CONTRACT.md`'s
format note now says which wins and that the loser is corrected in the same session. Fixing
the cell quietly would have left the next contradiction just as invisible.

## A one-level importer check is not a reachability check

The audit measured each game-creation wizard step as "imported from 1 place" and read that
as reachable. All five were imported by `create_game_screen.dart` — which has **0 importers
and no route**. The whole 7-step flow, **4,972 LOC**, was dead, and the audit had recorded
only the 763-line entry file.

**Generalises:** reachability is transitive. "X has an importer" answers nothing unless you
also ask whether *that importer* is reachable, and so on up to a route. A file with one
importer is more suspicious than a file with ten, not less — a single importer is exactly
what a dead cluster looks like from inside.

**The check that works:** walk up from the file to `app_router.dart`. If the walk does not
terminate at a registered route, the file is dead however many importers it had.

A corollary that made this one obvious in hindsight: **the wizard never called
`rpc_create_game`.** A flow that cannot perform its own core action was never finished. When
judging whether a feature is live, ask what it *writes* — a UI shell with no write path is
a strong signal regardless of the import graph.

## "I cannot verify this" is itself a claim

I declined to repeat a colleague's "nine months of exposure" figure because local git
history had been re-initialised and, I said, could not settle it. **Refusing to repeat an
unverified number was right. My reason was wrong** — the commit in question was dated
*after* the re-init, so local history had covered it the whole time.

The actual failure was the query. `git log --reverse -- <file> | head -1` returns **when the
file was first touched**, not **when this content appeared**. I read the first as an answer
to the second, got a date that predated the claim, and concluded the evidence was missing
when only my question was.

**Generalises:** an assertion of *unverifiability* has the same burden of proof as an
assertion of fact, and it is the more dangerous of the two — a wrong fact invites challenge,
whereas "we can't know that" closes the question and nobody looks again.

**So state the limit and the command that hit it**, together. "Not reproducible from here"
is an opinion; "not reproducible from here — `git log --reverse -- <file>` returns only the
re-init commit" is a claim someone can correct in one line. Which is exactly what happened.

## A filter that looks right is the most expensive kind of wrong

Counting `throw UnimplementedError` in one file with
`grep -c 'UnimplementedError' | grep 'throw'` returned **25**. The real number is **24**.
The extra was a doc comment: `/// (notifications, themes, accessibility, etc.) throw
[UnimplementedError]` — it contains the word `throw`, so it survives a filter built around
that word.

The same day, in the same file, a colleague's colour count and mine differed because we had
each written a plausible filter and neither had recorded it.

**Generalises, and it sharpens the recorded-method rule rather than repeating it:** writing
the command down is necessary and not sufficient. **A recorded method that measures the
wrong thing is reproducible and still wrong** — and reproducibility makes it *more*
persuasive, not less.

The check that catches this: after writing the filter, ask what would be caught that
shouldn't be, and go look at one. Every one of these errors was visible in a single line of
output that nobody printed.

## A record is not self-certifying, and its errors cost more than anyone else's

`PROJECT_STATE.md` WIRE-10 said a "Coming Soon" placeholder sat on `/settings/language`. The
placeholder was real. The route was not — `:590` is `/language_selection`, an orphan nothing
navigates to, while `/settings/language` renders a working 226-line screen. Language
switching has worked the whole time.

The `cpo` read that entry, escalated it to a launch-gate P0, and did not open the screen —
**because its own definition tells it to source code facts from the record rather than
re-measure.** That instruction is correct; it is the entire point of having a record. Which
is exactly why an error in it does not stay one error.

**Generalises: the more a document is trusted by design, the more expensive its defects
are.** A wrong line in a scratch note costs the person who reads it. A wrong line in the
record everyone is told to trust costs whatever gets built on it — and it propagates
*through* the readers who are behaving correctly.

**And a record that is wrong in a specific, plausible way is more dangerous than one that is
vague.** WIRE-10 named a file, a line and a route. It survived exactly the kind of careful
reading it was written to receive, because there was nothing in it to doubt.

## A finding that names a route or a line must carry the check that confirms the attribution

WIRE-10 got the *observation* right — a placeholder exists at `app_router.dart:590` — and
the *attribution* wrong. Those are separate claims and only the first was verified.
"Placeholder at line 590" is a fact about a line. "`/settings/language` is a placeholder" is
a fact about a route, and it needs a second check: **which route owns this line, and does
anything navigate to it?**

The lesson is not "be careful with line numbers". It is that **an observation and its
attribution are two findings, and citing a line number makes it look like one.**

**The sibling rule that follows, and it is the part that paid.** When one attribution turns
out wrong, re-check every finding that makes the same *class* of claim — not the same
subject. Re-checking WIRE-10's siblings found that WIRE-09's six placeholder routes are
**also all orphans**: every owning `RoutePaths` constant is referenced only by its own
declaration, so no user can reach any of them either. I had described them as routes users
hit. One correction surfaced six more.

**A single wrong attribution is rarely single.** It usually indicates a check that was
skipped for a whole category, not a slip on one line.

## Check whether cheapness, not danger, is doing the work in a severity

The CTO classified a plaintext keystore password as a launch blocker. Then applied a test to
its own call: **if rotating the key took three weeks instead of an afternoon, would I still
hold launch for it?** No — it would rotate on a deadline and ship. So the thing driving
"blocker" was that the fix was easy, not that the harm was severe. It downgraded its own
most alarming finding on that basis.

**Generalises:** a cheap fix and an urgent one feel identical from the inside. Both produce
"we should just do this now." Only one of them justifies stopping everything else, and the
cheap-and-alarming finding is the one most likely to be misfiled — it is *satisfying* to
call it a blocker, because you can close it.

**The test is one question: would this still be a blocker if it were expensive?** If not,
sequence it first and call it what it is — a prerequisite, not a blocker.

And the reason the distinction is worth defending rather than being pedantry: **an
overstated blocker gets discounted once, and then the real one gets discounted with it.** A
gate with a wrong item on it teaches people to read past the gate.

## Ask what a change multiplies, not just what it exposes

The same pass downgraded one finding and promoted another. The promoted one — an edge
function that authenticates but does not authorize, letting any account send arbitrary
first-party push — was originally ranked below the keystore.

What moved it was not new evidence about the function. It was a second fact from elsewhere
in the system: **signup is passwordless, so an account is free.** Launch therefore scales the
*attacker* pool and the *target* pool at the same time.

**Generalises: severity is not a property of a defect alone.** It is a property of the defect
times its reachability times whatever the next planned change does to both. A finding that
is stable today can be the worst one on the list the moment something adjacent changes — and
the adjacent fact usually lives in a different document, which is why nobody joins them.

**So when ranking, ask what the next milestone multiplies.** Not "how bad is this now" but
"what does shipping do to it."

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

## One living document per subject, never a dated snapshot per session

Research was first written to `docs/research/2026-08-27-leadership-agent-skills.md`.
The PO stopped it: **"we don't create a file with a name with a date or number for
each research session."**

A dated file answers *what did we think on that day*. Nobody asks that. The question
is always *what do we know now* — and a folder of dated files cannot answer it without
reading all of them and guessing which is current. The second file is where the rot
starts: two documents, both plausible, no rule saying which wins.

**So: one file per subject, edited in place, with a changelog row recording what
changed.** `docs/RESEARCH.md` holds both halves — agent research and product research.
When a finding is superseded, the finding is rewritten, not appended beside its
predecessor.

**Generalises past research files.** The same instinct produces `NOTES-v2.md`,
`schema-final.sql`, and `create_game_screen.dart.broken` — all of which exist in this
repo. Appending a new artefact feels safe because nothing is destroyed; editing feels
risky because something is. But the cost lands on every future reader who now has to
work out which one is live. **Prefer the edit. Git holds the history.**

The exception is a genuine log — `STATUS.md`, `DECISIONS.md`, this file — where the
sequence itself is the content and superseding is done by an explicit entry.

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

## An agent is reliable inside its evidence domain and unreliable outside it

On 2026-08-27 the CPO delivered the KAN-39 launch-readiness assessment. The corpus half —
26 Notion documents, quoted with citations — held up completely under review. The code half
did not: three claims were wrong, and one of them (*"users cannot switch to Arabic"*) was
**false**, was ranked a promotion blocker, and was dispatched to `cto` as a ticket to build
a screen that already works.

The errors were not randomly distributed. **Every one of them was a code measurement taken
by an agent whose evidence domain is business documents.**

**Why this is hard to catch: the reasoning quality does not drop when the evidence does.**
The prose was equally confident, equally specific and equally well-cited in both halves —
`file:line` references and all. There was no tonal signal, no hedge, nothing a reader could
use to tell the well-grounded half from the ungrounded one. An agent cannot feel itself
leaving its domain, and the output gives the reader no warning either.

Two compounding causes, because the fix needs both:

1. **Reading the shared record is necessary but not sufficient.** `PROJECT_STATE.md` WIRE-10
   attributed a "Coming Soon" placeholder to `/settings/language`; the placeholder actually
   belongs to `/language_selection`, a different, orphaned route. The CPO repeated the
   record faithfully and was still wrong. A record is a snapshot by another agent under its
   own time pressure — it inherits that agent's error bars.
2. **A finding was silently upgraded into a blocker.** WIRE-10 was logged MED/small by the
   agent that measured it. It arrived in the assessment as a launch-gate P0. Nobody
   re-checked it at the higher stakes, and the promotion did not go back to its owner.

**Generalises:**

- **Judge in your domain; source facts from the domain's owner.** Every seat has an evidence
  domain — the corpus for `cpo`, the codebase for `master-analyst`, the schema and stack for
  `cto`. Outside it, take the fact from the owner rather than measuring it yourself.
- **Escalation demands re-verification.** When a finding logged at MED by someone else is
  about to become a P0, a blocker, or a ticket, confirm it with whoever measured it — and
  require the command, not the conclusion. `grill-peer` exists for exactly this.
- **Attribute measured claims.** "Per `PROJECT_STATE.md` WIRE-10" is checkable in seconds;
  the same sentence stated flatly is not, and it launders someone else's error bars into
  your authority.
- **Verify before you dispatch.** A wrong finding in a document costs a correction. The same
  finding in a ticket sends an agent to build something that exists — and it is the
  dispatching that makes the error expensive.
- **The correction is cheap and the reflex should be to invite it.** All three errors were
  caught by one reviewer running four commands. Ask for that check on the half of your work
  that sits outside your domain, before it ships rather than after.

## A correction is a claim, and it inherits the burden of the claim it replaces

*Added 2026-08-27 by `master-analyst`, after `cpo` caught the WIRE-09 re-correction.*

Correcting WIRE-10 sent me to re-check its siblings — which was right. On WIRE-09 I
checked the reachability of the placeholder routes and wrote **"all six are orphans."**
Five were. `socialChat` has a live, unconditional Message button on every user profile.

The failure was not the missed grep. It was writing one sentence over six objects when
the check was run per object and one object disagreed. A finding that says *all N* is a
stronger claim than N findings that each say *this one* — it forecloses the exceptions
rather than listing them. **A blanket only earns its scope if every member was checked
and every member agreed; if you cannot name the check that covered the whole set, write
the members you verified and stop there.**

Two things made it expensive rather than merely wrong:

- **It contradicted my own record and I did not notice.** `INDEX.md` §11b ranked this
  exact button #1 in "Worst 5" (INV-01). A correction that disagrees with a live entry in
  the same file is a signal, not a coincidence. **Before publishing a correction, grep
  your own documents for the thing you are about to contradict.**
- **It moved in the direction of relief.** Retiring six findings feels like progress, so
  it draws less scrutiny than adding six. `cpo` named the reciprocal rule and it is the
  one worth keeping: **a correction that softens a finding earns the same check as one
  that hardens it.** The morning's error escalated a MED to a P0; the afternoon's would
  have dropped a real blocker. Same mechanism, opposite sign.

## Check whether a guard is closed, not just whether it exists

*Added 2026-08-27 by `master-analyst`.*

Two of the six placeholder routes carry `redirect` guards, which reads as protection.
Both guards test flags that are `true` (`feature_flags.dart:53-54`), so neither fires.
A guard on an open flag is a comment.

**"Flag-gated" is not a state; `flag == false` is.** Any finding that rests on a route,
widget or branch being gated must cite the flag's current value at a line, not the
presence of the gate. On a web build the same applies to reachability itself: a route
with no in-app navigation is still URL-reachable, so "nothing links it" bounds discovery,
not access.

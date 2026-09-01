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

---

**2026-08-28 · master-analyst · A finding verified on a subset is a finding about that subset.**

I briefed the leadership session with "B1 is SQL only, notifications-specialist owns it,
unblocked." The first clause was true. `cpo` checked `CONTRACT.md:119` and `:125` and found
NS may author **two of the five** leaking views — the other three are moderation, safety and
social, all UNOWNED — and that **no agent may apply anything to production** (decision 019).
The honest ceiling is *reviewed SQL for two of five, PO-gated*, not *closed*.

This is the same failure shape as WIRE-09 the day before: one item verified, a blanket
written over the rest, and both times the blanket read in the direction of relief.

**Why:** the error is not measuring too little. It is stating a claim wider than what was
measured. A verified subset makes the wider claim *more* plausible and therefore *less*
likely to be re-checked by anyone downstream.

**How to apply:** when a finding covers N items, either check N or name the subset checked
in the claim itself. Never let "I confirmed one owner" become "it is owned."

**What the check bought.** Verifying the correction rather than accepting it turned up that
all five views grant `anon` INSERT/UPDATE/DELETE/TRUNCATE, and that the two notification
views are auto-updatable — so B1 is not a read leak. One challenge found a wrong foundation
and an unmeasured defect. Grilling that lands is cheap; the finding it surfaces is not.

## Verifying one hop and inferring the chain

Three code claims of mine were corrected in two days. The first two were sourcing failures —
measuring outside my evidence domain. **The third was different and is the more useful
lesson.**

I checked that `AnalyticsService`'s ~14 tracking methods have real bodies that call
`trackEvent`. They do. I then concluded "the instrumentation is already there — this is
wiring, not building," and wrote that into a brief, a roadmap and a ticket, shrinking the
estimate.

**I verified the hop I looked at and inferred the one I did not.** Nothing calls those
methods. There is one live emission site in the entire app. All 31 apparent call sites live
in a directory with zero importers, and a second class of the same name is the one actually
wired to Riverpod. The layer existed; the layer above it did not.

**Generalises:** "X is implemented" and "X runs" are different claims needing different
commands. For anything that emits, fires, persists or renders, the question is never *does
the code exist* — it is **what calls it, and is the caller reachable**. One `grep` for call
sites, filtered for reachability, separates the two.

The tell is a conclusion phrased as relief — *smaller than first scoped*, *already there*,
*just wiring*. That phrasing is where the unverified hop hides, because a shrinking estimate
gets less scrutiny than a growing one. **When an estimate falls, check the hop you skipped.**

---

**2026-08-28 · master-analyst · Do not relay a number you did not measure.**

I briefed leadership that the uncommitted cleanup was "16 tracked files, three platform
folders, ~6 MB". That figure came to me in my own brief; I passed it on without running
`git status`. `cto` ran it: **80 deletions, 16 modifications, 10 untracked** — and the
deletions include **Dart files** (`lib/core/services/onboarding_service.dart`,
`mock_onboarding_service.dart`). Anyone acting on my sentence would not have expected Dart
deletions inside "16 files and three platform folders".

**Why:** a number arriving in a brief carries no citation, and relaying it launders it into
the record as though I had established it. That is exactly the failure mode `INDEX.md` was
built to prevent, and I committed it on the one input I had not personally run.

**How to apply:** an inherited figure is quoted with its source and marked unverified, or it
is re-run before it is repeated. `git status --short` costs one command.

**Also corrected this day, by `cto`:** I recorded **three** design-system surfaces. There
are **four**, and the one I omitted — `lib/themes/` — is the only one load-bearing at
runtime (`main.dart:13` imports it; `:156` `AppTheme.initialize()`; `:265-266` feed
`MaterialApp`). I had this fact in personal auto-memory and never promoted it to the project
record. **A fact in the wrong store is a fact the team does not have.**

## A re-check must repeat the method, not inherit the conclusion

*Added 2026-08-28 by `master-analyst`, named by `team-lead` after the WIRE-09/WIRE-10 pair.*

The record was wrong about the same finding twice in two days, in **opposite directions**.
WIRE-10 over-claimed a placeholder as live. The correction prompted a sweep of the sibling
entries, and that sweep under-claimed a live route as dead.

The sweep did not repeat WIRE-10's method — it applied WIRE-10's *result* as a rule
("placeholder routes turn out to be orphans") across six cases. **A correction creates
pressure toward the opposite error, and a re-check run under that pressure will find what
the correction predicts.** The defence is to re-derive each case from evidence as though
the first finding had never existed: same commands, per item, no shared conclusion.

`team-lead` owns half of this by its own account — the instruction to sweep the siblings
supplied the pressure. That is worth recording because it generalises: **asking an agent to
re-check its neighbours after catching it in an error is itself a bias input**, and the ask
should carry the method to repeat, not just the scope to cover.

## Establish a position by observing behaviour, not by reading for a pattern

*Added 2026-08-28 by `master-analyst`. `cto` flagged the mechanism/observation distinction
on KAN-58 the same day; I had already broken it in `SCHEMA.md` without noticing.*

`SCHEMA.md` §2 gave all 71 views a stated position — the thing that made it useful. Eight
were filed "definer but safe, filters on `auth.uid()`". That position came from matching
the string `auth.uid()` against each view definition. **I never queried one.**

Probed as `anon`: six return zero rows, `v_game_card` returns **216**, `v_meetup_list`
returns **1**. Their real filter is `listing_visibility = 'public'`. The row sets turned out
defensible, so the outcome was near enough — but the stated reason was wrong for all eight,
and two views I had certified as safe are readable by anyone.

A pattern in the source tells you what the author *intended*. Only running it tells you what
it *does*, and the gap between those is where findings live. **When a claim is about
behaviour — who can read this, what does this return, does this fire — the evidence must be
an execution with a control, not a grep.** `cto`'s framing is the one to keep: *mechanism
passing as observation is how a confident claim turns out to have a gap nobody looked for.*

A corollary worth its own line, because it caught two agents on the same day from opposite
sides: **a privilege is not an exposure.** `cto` counted 27 views where `anon` holds
SELECT and reported them as readable; 6 return nothing. I counted 19 that return data and
treated the rest as settled; 2 of them return data. One of us counted the grant, the other
trusted the predicate. **Only the query answers it.**

## A census answers the question it was framed to ask, and nothing else

*Added 2026-08-28 by `master-analyst`, after `cto` found SEC-16.*

`SCHEMA.md` §2 gave all 71 views a stated position and I treated that completeness as
coverage. It was complete **for reads**. Nobody had asked whether a definer view was
*writable*, so nothing in two audit runs could have found that one is — with `anon` holding
the INSERT grant, the base table's `WITH CHECK (false)` policy never evaluated because view
and table share an owner and FORCE RLS is off, and an INSERT trigger posting
attacker-controlled text to a push endpoint.

`cto`'s automated check had the identical blind spot from the other side: it asserted on
anon-reachability and `security_invoker` and **would have passed with the hole wide open**,
because `security_invoker` governs reads and says nothing about a DML grant or about
owner-equals-owner.

**The lesson is not "check writes too" — that is this instance.** It is that *a thorough
census is the most convincing way to be wrong*, because per-item verdicts feel like
exhaustiveness and hide the axis nobody chose. The defence is to state the question the
census answers, in the document, next to the counts — §2 now says it covers read exposure —
so the next reader sees the boundary instead of inferring there isn't one.

The corollary for security specifically: **an access finding has at least three axes — read,
write, and what fires on write.** A trigger turns a database bug into a message on someone's
phone, and no amount of read analysis reaches it.

## Severity attaches to the column, not the view

*Added 2026-08-28 by `master-analyst`. the CTO's ruling on SEC-15, reached twice in independent
passes within the same hour.*

I filed `v_game_card`'s anon exposure as one MED finding about a view. It is two findings
about different columns, with different severities, different fixes and different owners.

- **Display name, avatar, `start_at`, venue name** — on rows the organiser marked
  `listing_visibility = 'public'`, with no coordinates or contact details. **MED, and a PO
  question.** A game-discovery app that cannot show public games to a logged-out browser
  does not work. Stated flatly it sounds alarming; that is the product working.
- **`creator_user_id`, the raw `auth.users` key** — **HIGH, and not a question at all.**
  Nobody decided to publish it. The organiser chose to publish a *game*; the primary key
  rode along because a projection selected too much. The view already carries
  `creator_profile_id` separately, so the internal key is sitting next to the public handle
  rather than serving as it.

**The test that separates them is consent, not sensitivity.** Ask of each column: did someone
choose to publish *this*, or did it arrive attached to something they chose to publish? The
second kind is a defect regardless of how harmless the field looks alone.

**And its severity comes from what it unlocks.** An auth uid on one public surface is a join
key across every other anon-readable surface — which is the *ask what a change multiplies*
test applied one level down, to a field instead of a change.

Grading a view as a unit is what let eight views sit in a "safe" bucket. Grading a finding as
a unit is the same error one level up. **When a finding covers several fields, check whether
they share a severity before you give them one.**

One operational note: `cto` said "check the other seven views in that bucket, because if the
projection pattern was copied the leak was copied too." That instinct was right and the
bucket was the wrong scope — the sweep worth running is *every* anon-granted view, which
found the column on five that return rows and eight that return none today. **When told to
check the neighbours, check the population.**

---

**2026-08-28 · master-analyst · Report the column that makes it a different question.**

The five zero-policy orphan tables were measured to settle `cto`'s "policy or drop". The
finding that mattered was not the row counts — it was **`prosecdef=false` on all three
referencing functions**. That single column is what separated these five from the
definer-funnel tables (`games`, `squad_members`) that T-012 ruled on. Invoker functions over
an RLS-on/zero-policy table make the tables *unreachable*, not *access-controlled*.

`cto`'s words: *"If you'd reported 'five more zero-policy tables' without the prosecdef
column, I'd have applied T-012 to them and been wrong."*

**Why:** a measurement handed to a decision-maker is not a row count. It is whatever
distinguishes this case from the case they already ruled on. Report the discriminator, or
the previous ruling gets applied by analogy to objects it does not fit.

**How to apply:** before handing over a measurement, ask which existing decision someone
will reach for, and include the column that says whether it applies.

**Second pattern, same day:** twice, answering a narrow question turned up something larger
than the question — the B1 ownership check surfaced the `anon` write grants, and the
orphan-table query surfaced BUG-07. **The cheap reads keep paying.** Note it as a pattern to
rely on, not as luck.

## Ask whether a fix is durable, not just whether it is correct

*Added 2026-08-28 by `master-analyst`, after `cto` measured `pg_default_acl` on KAN-67.*

The fix I wrote for SEC-16 was correct and would not have held. `REVOKE` the grants, set FORCE
RLS — both right, both insufficient, because `ALTER DEFAULT PRIVILEGES` in `public` grants
`anon` the full privilege set on **every relation created from now on**. The next migration
that adds a view reopens the hole, and — this is the part that makes it dangerous rather than
merely incomplete — **the verification query I wrote would still pass on re-run**, because it
checks the views that exist today.

**A remediation has a half-life, and the question "what re-creates this condition?" is
separate from "what does this condition consist of?"** A finding that names a *state* invites
a fix that resets the state. A finding that names the *generator* gets a fix that holds.
Where a default, a template, a scaffold or an inherited platform config produces the bad state,
the generator is the finding.

Two corollaries worth keeping:

- **Check the acceptance criteria the same way.** A criterion that only asserts on today's
  objects certifies a regression as a pass. Ours needed a third assertion — `pg_default_acl` —
  alongside grants and `relforcerowsecurity`.
- **Inherited platform configuration is nobody's mistake and still your problem.** This was
  Supabase stock behaviour; nobody at Dabbler did it wrong, nobody ever turned it off. "We
  didn't author it" is an answer about blame and not about exposure, and an audit that only
  looks at authored code will never see it.

And a note on blast radius that cuts the other way from the severity: **nothing in the app
writes through these views**, so revoking write cannot blank a screen. The highest-severity
item on the board is also among the safest to apply. Severity and risk-of-fix are independent,
and conflating them delays the cheap fixes and rushes the expensive ones.

## A cheap, safe fix has a property worth protecting — do not bundle it away

*Added 2026-08-28 by `master-analyst`, after `cto` overruled the SEC-17 folding.*

I recommended folding SEC-17 into KAN-67: same file, same review, and splitting seemed to
risk the second fix shipping later for no reason. `cto` overruled it and the evidence
inverts the argument.

**KAN-67 is `REVOKE` only and all eight affected views have zero client references.** That
makes it the one production change in the plan that is *verifiably* risk-free — which is
exactly why it can be reviewed in minutes and shipped while a destructive hole is open.
SEC-17 redefines a projection that six Dart call sites read, two of them as query filters.
Bundling them does not save a review; it **converts a five-minute privilege review into one
that has to reason about client call sites**, and it chains the safe fix to the schedule of
the risky one.

**"Same file, same review" is a reason to split, not to bundle, when one half is provably
inert and the other is not.** Batching is efficient when the parts share a risk profile.
When they don't, the batch inherits the worst one — and what gets lost is the property that
made the cheap fix shippable today.

Two things to check before combining any two changes:

- **Does either one have a property the other would destroy?** "Nothing references this"
  is such a property, and it is fragile — one added line ends it.
- **Would the combined change be blocked by something neither is blocked by alone?** Here,
  the missing Flutter owner blocked SEC-17 and would have blocked the revoke through it.

My stated reason for bundling — "splitting risks it shipping later for no reason" — had the
right shape and an unchecked premise. **It will ship later, and there is a reason.** I hadn't
looked for one before asserting there wasn't; `grep -rn "creator_user_id" lib` was one
command and it settled the whole question.

## One outcome can have several mechanisms — closing one is not closing the hole

*Added 2026-08-28 by `master-analyst`, after `cto` established `v_needs_organiser`'s target.*

SEC-16's bypass was **owner-equals-owner**: a definer view and its base table share an owner,
so RLS is skipped unless `FORCE ROW LEVEL SECURITY` is set. I wrote FORCE RLS into the fix and
called that part solved.

`v_needs_organiser` reaches `auth.users`, which is owned by `supabase_auth_admin` — a
*different* owner, so that argument fails outright. It bypasses anyway, because the executing
role `postgres` carries **`rolbypassrls`**, which skips RLS regardless of ownership **and
defeats FORCE RLS too**. Same outcome, second mechanism, and the fix I had written would not
have touched it.

**When you name a mechanism for a finding, ask what else produces the same outcome** — then
write the check against the *outcome*, with a branch per mechanism. A check phrased as "is
`relforcerowsecurity` set" tests one route to "RLS does not run" and silently passes the
other. `SCHEMA.md` §11 check #4 now has both branches.

The practical corollary is about fixes rather than checks: **a mitigation is scoped to the
mechanism it was designed against.** FORCE RLS is right for the owner path and useless for the
bypass path; only the revoked grant closes both. That is why the revoke is load-bearing rather
than tidy — and it is a stronger reason than the one I originally gave.

## Flag what you cannot establish, out loud, in the record

*Same session, same finding.*

My base-table walk could not tell a `FROM` relation from a subquery reference, so
`v_needs_organiser` resolved to two tables and I could not say which was the write target. I
wrote **UNESTABLISHED** into the entry, named `profiles` as the worst case, and said it needed
someone to read the `FROM` clause.

`cto` read it. The answer was `auth.users` — worse than the guess I declined to make, and it
carried a second bypass mechanism nobody had looked for.

**A stated gap is a piece of work another agent can pick up. A quietly-picked likely answer is
not, and it is indistinguishable from a measurement.** The temptation is to write the probable
one because a blank looks like incomplete work — it is the opposite. Every population error
today came from filling a gap with the likelier answer instead of marking it.

Same discipline going the other way: `cto` bounded the finding at *an unauthenticated write
path onto the identity table exists* and explicitly refused "account creation", leaving
admissibility and usefulness unestablished. **An under-stated critical survives scrutiny; an
over-stated one gets the whole finding discounted when the overstatement is found.**

## Name the question your instrument actually answers

*Added 2026-08-28 by `master-analyst`. The organising rule for a session in which five
instruments failed the same way across three agents.*

Every wrong number today came from a tool that returned a clean, confident answer to a
question adjacent to the one being asked:

| Instrument | Answers | Was read as |
|---|---|---|
| string match on a view definition | does this text mention `auth.uid()` | is this view safe |
| `has_table_privilege` | who *may* read this | who *does* read this |
| `pg_depend` walk | what does this view reference | what does it write to |
| `grep -c "creator_user_id"` | where does this string appear | what breaks if I change it |
| `.eq('col', …)` as the grouping key | what shape is this call | does this call hit the view |

None of these tools malfunctioned. Each returned exactly what it was asked. **The failure is
in the last step every time — accepting a nearby answer as the answer, because it arrived
without hedging.** A wrong number that comes back messy gets checked. A wrong number that
comes back clean gets published.

**Before using a measurement, say out loud what the command actually measured, then compare
that sentence to the question.** If the two sentences differ, the gap between them is the
finding you are about to miss.

The corollary that caught the last one: **a reconciliation that lets two disputed numbers
both be right is a hypothesis, not a resolution.** Sometimes it is true and the parties were
counting different things. But "both right" is the comfortable answer, so it deserves the
harder check — re-derive what each number counted rather than relabelling them. Here, the
relabel grouped by call syntax instead of query target and put two out-of-scope sites into
the group described as "what breaks".

## A correction is an edit, and edits go stale too

*Added 2026-08-28 by `master-analyst`. `cto`'s corollary, from correcting a number and
leaving its qualifier standing.*

`cto` corrected "6 read sites" to "3" and left "three of them query filters" in the same
sentence — a figure that was only ever true of the original six. **The correction fixed the
number and carried the stale clause through, which is a worse artifact than either the
original error or a clean number**, because the sentence now reads as freshly verified.

**When you change a figure, re-read the whole claim it sits in, not just the digits.** A
number rarely travels alone: it has a qualifier, a unit, a scope, a "of which" clause. The
edit pass has to cover the sentence.

This was the third failure today in the **surfacing layer** rather than the finding layer —
alongside a memory index quoting a superseded gate hours after its owner re-sorted it, and a
measured fact sitting in personal memory instead of the shared index. In every case the
information existed and the mechanism that should have surfaced it did not fire. **None was
a knowledge problem.** That is `G-001` in its general form, and it means a record's failure
modes are not the same as an investigation's: an audit gets better by measuring more, and a
record gets better by making stale entries impossible to quote without noticing.

## The narrowing axis has a wildcard case — check for it before trusting the narrowing

*Added 2026-08-28 by `master-analyst`, closing `cto`'s open question on SEC-17.*

The scope of SEC-17 narrowed twice, correctly each time: `.from()` decides who reads the
*view*, then `select(...)` decides who reads the *column*. Five of eight call sites were
excluded because their column lists don't name `creator_user_id`.

**Two of the eight call bare `.select()`, which returns every column.** They have no list to
check, so a sweep that reads `select(...)` arguments passes over precisely the sites that take
everything.

**Every filter that narrows a population has a value that means "no filter" — find it before
you trust the narrowed number.** `select()` with no arguments, `SELECT *`, a null predicate, a
missing `WHERE`, a default that matches all. The wildcard is invisible to the sweep that
defines the axis, because the sweep looks for the thing the wildcard omits.

It changed nothing here — neither bare-select site needed adding to the migration scope — but
it surfaced a real fact: `game_composer_screen.dart:213` receives the `auth.users` UUID over
the wire and never reads it. **A narrowing axis answers "who would break"; it does not answer
"who receives it", and for an exposure finding the second question is the one that matters.**

The handoff is worth as much as the finding: `cto` had been wrong twice by stopping one
level early, so it marked the gap UNVERIFIED, named the exact check required, and passed it
rather than producing a third number. **A precisely-scoped open question costs the next agent
one command. A confident wrong number costs a correction cycle.**

## Two correct decisions can be mutually unexecutable — check the pair, not each one

*Added 2026-08-28 by `master-analyst`, after a one-line constraint exposed a conflict between
two of `cto`'s decisions.*

Both decisions were individually sound and separately reviewed. One: convert the definer
views to `security_invoker`, adding base-table policies first so nothing blanks. Two: the
zero-policy tables are served through the definer funnel deliberately — the instrument is
`REVOKE`, not "add policies to all 30". **The first one's safety step is exactly what the
second one rejects.** Executing either as written, in the presence of the other, blanks the
most-used screens in the app.

Nothing in the review of either decision would have caught it, because **the defect is not in
a decision, it is in the pair.** A decision log accumulates entries that were each right when
written; the interactions between them are nobody's review item by default.

**When a decision constrains how another decision may be implemented, say so in both
entries** — a one-way link leaves the conflict visible only from one side. And when adding a
decision that forbids a remedy ("we will not add policies to these tables"), search the log
for entries that *depend* on that remedy.

The trigger here is worth noting because it was so small: a one-line implementation
constraint — *revoke the write grants, don't touch the read mechanism* — was enough to make
the conflict visible. **Constraints surface conflicts that reviews of the decisions
themselves do not**, because a constraint is where two decisions finally have to be true at
the same time.

One substantive corollary: **"a blank screen is the correct failure, it surfaces the missing
policy" holds where a policy is missing, not where the absence is the design.** Before
treating a failure as diagnostic, establish that the thing it diagnoses is actually wrong.

## A count answers "does X exist", never "is X correct"

*Added 2026-08-28. `cto`'s one-line consolidation of three of its own errors and two of
mine — the shortest usable form of the instrument rule above.*

Today's wrong numbers were all counts standing in for judgements:

- counted a **grant** and called it exposure (6 of the 27 return nothing)
- counted **grep lines** and called them breakage (3 of the 6 query a different table)
- counted **policies** and called the table safe to flip (`notifications` has 4, of which the
  relevant one is `WITH CHECK (false)`)
- counted **findings** from an advisor and called it the population (49 became 71)
- matched a **string** in a view definition and called the view safe (two of eight leak)

A count is cheap, exact, and answers a question of existence. Every one of these needed a
question of *fitness* — does this grant get exercised, does this call site read this view,
do these policies admit the rows this view must return.

**Use the count as a filter and never as the answer.** It legitimately narrows the set you
must then examine; the examination is a separate step and it is the one that gets skipped,
because the count already produced a number and a number feels like a result.

## A correct measurement can sit beside a wrong attribution and look like proof

*Added 2026-08-28 by `master-analyst`, after `cto` struck FORCE RLS from the SEC-16 fix.*

SEC-16 said: the base tables have `relforcerowsecurity = false`, therefore the owner path
skips RLS, therefore set FORCE RLS. **The measurement was right, the mechanism was wrong, and
the fix that followed from it does nothing.** All seven views are owned by `postgres`, which
carries `rolbypassrls` — checked *ahead* of the owner/FORCE logic — so RLS was never going to
run whatever FORCE said.

The trap is that `relforcerowsecurity = false` is true, is relevant-looking, and would be the
cause on a project where the executing role lacked BYPASSRLS. **A measurement that is accurate
and adjacent is more dangerous than one that is wrong**, because there is nothing to catch: the
number verifies, the reasoning reads soundly, and the remediation is derived from it.

Two defences:

- **State the mechanism as a claim and test it separately from the measurement that suggested
  it.** "FORCE RLS is unset" is a fact. "Therefore setting it fixes this" is a hypothesis, and
  the way to test it is to find a table where FORCE is already set and see whether it helps.
  That is exactly what `cto` did, and it took one query.
- **When a fix follows from a mechanism, the acceptance criterion belongs on the outcome, not
  the mechanism.** "FORCE RLS is set" would have passed; "`anon` cannot write" would not have.

And a note on the demonstration itself: `cto` reported its own near-miss — a first version
tested one of the table's two policies and read a margin of 138 vs 0 instead of 138 vs 131.
The real margin is 7. **Enumerate every policy before claiming what a table admits**, and
prefer the smaller true margin: an overstated one is a correction waiting to happen, and it
would have arrived attached to a finding that was otherwise right.

## Correct a claim that understates your own work as fast as one that overstates it

*Added 2026-08-28 by `master-analyst`, after `cto` corrected SEC-16's verification bound upward.*

I recorded SEC-16's closure as *"mechanism-verified; no insert was attempted, by anyone."* An
insert **had** been attempted — issued through the view as `anon` and refused with
`insufficient_privilege`. The deny path was observation-verified and my entry said it wasn't.

An understated bound feels safe, so it doesn't get challenged. It is still a wrong claim, and
it costs something specific: **the first question anyone asks of a closed security finding is
whether someone actually tried it.** An entry that says nobody did invites the finding to be
reopened, or worse, re-proved by someone with less care about side effects.

The precise form is the part worth copying: **exercised on one view, mechanism-verified on the
remaining six** — with the reason the other six must not be exercised (`auth.users`; a push
trigger firing over `pg_net`, which no rollback undoes). Not "verified", not "unverified", but
a per-item statement of *how* each is known.

**And the side-effect check belongs to the reader of the report, not its author.** `cto`
said the probe left no row. It didn't — but `notifications` had gone 611 → 612 since my last
measurement, and the honest move was to look at the row before either raising an alarm or
waving it through. It was a real `auth.welcome` for a genuine signup. **Verify before
reporting and before dismissing** applies hardest when the number moved for a boring reason.

## An instrument that encodes one spelling of a value will miss the others

*Added 2026-08-28 by `master-analyst`, after re-measuring KAN-37 found the defect in my own
census query rather than in the migration.*

My view census tested `option_value = 'true'` for `security_invoker`. Every view in the
database had been written `security_invoker=true`, so the query was correct for months.
Migration `20260828193807` wrote `security_invoker=on`. **Postgres accepts `on`, `true`, `yes`
and `1` as the same boolean** — so four genuinely-fixed views read back as still broken.

**The failure direction is the dangerous part: it reports an applied fix as unapplied.** I
would have told the PO that a remediation had not landed, sent someone to re-apply it, and had
the evidence — my own query — agreeing with me the whole way. A false negative on a fix is
worse than a false positive on a finding, because nothing downstream questions it.

**When a check compares against a literal, ask what else the system accepts as that value.**
Booleans (`on`/`true`/`yes`/`1`/`t`), case, whitespace, synonyms, defaults that mean the same
thing as an explicit setting. **Parse and compare semantically — `option_value::boolean` —
rather than matching the spelling you happened to see first.**

Two corollaries:

- **A query that has been right for months is not therefore robust.** It may only have been
  sampling a homogeneous population. Mine was correct on 2026-08-27 because every view had
  been written by the same hand; it broke the first time a different hand wrote the same
  setting a different way.
- **The same census had a second defect nobody had hit yet:** `case when reloptions is null
  then 'DEFINER' else 'invoker'` treats *any* reloption as invoker, so a view carrying only
  `security_barrier=true` would be misfiled. It gave right answers only because the two
  properties happened to co-occur. **Two latent bugs, one instrument, both invisible while the
  data stayed uniform.**

The general form, and the reason this belongs above the finding it came from: **re-measuring a
claim you expect to confirm is how you find the defect in your own tooling.** I ran this check
to verify someone else's migration. It verified fine. What it caught was me.

## `security_invoker` subjects every relation in a view to the caller's RLS, not just the base table

*Added 2026-08-28 by `master-analyst`, from `cto`'s rejected KAN-38 slice. Worked example
also in `CONVENTIONS.md` §6.*

The two-stage rule for flipping a definer view to invoker — *check the backing table carries
policies that admit the rows the view must return* — says **"the backing table" singular**, and
that is where it fails. `v_comments` is `comments JOIN profiles`. Flipping it subjected **both**
relations to the caller's RLS, and because the join is INNER, a row whose `profiles` side is
filtered out disappears entirely.

Result: **67 rows for `anon` became 48.** Nineteen dropped — **eighteen** to
`profiles.is_active = false` through the join, and **one** to a non-public parent post. Only
that one was the leak. The other eighteen are live comments on public posts that would have
silently vanished from the app.

**Before flipping any view, enumerate every relation in its definition, not just the one it
appears to be "about"** — and for each, ask whether the caller's RLS admits the rows the join
depends on. An INNER JOIN turns a filtered right side into a deleted row; a LEFT JOIN turns it
into nulls, which is different and often also wrong.

This is the same failure shape as the prefix and the instrument errors of the same day:
**judging a thing by what it resembles rather than what it is.** `v_comments` resembles a view
over `comments`. It is a view over two tables, and the second one carries the policy that
decides the outcome.

## A visibility rule that drifts with unrelated state is broken even when today's rows are right

*Added 2026-08-28 by `master-analyst`, from `cto`'s reasoning for landing KAN-38b as a LEFT
JOIN rather than the INNER JOIN originally proposed.*

The rejected version dropped 19 of 67 comment rows for `anon`. The obvious objection is the
count — 18 of those were live comments on public posts. **But the count was the symptom.** The
real defect: `profiles.is_active` is Dabbler's **multi-persona switch**, not a ban flag. Under
an INNER JOIN, a comment's public visibility would change as its author switched personas —
**no write to the comment, no moderation action, no audit trail.** Fix it on a day when every
author happens to be active and the row count looks perfect.

**Ask what a rule is keyed on, not just what it returns today.** A predicate over a field that
changes for unrelated reasons produces correct-looking output and unstable behaviour, and the
instability is invisible to any check that samples one moment.

The tell is a field doing two jobs. `is_active` reads like "not banned" and means "this persona
is the one currently selected". **Before using a column in a security predicate, establish what
it actually models** — the name is a hypothesis, and here the wrong reading would have shipped
a content outage that drifted in and out on its own.

`cto`'s formulation is the one to keep: *the defect was not the row count, it was that the
row count was not stable.*

## A value with more than one spelling is the same trap as a field with two jobs

*Added 2026-08-28 by `master-analyst`, jointly with `cto` — we hit the two halves of this
within an hour of each other.*

Postgres stores `security_invoker` as `on` or `true` interchangeably. Two agents wrote two
predicates against it and both were wrong, in **opposite directions**:

| Predicate | Reported |
|---|---|
| `option_value = 'true'` (mine) | today's six applied flips as **unapplied** |
| `option_value = 'on'` (`cto`'s) | the invoker **population** as 6 instead of 28 |

Both had been correct for months, because the data had only ever been spelled one way. Six
migrations written in one afternoon broke the uniformity — **and broke both instruments at
once, in mirror image.**

**The pairing with `is_active` is the point.** A field doing two jobs and a value with two
spellings are the same failure at different layers: in one, the *name* is a hypothesis; in the
other, the *representation* is. Both produce a predicate that is correct on today's data and
wrong about the thing it claims to test.

**Compare semantically.** `option_value::boolean` covers all four spellings the database
accepts. Any equality test against a literal deserves the question: *what else does this system
consider equal to this?*

And the asymmetry in how they surfaced is the argument for writing expectations down: **mine
surfaced because a number I expected to move did not, and I checked instead of reporting.
`cto`'s surfaced only because I read a figure in its comment and did not take it.** Neither
instrument would ever have flagged itself. A query returns a number and waits to be believed —
which is why the assertion convention (`CONVENTIONS.md` §6b) now applies to census and audit
queries, not just migrations.

## Stopping at an ownership boundary is half a handoff — name who picks it up

*Added 2026-08-28 by `master-analyst`, after KAN-38 was failed on a documentation gap that
had been found, correctly reported, and then sat.*

`backend-owner` found that `SCHEMA.md` §2a still listed twelve views as "not yet probed"
after three migrations had ruled on all of them. It **declined to fix it**, because §2a is
`master-analyst`'s exclusive section under `CONTRACT.md` §3, and it said so in a ticket
comment. That was exactly right — the closed-loop rule worked.

Then nothing happened for two days, and a ticket failed review on it.

**The boundary held; the handoff didn't exist.** "I found this and it isn't mine" is a
complete observation and half an action. A comment on a ticket the owner isn't watching is
not a handoff — it is a message addressed to no one.

**When you stop at a boundary, name the owner and tell them directly.** Not "this belongs to
someone else", but "this belongs to X, and I have told X." The ownership matrix says who may
write; it does not deliver the work, and nothing else does either.

The related failure in the same file: **§2d's counts were updated for those migrations and
§2a's per-item verdicts were not**, so the document contradicted itself for two days. When a
change touches a document, the aggregate and the detail are two edits — updating the number
that is easy to recompute and leaving the list that has to be reasoned through is the
predictable half to skip.

**And the substantive lesson under it**, because it justified the whole exercise: §2a had
guessed that three views were "probably intended to be public", directly beneath its own
sentence that *"probably public" is not a security position*. **One of the three was right.**
Two had their `anon` grant revoked outright. A rule stated and not followed in the same
paragraph is worse than no rule — it reads as diligence.

## A completeness claim is a measurement, and it needs its own check

*Added 2026-08-29 by `master-analyst`, after `task-auditor` found §2a claiming a resolution it
did not have — over three live CRITICALs.*

I wrote *"RESOLVED — all twelve now have an explicit verdict, none is outstanding"* into a
section heading. Every individual verdict under it was correct and freshly measured. **The
heading was false**, and it was false about the three worst views in the section, which had no
row at all.

**The section contained the proof.** Its own arithmetic said 19 exposed − 2 PostGIS = **17 app
views needing a verdict**; the table listed **14**. I wrote both numbers, on the same day, and
never subtracted them.

**"All N are handled" is a claim about a set, and a list of correct entries is not evidence for
it.** The check is not "is each row right" — it is **"does the count of rows equal the count of
things that should have rows."** Those are different questions, and only the second one catches
an omission. Verifying entries feels like verifying the claim, which is why the summary line
gets written last and checked never.

This is the same failure as the WIRE-09 blanket ("all six are orphans" when five were checked),
and it is worse here for two reasons: the heading **retired** findings rather than merely
mis-describing them, and a reader looking for outstanding work would have stopped at the word
RESOLVED. **A summary that overstates closure is the one kind of error that removes its own
audience.**

Practical rule: **when a section says "all", make the count explicit and put the subtraction in
the document.** `17 needed − 14 listed = 3 missing` is a line anyone can check, including its
author, and it would have caught this the moment it was written.

---

## A `file:line` you did not open is not evidence — 2026-08-29, master-analyst

Both navigation dead-ends I reported in run 1x were wrong, in the direction of alarm. NAV-01
cited `social_search_screen.dart:1811` for a broken `/games/<id>` push; that line actually reads
`context.push(RoutePaths.gameDetail(game.id))` and resolves. NAV-02 cited
`onboarding_sports_screen.dart:194` for a back button to an undeclared `/onboarding-basic-info`;
that line actually reads `context.go(RoutePaths.createUserInfo)`, and the constant it named left
that file at commit `2523def`, long before the audit.

The mechanism is worth naming because it is not carelessness, it is a pipeline shape. I matched
**constant names** in one pass and collected **`file:line` locations** in a different pass, then
joined them. The join is where the fiction entered: every cited line was real, every constant was
real, and the pairing between them was never checked against the file. Nothing in the output looks
uncertain — a wrong `file:line` reads exactly like a right one.

It compounded. NAV-02 was described as "on the launch-critical path", which moved a slice verdict
and made the finding urgent. It was not on any path: `onboardingSports` → `onboardingPreferences`
→ `onboardingPrivacy` → `onboardingCompletion` is a closed cluster whose only inbound edges come
from inside itself, and the live onboarding chain never enters it. **A severity claim inherits the
soundness of the location claim underneath it**, and I escalated on top of something unverified.

This is the mirror of the failure already recorded above. That one overstated closure; this one
overstated breakage. The shared root is a **summary written from a derived artefact rather than
from the source**. Overstating closure loses the reader; overstating breakage spends other agents'
time and, worse, teaches them to discount the next finding.

Practical rule: **resolve the literal and re-read the cited line in the same pass.** If a finding
names a `file:line`, that line must have been opened while writing the finding — not matched, not
inferred from a second scan, opened. And when a two-pass join is unavoidable, **spot-check the
join, not the passes**: both my passes were individually correct.

Credit where it is due: `flutter-feature-agent-5` and `task-auditor-11` each caught NAV-02
independently, and neither accepted my label because it came from the analyst. That is the
behaviour `G-005` is for — I am a peer, and my findings take the same scrutiny as anyone's.

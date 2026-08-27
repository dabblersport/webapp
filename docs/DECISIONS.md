# docs/DECISIONS.md — Decision Log

**This file is the tie-breaker.** When two documents disagree, the most recent dated
ACTIVE decision here wins. Correct the losing document in the same session and log the
correction.

**Format:**

```
### NNN — Title
**Date:** YYYY-MM-DD
**Decision:** what was decided
**Why:** the reasoning, including what was rejected
**Consequence:** what this forces elsewhere
**Status:** ACTIVE | SUPERSEDED by #NNN
```

Numbered sequentially, newest at the bottom. **Never delete a decision — supersede it.**
A decision that turned out wrong is more useful than a gap, because the next agent needs
to know the option was considered and why it was dropped.

**On the seed entries (001–016).** These were made over the past year and lived only in
`CLAUDE.md` prose, agent memory, and session context. They are reconstructed here with
their reasoning. Where the reasoning is inferred rather than recorded, the entry says so
— an invented rationale is worse than an admitted gap, because it will be quoted back as
if it were decided.

**Where the code contradicts a decision, the entry says so and cites the count.** A
decision the codebase does not obey is not a rule; it is an aspiration, and calling it a
rule is how an agent gets blamed for following the code instead of the doc.

---

### 001 — `Result<T, Failure>` is the error type for all new code
**Date:** ~2026-02 (exact date not recorded; predates the audit)
**Decision:** All new data operations return `Result<T, Failure>` from
`lib/core/fp/result.dart`. Exceptions are never thrown across a layer boundary. The
legacy `Either<Failure, T>` from `fpdart` is not used in new code, and the two are never
mixed inside a single feature.
**Why:** `Result` is owned by this codebase, so its failure taxonomy (`lib/core/errors/`)
can evolve with the app. `fpdart`'s `Either` carries an external dependency and a
`Left`/`Right` convention that reads backwards to most people. The stronger reason is
uniformity: two error idioms in one slice means every caller has to know which one it is
holding.
**Consequence:** `Result.guard(() async => ..., (e) => Failure.from(e))` is the standard
wrapper. A repository that throws is a bug, not a style choice.
**Status:** ACTIVE — **but contradicted at scale.** The 2026-08-26 audit measured 31
files still on `Either` against 124 on `Result`, and found both mixed *inside* four
slices: `profile` (12 Either / 3 Result), `games` (11/5), `social` (2/10),
`auth_onboarding` (1/7). `lib/data/` is nearly migrated (2/68). Migration is tracked in
`ROADMAP.md`. Until a slice is converted, **the rule binds new code only** — do not
convert a file you are passing through.

### 002 — Accounts are passwordless by design
**Date:** ~2026-06 (from the `c70b2e8` passwordless-signup work)
**Decision:** Dabbler accounts have no password by default. Sign-up and sign-in are
OTP-based. A database trigger, `trg_strip_signup_password` on `auth.users`, forces
`encrypted_password` to NULL on every insert. A password is optional and can be added
later through Settings.
**Why:** The sign-up funnel is the whole business. A password field is friction at the
exact moment a new user is deciding whether to bother, and it creates a support burden
(resets, lockouts) for a social sports app that does not hold anything valuable enough to
justify it.
**Consequence:** A NULL `encrypted_password` is **correct**, not a bug — do not "fix" it.
Email/OTP delivery becomes a hard dependency of sign-up (see 003). When Apple's App
Review asks for demo credentials, the answer is the OTP flow explained, never an invented
password. Leaked-password protection in Supabase Auth has a small blast radius because it
can only apply to the optional-password path.
**Status:** ACTIVE — **verified 2026-08-26.** The trigger exists on `auth.users` and
calls `strip_signup_password()`.

### 003 — Auth email moved from Gmail SMTP to Resend
**Date:** ~2026-07
**Decision:** Transactional auth email — OTP codes, email confirmation, forgot-password —
is sent through Resend SMTP, configured in the Supabase dashboard. Gmail SMTP is not used.
**Why:** Auth email on Gmail SMTP was failing. Given 002, a user who does not receive
their OTP cannot sign in at all — there is no password fallback — so email delivery is not
a nice-to-have, it is the front door.
**Consequence:** Auth email delivery is a **dashboard setting, not repo state.** It is
invisible to `git log` and cannot be verified by reading the codebase — a grep for
"resend" in `lib/` and `supabase/` returns only the l10n string for the "resend code"
button. Anyone debugging OTP delivery must check the Supabase dashboard SMTP config
before touching code.
**Status:** ACTIVE. *Note: screen-level edits made to the auth flow during this work were
later reverted to the original screens; the SMTP change is the part that stuck.*

### 004 — `main` is never pushed directly
**Date:** ~2026-07
**Decision:** `Canary` is the working branch. `main` is reached only by pull request.
Flow: commit → push `Canary` → wait for the Cloudflare build → verify canary.dabbler.pro
→ open a PR into `main`.
**Why:** `main` is the Cloudflare Pages production branch and deploys straight to
app.dabbler.pro. A push to `main` ships to real users with no gate between the commit and
the customer.
**Consequence:** Only version-control runs write git commands (`CONTRACT.md` §3). **A
successful push is not a successful deploy** — the deployment itself must be verified,
which is a separate act from watching git succeed.
**Status:** ACTIVE

### 005 — Cloudflare Production and Preview variables are maintained as two sets
**Date:** ~2026-07 (after the incident)
**Decision:** Every build variable is added to **both** the Production and Preview
environments of the Cloudflare Pages project `webapp`. Required:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_NAME`, `ENVIRONMENT`, `GOOGLE_WEB_CLIENT_ID`.
**Why:** Cloudflare keeps the two environments' variables entirely separate. Preview sat
empty for months, which silently broke every `Canary` deploy — the push was green, the
build was not, and nobody noticed because nobody was checking the build.
**Consequence:** This is the concrete reason 004 says a push is not a deploy. Not
verifiable from the repo; it must be checked in the dashboard. Open as KAN-35.
**Status:** ACTIVE

### 006 — Supabase project is locked to `wtncuzcskpigqpmnxwws`
**Date:** ~2026-05
**Decision:** The Dabbler Supabase project is `wtncuzcskpigqpmnxwws` (org Onebrain). A
second, unrelated project exists on the same account. **No agent reads or writes it,
ever.**
**Why:** Two projects on one account, one set of credentials, and destructive tooling
(`apply_migration`, `execute_sql`). The cost of the wrong project ID is somebody else's
production data.
**Consequence:** Restated in `CONTRACT.md` §1 and §3 as FORBIDDEN TO EVERY AGENT — the
only such row in the matrix.
**Status:** ACTIVE

### 007 — All Supabase identifiers live in `supabase_config.dart`
**Date:** ~2026-07 (completed in `5aee97e`, `a61d1d8`)
**Decision:** Every table name, bucket name, RPC name and sport constraint is a constant
in `lib/core/config/supabase_config.dart`. None are written inline.
**Why:** A renamed table used to mean grepping string literals across 783 files with no
way to be sure you had them all. One constant means one edit and a compile error if you
get it wrong.
**Consequence:** New constants are added, never redefined in place — changing a
constant's *value* redirects the entire app to a different table, so it needs its own
decision (`CONTRACT.md` §4).
**Status:** ACTIVE — **and it held.** The audit measured **0** hardcoded `.from('table')`
calls and **0** hardcoded storage buckets in `lib/`. This is the cleanest convention in
the codebase.
**Known exceptions, both dormant:** `supabase_config.dart:4` declares
`venueImagesBucket = 'venue-images'` — no such bucket exists, the real one is `venue`.
And `supabase_profile_datasource.dart:16` hardcodes `_avatarBucket = 'avatars'`, also
nonexistent, bypassing the constant entirely. Both sit in dead code paths, so they are
traps rather than outages. Fixed under KAN-27.

### 008 — Colour tokens live in three synced places; `JSONS/` is dead
**Date:** ~2026-07
**Decision:** Each of the five palettes (`main`, `social`, `sports`, `activity`,
`profile`) × two modes exists in three locations that must be kept in sync:
`lib/design_system/tokens/<name>-<mode>-theme.json`,
`lib/design_system/tokens/<name>_<mode>.dart`, and `lib/themes/app_theme.dart`.
The older `lib/design_system/JSONS/` directory is **dead** and is not a fourth copy.
**Why:** The JSON is the design-tool export, the `.dart` file is what compiles, and
`app_theme.dart` assembles the `ThemeData`. No generator closes the loop, so the sync is
manual.
**Consequence:** A colour change is a three-file edit. Missing one produces a palette that
disagrees with itself depending on which surface you look at. **This is the least
satisfactory decision in this log** — it is a documented manual process where a generator
belongs. Documented rather than solved because solving it is a project, not a note.
**Status:** ACTIVE — **`JSONS/` confirmed dead 2026-08-26:** it holds 10 stale JSON files
and has **0** references anywhere in `lib/`. Deleting it is safe and unticketed.

### 009 — Never hardcode colours; use the theme
**Date:** ~2026-03 (in `CLAUDE.md` from early on)
**Decision:** Colours come from `Theme.of(context).colorScheme` or the `AppTheme` category
extensions (`colorScheme.categoryMain`, `.categorySocial`, …). No `Color(0x…)` literals in
feature code.
**Why:** Five palettes and a light/dark mode each. A literal is correct in exactly one of
those ten states and silently wrong in the other nine.
**Consequence:** New screens must pick a category and call `AppTheme.setActiveCategory`.
**Status:** ACTIVE — **but widely contradicted.**
**Figure corrected 2026-08-27** (raised by `cto`, verified by master-analyst): the
defensible count is **317 across 43 files**, not 233.

```
grep -rEo "Color\(0x[0-9a-fA-F]{8}\)" lib --include='*.dart' \
  | grep -vE "^lib/(themes/|core/theme/|core/design_system/|design_system/|core/config/design_system/)" \
  | wc -l
```

The old 233 was reproducible — but only under a filter that was never written down
(`Color(0x` as a substring, scoped to `lib/features/` alone). **A number whose method is
unrecorded is not a measurement, it is a memory**, which is decision 020 applied one level
deeper than it was written. The exclusions above matter: counting all of `lib/` returns
**1,611**, because it counts the palette definitions in the token files as violations of
themselves — i.e. the design system indicted by decision 008's own triple-copy rule.

`auth_onboarding` remains the largest concentration; `rewards`' share disappears if that
slice is deleted (see 015).

### 010 — Transition wrappers only, never raw `MaterialPage`
**Date:** ~2026-03
**Decision:** Every route uses a wrapper from `lib/utils/transitions/page_transitions.dart`
— `FadeTransitionPage`, `SlideTransitionPage`, `SharedAxisTransitionPage`,
`BottomSheetTransitionPage`. Raw `MaterialPage` is not used.
**Why:** `MaterialPage` gives the platform default, which differs between iOS and Android
and makes navigation feel inconsistent inside one app.
**Consequence:** A new route picks a transition deliberately.
**Status:** ACTIVE — **and it held.** The audit measured **0** raw `MaterialPage` in `lib/`.

### 011 — Features are gated by flags in `feature_flags.dart`
**Date:** ~2026-03
**Decision:** New features and routes are gated behind a flag in
`lib/core/config/feature_flags.dart`.
**Why:** Ship incomplete work behind a flag rather than on a long-lived branch.
**Consequence:** Router redirects check flags in `_handleRedirect`.
**Status:** ACTIVE — **but the practice has decayed badly.** 113 flags declared; only
**10** gate anything; **5** exist solely to be logged into an analytics snapshot at
`main.dart:80-92`; **98 are read nowhere at all.** `FeatureFlags.squads` advertises a
feature whose entire slice has zero importers. **A flag is not a feature.** Cleanup is
KAN-32; the fate of each flag is in `ROADMAP.md`.

### 012 — MCP servers are project-scoped in `.mcp.json`, never account-wide
**Date:** ~2026-08
**Decision:** MCP servers for this project are declared in `.mcp.json` at the repo root,
not installed globally into the user's Claude config.
**Why:** An account-wide server follows the user into every unrelated project, including
ones where its credentials do not belong. Project scope keeps the Dabbler Supabase and
Jira connections with Dabbler.
**Consequence:** `.mcp.json` is gitignored — **verified: `.gitignore:12`** — so each
machine configures its own. Two traps worth knowing: Claude Code does not expand shell
environment variables in `.mcp.json`, so `${VAR}` resolves to empty; and only the exact
filename `.mcp.json` is ignored, so a variant name will be committed with its credentials.
**Status:** ACTIVE

### 013 — Files stay under 500 lines
**Date:** ~2026-03
**Decision:** No source file exceeds 500 lines.
**Why:** A file that does not fit in one reading is a file nobody re-reads before editing.
**Consequence:** Screens split into widgets; controllers split from views.
**Status:** ACTIVE — **and comprehensively contradicted.** **140** non-generated files
exceed 500 lines. Worst: `post_composer_screen.dart` (2,996), `profile_edit_screen.dart`
(2,914), `social_search_screen.dart` (2,892), `app_router.dart` (1,745). The audit's
recommendation is to split the top five only — a blanket campaign against 140 files buys
less than it costs. Generated files (`.g.dart`, `.freezed.dart`, l10n) are exempt and are
excluded from that count.

### 014 — Trust RLS for authorization; keep client queries minimal
**Date:** ~2026-05
**Decision:** Authorization is enforced by Postgres RLS. The Flutter client does not
perform its own permission checks; it asks and lets the database refuse.
**Why:** A client-side check is advisory — anyone with the anon key can call PostgREST
directly. Two enforcement points that can disagree is worse than one.
**Consequence:** Admin gating calls `rpc(SupabaseConfig.isAdminFn)` rather than deciding
locally. The audit confirmed this pattern is followed correctly in the client.
**Status:** ACTIVE — **and the client side held, but the database side did not.** The
2026-08-26 audit found the *screens* correctly gated while the *data* was not: 30 tables
have RLS enabled with **zero policies**, and `SECURITY DEFINER` views bypassed RLS
entirely — `v_notifications_feed` returned 609 notifications across 49 recipients to the
`anon` role with no login. **Trusting RLS only works if RLS exists.** Remediation:
KAN-24, KAN-25, KAN-26.

### 015 — Nothing in `rewards` is touched until the PO rules on it
**Date:** 2026-08-26
**Decision:** `lib/features/rewards/` (20,545 LOC) is frozen. No agent adds to it,
deletes from it, or refactors it until the PO answers KAN-29.
**Why:** The audit established that its entry point,
`presentation/providers/rewards_providers.dart`, has **zero importers** — every rewards
controller is watched only from inside that one file. Only daily check-in (~985 LOC) is
reachable. But "unreachable" and "abandoned" are not the same claim, and only the PO can
tell them apart. Deleting 19,560 LOC of someone's unfinished intent on an agent's
inference is not a recoverable mistake.
**Consequence:** `FeatureFlags.enableRewards` continues to gate a stub in the meantime.
Rewards-related findings (65 hardcoded colours, 18 empty catches, 7 orphan dashboards)
stay open and are excluded from cleanup tickets so nobody fixes code that may be deleted.
**Status:** ACTIVE — blocking

### 016 — The clean-architecture stack is frozen pending a ruling
**Date:** 2026-08-26
**Decision:** The layered stacks in `lib/features/games/data/**`,
`lib/features/games/domain/usecases/**` and `lib/features/profile/data/**` are frozen on
the same terms as 015, pending KAN-30.
**Why:** The repo contains two architectures for the same domains. The live one queries
`SupabaseConfig`-named tables, views and RPCs directly. A parallel textbook stack was
built, unit-tested, and then routed around — roughly a quarter of `lib/`. All 66 passing
tests target the stack that is *not* running. Choosing wrongly either destroys real design
work plus the only tests that exist, or entrenches a duplicate that makes every future
change happen twice.
**Consequence:** Until this is answered, no agent may "helpfully" wire the dead stack up
or delete it. New work follows the **live** pattern: provider → repository → view/RPC.
**Status:** ACTIVE — blocking

### 017 — The governance docs are closed to the agents they govern
**Date:** 2026-08-26
**Decision:** `.claude/agents/**`, `docs/CONTRACT.md`, `MANIFESTO.md`, `DECISIONS.md`,
`AGENTS.md`, `WORKFLOWS.md` and `CONVENTIONS.md` are writable by master-analyst only.
`.claude/settings*.json` and `.mcp.json` are writable by nobody but the PO.
**Why:** An agent that can edit its own definition can widen its own scope; one that can
edit the decision log wins every disagreement by rewriting it. The settings files are
included because an agent able to edit `settings.local.json` can grant itself any
permission the matrix denies — closing the loop only at the docs layer would leave the
real door open.
**Consequence:** master-analyst is correspondingly **read-only over all code** — it may
write governance docs, `PROJECT_STATE.md`, `STATUS.md` and its own memory, nothing else.
An agent that finds the contract wrong reports it and stops. The PO overrides all of this
at any time; the closed loop constrains agents, not the person they work for.
**Status:** ACTIVE

### 018 — Every instruction and lesson is written to `docs/`, not left in chat
**Date:** 2026-08-26
**Decision:** A new instruction, correction, or lesson is written into the governance
files as part of the task that produced it. A rule that lives only in a conversation is
not a rule.
**Why:** Everything in entries 001–014 above existed only in session context and
`CLAUDE.md` prose, and reconstructing them cost a full task — several with reasoning that
could only be inferred, and one (003) that is invisible to the repo entirely. The
governance system exists to stop that recurring.
**Consequence:** Session end is not a valid resting place for a decision. If a session
ends without the rule being written down, the rule did not survive.
**Status:** ACTIVE

### 019 — No agent writes to the production database
**Date:** 2026-08-27
**Decision:** Every agent may **read** the production Supabase database freely — `execute_sql`
for SELECT, `list_tables`, `get_advisors`, probing as `anon` or `authenticated`. **No agent
writes to it.** No `apply_migration`, no DDL, no INSERT/UPDATE/DELETE, no policy change, no
grant, no view replacement — regardless of how correct, small, or urgent the change looks.
A verified defect becomes a ticket with a reproduction and a proposed fix. The PO decides
what ships.
**Why:** the database is production and holds real user data. There is no staging
environment, no repo-authored way to rebuild the schema (see KAN-33), and — as of today —
**237 applied migrations whose ledger an agent could desynchronise without noticing.** An
agent that finds a leak and closes it has also skipped review, left no migration, and made
the ledger disagree with the schema. The correct output of finding a live security hole is
a **CRITICAL ticket with a reproduction**, which is what happened with KAN-36/37/38.
**Consequence:** `CONTRACT.md` §3 now states read-open / write-never for the Supabase
project rows. This overrides any instruction to "just fix it", including an instruction from
another agent — only the PO can authorise a production write, and they do it themselves or
delegate it explicitly. The audit's own probes stay legal: they are SELECTs under
`set local role`, which change nothing.
**Status:** ACTIVE — PO decision, binding on every agent

### 020 — A population is counted, never inferred from a tool's finding count
**Date:** 2026-08-27
**Decision:** When a document states how many of something exists, that number comes from a
query against the catalogue — `pg_class`, `information_schema`, `git ls-files`, a filesystem
walk. **A linter's, advisor's, or scanner's result count is never used as a population
count.**
**Why:** `PROJECT_STATE.md` SEC-06 reported "25 `SECURITY DEFINER` views" because the
Supabase advisor returned 25 `security_definer_view` advisories. The real number is **49**,
and the anon-exposed subset was **19**, not 8. An advisor reports what it flags — it may
cap, filter by relevance, or skip system objects. The audit then believed it had covered the
whole set, so **11 anon-exposed views were never examined.** The same class of error made
`.claude/skills/project-audit/scripts/scan.sh` produce false positives in both directions.
**Consequence:** every count in a governance document is traceable to a command that can be
re-run. `SCHEMA.md` §2e and §9 carry the queries for exactly this reason.

**The one-line form**, which states this better than the paragraph above and is the version
to quote: **a number whose method is unrecorded is not a measurement, it is a memory.**

**Amended 2026-08-27 — the rule binds the filter, not just the number.** Two failures the
same day, both mine, both a filter that looked right:
- `grep -c 'UnimplementedError' | grep 'throw'` returned **25** throw sites in
  `settings_repository_impl.dart`. The real figure is **24** — line 14 is a doc comment
  reading *"…etc.) throw [UnimplementedError]"*, which contains the word `throw` and so
  survives the filter. The correct count needs the two real forms:
  `grep -cE '^\s+throw UnimplementedError|=>\s*throw UnimplementedError'`.
- `git log --reverse -- <file> | head -1` was read as "when did this content appear". It
  answers *when the file was first touched*, which is a different question. See `G-001`.

**So: record the command, and then check the command answers the question you asked.** A
recorded method that measures the wrong thing is reproducible and still wrong.
**Status:** ACTIVE

### 021 — The leadership layer: CPO and CTO hold delegated decision authority
**Date:** 2026-08-27
**Decision:** Dabbler runs a four-layer structure —
`PO → assistant → LEADERSHIP (Analyst · CPO · CTO · CFO later) → EXECUTIVES`.
Leadership agents **think, negotiate, and may reject an executive's work with reasons and
direct the fix.** They are not read-only advisors: they hold authority delegated by the PO,
and **the structure is the permission.** What they may not do is act outside it, or decide
something reserved to the owner.

Ownership moves accordingly: `cpo` takes `BRIEF.md` and `ROADMAP.md`; `cto` takes
`ARCHITECTURE.md`, `CONVENTIONS.md` and `SCHEMA.md` §11; `DECISIONS.md` is split by prefix
(`G-`/`T-`/`P-`). **master-analyst keeps `PROJECT_STATE.md`, `STATUS.md`, the governance
files, and the measured sections of `SCHEMA.md`.**

**Why:** measurement and decision are different authorities and should not sit in one agent
— the reasoning behind the closed-loop rule in §2 of `CONTRACT.md`. The Analyst establishes
**what is true**; the CPO and CTO decide **what should be true next**. Concretely, this
unblocks `BRIEF.md`, which master-analyst had deliberately left empty because product intent
is not derivable from code: the CPO has an actual source in the 26-document business corpus.

**Consequence:** `CONTRACT.md` §3 gains `CP` and `CT` columns and §9 records three guards
this split needs — `SCHEMA.md` split by section rather than handed over whole, a CTO
convention change requiring a numbered `T-nnn` decision, and prefixed numbering so three
appenders do not collide. Neither leadership agent writes production (decision 019) or
feature code.

**Numbering note:** this is the last entry in the unprefixed governance sequence. From here,
governance is `G-nnn`, technical is `T-nnn`, product is `P-nnn`.
**Status:** ACTIVE — PO structural decision

---

### P-001 — The corpus, not the codebase, is the source for `BRIEF.md`
**Date:** 2026-08-27
**Decision:** `docs/BRIEF.md` §§1–7 are filled exclusively from the 26-document business
corpus under the Notion page **Business docs** (`3c9d4c6dd86d80c08d66fd95416b23e4`), with
precedence `00 executive summary` → `02 monetization architecture` →
`03 investment memorandum` → everything else. Where the corpus does not answer, the marker
stays. **No section of `BRIEF.md` is ever inferred from the code.**

**Why:** `master-analyst` left the file empty on purpose. The codebase carries 20,545 lines
of unreachable rewards code, a complete second architecture nothing routes to, 113 feature
flags of which 10 gate anything, and six routes that render "Coming Soon". Inferring intent
from that encodes abandoned strategy as current truth — and because `BRIEF.md` sits above
`ROADMAP.md` in precedence, every future scoping decision would inherit the error.
Rejected: filling the file from `PROJECT_STATE.md`, which is a measurement of what is, not
a statement of what should be.

**Consequence:** The corpus is now a load-bearing dependency of the repo. When a corpus
document changes, `BRIEF.md` §§1–7 may go stale and nothing in the repo will detect it.
Reading Notion is the CPO's job; writing to it is the PO's.
**Status:** ACTIVE

### P-002 — Four of the five open non-goal forks are settled by the corpus
**Date:** 2026-08-27
**Decision:** Payments/booking, gamification, the venue marketplace and competitive leagues
are all **in committed scope**, not non-goals. In-app chat is **out of Phase 1A**; whether
it is ever in scope is NOT ESTABLISHED. Citations are in `docs/BRIEF.md` §5.

The scoping consequences:

- **Booking and payments** are Phase 1B (Month 9), not cut. `13a` Appendix C: *"Booking
  infrastructure is explicitly OUT"* of the 90-day plan. Deleting `lib/features/payments/`
  today deletes deferred product, not dead product — flag it, do not bury it.
- **Gamification** is one of the five named product layers, but committed launch scope is a
  **3-tier** Bronze/Silver/Gold surface plus streaks (`13a` Sprint 11 gate; `14` D52–D54).
  The 15-tier system and the achievement analytics dashboards are Stage 2 at the earliest.
- **Leagues** ship at launch — `14` E17–E20, *"run a full season"*.

**Why:** these four forks blocked KAN-29 and shaped the whole dead-code programme, and were
unanswerable from the code. The corpus answers them plainly and nobody had read it against
the repo.

**Consequence:** KAN-29 is no longer "build or bury". The recommendation to the PO is: keep
the ~985 LOC live check-in surface, cut the 19,560 lines above it, revisit at Stage 2.
KAN-30 (the clean-architecture stack) is untouched — the corpus is silent on internal
architecture, and that remains the CTO's call.
**Status:** ACTIVE — pending PO ratification on the rewards cut

### P-003 — The persona rule is about game type, never about access
**Date:** 2026-08-27
**Decision:** A **Player** creates **casual** games (no fee, no uplift, off-platform
payment). An **Organiser** creates **organised** games (in-app payment, uplift) and leagues.
**Both can join anything.** One account holds up to two simultaneous profiles.

Therefore the values of `enablePlayerGameCreation` and `enableOrganiserGameJoining` are
**correct at `true`**, and the code comments asserting that players cannot create and
organisers cannot join are **wrong**. Fix the comments, not the flags.

**Why:** `11 v2` §B.1 states it as a table — Player *"Can Create: ✅ Casual games only"*,
Organiser *"Can Create: ✅ Organised games + leagues"* — and `14` E2 confirms an organiser
keeps their player profile. The contradiction had been sitting in `feature_flags.dart`
unresolved because no one had a source for it.

**Consequence:** the two comments in `lib/core/config/feature_flags.dart` are stale and
should be corrected in the next pass over that file (KAN-32). The persona hierarchy that
follows — Player is the network, Organiser is the wedge and the primary paying persona,
Venue is the first customer — is recorded in `docs/BRIEF.md` §2.
**Status:** ACTIVE

### P-004 — Promotion is held until five blockers close
**Date:** 2026-08-27
**Decision:** Dabbler stays live and stays **unpromoted**. No acquisition spend, no press,
no venue partner pack, no founding-cohort outreach until these close:

| | Blocker | Ticket |
|---|---|---|
| B1 | Unauthenticated cross-tenant data leak (`13b` P0-9 red) | KAN-36 / 37 / 38 |
| B2 | PDPL data export unreachable (`13b` P0-6 red, `14` D8) | KAN-52 |
| ~~B3~~ | ~~Users cannot switch to Arabic~~ — **RETRACTED 2026-08-27, the claim was false** | KAN-53 closed |
| B4 | "Message" button on every profile lands on "Coming Soon" (`14` H6) | KAN-45 |
| B5 | Analytics sink is 4 empty methods — the app emits nothing | KAN-51 |

Two further items are holds in their own right: the cricket wedge has no cricket feature
(KAN-54, a PO decision) and the venue pack contracts deliverables that do not exist
(KAN-55).

**Why:** this is not the CPO's bar — it is the corpus's own. `13b`: *"The go/no-go gate
(Section C) is binding. If a P0 criterion is red, you hold the launch. No exceptions, no
'we'll fix it live.'"* and *"A held launch costs days. A broken launch costs trust, store
ratings (which are hard to recover), and the founding-user cohort you only get once."*
Four of its ten P0s are red against measured build state.

B5 is ranked as the decisive one **for promotion specifically**: B1 is the more serious
defect, but B5 is what makes the $200–225K acquisition budget in `08` unspendable — money
would buy users and learn nothing.

Rejected: promoting behind a "beta" label. It does not repair a P0, and `13b`'s reasoning
about store ratings and the one-shot founding cohort applies identically.

**Consequence:** `docs/ROADMAP.md` gains a promotion-gate wave carrying these. The PO may
overrule this — he owns the product; I own the reasoning. If he does, record it here and
name which blocker is being accepted as a risk.

**AMENDED 2026-08-27, same day.** `team-lead` verified my code claims and three did not
hold. **B3 is withdrawn in full** — language switching works via the settings picker
(`settings_screen.dart:1064` → `localeProvider`, which `main.dart:268` consumes); the
"Coming Soon" placeholder at `app_router.dart:590` belongs to the orphaned
`/language_selection` route, not to `/settings/language`, and `PROJECT_STATE.md` WIRE-10
misattributes it. KAN-53 is closed as raised-in-error. B5's count was wrong (4 empty sink
methods, not 18) and B6 overstated (no cricket *wedge*, not no cricket *feature*); both
findings survive, restated in `BRIEF.md` §10. B2 was understated — 2,092 LOC, not ~1,500.

**The hold still stands on B1 and B2 alone**, and the reasoning for using `13b`'s gate as
the bar is unaffected. The three errors were code measurements, not corpus readings — see
the lesson in `docs/LEARN.md` and decision `P-006`.
**Status:** ACTIVE — as amended

### P-005 — Corpus contradictions are logged, not silently resolved
**Date:** 2026-08-27
**Decision:** Where two business documents disagree, `docs/BRIEF.md` §11 quotes both and
picks no winner. Fourteen are recorded. Six require a PO ruling and are listed in
`BRIEF.md` §14. **No agent resolves a corpus contradiction by choosing the more convenient
side.**

The two that block work rather than merely confusing it:

- **C1 — Year 1 is either ~$1.5M or ~$82K.** `00`, `02` and `03` — the three precedence
  documents — all say ~$1.5M on 50K MAU. `12c` (June 2026, newest) says $82K base / $28K
  conservative. 13–27× apart. `12c` supersedes only the research brief and says nothing
  about `00`/`02`/`03`, which remain live and rank above it. Until this is ruled on,
  "on track" has no meaning and no hiring, ask, or roadmap can be sized.
- **C4 — Does a player ever pay Dabbler?** `01` Permanent Truth 1, `02` Part I
  (*"Dabbler does not extract value from players"*, *"Charged to the venue, never to the
  player"*) and `04` Non-Negotiable 1 all say no. `12a`/`12b` introduce an **App Fee of AED
  1.3 charged to free players** and an **Organiser Uplift** of which Dabbler keeps 80% out
  of what a player pays. `04` Art. 33.1: *"No officer … holds the authority to waive,
  modify, or negotiate the Non-Negotiables."*

**Why:** a contradiction inside the corpus is a finding, and the finding belongs to the
owner. An agent that picks a side silently converts an unmade decision into an invisible
one — and in C4's case would be resolving a constitutional question by implementation.

**Consequence:** C4 must be settled **before any pricing is built**, because `04` makes it
a contractual representation to institutional partners and `02` Part XI currently records
every pillar as Truth-checked without the App Fee appearing in the matrix. Any pricing
ticket that lands before that ruling should be rejected by the CPO on this entry.
**Status:** ACTIVE

---

## Technical decisions (`T-nnn`) — owner: `cto`

### T-001 — A view never re-implements RLS; `security_invoker = true` is the default
**Date:** 2026-08-27
**Decision:** Every view in `public` is created with `security_invoker = true`. A view that
runs as its owner (`SECURITY DEFINER` semantics) is an **exception** requiring a written
entry in `SCHEMA.md` §2 naming why the caller's RLS must not apply. Views carry **no
`auth.uid()` predicate of their own** — the base table's RLS is the single place
authorization is expressed.

**Why:** Reproduced 2026-08-27 as the `anon` role against `wtncuzcskpigqpmnxwws`:

```sql
SET LOCAL ROLE anon;
SELECT count(*) FROM public.v_notifications_feed;   -- 609
SELECT count(DISTINCT to_user_id) FROM public.v_notifications_feed;  -- 49
SELECT count(*) FROM public.notifications;          -- 0  ← RLS works
```

Confirmed reachable over HTTP with the publishable anon key that ships in the web bundle:
`GET /rest/v1/v_notifications_feed` → `HTTP/2 206`, `content-range: 0-2/609`, returning
`to_user_id, title, body, action_route, context`. **RLS on `notifications` is correct and
was never the problem** — two definer views walked around it.

**Rejected — adding `WHERE to_user_id = auth.uid()` to each view.** It fixes the two known
views and leaves the class intact: it re-implements RLS in 19 places, each of which can
drift independently, and it silently returns 0 rows for legitimate `service_role` callers.
The predicate belongs on the table, once.

**Rejected — revoking `SELECT` from `anon` on all views.** 47 views are anon-readable and
some are legitimately public pre-login surface (`v_game_card`, `v_venues_with_sports`,
`v_profile_public`). A blanket revoke trades a data leak for a broken signed-out experience.

**Consequence:** the remediation is one mechanical migration flipping `security_invoker` on
the 19 offenders, not 19 bespoke predicates. Views whose base tables lack RLS
(`public.games` has RLS enabled with **zero policies**) will return 0 rows after the flip —
that is the correct failure, and it surfaces the missing policies rather than hiding them.
Ordering therefore matters: **base-table policies land before the invoker flip**, or live
screens go blank. See `T-002` for how this stops recurring.
**Status:** ACTIVE

### T-002 — Anon reachability is an allowlist, proven by a catalogue test
**Date:** 2026-08-27
**Decision:** The set of objects readable by `anon` is an explicit allowlist in
`SCHEMA.md` §2. A test queries `pg_class` for every anon-readable view lacking
`security_invoker`, diffs it against the allowlist, and **fails the build on any addition**.
The population comes from the catalogue, never from an advisor's finding count.

**Why:** This leak was open for weeks with a correct RLS policy sitting one level below it,
because nothing in the pipeline could see the gap. It was found by an audit, not by a
guard. An audit is a snapshot; the next definer view added on a Friday re-opens the same
hole. Decision `020` established that counts come from the catalogue — this makes that
enforceable rather than aspirational.

**Rejected — relying on the Supabase security advisor.** It is the tool that produced the
original undercount (25 flagged vs 49 actual definer views, 8 vs 19 anon-exposed), which is
exactly the failure decision `020` was written about. It is a useful prompt and a worthless
gate.

**Rejected — a code-review checklist item.** Every convention in this repo that depends on a
human remembering has decayed measurably: 113 feature flags of which 10 gate anything, 143
files over the 500-line limit. Conventions that are not mechanically enforced do not hold
here. That is an observation about this codebase, not a judgement about anyone.

**Consequence:** one new CI step with database credentials. The allowlist becomes the
reviewable artifact — a PR that widens anon access shows up as a diff to a list, which is
the review conversation we actually want.
**Status:** ACTIVE

### T-003 — The Play upload key is compromised; signing material never lives in the repo
**Date:** 2026-08-27
**Decision:** Treat the Android upload key as **compromised** and rotate it via Play Console
upload-key reset. Signing credentials move to `android/key.properties` (already gitignored
at `android/.gitignore:14`) and are injected from CI secrets. No credential is ever a
literal in a tracked build file.

**Why:** `android/app/build.gradle.kts:36,38` contain a plaintext `storePassword` and
`keyPassword`. Independently verified 2026-08-27:

```
git ls-files --error-unmatch android/app/build.gradle.kts   → TRACKED
git cat-file -p origin/main:android/app/build.gradle.kts    → present on main
git log -S storePassword -- android/app/build.gradle.kts    → ebaf9b8, 2025-11-22
gh repo view dabblersport/webapp --json visibility           → "PUBLIC"
```

**Nine months in a public repository.** Mitigating and material: the `.jks` itself is *not*
committed (`git ls-files | grep -iE '\.jks$'` → empty), so this is half the credential, not
a shippable forgery kit. It is also permanently in public git history and cannot be
un-published.

**Rejected — rewriting history to purge the password.** The repository is public and has
been for nine months; assume the value is captured. History rewriting on a public repo
breaks every clone and buys a false sense of containment. Rotate the key, which actually
invalidates the secret, and leave history alone.

**Rejected — treating this as low severity because the keystore file is absent.** An upload
key with a known password is one leaked file away from an attacker publishing a build as
Dabbler. The cost of rotation is an afternoon; the cost of being wrong is the store listing.

**Consequence:** GitHub secret scanning did **not** flag this — its three open alerts are
all `google_api_key` on Firebase config, which is public by design and should be dismissed.
Secret scanning is not covering the one secret that matters, so `T-002`'s posture applies
here too: add a pre-commit guard for credential literals in build files.

**Amendment, 2026-08-27 — the claim is bounded, and the bound is now verified.**
`master-analyst` pushed back that "signing key exposed" overstates this, and they are right.
The precise claim is **credential exposed, artifact not**, verified harder than the original:

```
git log --all --diff-filter=A --name-only --format='' | sort -u \
  | grep -iE '\.(jks|keystore|p12|pfx|pepk)$'          -> NONE ever added, any ref, any history
git grep -lE "^[A-Za-z0-9+/]{500,}={0,2}$" -- android/ .github/ scripts/  -> no encoded blob
grep -rniE "keystore|signing|jks" .github/workflows/    -> nothing; deploy-web.yml is web-only
```

**Android signing never runs in CI at all** — `storeFile = file("upload-keystore.jks")`
(`:35`) resolves to a file that exists only on the maintainer's local machine. The password
alone signs nothing.

This does **not** reduce the case for rotating, and it changes the grounds. See the amendment
to `T-011`: this is not "a user is being harmed", it is "a permanent, unrecoverable disclosure
with a cheap fix". Stating it as the former to the PO would be overclaiming, and an
overstated blocker is how a real one gets discounted later.
**Status:** ACTIVE — amended 2026-08-27

### T-004 — Logout is a teardown contract, not a call to `signOut()`
**Date:** 2026-08-27
**Decision:** `AuthService.signOut()` becomes an orchestrated teardown that must, in order:
delete the device's `fcm_tokens` row server-side, clear `UserService`, `ProfileCacheService`
and `LocationService` local state, then call `supabase.auth.signOut()`. Any new on-device
cache registers itself with this teardown; a cache that does not participate is a defect.

**Why:** `lib/core/services/auth_service.dart:261-267` is the entire implementation — one
`signOut()` call and a try/catch. Verified: `UserService.clearUserData()` has exactly one
caller and it is `clearAllDataForTesting()`; `LocationService.clearLocation()` has **zero**
call sites; `grep -rnE "\.delete\(\)" lib | grep -iE "fcm|token"` returns **nothing**.

After logout the device retains the previous account's email, phone, name, age and gender,
**up to 25 other users' cached profiles including their email addresses**
(`profile_cache_service.dart:22,227`), and the last GPS fix. The FCM token is never revoked,
so **a signed-out device keeps receiving the previous account's push notifications with
content in the body.** On a shared, sold or handed-down device that is a privacy breach with
no user-visible cause and no way for the user to stop it.

**Rejected — clearing all of `SharedPreferences` on logout.** `CacheService.clear()` already
does this (`cache_service.dart:73`) and it is a bug, not a pattern: it destroys onboarding
state, locale and theme choice alongside the session. Teardown must be explicit about what
it owns.

**Consequence:** this is the highest user-facing harm in the assessment that is also cheap
to fix, and it is **independent of the database work** — it can ship in the same PR as
nothing else and still be worth shipping.
**Status:** ACTIVE

### T-005 — Session tokens stay in SharedPreferences; the control is backup exclusion
**Date:** 2026-08-27
**Decision:** Keep supabase_flutter's default `SharedPreferencesLocalStorage`. Do **not**
adopt `flutter_secure_storage`. Instead add `android:dataExtractionRules` and
`android:fullBackupContent` to `AndroidManifest.xml` excluding the Supabase session
preferences file.

**Why:** `lib/main.dart:167-177` passes no `localStorage`, so the refresh token lands in
plaintext prefs. On its own that is the standard Supabase Flutter posture and not a finding.
What makes it real is the compounding: the manifest declares **no** `allowBackup`,
`dataExtractionRules` or `fullBackupContent`, and at `targetSdk = 35`
(`android/app/build.gradle.kts:29`) **Android Auto Backup is on by default** — so a
long-lived refresh token syncs to the user's Google Drive and rides along in device-to-device
transfer. That is durable account access leaving the device.

**Rejected — migrating to `flutter_secure_storage`.** It is the instinctive answer and the
wrong trade here. It introduces a Keystore/Keychain dependency with known migration and
device-restore failure modes, it would silently sign out the entire installed base on
upgrade, and it does not close the backup vector any more completely than four lines of
manifest XML do. Reach for it if the app later handles payment credentials.

**Consequence:** the fix is manifest-only, ships with no migration and no forced logout.
Revisit if the threat model changes.
**Status:** ACTIVE

### T-006 — No certificate pinning
**Date:** 2026-08-27
**Decision:** Dabbler does not pin certificates. MASVS-NETWORK-2 is recorded as **not
applicable at this risk profile**, not as an open gap.

**Why:** Traffic terminates on Supabase-managed certificates that rotate frequently. Pinning
buys an outage on every rotation in exchange for near-zero gain: RLS is the actual
authorization control, and there is no high-value transaction flow to protect. Transport is
otherwise clean and verified — zero non-localhost `http://` URLs in `lib/`, `web/` or
`supabase/`; no `usesCleartextTraffic`; iOS ATS sets `NSAllowsArbitraryLoads = false` with a
`supabase.co` exception that itself forbids insecure loads (`ios/Runner/Info.plist:65-79`);
no custom `TrustManager` or `badCertificateCallback`.

**Rejected — pinning "because MASVS lists it".** A control adopted without a threat that
motivates it is a liability with a compliance label on it. This entry exists so the question
is not reopened every audit.
**Consequence:** recorded as a deliberate, revisitable position.
**Status:** ACTIVE

### T-007 — Dead-but-wired code is deleted, not implemented
**Date:** 2026-08-27
**Decision:** Where an audit finds a stub wired into a live provider, the default is
**delete the stub and its dead call chain**. Implementing it requires a product reason from
the `cpo`, not merely the observation that it is unimplemented.

**Why:** KAN-28 as written is wrong in both directions and the correction changes what to do.
`SettingsRepositoryImpl` has **28** methods of which **24** throw `UnimplementedError`, not
26 of 26. It *is* live — `profile_providers.dart:188` → `PrivacyController` →
`privacy_settings_screen.dart:61`, routed at `app_router.dart:1257` with no feature flag —
but `PrivacyController` only ever calls the **four methods that genuinely work**. The 24
throwing methods have exactly one caller, `ChangeSettingsUseCase`, which is **never
constructed** (`SettingsController()` at `profile_providers.dart:178` takes no arguments, so
its usecase field is permanently null). **No user hits an `UnimplementedError` today.**

The same shape appears in KAN-27: the wrong bucket constant `venueImagesBucket =
'venue-images'` (real bucket is `venue`) has **zero call sites**, and the genuinely
convention-breaking inlined literal `_avatarBucket = 'avatars'`
(`supabase_profile_datasource.dart:16`) sits on a dead path behind the never-constructed
`UploadAvatarUseCase`. The live avatar upload uses the correct constant and works.

**Rejected — implementing the 24 methods.** That is days of work to satisfy an interface
nothing calls, and it would make dead code load-bearing.
**Rejected — leaving it as documented tech debt.** Dead code wired to live providers is what
made both these tickets misread as user-facing crashes; it costs review attention on every
future audit.

**Consequence:** **KAN-28 and KAN-27 must be re-scoped before anyone works them** — both are
currently written against facts that do not hold. Neither blocks promotion. One genuine defect
*is* hiding here and needs its own ticket: `profile_avatar_screen.dart:624` fakes a successful
upload with a `Future.delayed` and shows "Avatar uploaded successfully!" without touching
storage.

**Amendment, 2026-08-27, after `master-analyst` challenged the reasoning.** The verdict stands;
one word of it was wrong and it changes the fix.

*Corrected:* "dead code" is the wrong label for KAN-28. `SettingsRepositoryImpl` is
**constructed and injected** (`profile_providers.dart:188` -> `:201`), and
`privacyControllerProvider` is watched by 16 files. It is a **live, wired repository with 4
working methods and 24 landmines** — not dead weight. The distinction matters: anyone adding a
theme, notification or accessibility setting calls a method that **compiles, autocompletes, and
throws at runtime** on an already-live chain. Severity stays where the Analyst put it; the
description "live user-facing failure" was an overstatement, and so was "dead code" in the other
direction. It is a landmine on a wired path.

*Held under challenge, both verified:* there are **24** throws, not 25 — `grep -c
UnimplementedError` returns 25 because line 14 is a **doc comment** (`/// (notifications,
themes, accessibility, etc.) throw [UnimplementedError]`). And `ChangeSettingsUseCase` **is**
never constructed: `grep -rn "ChangeSettingsUseCase(" lib` returns only
`change_settings_usecase.dart:69`, its own constructor *declaration*.
`SettingsController()` (`profile_providers.dart:178`) passes no argument to
`SettingsController({ChangeSettingsUseCase? changeSettingsUseCase})`
(`settings_controller.dart:65`), so `_changeSettingsUseCase` is permanently null. That claim was
about `ChangeSettingsUseCase`, not about the repository.

*New consequence for the fix:* deleting the 24 methods from the impl alone would break
`implements SettingsRepository`. **The interface must shrink with it** — or the 24 landmines
simply move up a layer. That is the actual work item, and neither the original ticket nor my
first reading of it said so.
**Status:** ACTIVE — amended 2026-08-27

### T-008 — `Result` is the only convention; `Either` is converted on touch, never migrated
**Date:** 2026-08-27
**Decision:** No scheduled `Either` → `Result` migration. A file that is edited for any
other reason is converted as part of that change. The home-grown `lib/core/utils/either.dart`
is deleted once its 13 dependents are converted; no new file may import it.

**Why:** Decision `001` records two conventions. There are **three**: `Result` (124 files),
**fpdart** `Either` (17 files — all of `games`, plus `rewards`, `social`, two repositories),
and a **hand-written `Either` in `lib/core/utils/either.dart`** (13 files — all of `profile`,
plus one onboarding controller) that is not fpdart and not type-compatible with it. The
CLAUDE.md statement that legacy code uses fpdart is half right, which is worse than wrong
because it stops people looking.

Two files mix conventions *within a single class*:
`games/data/repositories/games_repository_impl.dart` imports both and returns `Either` from
~20 methods but `Result` from `rateGame` and `myAverageRating`;
`games/presentation/controllers/venues_controller.dart` typedefs `Result` at :10 and uses
fpdart `Either` at :275-276.

**Rejected — a big-bang migration.** 31 files across the two most feature-dense slices, with
5 test files in the entire repo (66 tests, all passing) as the safety net. A refactor of that
size with no regression suite is how a working app becomes a broken one, and it buys the user
nothing.
**Rejected — accepting three conventions permanently.** The mixed files prove it produces
real confusion at the boundary.

**Consequence:** the two mixed files are worth fixing now because they are actively
misleading; the rest waits for natural traffic. Not a promotion blocker.
**Status:** ACTIVE

### T-009 — Edge functions verify authorization scope, not just authentication
**Date:** 2026-08-27
**Decision:** Every edge function that acts on a `user_id` from its request body must prove
the **caller's relationship to that user**. Authenticating the caller is necessary and not
sufficient. Functions with no auth check at all are placed behind auth or documented as
deliberately public with a rate limit.

**Why:** `supabase/functions/send-push-notification/index.ts` correctly verifies the JWT
(`:80-90`) and honours blocks (`:94-109`), but `user_id`, `title` and `body` all come from
caller-supplied JSON (`:38-39`) with **no check that the caller knows the target and no rate
limit**. Any authenticated user can deliver arbitrary title and body text to any other user
as a trusted Dabbler push — a phishing primitive ("Your account is locked — tap to verify")
and a harassment vector against enumerated user IDs. The authentication is fine; the
authorization scope is missing. `supabase/functions/detect-country/index.ts` has no
`Authorization` check across its 188 lines, `Access-Control-Allow-Origin: *` (`:97`), and
logs client IPs (`:32-34`).

Two functions are built correctly and are the pattern to copy: `broadcast-notification`
gates on `requireAdmin()` before ever constructing a service-role client (`:18-49`, `:93`),
and `send-push-notification`'s own trusted-server path compares `x-trigger-secret` against a
service-role-only RPC using `constantTimeEqual` (`:68-75`).

**Rejected — fixing this in the client.** The client is not a trust boundary; it is the
thing being defended against.
**Consequence:** `send-push-notification` needs a relationship predicate and a per-caller
rate limit before promotion, because it is abusable *today* by any registered account.
**Status:** ACTIVE

### T-010 — Line count and colour literals are budgets, not defects; they do not gate launch
**Date:** 2026-08-27
**Decision:** The 500-line limit (`013`) and the no-hardcoded-colours rule (`009`) are
**held for new and edited code and not retrofitted**. Neither blocks promotion. No cleanup
sprint is scheduled.

**Why:** These are the largest numbers in the assessment and the least consequential. 143
non-generated files exceed 500 lines (`find lib -name '*.dart' ! -name '*.g.dart' !
-name '*.freezed.dart' -exec wc -l {} + | awk '$1>500 && $2!="total"' | wc -l`; the Analyst's
140 is the same measurement additionally excluding `lib/l10n/` — **not a disagreement**, a
definitional difference, and l10n exclusion is the better choice since those files are
generated).

The colour figure in decision `009` is worth correcting: **233 is not reproducible.** The
defensible number is **317 occurrences across 43 files**, excluding all five token-definition
trees:

```
grep -rEo "Color\(0x[0-9a-fA-F]{8}\)" lib --include='*.dart' \
  | grep -vE "^lib/(themes/|core/theme/|core/design_system/|design_system/|core/config/design_system/)" | wc -l
```

The commonly quoted 866 double-counts `lib/design_system/tokens/*.dart` and
`lib/core/config/design_system/` — which are palette definitions, i.e. the design system
being counted as a violation of itself (see decision `008`, the triple-copy). The offenders
are **heavily concentrated**: the top 10 files hold 207 of 317, and `composer_drawer_kit.dart`
(41) plus the auth/onboarding cluster (67 across two files) are a third of the total.

**Rejected — a cleanup sprint before promotion.** Not one of these 317 literals or 143 long
files can harm a user or lose data. Spending the pre-launch window here instead of on the
anon leak and the signing key would be a serious misallocation.

**Consequence:** if these are ever attacked, attack the top 5 files — that clears ~45% of the
colour debt for a day's work. Decision `010` (transition wrappers) is confirmed **held**:
zero raw `MaterialPage` in `lib/`. A *different* violation exists that the convention does
not currently name — **13 `MaterialPageRoute` call sites across 8 files** bypassing GoRouter
via imperative `Navigator.push`, 5 of them in `sports_screen.dart`. `CONVENTIONS.md` should
name it; it is not a launch blocker.
**Status:** ACTIVE

### T-011 — Dabbler is not promotable today; three fixes change that
**Date:** 2026-08-27
**Decision:** **Do not promote.** The gate is exactly three items, all of which can harm a
real user and none of which is speculative:

1. **The anon data leak** (`T-001`) — 609 private notifications across 49 users, plus the
   moderation queue (`v_mod_queue_open`, 9 rows) and `v_safety_overview`, readable by anyone
   with the publishable key that ships in the web bundle.
2. **The Play upload key** (`T-003`) — nine months public; rotate.
3. **Logout and push revocation** (`T-004`) — a signed-out device keeps receiving another
   account's notifications.

`T-009`'s `send-push-notification` scope fix is a strong fourth: it is abusable today by any
registered account, and it is a day's work.

**Why this list and not a longer one.** The distinction that governs it is *would harm a
user* versus *would embarrass us*. The rewards slice being 20,545 lines of unreachable code,
113 feature flags of which 10 gate anything, 143 oversized files, 317 colour literals, three
error-handling conventions, `v_space_slots_today` erroring on a table that does not exist —
all real, all worth fixing, **none of them can hurt somebody who installs the app.** They are
the reasons the PO is right to feel the product is immature. They are not the reasons to
withhold promotion.

Two facts argue *for* promotability once the three land: the app **compiles clean** (`flutter
analyze` → **0 errors**, 55 warnings, 102 infos) and **all 66 tests pass** — figures measured
independently and matching `PROJECT_STATE.md` exactly. And the architecture's load-bearing
security decision is sound: authorization is deferred to RLS with **no client-side
authorization decisions anywhere**, admin routes are server-authoritative and fail *closed*,
and deep links do not bypass the auth gate. The database leak is a failure of a *view layer*
built on top of a correct model, not a failure of the model.

**Rejected — promoting now and fixing forward.** The notification leak is live, unauthenticated
and trivially enumerable. Promotion multiplies the number of people whose private data is
exposed while it stays open.
**Rejected — a full hardening programme before promotion.** That defers launch by months for
items that cannot hurt anyone. The PO's instinct that the product is immature is correct and
is a *product* judgement (`cpo`'s half of KAN-39), separate from this technical gate.

**Consequence:** the three blockers are days of work, not weeks, and they are independent —
`T-003` and `T-004` need no database access at all. **No agent applies any of this to
production directly** (decision `019`): each ships as a reviewed migration or PR through
`Canary` → verify → PR.
**Amendment, 2026-08-27 — the gate is re-sorted, after `master-analyst` caught my own
criterion being applied loosely.** The verdict (**do not promote**) is unchanged. What changes
is which items sit on which grounds, because I was not holding my own line.

The line is *would harm a user* vs *would embarrass us*. Applied honestly:

**Promotion blockers — harm is occurring or executable today:**
- **KAN-56**, the anon leak. Private data is exposed right now, to anyone.
- **KAN-58**, logout and push revocation. Harm is occurring right now, on real devices.
- **KAN-59**, push authorization scope — **promoted from "strong fourth" to blocker.** Any
  registered account can deliver arbitrary title and body as a trusted first-party push.
  Signup is passwordless, so obtaining an account is trivial. Promotion multiplies **both**
  the target pool and the attacker pool, which is precisely the wrong thing to scale.

**Pre-promotion requirement, on different grounds — KAN-57**, the Play upload key. **No user
is harmed by this today.** The password alone signs nothing; the keystore has never been in
the repository in any form and Android signing never runs in CI. It belongs before promotion
because the disclosure is **permanent and unrecoverable** and the fix costs an afternoon — not
because anyone is currently at risk.

**The test that exposed my error:** if rotation took three weeks instead of an afternoon,
would I hold launch for it? No — I would rotate on a deadline and promote. That makes
*cheapness*, not *danger*, the thing driving its blocker status, which is a legitimate reason
to do it first and a weak reason to call it a blocker. KAN-56 and KAN-58 would hold launch at
any cost; that is what a blocker means.

**Consequence for how this is argued to the PO:** "a credential is exposed, the signing
artifact is not" is materially different from "the signing key is exposed", and only the first
is true. An overstated blocker is how a real one gets discounted the next time.
**Status:** ACTIVE — this is the CTO's launch-readiness position for KAN-39, amended
2026-08-27

### P-006 — The CPO takes code facts from the Analyst's record, never by measuring
**Date:** 2026-08-27
**Decision:** The CPO judges the business against the **corpus**, which it reads directly.
It does **not** establish facts about the codebase by running its own greps. Code facts come
from `docs/PROJECT_STATE.md`, or from `cto` / `master-analyst` via `grill-peer` **with the
command that produced them attached**. Where a claim about the build is load-bearing for a
verdict — especially one that becomes a blocker or a ticket — it is attributed to whoever
measured it, and the CPO does not upgrade a record's finding into a blocker without asking
the owner to confirm it still holds.

**Why:** on 2026-08-27 the KAN-39 gap analysis shipped with three wrong code claims — B3
(Arabic switching, **false**, ranked a promotion blocker and sent to `cto` as a build
ticket), B5 (18 empty methods, actually 4) and B6 ("no cricket feature", actually no cricket
*wedge*). Every corpus finding in the same document — where documents were quoted — held up
under the same review. The errors clustered exactly where the seat left its evidence domain.

Two compounding causes worth naming, because the rule only works if both are handled:
1. `PROJECT_STATE.md` WIRE-10 misattributed a placeholder route, and I propagated it without
   opening the screen. **Reading the record is necessary but not sufficient** — a record
   claim that is about to become a blocker gets confirmed with its owner.
2. Nothing in my prose signalled lower confidence in the measured half. **The failure is
   invisible from the inside**, because reasoning quality does not drop when the evidence
   does.

**Consequence:** when a verdict turns on whether something is built, `grill-peer` the `cto`
and require the command — this was already in the CPO's own definition and was not followed.
A CPO ticket that asserts a code fact cites its source. `master-analyst` owns correcting
WIRE-10. The generalising lesson is in `docs/LEARN.md`.
**Status:** ACTIVE

### G-001 — "I cannot verify this" is itself a claim, and needs the same standard
**Date:** 2026-08-27
**Decision:** An assertion that something is *unverifiable* carries the same burden of proof
as an assertion of fact. Before writing "not reproducible from here", establish that no
available query answers it.
**Why:** on 2026-08-27 I declined to repeat the CTO's "nine months of exposure" figure for
the keystore password, on the grounds that local history had been re-initialised
(`555b378`, 2025-10-17) and therefore could not settle it. **Refusing to repeat an
unverified number was right. The reason I gave was wrong.** `ebaf9b8` is dated
**2025-11-22**, which is *after* the re-init — local history covered it the whole time. The
error was the query: `git log --reverse -- <file> | head -1` returns when the file was first
touched, not when the password appeared, and I read the former as an answer to the latter.
**Consequence:** the caution was still correct — bounding a claim to what you measured never
costs anything. But "unverifiable" was published as a property of the evidence when it was a
property of my query. State the limit **and** the command that hit it, so a reader can tell
which of the two is really blocked.

**Corollary, from the CTO, 2026-08-27 — the same asymmetry applies to severity.** An
overstated blocker closes the question in the other direction: it gets discounted once, and
then **the real one gets discounted with it.** Both failures work the same way — by removing
something from scrutiny. So a severity is a claim like any other and carries the same
burden: *what is the harm, to whom, today?*

**The test that catches an inflated severity**, also the CTO's, and it caught their own most
alarming finding: **if the fix took three weeks instead of an afternoon, would you still hold
launch for it?** If not, then cheapness — not danger — was doing the work in the
classification. That is a fine reason to sequence something first and a weak reason to call
it a blocker.
**Status:** ACTIVE

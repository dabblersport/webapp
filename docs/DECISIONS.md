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

> **Numbering rule for `T-` entries (added 2026-08-28, after three collisions in one session).**
> Two CTO seats appending concurrently both picked the next free number and collided three times.
> **Before appending, re-run `grep -o '^### T-[0-9]*' docs/DECISIONS.md | sort -u | tail -1`** — the
> file may have moved since you last read it. On a collision, the **earlier-positioned entry keeps
> the number**; renumber the later one and leave a one-line note saying what it was. Never renumber
> an entry already cited in a ticket or in agent memory. Next free number: **T-025**.

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

**Correction, 2026-08-28 — the "19 offenders" figure was mine and it was low.** Re-measured
against `wtncuzcskpigqpmnxwws`:

```sql
-- definer views = reloptions lacking security_invoker=true
SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='v'
  AND NOT COALESCE((SELECT option_value='true' FROM pg_options_to_table(c.reloptions)
       WHERE option_name='security_invoker'), false);            -- 49  (of 71 views)
-- …the same set, filtered to anon SELECT privilege                 -- 27
```

**49 definer views, 27 of which grant `anon` SELECT.**

**Re-corrected 2026-08-28, after `master-analyst` checked this and I was wrong twice over.**
Two claims above need retracting:

1. **The 49 was never a correction to anyone's record.** `PROJECT_STATE.md` and `SCHEMA.md` §2
   have carried 71/49 since 2026-08-27. The Analyst's "19" was an **exposure** count, not a
   definer count. I reconciled my number against theirs without checking they measured the same
   thing.
2. **"Not 19 on either definition" was false, and the error is the substantive one.** 27 is a
   **privilege** count — definer AND `anon` holds SELECT. It is not an exposure count: six of the
   27 return **zero rows** to `anon`. 27 = the Analyst's 19 + 8 they had bucketed separately.
   **Quoted as a leak figure, 27 overstates the problem.**

**A privilege is not an exposure.** Counting the grant is not observing the behaviour, and B1's
remediation must be scoped against rows returned, not against `has_table_privilege`.

**The exposure figure is 21** — 19 leaks plus 2 (`v_game_card` 216 rows, `v_meetup_list` 1)
that the Analyst found were filtering on `listing_visibility = 'public'` rather than the
`auth.uid()` their record claimed. `SCHEMA.md` §2b carries the per-view counts and the control
query. Use 21, not 27 and not 49, whenever the question is "what leaks".

The remediation shape is unchanged; its size is still materially larger than `T-011` scoped, and
the ordering warning below now governs **30** RLS-enabled zero-policy tables rather than a
handful. See `T-015` — for those 30 the correct instrument is a revoked grant, not a policy.

**Consequence:** the remediation is one mechanical migration flipping `security_invoker` on
the offenders, not bespoke predicates. Views whose base tables lack RLS
(`public.games` has RLS enabled with **zero policies**) will return 0 rows after the flip —
that is the correct failure, and it surfaces the missing policies rather than hiding them.
Ordering therefore matters: **base-table policies land before the invoker flip**, or live
screens go blank. See `T-002` for how this stops recurring.
**AMENDMENT, 2026-08-28 — THIS IS NOT A READ LEAK. IT IS UNAUTHENTICATED WRITE ACCESS.**
`master-analyst` measured that the leaking views also grant `anon` INSERT/UPDATE/DELETE and that
two are auto-updatable, and correctly stopped at "preconditions verified, exploitation not
demonstrated" under decision `019`. I demonstrated it **without writing**, using `EXPLAIN`
(no `ANALYZE` — plans and performs ACL checks, executes nothing).

**The demonstration, with its control:**

```sql
SET LOCAL ROLE anon;
EXPLAIN DELETE FROM public.v_notifications_feed WHERE id = '…'::uuid;
--   Delete on notifications
--     ->  Index Scan using notifications_pkey on notifications
--           Index Cond: (id = …)                        <-- NO RLS FILTER

SET LOCAL ROLE anon;                        -- CONTROL, same delete, base table
EXPLAIN DELETE FROM public.notifications    WHERE id = '…'::uuid;
--   Delete on notifications
--     ->  Index Scan using notifications_pkey on notifications
--           Index Cond: (id = …)
--           Filter: (current_setting('request.jwt.claim.sub')::uuid = to_user_id)   <-- RLS APPLIED
```

Identical plans. **Through the view the RLS filter is simply absent.** Postgres rewrites the
delete straight onto the base table.

**Why there is no residual protection:** the views are owned by `postgres`, and
`pg_roles.rolbypassrls` for `postgres` is **true**. With `security_invoker=false`, base-table
access is checked as the owner — so the write executes as a role that bypasses RLS entirely.
There is no second line of defence behind these views.

**Blast radius — and it answers whether this is drift or five bad views. It is drift:**
- **70 of 71** views in `public` grant `anon` INSERT/UPDATE/DELETE
- **49** of those are definer
- **8** are additionally auto-updatable, i.e. **live unauthenticated write paths**:
  `v_notifications_feed`, `v_notifications_ranked`, `v_posts_time_preview`, `v_user_reputation`,
  `v_my_drafts`, `v_hidden_list`, `v_needs_organiser`, `geometry_columns`

**Correction to my own record:** I previously listed `geometry_columns` / `geography_columns` as
confirmed false positives. That was correct **for read** and **wrong for write** —
`geometry_columns` is one of the 8, and anon DELETE against PostGIS metadata is not harmless. A
false-positive ruling is scoped to the privilege it was made about.

**Consequence — the fix order changes.** The `REVOKE` is now the **first and most urgent** step,
ahead of any `security_invoker` work: it is a single statement class, it is testable by
re-running the grant query, it needs no decision about what each view should return, and it
closes a destructive path rather than a confidentiality one. `T-012`'s revoke ruling and this
one are the same instrument applied to tables and views.
**Status:** ACTIVE — amended 2026-08-28

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
**Second amendment, 2026-08-28 — the code change in the working tree is NOT the fix.**
`android/app/build.gradle.kts` now reads signing values from a gitignored `key.properties`
and cites this decision in a comment. The change is correct and well made — it fails loudly
when the properties file is absent rather than silently falling back to debug signing.

**It does not close KAN-57, and marking it done would be the failure mode this decision exists
to prevent.** Removing the literal stops *future* exposure. The password is in public git
history permanently and cannot be un-published. **Only rotation invalidates it.** KAN-57 closes
when Play Console has issued a new upload key, not when the diff lands.

The change is also **uncommitted and unverified on Android** — it alters the release signing
path, and only `flutter build web --release` has been run. A web build exercises none of it.
**Do not commit it without an Android release build.**
**Status:** ACTIVE — amended 2026-08-27, 2026-08-28

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

**Amendment, 2026-08-28 — the seam is confirmed correct; the scope of "which caches" was
understated.** The CPO asked me to test the "cheapest fix on the board" claim rather than take
it on trust. Doing so nearly overturned this decision, and the result changes the acceptance
criteria without changing the priority.

**The scare:** `grep -rn "signOut()" lib` shows **four** logout stacks, one of which
(`supabase_auth_datasource.dart:71`) calls `client.auth.signOut()` **directly**, bypassing
`AuthService`. Were it live, a teardown installed at this decision's seam would silently not run
on some exits and the fix would be a four-stack consolidation.

**It is not live:**
```
grep -rn "logoutUseCaseProvider" lib --include='*.dart'   -> declared auth_providers.dart:274, ZERO consumers
```
The `SupabaseAuthDataSource → AuthRepositoryImpl → LogoutUseCase` stack is dead;
`settings_screen.dart:1191` names it in a comment as "unimplemented". Every **live** exit funnels
through `AuthService().signOut()` — `auth_providers.dart:225`, `auth_controller.dart:104`,
`account_management_screen.dart:1076`. **The seam in this decision is the right one and it is
complete.**

**Two amendments to scope:**
1. **The dead `LogoutUseCase` stack is deleted as part of this work** (`T-007`, dead-but-wired).
   It is harmless today and is precisely the thing a newly-hired Flutter agent would wire up
   next, silently defeating the teardown. A landmine left for the hire is not acceptable.
2. **This decision names three caches; `grep -rln "SharedPreferences\|Hive\.\|FlutterSecureStorage" lib`
   returns 19 files.** Not all are session-scoped — `theme_service`, `locale_provider` and
   `notification_preference` are exactly what the blanket-clear rejection above protects. But
   **all 19 must be classified** session-scoped vs preference-scoped. That classification, not
   the teardown code, is the actual work, and "clear three caches" would have shipped a partial
   teardown that looked complete.

Priority is unchanged: still hours, still the highest harm-per-hour item. **Mechanism-verified is
not observation-verified**, and this is the difference between the two.
**Status:** ACTIVE — amended 2026-08-28

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
**Third amendment, 2026-08-28 — the verdict hardens.** KAN-56 is no longer a confidentiality
breach. It is **unauthenticated destructive write access to production data**, demonstrated at
plan level with a control (`T-001` amendment). Any holder of the publishable key that ships in
the web bundle can delete or forge rows in `notifications`, `posts`, reputation and drafts
through 8 auto-updatable definer views, with RLS bypassed because the view owner is `postgres`
and `rolbypassrls` is true.

**This does not merely reinforce "do not promote" — it raises a question above my authority.**
The exposure is live now, on a shipped app, and it is destructive rather than merely readable.
Whether that warrants an out-of-hours production change is a **PO decision under decision `019`**,
which I will not pre-empt. My technical position: the `REVOKE` is a one-line-per-object change
with no behavioural effect on the app (nothing in `lib/` writes through a view — all writes go to
tables or RPCs), so it is the lowest-risk production change available and the one I would
authorise if it were mine to authorise. **It is not.**
**Status:** ACTIVE — this is the CTO's launch-readiness position for KAN-39, amended
2026-08-27, 2026-08-28

### T-012 — The repo hygiene cleanup: what may go, what stays, and why `macos/` stays
**Date:** 2026-08-28
**Owner:** `cto`. Input: `master-analyst`, `docs/PROJECT_STATE.md` §21 (48 files classified).
**Decision:** the cleanup ships as **one commit**, in the exact scope below. Nothing outside
this list is touched. Every verdict here was re-derived against the tree at `1b83967`, not
inherited from §21.

**APPROVED FOR DELETION — tracked (16 files)**

- Root regenerable artifacts (7): `.an_out.txt`, `flutter_analyze.txt`, `.dto_candidates`,
  `.dto_moves_map`, `.dto_conflicts`, `.dupes_candidates`, `.05B_summary.json`. All are
  captured tool output; `git log` preserves them; one command regenerates the two that matter.
- `PRODUCTION_READINESS_REVIEW.md` — superseded and now known-false ("maintainability High").
- `ONBOARDING_AUDIT.md` — its two surviving facts are folded into §21f (HYG-01, HYG-02).
- Dead code in `lib/` (4): `features/misc/presentation/screens/create_game_screen.dart.broken`,
  `design_system/JSONS/` (already ADR'd — 008), `core/services/onboarding_service.dart`,
  `core/services/mock_onboarding_service.dart`. Re-verified: `grep -rIl` over
  `lib test integration_test` returns **no importer** for any of the three Dart names, and
  **no occurrence of `JSONS`** anywhere in `lib`, `scripts`, or `pubspec.yaml`.
- Spent one-off scripts (3): `scripts/analyze_appbutton.sh`, `scripts/migrate_to_material3.sh`,
  `scripts/parse_logs.py`. Zero refs, each ran once, all preserved in history.
- `windows/` and `linux/` (22 tracked files, 136 KB) — see the platform ruling below.

**APPROVED FOR DELETION — untracked:** the four `flutter_0*.log`, `flutter_run.log`,
`test_icon.dart`, 19 × `.DS_Store`, `.github/prompts/.../__pycache__/`, and the empty
`docs/agents/` directory. Add `.DS_Store` to `.gitignore` in the same commit.

**APPROVED MOVES (3):** `APPLE_REVIEW_SIGNIN.md` → `docs/`;
`flutter_localization_checklist.md` → `docs/`; `task_20_flutter_overhaul.md` → `docs/briefs/`.
Move with `git mv`, and do not edit contents in the same commit.

> **⚠️ OVERRIDDEN 2026-08-29 — `macos/` is deleted after all. See `G-004`.** The PO ruled that
> macOS is not a targeted platform, so the cost this section weighs is a cost worth paying.
> **Read this section as the technical analysis, not as the standing instruction.** The analysis
> below is unchanged and was not disputed — bundle ID, entitlements and sign-in URL schemes
> genuinely cannot be regenerated by `flutter create`; the PO accepted that cost knowingly. Nothing
> else in `T-012` is affected: the other refusals and approved moves stand as written.

**REFUSED — `macos/` stays.** The Analyst's reasoning is sound and I reject only its
conclusion. Verified independently: no build targets it (`build_ios.sh:44` → `flutter build
ipa`, `scripts/cloudflare-build.sh` and `.github/workflows/deploy-web.yml:40` → `flutter
build web`); `pubspec.yaml` declares no `flutter.plugin.platforms` block, so no plugin needs
a desktop registrar; and the three `Platform.is*` sites at
`lib/features/profile/presentation/screens/support/bug_report_screen.dart:452-454` are
`dart:io` **runtime** constants inside a `String` getter — they compile on every non-web
target regardless of which platform folders exist. Folder removal cannot break them.
**Why I still keep it:** "one command recovers it" is true of the folder and false of its
contents. `flutter create --platforms=macos .` regenerates a stock Xcode project; it does not
regenerate bundle identifier, entitlements, signing configuration, or the Google/Apple
sign-in URL schemes, all of which would have to be re-derived by hand. The cost of keeping is
5 MB of repo weight that no build reads. The cost of being wrong is a day of Xcode
archaeology. **Rejected alternative:** delete all three folders for symmetry — symmetry is
not a reason. `windows/` and `linux/` go because there is no plausible Dabbler desktop target
on either and nothing bespoke was ever configured in them; `macos/` differs on both counts.

**REFUSED — `scripts/generate_token_json.py` stays, and it is not an ASK.** It is the
**producer** of the ten `*-{light,dark}-theme.json` files in `lib/design_system/tokens/`,
which `pubspec.yaml:223` ships as a Flutter asset and `DynamicColorSchemeLoader` reads at
runtime over HTTP on web. Zero inbound references is the expected signature of a build step a
human runs by hand, not evidence of rot. Deleting it would leave a shipped asset directory
that can only be hand-edited — and this repo already keeps each palette in three synced
places. **General rule this sets: a generator is judged by its output, never by its callers.**

**REFUSED — the design-system Markdown in `lib/` is out of scope.** The 4 files under
`lib/design_system/` and the 3 unreferenced ones under `lib/core/design_system/` are not
touched in this commit. They cost nothing, and `MATERIAL3_MIGRATION_GUIDE.md` — cited from
live code at `lib/core/design_system/colors/app_colors.dart:10,17` — cross-links its
neighbours by relative path. A docs consolidation is its own ticket with its own link check.

**RULED — `upload_certificate.pem` is deleted from the working tree and never committed.**
It is the public half of the Play upload key and re-downloadable from Play Console, so this
is not an exposure. It is signing material, and T-003 already holds that signing material
does not live in the repo. Consistency, not secrecy, is the reason.

**PUSHED BACK TO THE PO — two items, both business calls, not technical ones:**
`1ab7a966-…_DABBLER_CONTENT_ENGINE.pdf` (432 KB, marketing artefact — is Notion the source of
record?) and `App screenshot/` (7 tracked files — are these the current App Store set?).
I will not guess either.

**NOT hygiene, tracked separately:** HYG-02 — `OnboardingData` is declared twice
incompatibly (`domain/models/onboarding_state.dart:40` Freezed vs
`presentation/providers/onboarding_data_provider.dart:5` hand-written). That is a
convention defect and gets its own ticket; it must not ride in a deletion commit.

**Consequence:** ~57 tracked files and ~1.3 MB leave the repo, of which 22 are
`windows/`+`linux/`. Repo weight is not the point; a root that reads as maintained is. No
build, CI job, store submission, or runtime path changes — the three claims that could have
broken one (desktop registrars, `Platform.is*`, the token generator) were each checked
directly and are recorded above so nobody re-derives them.
 **Status:** ACTIVE, except the `macos/` refusal — **overridden by `G-004`** (PO, 2026-08-29). Every other refusal, approved move and ASK in this entry stands.

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

### P-007 — SEC-13 joins the promotion gate; the gate is the month, everything else waits
**Date:** 2026-08-28
**Decision:** Three rulings, on `master-analyst`'s ground-truth briefing.

**(a) SEC-13 / KAN-59 is added to Wave P as a fifth blocker.** `send-push-notification`
authenticates but does not authorize: any account can send arbitrary trusted first-party
push to any user. Accounts are free — passwordless by design (decision 002).

**Why it is a *promotion* blocker specifically:** promotion multiplies the attacker pool and
the target pool in the same motion, and push is the one channel where the sender is
Dabbler. A spoofed push is indistinguishable from us. `01` Permanent Truth 7 makes
notifications a trust instrument — *"Notifications, streaks, and gamification are tools —
not goals"* — and `13b`'s P0-9 (*"no unauthorized data access"*) is the same class of
control. `master-analyst` raised it against my omission and was right; I had scoped Wave P
off `13b`'s ten P0s and this sits outside them.

**(b) Scope ruling for the month — the gate is the month.** IN: B1 (authored), SEC-13, the
cleanup commit, B5, B4, B2, and unblocking execution authority. **OUT, explicitly:** the 12
unexamined definer views (triage to a list, do not fix), the 30 zero-policy tables,
KAN-29 rewards, KAN-30 clean-architecture, and test coverage over reachable code.

**Why:** KAN-29 and KAN-30 are frozen PO questions worth ~25% of `lib/` and they do not
block promotion. Answering them inside a month that also has to close five blockers is how
both get done badly. They wait, deliberately, and that is a product call I am making rather
than leaving implied.

**(c) The B1 ownership picture is corrected.** `master-analyst` proposed B1 as *"the one
blocker that can move today — SQL only, notifications-specialist owns it."* Verified against
`CONTRACT.md` and it is wrong on two counts:

1. **Scope.** B1 spans `v_mod_queue_open`, `v_safety_overview` and `v_circle_feed` —
   moderation, safety and circles. `CONTRACT.md:119` limits NS to *notification-related*
   migrations; every other migration is **UNOWNED**. NS can author two of the five views.
2. **Application.** `CONTRACT.md:125` — *"**NOBODY. No agent writes production**, including
   notifications-specialist … however correct or urgent"* (decision 019). Even the two
   authorable views produce a reviewed `.sql` that nobody may apply.

**So B1 cannot move today.** It can reach *reviewed SQL awaiting the PO*, for two of five
views. That is the honest ceiling.

**Consequence:** there are **two** bottlenecks, not one. **Authoring** — no agent writes
Dart, so B2/B4/B5 have zero throughput (verified: 7 agents, none owns a Dart feature slice;
NS owns only `lib/features/notifications/**` and `lib/services/notifications/**`).
**Shipping** — decision 019 means no agent applies anything to production, so B1 and SEC-13
stop at authored. A Flutter agent fixes the first and not the second. Both are PO decisions
and neither is mine or the CTO's to grant: `CONTRACT.md` is governance, owned by
`master-analyst`, accepted by the PO.
**Status:** ACTIVE

### T-015 — Definer-funnel tables are protected by a revoked grant, not by an absent policy
**Date:** 2026-08-28
**Numbering note, 2026-08-28:** this entry was authored as `T-012`, colliding with the existing
`T-012` (repo hygiene, 2026-08-27). Renumbered to `T-015` — the older entry keeps `T-012`
because it is already cited in memory and in ticket history. No content changed. Two seats
appending to this file concurrently is how the collision happened; the next `T-` number is
**T-017**.
**Decision:** For the 30 `public` tables with RLS enabled and zero policies, the fix is
**`REVOKE SELECT ON <table> FROM anon, authenticated`** — not adding policies. Access stays
through the `SECURITY DEFINER` functions that already serve them. Five tables that no function
or view reaches get a policy or get dropped.

**Why — I was asked whether zero-policies is deliberate definer-RPC-only design. Partly, and
the implementation is wrong either way.** Measured 2026-08-28:

```sql
-- pg_depend does NOT track plpgsql body references. Search prosrc instead.
SELECT z.relname,
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace pn ON pn.oid=p.pronamespace
     WHERE pn.nspname='public' AND p.prosecdef AND p.prosrc ~* ('\m'||z.relname||'\M'))
FROM (…RLS-on, zero-policy tables…) z;
```

`games` → **37** definer functions in source. `squad_members` → 9. `moderation_tickets` → 2
plus a view. The funnel is real and the pattern is coherent. **My first pass used `pg_depend`
and returned 0 for all 30** — a measurement artifact, not a finding, and precisely the error
class of decision `020`.

**But every one of the 30 still grants `SELECT` to both `anon` and `authenticated`.** The only
thing standing between an unauthenticated caller and `moderation_tickets` is the *absence* of a
policy. That is a design which **fails open on a single mistake**: one well-meaning permissive
policy, added by anyone, opens the table instantly. A revoked grant fails closed — a policy
added later still grants nothing without an explicit `GRANT`.

**Rejected — adding `auth.uid()` policies to all 30.** It would break the definer functions'
intended behaviour (they are supposed to see rows the caller cannot), duplicate authorization
logic already inside 37 functions, and does not remove the wide grant that is the actual
exposure.
**Rejected — leaving it, since it currently returns 0 rows.** "Returns 0 rows today" is a
property of what is absent, not of what is enforced. That is the same reasoning that made the
notification leak survive weeks with correct RLS underneath it (`T-001`).

**Consequence — this refines `T-001`'s ordering constraint and makes it safer.** I previously
wrote "base-table policies land before the invoker flip". For definer-funnel tables that is
**wrong**: they must *not* get policies. The correct sequence is (1) revoke the grants, (2)
leave views over these tables as documented definer exemptions in `SCHEMA.md` §2, (3) flip only
the views whose base tables have real policies. `v_mod_queue_open` and `v_safety_overview` are
in this set — they are definer views over definer-funnel tables, so KAN-56 must revoke rather
than flip them.
**Status:** ACTIVE

### T-013 — There are four design-system surfaces, not three; `lib/themes` is canonical for theming
**Date:** 2026-08-28
**Decision:** **`lib/themes/AppTheme` is canonical for theming** and
**`lib/core/design_system/` is canonical for components.** `lib/design_system/` is absorbed into
`core/design_system` **on touch**, never as a migration project. The `dabbler_design_system` git
dependency is **removed now**.

**Why:** the question was put to me as "which of three is canonical". It is four, and the
missing one is the only one that is load-bearing at runtime. Measured 2026-08-28:

| Surface | Files | Import sites |
|---|---|---|
| `lib/core/design_system/` | 22 | 74 |
| `lib/design_system/` (self-described "temporary") | 11 | **77** |
| **`lib/themes/`** | 4 | 39 |
| `lib/core/theme/` | 2 | 2 |
| `dabbler_design_system` (git dep) | — | **0** |

`main.dart` calls `AppTheme.initialize()` (`:156`) and hands `AppTheme.lightTheme` /
`AppTheme.darkTheme` to `MaterialApp` (`:265-266`). **Every colour the user actually sees comes
from `lib/themes/`,** which was not among the three offered. Canonical is a fact about what the
app consumes, not a preference between candidates.

Note the trap in the raw numbers: `lib/design_system/` has the *most* import sites (77) while
describing itself as temporary. Import count measures entrenchment, not intent — it is an
argument about migration cost, not about which should win.

**Rejected — consolidating all four now.** 37 files, ~190 import sites, and 5 test files in the
whole repo as the safety net. That is how a working app becomes a broken one, and it buys the
user nothing (`T-008` reasoning, same shape).
**Rejected — declaring `lib/design_system/` canonical because it has the most imports.** It
names itself temporary and holds 10 palette files that are copies (decision `008`, the
triple-copy). Rewarding entrenchment would make the duplication permanent.

**Consequence:** removing the `dabbler_design_system` git dependency is immediate and free — 0
imports, and a git dependency is a supply-chain surface with no benefit. The other three
converge over time. Anyone adding a component puts it in `core/design_system`; anyone touching a
colour goes through `AppTheme`.
**Status:** ACTIVE

### T-014 — The first hire is a Flutter feature agent, because a promotion blocker is otherwise unownable
**Date:** 2026-08-28
**Decision:** Standing up a **Flutter/Dart feature agent is the first item in the plan**, ahead
of everything except KAN-56. I agree with `master-analyst`'s conclusion and reach it by a
different and, I think, stronger route.

**Why:** their argument was throughput — 7 agents (`ls .claude/agents/`, verified 2026-08-28),
none writes Dart, 23 of 25 slices unowned, so the month's Dart output is structurally zero.
True, and it understates the problem.

**The sharper fact: KAN-58 is a promotion blocker that nobody on the roster can finish.** Its
FCM-token half sits with `notifications-specialist`, but the teardown half — clearing
`UserService`, `ProfileCacheService`, `LocationService` — is Dart in `lib/core/**`, which
`CONTRACT.md` §3 leaves unowned. So the gate is not merely "slow to clear"; **one of its three
items has no owner at all.** Of the three blockers, KAN-56 is SQL and owned, KAN-59 is an edge
function and owned, and KAN-58 is half-orphaned.

That converts the hire from a capacity question into a **gate-clearing dependency**, which is a
different priority argument and does not rest on any judgement about how much Dart work the
month should contain.

**Rejected — assigning the Dart half of KAN-58 to `notifications-specialist`.** It owns the
notification domain, not `lib/core/services/`. Handing it three unrelated caches because it
happens to be adjacent is how single-owner sprawl starts, and `CONTRACT.md` §3 exists to prevent
exactly that.
**Rejected — deferring the hire until after the gate clears.** The gate cannot clear without it.

**Consequence:** the agent's first task is the KAN-58 teardown, not the 69,612 lines of
unreachable code. Deletion at that scale with 5 test files and **zero coverage over anything a
user executes** (KAN-34) is the highest-risk work available, and it should not be a new owner's
first act. Test coverage on live paths comes before mass deletion.
**Status:** ACTIVE

### T-016 — B5 is not "fill in four empty methods"; there is one emission site and two `AnalyticsService` classes
**Date:** 2026-08-28
**Decision:** Implementing the analytics sink does **not** make the product emit anything
useful. Before any vendor is chosen, two structural defects are fixed: the **duplicate
`AnalyticsService` class**, and the **orphaned `lib/core/analytics/` tree**. Only then does
placing call sites in feature code become worth doing. B5's acceptance criterion — "games
confirmed is queryable end to end" — is gated on Dart edits in unowned feature slices, so B5
inherits the `T-014` hire and cannot start before it.

**Why:** the "four empty methods" description is accurate about the sink and misleading about
the work. Verified 2026-08-28:

```
grep -rn "AnalyticsService" lib test --include="*.dart"
grep -rn "core/analytics/" lib test --include="*.dart" | grep -v "^lib/core/analytics/"   -> NOTHING
grep -n "analytics" lib/providers.dart                                                    -> NOTHING
```

1. **There is exactly one real emission site in the entire app**: `lib/main.dart:78`,
   `AnalyticsService.trackEvent('flags_snapshot', …)`. Filling in the sink today yields one
   event, at startup, about feature flags. **Nothing on the "games confirmed" path emits at
   all** — so the north-star metric would still be underivable with the sink fully working.

2. **Two different classes are named `AnalyticsService`.**
   `lib/core/services/analytics/analytics_service.dart` is the façade with the four TODO sinks
   plus a rich typed layer (`trackGameCreated`, `trackGameJoined`, `trackGameSearch`) that
   already builds correct payloads. `lib/core/services/cache_service.dart:78` declares a
   **second, unrelated `AnalyticsService`** — also empty — and it is the one exposed through
   Riverpod as `analyticsServiceProvider` (`:107`). Anything resolving analytics through the
   provider graph reaches the wrong empty class. A vendor wired into the façade would leave
   every provider-based caller still silent, and the failure would be invisible.

3. **`lib/core/analytics/` (helpers 471 LOC, storage 421 LOC, plus widgets) has zero importers
   outside its own directory**, and `providers.dart` does not mention analytics. The typed
   instrumentation the product needs largely *exists* and is unreachable — the same disease as
   the 2,092-line `data_export_service.dart` in B2 (also zero importers, verified). Two of the
   CPO's four blockers are the same defect: **built, never connected.**

**Rejected — picking a vendor first.** The sink is the cheap half. Choosing a vendor before the
call sites exist optimises the part that is not the bottleneck, and would let "analytics is
wired" be reported truthfully while the product still emits one flag snapshot.
**Rejected — deleting the orphaned `lib/core/analytics/` tree as dead code under `T-007`.**
`T-007` deletes dead-but-wired code. This is dead-and-needed: it is the closest thing to a
specification of what Dabbler intends to measure, and B5 needs it connected, not removed.

**Consequence:** B5's honest shape is *resolve the name collision → connect the helper tree →
place call sites on the confirm path → implement the sink*, in that order, and every step but
the last is Dart in unowned slices. The contradiction between `02` ("games confirmed") and `08`
(CSAU) affects the dashboard, not this work, and does not block it — the CPO is right about
that.
**Status:** ACTIVE

### P-008 — The gate is the union of spend-risk and user-harm; B5 is larger, not smaller
**Date:** 2026-08-28
**Decision:** Three rulings on the `cto`'s gate sequencing.

**(a) The promotion gate is the UNION of the two seats' gates, and `cto` was right to refuse
to let it shrink to mine.** My four were scoped to *"may we spend money pointing people at
this"*. The CTO's criterion is *"is harm occurring or executable today"*. Both belong.
**KAN-58 (logout teardown — a signed-out device keeps receiving another account's pushes)
joins as B9**, alongside B8/KAN-59 which I had already accepted from `master-analyst`.

Wave P is now **six**: B1, B2, B4, B5, B8, B9.

**Why:** a gate assembled from one seat's risk model is not a gate, it is that seat's
preference wearing a gate's name. I scoped mine to spend because that is the decision I own;
that is a reason to *state* the scope, not to let the scope define the whole bar. If the PO
promotes with B8 or B9 open, it should be a knowing call recorded as such — which is exactly
what `cto` said and I am adopting it.

**(b) B5 is LARGER than I scoped it. My correction was wrong in the opposite direction.**
On 2026-08-27 I corrected "18 empty methods" to "4", and then concluded *"the instrumentation
is already there — this is wiring a provider, not building instrumentation."* Verified today
against `cto`'s `T-016`, and the conclusion is wrong:

- **One live emission site in the whole app** — `main.dart:78`, a flags snapshot. The only
  other `trackEvent` callers are in `lib/features/rewards/`, which is unreachable.
- **Two classes named `AnalyticsService`** — `analytics_service.dart:6` (the façade) and
  `cache_service.dart:78` (the one exposed via Riverpod).
- `lib/core/analytics/` (~900 lines, where all 31 apparent call sites live) has **zero
  importers outside itself.**

**Nothing on the games-confirmed path emits.** Filling the sink yields one event about
feature flags. B5 is building the emission layer and deciding which of two classes survives.

**(c) B4 closes by hiding the button at the call site, not by flipping `messaging = false`.**
`cto` is right and the reason is a product one: flipping the flag makes the button bounce the
user silently to home, which reads as a broken app. An absent feature and a broken one are
different user experiences. Hide it at `user_profile_screen.dart:1475`.

**Consequence:** the honest month is `cto`'s short list — **hire → B1 → KAN-58 → B4 (hidden)
→ KAN-59**. **B2 and B5 are next month.** I accept that and will not ask for compression; I
invited an uncompressed estimate and got one. The spend gate therefore does not open this
month, because B5 gates it and B5 is not in the month. That is the honest position to put to
the PO rather than a plan that implies otherwise.
**Status:** ACTIVE

### P-009 — B1 is a CIA defect, not a read leak; split it so the certain half can move
**Date:** 2026-08-28
**Decision:** On `master-analyst`'s grant measurement (2026-08-28, `role_table_grants` +
`information_schema.views`, read-only):

**(a) B1's description changes from confidentiality to confidentiality + integrity +
availability.** All five leaking views grant `anon` the **full** privilege set — SELECT,
INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER — and the two notification views are
**auto-updatable** and **SECURITY DEFINER**. Nobody scoping this may treat the fix as "add a
uid predicate": the grants are the other half, and on the current evidence the more
dangerous half.

**Stated at the evidence's actual strength:** preconditions measured, exploitation not
demonstrated. `master-analyst` correctly declined to execute a write to prove it end to end,
because that is a data change and decision 019 forbids it however diagnostic the intent. I
endorse that refusal — **I do not want this proven against production**, and no one should
read the absence of a demonstration as doubt about the finding.

**(b) No new blocker. B1 is split.**
- **B1a — revoke the `anon` DML grants.** Smaller, more certain, and the half that closes
  integrity and availability. **NS can author it for the two notification views.**
- **B1b — the definer-view read sweep.** 49 views, 27 anon-readable, 30 zero-policy tables.
  The week `cto` scoped.

**Why split:** B1a and B1b have different costs, different owners and different ceilings.
Fused, B1a inherits B1b's week and its unowned-migration blockage for the three non-
notification views. Split, the cheapest fix to the worst harm can move on its own. That is a
sequencing gain available for free, and it was invisible while B1 was one item.

**(c) Ranking is unchanged — B1 stays first, and this makes it more first.** But note the
relationship to **B8/KAN-59**: B8 was accepted on the reasoning *"any free account can send
trusted first-party push."* If unauthenticated INSERT into the notification store surfaces
in the in-app feed — or triggers delivery — then **B1a is the same harm at a lower bar: no
account required at all.** Whether a row insert reaches a device is a question for `cto`,
not an assertion from me. If the answer is yes, B1a partially mitigates B8 and the sequence
should reflect it.

**Consequence:** `BRIEF.md` §10 B1 rewritten. `ROADMAP.md` Wave P carries B1a/B1b. The
question to `cto` is whether B1a lands inside this month's capacity, given it is the one
piece of B1 with a named author.
**Status:** ACTIVE

### P-010 — The one-month plan, and KAN-57 goes on the gate unless the keystore was never exposed
**Date:** 2026-08-28
**Decision:**

**(a) The Flutter hire is reframed from capacity to gate-clearing dependency.** `cto` and
`master-analyst` both established that **KAN-58 cannot be finished by anyone on the roster**
— its FCM half is `notifications-specialist`'s, its teardown half is Dart in `lib/core/**`,
which `CONTRACT.md` §3 leaves unowned. That is a strictly better argument than the
throughput one I was carrying, because it survives a PO who wants a smaller month: it is not
a claim about how much Dart the month should contain, it is a claim that one gate item has
no possible owner. Adopted.

**(b) KAN-57 is added to the gate as B10 — conditionally, and the condition is default-deny.**
Android signing passwords have been in public git history since **2025-11-22 — nine months**.
`master-analyst` flags it as the ticket most likely to be closed wrongly, because someone has
already written the code fix and **git history is immutable: only rotation invalidates a
credential.**

Applying the union criterion this gate now runs on — *does promotion make it worse* and *is
harm executable today* — it answers yes twice. A release-signing credential lets someone
produce an artifact Android trusts as Dabbler, and promotion raises both the value of that
forgery and the number of people exposed to it.

**The condition, because I will not assert what I have not established:** if the keystore
*file* was never in the repository, exposed passwords alone may be inert, and B10 drops off
the gate. **That determination is `cto`'s.** Until it is made, B10 stays on, because the safe
default for a credential is to treat it as compromised. **KAN-57 closes on rotation, never on
the diff** — and no agent may rotate it (decision 019), so it is PO work by construction.

**(c) The month is written into `ROADMAP.md` §Wave P — Execution.** Sequence:
**hire → B1a → KAN-58 → B4 → B8 → B1b**, with B2 and B5 explicitly next month.

**Consequence:** the acquisition-spend gate does **not** open this month, because B5 gates it
and B5 is not in the month. Stated plainly to the PO rather than implied. Wave P now carries
seven items (B1a, B1b, B2, B4, B5, B8, B9) plus conditional B10.
**Status:** ACTIVE

### T-017 — `security_invoker` is half the fix; owner-equals-owner defeats RLS, and one view can send push
**Date:** 2026-08-28
**Decision:** A view is not safe merely because it will be flipped to `security_invoker`. Two further
conditions are required and are now part of the standard: **(a) `anon`/`authenticated` hold no DML
grant on any view or table they do not need to write**, and **(b) any table whose RLS must bind its
own owner sets `FORCE ROW LEVEL SECURITY`.** `notifications` gets both, immediately, as **B1a** —
ahead of the `T-001` read sweep.

**Why — the CPO asked whether an `anon` INSERT into `notifications` actually reaches a user. It
does.** Chain established 2026-08-28, entirely from the catalogue:

```sql
-- 1. the view is genuinely insertable, not just nominally auto-updatable
SELECT is_insertable_into FROM information_schema.views
 WHERE table_schema='public' AND table_name='v_notifications_feed';        -- YES
-- every NOT NULL column without a default (to_user_id, kind_key, title) is exposed in the view
-- 2. owner equals owner, and FORCE RLS is off
SELECT relowner::regrole, relrowsecurity, relforcerowsecurity FROM pg_class …;
--   notifications        -> postgres, t, f
--   v_notifications_feed -> postgres
-- 3. the trigger is live
--   trg_push_on_notification_insert, tgenabled='O'
-- 4. the kind_key needed is public
SELECT has_table_privilege('anon','public.notification_kinds','SELECT');   -- true
-- 23 of 29 kinds carry 'push' in default_channels (there is NO push_enabled column):
SELECT count(*) FILTER (WHERE 'push' = ANY(default_channels)), count(*) FROM public.notification_kinds;
```

**The defence that exists is correct and is bypassed.** `notifications` carries
`n_block_insert — FOR INSERT WITH CHECK (false)`. That is deliberate and it does block a *direct*
`anon` insert. But **Postgres does not apply RLS to a table's owner unless `FORCE ROW LEVEL
SECURITY` is set.** The definer view runs as `postgres`, which owns the base table, so an insert
routed through the view never evaluates the policy. **The block is real; the door is elsewhere.**

**The consequence is not a data leak, it is push.** `trg_push_on_notification_insert` posts
`NEW.title` and `NEW.body` **verbatim** to `send-push-notification`, authenticating with
`x-trigger-secret`. `T-009` recorded that secret path as the *correctly built* one — and it is;
that is precisely why this is severe. It is the path that **bypasses the JWT and relationship
checks**, so an attacker-inserted row inherits full first-party trust.

**This lowers the bar on `T-009` from "any registered account" to "no account at all"**, reachable
with the publishable key in the web bundle.

**Two additions from `master-analyst`, who re-derived the chain independently:**

*Worse* — `has_table_privilege('anon','public.notifications','INSERT')` is **also true**: a direct
DML grant on the base table, not only on the view. That path is genuinely blocked, because RLS
*does* apply to `anon` there and `n_block_insert` denies it. But it means the grant hygiene is
broader than one view, and it is exactly the grant that becomes a second hole the moment someone
adds `FORCE ROW LEVEL SECURITY` and assumes they are finished. See `T-018`.

*Better, slightly* — the trigger enforces the **victim's** `notification_settings` before firing:
`push_enabled`, `muted_kinds`, and quiet hours with the high-priority override. **This gates
reliability, not access.** Note `_has_settings`: a user with **no settings row gets no gating at
all**, which is likely most of them. Recorded so nobody later reads the gating as a mitigation and
concludes the finding was overstated.

**Rejected — folding this into `T-009`/KAN-59 and reducing that ticket.** They are different doors.
Revoking DML closes the unauthenticated path; the authenticated abuse in `T-009` — caller-supplied
`user_id`, no relationship predicate, no rate limit — is untouched by it. KAN-59 stands at full
scope; it drops from "the same harm" to "the remaining half".
**Rejected — waiting for the `T-001` invoker sweep to cover it.** That sweep is a week and is
blocked on unowned migrations. This is a `REVOKE` plus a `FORCE ROW LEVEL SECURITY`, it is
notification-domain work with a named owner, and it closes the worst item on the gate on its own.

**Correction to the record:** `v_mod_queue_open` and `v_safety_overview` are `is_insertable_into
= NO` — aggregates are not auto-updatable. They hold the wide grants and remain a
**confidentiality** problem only.

**Superseded 2026-08-28 — I wrote "only one view carries this" and that was wrong.** I generalised
from the three views the CPO happened to name instead of measuring the population. Measured across
all 71: **8 views are definer AND auto-updatable AND anon-writable.** See `T-018`, which also
supersedes the fix shape below.

**Bound, stated as `T-003`'s was: preconditions verified, exploitation not demonstrated.** Every link
was read from the catalogue; **no insert was attempted**, because that is a write to production under
`019`. There is no authorization control left in the path — only the question of whether Postgres
behaves as documented. A demonstration, if ever wanted, belongs on a Supabase branch and never
against `wtncuzcskpigqpmnxwws`.

**Consequence:** the general lesson for `T-001` — `security_invoker` addresses *reads*. It does
nothing about a wide DML grant and nothing about owner-equals-owner. The `T-002` catalogue test must
assert on grants and `relforcerowsecurity`, not only on invoker status, or it will pass while this
exact hole is open.
**Status:** ACTIVE

### P-011 — B1a is first on the gate, ahead of the hire; and it is now a live destructive exposure
**Date:** 2026-08-28
**Supersedes:** the sequencing in `P-010` and the surface description in `P-009`.

**(a) Correction to `P-009`, from `cto`.** I wrote that "the two notification views are
auto-updatable and SECURITY DEFINER." Only **`v_notifications_feed`** is
`is_insertable_into = YES`. `v_mod_queue_open` and `v_safety_overview` are **NO** — they hold
the wide grants, which reads alarming, but aggregates are not auto-updatable.

**READ THIS WITH (b) — corrected 2026-08-28 (`P-014`).** "One view, not three" was a
correction to **the three views I had named in `P-009`**. It is not a statement about the
population. **The population is eight** — see (b). I left both sentences in this entry
without reconciling them, and read alone (a) understates the surface by 8×. `cto` made the
same error in the opposite direction, generalising from my three named views rather than
measuring; neither of us caught it until the population was queried.

**(b) The severity is now higher than either correction, and it is demonstrated.** `cto` and
`master-analyst` independently established, and `master-analyst` verified rather than
accepted:

- **70 of 71 views grant `anon` INSERT/UPDATE/DELETE.** Eight are definer + auto-updatable —
  **live write paths**: `v_notifications_feed`, `v_notifications_ranked`,
  `v_posts_time_preview`, `v_user_reputation`, `v_my_drafts`, `v_hidden_list`,
  `v_needs_organiser`, `geometry_columns`.
- **RLS is not consulted.** All eight are `security_invoker = false`, so access is checked as
  the view owner — `postgres` (`rolbypassrls`) for seven, **`supabase_admin` (`rolsuper`)** for
  the eighth. The base table's correct `n_block_insert` policy is never evaluated, because
  Postgres does not apply RLS to a table's owner without FORCE ROW LEVEL SECURITY.
- **An insert fires a real push.** `trg_push_on_notification_insert` is enabled and posts
  `NEW.title`/`NEW.body` verbatim to `send-push-notification` using the vault
  `x-trigger-secret` — the trusted-server path, which bypasses JWT and relationship checks by
  design. 23 of 29 `notification_kinds` are push-enabled and `anon` can read that table.
- **`EXPLAIN` without `ANALYZE` plans and ACL-checks without executing.** As `anon`, `EXPLAIN
  DELETE` through a view and against the base table produce identical plans **except the base
  table carries an RLS filter and the view carries none.**

**Stated at its strength: preconditions and query plans verified; no write executed.** Both
agents declined to attempt the insert or delete under decision 019, and I endorse that. If
anyone wants it demonstrated it belongs on a Supabase branch, never against
`wtncuzcskpigqpmnxwws`.

**(c) B1a moves to first on the whole gate — ahead of the Flutter hire.** It has an author
(`cto`), needs no Flutter agent, and `grep -rnE "\.from\('v_|\.from\(\"v_" lib` returns **0**
— none of the eight is referenced anywhere in `lib/`. **Revoking `anon` DML on them has zero
client-behavioural effect.** Revised sequence: **B1a → hire → B1b → KAN-58 → B4 → B8.**

**B1a does not close B8.** It closes the unauthenticated path. The authenticated abuse in
`T-009` — caller-supplied `user_id`, no relationship check, no rate limit — survives
untouched through the edge function's other door. **Keep B8 at full scope.**

**(d) Wave P's description of B1 was wrong and would have mis-scoped the fix.** "Unauthenticated
cross-tenant data leak" invites "add a uid predicate to the views," which leaves `anon`
holding DELETE on eight. The accurate sentence: **an unauthenticated party can today delete
other users' notifications, drafts, posts-time data and reputation rows, and the database will
not consult a single policy while doing it.** `security_invoker` was only ever half the fix;
the **REVOKE comes first**.

**(e) What I am escalating, and what I am not deciding.** Whether a live, demonstrated,
unauthenticated destructive exposure justifies an out-of-hours production change is **a PO
call under 019, not mine and not `cto`'s.** I will not argue it either way. What I will do is
make sure the PO receives the accurate sentence rather than a line item reading "data leak" —
and record the business position: this is the one item on the gate where the harm is **live
and destructive now**, not merely worse after promotion. Every other blocker can wait for a
scheduled change. This one is the PO's judgement about his own users' data.
**Status:** ACTIVE

### T-019 — `geometry_columns` is excluded from the revoke: we cannot alter it, and it is not ours
**Renumbered 2026-08-28** from `T-015` (collision with the definer-funnel entry above). Content unchanged.
**Date:** 2026-08-28
**Decision:** The KAN-67 revoke migration **explicitly excludes `public.geometry_columns`** and
names the exclusion in a comment. It is **not** batched with the other 7 write paths. Whether
PostGIS metadata grants should change at all is referred to the platform, not solved by us.

**Why — `master-analyst` flagged that batching it was risky; it is worse than risky, it fails.**
Verified 2026-08-28:

```sql
SELECT current_user,                                          -- postgres
       (SELECT rolsuper FROM pg_roles WHERE rolname=current_user),  -- FALSE
       pg_get_userbyid(c.relowner),                           -- supabase_admin
       pg_has_role(current_user, c.relowner, 'USAGE')         -- FALSE
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname='geometry_columns';
```

Migrations run as `postgres`. `postgres` is **not** a superuser and is **not** a member of
`supabase_admin`, which owns `geometry_columns`. **`REVOKE … ON geometry_columns FROM anon`
therefore fails for insufficient privilege.** A blanket `REVOKE … ON ALL TABLES IN SCHEMA
public` is the trap: depending on version it either errors on the object we do not own or skips
it while reporting success, and both outcomes are worse than an explicit exclusion — one halts
the migration partway through a security fix, the other reports a fix that did not happen.

**Rejected — `REVOKE … ON ALL TABLES IN SCHEMA public FROM anon` as a single statement.** It is
the obvious form and it is the one that breaks. The migration enumerates its targets.
**Rejected — pursuing a way to force it.** It is PostGIS-managed platform metadata, not
application data. Fighting the platform to change a grant we do not own is how a security fix
becomes an outage.

**Consequence:** 7 of the 8 write paths close in this migration; the 8th is documented as
platform-owned and out of our control, with the query above as the evidence. That is an honest
partial fix, which is worth more than a blanket statement that appears total and is not. If the
PostGIS grant is judged to matter, it is a Supabase support question.
**Status:** ACTIVE

### P-012 — B10 demoted from blocker to pre-promotion requirement; the password is burned everywhere
**Date:** 2026-08-28
**Amends:** `P-010` (b).

**(a) My condition resolved, and the answer is not the one the condition implied.** `cto`
re-verified from scratch: **only the passwords were ever committed. The keystore file never
was** — no `.jks`/`.keystore`/`.p12`/`.pfx`/`.pepk` in any ref, any history, by name or by
object.

**(b) B10 is demoted from blocker to pre-promotion requirement, and I was wrong to set it as
a blocker.** `cto` applied **my own criterion** against my ruling and it fails:
`storeFile = file("upload-keystore.jks")` resolves to a file that exists only on the
maintainer's machine, and Android signing never runs in CI. **Nobody can produce a forged
Dabbler artifact with what is public.** It is half a credential.

My safe default — compromised-until-shown-otherwise — was the right instinct at the wrong
setting. **"Compromised" here means *disclosed*, not *exploitable*, and the union criterion
this gate runs on was built precisely on that distinction.** The test that settles it: *if
rotation took three weeks instead of an afternoon, would I hold promotion for it?* No — I
would rotate on a deadline and promote. That makes **cheapness, not danger**, what was
driving its position, which is a good reason to do it early and a weak reason to call it a
blocker.

`cto`'s argument for why this matters beyond bookkeeping is the one I want on record:
**an overstated item is how a real one gets discounted next time.** B10 sitting beside B1a
implied comparable urgency and would have cost credibility on the next genuine escalation.

**B10 → pre-promotion, PO-executed, on a deadline. Off the critical path entirely** — it
blocks nothing and nothing blocks it. **It still closes on rotation, never on the diff**;
the password is on `main` in a public repo today and history rewriting on a public repo
buys containment that does not exist.

**(c) The item that is not in any ticket, and is worth more than the key rotation.**
`storePassword` and `keyPassword` are **the same value**, and it reads as a personal
password rather than a generated one. **If it is reused anywhere — email, Play Console,
Apple, Supabase, anything — rotating the upload key does not close that.**

This is not an engineering task and nobody will speculate about where it is used. It is a
sentence for the PO: **this specific string has been publicly readable since 2025-11-22 —
treat it as burned everywhere it appears.** Escalated directly, because it is exactly the
kind of finding that goes unsaid on the grounds that it is not anybody's ticket.
**Status:** ACTIVE


### T-018 — The wide `anon` grant is inherited Supabase default privilege, so REVOKE alone reopens it
**Date:** 2026-08-28
**Decision:** The B1a fix is **three parts, not one**, and it is **schema-level, not per-view**:
1. `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon, authenticated`
   (then re-grant the narrow set the app actually writes).
2. **`ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE …` for both grantors** — without this every
   future view re-acquires the full grant on creation.
3. `FORCE ROW LEVEL SECURITY` on base tables reached by definer views (`T-017`).

It is **not** a uid predicate, and the definer→invoker conversion is a separate, later concern
(`T-001`'s read sweep). **A REVOKE-only migration would pass KAN-67's Query A on re-run and
silently regress on the next migration that adds a view.**

**Why — this answers KAN-67 AC#5, which was unmeasured, and it changes the fix.** Measured across
the full population of 71 views:

```sql
-- 70 of 71 views grant anon INSERT/UPDATE/DELETE
-- 19 are auto-updatable; all 19 also carry the write grant
-- 8 are definer AND auto-updatable AND anon-writable  <- live unauthenticated write paths
SELECT * FROM pg_default_acl;   -- the cause
```

`pg_default_acl` shows `ALTER DEFAULT PRIVILEGES` in `public`, from **both** `postgres` and
`supabase_admin`, granting `anon` and `authenticated` **`arwdDxtm`** — the full set — on every
relation created. **This is inherited Supabase stock configuration, not something Dabbler
authored.** So the answer to AC#5 is: **project-wide default drift, not specific to five views**,
and the drift is *generative* — it re-applies to anything created later.

**The 8 live write paths:** `v_notifications_feed`, `v_notifications_ranked`, `v_hidden_list`,
`v_my_drafts`, `v_needs_organiser`, `v_posts_time_preview`, `v_user_reputation`, and
`geometry_columns`. **`geometry_columns` is PostGIS-owned and a known false positive** (decision
`021`) — its writability is a PostGIS artifact and touches no app data. **Seven app views, one
false positive.**

**Rejected — splitting the migration by view ownership, as KAN-67 AC#1 proposes.** The fix operates
on schema-level grants and default privileges, so "notifications-specialist authors the two
notification views, the other three are UNOWNED" **does not match the shape of the work**. There is
no per-view REVOKE that fixes this; carving it that way would produce two migrations that each
half-fix a schema-wide setting. **This is one migration against schema-level configuration, and it
is UNOWNED** — which makes it the sharpest argument yet for the backend-owner hire, because the
highest-value item on the gate cannot be sliced into something an existing agent may author.

**Rejected — a blanket `REVOKE ALL`, including SELECT.** `T-001` already rejected this: 47 views are
anon-readable and some are legitimately public pre-login surface. This decision revokes **write**
and leaves the read question to the `T-001` sweep.

**Consequence:** B1a is larger in authorship than "revoke five grants" and **smaller in risk** than
the read sweep, because revoking a write grant cannot blank a screen — nothing in the app writes
through these views. It remains first. `T-002`'s catalogue test must assert on
`pg_default_acl` as well as on grants, or it will pass the day after a new view is created.
**Status:** ACTIVE

### T-020 — A control's data is never readable by the people it constrains; and dead *data* is not dropped like dead *code*
**Renumbered 2026-08-28** from `T-016` (collision with the analytics entry above). Content unchanged.
**Date:** 2026-08-28
**Decision:** Two rulings, both prompted by `master-analyst`'s orphan-table measurement (KAN-68).

**(a) `safety_blocklist_terms` gets a `SECURITY DEFINER` function, not a read policy.**
Make `content_hits_blocklist` definer and **revoke** direct `SELECT` on
`safety_blocklist_terms` from `anon` and `authenticated`. Same for
`context_rating_config` via `_get_context_config`.

**(b) `challenge_types` and `surface_catalog` are revoked now and dropped later, if ever.**
Revoking is free and immediate. **Dropping is deferred and is not covered by `T-007`.**

**Why (a) — the deciding argument is not consistency, it is that a blocklist must not be
readable by the people it blocks.** The obvious alternative is a read policy granting
`authenticated` access to the terms. That would work and it would be wrong: **every user could
then download the list of banned terms and trivially author around it.** A moderation control
whose contents are visible to those it constrains is not a control. So this lands on the definer
side of the `T-012` axis — but for a reason specific to what the table *is*, not by analogy.

Note this is genuinely a different shape from `T-012`'s funnel tables. `master-analyst` measured
that all three referencing functions here are `prosecdef = false` — **invoker functions over an
RLS-on, zero-policy table, which return 0 rows to every real caller.** These five are not
access-controlled by a funnel; they are simply unreachable. `T-012`'s "revoke, do not add
policies" was right for `games` and `squad_members` and would have been the wrong instrument
here. Same axis, different objects, and the measurement is what separated them.

**Why (b) — `T-007` says delete dead code; that does not transfer to data.** Dead Dart is
recoverable from git in one command. **38 rows of dropped config are not recoverable from
anything.** A table with no reader of any kind costs nothing to leave in place, so the
asymmetry between "wrong to drop" and "wrong to keep" is enormous and one-sided. Revoke now,
which removes the exposure; defer the drop, which is the irreversible half and carries no
urgency. `space_slot_holds` is explicitly left alone — `supabase_config.dart:141` and
`lib/data/models/slot.dart:66` both name it, so it is parked scaffolding, and whether it stays
is a product question for the `cpo`, not a technical one.

**The locale bug (KAN-68 defect 1) — fix, do not delete.** The predicate
`where locale='any' or locale=p_locale` treats `'any'` as a property of the *stored term* while
the caller passes it as the *query* locale, so it matches nothing. Correct form:
`where p_locale = 'any' or locale = 'any' or locale = p_locale`.

**Rejected — deleting the method and RPC.** `T-007`'s default is deletion, and this is the
exception. Dabbler carries user-generated content on a social product; a content blocklist is a
control it should have. The right end state is a working check, not the honest absence of one.

**Rejected — fixing the locale bug alone.** It changes nothing while RLS returns zero terms.
Either defect alone returns `0` — a plausible, silent "clean" — for every input.

**Consequence — the verification method is part of the fix.** `master-analyst`'s criterion
stands and I am reinforcing it: **verify as role `authenticated`, never as service role.** A
service-role test passes while production fails, which is precisely how this survived. That
requirement belongs in the ticket, because the defect is invisible at the call site: no error,
no log, just `0`.

**Not a promotion blocker.** `grep -rn "contentHitsBlocklist" lib` returns only the definition —
nothing calls it, so no content is being let through today. But `moderation_service.dart` is
live and imported by five screens, so this is one wiring change from becoming a silent safety
failure. That is the `T-007` "landmine on a wired path" shape, and it is the worst version of
it: **a safety control that fails open is more dangerous than an absent one, because its
existence implies protection.**
**Status:** ACTIVE

### P-013 — B10 comes off the gate entirely; `space_slot_holds` is kept as deferred product
**Date:** 2026-08-28
**Amends:** `P-012`.

**(a) B10 is off the promotion gate. Not "pre-promotion requirement" — off it.** `P-012`
demoted it and kept it gate-adjacent. That was a fudge: it left an item on the list while
conceding it does not meet the list's criterion. `master-analyst` reached the same verdict
as `cto` independently, from evidence rather than from `cto`'s argument, and pushed for the
clean version. They are right.

**The principle, in their words, is sharper than mine:** *the gate is only useful while
every item on it is one that promotion genuinely worsens.* B10 answers **no** twice — the
exposure is nine months old and static, it does not scale with users, and promoting does not
make a `.jks` that lives only on the PO's machine more reachable.

**B10 → HIGH in the normal queue. Still closes on rotation, never on the diff.** Three things
remain true and are not softened: the credential is **pre-compromised against any future
`.jks` leak**; **password reuse is unmeasurable from here** and only the PO can answer it
(escalated separately, and it is the part that matters); and nine months of public history is
immutable.

**(b) `space_slot_holds` is kept.** `master-analyst` correctly routed its fate to me as a
product question rather than a measurement. **It is parked scaffolding for venue slot
booking, and booking is committed scope** — Phase 1B, Month 9 (`P-002`, from `11 v2` F.3 and
`13a` Appendix C). Same ruling as `lib/features/payments/`: **deferred product is not dead
code.** Do not drop it in the orphan-table sweep.

`challenge_types` and `surface_catalog` — no reader of any kind, 38 rows of unreachable
config — are the safest drops and I have no product objection. Note only that `challenges`
sits under the *competitive leagues* fork, which `P-002` ruled **in scope**; these two tables
are config for a surface that was never built, not the feature itself.

**(c) KAN-68 (fail-open safety blocklist) is NOT a gate item, and `master-analyst` was right
not to propose it.** It is a trap rather than a breach: `contentHitsBlocklist` has no caller
in `lib/`, so nothing trusts it today.

**But it is recorded in `BRIEF.md` as a known trap**, because moderation is a corpus
commitment, not merely a feature — `04` Art. 22 gives the Ethics Committee oversight of
player concerns, and `09` §G.1 sells venues a compliance posture. The App Store requirement
(`13c`, `14` D33) is a **report/block mechanism**, which exists and is live in the composer
and report dialog. **Anyone scoping moderation work must not assume the blocklist works.**
**Status:** ACTIVE

### P-014 — B1a is schema-level and unowned; the sequencing gain is withdrawn
**Date:** 2026-08-28
**Amends:** `P-009` (b) and `P-011`. Source: `cto` `T-018`.

**(a) The wide grant is inherited Supabase stock default privilege, not a mistake anyone
made.** `pg_default_acl` shows `ALTER DEFAULT PRIVILEGES` granting `anon` the full set on
every relation created in `public`. Nobody did this to us; nobody ever turned it off.

**Therefore a REVOKE-only fix reopens on its own.** Every future view re-acquires the grant
on creation. It would pass the verification query and **silently regress on the next
migration** — which is worse than not fixing it, because it converts a known hole into a
verified-clean one.

**(b) I withdraw the sequencing gain from `P-009`.** I split B1a from B1b partly because "NS
can author the two notification views" — a per-view carve that let the cheapest fix move
under the current permission matrix. **That does not survive.** There is no per-view REVOKE
that fixes a schema-wide default; carving it that way produces two migrations that each
half-fix the setting, and the `pg_default_acl` half belongs to no owner at all.

**The split itself stands** — the write fix is smaller and more certain than the read sweep,
and that reasoning is untouched. What is gone is the reason I liked it.

**(c) The honest position is worse than yesterday: B1a is both the highest-value item on the
gate and unassignable.** `hire → B1a` is now a **hard dependency**, not a scheduling
preference. Revised sequence: **hire → B1a → KAN-58 → B4 → KAN-59 → B1b.**

**(d) The fact that cuts the other way, and the PO needs it.** **Revoking write cannot blank
a screen.** Nothing in the app writes through these views, so unlike the B1b read sweep —
which *will* blank live screens if base-table policies land in the wrong order — **B1a
carries almost no regression risk.**

**It reads as the scariest item on the board and it is the safest to apply.** "Highest
severity" and "highest risk to apply" point in opposite directions here, and people
routinely assume they do not. That materially strengthens the out-of-hours case already in
front of the PO and it is relayed to him directly.
**Status:** ACTIVE

### T-022 — SEC-17 is NOT folded into KAN-67: one is privilege-only, the other redefines a live view
**Renumbered 2026-08-28** from `T-017` (collision). Content unchanged.
**Date:** 2026-08-28
**Decision:** The `creator_user_id` fix (SEC-17) ships **separately** from the KAN-67 revoke.
`master-analyst` recommended folding them — same migration, same review, and splitting risks the
uid fix shipping later for no reason. **Rejected**, on evidence, and the reason is the opposite
of "no reason": they are different classes of change with opposite risk profiles.

**Why — measured 2026-08-28:**

| | KAN-67 revoke | SEC-17 uid removal |
|---|---|---|
| Change type | `REVOKE` — privilege only | `CREATE OR REPLACE VIEW` — redefines the projection |
| Client references | **0** across all 8 views | **6** read sites |
| Regression risk | none possible | **breaks live screens** |

```
for v in v_notifications_feed v_notifications_ranked v_posts_time_preview \
         v_user_reputation v_my_drafts v_hidden_list v_needs_organiser; do
  grep -rn "$v" lib --include='*.dart' | wc -l;   # 0 for every one
done

grep -rn "creator_user_id" lib --include='*.dart'   # 6 sites
```

`creator_user_id` is **read and filtered on** in live code: `game_view_controller.dart:212`,
`game_model.dart:81` (→ `organizerId`), and as a **query filter** at
`game_history_providers.dart:79-80`, `supabase_games_datasource.dart:507`,
`sport_profile_view_provider.dart:264`. `v_game_card` is one of the most live objects in the
schema — `supabase_config.dart:219` plus explore, social feed, game history and nearby-games.

**Dropping the column naively breaks game history filtering, the sport profile view and organiser
identity on the detail screen.**

**The deciding argument:** KAN-67 is the **only** production change in this plan that is
*verifiably* risk-free — nothing references those 8 views at all. That property is why it can be
reviewed in minutes and shipped first while a destructive hole is open. **Folding a
six-call-site client regression into it destroys exactly that property**, and the review that
should wave it through now has to reason about Dart call sites. "Same file, same review" is the
reason not to, not the reason to.

**Amendment, 2026-08-28 — scoping made precise. My blast-radius figure was overstated;
`master-analyst`'s migration scope was too wide; the one genuinely dangerous site is the one
they identified.** The ruling (do not fold) is unchanged and now rests on a smaller, firmer
number.

Splitting the 6 sites by **what they actually query**:

*Read `v_game_card` — a column drop hits these (3):*
- `game_history_providers.dart:79-80` — an `or` filter string applied to
  `.from(SupabaseConfig.vGameCardTable)`. **A filter on the view.** This is the site that fails
  as *silently wrong results* rather than an error, and it is the whole argument.
- `game_view_controller.dart:212` — fed from `.from(SupabaseConfig.vGameCardTable)` at `:399`.
- `game_model.dart:81` — the shared parser.

*Query the `games` TABLE, not the view — untouched by a view change (2):*
- `sport_profile_view_provider.dart:264` and `supabase_games_datasource.dart:507` both do
  `.from(SupabaseConfig.gamesTable)`. They would only matter if the column were dropped from the
  base table, which nobody has proposed.

So the view-drop blast radius is **3, not 6.** I asserted 6 by counting the identifier rather
than checking what each site queried — a grep count read as a call-site count, which is the same
class of error as the `pg_depend` artifact and decision `020`.

**The identity model is more fragmented than either of us said**, and this is the part that makes
SEC-17 real work: **four** identity columns are in play — `host_user_id` (**23** references),
`creator_user_id` (6), `organizer_id` (4), `creator_profile_id` (**1**). `game_model.dart:81`
already reconciles two of them with an empty-string default:
`organizerId: json['creator_user_id'] ?? json['host_user_id'] ?? ''`. That default is itself a
silent-failure vector. `creator_profile_id` — the identity we would migrate *to* — has **one**
reference in the entire app.

**Consequence — SEC-17 is larger than it looks and is blocked on the `T-014` hire.** The fix is
not "drop the column": the app legitimately needs a creator identifier. It is *migrate the 6 call
sites to `creator_profile_id`, then drop the uid from the projection* — a coordinated Dart + SQL
change, in `lib/features/games/**` and `lib/features/profile/**`, which is unowned. It therefore
sits behind the same Flutter feature agent as KAN-58, and folding it into KAN-67 would have
blocked the revoke on that hire.

**Status:** ACTIVE


### T-021 — B1b moves ahead of B4; SEC-17 rides in B1a's migration
**Date:** 2026-08-28
**Decision:** Final gate order is **hire → B1a → KAN-58 → B1b → B4 → KAN-59**. B1b (the definer-view
read sweep) moves **ahead of B4** (hiding the Message button). Separately, **SEC-17 — dropping
`creator_user_id` from anon-reachable projections — is folded into B1a's migration** rather than
waiting for the B1b sweep.

**Why B1b moves.** Until 2026-08-28 B1b was "49 views with the wrong invoker setting" — a
correctness defect with **no measured user impact**, which is why I was content to rank it last.
`master-analyst`'s sweep gave it one: **61 of 240 `auth.users` UUIDs are readable by `anon` — 25% of
the user base** (v_notifications_feed/_ranked 51 uids/611 rows, v_game_card 25/216, v_circle_feed
1/6, v_meetup_list 1/1). Measured by **probing each view as `anon`**, not by reading column lists —
the distinction every agent here got wrong at least once today. Eight further views carry the column
and return zero rows: **dormant, not clean.**

**B4 is hiding a button. It cannot harm anyone; it embarrasses us.** On the *harm a user* vs
*embarrass us* criterion that governs this whole gate, a cosmetic fix does not precede closing a
quarter of the user base's identifiers. The original ordering was set when B1b had no number
attached and does not survive the number.

**Rejected — moving B1b above `KAN-58`.** A signed-out device still receiving another account's push
notifications is harm occurring on a real device now; B1b is exposure without a demonstrated
consequence. Severity ranking is not the same as harm ranking.

**RETRACTED 2026-08-28, same day — the SEC-17 half of this decision was wrong. See `T-022`.**
I wrote that dropping `creator_user_id` was "a column drop, not a sweep… no added risk". **I never
checked whether the app reads the column.** It does, at **six live sites**, verified independently:

```
grep -rn "creator_user_id" lib --include='*.dart'   -> 6
```

Three are **query filters** — `game_history_providers.dart:79-80`,
`supabase_games_datasource.dart:507`, `sport_profile_view_provider.dart:264` — and two are read
into organiser identity (`game_view_controller.dart:212`, `game_model.dart:81`). Dropping the
column naively breaks game-history filtering, the sport profile view, and organiser identity on
the detail screen.

**And folding it would have destroyed the property that makes B1a shippable.** The revoke is the
only production change in this plan that is *verifiably* risk-free — **0 client references across
all 8 target views**, re-verified. A review that could wave it through in minutes would instead
have had to reason about six Dart call sites.

**The error is the one I conceded twice already today**: `master-analyst` observed that
`creator_profile_id` exists separately, and I inferred from that that the uid was unused rather
than grepping for it. *A column existing beside another is not evidence nothing reads it.*

SEC-17's real shape is **migrate the six call sites to `creator_profile_id`, then drop the uid** —
coordinated Dart + SQL in unowned slices, so it sits behind the `T-014` hire. **The B1b re-rank
above stands on its own evidence and is unaffected.**

**Consequence:** `SEC-15` (precise `start_at` + venue + real name to an unauthenticated caller)
stays **MED and stays a PO decision**. I argued it higher; `master-analyst` held it at MED on grounds
I accept — the rows are opted into, there are no coordinates or contact details, and a discovery app
that cannot show public games to a logged-out browser does not work. My argument is recorded for the
PO to weigh, not re-litigated.
**Status:** ACTIVE

### P-015 — Authoring B1a is also blocked, but it is an unfilled seat, not a prohibition
**Date:** 2026-08-28
**Amends:** `P-014` (c). Source: `cto`'s option-C proposal, checked against `CONTRACT.md`.

**(a) `cto`'s option C does not survive the document.** The proposal: *"an agent authors the
migration, the PO applies it — authoring an unapplied migration file isn't the contended
permission; applying to production is."* Sound in principle. **`CONTRACT.md` §3 does not
work that way** — it carries **two separate restrictions**, and only one is about applying:

| Row | Rule |
|---|---|
| `supabase/schema/migrations/**` | *"NS writes only notification-related migrations. **Every other migration is UNOWNED — nobody writes it**, pending a backend owner."* |
| Supabase project — **writing** | *"**NOBODY. No agent writes production** … however correct or urgent."* |

B1a's migration is schema-wide default privileges. It is not notification-related. **So it is
blocked at authoring as well as at applying**, and option C as stated does not unblock it.

**(b) But the two rows are not the same kind of rule, and the difference is the way through.**

- The production row is a **prohibition**: *"NOBODY … however correct or urgent … This
  overrides any instruction to 'just fix it', including from another agent."*
- The migrations row is an **unfilled seat**: *"UNOWNED — nobody writes it, **pending a
  backend owner**."*

**A seat the document says is empty and expects to be filled is not a permission that needs
contesting.** Filling it is what the row anticipates.

**(c) This reframes the PO question, and makes it smaller.** I had been carrying *"which do
you unblock, and how"* as if it required amending a contested matrix. For B1a it does not.
The ask is: **fill the backend-owner seat `CONTRACT.md` already names as vacant.**

**And that is a different hire from the Flutter agent.** I had them fused. They are not:

| Unblocks | Needed for |
|---|---|
| **Backend owner** (schema/SQL) | **B1a**, B1b, and the 30 zero-policy tables |
| **Flutter agent** (Dart) | B2, B4, B5, and KAN-58's teardown half |
| **PO only** (019, unamendable) | *Applying* any of it to production |

So B1a's dependency is **backend owner → PO applies**, not **Flutter hire → …**. If the PO
fills the backend seat first, **B1a can move in week one** — which is `cto`'s conclusion
reached by a different and, I think, sounder route.

**(d) I am not resolving the ambiguity myself, and neither should `cto`.** Whether "UNOWNED —
pending a backend owner" permits an existing agent to author in the interim is a reading of
**`master-analyst`'s file**, accepted by the PO. Two leadership agents agreeing on a
convenient interpretation of a permission boundary is the exact failure `019` and
`CONTRACT.md` exist to prevent. **Recommended, not decided.**

**(e) Third element, from `master-analyst` via `cto`: FORCE RLS is load-bearing.** The fix is
**REVOKE + `ALTER DEFAULT PRIVILEGES … REVOKE` + FORCE ROW LEVEL SECURITY**. Revoking alone
leaves the same shape one careless `GRANT` from reopening; without FORCE, owner-executed
paths keep bypassing policy. Any B1a migration missing the third part is incomplete.
**Status:** ACTIVE

### P-016 — B1b ahead of B4; SEC-17 stays out of B1a; the sequence has three tracks, not one
**Date:** 2026-08-28
**Amends:** the sequence in `P-010`/`P-014`. Sources: `cto` `T-018` + retraction.

**(a) B1b moves ahead of B4. Accepted.** `master-analyst` measured **61 of 240 `auth.users`
UUIDs readable by `anon` — 25% of the user base** — by probing each view as `anon` rather
than reading a column list. **B4 is hiding a button: it cannot harm anyone, it embarrasses
us.** On the union criterion, a cosmetic fix must not precede closing a quarter of the user
base's identifiers. `cto` ranked B4 higher when B1b had no number attached; the ordering does
not survive the number.

B1b stays *behind* KAN-58 — a signed-out device receiving another account's pushes is active
harm on a real device; B1b is exposure without demonstrated consequence.

**(b) SEC-17 stays out of B1a. `cto` retracted it and the retraction is the important half.**
They proposed folding a `creator_user_id` column drop into B1a's migration as "no added
risk", then verified: **the column is read at six live sites**, three of them query filters
(`game_history_providers.dart:79-80`, `supabase_games_datasource.dart:507`,
`sport_profile_view_provider.dart:264`). Dropping it naively breaks game-history filtering,
the sport profile view, and organiser identity.

**Why this matters more than an ordinary near-miss:** it would have destroyed the single
property that makes B1a shippable tonight — **0 client references across all 8 target views**,
which is what lets me put a low-risk change in front of the PO for an out-of-hours call.
Bolting a six-call-site client regression onto it converts a minutes-long review into one
that has to reason about Dart call sites.

**B1a stays exactly as scoped: REVOKE + `ALTER DEFAULT PRIVILEGES` + FORCE RLS. Nothing
added.** SEC-17 goes behind the hire: migrate the six call sites to `creator_profile_id`,
*then* drop the uid. Coordinated Dart + SQL in unowned slices.

**(c) The sequence is three parallel tracks, not one chain.** `P-015` split the seats;
the sequence had not caught up. Correcting it:

| Track | Items | Gated on |
|---|---|---|
| **Backend** | **B1a → B1b** | backend owner authors → **PO applies** |
| **Dart** | KAN-58 → B4 → SEC-17 | Flutter agent → PO applies |
| **Owned today** | **B8 / KAN-59** | **Nothing. `CONTRACT.md` gives NS `supabase/functions/send-push-notification/**` = W** |

**B8/KAN-59 is the only gate item that can be authored today** — no hire, no permission
change, no reading of an ambiguous row. It is not the highest severity, but it is the only
one where work can start before the PO answers anything. **It should start now.**

The two tracks are parallel. Nothing in the Dart track blocks the backend track, and neither
blocks B8.
**Status:** ACTIVE

### T-023 — `v_needs_organiser` is an anon-writable path onto `auth.users`; it goes in the first revoke
**Date:** 2026-08-28
**Decision:** `v_needs_organiser` is the **highest-priority object in B1a** and must be in the first
`REVOKE`, ahead of the notification views. `master-analyst` recorded its insert target as
UNESTABLISHED and declined to assert it; I read the `FROM` clause and it resolves to **`auth.users`**
— the identity table, not `profiles`.

**Why — every precondition measured 2026-08-28, none demonstrated:**

```sql
SELECT pg_get_viewdef('public.v_needs_organiser'::regclass, true);
--   SELECT id AS user_id FROM auth.users u
--   WHERE NOT (EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = u.id AND …));
--   profiles appears only in a NOT EXISTS subquery -> the single FROM relation is auth.users
```

| Link | Value |
|---|---|
| view `is_insertable_into` | **YES** |
| `anon` INSERT on the view | **true** |
| view security | **definer**, owner `postgres` |
| `has_table_privilege('postgres','auth.users','INSERT')` | **true** |
| `auth.users` owner | `supabase_auth_admin` — **not** `postgres` |
| `pg_roles.rolbypassrls` for `postgres` | **true** |
| `auth.users` NOT NULL, no-default columns | **`id` (uuid) only** — and the view projects exactly `id` |

**The owner mismatch does not save it.** `T-017`'s bypass was owner-equals-owner; here the owner
differs, so that argument fails — but `postgres` carries **`rolbypassrls = true`**, which reaches the
same place by another route. RLS on `auth.users` does not constrain a definer view executing as
`postgres`. **Two different mechanisms, one outcome: the policy is not evaluated.**

**Bound — and this bound is narrower than `T-017`'s, deliberately.** The preconditions for an
unauthenticated INSERT into `auth.users` are present and measured. **No insert was attempted**
(`019`). Two things are **UNESTABLISHED and must not be stated as fact**: whether `auth.users`'
remaining constraints, unique indexes and triggers (including `trg_strip_signup_password`) admit a
row carrying only `id`; and **whether such a row is useful to an attacker** — it may be an inert
orphan, or it may collide with or poison a subsequent real signup. **Do not describe this as account
creation or account takeover.** The established claim is exactly: *an unauthenticated write path onto
the identity table exists.* That is sufficient to act on and it is not the same as a demonstrated
exploit.

**Rejected — waiting for the exploitability question before acting.** The remediation is a `REVOKE`
on a view **nothing in `lib/` references** (0 client references, verified across all 8). It is free
to close and the question can be answered afterwards on a branch. Ordering the fix behind the
research inverts cost and risk.

**Consequence:** `T-018`'s fix parts (1) and (2) already cover this if applied schema-wide — which is
the argument for the schema-wide form over any per-view carve, now with a second independent
instance. Part (3), `FORCE ROW LEVEL SECURITY`, must cover **all seven** base tables:
`master-analyst` measured `relforcerowsecurity = false` on every one. **And `FORCE RLS` alone would
not have closed this one** — `rolbypassrls` defeats FORCE too. Only the revoked grant closes it.
**Status:** ACTIVE

### P-017 — `v_needs_organiser` leads the REVOKE; and the wording is bounded deliberately
**Date:** 2026-08-28
**Source:** `cto` `T-023`.

**(a) A second, independent instance of the same class.** `v_needs_organiser` resolves to
**`auth.users`** — the identity table. Preconditions measured: the view is insertable, `anon`
holds INSERT, it runs as `postgres`, `postgres` has INSERT on `auth.users` and carries
**`rolbypassrls = true`**, and the only NOT NULL no-default column is `id`, which is what the
view projects.

**Different mechanism from SEC-16, same outcome.** SEC-16 was owner-equals-owner; here the
owner differs, so that argument fails — **BYPASSRLS gets there anyway**. Consequence for the
fix: **`FORCE ROW LEVEL SECURITY` would not have closed this one. Only the revoked grant
does.** That makes REVOKE the load-bearing element, not a companion to the invoker work.

**(b) The wording is bounded, and the bound is the ruling.** `cto` drew it tighter than
SEC-16's deliberately, and I am adopting it verbatim rather than sharpening it.

> **The accurate sentence: an unauthenticated write path onto the identity table exists.**

**Two things are unestablished and must not be stated as fact:** whether `auth.users`'
remaining constraints and triggers admit a row carrying only `id`, and **whether such a row
is useful to an attacker** — it may be an inert orphan. **No insert was attempted.**

**This must not be relayed as account creation or account takeover.** I argued earlier that
loose wording mis-scopes work; this is the case where overstatement would cost most, and
where my own incentive runs toward it — an identity-table finding is the most alarming thing
on the board and the least established. **Recording the bound is the decision.**

**(c) Scope changes, three, all adopted:**
1. **`v_needs_organiser` goes into the first REVOKE, ahead of the notification views.** It
   costs nothing to close — 0 client references across all 8 target views — so the
   exploitability question gets answered afterwards, **on a branch**, rather than gating the fix.
2. **`v_notifications_ranked` is a second entry to the same push trigger.** Revoking only
   `v_notifications_feed` would have left SEC-16 open through the sibling.
3. **All seven base tables need FORCE RLS**, not just `notifications`.

**(d) What it does not change.** The risk profile of applying B1a is unchanged — still a
revoke on objects nothing references, still the safest change on the board. **The PO's
decision is unchanged.** It strengthens the case only in that a second independent instance,
found in the same schema-wide sweep, is the argument against any per-view carve.
**Status:** ACTIVE

### P-018 — SEC-17's surface is three views and two base tables; the free-migration lead is dead
**Date:** 2026-08-28
**Amends:** `P-016` (b). Source: `cto` schema read, closing a lead they raised and then killed.

**(a) The `host_user_id` lead is dead, verified against production.**
`SELECT … information_schema.columns WHERE column_name IN ('host_user_id', …)` → **zero rows.
`host_user_id` does not exist anywhere in the `public` schema.** The comment at
`game_history_providers.dart:49` calling it "nonexistent" is accurate.

**So the consequence is worse than null, as read.** `game_model.dart:81`'s chain is
`creator_user_id ?? host_user_id ?? ''` — the middle term is *always* null because the key
is absent from every payload. Dropping `creator_user_id` resolves `organizerId` to **`''`**,
an empty string that **passes null checks and propagates looking real**. There is no free
migration path.

**Worth recording as method, not just fact:** `cto` raised this as a lead and explicitly
declined to assert it. I passed evidence *bearing on* it — a code comment — at the same bound
rather than adopting it as a finding. `cto` then ran the schema read, and **the answer went
against the person who raised the lead.** Evidence passed at its real strength, verified by
the party with the tooling, resolving against their own hypothesis. That is the protocol
working, and it is the reason the record can be trusted at the end of a long day of
corrections.

**(b) SEC-17's surface is wider than scoped, and the migration target is available.**

- **Good:** `creator_profile_id` exists on `games`, `meetups`, `v_game_card`, `v_meetup_list`
  **and** `v_my_games`. "Migrate the sites to `creator_profile_id`" is available at every
  surface — **no new column required.**
- **Less good:** `creator_user_id` also sits on **`v_meetup_list`**, **`v_my_games`** and the
  **`meetups`** base table. SEC-17 was scoped against `v_game_card` alone. **It is three views
  and two base tables.**

**Ranking and sequence unchanged** — still behind the Flutter hire, still not folded into
B1a. Recorded so whoever scopes it does not discover the extra surfaces mid-migration.

**(c) Final failure taxonomy for SEC-17**, agreed by both seats: **3 query errors · 2 silent
identity substitutions · 1 silently dead navigation.** Five of six failures sit on the
loud-to-silent axis in the wrong direction — which is the argument for migrating the call
sites *before* dropping the column, rather than relying on tests to catch it.
**Status:** ACTIVE

### T-024 — B1b is not a blanket invoker flip; `T-001` and `T-015` conflict, and `T-015` wins
**Date:** 2026-08-28
**Decision:** **A definer view over a zero-policy base table stays definer.** B1b converts only those
views whose base tables carry real policies. For the rest, the security boundary is the **revoked
grant** (`T-015`), not the invoker flip. `T-001`'s stated remedy — *"base-table policies land before
the invoker flip"* — is **superseded for the zero-policy set**: those tables are not getting policies,
so their views are not getting flipped.

**Why — two of my own decisions give opposite instructions and the conflict is live.** `T-001` says
flip the definer views to `security_invoker`, ordering base-table policies first so screens do not
blank. `T-015` says the 30 RLS-enabled zero-policy tables are served *deliberately* through definer
functions and views, and the correct instrument is `REVOKE`, **explicitly rejecting "add policies to
all 30"**. Both cannot be executed. Measured 2026-08-28:

```sql
SELECT tablename, (SELECT count(*) FROM pg_policies p
                   WHERE p.schemaname='public' AND p.tablename=t.tablename) AS policies
FROM pg_tables t WHERE t.schemaname='public' AND t.rowsecurity;
--  games 0 · content_drafts 0 · user_hidden_modes 0
--  user_reputation_aggregate 1 · meetups 2 · notifications 4 · posts 5 · profiles 13
```

**`games` has RLS enabled and zero policies, and `v_game_card` reads it.** `v_game_card` is the live
game surface — explore, social feed, game history, nearby games, the detail screen
(`supabase_config.dart:219`, `game_view_controller.dart:399`). **Flipping it to `security_invoker`
returns zero rows to every user, signed in or not, and blanks the app.** Not a regression risk — a
certainty, and the most-used screens first.

**Two independent sources agree the funnel is deliberate**, which is what makes this a design
constraint rather than a defect to fix: `master-analyst`'s `prosrc` measurement from the database side
(37 definer functions reference `games`), and a source comment from the client side at
`game_composer_screen.dart:205-207` — *"the raw `games` table is not client-readable (RLS with no
policies)"* — written by whoever built it.

**Rejected — adding policies to the zero-policy tables so the flip becomes safe.** This is `T-015`'s
rejected option and the reasons stand: it breaks the definer functions' intended behaviour (they are
*supposed* to see rows the caller cannot), duplicates authorization already inside 37 functions, and
does not remove the wide grant that is the actual exposure.
**Rejected — flipping everything and accepting the blank screens as "the correct failure".** `T-001`
called a blank screen correct because it surfaces missing policies. That reasoning holds where a
policy is *missing*; it does not hold where the absence is the design. Shipping a blank explore tab to
prove a point about a table that was never meant to be client-readable is not a correct failure.

**Refinement, 2026-08-28 — a non-zero policy count is necessary but NOT sufficient.** `master-analyst`
caught that the ruling as first written gates on "base tables carry real policies", and that filter
admits `notifications`: it has **4** policies, but its only INSERT policy is `n_block_insert WITH
CHECK (false)` — the very policy `T-017` is about. **A count tells you policies exist; it says nothing
about whether they admit the rows the view must return, for the roles that call it.**

**The check is therefore two-stage: count first as a cheap filter, then read the surviving tables'
policies against the view's actual read pattern and calling roles.** Flipping on the count alone
delivers the same outage through a table that passed. This is the session's recurring error in its
final form — a count answering *"do policies exist"* being read as *"is this configured correctly"* —
and it is the third time today a count stood in for the thing it merely correlates with.

**Consequence:** B1b is smaller and more surgical than "49 views". The gate item is **the revoke
(`T-018`) plus FORCE RLS where the executing role does not bypass it (`T-023`)**; the invoker
conversion applies only to views over policy-carrying tables and is not, by itself, a promotion
blocker. Whoever executes B1b must check each view's base-table policy count **before** flipping it —
`T-002`'s catalogue test should assert this pairing so a future flip cannot blank a screen.
**Status:** ACTIVE — supersedes `T-001`'s remediation ordering for the zero-policy set

### T-025 — `FORCE ROW LEVEL SECURITY` remediates nothing here; `T-018` part (3) is superseded
**Date:** 2026-08-28
**Supersedes:** `T-018` part (3). **Amends:** `T-017`'s mechanism claim. Source: authoring the final
KAN-67 migration (posted as a comment on KAN-67, 2026-08-28).

**Decision: the KAN-67 migration is REVOKE + `ALTER DEFAULT PRIVILEGES` only. No `FORCE ROW LEVEL
SECURITY` statement ships.** The revoked grant is the entire fix.

**Why — measured, not reasoned.** `T-023` established that `postgres` carries `rolbypassrls = true`
and correctly concluded that FORCE RLS would not close `v_needs_organiser`. It attributed the other
six views to owner-equals-owner, which implied FORCE *would* close those. **That is wrong, and the
same `rolbypassrls` is the operative mechanism for all seven** — every one of the seven views is
owned by `postgres`, so RLS on the base table is evaluated as `postgres`, and `BYPASSRLS` is checked
before the owner/FORCE logic.

Demonstrated read-only against production rather than cited from the manual:

```sql
-- public.sport_profiles: relforcerowsecurity = true, owner = postgres.
SELECT (SELECT count(*) FROM public.sport_profiles) AS visible_as_postgres,           -- 138
       (SELECT count(*) FROM public.sport_profiles sp
          WHERE EXISTS (SELECT 1 FROM public.profiles p
                        WHERE p.id = sp.profile_id
                          AND (p.user_id = auth.uid() OR p.is_active = true))) AS admitted; -- 131
```

**Seven rows visible that no policy admits, on a table where FORCE is already set.** FORCE is
configured and being bypassed. A FORCE RLS statement in the migration would have been a schema change
that does nothing, carrying a false sense of remediation into the verification step.

**Rejected — shipping it anyway "for defence in depth".** It defends nothing while `postgres` holds
`BYPASSRLS`, and it would put a line in the migration whose passing verification means nothing. If
the bypass attribute is ever removed from `postgres`, FORCE becomes meaningful and can ship then, as
its own decision.

**Two further rulings made in the same pass:**

**(a) `geometry_columns` is excluded from the REVOKE, for a second reason beyond decision `021`.**
It is owned by `supabase_admin` and its grant was made by `supabase_admin`. `postgres` is not a member
(`pg_has_role('postgres','supabase_admin','MEMBER') = false`), so a REVOKE issued as `postgres` would
warn rather than act. Excluding it is correct; the sweep filters on `relowner = postgres` for the same
reason.

**(b) The `supabase_admin` half of the `ALTER DEFAULT PRIVILEGES` fix cannot be executed by us and is
marked `NEEDS PO DECISION` in the migration, commented out.** Same membership fact. It matters only
for relations created *by* `supabase_admin` — platform and extension objects — while Dabbler's
migrations run as `postgres`, which the shipped statement covers. `T-018`'s "both grantors" remains
the correct end state; **one of the two is not reachable from this project's roles.**

**Consequence — the base-table half is now the honest remainder.** All **184** base tables in `public`
grant `anon`/`authenticated` write (measured 2026-08-28). Those are RLS-constrained, which the views
were not, so they are not the promotion blocker — but `T-018` part (1)'s "revoke on ALL TABLES then
re-grant the narrow set" is **not** in this migration and must not be read as done. It needs the
re-grant set established first, and that is the backend owner's work.

**And one convention consequence:** after the `ALTER DEFAULT PRIVILEGES` revoke, a new table the app
writes to needs an explicit `GRANT` or the client gets a permission error. That is the correct failure
direction and it is recorded in `CONVENTIONS.md` §6.

**APPLIED 2026-08-28** by `cto` under `G-002`, as migration `20260828160122` —
`kan67_revoke_anon_view_write_grants`. Verification posted as KAN-67 comment `10100`; ticket moved to
**In Review** for `task-auditor`, not Done, because `cto` applied it. Post-apply state, verified:
zero `postgres`-owned views grant write to `anon` or `authenticated`; all seven named views false on
every write flag; `anon`-readable views still **48**, unchanged, so no read path moved; the `postgres`
grantor's default ACL is now `anon=rxtm` / `authenticated=rxtm`. The `supabase_admin` grantor still
carries `arwdDxtm` — ruling (b) above, unreachable and knowingly deferred.

**One execution lesson, recorded because it nearly bit.** The migration's own Step 5 probe
(`BEGIN; SET LOCAL ROLE anon; INSERT …; ROLLBACK;`) is unsafe to paste into an MCP `execute_sql`
call. If the harness autocommits each statement separately, `SET LOCAL ROLE` is discarded and the
`INSERT` runs as `postgres` — succeeding, and firing `trg_push_on_notification_insert` over `pg_net`,
which no rollback undoes. **Role-switching probes go inside a single `DO $$ … $$` block**, which
cannot be split, trapping `insufficient_privilege` as the pass condition. This applies to every future
verification block, not just this one.
**Status:** ACTIVE — applied and verified

---

### G-002 — `cto` gains standing authority to apply production migrations; `019` is amended, not repealed
**Date:** 2026-08-28
**Decision:** The PO, live in chat, directly instructed the assistant to apply the KAN-67
migration. The assistant declined to execute it — 019 was written for exactly that moment —
and asked the PO who should hold the authority instead of the assistant doing it once and
quietly setting a precedent. The PO's answer: **`cto`, standing, not a one-time exception.**

`019`'s prohibition is narrowed from *"no agent, ever"* to *"no agent, except `cto`, and only
under these conditions."* All four must hold for a given migration:

1. **Authored and posted first.** The migration exists as a Jira comment on the ticket it
   closes, in the format KAN-67 established: a plain-English "what this does / does not
   touch" brief, the SQL between `BEGIN;`/`COMMIT;`, and a numbered verification block —
   *before* it is applied, not written up after.
2. **Preconditions measured live, read-only, first.** The population counts, ownership/role
   checks, and any `EXPLAIN`-only demonstrations this migration depends on were run against
   the real project and are cited in the comment — not carried over from an earlier count,
   not assumed.
3. **Schema/privilege/definition changes only — not bulk data mutation.** DDL, `GRANT`/
   `REVOKE`, `ALTER DEFAULT PRIVILEGES`, `CREATE OR REPLACE VIEW`/policy changes are in scope.
   A migration whose SQL includes `INSERT`/`UPDATE`/`DELETE` against existing rows of user
   data is **out of scope for this authority** and still requires the PO to apply it
   personally, unchanged from `019`'s original rule — 021 gave `cto` decision authority, not
   authority over user data.
4. **Verified and posted back after, before the ticket closes.** `cto` runs the comment's own
   verification queries immediately after applying and posts the results to the same ticket.
   This is the residual control for `019`'s original risk (see below) — it is what keeps
   `docs/PROJECT_STATE.md` and the **237-and-counting** migration ledger from silently
   desyncing from what production actually holds.

**Why the bound is here and not wider.** `019`'s reasoning stands: no staging environment, no
repo-authored way to rebuild the schema, and a ledger an agent could desynchronise without
noticing. Nothing about being asked directly, or about the fix being obviously correct, closes
that gap — a well-verified schema migration, documented and checked before and after, does;
an open-ended "apply what you judge correct" does not. The PO chose to place this authority on
`cto` specifically, matching `021`'s existing split — `cto` already owns the technical
correctness call for a migration; this decision adds the hands to execute what `cto` already
had the authority to design.

**Consequence:** `CONTRACT.md`'s "Supabase project — writing" row and the "backend" table are
corrected in the same session to give `cto` a `W*` (conditions 1–4) instead of `—`.
`master-analyst` should treat any `cto`-applied migration as a ledger event: reconcile
`PROJECT_STATE.md` against it on the next audit pass, the same as it would a PO-applied one.
The KAN-67 migration is the first to ship under this authority.
**Status:** ACTIVE — PO decision, supersedes `019`'s "PO only" clause for `cto` under the
stated conditions; `019` otherwise stands for every other agent

---

### G-003 — Two vacant seats filled: `backend-owner` (KAN-70) and `flutter-feature-agent` (KAN-71)
**Date:** 2026-08-28
**Decision:** The PO filled both seats `CONTRACT.md` had named vacant. `.claude/agents/backend-owner.md`
and `.claude/agents/flutter-feature-agent.md` are added, following the existing house pattern
(`notifications-specialist.md`, `app-store-submission-fixer.md`): MODEL/EFFORT frontmatter,
the same brief-reading convention, explicit "what you own vs. what you don't" boundaries.

**`backend-owner`** takes everything Supabase-shaped outside the notification domain: schema,
RLS, RPCs, non-notification edge functions, `supabase/schema/migrations/**` (minus
notification files). **It authors; it does not apply.** Decision `019` still binds it —
only `cto` (under `G-002`) or the PO may run its migrations against production. `cto` still
decides architecture/shape (`021`); `backend-owner` builds what `cto` rules on.

**`flutter-feature-agent`** takes `lib/features/**` (minus `lib/features/notifications/**`),
`lib/core/**`, `lib/data/**` — 23 of 25 slices `CONTRACT.md` had marked UNOWNED. It does not
touch Supabase migrations (routes schema needs to `backend-owner`) and does not apply anything
to production. Per `T-014`, its first task is the KAN-58 teardown, not the 69,612-line dead-code
removal — test coverage on live paths comes first.

**Consequence:** `master-analyst` (file owner) updates `CONTRACT.md`'s permission matrix —
`BO`/`FA` columns added, previously-UNOWNED backend and `lib/features/**`/`lib/core/**`/
`lib/data/**` rows reassigned accordingly. `KAN-70` and `KAN-71` are commented and closed as
resolved — the PO action they asked for is done. Neither new agent gains any production-write
authority; that stays exactly where `019`/`G-002` put it.
**Status:** ACTIVE — PO decision

---

### T-026 — QA is required before promotion, not before every ticket; the missing piece is a mechanical gate, not a reviewer
**Date:** 2026-08-28
**Source:** PO question via team-lead, on whether a dedicated QA pass is required now that
`backend-owner` and `flutter-feature-agent` (KAN-70/71) are coming online. Answers the gap implied by
`task-auditor`'s own definition — "runs BEFORE QA, never instead of it" — which names a QA step that
nothing on the roster fills.

**Decision, in three parts and in this order.**

**(1) `task-auditor` is not sufficient, and does not claim to be.** Its two gates — acceptance criteria,
and alignment with the governance docs — are both document-to-document comparisons. Neither opens the
app. An agent can satisfy every acceptance criterion in prose and ship a screen that throws on first
build. That gap is real and it widens the moment two feature agents are landing work in parallel.

**(2) But the first fix is not a QA agent — it is the automated gate that does not exist.** Measured
today, not assumed:

* `test/` holds **5** test files (`find test -name '*_test.dart' | wc -l`).
* **`flutter test` is run by nothing.** `.github/workflows/deploy-web.yml` runs `pub get` and
  `flutter build web`, and no test step.
* **`flutter analyze` is run by nothing.** Not in the workflow, not in `scripts/cloudflare-build.sh` —
  that script's only checks are four `test -n` guards on environment variables.

So the sole thing standing between a bad commit and `canary.dabbler.pro` is whether an agent
*remembered* to run analyze by hand. **Hiring a QA agent on top of that buys judgment where the
missing thing is arithmetic.** `flutter analyze --fatal-infos` and `flutter test` belong in CI on every
push to `Canary` and every PR into `main`, and that gate scales with throughput in a way a reviewing
agent does not. `version-control` owns the implementation.

**(3) QA as a role: yes — gating `Canary` → `main`, not gating `In Review`.** Running a full QA pass per
ticket would bottleneck two new feature agents on day one for no proportionate gain; most tickets do
not touch a user-visible path. The promotion boundary is where the risk concentrates and where
`KAN-39`'s launch-readiness decision already lives. **Scope the role as verification against the
running app** — the Dart MCP server (`widget_inspector`, `get_runtime_errors`, `hot_reload`) makes
"did anyone actually open this screen" answerable, and that is precisely the question neither
`task-auditor` nor CI can answer.

**Rejected — a QA agent that reviews diffs.** That is `task-auditor` with a second name, and a second
reader of the same artefact finds the second-most-obvious problems, not the ones that matter. If the
QA seat does not drive the app, it should not be filled.

**Rejected — deferring QA until after launch.** The throughput argument cuts the other way: the reason
nothing has slipped through yet is that until now one agent at a time was touching the code.

**Consequence.** Filling an agent seat is the PO's call, not `cto`'s — this decision states the shape
and the boundary, and the PO decides whether to hire. Until the seat exists, the promotion gate is
`task-auditor` plus the CI gate from (2) plus a human look at `canary.dabbler.pro`, and **promotion
should not be described as QA-verified**, because it will not be.

**Flagged in passing, not fixed:** `.github/workflows/deploy-web.yml` publishes to the `gh-pages`
branch on every push to `main` and `BETA`. Production is Cloudflare Pages (`CLAUDE.md`), so `main`
currently drives **two** deploy targets and only one of them is watched. Either that workflow is dead
and should be removed, or it is a live unmonitored surface. Needs its own ticket; it is not part of
this decision.
**Status:** ACTIVE

### P-019 — A comment outlives the persona that wrote it: degrade the author, never hide the comment
**Date:** 2026-08-28
**Ruling for:** KAN-38 `v_comments`/`v_post_comments`. Requested by `backend-owner`, held by `cto`.

**The question.** `profiles.is_active` is not a ban flag — it is the **currently-selected
persona** switch. `persona_service.dart:155-201` `switchActiveProfile` sets *every* profile
for the user to `is_active = false`, then sets exactly one to `true`. Verified directly.
`profiles_select_public USING (is_active = true)` therefore means *"only your currently
selected persona is publicly visible."* Flipping `v_comments` to `security_invoker` with an
INNER JOIN drops **18 of 67 rows** — comments whose author has since switched persona.

**Ruling: LEFT JOIN, then invoker. Degrade the author, keep the comment.** 66 of 67 rows
survive; the 1 genuine cross-tenant leak closes. `backend-owner`'s recommendation, adopted.

**Why:**

1. **The corpus supports it directly.** `04` Art. 11 **Right 2 — Privacy**: *"Privacy
   defaults are protective; expanded visibility requires affirmative player action."*
   Displaying the name and avatar of a persona the user has **switched away from** is
   expanded visibility with no affirmative action. The LEFT JOIN is the protective default.
2. **Hiding harms third parties to protect one.** A comment is a public utterance on a
   public post. Deleting it from the view breaks conversation continuity for *everyone else*
   — replies dangle with no parent. Degrading achieves the privacy outcome without that cost.
3. **A third state settles it, which neither seat raised.** `persona_service.dart:212-224`
   `deactivateProfile` ("for conversion flow") sets `is_active = false` **without activating
   another** — so a user can transiently hold **zero** active personas. Under INNER JOIN,
   every comment they have ever written **vanishes mid-conversion and reappears afterwards.**
   **Content that flickers is worse than content that degrades**, and it is precisely the
   class of defect this gate spent the week removing.
4. **This is consistency, not new behaviour.** Every other public-facing read of `profiles`
   already filters `is_active = true` — `profile_repository.dart:39`,
   `supabase_profile_datasource.dart:173`, `profile_creation_service.dart:87`. `v_comments`
   is the outlier.

**Why not Option 2 (keep definer, revoke the grant).** It is safe and costs nothing today —
and I am declining it. We have just spent a week establishing that **definer-view-plus-grant
is a class of defect, not a set of instances**. Deliberately leaving one instance in place,
immediately after that finding, sets the precedent that the class is negotiable when the fix
is inconvenient. It is cheap to fix now and there is no client to break.

**Two conditions attached to the ruling:**

**(a) The degraded state must be designed, not defaulted.** NULL author fields render as
blank or `null` unless somebody decides otherwise. `14` H6 forbids broken UI and B4 was
exactly this failure. **The comment displays with a neutral, non-identifying author label
and no avatar** — never blank, never `null`, and **never "Unknown user" or "Deleted user"**,
both of which assert something false: the account exists and the comment is genuine. This
binds whoever wires the comments UI, and goes in the ticket **now**, while there is no UI to
retrofit.

**(b) A corpus ambiguity is surfaced, not resolved.** `11 v2` B.1 states a user may hold
*"up to **2 simultaneous profiles** (Player + Organiser)"*, while the code enforces exactly
one `is_active`. These reconcile only under the reading **"hold two, display one"** — which
is nowhere written. **That is the PO's to settle, not mine.** It does not block this
migration: the ruling holds under either reading, because both agree the *non-selected*
persona is not the public-facing identity.
**Status:** ACTIVE

---

### T-027 — Five `anon`-readable views in `public` are intentionally public and are not findings
**Date:** 2026-08-28
**Source:** closing out KAN-38. Raised by `backend-owner` in the definer-view sweep; each claim
**re-verified live and read-only by `cto`** before being recorded, because a "this one is fine"
entry is exactly the kind of note that later gets quoted instead of checked.

**Decision: the five views below stay readable by `anon`. They are not remediation targets, and a
future audit that flags them should be closed against this entry rather than re-investigated.**

| View | Owner | Why it is public |
|---|---|---|
| `username_registry_public` | postgres | `SELECT list_active_usernames()`. Publishing taken usernames is the point — it backs signup availability checking, which by definition must answer before a session exists. |
| `geometry_columns` | supabase_admin | PostGIS catalogue. Not ours, and **not alterable by us** — `pg_has_role('postgres','supabase_admin','MEMBER') = false` (`T-025`). |
| `geography_columns` | supabase_admin | Same. |
| `v_potential_vibes_default` | postgres | Function-backed: `SELECT … FROM rpc_potential_vibes(NULL,'player',…,20)`. |
| `v_recreate_quickpicks` | postgres | Function-backed: `SELECT … FROM rpc_recreate_suggestions('game',NULL,6)`. |

**On the two function-backed views, the reasoning that matters.** `security_invoker` is a **no-op**
for a view whose FROM is a set-returning function — there is no base relation for a policy to be
evaluated against, and the access decision lives inside the function, which injects `auth.uid()`
itself. So "flip it to invoker" would be a change that reads as remediation and remediates nothing.

**But I did not stop at that argument, because it is an argument about mechanism.**
`v_potential_vibes_default` exposes `user_id`, `username`, `display_name`, `score` — if the function
did *not* scope to the caller, this would be a live roster leak, and the mechanism story would still
have sounded correct. Tested as `anon`, read-only, with the expected result written as an assertion:

```sql
SET LOCAL ROLE anon;  -- inside a DO block per T-025
SELECT count(*) FROM public.v_potential_vibes_default;  -- asserted <= 0
```

**The assertion held.** No rows reach `anon`. The scoping is real, not merely claimed.

**Rejected — revoking `anon` SELECT on all five "to be safe".** It would break signup username
availability, and it would revoke on two catalogue views we have no membership to revoke on, which
warns rather than acts and leaves a migration that appears to have done something.

**Rejected — flipping the two function-backed views to `security_invoker`.** A schema change that
does nothing, carrying a false sense of remediation into the verification step. Same error class as
the `FORCE ROW LEVEL SECURITY` correction in `T-025`.

**Consequence.** `anon`-readable views in `public` stand at **45** after KAN-37/38 (from 48). These
five are part of that number **by design**. `master-analyst` should carry them as confirmed false
positives alongside the existing PostGIS and publish-safe-key entries, so the count is never read as
45 outstanding findings.
**Status:** ACTIVE

---

### T-028 — `CONVENTIONS.md` §6b is backed: expected values ship as assertions, not as queries
**Date:** 2026-08-28
**Source:** proposed and written by `master-analyst` after the 2026-08-28 migration run; extended
to census and audit queries at `cto`'s request. Recorded here because **§9.2 requires a numbered
decision behind any convention change** — a standard that appears without one is a silent edit.

**Decision: backed as house form.** Every migration carries its expected values as assertions in
the migration itself. Any census or audit query with a known expected value does the same.

**Why it is a convention and not a preference.** Three defects surfaced on 2026-08-28, and **not
one would have been caught by a query whose output a human read afterwards:**

1. A census predicate testing `option_value = 'true'` reported six genuinely-applied invoker flips
   as **unapplied** — it would have sent someone to re-apply a landed migration.
2. The mirror-image predicate testing `= 'on'` reported the invoker **population** as 6 when it was
   28. Same column, same afternoon, opposite errors — both correct for months only because the data
   had been spelled one way until the day's migrations broke the uniformity in both directions.
3. An `INNER JOIN` invoker flip on `v_comments` would have dropped 18 live comments from public
   posts. The row count was the only signal, and it was checked only because an expected value
   existed to compare it against.

**The distinction that carries the rule: a verification query returns a number and waits to be
believed; an assertion refuses to complete.** Defects 1 and 2 were instrument bugs, and **neither
instrument would ever have flagged itself.** That is why the scope extends past migrations to the
census queries `PROJECT_STATE.md` rests on — the record's credibility depends on instruments that
return a number and wait to be believed, and two of them were wrong on the same day.

**The four rules, each earned rather than reasoned:** assert the control as well as the target
(a leak-closing migration that asserts only zeroes can pass while blanking the app) · assert both
directions on a scoped fix (zero cross-user rows *and* more than zero of the caller's own — only
the first proves security, only the second proves usability) · compare semantically, never by
spelling (`option_value::boolean`) · state the role a count was produced under.

**Rejected — leaving this as a practice rather than a convention.** It was already a practice; it
produced the three defects above anyway, because a practice is what an agent does when it
remembers to. `task-auditor` reads `CONVENTIONS.md` at Gate 2, which makes a missing assertion
block reviewable rather than merely regrettable.

**Consequence.** A migration submitted without assertions is incomplete work and may be rejected on
that basis alone. This applies to `cto`-authored migrations first — the three that shipped today
set the precedent, and the one instrument bug on my side came from a reported figure that carried
no expectation.
**Status:** ACTIVE

---

### T-029 — The six remaining anon-readable definer views split 3/3 on flip-vs-revoke; and my `v_mod_queue_open` base-table claim on KAN-56 was wrong
**Date:** 2026-08-29
**Source:** duplicate triage of KAN-24/25/26/36/56/69. All figures below measured read-only
against `wtncuzcskpigqpmnxwws` on 2026-08-29 — not carried forward from the 2026-08-27 audit.

**Correcting myself first, because the wrong claim is already quoted in a ticket.** My
2026-08-28 comment on KAN-56 said `v_mod_queue_open` and `v_safety_overview` are definer views
over **`moderation_tickets`**, a zero-policy definer-funnel table, and therefore must be revoked
rather than flipped. `moderation_tickets` is not a base relation of either view:

```sql
SELECT DISTINCT d.refobjid::regclass FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
WHERE r.ev_class = 'public.v_mod_queue_open'::regclass
  AND d.classid = 'pg_rewrite'::regclass AND d.refclassid = 'pg_class'::regclass;
--   moderation_reports, profiles      -- NOT moderation_tickets
```

I reasoned from the table's name to the view's name. The conclusion happened to stay correct for
`v_safety_overview` and is **wrong for `v_mod_queue_open`**, which is the one I used as the
worked example. Recorded rather than quietly amended, because the KAN-56 comment is what an
implementing agent would read.

**Decision — the split is by whether EVERY base relation of the view has at least one policy.**
`security_invoker` applies the caller's RLS to *every* joined relation, so one zero-policy base
blanks the whole view for legitimate users. That is the trap; it is the same one that took
`v_comments` from 67 to 48 rows on Migration B.

| View | Base relations (policy count) | Ruling |
|---|---|---|
| `v_mod_queue_open` | `moderation_reports` (2), `profiles` (13) | **FLIP** — verify an admin still sees 9 |
| `v_circle_feed` | `circle_members` (5), `circles` (6), `post_circles` (1), `posts` (5) | **FLIP** |
| `v_circle_feed_visible` | `circle_members` (5), `profile_follows` (4), `v_circle_feed` | **FLIP**, after `v_circle_feed` — nested, the inner view governs |
| `v_safety_overview` | `audit_events` (1), `moderation_actions` (1), `moderation_reports` (2), **`safety_takedowns` (0)** | **REVOKE** + written definer exemption |
| `v_hidden_list` | **`user_hidden_modes` (0)** | **REVOKE** + exemption |
| `v_my_drafts` | **`content_drafts` (0)** | **REVOKE** + exemption |

**Why revoke and not "add the missing policies".** `T-015` and `T-024`: a zero-policy table with
RLS on is deny-all and is reached deliberately through the definer funnel. Adding `auth.uid()`
policies to make the flip safe breaks the funnel. That ruling is unchanged; what changes is
which views it actually applies to — three, not the set I implied.

**Rejected — revoking all six "to be safe."** `v_mod_queue_open` leaks 9 moderation tickets
*about users* and `v_circle_feed` leaks 6 rows of private circle content to `anon` today. Both
have working base-table policies, so the flip fixes them **and** keeps the admin and member
surfaces working. Revoking would close the leak by breaking the feature, then look like success
in the verification step — the failure mode `T-025` and `T-027` were both written about.

**Rejected — treating the four 0-row views as already fixed.** `v_circle_feed_visible`,
`v_hidden_list`, `v_my_drafts` and `v_recreate_quickpicks` return 0 to `anon` today because the
tables are empty, not because anything gates them. A 0-row view is not a fixed view.

**Consequence.** KAN-56 narrows to exactly these six plus the 184-table write grant; KAN-25 and
KAN-36 close into it as duplicates. `v_space_slots_today` is excluded — it raises `42P01` for
every caller and is a KAN-63 repair, not a leak. The per-view verification is row count as
`anon` (must be 0) **and** as a legitimate `authenticated` user who should see the rows (must be
unchanged); on `v_mod_queue_open` that second check is a real admin, and it is the one that
catches me if the 2 policies on `moderation_reports` turn out not to admit admins.
**Status:** ACTIVE

---

### G-004 — `macos/` is deleted after all; the PO overrides `T-012`'s "macOS stays" ruling
**Date:** 2026-08-29
**Source:** PO, direct, in chat, after the assistant flagged that an uncommitted deletion of
`macos/**` sitting in the working tree contradicted `T-012` (`cto`'s repo-hygiene ruling, which
kept `macos/` specifically because of its bundle ID / entitlements / sign-in URL schemes, while
approving `windows/`/`linux/` for removal). The PO's answer: **macOS is not a targeted platform;
removing it does not affect the project. Skip restoring it.**

**Decision:** `T-012`'s "`macos/` stays" conclusion is overridden for this project. The deletion
already sitting in the working tree is correct and should proceed to a normal commit rather than
be reverted. `T-012`'s reasoning about *why* `macos/` is riskier to delete than `windows/`/`linux/`
was sound as a technical matter (bundle ID, entitlements and sign-in URL schemes genuinely cannot
be trivially regenerated) — the PO is accepting that cost knowingly, not disputing the analysis.

**Why this is the PO's to decide and not a correction to `cto`'s work:** `T-012` was a correct
call under the information `cto` had — no plausible desktop target was visible from the repo
alone. Whether macOS is an actual target platform for Dabbler is product/business information no
agent can derive from the tree; per `CONTRACT.md` §2, **the PO overrides everything in the closed
loop**, and this is exactly that kind of override, not a defect in the original ruling.

**Consequence:** the `macos/**` deletion is left in place, uncommitted, to be picked up by
`version-control` in the same repo-hygiene commit as the already-approved `windows/`/`linux/`
removal (or a follow-up one) rather than reverted. `cto` should note this on `T-012` as a
PO-overridden conclusion, since a future reader of `T-012` alone would otherwise still believe
`macos/` stays.
**Status:** ACTIVE — PO decision, overrides `T-012`'s macOS conclusion only; the rest of `T-012`
(what else may go, one-commit scope) is unaffected

---

### G-005 — `master-analyst` is a peer, not a checkpoint; stop routing tasks through it
**Date:** 2026-08-29
**Source:** PO, direct, in chat. Observed from the KAN-58/37/38/67 session: the assistant and
`cto` had built a habit of CC'ing `master-analyst` on routine task completions and migrations
("master-analyst has the ledger note", propagation on every doc change) that had drifted past
what `021` or `G-002` actually required. The PO's read: `master-analyst` should be a peer of
`cpo`/`cto`, not something every task passes through — that costs tokens and time for no
reason, and it is not what the role is for.

**Decision.** `021` already lists `master-analyst` as one of three leadership peers; `G-005`
corrects the drift in practice and in `CONTRACT.md`'s wording (§3's "Leadership vs executive"
paragraph had silently dropped it, naming only `cpo`/`cto` — fixed in the same session).

**What `master-analyst` is:** continuous whole-project understanding — what is built, what is
broken, what is dead, what the docs still get wrong — and the reference new agents and the PO
read to get oriented. A knowledge base that stays current on its own audit cadence, not a
workflow gate.

**What it is not:** it does not review other agents' work (`task-auditor` does, exclusively —
see `CONTRACT.md` §2), and it is not a default recipient of every task, ticket verdict, or
migration. `G-002`'s "treat any `cto`-applied migration as a ledger event" stands, but as a
**pull**: `master-analyst` reconciles on its own next audit pass, not because it was pinged.
The assistant will stop CC'ing it on routine completions going forward.

**One exception, kept, because it is narrow and `master-analyst` itself asked for it:** a
PO-direct edit to one of the four closed-loop files it exclusively writes (`CONTRACT.md`,
`MANIFESTO.md`, `AGENTS.md`, `WORKFLOWS.md`) still gets a same-day note — it is the one file
class `master-analyst` has no other way to discover changed under it, since it is meant to be
the sole writer. This is not "reviewing a task"; it is keeping one agent's own record of its
own file from going stale.
**Status:** ACTIVE — PO decision

### T-030 — A `service_role` policy is a contradiction: service_role bypasses RLS, so the fix is DROP, not rewrite
**Date:** 2026-08-29
**Decision:** The storage policy `"service role write dabbler-news"` is **dropped**, not
rewritten. Any future policy whose stated purpose is "let service_role do X" is likewise a
defect to remove rather than a grant to narrow.

**Why:** measured live 2026-08-29:

```sql
SELECT policyname, cmd, roles::text, with_check FROM pg_policies
WHERE schemaname='storage' AND tablename='objects' AND with_check ILIKE '%dabbler-news%';
-- "service role write dabbler-news" | INSERT | {public} | (bucket_id = 'dabbler-news')
```

**`roles={public}` with no auth check of any kind.** Anyone — including `anon` — can upload
arbitrary objects into that bucket today. The name says service-role; the grant says everyone.

The name reveals the mistake rather than the intent. **`service_role` bypasses RLS entirely —
it never needs, and is never affected by, a policy.** A policy written to enable it therefore
cannot do what it says, and what it actually does is grant the same permission to every role
that *is* subject to RLS. Rewriting it to "narrow it to service_role" would produce a policy
that is still meaningless and merely looks safer.

**Rejected — rewriting the predicate to check for the service role.** It encodes the same
misunderstanding in more convincing syntax, and a reviewer would read it as correct.
**Rejected — leaving it pending a product ruling on write ownership.** That question is real
and separate; it does not need answering to close an open unauthenticated write. Dropping the
policy denies client-tier writes and leaves every legitimate service-role path working
unchanged, because those never consulted it.

**Consequence:** this is a **more urgent finding than the missing SELECT that KAN-27A was
raised for** — an open write outranks a missing read — so it ships in that migration rather
than waiting for its own. Backend-owner was right not to touch it unruled; the ruling is now
made. If a client-tier write path for news media is later wanted, it is designed then, on
evidence, and named for what it actually grants.
**Status:** ACTIVE

### T-031 — A migration file is immutable once applied; corrections ship as new migrations
**Date:** 2026-08-29
**Decision:** Once a migration has been applied to production and recorded in
`supabase_migrations.schema_migrations`, **its file is frozen.** A correction, addition or fix
ships as a **new migration with a new name**. Editing an applied file in place is prohibited,
even when the edit is correct and the file has not yet been committed.

**Why — this was not hypothetical; it happened today and I nearly re-ran into it.** The ledger
records `kan27a_venue_dabbler_news_storage_policies` at version `20260828215203`. But the
version that ran did **not** contain T-030's `DROP POLICY`, which was added to the file
afterwards. Measured before applying anything:

```sql
SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
  AND policyname IN ('venue_select_public','venue_insert_admin','venue_update_admin',
                     'venue_delete_admin','dabbler_news_select_public');   -- 5, all already live
SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
  AND policyname='service role write dabbler-news';                        -- 1, still live
```

All five `CREATE POLICY` statements were already in production with definitions matching the
file exactly, while the `DROP` was not. **Running the file as written would have failed on the
first `CREATE POLICY` (duplicate), part-way through a security migration.** The pre-flight
name-collision check is the only reason that did not happen.

The deeper harm is to the record: **the ledger entry named a file whose content had since
changed**, so neither the repo nor the ledger could tell you what production actually held.
That is precisely the desync `019` was written about and `G-002` condition 4 exists to prevent —
and condition 4 cannot catch it, because it verifies the migration *you* applied, not one
someone else applied and then edited.

**Consequence:** the DROP shipped as `kan27a_followup_drop_open_dabbler_news_write`, a separate
ledger entry that describes exactly what ran. Verified after: open write policy `0`, no
remaining `dabbler-news` INSERT policy, public read intact, 4 venue policies intact, total
storage policies 14 → 13.

**Two additions to the apply routine, both cheap, both would have caught this alone:**
1. **Name-collision pre-flight.** Before any `CREATE POLICY`/`CREATE INDEX`/`CREATE TABLE`
   migration, check whether the objects it creates already exist. A duplicate name means the
   migration, or part of it, has already run.
2. **Check the ledger for the migration's own name before applying it.** If it is already
   recorded, the file must not be re-run — and if the file has changed since, that is a
   `T-031` violation to be reported rather than resolved by applying it.

**Rejected — re-running the corrected `kan27a` file.** It would have errored on the duplicate
policies, and had it somehow succeeded it would have written a second ledger row for a name
already present, making the record worse rather than better.
**Status:** ACTIVE

---

### G-006 — Claim a ticket before applying under it; collisions between same-role instances are structural, not case-by-case
**Date:** 2026-08-29
**Source:** the assistant, after the second same-day collision between two `cto` instances
working the same ticket (KAN-56, then KAN-27A) without either aware of the other. Both were
individually correct under G-002 — same-role, same-authority instances are each entitled to
act — and both root-caused it the same way independently: nothing in the artifacts an agent
checks before applying (the file, the live schema, the migration ledger) records that a peer
is mid-review on the same ticket. `cto-8` named it plainly: *"the collisions are not really
about these two tickets... worth a durable fix rather than another case-by-case untangle."*
Agreed — recording one here instead of a third ad-hoc resolution.

**Decision.** Before applying anything to production under `G-002`, an agent posts a short
**claim comment** on the Jira ticket first — one line, e.g. *"cto-8 claiming this for
apply, starting now"* — and re-reads the ticket's comments immediately before applying to
check no later claim or completed-apply comment landed after its own. A ticket comment is
already the durable, ordered, timestamped record every `G-002` apply already posts to
*after* the fact (condition 4); this decision only asks for the same post to happen *before*
as well, which costs one extra comment and closes the exact gap both collisions exploited.

**Why not `ListAgents` alone.** Both instances involved had already independently landed on
"check `ListAgents` next time" as their own lesson, and it is necessary but not sufficient:
it shows who is *running*, not who is *mid-review-of-this-specific-ticket*, and it says
nothing once either instance goes idle between messages (which is exactly when both applies
in today's collisions happened). The Jira comment is durable across idle periods in a way a
live agent-process check is not.

**Why not a file lock or a database mutex.** Heavier machinery for a problem that is really
about *visibility*, not *concurrency control* — no two applies actually raced on the same
statement today; the failure was two agents each reasonably believing they were the only one
working the ticket. A comment fixes the belief, which is the actual defect.

**Consequence.** `CONTRACT.md`'s `G-002` section gains a fifth condition: claim-comment
first, re-check before applying. Applies to every role with production-apply or
file-owning authority acting under a numbered decision (`cto` today; anyone `G-002`-equivalent
authority is extended to later), not `cto` specifically — the failure mode is about
same-role parallelism, not about this one seat.
**Status:** ACTIVE — PO-adjacent process decision, closes the gap both `T-030`/`T-031`
collisions exposed

### T-032 — KAN-33: adopt the CLI convention, but the baseline is the work and the rename is a consequence
**Date:** 2026-08-29
**Decision:** Dabbler adopts the Supabase CLI convention — **`supabase/migrations/`** — and the
existing 43 files are **archived, not moved**. But the directory question is downstream of the
one that matters, so the ticket's real deliverable is a **schema baseline**.

**Why the ticket's binary is false.** KAN-33 asks: align to `supabase/migrations/`, or configure
the CLI to read `supabase/schema/migrations/`? Measured 2026-08-29:

```
ls -d supabase/migrations        -> ABSENT
ls supabase/                     -> functions  schema
ls supabase/config.toml          -> does not exist
ls supabase/schema/migrations/   -> 43 files, 1 containing CREATE TABLE
```

**There is no `supabase/config.toml`.** No CLI project has ever been initialised here, so the
second option — "configure the CLI" — has nowhere to put the configuration. And the first option
is cosmetic on its own: `master-analyst` measured **244 applied migrations against 43 repo
files**, with roughly 200 having no file at all. **Neither directory can rebuild this schema.**
Renaming the folder the CLI can't use, so that a CLI that isn't configured could read files that
don't reconstruct anything, is motion without movement.

**The sequence, and the baseline is step 1:**
1. **Generate a baseline** capturing the current schema as one file (`supabase db pull`, or a
   `--schema-only` dump). This is the artifact that finally makes the repo able to rebuild the
   database.
2. Create `supabase/migrations/` with the baseline as its first entry, plus a `config.toml`.
3. **Repair the ledger** to mark the baseline applied, so the CLI never replays it at production.
4. **Archive** the 43 existing files to `supabase/schema/archive/`. Their effects are subsumed by
   the baseline; moving them into `supabase/migrations/` would invite the CLI to replay 43
   already-applied migrations.

**Rejected — configure the CLI to read `supabase/schema/migrations/`.** It fights the tool for no
benefit, breaks the expectation of every Supabase doc and any future contributor, and as measured
above the config file it would live in does not exist.
**Rejected — rename the directory and stop.** Leaves ~200 migrations unfiled, the schema still
unbuildable, and adds a new hazard: the CLI would try to replay 43 applied files, **two of which
have names that do not match the ledger** (`kan37_kan38_definer_view_read_sweep.sql` vs the
ledger's `kan37_kan38a_definer_view_read_closure`). Those mismatches are the `T-031` failure again
— files renamed after application — and archiving resolves them.
**Rejected — backfilling the ~200 missing migrations.** They are unrecoverable: the ledger records
that they ran, not the statements they contained. A baseline captures the identical end state in
one file. Reconstruction is archaeology with no payoff.

**Consequence — this is the ticket that closes the oldest gap in the record.** Decision `019`
rested on three facts: no staging environment, a ledger an agent could desynchronise, and **no
repo-authored way to rebuild the schema.** The baseline removes the third. That makes KAN-33
worth more than its "tidy the folders" framing suggests, and it is the reason to do it properly
rather than quickly.

**Boundary note for G-002:** step 3 writes to `supabase_migrations.schema_migrations`. That is
infrastructure metadata, not user data, so it remains inside condition 3 — but it is close enough
to the line that it is named here rather than assumed.
**Ownership:** `backend-owner` authors; `cto` applies under G-002. Steps 1 and 2 are repo work and
need no production access at all; only step 3 touches the database.

**Amendment, 2026-08-29 — step 3 is HELD. Two independent blockers, either sufficient.**
Steps 1, 2 and 4 were delivered well: a 1.38 MB baseline with 193 `CREATE TABLE` and 2,360
`GRANT` lines, a provenance header naming command, project, ledger head and tool versions, 43
files archived as tracked renames, and `config.toml` created. The ledger repair does not follow.

**Blocker 1 — the baseline is already stale.** It was dumped at ledger head `20260829071539`.
Measured after delivery:

```sql
SELECT version, name FROM supabase_migrations.schema_migrations
WHERE version >= '20260829071539' ORDER BY version;
-- 20260829071539  kan56b_v_circle_feed_members_count_fix
-- 20260829072707  kan77_circle_member_count_anon_rpc_leak   <-- NOT IN THE BASELINE
```

`kan77_circle_member_count_anon_rpc_leak` was applied **after** the dump point, so the baseline
does not contain it — and its file is **untracked** (`??`). Anyone rebuilding from the repo would
get a database **missing an anon-leak fix**, with no migration file to supply it. Worse, its
ledger version (`…072707`) is *earlier* than the baseline's filename (`20260829120000`), so it
cannot chain after the baseline either. **A baseline is only true at an instant, and this one has
already been overtaken.**

**Blocker 2 — nothing is committed.** Baseline, `config.toml` and the 43 archive moves are all in
the working tree. A ledger row naming a file that exists in no commit is precisely `T-031`'s
desync wearing new clothes: the ledger would reference a baseline the repo does not contain.

**Ordering rule this establishes — the baseline is dumped LAST, not first.**
`re-dump → commit → repair`, and the dump happens only when no migration is in flight. KAN-77 has
one migration applied and a second authored but not yet applied, so the schema is moving; a
baseline taken now is stale before it is committed. **Never repair the ledger against an
uncommitted file.**

**Also flagged:** `supabase/.temp/` is **not gitignored** (`git check-ignore` → not ignored), so
CLI artifacts would be committed. Add the ignore before the commit.
**COMPLETE, 2026-08-29.** All four steps landed. Step 3 applied by `cto` under G-002:

```sql
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20260829080500', 'baseline_schema');
```

`statements` left NULL deliberately — that is what a repair means: *recorded as applied, not
executed here*, because the schema it describes is already live.

Verified after: baseline row present, `statements IS NULL`, no duplicate, ledger head now
`20260829080500`, 248 rows total. Both blockers were cleared first — commit `8c82caf` (46 files,
scoped, exclusions honoured) and head unchanged at `20260829073752` with **0** migrations landed
since the dump.

`backend-owner` followed the re-dump discipline exactly, including **discarding a completed dump**
because the head moved mid-flight — moved by my own KAN-52 applies. The race this rule was written
against fired on the very next attempt, which is the best possible evidence the rule was needed.

**What this changes, stated precisely.** Decision `019` rested on three facts: no staging
environment, **no repo-authored way to rebuild the schema**, and a ledger an agent could
desynchronise. **The second is now false as to the artifact** — a 1.38 MB baseline with 193
`CREATE TABLE` and 2,360 `GRANT` statements exists, is committed, and is recorded in the ledger.

**It is not yet false as to the capability.** Nobody has restored from it. The baseline is
*mechanism-verified, not observation-verified* — the same distinction applied to KAN-58. Until a
rebuild is actually performed against a scratch project, the honest claim is "the artifact exists",
not "we can rebuild". **Whether that changes anything about `019` or `G-002`'s bounds is a PO
decision, and nothing here loosens either.**
**Status:** ACTIVE — COMPLETE 2026-08-29

### T-033 — Amends `T-032` step 4: seven of the 43 files are not in the ledger, and one of them was never applied
**Date:** 2026-08-29
**Decision:** `T-032` stands — adopt `supabase/migrations/`, the baseline is the work. **Two
corrections to it, both measured, neither overturning it.**

**(1) Step 4 is wrong as written.** It says archive all 43 files because "their effects are
subsumed by the baseline." That is true for 36 of them and **false for at least one**. Name-exact
reconciliation against the live ledger, 2026-08-29:

| | Count |
|---|---|
| Ledger entries (`supabase_migrations.schema_migrations`) | **244** |
| Repo files in `supabase/schema/migrations/` | **43** |
| Repo files matching a ledger `name` | **36** (35 in the `>= 20260627` era, plus `add_select_policies_game_roster_and_waitlist` → `20260521203824`) |
| Repo files with **no ledger entry at all** | **7** |
| Ledger entries with no repo file | **208** |

The 7 unmatched files, and whether production actually carries their effect:

* `baseline_notification_engine.sql` — **applied.** `process_notification_event`,
  `flush_notification_aggregates` exist.
* `add_rpc_get_nearby_games.sql` — **applied.** `rpc_get_nearby_games` exists.
* `add_rpc_get_nearby_venues.sql` — **applied.** `rpc_get_nearby_venues` exists.
* `fix_push_trigger_edge_auth.sql` — **applied.** `get_push_trigger_secret`,
  `trg_push_on_notification_insert` exist.
* `kan37_kan38_definer_view_read_sweep.sql`, `kan38_v_comments_read_sweep.sql` — **applied under
  different ledger names** (`kan37_kan38a_definer_view_read_closure`,
  `kan38b_v_comments_leftjoin_invoker`). Already identified in `T-032`; a `T-031` rename.
* `add_post_theme_id_and_seed_themes.sql` — **NOT APPLIED.** `public.posts` exists,
  `public.post_themes` exists, **`posts.theme_id` does not exist.** No ledger row under this name.

A baseline is a dump of production. Production does not have `posts.theme_id`. So the baseline
cannot subsume this file, and archiving it under `T-032` step 4 would silently delete a pending
schema change — the exact class of loss `T-032` was written to end.

**Therefore:** archiving is the default, but **each of the 7 is adjudicated individually before
archiving, against the live catalogue — never against the filename.** A file whose objects exist
is archived. A file whose objects do not exist is **not** archived and **not** placed in
`supabase/migrations/`; it goes to the PO as an open question — is `posts.theme_id` wanted, or is
this abandoned work? That is a product question, not a filing one.

**Nothing enters `supabase/migrations/` with a version not already in the ledger, except the
baseline.** A file placed there with a fresh timestamp is a file the next `db push` executes
against production. `add_post_theme_id_and_seed_themes.sql` is precisely such a file today.

**(2) The rejection of "configure the CLI" is stronger than `T-032` states.** `T-032` rejects it
because `supabase/config.toml` does not exist. The real reason is that **the option does not
exist.** Verified against the installed CLI (`supabase 2.48.3`, `supabase init` in a scratch
directory): `[db.migrations]` accepts only `enabled` and `schema_paths`. `schema_paths` is glob
input for *declarative schema* files, not a relocation of the migrations directory — that path is
hardcoded to `supabase/migrations`. Creating a `config.toml` would not have helped. KAN-33's
acceptance criteria offer a choice between one real option and one that cannot be configured.

**Rejected — supersede `T-032`.** Its reasoning holds and its sequence is right; only one step's
premise is too broad. Superseding a correct decision over a scoped defect churns the record.
**Rejected — quarantine all 43 and adjudicate each.** 36 are ledger-matched; re-deriving what the
ledger already asserts is the duplication `T-032` correctly refused.

**Consequence:** `T-032`'s four steps stand, with step 4 amended to: *archive the 36
ledger-matched files; adjudicate the 7 unmatched against the live catalogue; escalate any whose
objects are absent.* Ownership is unchanged — `backend-owner` authors, `cto` applies step 3 under
`G-002`.
**Amendment, 2026-08-29 — the 7th file is not a PO question. My premise was wrong: I checked
the wrong column.** `backend-owner` held rather than acting, and was right to.

I ruled `add_post_theme_id_and_seed_themes.sql` unadjudicable — hold pending a PO call on whether
the feature is wanted — because I queried `posts.theme_id` and it did not exist. **The file adds
`post_theme_id`.** Re-measured:

```sql
posts.theme_id           -> 0    <-- the column I checked. Does not exist. Never did.
posts.post_theme_id      -> 1    <-- the column the file actually adds. EXISTS.
posts_post_theme_id_fkey -> 1    <-- exact FK name the file would create. EXISTS.
public.post_themes       -> 5 rows, all is_system
posts WHERE post_theme_id IS NOT NULL -> 9      <-- LIVE POSTS ARE USING IT
```

**Nine live posts reference a theme.** The feature is not unapplied, not abandoned, and not a
product question — it shipped, and it is in use. There was never anything to ask the PO.

`backend-owner` also measured content drift proving the file is not what shipped: its
`'System Default'` is `background_type='color'` `#1E1E1E` while live is an `image` purple
gradient; its `'News'` is `'gradient'` while live is `'image'`. And live carries two themes
(`'Alert'`, `'Stadium'`) the file never seeds. So this is a **stale draft superseded by something
else already applied** — the same `T-031` shape as the two rename cases, with no ledger row under
its own name.

**Corrected ruling: archive it as a superseded draft with the other 42.** The 7-file adjudication
set becomes 6.

**How the error happened, because it is the session's recurring one.** I searched for a plausible
column name rather than the one the file creates, got a confident `0`, and read "column absent"
as "work never applied" — which manufactured a PO question out of a typo of my own. An instrument
answering a *nearby* question: `theme_id` and `post_theme_id` are one prefix apart, and the wrong
one returns a clean, unambiguous answer. **When adjudicating a file against the catalogue, the
identifiers come from the file, never from memory of what they probably are.**
**Status:** ACTIVE — amends `T-032`, does not supersede it; amended 2026-08-29

---

### G-007 — `android/**` was UNOWNED; `flutter-feature-agent` gets it, matching AS's `ios/**` pattern
**Date:** 2026-08-29
**Source:** the assistant, after `task-auditor-9` failed KAN-60 partly on a real permission
violation — the assistant had dispatched `flutter-feature-agent-4` to fix Android manifest/XML
backup config, and `android/**` was `UNOWNED` in `CONTRACT.md` except `notifications-specialist`'s
narrow FCM/manifest exception; `flutter-feature-agent`'s own cell there was `R`. The work itself
(manifest wiring, two new `res/xml/**` files) was independently verified correct by
`task-auditor-9` — the ticket failed on ownership and on a separate structural AC conflict
(Android's backup exclusion is file-granular; the ticket's "don't over-exclude" AC is not
satisfiable that way without a PO call on scope, raised to the PO separately), not on the code.

**Decision.** `flutter-feature-agent` owns `android/**` platform config — manifest, native
resources, Gradle — the same shape as `app-store-submission-fixer`'s existing `ios/**` row:
`notifications-specialist` keeps its narrow write for FCM channel/manifest changes and must
still say so in its status entry so `flutter-feature-agent` isn't surprised finding a change it
didn't make.

**Why this seat and not a new hire.** Same reasoning as `G-003`/`G-005`: a vacant cell is not a
permission needing contesting, it's a seat the table already expects to be filled, and
`flutter-feature-agent` is the closest-fit existing role (it already owns `lib/core/**`, the
Dart side of the same platform surface) rather than justifying a dedicated Android-only agent
for one manifest change.

**Consequence:** `CONTRACT.md`'s `android/**` row corrected in the same session. KAN-60's rework,
once it resumes, is no longer blocked on this — the ownership question that failed it is closed.
**Status:** ACTIVE — PO-adjacent process decision, closes the ownership half of `task-auditor-9`'s
KAN-60 finding

---

### G-008 — Route to the owner, not through a manager. `cto` coordinates; it does not relay
**Date:** 2026-08-29
**Source:** PO, direct. The observed pattern was
`PO → assistant → cto → specialist → cto → assistant → PO`, sometimes with a second manager hop
inside it. The PO's verdict: *"The CTO often appears to be performing work instead of managing
work. That is not the intended architecture."* Correct, and the cause is the assistant's dispatch
habit, not the agents' behaviour — `cto` answered what it was asked.

**Decision, five rules.**

**1. Direct routing is the default.** A request belonging to one domain goes straight to that
domain's owner, per `CONTRACT.md` §3. No manager approval, no manager relay, no asking `cto` for
something the specialist already knows. `backend-owner` answers schema questions;
`flutter-feature-agent` answers Dart questions; `master-analyst` answers state questions;
`task-auditor` answers "is it really done".

**2. `cto`/`cpo` are for coordination and rulings only** — multi-domain features, cross-cutting
architecture, dependency ordering, prioritisation, and decisions reserved to them by `021`
(`cto`: architecture/schema/stack shape; `cpo`: product/scope). **`cto` applying production
migrations under `G-002` stays** — that is an authority, not a relay. What ends is `cto` being
asked implementation questions its specialists own.

**3. Decompose before dispatching.** Work that splits into independent units is dispatched as
independent units, in parallel, each to its owner — not handed to one agent as a bundle, and not
serialised through a manager. Assemble at the end.

**4. Reports are short.** What was done · files changed · blockers if any · result. No
management summaries, no restating the brief, no narrating what a peer already said.

**5. Peer-to-peer is expected.** `backend-owner ↔ notifications-specialist`,
`flutter-feature-agent ↔ task-auditor`, and so on, direct via `SendMessage`. Routing a peer
question through `cto` or through the assistant is the anti-pattern this decision names.

**What this does not change.** `019`/`G-002` (only `cto` or the PO writes production),
`G-006` (claim-before-apply), `CONTRACT.md` §2's closed loop (`task-auditor` reviews everything
and writes nothing it could be judged on), and `G-005` (`master-analyst` is a peer, not a
checkpoint) all stand. **This decision is `G-005` generalised**: `G-005` stopped one seat becoming
a mandatory hop; `G-008` says no seat is one.

**Consequence.** The assistant dispatches to owners, relays specialist results to the PO without
a manager in between, and stops spawning a `cto` instance to investigate what a specialist owns.
`CONTRACT.md` §3 gains a routing note pointing here.
**Status:** ACTIVE — PO decision

---

### G-009 — `cto` may apply security-remediation data changes; `G-002` condition 3 is narrowed
**Date:** 2026-08-29
**Source:** PO, direct, after `cto` correctly declined to apply KAN-78 — an `UPDATE` nulling the
passwords of 55 compromised seed accounts — because `G-002` condition 3 reserves user-data
mutations to the PO personally. The rule worked as designed; the PO's answer: *"The CTO can do
the migration job after confirming."*

**Decision.** `G-002` condition 3 is narrowed. `cto` may apply a data change (`UPDATE`/`DELETE`
against existing rows) when **all** of these hold, on top of `G-002`'s other four conditions:

1. **It is remediation of a recorded security finding**, not a product or content change — the
   ticket exists, the exposure is measured, the fix closes it.
2. **It is scoped by an executable guard**, not by hand-checked intent: the migration aborts
   (`RAISE`) unless the live row count matches the expected count exactly, so it cannot silently
   drift onto a different set if run later or re-run.
3. **`cto` confirms the preconditions live immediately before applying** — the PO's *"after
   confirming"* — and records the measured numbers in the ticket comment.

Anything failing those tests stays PO-only under `019`: bulk content edits, backfills, product
data corrections, and any data change whose blast radius is not bounded by an assertion.

**Why the narrowing is safe.** The three conditions are what made KAN-78 low-risk in the first
place: a bounded, asserted, 55-row change to accounts that have never been signed into, closing a
live credential exposure. The original blanket exclusion was written before `T-028` made
executable assertions standard; with that in place, "cannot touch more rows than intended" is
enforced by the migration rather than trusted to the applier.

**Consequence.** KAN-78 is applied by `cto` under this decision. `CONTRACT.md`'s Supabase writing
row cites `G-009` alongside `G-002`. `019`'s bar stands for every other agent and every
non-remediation data change.
**Status:** ACTIVE — PO decision, narrows `G-002` condition 3

---

### T-034 — KAN-61's CI credential: a zero-grant Postgres login over the pooler, and why `cto` does not mint it
**Date:** 2026-08-29

**Context.** KAN-61 shipped a CI gate (`.github/workflows/anon-allowlist-check.yml`,
`scripts/ci/check_anon_allowlist.sh`) that enforces `T-002` by diffing the live catalogue
against the allowlist in `SCHEMA.md` §2f. It is blocked on one missing GitHub Actions secret,
`SUPABASE_DB_URL`. `version-control-6` correctly stopped rather than guess a credential.

**Decision — the credential is a dedicated, zero-grant login role, not a reused one.**
Not `postgres` (BYPASSRLS, owns the schema), not `service_role`, not a Supabase personal
access token (a PAT reaches the whole account — including the second, unrelated project that
`CLAUDE.md` forbids touching — so it is *wider* than a DB login, not narrower).

Measured live, read-only, 2026-08-29 — the gate needs no grants at all:

* `pg_database.datacl` on `postgres` is `{=Tc/postgres,...}` — **PUBLIC already holds CONNECT**,
  so a bare role connects without an explicit grant.
* Cross-role privilege inquiry does not require membership. Proven by acting as `anon`
  (`SET LOCAL ROLE anon`, `pg_has_role(...,'authenticated','MEMBER') = false`) and still
  resolving `has_table_privilege('authenticated', c.oid, 'SELECT')` across all public views
  → `47`. A role with zero grants can therefore answer the gate's question about `anon`.

**Consequence — accepted blast radius.** Any login role can read all of `pg_catalog`:
every table and column name, every view definition, every RLS policy, and every function
body via `pg_proc.prosrc`. Catalog read is granted to PUBLIC and is not practically
revocable, so **full schema disclosure is unavoidable for any DB credential** and is accepted
here. What the role cannot reach is user data: with no table grants, RLS is not even the
binding constraint. This is strictly less exposure than a leaked `service_role` key.

**Consequence — the secret must be the pooler URL, not the direct host.** Measured:
`db.wtncuzcskpigqpmnxwws.supabase.co` resolves to an **AAAA record only** (no A record).
GitHub-hosted runners have no IPv6. The connection string in `check_anon_allowlist.sh`'s
header — "a direct Postgres connection string" — is therefore wrong for the environment the
script runs in, and the direct host will fail from CI. The secret must use the Supavisor
pooler with the `<role>.wtncuzcskpigqpmnxwws` username form. The project's IPv6 sits in AWS
`eu-west-2` space, but **the pooler shard prefix must be copied from the dashboard, not
inferred** — every region's pooler hostname resolves regardless of project membership, so DNS
proves nothing about which shard serves this project.

**Consequence — `cto` does not mint this credential, and the bound is the transcript.**
`G-002` covers the DDL (`CREATE ROLE` is a privilege change, not data mutation), so authority
is not the obstacle. The obstacle is that `cto`'s only DDL path to production is the Supabase
MCP, which takes SQL as a tool argument — so the password would be written into an agent
transcript. A production database credential that has passed through a transcript is not a
clean credential, and the alternative costs the PO one paste in the SQL editor. `ALTER ROLE`
cannot accept a password the author has not seen (a pre-hashed SCRAM verifier still requires
knowing the password), so there is no agent-side way around this. **The PO runs the
`CREATE ROLE` and sets the secret; `cto` specifies both.** Filed on KAN-61.

**Gate status at time of writing.** The live query returns exactly the 12 views on the
`SCHEMA.md` §2f allowlist — `geography_columns`, `geometry_columns`,
`username_registry_public`, `v_challenge_card`, `v_game_card`, `v_meetup_list`, `v_my_games`,
`v_potential_vibes_default`, `v_rateable_after_game`, `v_recreate_candidates`,
`v_recreate_quickpicks`, `v_space_slots_today`. The gate passes the moment it can connect.

**Bounded observation, not a ticket.** The workflow also triggers on `pull_request` into
`main`. GitHub does not expose secrets to fork PRs, so an outside PR would hit a permanently
red gate nobody can fix. The repo is private and single-org, so this is latent, not live —
it becomes real only if `dabblersport/webapp` ever accepts outside contributions.

**Status:** ACTIVE — provisioned and verified 2026-08-29. The PO created `dabbler_ci_readonly`
in the SQL editor and set `SUPABASE_DB_URL` via `gh secret set`; no password reached an agent
transcript. The pooler prediction held: the gate connects from GitHub-hosted runners and reads
`pg_catalog` with zero grants, confirming a role with no privileges answers this question.
Proven end to end on PR #11 (closed unmerged, branch deleted) — run `33259101405` green
(`OK: all 12 …`), run `33259141446` red on a live catalogue read (`FAIL: … - v_game_card`),
run `33259167876` green again. The red run is the `T-002` gate doing its job against
production data with no DDL against `wtncuzcskpigqpmnxwws`.

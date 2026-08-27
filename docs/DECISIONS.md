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
**Status:** ACTIVE — **but widely contradicted.** The audit counted **233** hardcoded
`Color(0x…)` in `lib/features/`: `auth_onboarding` 97, `rewards` 65, `venues` 20,
`social` 20, `games` 13, `profile` 11. Only `auth_onboarding`'s 97 are worth fixing —
`rewards`' 65 disappear if that slice is deleted (see 015).

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
**Status:** ACTIVE

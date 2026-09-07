# docs/CONVENTIONS.md — Coding Conventions

**Owner:** master-analyst (write) · all agents (read)
**Last updated:** 2026-08-26
**Purpose:** Standard conventions, chosen so an agent never has to ask. Deviate only with
a logged decision in `DECISIONS.md`.

This file states rules. The reasoning lives in `DECISIONS.md`; the non-negotiables live in
`MANIFESTO.md`.

**Every violation count below cites its finding in `docs/PROJECT_STATE.md`.** That is not
bookkeeping: a number with no source cannot be re-checked when the source changes, and it
changed twice on 2026-08-27. `PROJECT_STATE.md` is the measured record and this file is a
consumer of it — **if a count here disagrees with `PROJECT_STATE.md`, that file wins** and
this one is corrected in the same session. Where a convention is widely violated in existing code, the row says so —
**a convention binds the code you write, not the code you pass through** (`MANIFESTO.md` R8).

---

## 1. FILE & FOLDER NAMING

| Thing | Convention | Example |
|---|---|---|
| Dart file | `snake_case.dart` | `game_detail_screen.dart` |
| Feature slice | `snake_case/` under `lib/features/` | `lib/features/venue_submissions/` |
| Screen | `<subject>_screen.dart`, class `<Subject>Screen` | `profile_edit_screen.dart` → `ProfileEditScreen` |
| Controller | `<subject>_controller.dart`, class `<Subject>Controller` | `check_in_controller.dart` |
| Provider file | `<subject>_providers.dart` | `notifications_providers.dart` |
| Repository interface | `<subject>_repository.dart` | `rewards_repository.dart` |
| Repository impl | `<subject>_repository_impl.dart` | `notifications_repository_impl.dart` |
| Datasource | `supabase_<subject>_datasource.dart` | `supabase_games_datasource.dart` |
| Model (Freezed) | `<subject>_model.dart` | `notification_model.dart` |
| Test | mirrors the source path under `test/` | `test/features/games/domain/models/game_test.dart` |
| Migration | `<timestamp>_<verb>_<subject>.sql` | `20260826120000_add_notification_policies.sql` |

**Never use a `_v2`, `_new`, `_old` or `.broken` suffix.** If a file replaces another,
delete the one it replaces in the same change. The tree currently contains
`activities_screen_v2.dart` and `notifications_screen_v2.dart` — both of which are the
**live** screens whose v1 predecessors were deleted — and `create_game_screen.dart.broken`,
632 lines tracked since April. That ambiguity is exactly the cost this rule prevents.

---

## 2. THE FEATURE SLICE LAYOUT

```
lib/features/<domain>/
  domain/
    repositories/   # abstract interfaces
    usecases/       # extend UseCase<T, Params>
    models/         # domain-only models
  data/
    datasources/    # Supabase calls
    repositories/   # concrete impls of the domain interfaces
    mappers/        # entity ↔ model
  presentation/
    screens/        # ConsumerWidget / ConsumerStatefulWidget
    widgets/
    controllers/    # StateNotifier with a typed XxxState
    providers/      # infra → repo → controller
```

**A slice may omit `domain/usecases/` and `data/datasources/`** and wire the repository
straight to the controller. Do this when the feature has no business logic beyond fetching
and shaping data — which is most of them. The full tree is not a target to aspire to.

**Do not build a layer you cannot reach.** Adding `domain/usecases/` to a slice whose
screens do not exist yet produces exactly what this codebase already has too much of. See
`MANIFESTO.md` §2.

---

## 3. STATE MANAGEMENT

- Riverpod 2.x throughout.
- **Three-layer stack:** infra provider → repository provider → controller provider.
- In widgets: `ref.watch(provider)`.
- In the router (no `BuildContext`):
  `ProviderScope.containerOf(context, listen: false).read(provider)`.
- **Every provider is exported from `lib/providers.dart`.** Append your export; do not
  reorder the file (`CONTRACT.md` §4).
- A provider that nothing watches is dead. Before adding one, know which widget will
  consume it — **113 of 400 providers in this codebase are currently orphaned**
  (`PROJECT_STATE.md` PROV-01).
- A provider must not throw at construction. `authRepositoryProvider`
  (`auth_providers.dart:265`) throws `UnimplementedError` and is defused only because
  nothing watches it. Return an `Err` or do not declare the provider.

---

## 4. ERROR HANDLING

- All data operations return `Result<T, Failure>` from `lib/core/fp/result.dart`.
- Async work is wrapped:
  ```dart
  return Result.guard(
    () async => await supabase.from(SupabaseConfig.gamesTable).select(),
    (e) => Failure.from(e),
  );
  ```
- **Never throw across a layer boundary.** A repository that throws is a bug.
- Failure types live in `lib/core/errors/`.
- **Never write an empty catch block.** If an error is genuinely ignorable, say so in a
  comment naming why. There are 44 empty catches in the tree (`PROJECT_STATE.md` ERR-01);
  7 of them silently swallow
  failures on the live onboarding path.
- **Never use `print()` in production code — use `debugPrint`.** 26 `print()` calls remain
  (`PROJECT_STATE.md` STYLE-02); the zone guards in `main.dart` and `lib/utils/logger.dart`
  are intentional, but `post_repository_impl.dart`'s `print('INSERT PAYLOAD: $data')` logs
  request bodies and should be deleted, not converted.
- **Never write `on UnimplementedError catch`.** Catching your own unfinished work makes
  it invisible (`settings_screen.dart:1194`).

**Legacy `Either` — migration status** (`PROJECT_STATE.md` ARCH-03). 31 files still use `Either<Failure, T>` from
`fpdart` against 124 on `Result`. Both appear *inside* four slices: `profile` (12/3),
`games` (11/5), `social` (2/10), `auth_onboarding` (1/7). `lib/data/` is nearly done (2/68).

- **New code uses `Result`.** Always.
- **Never mix the two in one file.**
- **Do not convert a file you are merely passing through** — conversion is its own work
  item, because it changes every caller.

---

## 5. DESIGN SYSTEM

- **Never hardcode a colour.** Use `Theme.of(context).colorScheme` or the `AppTheme`
  category extensions (`colorScheme.categoryMain`, `.categorySocial`, `.categorySports`,
  `.categoryActivity`, `.categoryProfile`).
- Screens set their palette with `AppTheme.setActiveCategory(category)` in `initState` or
  on navigation. All five categories are preloaded in `main.dart`.
- Standard layout: `TwoSectionLayout` (purple top / dark bottom).
- Components: `AppButton.primary/secondary/ghost`, `AppCard`, `AppButtonCard`,
  `AppActionCard`, `CustomInputField`.
- Spacing: the 4dp grid, via `AppSpacing`.
- Icons: Lucide (`lucide_icons`) and Iconsax (`iconsax_flutter`).
- **Routes use a transition wrapper**, never raw `MaterialPage`. Choose from
  `lib/utils/transitions/page_transitions.dart`.

**The triple-copy palette rule.** Each palette × mode exists in three places that must be
edited together:
1. `lib/design_system/tokens/<name>-<mode>-theme.json` — the design-tool export
2. `lib/design_system/tokens/<name>_<mode>.dart` — what compiles
3. `lib/themes/app_theme.dart` — assembles the `ThemeData`

Miss one and the palette disagrees with itself depending on the surface. There is no
generator; the sync is manual (decision 008).
`lib/design_system/JSONS/` is **dead** — 0 references — and is not a fourth copy.

**Existing violations: 233** hardcoded `Color(0x…)` in `lib/features/`
(`PROJECT_STATE.md` STYLE-01) — `auth_onboarding`
97, `rewards` 65, `venues` 20, `social` 20, `games` 13, `profile` 11. Binding on new code;
not an invitation to fix the old.

---

## 6. SUPABASE ACCESS

- Access via `Supabase.instance.client`.
- **Every table, bucket, RPC and sport-constraint name comes from
  `lib/core/config/supabase_config.dart`.** Never inline a string.
- Add new constants; **never change an existing constant's value** without a
  `DECISIONS.md` entry — the value determines which table the whole app talks to.
- **Verify a bucket or table exists before using its constant.** Two constants currently
  name things that do not exist: `venueImagesBucket = 'venue-images'` (real name: `venue`)
  and a hardcoded `'avatars'` in `supabase_profile_datasource.dart:16` (real name:
  `Avatar`).
- **Trust RLS.** No client-side permission checks; ask and let the database refuse. Admin
  gating calls `rpc(SupabaseConfig.isAdminFn)`.
- **New tables ship with policies in the same change.** RLS enabled with zero policies
  denies everything and looks like an empty result set, not an error.
- **New views are created `security_invoker = true`** unless a decision says otherwise. A
  `SECURITY DEFINER` view bypasses the underlying table's RLS entirely.
- **Before flipping an existing view to `security_invoker`, run T-024's two-stage rule
  against every relation the view touches — joins included, not just the table you
  think of as primary.** `security_invoker` applies the caller's RLS to all of them,
  and an INNER JOIN whose right side is filtered by RLS drops the entire row, not just
  the joined columns. Stage 1 is "does the relation have a SELECT policy"; stage 2 is
  "does that policy admit the rows this view is supposed to return, for the roles that
  call it". Stage 1 alone is not enough. **Prove it with a before/after row count**
  computed read-only, rather than reasoning about it: `v_comments` (`comments JOIN
  profiles`) was measured at 67 rows to anon before and 48 after, where only 1 of the
  19 lost rows was the leak being closed.
- **New tables and views ship with their own explicit `GRANT`.** As of migration
  `20260828160122` (KAN-67, applied 2026-08-28), `ALTER DEFAULT PRIVILEGES` for grantor
  `postgres` in `public` no longer hands `anon` and `authenticated` write on every
  relation created — the default is now `rxtm`, read without write. A new table the app
  writes to gets a permission error until it is granted. That failure is loud and
  correct; the fix is a `GRANT` in the same migration, scoped to what the app actually
  writes, never a blanket `GRANT ALL`.
- **Never grant `anon` or `authenticated` write on a view.** Nothing in this app writes
  through a view, and an auto-updatable view over a definer boundary is a write path
  around RLS (`T-018`, `T-023`, `T-025`).
- Edge functions live in `supabase/functions/<name>/index.ts`, called via
  `supabase.functions.invoke('name', body: {...})`.

---

### 6b. Every migration carries its expected values as assertions, not as a query

*Written by `master-analyst` 2026-08-28, extended to census and audit queries at `cto`'s
request, and backed by `cto` under `T-028`. Applies to migrations, and to any census or audit
query with a known expected value.*

**A verification query returns a number and waits to be believed. An assertion refuses to
complete.** Write the expected value into the migration:

```sql
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.v_comments;          -- as the role under test
  IF n <> 66 THEN
    RAISE EXCEPTION 'expected 66 rows, got %', n;
  END IF;
END $$;
```

**Why this is a convention and not a preference.** On 2026-08-28 three separate defects were
found by comparing a number against an expectation, and **not one of them would have been
caught by a query whose output a human read afterwards:**

- A census predicate testing `option_value = 'true'` reported six genuinely-applied invoker
  flips as **unapplied** — it would have sent someone to re-apply a landed migration.
- The mirror-image predicate testing `= 'on'` reported the invoker **population** as 6 when it
  was 28.
- An `INNER JOIN` invoker flip would have dropped 18 live comments; the row count was the only
  signal, and it was only checked because an expected value existed to compare against.

**Rules:**

1. **Assert the control as well as the target.** A migration that closes a leak must also
   assert that a path which *should* still return rows still does — `v_game_card` returning
   216 is what proves the fix did not blank the app.
2. **Assert both directions on a scoped fix.** Zero cross-user rows *and* more than zero of
   the caller's own. Only the first proves security; only the second proves usability.
3. **Compare semantically, never by spelling.** `option_value::boolean`, not
   `option_value = 'true'` — Postgres accepts `on`/`true`/`yes`/`1` as one value.
4. **State the role.** A count means nothing without the role that produced it; run it under
   `SET LOCAL ROLE anon` or a real JWT, and say which in the assertion message.

See `PROJECT_STATE.md` changelogs 1s–1v for the three migrations this came out of.

### 6c. `CREATE OR REPLACE VIEW` silently resets `security_invoker`

**Every `CREATE OR REPLACE VIEW` on a view that is `security_invoker = on` MUST be
followed, in the same transaction, by an explicit re-`ALTER VIEW ... SET
(security_invoker = on)`.**

Grants survive `CREATE OR REPLACE VIEW`. The `security_invoker` reloption does not —
it silently reverts to off, and the view goes back to running as its owner, bypassing
RLS on every base relation.

Verified live 2026-08-29 in a rolled-back transaction against the already-flipped
`v_circle_feed`: `reloptions` came back empty immediately after the replace.

```sql
BEGIN;
CREATE OR REPLACE VIEW public.some_view AS SELECT ...;
SELECT coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
                 WHERE option_name='security_invoker'), 'RESET_TO_OFF')
FROM pg_class WHERE relname='some_view';   -- measured: RESET_TO_OFF
ROLLBACK;
```

There is no error and no warning. A migration that edits a flipped view's body and
omits the re-`ALTER` reopens whatever leak the flip closed, and every leak-closure
verification that only checks row counts for a legitimate caller will still pass.
So, per 6b, the migration must also assert the flag itself:

```sql
-- expect: 'true'
SELECT coalesce((SELECT option_value FROM pg_options_to_table(reloptions)
                 WHERE option_name='security_invoker'), 'false')
FROM pg_class WHERE relname='some_view';
```

Caught by backend-owner in `kan56b_v_circle_feed_members_count_fix.sql` before it
shipped; independently re-verified by cto under G-002. Had it been missed, the fix for
a display bug would have re-opened the KAN-56 anon leak.

**The same trap applies to functions.** `CREATE OR REPLACE FUNCTION` that omits
`SECURITY DEFINER` resets `prosecdef` to `false`, exactly as the view form resets
`security_invoker` — silently, with no error. Any migration that edits the body of a
definer function MUST restate `SECURITY DEFINER` and its `SET` clauses in full, and
assert them per 6b:

```sql
-- expect: prosecdef = true, proconfig contains search_path and row_security
SELECT prosecdef, proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'some_function';
```

This also constrains ordering: if two unapplied migrations both `CREATE OR REPLACE` the
same function, the one that does *not* carry the elevation must not sort last. See
`T-044` (`find_slots`), where an unapplied KAN-74 file and the KAN-104 elevation touch
the same body.

### 6d. A `SECURITY DEFINER` function in `public` is a public API endpoint

**Every new `SECURITY DEFINER` function in `public` MUST either authorize internally
or be `REVOKE EXECUTE ... FROM PUBLIC` in the same migration that creates it.**

PostgREST exposes every function in `public` as an RPC, and Postgres grants EXECUTE to
`PUBLIC` by default. A definer function therefore runs with the owner's privileges, for
any anonymous caller, bypassing whatever RLS gates the same data elsewhere. "Internal
helper" is not a property the database knows about.

**Never read an ACL by eye to answer this.** Supabase's default privileges produce ACLs
that look explicit while a `=X` PUBLIC grant does the real work:

```
{=X/postgres, postgres=X/postgres, service_role=X/postgres}   -- anon CAN execute
```

Ask Postgres instead:

```sql
SELECT p.oid::regprocedure::text,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = '<name>';
```

Two ways to close it, and the choice is not free:

1. **Authorize inside the function** — return NULL (or an empty set) unless the caller
   owns the row, is a member, or the row is public. Mirror the table's own RLS
   predicate, using `auth.uid()` → `profiles`, never the legacy
   `request.jwt.claim.*` GUC (§6c's sibling trap; see KAN-56).
2. **`REVOKE EXECUTE ... FROM PUBLIC`** — correct for functions only a server-side
   caller should reach. Revoking from `anon`/`authenticated` alone does nothing while
   the PUBLIC grant stands.

**Option 2 is unsafe when a `security_invoker` view calls the function**, because the
view calls it *as the caller*: the revoke does not degrade to NULL, it raises
`42501 permission denied` and the whole view dies for every legitimate user. Measured
on `circle_member_count` (KAN-77). When a view depends on the function, use option 1.

Established by KAN-77 and KAN-80, after `create_seed_user` was found anon-callable in
production.

### 6e. A guard added later does not protect the rows that predate it

**When a control's protection depends on *when* it was installed, count the rows that
predate it. Never reason from the guard's existence to the data's safety.**

Reading a `BEFORE INSERT` trigger tells you what happens to rows written from now on.
It tells you nothing about rows already on disk. The same applies to a `NOT VALID`
constraint, a column default, and an RLS policy added to an already-populated table.

Worked example, 2026-08-29 (KAN-78). `auth.users` carries `trg_strip_signup_password`,
which unconditionally nulls `encrypted_password` on insert. Reading it, cto concluded
that a seed helper writing a hardcoded password was harmless. It was not: the trigger
was installed 2026-06-24, the seed rows were written 2026-04-29 to 05-04, and **55
accounts still carried a working password hash** — all email-confirmed, none banned,
52 with guessable addresses. A real credential path, missed by verifying the mechanism
instead of the data.

Verify against the rows, not the guard:

```sql
-- the guard exists and is enabled — necessary, not sufficient
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = '<trigger>';

-- what the rows actually contain, which is the question
SELECT count(*) FROM <table> WHERE <the condition the guard is meant to prevent>;
```

**The tell to watch for.** `enforce_passwordless_signup`'s own migration note says the
trigger "fires only on INSERT, so existing users and the Settings set-password flow (an
UPDATE) are unaffected." That sentence was written as reassurance and read as one for
eight weeks. It is in fact a precise description of the hole. When a guard documents its
own blind spot, that line is the finding — not the comfort.

The general form: **mechanism-verified is not observation-verified.** Both are
required, and only the second one is evidence about production. This is the same
failure shape as §6b's rule that a migration asserts its expected values rather than
merely querying them — and the remedy is the same: make the check *executable*. A
commented-out count relies on an operator reading it; a `RAISE EXCEPTION` on an
unexpected count means the migration refuses to run against drifted state.

### 6f. A table created outside a migration gets an explicit `REVOKE` before it carries data

*Renumbered from a second `6c` on 2026-09-07 by `cto`. Two sections carried that number, which
made every `§6c` citation ambiguous. All eight existing citations — six in `DECISIONS.md`, two
inside this file — refer to the `CREATE OR REPLACE VIEW` trap above, so that section keeps `6c`
and this one moved. No citation needs updating.*

*Convention requested by `cto` and written here 2026-09-01; backed as `T-045`.*

`public` carries **two** `ALTER DEFAULT PRIVILEGES` rules that auto-grant `anon` the full write
set on every new relation. They are not equally fixable, and the split decides the convention:

| Grantor | `ALTER DEFAULT PRIVILEGES FOR ROLE …` | Covers |
|---|---|---|
| `postgres` | **WILL RUN** — `pg_has_role(postgres,'postgres','MEMBER') = true` | **Every table any agent creates**, because our migrations run as `postgres` |
| `supabase_admin` | **WILL FAIL** — no membership, not superuser (`T-025`, `T-045`) | Dashboard table editor, extensions, some CLI paths |

**So the fix is not "per-table `REVOKE` across 184 forever."** One migration against the
`postgres` rule closes the default permanently for the agent-authored path, which is nearly
everything. What it cannot reach is the human path.

**The convention, which is the only thing that covers the gap:**

> **A table created outside a migration — dashboard table editor, extension, CLI — must get an
> explicit `REVOKE ALL ON <table> FROM anon, authenticated;` before it carries data.**

**And the only thing that will actually catch a violation is the catalogue test** (`T-002`),
which must assert that no table in `public` carries an `anon` write grant it was not explicitly
given. A convention nobody can verify is a preference.

**Explicitly rejected, so nobody attempts it:** a single migration scoped against both grantors.
Half of it cannot execute, and per `T-031` a migration that fails partway through a privilege
change is worse than one never written — it leaves the schema in a state no file describes.

**Current standing risk, for context rather than alarm:** 184 of 185 tables carry an `anon`
write grant; 183 are held by RLS alone and `spatial_ref_sys` has no RLS (PostGIS). **No write
policy admits an anonymous caller, so nothing is exploitable today.** The grant is the standing
risk and RLS is the only thing between it and an incident — which is why the default matters
more than any individual table does.

### 6g. `CREATE OR REPLACE FUNCTION` is a whole-body replacement — author it from the live catalogue

*Written 2026-09-07 by `cto`. The rule existed only in `T-058`, `T-052`'s amendment and
individual ticket ACs, so every ticket re-derived it and one citation drifted to §6c — which is
the **view** case and only ever the analogue. This is the direct statement; cite this.*

**Take the body from `pg_get_functiondef('public.fn(argtypes)'::regprocedure)` read from the
database, and edit that. Never from the baseline dump, never from the migration file that last
defined it.**

`CREATE OR REPLACE FUNCTION` replaces the **entire** body and **every** attribute. Anything the
new text does not restate is not patched — it is dropped, silently, with no error at apply time:

| Attribute | If the replacement omits it |
|---|---|
| `SECURITY DEFINER` | `prosecdef` reverts to `false` (`T-044`) — the inverse also bites: an unintended `SECURITY DEFINER` turns an invoker function into a public API endpoint (§6d) |
| `SET search_path` | the setting is lost; the function resolves names against the caller's path |
| `STABLE` / `IMMUTABLE` | **silently becomes `VOLATILE`** — see the trap below |
| Body edits made by an earlier migration | reverted wholesale. This is how `T-052`'s amendment describes `KAN-131` reverting `KAN-128`'s `ON CONFLICT DO NOTHING` on all three inserts while the unique constraint stayed — turning an absorbed webhook replay into a 500 the provider retries forever |

So a migration that edits a function must state, in its header, that the body was taken from the
live catalogue, and must assert the preserved attributes afterwards per §6b — not just the
behaviour it changed.

**The non-obvious half: preserving attributes verbatim means preserving an *absence*.**
`pg_get_functiondef` emits **no volatility keyword for a `VOLATILE` function**, because `VOLATILE`
is the default. The keyword is present only for `STABLE` and `IMMUTABLE`. Two functions edited
side by side will therefore *look* inconsistent when they are correct:

```
calculate_notification_score   provolatile = 'v'   -- def emits NO volatility keyword
should_bypass_quiet_hours      provolatile = 's'   -- def emits "STABLE"
```

Both measured live 2026-09-07. "Tidying" the first to match the second reads as consistency and
is a **silent behavioural change** — it would let the planner cache a function that must be
re-evaluated per row. Do not add a keyword the live definition did not emit, and do not remove
one it did. If you need to know the truth rather than infer it from the text, read `provolatile`
directly: `v` = VOLATILE, `s` = STABLE, `i` = IMMUTABLE.

**Verify after applying**, per §6b:

```sql
SELECT prosecdef, provolatile, proconfig
FROM pg_proc WHERE oid = 'public.your_fn(uuid,text)'::regprocedure;
-- expect: exactly what it was before, except the one thing you meant to change
```

Found by `backend-4` while checking whether its own citations survived a §6c renumber — the
citation was wrong, and the reason it was wrong was that this section did not exist.

---

## 7. CODE GENERATION

Run `dart run build_runner build -d` after changing:
- any Freezed model (`@freezed`)
- any `@JsonSerializable`
- any Riverpod generator annotation
- any `@GenerateMocks` in a test

Watch mode: `dart run build_runner watch -d`.

**Never hand-edit** `*.g.dart`, `*.freezed.dart`, or `lib/l10n/app_localizations*.dart`.
They are regenerated and your edit will vanish. They are also excluded from every
convention count in this file.

---

## 8. FILE SIZE

**Target: 500 lines.** This is guidance with a target, not a rule of engagement
(`PROJECT_STATE.md` ARCH-01) — 140
non-generated files currently exceed it and no mechanism enforces it (`MANIFESTO.md` §1).

- **New files stay under 500 lines.**
- When an existing file crosses the line while you are legitimately in it, split the part
  you are working on — extract a widget, a controller, a mapper. Do not undertake to split
  the whole file.
- The five worst are `post_composer_screen.dart` (2,996), `profile_edit_screen.dart`
  (2,914), `social_search_screen.dart` (2,892), `post_detail_screen.dart` (2,304),
  `sports_screen.dart` (2,303). Splitting those is scheduled work with its own owner, not
  something to attempt in passing.

---

## 9. GIT

- Branches: `Canary` (working, capital C) and `main` (production). Feature branches off
  `Canary`, named `feat/<slice>-<short-description>` or `fix/<slice>-<short-description>`.
- **Conventional commits:** `type(scope): summary` — `feat`, `fix`, `refactor`, `chore`,
  `docs`, `security`. Scope is the slice name. Example:
  `fix(notifications): repair server-triggered push (was 401)`.
- **Only version-control runs write git commands** (`CONTRACT.md` §3).
- **Never push `main`.** PR from `Canary` only.
- **No `Co-Authored-By` trailer** unless `.claude/settings.json` sets `attribution.commit`.
- Never commit: `.env`, secrets, credentials, `node_modules/`, build output, `.mcp.json`.
- **Stage by explicit path — never `git add -A`, `git add .`, or `git commit -a`**, and read
  `git status --short` before every commit. The tree is shared by every seat; the full rule
  and why the failure is silent are in **§12i**.

---

## 10. TESTING

- Tests live under `test/`, **mirroring the source path**:
  `lib/features/games/domain/usecases/join_game_usecase.dart` →
  `test/features/games/domain/usecases/join_game_usecase_test.dart`.
- Mocks: `@GenerateMocks([MyRepository])`, then `dart run build_runner build -d`.
  `mockito ^5.4.4` is already a dev dependency.
- **Test reachable code** (`PROJECT_STATE.md` TEST-01, TEST-02). All 66 current tests pass
  and every one targets a stack no route
  reaches — a green suite that protects nothing. Before writing a test, confirm a route
  reaches the code under test.
- An agent may add tests for code it owns. **Nobody deletes another owner's test.**
- Run `flutter test` before reporting a task complete.

## 11. CI LINT POLICY

Decided under `KAN-112` (`DECISIONS.md` `T-042` follow-up), 2026-09-01.

- **`flutter analyze` warnings are fatal in CI.** `ci.yml`'s Analyze step fails the build on
  any warning (`unused_local_variable`, `unused_field`, `unused_element`,
  `dead_null_aware_expression`, `dead_code`, `unreachable_switch_case`,
  `unused_result`, etc.). Fix these in code before pushing to `Canary` — don't
  suppress them in `analysis_options.yaml`.
- **`flutter analyze` infos are advisory, not fatal, in CI.** `ci.yml` runs
  `flutter analyze --no-fatal-infos`. Infos (`avoid_print`, `deprecated_member_use`,
  `empty_catches`, `use_build_context_synchronously`, `type_literal_in_constant_pattern`,
  `unintended_html_in_doc_comment`, `collection_methods_unrelated_type`) are real findings
  worth fixing opportunistically when touching a file, but at ~56 pre-existing infos across
  the app (mostly `avoid_print` in early-stage services), fixing them all in one pass is a
  much larger, lower-value task than clearing the warnings was. This is a pragmatic call,
  not a claim that they don't matter — an agent touching a file with infos in it should
  still clean up what's local to that file.
- If a specific lint rule needs a permanent, deliberate waiver, waive it **per-rule with a
  comment explaining why** in `analysis_options.yaml`. Do not add a blanket `errors: ignore`
  block — that hid this exact gate's failures from KAN-72 to KAN-112.

---

## 12. TRAPS THAT MAKE A CORRECT MEASUREMENT WRONG

Owed by `DECISIONS.md` `T-064` and `T-065`. Each entry is a case where a number or a
check was **right when taken and wrong when read**. None of them is caught by review.

### 12a. A predicate that excludes rows by NULL comparison is not an authorization check

**Rule.** Where a filter's security effect depends on an argument being NULL, the
authorization must be stated **separately and explicitly**, so that making the filter
null-safe cannot open the data.

`public.rpc_potential_vibes` filters `spw.user_id <> p_me`, and the 6-argument wrapper
injects `auth.uid()` as `p_me`. For `anon`, `p_me` is NULL, the comparison is NULL, and
`v_potential_vibes_default` returns zero rows. That zero is a **self-exclusion clause
doing accidental duty as a gate**. The natural null-safe repair — `p_me IS NULL OR
spw.user_id <> p_me` — hands `anon` every row of `v_sport_profiles_with_user`.

**Do not "tidy" this predicate.** Verified still present in prod 2026-09-07 (`cto`,
read-only, via `pg_get_functiondef`).

### 12b. Concurrent seats do not share a working tree — and `git stash` is the sharpest edge

Full standard in `DECISIONS.md` `T-065`. In this file, the operational form:

- **A seat that writes files, or that takes a measurement it will quote, holds an
  isolated tree.** `flutter analyze` and `flutter test` read the *working tree*, so a
  measurement taken across another seat's in-flight edits describes a tree nobody will
  ever see — and the report reads exactly like a correct one.
- **`git stash`, `git stash -u`, `git checkout`, `git reset` and `git clean` are
  forbidden in the shared `dabbler-code` checkout.** All five are repo-global: they act
  on every other seat's uncommitted work, not just yours. `-u` additionally sweeps
  untracked files, which are the ones no other seat can recover from reflog. A seat that
  needs a clean tree to measure against **must not create one by clearing the shared
  one**.
- **The sanctioned way to take a clean-tree measurement:** measure in an isolated tree
  and quote the sha (mechanism referred to `devops` under `T-065`); or, with no
  isolation, **do not clean the tree — quote the sha and state that the tree was dirty**,
  which makes the caveat visible instead of destroying someone's work to hide it.
- **Read-only seats may share the tree.** Reading races nothing.
- **The one path-scoped carve-out.** The `checkout`/`reset`/`clean` ban above is aimed at the
  **repo-global** forms — `git checkout <branch>`, `git checkout .`, `git reset`, `git clean`,
  `git stash` — every one of which acts on files you did not name. **`git restore -- <path>`
  (equivalently `git checkout -- <path>`) naming an explicit path you authored is permitted**,
  because its blast radius is exactly that path. Two conditions, both required: you wrote the
  hunk, and you name the file — never `.`, never a directory, never a glob.
- **Before discarding anything, run `git status --short` and read every line.** A tree with
  several dirty files is usually several seats' work, or one coherent unlanded change set.
  Discarding a file because it is *premature* rather than *wrong* destroys authored work that
  someone must then redo. **Unlanded is not the same as incorrect**: an uncommitted edit
  asserts nothing to anyone, so the fix for "this must not land yet" is to leave it alone and
  commit the set together — not to discard half of it now and rewrite it later.
- `git commit -o <path>` is a partial workaround, not the fix: it protects the committing
  seat's own file and stops nothing else.

### 12c. Every quoted measurement carries the sha it was taken at

Cheap, immediate, and it works with no isolation at all — it converts a silent error into
a detectable one. A `flutter test` count with no sha attached is a claim the reporter
cannot support.

### 12d. Where a constraint can hold an invariant, the constraint holds it and the function asserts it

**Never the reverse.** Owed by `T-049` Decision 3 and `T-061`.

A check inside a function body lives in the thing that the next `CREATE OR REPLACE` replaces
whole (§6c, `T-044`) — which is how `trgfn_payment_to_ledger` acquired its defects. A
constraint survives every rewrite of every function that touches the table.

- `EXISTS` is not idempotency; a `UNIQUE` constraint plus `ON CONFLICT` is (`T-049`).
- A defensive `IF … IS NULL THEN RAISE` is not referential integrity; a `FOREIGN KEY` is
  (`T-061`).
- The assertion still belongs in the function, stated so it cannot be mistaken for the
  mechanism. `SELECT … INTO STRICT` does it in one keyword:

```sql
SELECT vs.venue_id INTO STRICT v_venue_id
FROM public.venue_bookings vb
JOIN public.venue_spaces vs ON vs.id = vb.venue_space_id
WHERE vb.id = NEW.booking_id;
```

**An `INTO STRICT` written before its constraint exists asserts a guarantee nothing
provides.** That is why `KAN-140` must not land before `KAN-145`.

### 12e. A comment saying it is done is not it being done — and quoting one propagates the lie

**Rule.** A Jira comment describing an edit is **evidence of intent, never of state**. Before
asserting what a ticket says, read the **field** — the description, the status, the `due_date` —
not a comment's account of it. When you quote board state, name which field you read.

**Two measured instances, two seats, 2026-09-06/07.** `po` caught itself on `KAN-130`
(comment 10659 said "corrected"; the description edit was never called). `KAN-140` comment
10649 is headed *"AC addition per `T-061`"* and contains a numbered `6.` and `7.` — **and the
description still held ACs 1–5.** The proposed ACs were never applied.

**The second-order failure is the expensive one.** `cto` read 10649, quoted it to `team-lead`
as "AC6 and AC7 were added at 20:11", and `team-lead` relayed it to `po` — a claim about board
state that nobody had opened the board to check, inside a message whose purpose was to correct
*someone else's* stale ticket text. It was caught only because `po` re-read the live ticket
instead of taking the relay. **A comment is a claim by its author about their own work**, which
is the one category of evidence this repo already distrusts everywhere else (§12c, `T-055`).

**Writing side:** if you intend an AC to bind, **edit the description field**. Post the comment
as the audit trail *after* the edit lands, and say which field you changed.

### 12f. A term can go stale inside a document that is still live — and the quotation stays correct

**Rule.** When a quoted rule names a **role**, check that the word still denotes what it denoted
when the rule was written. A verbatim quote from a current decision can route work to the wrong
seat, and nothing about the quote looks wrong.

**The measured case.** `G-002` condition 3 (2026-08-28) says a user-data migration *"requires the
**PO** to apply it personally"*, and `019` (2026-08-27) says *"only the **PO** can authorise a
production write."* Both are ACTIVE, both are quoted accurately — and in both, "the PO" means the
**human decision-maker**, written before `po` existed as an agent seat. `CONTRACT.md:242` is the
same rule in current vocabulary: *"User-data mutation is **CEO-only** (`019`)."*

**What it costs.** On 2026-09-07 `cto` quoted `G-002` condition 3 correctly and routed `KAN-155`'s
apply — an `UPDATE` against 82 live `user_subscriptions` rows — to `po`, a seat with no such
authority, which would have had to refuse it. `team-lead-4` caught it by reading `019` and
`CONTRACT.md:242` rather than carrying the quote.

**How to apply.** `CONTRACT.md` is the translation layer: where a decision's body and a
`CONTRACT.md` row disagree on **who**, the row governs and the body is the older vocabulary. This
is the sibling of §12e — there, a comment claimed a state it did not have; here, a live rule uses
a word that no longer means what it says. **Both fail by being accurate.**

**Not fixed at the source deliberately:** `019`/`G-002` are never edited — a decision is
superseded, not rewritten (`DECISIONS.md` preamble), and role custody is off the seats a rule
binds (`G-022`). So this trap is permanent and the check is the only defence.

### 12g. Retiring a value is safe where it is compared, dangerous where it is a fallback default

*Written 2026-09-07 by `cto`, from the `KAN-155` review. The plan-key set will change again;
this is the check to run when it does.*

**Before deleting a value that functions reference by literal — a plan key, a role name, a
status — sweep for it, then classify every hit by how it is used. Two shapes, one risk:**

| Shape | Behaviour once the value no longer exists |
|---|---|
| **Compared against** — `IF v_plan = 'prime' THEN … RETURN true; END IF; RETURN false;` | **Safe.** The comparison stops matching and the function **fails closed**. The branch goes dead; nothing is granted. |
| **Assigned as a fallback default**, feeding a lookup that **fails open** — `v_plan := 'kickoff';` then `IF v_cap IS NULL THEN RETURN true;` | **Dangerous.** The fallback points at a row that no longer exists, the lookup misses, and the fail-open branch **grants**. |

`KAN-155` retired `kickoff`/`pro`/`prime`. Three functions named a retired key.
`should_bypass_quiet_hours` and `calculate_notification_score` compare, and were never at risk.
`can_send_notification_now` **assigns** `'kickoff'` as its no-active-subscription fallback and
returns `true` when it finds no cap row — so deleting the key would have granted **unlimited
notifications to every user without an active subscription**. That fix had to land in the same
transaction as the delete, and it did.

**The rule this yields:** a literal in a comparison and the same literal in an assignment are
different risk classes, and the grep that finds them cannot tell them apart. **Read every hit;
classify by shape, not by count.** A sweep that reports "three functions reference the key" has
not answered the question — one of those three was the whole risk.

**And sweep wide, then read.** The same `KAN-155` sweep returned `posts_mapping_check`, which
matched on `'kickoff_at'` — a **column name** on `posts`, unrelated to plans. Both failure modes
were live: reporting it would have added a spurious object to a hand-applied production
migration, and narrowing the pattern to dodge it could have hidden a real hit. The discipline is
a wide sweep across every surface a literal can hide in — function bodies, view definitions,
CHECK constraints, column defaults, RLS `USING`/`WITH CHECK`, trigger definitions — followed by
reading each hit. Not a cleverer pattern.

### 12h. A probe can fail to reach the code under test **without raising** — the silent form of the `T-055` trap

*Written 2026-09-07 by `cto`, from a variant `team-lead-4` and `backend-4` found. `T-055`'s
falsifiability condition 3 — "the target path must be shown to execute before falsifiability is
checked" — was written against a path that **raises**. This is the form that does not.*

**A before/after probe that reads "identical on both sides" has two possible causes, and they
are indistinguishable from the result alone: the change did nothing, or the probe never reached
the code the change touched.** Condition 3 catches the loud version — `settle_game` raising
`42804` before the insert under test (`T-058` Decision 2). It does not catch this one:

```sql
SELECT * INTO v_rule FROM public.notification_scores WHERE kind_key = p_kind_key AND is_enabled;
IF NOT FOUND THEN
    RETURN 1;          -- plausible value, no error, probe never reaches the rest
END IF;
```

`calculate_notification_score` has exactly this shape. Against an empty or non-matching
`notification_scores`, it returns `1` — a number that looks like a result — and every line below
the guard is unreached. A probe comparing the return value before and after a change to those
lines sees `1` and `1`, and **reports a pass**. Nothing raises. Nothing is logged.

**So condition 3 is strengthened, and the stronger form is the one to apply:**

> Show that the probe reaches **the specific statements the change modifies** — not merely that
> the function executes without error.

**How to satisfy it.** Pick whichever fits the path:

- Assert the guard's precondition explicitly before probing — the lookup row exists, the count is
  non-zero, the status is the one the branch requires — and fail the probe if it does not.
- Make the pre-change side produce a **distinguishable wrong answer**, not merely a different
  one. `backend-4`'s `KAN-145` probe is the model: a named `RAISE` (`PROBE_RESULT=
  INSERT_SUCCEEDED_NO_FK`) proves the insert was actually attempted and actually succeeded, so
  the post-change `23503` means the constraint acted rather than the path having gone missing.
- Where the early return is the whole risk, probe the guard itself as its own case.

**The general rule, and it outlives this instance:** an assertion that something is *unchanged*
proves nothing unless you have separately established that the thing was *reached*. Empty tables
and unmatched lookups are the usual reason it was not — and this codebase is full of both, since
most feature tables hold zero rows.

### 12i. In a shared tree, `git add -A` commits other seats' work under your name

*Written 2026-09-07 by `cto`, from a near-miss `backend-4` found and `team-lead-4` routed.
`12b` bans the repo-global commands that **destroy** another seat's uncommitted work. This is
the other half: the repo-global command that **absorbs** it. Nothing in `12b` catches it,
because nothing is destroyed — the work is committed, just not by its author and not with its
message.*

**The property.** Every seat writing to `dabbler-code` shares **one working tree**. Verified
2026-09-07 by `cto`: `git worktree list` returns the single checkout at
`/Users/moatazmustapha/Desktop/Thebes/Dabbler/dabbler-code` (plus one unrelated `prunable`
scratchpad), and `git rev-parse --git-common-dir` returns `.git`. **The same holds for
`dabbler-admin`, `dabbler-design-system`, `dabbler-docs` and `dabbler-web`** — each is a single
tree, measured the same way, the same day. The rule below is written for `dabbler-code` because
that is where sixteen developer seats plus `cto`, `devops` and `po` all write, but it is a
property of every Dabbler repo, not of this one.

**The rule.** **Stage by explicit path. Never `git add -A`, never `git add .`, never
`git commit -a`.** All three stage by *tree state*, not by authorship — they cannot distinguish
your edit from the edit another seat made ninety seconds ago. `git add <path>` and
`git commit -o <path>` name what you wrote; use those.

**And read `git status --short` before every commit.** Not as a formality — as the check. An
`M` you did not expect is far more likely to be another seat's live work than a stray of your
own, and in a shared tree that is the normal case rather than the surprising one.

**Why this needs its own rule rather than ordinary care.** The failure is **silent and
asymmetric**, and no error is raised anywhere in the chain:

- **The sweeping seat sees a clean, plausible commit.** `git status` goes empty, the diff
  contains its own work, the push succeeds. There is no signal that the commit is wrong.
- **The swept seat sees its changes gone from `git status`** and has no reason to look in
  another seat's commit for them. The likely response is to redo work that already exists —
  and the loss may not be noticed at all.
- **The history is wrong in a way review does not catch.** A migration commit that also
  carries someone else's `docs/` edits reads as a single authored change under a message that
  describes only part of it. `git blame` then attributes those lines to the wrong seat, and
  the real author's reasoning is nowhere.

**The near-miss this comes from.** On 2026-09-07, `backend-4` audited its own seven commits
and found that for several of them `docs/SCHEMA.md` and `docs/CONVENTIONS.md` were sitting `M`
in the shared tree — `cto`'s in-flight §8a/§6g/§12g work — while it was committing migration
files. It had used `git add <path>` every time. **Nothing was swept, and nothing was swept by
habit rather than by rule.** A single `-A` would have folded three of this document's sections
into a migration commit under another seat's name. That is the gap this entry closes.

**The relationship to `12b`, stated once so neither is read alone.** `12b` governs commands
that act on files you did not name and **remove** work: `stash`, `checkout`, `reset`, `clean`.
This governs commands that act on files you did not name and **claim** work: `add -A`,
`add .`, `commit -a`. Same root cause — a repo-global operation in a shared tree — and the two
opposite consequences. `12b`'s carve-out logic applies here unchanged: **name the path, and
only for hunks you authored.**

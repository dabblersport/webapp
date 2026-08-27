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
- Edge functions live in `supabase/functions/<name>/index.ts`, called via
  `supabase.functions.invoke('name', body: {...})`.

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

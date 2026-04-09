# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Dabbler** is a Flutter social gaming platform for discovering, joining, and organizing sporting events. Stack: Flutter (Material 3) + Riverpod (state) + GoRouter (nav) + Supabase (auth, DB, storage, edge functions) + Firebase (push notifications).

## Commands

```bash
# Run the app
flutter run

# Build
flutter build ios
flutter build apk

# Analyze / lint
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/features/auth/auth_test.dart

# Code generation (required after modifying Freezed models or Riverpod generators)
dart run build_runner build -d

# Watch mode for code generation
dart run build_runner watch -d
```

## Architecture

### Directory Structure

```
lib/
  app/           # AppRouter (GoRouter), app-level setup
  core/          # Cross-cutting: config, design system, FP primitives, utils, services
  data/          # Models (Freezed), repositories (interface + _impl), mappers
  features/      # Feature-sliced domain logic
  providers.dart # Central export hub for all Riverpod providers
  main.dart      # Entry point: Supabase init, Firebase init, ProviderScope
```

### Feature Slice Layout

Each feature under `lib/features/<domain>/` follows:
```
presentation/
  screens/       # UI screens (ConsumerWidget/ConsumerStatefulWidget)
  widgets/       # Feature-specific widgets
  controllers/   # AsyncNotifier / StateNotifier
  providers/     # Feature-scoped providers
domain/
  models/        # Domain models (may differ from data models)
```

### Data Flow

1. **Repository** (`lib/data/repositories/`) wraps Supabase calls, returns `Result<T, Failure>`.
2. **Provider** exposes repository or controller via Riverpod.
3. **Controller** (AsyncNotifier) calls repository, maps results to UI state.
4. **Screen** watches providers with `ref.watch(...)`.

**Never throw exceptions in UI-facing code.** All async operations use `Result.guard`:
```dart
return Result.guard(
  () async => await supabase.from('table').select(),
  (e) => Failure.from(e),
);
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/app/app_router.dart` | All routes, `_handleRedirect` for auth/onboarding/feature-flag gating |
| `lib/providers.dart` | Central re-export of all providers — add new providers here |
| `lib/core/config/feature_flags.dart` | Feature flag definitions — gate new features here |
| `lib/core/config/environment.dart` | Env config loaded from `.env` |
| `lib/core/fp/result.dart` | `Result<T,E>`, `Ok`, `Err`, `Unit` — the FP error-handling primitives |
| `lib/core/errors/` | `Failure` type hierarchy |

### Navigation

- Router defined in `lib/app/app_router.dart`.
- Route constants: `RoutePaths` and `RouteNames` from `lib/utils/constants/route_constants.dart`.
- **Always** use transition wrappers from `lib/utils/transitions/page_transitions.dart` (`FadeTransitionPage`, `SlideTransitionPage`, `SharedAxisTransitionPage`, `BottomSheetTransitionPage`). Never use raw `MaterialPage`.
- Redirect logic is centralized in `_handleRedirect` — handles auth state, onboarding completion, and feature flag gating.

### State Management

- Riverpod 2.x throughout. All providers exported from `lib/providers.dart`.
- In widgets: `ref.watch(provider)`.
- In router (no BuildContext): `ProviderScope.containerOf(context, listen: false).read(provider)`.

### Design System

- Standard screen layout: `TwoSectionLayout` (purple top / dark bottom).
- Theme: Material 3 via `AppTheme`. Colors via `Theme.of(context).colorScheme`. **Never hardcode colors.**
- Domain color extensions: `colorScheme.categoryMain`, `colorScheme.categorySocial`, etc.
- Components: `AppButton.primary/secondary/ghost`, `AppCard`, `AppButtonCard`, `AppActionCard`, `CustomInputField`.
- Spacing: 4dp grid system.
- Icons: Lucide (`lucide_icons`) and Iconsax (`iconsax_flutter`).

### Data Models

- All models are Freezed classes with `@JsonSerializable`. Run `dart run build_runner build -d` after changes.
- Pattern: define model → implement repository returning `Result<T, Failure>` → expose via provider → consume in controller/UI.

### Supabase

- Access via `Supabase.instance.client`.
- Trust RLS for authorization — keep queries minimal, no client-side auth checks.
- Schema reference: `supabase/schema/schema.json`.

## Do / Avoid

- **Do** use `Result<T, Failure>` for all data operations — never throw across layer boundaries.
- **Do** export new providers from `lib/providers.dart`.
- **Do** gate new routes/features with `FeatureFlags.<name>`.
- **Do** use `TwoSectionLayout` for standard screens.
- **Avoid** hardcoded colors — use `ColorScheme` or `AppTheme` extensions.
- **Avoid** raw `MaterialPage` — use transition wrappers.
- **Avoid** throwing exceptions from repositories.

## Onebrain Agent Team

### Agent Roles
- **Tech Lead**: Reads this file, breaks features into tasks, coordinates all agents
- **Flutter UI Agent**: Handles Task A — screens, widgets, animations, design system
- **Backend/Supabase Agent**: Handles Task B — DB tables, RLS policies, edge functions, auth
- **Integration Agent**: Handles Task C — wiring Flutter to Supabase, offline logic, app-level gaps
- **QA/Reviewer Agent**: Reviews all diffs, writes tests, flags security and performance issues
- **DevOps Agent**: Handles deployments, CI/CD config, release notes

### Task Classification
- **Task A (UI)**: Screens, layouts, widgets, animations, design system implementation
- **Task B (Logic)**: Database schema, business rules, Supabase functions, RLS policies
- **Task C (Integration)**: Connecting UI to backend, offline handling, end-to-end flows

### Rules
- Always read CLAUDE.md before starting any task
- Never hardcode API keys or secrets
- Every Task B must have RLS policies defined
- Every Task A must follow the existing design system in lib/core/theme
- Task C only starts after Task A and Task B are complete

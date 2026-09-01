---
name: kan30-boundary-correction-2026-08-31
description: KAN-30's clean-architecture deletion scope is WRONG — only 501 of 8,208 LOC is dead; profile/data and parts of games/data are live. KAN-29 (rewards) is correct as scoped.
metadata:
  type: project
---

Re-verified 2026-08-31 by live import-BFS from `lib/main.dart` (820 dart files, 548 reachable, 272 unreachable), at the PO's precondition on the 2026-08-30 delete ruling.

**KAN-29 (rewards) — boundary CONFIRMED.** 32 of 36 files in `lib/features/rewards/` unreachable. The 4 check-in seeds are self-contained (transitive closure inside rewards = exactly those 4). Real LOC: 20,545 total, 691 kept (ticket said ~985). **Must also delete `lib/features/profile/presentation/widgets/profile_rewards_widget.dart` (352 LOC, zero importers)** — it instantiates `RewardsService()` at :35 and would fail `flutter analyze` otherwise.

**KAN-30 (clean-architecture stack) — boundary MOVED. Only 501 LOC / 6 files genuinely dead:**
`games/data/mappers/mappers.dart` (2), `games/domain/usecases/create_game_usecase.dart` (272), `profile/data/mappers/mappers.dart` (2), `profile/data/providers/profile_providers.dart` (13), `profile/data/repositories/profile_repository.dart` (140), `profile/data/repositories/profile_stats_repository.dart` (72).

The other ~7,700 LOC is LIVE:
- `auth_service.dart:357` calls `ProfileLocalDataSourceImpl().clearCache()` → `profile/data/datasources/profile_data_sources.dart`. Logout teardown (commit `775d62f`, KAN-58). Deleting breaks sign-out.
- `profile_providers.dart` builds `SupabaseProfileDataSource` (:65), `ProfileRepositoryImpl` (:73), `SettingsRepositoryImpl` (:188); `privacyControllerProvider` (:199) is watched by `privacy_settings_screen.dart`.
- Commit `f20973c` (KAN-27/28) deliberately consolidated settings ONTO `settings_repository_impl.dart` — deleting it reverts accepted work.
- `VenueDetailScreen` (routed, `app_router.dart:839`) uses `games_providers.venuesRepositoryProvider` at :929 → `games/data/repositories/venues_repository_impl.dart` → `venues_datasource.dart`.
- `GamesScreen` (routed, `app_router.dart:782`) → `nearby_games_provider.dart` → 3 files in `games/data`.

**Why:** KAN-30 was measured before KAN-27/28/58 landed, and it over-generalised — its "built on UnimplementedError" claim is true only of the two interface files that ARE dead (18 occurrences, all in `profile_repository.dart` + `profile_stats_repository.dart`); `profile_repository_impl.dart` has zero.

**How to apply:** never re-quote KAN-30's 5,674 / 2,534 LOC figures. The remaining work there is a *migration*, not a deletion. See [[reachability-method]] and [[confirmed-dead-code]].

**Open follow-up:** `SportsScreen` is imported by `app_router.dart:46` but never instantiated anywhere — import-reachable, UI-dead. Not yet ticketed.

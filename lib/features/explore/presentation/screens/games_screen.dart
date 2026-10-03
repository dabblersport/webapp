import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_bar.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/providers.dart' hide nearbyGamesProvider;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// =============================================================================
// SCREEN — outer shell; waits for country-filtered sport list
// =============================================================================

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only list challenge-eligible sports (sports.is_challenge_sport = true).
    final sportsAsync = ref.watch(activeChallengeSportsByProfileCountryProvider);

    return sportsAsync.when(
      loading: () => const ListingPageSpinner(),
      error: (_, __) => const DabblerPage(
        body: ListingError(message: 'Failed to load sports'),
      ),
      data: (sports) => _GamesTabScreen(
        key: ValueKey(sports.map((s) => s.id).join()),
        sports: sports,
      ),
    );
  }
}

// =============================================================================
// TAB SCREEN — recreated when the sport list changes
// =============================================================================

class _GamesTabScreen extends ConsumerStatefulWidget {
  const _GamesTabScreen({super.key, required this.sports});

  final List<Sport> sports;

  @override
  ConsumerState<_GamesTabScreen> createState() => _GamesTabScreenState();
}

class _GamesTabScreenState extends ConsumerState<_GamesTabScreen> {
  // Index 0 = "All", then one tab per sport
  late final List<ScrollController> _scrollControllers;

  int get _tabCount => widget.sports.length + 1; // +1 for "All"

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(_tabCount, (_) => ScrollController());
  }

  @override
  void dispose() {
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    super.dispose();
  }

  // index 0 → null (all sports), index N → sport id at N-1
  String? _sportIdForTab(int index) {
    if (index == 0) return null;
    return widget.sports[index - 1].id;
  }

  Future<void> _handleRefresh() async {
    // Invalidate every family member so both the "all games" and the
    // location-filtered variants refetch, plus the pinned "My games" section.
    ref.invalidate(nearbyGamesProvider);
    ref.invalidate(myPinnedGamesProvider);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _resetFilters() {
    ref.read(nearbyGamesFilterEnabledProvider.notifier).state = false;
    ref.read(gamesDateFilterProvider.notifier).state = GamesDateFilter.any;
    ref.read(gamesSkillFilterProvider.notifier).state = GamesSkillFilter.any;
    ref.read(gamesOpenSpotsOnlyProvider.notifier).state = false;
  }

  void _openFilters() {
    showListingFilterSheet(
      context,
      builder: (_) => _GamesFilterSheetBody(onReset: _resetFilters),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The header's count and the applied-filters rail both follow every filter
    // that narrows the list.
    final nearby = ref.watch(nearbyGamesFilterEnabledProvider);
    final dateFilter = ref.watch(gamesDateFilterProvider);
    final skillFilter = ref.watch(gamesSkillFilterProvider);
    final openSpots = ref.watch(gamesOpenSpotsOnlyProvider);

    final active = <ListingActiveFilter>[
      if (nearby)
        ListingActiveFilter(
          label: 'Nearby',
          onClear: () =>
              ref.read(nearbyGamesFilterEnabledProvider.notifier).state = false,
        ),
      if (dateFilter != GamesDateFilter.any)
        ListingActiveFilter(
          label: dateFilter.label,
          onClear: () => ref.read(gamesDateFilterProvider.notifier).state =
              GamesDateFilter.any,
        ),
      if (skillFilter != GamesSkillFilter.any)
        ListingActiveFilter(
          label: skillFilter.label,
          onClear: () => ref.read(gamesSkillFilterProvider.notifier).state =
              GamesSkillFilter.any,
        ),
      if (openSpots)
        ListingActiveFilter(
          label: 'Open spots',
          onClear: () =>
              ref.read(gamesOpenSpotsOnlyProvider.notifier).state = false,
        ),
    ];

    return DabblerPage(
      topBar: ListingHeader(
        title: AppLocalizations.of(context).nav_games,
        filterCount: active.length,
        onFilter: _openFilters,
      ),
      // The DS cards and tabs carry no screen gutter of their own.
      body: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
        ),
        child: DabblerTabPager(
          scrollable: true,
          items: <DabblerTabItem>[
            const DabblerTabItem(id: 'all', label: 'All'),
            for (final sport in widget.sports)
              DabblerTabItem(
                id: sport.id,
                label: sport.localizedName(context),
              ),
          ],
          pages: List.generate(
            _tabCount,
            // The applied-filters rail sits under the tabs, above each list.
            (i) => Column(
              children: [
                ListingActiveFilters(filters: active, onClearAll: _resetFilters),
                Expanded(
                  child: _GameTabBody(
                    sportId: _sportIdForTab(i),
                    scrollController: _scrollControllers[i],
                    onRefresh: _handleRefresh,
                    onRetry: () => ref.invalidate(nearbyGamesProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// FILTER SHEET
// =============================================================================

/// Date window, skill tier and open spots (the old inline chips), plus the
/// nearby control. Everything writes straight to its provider, as before.
class _GamesFilterSheetBody extends ConsumerWidget {
  const _GamesFilterSheetBody({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFilter = ref.watch(gamesDateFilterProvider);
    final skillFilter = ref.watch(gamesSkillFilterProvider);
    final openSpotsOnly = ref.watch(gamesOpenSpotsOnlyProvider);

    return ListingFilterBody(
      onReset: onReset,
      groups: [
        ListingFilterGroup(
          label: 'Date',
          children: [
            for (final f in GamesDateFilter.values)
              if (f != GamesDateFilter.any)
                DabblerChip(
                  label: f.label,
                  selected: f == dateFilter,
                  onTap: () => ref.read(gamesDateFilterProvider.notifier).state =
                      f == dateFilter ? GamesDateFilter.any : f,
                ),
          ],
        ),
        ListingFilterGroup(
          label: 'Skill level',
          children: [
            for (final f in GamesSkillFilter.values)
              if (f != GamesSkillFilter.any)
                DabblerChip(
                  label: f.label,
                  selected: f == skillFilter,
                  onTap: () => ref.read(gamesSkillFilterProvider.notifier).state =
                      f == skillFilter ? GamesSkillFilter.any : f,
                ),
          ],
        ),
        ListingFilterGroup(
          label: 'Availability',
          children: [
            DabblerChip(
              label: 'Open spots',
              selected: openSpotsOnly,
              onTap: () => ref.read(gamesOpenSpotsOnlyProvider.notifier).state =
                  !openSpotsOnly,
            ),
          ],
        ),
        // Not migrated yet (location slice): hosted on a transparent Material.
        ListingFilterSection(
          label: 'Nearby',
          child: ListingMaterialHost(
            child: NearbyFilterBar(
              enabledProvider: nearbyGamesFilterEnabledProvider,
              sortProvider: nearbyGameSortProvider,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// GAME TAB BODY
// =============================================================================

class _GameTabBody extends ConsumerWidget {
  const _GameTabBody({
    required this.sportId,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final String? sportId;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyEnabled = ref.watch(nearbyGamesFilterEnabledProvider);
    final locState =
        nearbyEnabled ? ref.watch(activeLocationProvider).valueOrNull : null;
    final location =
        locState is ActiveLocationReady ? locState.location : null;
    final sortOrder = ref.watch(nearbyGameSortProvider);

    // While the filter is on but location isn't ready yet (locating/denied),
    // fall back to the unfiltered list; NearbyFilterBar surfaces the status.
    final NearbyGamesParams params = (
      lat: location?.lat,
      lng: location?.lng,
      radiusMeters: location?.nearbyRadiusMeters,
      sportId: sportId,
      sortOrder: sortOrder,
    );

    final gamesAsync = ref.watch(nearbyGamesProvider(params));
    // Pinned section: the viewer's created/joined upcoming games,
    // independent of the location filter.
    final pinned = ref.watch(myPinnedGamesProvider(sportId)).valueOrNull ??
        const <NearbyGameModel>[];
    final isFiltered = location != null;

    return gamesAsync.when(
      loading: () => const ListingSkeleton(),
      error: (e, _) =>
          ListingError(message: "Couldn't load games", onRetry: onRetry),
      data: (games) {
        final pinnedIds = {for (final g in pinned) g.id};

        // List filters. Pinned "My games" stay visible — the filters narrow
        // discovery, not your own commitments.
        final dateFilter = ref.watch(gamesDateFilterProvider);
        final openSpotsOnly = ref.watch(gamesOpenSpotsOnlyProvider);
        final skillFilter = ref.watch(gamesSkillFilterProvider);
        final now = DateTime.now();
        final filtersActive = dateFilter != GamesDateFilter.any ||
            skillFilter != GamesSkillFilter.any ||
            openSpotsOnly;

        bool passes(NearbyGameModel g) {
          // Past/cancelled games never show here — history lives in
          // My Sports → History (sports_library_screen).
          if (g.status == 'ended' || g.status == 'cancelled') return false;
          if (openSpotsOnly && (g.spotsRemaining ?? 1) <= 0) return false;
          if (!skillFilter.matches(g.minSkill, g.maxSkill)) return false;
          return dateFilter.matches(g.scheduledAt, now);
        }

        final others = games
            .where((g) => !pinnedIds.contains(g.id))
            .where(passes)
            .toList();

        if (pinned.isEmpty && others.isEmpty) {
          if (filtersActive && games.isNotEmpty) {
            return const ListingEmpty(
              icon: 'game',
              title: 'No games match your filters',
              text: 'Adjust or clear the filters.',
            );
          }
          return ListingEmpty(
            icon: 'game',
            title: isFiltered ? 'No games nearby' : 'No games yet',
            text: isFiltered
                ? 'Try widening your search radius in the filter.'
                : 'Be the first to create a game in your area!',
          );
        }

        // Flat entry list: headers + cards share one ListView so scroll,
        // refresh, and separators stay unified.
        final entries = <_ListEntry>[
          if (pinned.isNotEmpty) ...[
            const _ListEntry.header('My games'),
            ...pinned.map(_ListEntry.game),
            if (others.isNotEmpty) const _ListEntry.header('All games'),
          ],
          ...others.map(_ListEntry.game),
        ];

        return DabblerRefresh(
          onRefresh: onRefresh,
          child: ListView.separated(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.only(
              top: DabblerSpacing.space4,
              bottom: DabblerSpacing.space8,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: DabblerSpacing.space4),
            itemBuilder: (_, i) {
              final entry = entries[i];
              if (entry.isHeader) {
                return Text(
                  entry.headerLabel!,
                  style: listingText(
                    context,
                    DabblerType.headline,
                    color: DabblerColors.of(context).textPrimary,
                  ),
                );
              }
              return _GameCard(
                game: entry.gameModel!,
                showDistance: isFiltered,
              );
            },
          ),
        );
      },
    );
  }
}

/// A row in the games list: either a section header or a game card.
class _ListEntry {
  const _ListEntry.header(String label)
      : headerLabel = label,
        gameModel = null;
  const _ListEntry.game(NearbyGameModel this.gameModel) : headerLabel = null;

  final String? headerLabel;
  final NearbyGameModel? gameModel;

  bool get isHeader => headerLabel != null;
}

// =============================================================================
// GAME CARD
// =============================================================================

/// A game on the design system's event card (the Listings frame draws a local
/// card; the DS card is canonical). Sport artwork stands in for a cover, the
/// footer carries the status, relation and spots badges.
class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, this.showDistance = false});

  final NearbyGameModel game;
  final bool showDistance;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);

    final venueLine = [
      if (game.venueName?.isNotEmpty == true) game.venueName!,
      if (showDistance && game.distanceMeters > 0) game.distanceLabel,
    ].join('  ·  ');

    final badges = <Widget>[
      if (game.isMine)
        DabblerBadge(
          label: game.isCreated ? 'Created' : 'Joined',
          tone: DabblerBadgeTone.defaultTone,
          status: game.isCreated
              ? null
              : colors.status(DabblerStatusTone.success),
        ),
      _statusBadge(colors, game.status),
      if (game.spotsRemaining != null)
        DabblerBadge(
          label: game.spotsRemaining! > 0
              ? '${game.spotsRemaining} spots left'
              : 'Full',
          // The DS `warning` tone is the neutral tint.
          tone: DabblerBadgeTone.warning,
          status: game.spotsRemaining! == 0
              ? colors.status(DabblerStatusTone.error)
              : null,
        ),
    ];

    return DabblerCardEventLarge(
      title: game.title,
      sport: listingSportFor(game.sportName),
      cover: const ListingCover(),
      dateTime: game.scheduledAt != null ? _formatTime(game.scheduledAt!) : null,
      location: venueLine.isEmpty ? null : venueLine,
      footer: ListingBadgeRow(badges: badges),
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
      semanticLabel: game.title,
    );
  }

  static Widget _statusBadge(DabblerColors colors, String? status) {
    switch (status?.toLowerCase()) {
      case 'live':
        return DabblerBadge(
          label: 'Live',
          tone: DabblerBadgeTone.defaultTone,
          status: colors.status(DabblerStatusTone.error),
        );
      case 'ended':
        return const DabblerBadge(label: 'Ended', tone: DabblerBadgeTone.warning);
      case 'cancelled':
        return const DabblerBadge(
          label: 'Cancelled',
          tone: DabblerBadgeTone.warning,
        );
      default:
        return const DabblerBadge(label: 'Upcoming');
    }
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(dt.year, dt.month, dt.day);
    final diff = gameDay.difference(today).inDays;
    final timeStr = DateFormat('h a').format(dt);
    if (diff == 0) return 'Today  $timeStr';
    if (diff == 1) return 'Tomorrow  $timeStr';
    return '${DateFormat('d MMM').format(dt)}  $timeStr';
  }
}

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_chips.dart';
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
    final sportsAsync = ref.watch(
      activeChallengeSportsByProfileCountryProvider,
    );

    return sportsAsync.when(
      loading: () => const DabblerPage(body: Center(child: DabblerSpinner())),
      error: (_, __) => DabblerPage(
        body: Center(
          child: DabblerEmptyState.error(title: 'Failed to load sports'),
        ),
      ),
      data: (sports) => _GamesTabScreen(
        key: ValueKey(sports.map((s) => s.id).join()),
        sports: sports,
      ),
    );
  }
}

// =============================================================================
// LIST FILTERS — shared by the body, the rail and the sheet footer
// =============================================================================

/// The query for [sportId] under the current nearby filter.
NearbyGamesParams _paramsFor(WidgetRef ref, String? sportId) {
  final nearbyEnabled = ref.watch(nearbyGamesFilterEnabledProvider);
  final locState = nearbyEnabled
      ? ref.watch(activeLocationProvider).valueOrNull
      : null;
  final location = locState is ActiveLocationReady ? locState.location : null;
  return (
    lat: location?.lat,
    lng: location?.lng,
    radiusMeters: location?.nearbyRadiusMeters,
    sportId: sportId,
    sortOrder: ref.watch(nearbyGameSortProvider),
  );
}

/// Whether [g] survives the list filters. Past and cancelled games never show
/// here — history lives in My Sports → History.
bool _passes(WidgetRef ref, NearbyGameModel g, DateTime now) {
  if (g.status == 'ended' || g.status == 'cancelled') return false;
  if (ref.watch(gamesOpenSpotsOnlyProvider) && (g.spotsRemaining ?? 1) <= 0) {
    return false;
  }
  if (!ref.watch(gamesSkillFilterProvider).matches(g.minSkill, g.maxSkill)) {
    return false;
  }
  return ref.watch(gamesDateFilterProvider).matches(g.scheduledAt, now);
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
    // location-filtered variants refetch, plus the pinned section.
    ref.invalidate(nearbyGamesProvider);
    ref.invalidate(myPinnedGamesProvider);
    await Future.delayed(DabblerMotion.delaySettle);
  }

  void _resetFilters() {
    ref.read(nearbyGamesFilterEnabledProvider.notifier).state = false;
    ref.read(gamesDateFilterProvider.notifier).state = GamesDateFilter.any;
    ref.read(gamesSkillFilterProvider.notifier).state = GamesSkillFilter.any;
    ref.read(gamesOpenSpotsOnlyProvider.notifier).state = false;
    ref.read(nearbyGameSortProvider.notifier).state = NearbySortOrder.nearest;
  }

  void _openFilters() {
    showListingFilterSheet(
      context,
      onReset: _resetFilters,
      builder: (_) => const _GamesFilterBody(),
      footerBuilder: (_) => const _ShowGamesButton(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The header's count and the applied-filters rail both follow every filter
    // that narrows the list.
    final nearby = ref.watch(nearbyGamesFilterEnabledProvider);
    final radius = ref.watch(nearbyRadiusProvider);
    final dateFilter = ref.watch(gamesDateFilterProvider);
    final skillFilter = ref.watch(gamesSkillFilterProvider);
    final openSpots = ref.watch(gamesOpenSpotsOnlyProvider);
    final sortOrder = ref.watch(nearbyGameSortProvider);
    final locState = ref.watch(activeLocationProvider).valueOrNull;

    final active = <DabblerFilterRailItem>[
      if (nearby)
        DabblerFilterRailItem(
          label: nearbyRadiusLabel(radius),
          onRemove: () =>
              ref.read(nearbyGamesFilterEnabledProvider.notifier).state = false,
        ),
      if (dateFilter != GamesDateFilter.any)
        DabblerFilterRailItem(
          label: dateFilter.label,
          onRemove: () => ref.read(gamesDateFilterProvider.notifier).state =
              GamesDateFilter.any,
        ),
      if (skillFilter != GamesSkillFilter.any)
        DabblerFilterRailItem(
          label: skillFilter.label,
          onRemove: () => ref.read(gamesSkillFilterProvider.notifier).state =
              GamesSkillFilter.any,
        ),
      if (openSpots)
        DabblerFilterRailItem(
          label: 'Open spots',
          onRemove: () =>
              ref.read(gamesOpenSpotsOnlyProvider.notifier).state = false,
        ),
      if (sortOrder != NearbySortOrder.nearest)
        DabblerFilterRailItem(
          label: 'Starting soonest',
          onRemove: () => ref.read(nearbyGameSortProvider.notifier).state =
              NearbySortOrder.nearest,
        ),
    ];

    return DabblerPage(
      topBar: DabblerPageHeader(
        title: AppLocalizations.of(context).nav_games,
        locationLabel: locState is ActiveLocationReady
            ? locState.location.area.name
            : 'Set location',
        onLocationPressed: () => HomeLocationPickerSheet.show(context),
        actions: <DabblerPageHeaderAction>[
          DabblerPageHeaderAction(
            icon: 'search-normal',
            semanticLabel: 'Search',
            onPressed: () => context.push(RoutePaths.socialSearch),
          ),
          DabblerPageHeaderAction(
            icon: 'filter',
            semanticLabel: 'Filters',
            onPressed: _openFilters,
            count: active.length,
          ),
        ],
      ),
      // The DS cards and tabs carry no screen gutter of their own.
      body: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
        ),
        child: DabblerTabPager(
          scrollable: true,
          items: <DabblerTabItem>[
            const DabblerTabItem(id: 'all', label: 'All sports'),
            for (final sport in widget.sports)
              DabblerTabItem(id: sport.id, label: sport.localizedName(context)),
          ],
          pages: List.generate(
            _tabCount,
            // The applied-filters rail sits under the tabs, above each list.
            (i) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DabblerFilterRail(
                  items: active,
                  clearAllLabel: 'Clear all',
                  onClearAll: _resetFilters,
                ),
                Expanded(
                  child: _GameTabBody(
                    sportId: _sportIdForTab(i),
                    scrollController: _scrollControllers[i],
                    onRefresh: _handleRefresh,
                    onRetry: () => ref.invalidate(nearbyGamesProvider),
                    onChangeFilters: _openFilters,
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

/// The design's groups: Distance, Date, Skill level, then the app's own
/// Availability, and Sort by. Everything writes straight to its provider.
class _GamesFilterBody extends ConsumerWidget {
  const _GamesFilterBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFilter = ref.watch(gamesDateFilterProvider);
    final skillFilter = ref.watch(gamesSkillFilterProvider);
    final openSpotsOnly = ref.watch(gamesOpenSpotsOnlyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: DabblerSpacing.space6,
      children: [
        DabblerFilterGroup(
          label: 'Distance',
          children: nearbyDistanceChips(ref, nearbyGamesFilterEnabledProvider),
        ),
        DabblerFilterGroup(
          label: 'Date',
          children: [
            for (final f in GamesDateFilter.values)
              if (f != GamesDateFilter.any)
                DabblerChip(
                  label: f.label,
                  selected: f == dateFilter,
                  onTap: () =>
                      ref.read(gamesDateFilterProvider.notifier).state =
                          f == dateFilter ? GamesDateFilter.any : f,
                ),
          ],
        ),
        DabblerFilterGroup(
          label: 'Skill level',
          children: [
            for (final f in GamesSkillFilter.values)
              if (f != GamesSkillFilter.any)
                DabblerChip(
                  label: f.label,
                  selected: f == skillFilter,
                  onTap: () =>
                      ref.read(gamesSkillFilterProvider.notifier).state =
                          f == skillFilter ? GamesSkillFilter.any : f,
                ),
          ],
        ),
        DabblerFilterGroup(
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
        DabblerFilterGroup(
          label: 'Sort by',
          children: nearbySortChips(ref, nearbyGameSortProvider),
        ),
      ],
    );
  }
}

/// The sheet's closing action: "Show N games", N being what the "All sports"
/// list holds under the filters as they stand.
class _ShowGamesButton extends ConsumerWidget {
  const _ShowGamesButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(nearbyGamesProvider(_paramsFor(ref, null)));
    final now = DateTime.now();
    final count = games.valueOrNull?.where((g) => _passes(ref, g, now)).length;
    return DabblerButton(
      label: count == null ? 'Show games' : 'Show $count games',
      fullWidth: true,
      onPressed: () => Navigator.of(context).pop(),
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
    required this.onChangeFilters,
  });

  final String? sportId;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onChangeFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = _paramsFor(ref, sportId);
    final isFiltered = params.lat != null;

    final gamesAsync = ref.watch(nearbyGamesProvider(params));
    // Pinned section: the viewer's created/joined upcoming games,
    // independent of the location filter.
    final pinned =
        ref.watch(myPinnedGamesProvider(sportId)).valueOrNull ??
        const <NearbyGameModel>[];

    return gamesAsync.when(
      loading: () => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space4),
        children: const [
          DabblerSkeleton.card(),
          DabblerGap.v(DabblerSpacing.space4),
          DabblerSkeleton.card(),
          DabblerGap.v(DabblerSpacing.space4),
          DabblerSkeleton.card(),
        ],
      ),
      error: (e, _) => Center(
        child: DabblerEmptyState.error(
          title: "Couldn't load games",
          size: DabblerEmptyStateSize.inline,
          onRetry: onRetry,
          retryLabel: 'Retry',
        ),
      ),
      data: (games) {
        final pinnedIds = {for (final g in pinned) g.id};

        // Pinned "Upcoming" games stay visible — the filters narrow
        // discovery, not your own commitments.
        final now = DateTime.now();
        final filtersActive =
            ref.watch(gamesDateFilterProvider) != GamesDateFilter.any ||
            ref.watch(gamesSkillFilterProvider) != GamesSkillFilter.any ||
            ref.watch(gamesOpenSpotsOnlyProvider);

        final others = games
            .where((g) => !pinnedIds.contains(g.id))
            .where((g) => _passes(ref, g, now))
            .toList();

        if (pinned.isEmpty && others.isEmpty) {
          final narrowed = filtersActive && games.isNotEmpty;
          return Center(
            child: DabblerEmptyState(
              icon: 'game',
              title: narrowed
                  ? 'No games match your filters'
                  : isFiltered
                  ? 'No games found nearby.'
                  : 'No games yet',
              text: narrowed
                  ? 'Adjust or clear the filters.'
                  : isFiltered
                  ? 'Try widening your search radius in the filter.'
                  : 'Be the first to create a game in your area!',
              action: DabblerButton(
                label: 'Change filters',
                onPressed: onChangeFilters,
              ),
            ),
          );
        }

        return DabblerRefresh(
          onRefresh: onRefresh,
          child: ListView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.only(
              top: DabblerSpacing.space4,
              bottom: DabblerSpacing.space8,
            ),
            children: [
              if (pinned.isNotEmpty) ...[
                DabblerText('Upcoming', style: DabblerType.title2),
                const DabblerGap.v(DabblerSpacing.space4),
                _UpcomingRail(games: pinned),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
              for (final g in others) ...[
                _GameCard(game: g, showDistance: isFiltered),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// UPCOMING RAIL — the viewer's own games, counting down
// =============================================================================

class _UpcomingRail extends StatelessWidget {
  const _UpcomingRail({required this.games});

  final List<NearbyGameModel> games;

  /// The design's gauge window: the three days before the start.
  static const int _countdownWindowMinutes = 3 * 24 * 60;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final single = games.length == 1;
    final tiles = <Widget>[
      for (var i = 0; i < games.length; i++)
        _tile(context, games[i], i, locale, single),
    ];
    if (single) return tiles.first;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: DabblerSpacing.space4, children: tiles),
    );
  }

  Widget _tile(
    BuildContext context,
    NearbyGameModel g,
    int i,
    String locale,
    bool single,
  ) {
    final at = g.scheduledAt;
    final left = at?.difference(DateTime.now());
    final remaining = left == null || left.isNegative ? Duration.zero : left;
    final String value;
    final String unit;
    if (remaining.inDays > 0) {
      value = '${remaining.inDays}';
      unit = remaining.inDays == 1 ? 'day' : 'days';
    } else if (remaining.inHours > 0) {
      value = '${remaining.inHours}';
      unit = remaining.inHours == 1 ? 'hour' : 'hours';
    } else {
      value = '${remaining.inMinutes}';
      unit = 'min';
    }
    return DabblerCardUpcoming(
      width: single ? null : DabblerSizing.railCardWidth,
      tone: DabblerCardUpcomingTone
          .values[i % DabblerCardUpcomingTone.values.length],
      fraction: at == null
          ? 0
          : 1 - (remaining.inMinutes / _countdownWindowMinutes).clamp(0.0, 1.0),
      countdownValue: value,
      countdownUnit: unit,
      title: g.title,
      when: at == null
          ? null
          : '${DateFormat.MMMd(locale).format(at)} · ${DateFormat.jm(locale).format(at)}',
      place: g.venueName,
      onTap: () => context.push(RoutePaths.gameDetail(g.id)),
    );
  }
}

// =============================================================================
// GAME CARD
// =============================================================================

/// A game on the design system's game card (`Listings.dc.html:207-262`).
/// The listing's price, verified-host mark, duration, likes and shares have no
/// data or feature behind them in the app, so the card draws none; the join
/// button stays on the detail screen.
class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, this.showDistance = false});

  final NearbyGameModel game;
  final bool showDistance;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final at = game.scheduledAt;
    final colors = DabblerColors.of(context);
    final skill = _skillTier(game.minSkill, game.maxSkill);

    return DabblerCardGame(
      title: game.title,
      tags: [
        if (game.sportName?.isNotEmpty == true)
          DabblerBadge(
            label: game.sportName!,
            status: colors.status(DabblerStatusTone.info),
          ),
        if (skill != null)
          DabblerBadge(
            label: skill.label,
            status: colors.status(switch (skill) {
              GamesSkillFilter.beginner => DabblerStatusTone.success,
              GamesSkillFilter.intermediate => DabblerStatusTone.warning,
              _ => DabblerStatusTone.error,
            }),
          ),
        if (game.isMine)
          DabblerBadge(
            label: game.isCreated ? 'Created' : 'Joined',
            status: colors.status(DabblerStatusTone.success),
          ),
      ],
      dayLabel: at == null ? null : _dayLabel(at, locale),
      timeLabel: at == null ? null : DateFormat.jm(locale).format(at),
      meta: [
        if (game.venueName?.isNotEmpty == true) game.venueName!,
        if (showDistance && game.distanceMeters > 0) game.distanceLabel,
      ],
      progress: game.spotsRemaining != null && game.playerCount != null
          ? DabblerCardEventPlayers(
              label:
                  '${game.playerCount} of ${game.playerCount! + game.spotsRemaining!} players in',
              joined: game.playerCount!,
              capacity: game.playerCount! + game.spotsRemaining!,
              note: game.spotsRemaining! == 0
                  ? 'Full'
                  : '${game.spotsRemaining} spots left',
              tone: game.spotsRemaining! == 0
                  ? DabblerProgressBarTone.error
                  : game.spotsRemaining! <= 2
                  ? DabblerProgressBarTone.warning
                  : DabblerProgressBarTone.brand,
            )
          : null,
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
      semanticLabel: game.title,
    );
  }

  /// The tier name for the game's skill window, by its lower bound — the
  /// same bands the skill filter uses.
  static GamesSkillFilter? _skillTier(int? min, int? max) {
    final level = min ?? max;
    if (level == null) return null;
    for (final tier in GamesSkillFilter.values) {
      final r = tier.range;
      if (r != null && level >= r.$1 && level <= r.$2) return tier;
    }
    return null;
  }

  static String _dayLabel(DateTime dt, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(dt.year, dt.month, dt.day);
    final diff = gameDay.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat.MMMd(locale).format(dt);
  }
}

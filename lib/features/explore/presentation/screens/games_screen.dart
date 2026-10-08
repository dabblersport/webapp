import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'dart:async';

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/games_following_provider.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/utils/games_listing_copy.dart';
import 'package:dabbler/features/games/presentation/widgets/games_listing_card.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_chips.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_scaffold.dart';
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
          child: DabblerEmptyState.error(
            title: AppLocalizations.of(context).listing_load_sports_failed,
            retryLabel: AppLocalizations.of(context).feed_retry,
          ),
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
    radiusMeters: location == null ? null : ref.watch(gamesRadiusProvider),
    sportId: sportId,
    sortOrder:
        ref.watch(nearbyGameSortProvider) ?? NearbySortOrder.defaultOrder,
  );
}

/// Whether [g] survives the list filters. Past and cancelled games never show
/// here — history lives in My Sports → History.
bool _passes(WidgetRef ref, NearbyGameModel g, DateTime now) {
  if (g.status == 'ended' || g.status == 'cancelled') return false;
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
    ref.read(nearbyGameSortProvider.notifier).state = null;
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
    final l = AppLocalizations.of(context);
    final nearby = ref.watch(nearbyGamesFilterEnabledProvider);
    final radius = ref.watch(gamesRadiusProvider);
    final dateFilter = ref.watch(gamesDateFilterProvider);
    final skillFilter = ref.watch(gamesSkillFilterProvider);
    final sortOrder = ref.watch(nearbyGameSortProvider);
    final locState = ref.watch(activeLocationProvider).valueOrNull;

    final active = <DabblerFilterRailItem>[
      if (nearby)
        DabblerFilterRailItem(
          label: nearbyRadiusLabel(l, radius),
          onRemove: () =>
              ref.read(nearbyGamesFilterEnabledProvider.notifier).state = false,
        ),
      if (dateFilter != GamesDateFilter.any)
        DabblerFilterRailItem(
          label: _dateLabel(l, dateFilter),
          onRemove: () => ref.read(gamesDateFilterProvider.notifier).state =
              GamesDateFilter.any,
        ),
      if (skillFilter != GamesSkillFilter.any)
        DabblerFilterRailItem(
          label: _skillLabel(l, skillFilter),
          onRemove: () => ref.read(gamesSkillFilterProvider.notifier).state =
              GamesSkillFilter.any,
        ),
      // Every applied key is a chip, the sort included
      // (`Listings.2026-10-08.dc.html:2009-2021`).
      if (sortOrder != null)
        DabblerFilterRailItem(
          label: gamesSortLabel(l, sortOrder),
          onRemove: () =>
              ref.read(nearbyGameSortProvider.notifier).state = null,
        ),
    ];

    return DabblerPage(
      body: ListingScaffold(
        // The design's default header is plain (`gamesHead: 'none'`,
        // `Listings.2026-10-08.dc.html:2085-2088`); the tint is its variant.
        head: DabblerListingHead.none,
        header: DabblerPageHeader(
          safeArea: false,
          contentPadding: DabblerPageHeader.listingPadding,
          title: AppLocalizations.of(context).nav_games,
          locationLabel: locState is ActiveLocationReady
              ? locState.location.area.name
              : l.listing_set_location,
          onLocationPressed: () => HomeLocationPickerSheet.show(context),
          actions: <DabblerPageHeaderAction>[
            // The Favourites entry (`Listings.2026-10-08b.dc.html:96-98`).
            DabblerPageHeaderAction(
              icon: 'heart',
              semanticLabel: l.fav_title,
              onPressed: () => context.push(
                '${RoutePaths.favourites}?tab=${FavouriteKind.game.name}',
              ),
            ),
            DabblerPageHeaderAction(
              icon: 'search-normal',
              semanticLabel: l.listing_search,
              onPressed: () => context.push(RoutePaths.socialSearch),
            ),
            DabblerPageHeaderAction(
              icon: 'filter',
              semanticLabel: l.listing_filters,
              onPressed: _openFilters,
              count: active.length,
            ),
          ],
        ),
        tabs: <DabblerTabItem>[
          DabblerTabItem(id: 'all', label: l.listing_all_sports),
          for (final sport in widget.sports)
            DabblerTabItem(id: sport.id, label: sport.localizedName(context)),
        ],
        filters: active,
        clearAllLabel: l.listing_clear_all,
        onClearAll: _resetFilters,
        // The whole rail opens the sheet (`Listings.2026-10-08.dc.html:111`).
        onFiltersTap: _openFilters,
        filtersTapSemanticLabel: l.listing_filters_open,
        pages: List.generate(
          _tabCount,
          (i) => _GameTabBody(
            sports: widget.sports,
            sportId: _sportIdForTab(i),
            scrollController: _scrollControllers[i],
            onRefresh: _handleRefresh,
            onRetry: () => ref.invalidate(nearbyGamesProvider),
            onChangeFilters: _openFilters,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// FILTER SHEET
// =============================================================================

/// The design's groups: Distance, Date, Skill level and Sort by
/// (`Listings.2026-10-08.dc.html:1816-1823`; the price group waits for a price
/// source). Everything writes straight to its provider.
class _GamesFilterBody extends ConsumerWidget {
  const _GamesFilterBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final dateFilter = ref.watch(gamesDateFilterProvider);
    final skillFilter = ref.watch(gamesSkillFilterProvider);
    final sortOrder = ref.watch(nearbyGameSortProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: DabblerSpacing.space6,
      children: [
        DabblerFilterGroup(
          label: l.listing_group_distance,
          children: nearbyDistanceChips(
            context,
            ref,
            nearbyGamesFilterEnabledProvider,
            radiusProvider: gamesRadiusProvider,
          ),
        ),
        DabblerFilterGroup(
          label: l.listing_group_date,
          children: [
            for (final f in GamesDateFilter.values)
              if (f != GamesDateFilter.any)
                DabblerChip(
                  label: _dateLabel(l, f),
                  selected: f == dateFilter,
                  onTap: () =>
                      ref.read(gamesDateFilterProvider.notifier).state =
                          f == dateFilter ? GamesDateFilter.any : f,
                ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_skill,
          children: [
            for (final f in GamesSkillFilter.values)
              if (f != GamesSkillFilter.any)
                DabblerChip(
                  label: _skillLabel(l, f),
                  selected: f == skillFilter,
                  onTap: () =>
                      ref.read(gamesSkillFilterProvider.notifier).state =
                          f == skillFilter ? GamesSkillFilter.any : f,
                ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_sort,
          children: [
            for (final o in NearbySortOrder.values)
              DabblerChip(
                label: gamesSortLabel(l, o),
                selected: o == sortOrder,
                onTap: () => ref.read(nearbyGameSortProvider.notifier).state =
                    o == sortOrder ? null : o,
              ),
          ],
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
      label: count == null
          ? AppLocalizations.of(context).listing_show_games_plain
          : AppLocalizations.of(context).listing_show_games(count),
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
    required this.sports,
    required this.sportId,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    required this.onChangeFilters,
  });

  /// The listing's sports, to show a game's sport in the viewer's language.
  final List<Sport> sports;
  final String? sportId;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onChangeFilters;

  /// [name] (the RPC's English sport name) in the viewer's language.
  String? _sportLabel(BuildContext context, String? name) {
    if (name == null) return null;
    for (final s in sports) {
      if (s.nameEn.toLowerCase() == name.toLowerCase()) {
        return s.localizedName(context);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final params = _paramsFor(ref, sportId);
    final isFiltered = params.lat != null;

    final gamesAsync = ref.watch(nearbyGamesProvider(params));
    // Pinned section: the viewer's created/joined upcoming games,
    // independent of the location filter.
    final pinned =
        ref.watch(myPinnedGamesProvider(sportId)).valueOrNull ??
        const <NearbyGameModel>[];

    return gamesAsync.when(
      loading: () =>
          const ListingSkeletons(kind: DabblerListingSkeletonKind.game),
      error: (e, _) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ListingLayout.gutter,
        ),
        child: Center(
          child: DabblerEmptyState.error(
            title: l.listing_load_games_failed,
            size: DabblerEmptyStateSize.inline,
            onRetry: onRetry,
            retryLabel: l.feed_retry,
          ),
        ),
      ),
      data: (games) {
        final pinnedIds = {for (final g in pinned) g.id};

        // Pinned "Upcoming" games stay visible — the filters narrow
        // discovery, not your own commitments.
        final now = DateTime.now();
        final dateFilter = ref.watch(gamesDateFilterProvider);
        final filtersActive =
            dateFilter != GamesDateFilter.any ||
            ref.watch(gamesSkillFilterProvider) != GamesSkillFilter.any;

        final listed = games
            .where((g) => !pinnedIds.contains(g.id))
            .where((g) => _passes(ref, g, now))
            .toList();
        // Default order is starting soonest (CEO 2026-10-08), whichever path
        // served the rows; "Nearest" keeps the server's distance order.
        if (ref.watch(nearbyGameSortProvider) != NearbySortOrder.nearest) {
          listed.sort(_bySoonest);
        }
        // One "N following" fetch per set of visible cards, either data path.
        final others = watchGamesWithFollowing(ref, listed);

        if (pinned.isEmpty && others.isEmpty) {
          // `Listings.2026-10-08.dc.html:211-212` whenever anything narrows
          // the list; "No games yet" only for the bare, unlocated list, which
          // the design has no frame for.
          final narrowed = filtersActive || isFiltered;
          return ListingEmpty(
            icon: 'game',
            title: narrowed
                ? l.listing_games_nearby_title
                : l.listing_games_none_title,
            text: narrowed
                ? gamesEmptyText(
                    l,
                    radiusMeters: params.radiusMeters,
                    date: dateFilter,
                  )
                : l.listing_games_none_text,
            action: DabblerButton(
              label: l.listing_change_filters,
              onPressed: onChangeFilters,
            ),
          );
        }

        const EdgeInsetsDirectional gutter = EdgeInsetsDirectional.symmetric(
          horizontal: ListingLayout.gutter,
        );
        return DabblerRefresh(
          onRefresh: onRefresh,
          child: ListView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            // The rail bleeds to the screen edge (`margin: 0 -18px`), so the
            // gutter is per row rather than on the list.
            padding: const EdgeInsetsDirectional.only(
              top: ListingLayout.listTop,
              bottom: ListingLayout.listBottom,
            ),
            children: [
              if (pinned.isNotEmpty) ...[
                Padding(
                  padding: gutter,
                  child: DabblerText(
                    l.listing_upcoming,
                    style: DabblerType.displayLabel,
                  ),
                ),
                const DabblerGap.v(ListingLayout.upcomingGap),
                _UpcomingRail(games: pinned),
                const DabblerGap.v(ListingLayout.cardGap),
              ],
              for (var i = 0; i < others.length; i++) ...[
                if (i > 0) const DabblerGap.v(ListingLayout.cardGap),
                Padding(
                  padding: gutter,
                  child: GamesListingCard(
                    game: others[i],
                    sportLabel: _sportLabel(context, others[i].sportName),
                  ),
                ),
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
    if (single) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ListingLayout.gutter,
        ),
        child: tiles.first,
      );
    }
    // `Listings.dc.html:141`: the rail scrolls edge to edge, tiles 9 apart,
    // each hugging its content.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ListingLayout.gutter,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DabblerSpacing.space3,
        children: tiles,
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    NearbyGameModel g,
    int i,
    String locale,
    bool single,
  ) {
    final l = AppLocalizations.of(context);
    final at = g.scheduledAt;
    final left = at?.difference(DateTime.now());
    final remaining = left == null || left.isNegative ? Duration.zero : left;
    final String value;
    final String unit;
    if (remaining.inDays > 0) {
      value = '${remaining.inDays}';
      unit = remaining.inDays == 1 ? l.listing_unit_day : l.listing_unit_days;
    } else if (remaining.inHours > 0) {
      value = '${remaining.inHours}';
      unit = remaining.inHours == 1
          ? l.listing_unit_hour
          : l.listing_unit_hours;
    } else {
      value = '${remaining.inMinutes}';
      unit = l.listing_unit_min;
    }
    // Single: the date-first tile (`Listings.dc.html:119-137`), "venue ·
    // time" beside the date block. Several: the ring-first rail tile
    // (`:143-167`), date and time over the venue and its distance.
    return DabblerCardUpcoming(
      rail: !single,
      month: single && at != null
          ? DateFormat.MMM(locale).format(at).toUpperCase()
          : null,
      day: single && at != null ? '${at.day}' : null,
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
          : single
          ? DateFormat.jm(locale).format(at)
          : '${DateFormat.MMMd(locale).format(at)} · ${DateFormat.jm(locale).format(at)}',
      place: g.venueName,
      distance: !single && g.distanceMeters > 0 ? g.distanceLabel : null,
      onTap: () => context.push(RoutePaths.gameDetail(g.id)),
    );
  }
}

int _bySoonest(NearbyGameModel a, NearbyGameModel b) {
  final x = a.scheduledAt, y = b.scheduledAt;
  if (x == null) return y == null ? 0 : 1;
  if (y == null) return -1;
  return x.compareTo(y);
}

String _dateLabel(AppLocalizations l, GamesDateFilter f) => switch (f) {
  GamesDateFilter.any => l.listing_date_any,
  GamesDateFilter.today => l.listing_today,
  GamesDateFilter.tomorrow => l.listing_tomorrow,
  GamesDateFilter.thisWeek => l.listing_this_week,
  GamesDateFilter.thisWeekend => l.listing_this_weekend,
};

String _skillLabel(AppLocalizations l, GamesSkillFilter f) =>
    gamesSkillTierLabel(l, f);

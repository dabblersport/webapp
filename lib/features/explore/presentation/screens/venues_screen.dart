import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_bar.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/nearby_venues_provider.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/widgets/app_top_bar.dart';
import 'package:dabbler/providers.dart' hide nearbyVenuesProvider;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/dynamic_background.dart';

// =============================================================================
// SCREEN
// =============================================================================

class VenuesScreen extends ConsumerWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportsAsync = ref.watch(activeSportsByProfileCountryProvider);

    return sportsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator.adaptive())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Failed to load sports'))),
      data: (sports) => _VenuesTabScreen(key: ValueKey(sports.map((s) => s.id).join()), sports: sports),
    );
  }
}

// =============================================================================
// TAB SCREEN — created fresh when sport list changes
// =============================================================================

class _VenuesTabScreen extends ConsumerStatefulWidget {
  const _VenuesTabScreen({super.key, required this.sports});

  final List<Sport> sports;

  @override
  ConsumerState<_VenuesTabScreen> createState() => _VenuesTabScreenState();
}

class _VenuesTabScreenState extends ConsumerState<_VenuesTabScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.sports.length, vsync: this);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: DynamicBackground()),
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (_, __) => [
              if (!isWide) SliverToBoxAdapter(child: _buildHeader()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SportTabBarDelegate(
                  tabController: _tabController,
                  sports: widget.sports,
                  ref: ref,
                ),
              ),
              SliverToBoxAdapter(
                child: NearbyFilterBar(
                  enabledProvider: nearbyVenuesFilterEnabledProvider,
                  sortProvider: nearbyVenueSortProvider,
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: widget.sports.map((sport) {
                return _AllVenuesList(sportId: sport.id);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final profileState = ref.watch(profileControllerProvider);
    final isOrganiser = profileState.profile?.profileType == 'organiser';

    return AppTopBar(
      avatarContext: AvatarContext.main,
      extraActions: [
        if (isOrganiser)
          AppTopBarButton(
            icon: Iconsax.add_copy,
            onTap: () => context.push(RoutePaths.createVenueSubmission),
          ),
        AppTopBarButton(
          icon: Iconsax.archive_copy,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SportsLibraryScreen(initialTabIndex: 1),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// STICKY SPORT TAB BAR DELEGATE
// =============================================================================

class _SportTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _SportTabBarDelegate({
    required this.tabController,
    required this.sports,
    required this.ref,
  });

  final TabController tabController;
  final List<Sport> sports;
  final WidgetRef ref;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sports.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final sport = sports[index];
                    final isSelected = tabController.index == index;
                    final emoji = sport.emoji ?? '';

                    // iOS-style filter capsules — same treatment as the
                    // games screen tabs: frosted system material with a
                    // hairline; selected = flat primary capsule.
                    return Center(
                      child: GestureDetector(
                        onTap: () => tabController.animateTo(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              height: 38,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary
                                    : isLight
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : isLight
                                          ? Colors.black
                                              .withValues(alpha: 0.08)
                                          : Colors.white
                                              .withValues(alpha: 0.12),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (emoji.isNotEmpty) ...[
                                    Text(emoji,
                                        style: const TextStyle(fontSize: 15)),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    sport.localizedName(context),
                                    style: TextStyle(
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 0,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SportTabBarDelegate oldDelegate) =>
      oldDelegate.tabController != tabController ||
      oldDelegate.sports != sports;
}

// =============================================================================
// ALL VENUES LIST
// =============================================================================

/// venue_id → upcoming games happening there. One lightweight query over
/// v_game_card (visibility-gated per viewer) shared by every tab.
final _upcomingGamesByVenueProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final rows = await Supabase.instance.client
      .from(SupabaseConfig.vGameCardTable)
      .select('venue_id')
      .eq('is_cancelled', false)
      .gt('end_at', DateTime.now().toUtc().toIso8601String())
      .not('venue_id', 'is', null)
      .limit(300) as List<dynamic>;
  final counts = <String, int>{};
  for (final r in rows) {
    final id = (r as Map)['venue_id'] as String?;
    if (id != null) counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
});

class _AllVenuesList extends ConsumerWidget {
  const _AllVenuesList({required this.sportId});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyEnabled = ref.watch(nearbyVenuesFilterEnabledProvider);
    final locState =
        nearbyEnabled ? ref.watch(activeLocationProvider).valueOrNull : null;
    final location =
        locState is ActiveLocationReady ? locState.location : null;
    final gameCounts =
        ref.watch(_upcomingGamesByVenueProvider).valueOrNull ?? const {};

    // Nearby path: PostGIS RPC filtered by the active location + radius.
    // While the filter is on but location isn't ready (locating/denied),
    // fall back to the unfiltered list; NearbyFilterBar surfaces the status.
    if (location != null) {
      final params = (
        lat: location.lat,
        lng: location.lng,
        radiusMeters: location.nearbyRadiusMeters,
        sportId: sportId,
        sortOrder: ref.watch(nearbyVenueSortProvider),
      );
      final nearbyAsync = ref.watch(nearbyVenuesProvider(params));

      return nearbyAsync.when(
        loading: _buildSkeletons,
        error: (_, __) => _buildError(context),
        data: (venues) => venues.isEmpty
            ? _buildEmpty(
                context,
                hint:
                    'No venues within ${(location.nearbyRadiusMeters / 1000).round()} km — try widening your search radius.',
              )
            : _buildCards(
                context,
                ref,
                venues
                    .map((v) => _VenueCardData(
                          id: v.id,
                          name: v.nameEn,
                          city: v.city,
                          area: v.area,
                          pricePerHour: v.pricePerHour,
                          isIndoor: v.isIndoor,
                          distanceLabel: v.distanceLabel,
                          gamesCount: gameCounts[v.id] ?? 0,
                        ))
                    .toList(),
              ),
      );
    }

    final filters = VenuesBySportFilters(sportId: sportId, isActive: true);
    final venuesAsync = ref.watch(venuesBySportWithFiltersProvider(filters));

    return venuesAsync.when(
      loading: _buildSkeletons,
      error: (_, __) => _buildError(context),
      data: (venues) => venues.isEmpty
          ? _buildEmpty(context)
          : _buildCards(
              context,
              ref,
              venues
                  .map((v) => _VenueCardData(
                        id: v.id,
                        name: v.nameEn,
                        city: v.city,
                        area: v.area,
                        pricePerHour: v.pricePerHour,
                        isIndoor: v.isIndoor,
                        gamesCount: gameCounts[v.id] ?? 0,
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildCards(
    BuildContext context,
    WidgetRef ref,
    List<_VenueCardData> venues,
  ) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nearbyVenuesProvider);
        ref.invalidate(venuesBySportWithFiltersProvider);
        ref.invalidate(_upcomingGamesByVenueProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: venues.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, i) => _VenueCard(venue: venues[i]),
      ),
    );
  }

  Widget _buildSkeletons() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => Builder(
        builder: (context) => Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      itemBuilder: (_, __) => const _VenueCardSkeleton(),
    );
  }

  Widget _buildEmpty(BuildContext context, {String? hint}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.building_3_copy, size: 48, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'No venues found',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint ?? 'Try selecting a different sport.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Couldn\'t load venues',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: () {}, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// VENUE CARD
// =============================================================================

/// View-model for [_VenueCard] so the same card renders both the default
/// list ([VenueWithSportModel]) and the nearby list (NearbyVenueModel).
class _VenueCardData {
  const _VenueCardData({
    required this.id,
    required this.name,
    required this.city,
    this.area,
    this.pricePerHour,
    this.isIndoor,
    this.distanceLabel,
    this.gamesCount = 0,
  });

  final String id;
  final String name;
  final String city;
  final String? area;
  final double? pricePerHour;
  final bool? isIndoor;

  /// Formatted distance (e.g. "1.2 km"); non-null only when the nearby
  /// filter is active.
  final String? distanceLabel;

  /// Upcoming games happening at this venue (0 when none/unknown).
  final int gamesCount;
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});

  final _VenueCardData venue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final locationLine = [
      if (venue.area?.isNotEmpty == true) venue.area!,
      venue.city,
    ].join(', ');

    return InkWell(
      onTap: () => context.push(RoutePaths.venueDetail(venue.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.building_3_copy, size: 20, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (venue.distanceLabel != null)
                        _DistanceBadge(label: venue.distanceLabel!, cs: cs)
                      else if (venue.pricePerHour != null)
                        _PriceBadge(price: venue.pricePerHour!, cs: cs),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Iconsax.location_copy, size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          locationLine,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (venue.isIndoor != null ||
                      venue.gamesCount > 0 ||
                      (venue.distanceLabel != null &&
                          venue.pricePerHour != null)) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (venue.gamesCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              venue.gamesCount == 1
                                  ? '1 upcoming game'
                                  : '${venue.gamesCount} upcoming games',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        if (venue.isIndoor != null)
                          _SmallChip(
                            label: venue.isIndoor! ? 'Indoor' : 'Outdoor',
                            cs: cs,
                          ),
                        // Price moves down here when the badge slot is used
                        // by the distance label.
                        if (venue.distanceLabel != null &&
                            venue.pricePerHour != null)
                          _SmallChip(
                            label: venue.pricePerHour! > 0
                                ? 'AED ${venue.pricePerHour!.toStringAsFixed(0)}/hr'
                                : 'Free',
                            cs: cs,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DISTANCE BADGE
// =============================================================================

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.routing_copy, size: 12, color: cs.onPrimaryContainer),
          const SizedBox(width: 3),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PRICE BADGE
// =============================================================================

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price, required this.cs});

  final double price;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        price > 0 ? 'AED ${price.toStringAsFixed(0)}/hr' : 'Free',
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// =============================================================================
// SMALL CHIP
// =============================================================================

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// =============================================================================
// SKELETON CARD
// =============================================================================

class _VenueCardSkeleton extends StatelessWidget {
  const _VenueCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    box(140, 14),
                    const Spacer(),
                    box(60, 22),
                  ],
                ),
                const SizedBox(height: 8),
                box(100, 11),
                const SizedBox(height: 8),
                box(56, 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

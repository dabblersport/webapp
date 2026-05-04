import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/providers.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
    final cs = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final profileState = ref.watch(profileControllerProvider);
    final isOrganiser = profileState.profile?.profileType == 'organiser';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            child: SvgPicture.asset(
              'assets/images/dabbler_text_logo.svg',
              width: 100,
              height: 18,
              colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOrganiser) ...[
                GestureDetector(
                  onTap: () => context.push(RoutePaths.createVenueSubmission),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.add_copy, color: cs.primary, size: 18),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SportsLibraryScreen(initialTabIndex: 1),
                  ),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.archive_copy, color: cs.primary, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
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
    final tt = Theme.of(context).textTheme;

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
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sport = sports[index];
                    final isSelected = tabController.index == index;

                    int venueCount = 0;
                    if (isSelected) {
                      venueCount = ref
                          .watch(venuesBySportWithFiltersProvider(
                            VenuesBySportFilters(
                              sportId: sport.id,
                              isActive: true,
                            ),
                          ))
                          .maybeWhen(
                            data: (v) => v.length,
                            orElse: () => 0,
                          );
                    }

                    return GestureDetector(
                      onTap: () => tabController.animateTo(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sport.emoji != null)
                              Text(
                                sport.emoji!,
                                style: const TextStyle(fontSize: 15),
                              ),
                            if (sport.emoji != null) const SizedBox(width: 5),
                            Text(
                              sport.nameEn,
                              style: tt.labelLarge?.copyWith(
                                color: isSelected ? cs.onPrimary : cs.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.onPrimary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$venueCount',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
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

class _AllVenuesList extends ConsumerWidget {
  const _AllVenuesList({required this.sportId});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = VenuesBySportFilters(sportId: sportId, isActive: true);
    final venuesAsync = ref.watch(venuesBySportWithFiltersProvider(filters));

    return venuesAsync.when(
      loading: _buildSkeletons,
      error: (_, __) => _buildError(context),
      data: (venues) =>
          venues.isEmpty ? _buildEmpty(context) : _buildList(context, venues),
    );
  }

  Widget _buildList(BuildContext context, List<VenueWithSportModel> venues) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {},
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

  Widget _buildEmpty(BuildContext context) {
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
              'Try selecting a different sport.',
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

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});

  final VenueWithSportModel venue;

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
                          venue.nameEn,
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (venue.pricePerHour != null)
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
                  if (venue.isIndoor != null) ...[
                    const SizedBox(height: 6),
                    _SmallChip(
                      label: venue.isIndoor! ? 'Indoor' : 'Outdoor',
                      cs: cs,
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

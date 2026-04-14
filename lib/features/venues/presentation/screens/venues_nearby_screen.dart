import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart';
import 'package:dabbler/features/venues/presentation/providers/nearby_venues_provider.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/themes/app_theme.dart';

// =============================================================================
// SCREEN
// =============================================================================

/// Renders the Venues Nearby list inside the Sports → Venues tab.
///
/// Accepts [sportId] (nullable) forwarded from the sport-chip selection above.
class VenuesNearbyScreen extends ConsumerStatefulWidget {
  const VenuesNearbyScreen({super.key, this.sportId});

  /// UUID of the selected sport filter, or null for "all sports".
  final String? sportId;

  @override
  ConsumerState<VenuesNearbyScreen> createState() => _VenuesNearbyScreenState();
}

class _VenuesNearbyScreenState extends ConsumerState<VenuesNearbyScreen> {
  @override
  void initState() {
    super.initState();
    // Register a radius override so the slider live-patches this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locState = ref.read(activeLocationProvider).valueOrNull;
      if (locState is ActiveLocationReady) {
        ref
            .read(activeLocationProvider.notifier)
            .setRadiusOverride(locState.location.nearbyRadiusMeters);
      }
    });
  }

  @override
  void dispose() {
    ref.read(activeLocationProvider.notifier).clearRadiusOverride();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final result = await NearbyFilterSheet.show(context);
    if (result == null || !mounted) return;
    ref.read(nearbyVenueSortProvider.notifier).state = result.sortOrder;
    // Radius update is already handled by NearbyRadiusSlider inside the sheet.
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locAsync = ref.watch(activeLocationProvider);

    return locAsync.when(
      loading: () => _buildSkeletons(),
      error: (_, __) => _buildDeniedState(),
      data: (locState) => switch (locState) {
        ActiveLocationLoading() => _buildSkeletons(),
        ActiveLocationDenied() => _buildDeniedState(),
        ActiveLocationError() => _buildDeniedState(),
        ActiveLocationReady(:final location) => _buildReady(location),
      },
    );
  }

  Widget _buildReady(ActiveLocation location) {
    final sortOrder = ref.watch(nearbyVenueSortProvider);
    final radiusMeters = location.nearbyRadiusMeters;

    final params = (
      lat: location.lat,
      lng: location.lng,
      radiusMeters: radiusMeters,
      sportId: widget.sportId,
      sortOrder: sortOrder,
    );

    final venuesAsync = ref.watch(nearbyVenuesProvider(params));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter bar ───────────────────────────────────────────────────
        _FilterBar(
          areaName: location.area.name,
          radiusMeters: radiusMeters,
          sortOrder: sortOrder,
          onFilterTap: _openFilterSheet,
        ),

        // ── List ─────────────────────────────────────────────────────────
        venuesAsync.when(
          loading: () => _buildSkeletons(),
          error: (e, _) => _buildErrorState(e),
          data: (venues) => venues.isEmpty
              ? _buildEmptyState(radiusMeters)
              : _NearbyVenueList(venues: venues),
        ),
      ],
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildSkeletons() {
    return Column(
      children: List.generate(
        5,
        (i) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _NearbyVenueCardSkeleton(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(int radiusMeters) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final km = (radiusMeters / 1000).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.location_slash_copy,
              size: 56,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'No venues within $km km',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try expanding your search radius in the filter.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openFilterSheet,
              icon: const Icon(Iconsax.setting_4_copy, size: 18),
              label: const Text('Adjust filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeniedState() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.location_slash_copy,
              size: 56,
              color: cs.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Location unavailable',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable location or set a saved location to see venues nearby.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(activeLocationProvider.notifier).useGpsLocation(),
              icon: const Icon(Iconsax.gps_copy, size: 18),
              label: const Text('Enable GPS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.wifi_square_copy, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load venues',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                final locState =
                    ref.read(activeLocationProvider).valueOrNull;
                if (locState is ActiveLocationReady) {
                  final sortOrder = ref.read(nearbyVenueSortProvider);
                  final params = (
                    lat: locState.location.lat,
                    lng: locState.location.lng,
                    radiusMeters: locState.location.nearbyRadiusMeters,
                    sportId: widget.sportId,
                    sortOrder: sortOrder,
                  );
                  ref.invalidate(nearbyVenuesProvider(params));
                }
              },
              icon: const Icon(Iconsax.refresh_copy, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FILTER BAR
// =============================================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.areaName,
    required this.radiusMeters,
    required this.sortOrder,
    required this.onFilterTap,
  });

  final String areaName;
  final int radiusMeters;
  final NearbySortOrder sortOrder;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');
    final km = (radiusMeters / 1000).round();
    final sortLabel =
        sortOrder == NearbySortOrder.nearest ? 'Nearest first' : 'Default';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Iconsax.location_copy, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$areaName  ·  $km km  ·  $sortLabel',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sportsScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.setting_4_copy,
                    size: 14,
                    color: sportsScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: tt.labelSmall?.copyWith(
                      color: sportsScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LIST
// =============================================================================

class _NearbyVenueList extends StatelessWidget {
  const _NearbyVenueList({required this.venues});

  final List<NearbyVenueModel> venues;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: venues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _NearbyVenueCard(venue: venues[i]),
    );
  }
}

// =============================================================================
// CARD
// =============================================================================

class _NearbyVenueCard extends StatelessWidget {
  const _NearbyVenueCard({required this.venue});

  final NearbyVenueModel venue;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VenueDetailScreen(venueId: venue.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');

    final locationLine = [
      if (venue.area?.isNotEmpty == true) venue.area!,
      venue.city,
    ].join(', ');

    return Card.filled(
      color: sportsScheme.primary.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name row ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue.nameEn,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Distance badge
                        _DistanceBadge(
                          label: venue.distanceLabel,
                          cs: cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // ── Location ────────────────────────────────────────
                    Row(
                      children: [
                        Icon(
                          Iconsax.location_copy,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationLine,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Chips row ───────────────────────────────────────
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Indoor / outdoor chip
                        if (venue.isIndoor != null)
                          _SmallChip(
                            label: venue.isIndoor! ? 'Indoor' : 'Outdoor',
                            cs: cs,
                          ),
                        // Price chip
                        if (venue.pricePerHour != null)
                          _SmallChip(
                            label: venue.pricePerHour! > 0
                                ? 'AED ${venue.pricePerHour!.toStringAsFixed(0)}/hr'
                                : 'Free',
                            cs: cs,
                          ),
                        // First two sports
                        ...venue.sportNames.take(2).map(
                              (s) => _SmallChip(label: s, cs: cs),
                            ),
                        if (venue.sportNames.length > 2)
                          _SmallChip(
                            label: '+${venue.sportNames.length - 2}',
                            cs: cs,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
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

class _NearbyVenueCardSkeleton extends StatelessWidget {
  const _NearbyVenueCardSkeleton();

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: box(160, 16)),
              const SizedBox(width: 8),
              box(56, 22),
            ],
          ),
          const SizedBox(height: 8),
          box(120, 12),
          const SizedBox(height: 10),
          Row(
            children: [
              box(56, 22),
              const SizedBox(width: 6),
              box(70, 22),
              const SizedBox(width: 6),
              box(60, 22),
            ],
          ),
        ],
      ),
    );
  }
}

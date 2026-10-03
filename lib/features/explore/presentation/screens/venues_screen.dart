import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_bar.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/nearby_venues_provider.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/providers.dart' hide nearbyVenuesProvider;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
// MaterialPageRoute is the navigation route the archive action pushes, kept
// exactly as it was; it paints nothing of its own.
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// SCREEN
// =============================================================================

class VenuesScreen extends ConsumerWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportsAsync = ref.watch(activeSportsByProfileCountryProvider);

    return sportsAsync.when(
      loading: () => const ListingPageSpinner(),
      error: (_, __) => const DabblerPage(
        body: ListingError(message: 'Failed to load sports'),
      ),
      data: (sports) => _VenuesTabScreen(
        key: ValueKey(sports.map((s) => s.id).join()),
        sports: sports,
      ),
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

class _VenuesTabScreenState extends ConsumerState<_VenuesTabScreen> {
  void _resetFilters() {
    ref.read(nearbyVenuesFilterEnabledProvider.notifier).state = false;
  }

  void _openFilters() {
    showListingFilterSheet(
      context,
      onReset: _resetFilters,
      builder: (_) => ListingFilterBody(
        groups: [
          ListingFilterSection(
            label: 'Nearby',
            child: NearbyFilterBar(
              enabledProvider: nearbyVenuesFilterEnabledProvider,
              sortProvider: nearbyVenueSortProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int filterCount) {
    final profileState = ref.watch(profileControllerProvider);
    final isOrganiser = profileState.profile?.profileType == 'organiser';

    return ListingHeader(
      title: AppLocalizations.of(context).nav_venues,
      filterCount: filterCount,
      onFilter: _openFilters,
      actions: [
        if (isOrganiser)
          DabblerButton.icon(
            icon: 'add',
            semanticLabel: 'Add venue',
            tone: DabblerButtonTone.outlined,
            onPressed: () => context.push(RoutePaths.createVenueSubmission),
          ),
        DabblerButton.icon(
          icon: 'archive',
          semanticLabel: 'My sports',
          tone: DabblerButtonTone.outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SportsLibraryScreen(initialTabIndex: 1),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearby = ref.watch(nearbyVenuesFilterEnabledProvider);
    final sports = widget.sports;

    return DabblerPage(
      topBar: _buildHeader(nearby ? 1 : 0),
      body: sports.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              // The DS cards and tabs carry no screen gutter of their own.
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: DabblerSpacing.space6,
              ),
              child: DabblerTabPager(
                scrollable: true,
                items: <DabblerTabItem>[
                  for (final sport in sports)
                    DabblerTabItem(
                      id: sport.id,
                      label: sport.localizedName(context),
                    ),
                ],
                pages: [
                  for (final sport in sports)
                    // The applied-filters rail sits under the tabs.
                    Column(
                      children: [
                        ListingActiveFilters(
                          filters: [
                            if (nearby)
                              ListingActiveFilter(
                                label: 'Nearby',
                                onClear: _resetFilters,
                              ),
                          ],
                          onClearAll: _resetFilters,
                        ),
                        Expanded(child: _AllVenuesList(sport: sport)),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

// =============================================================================
// ALL VENUES LIST
// =============================================================================

/// venue_id → upcoming games happening there. One lightweight query over
/// v_game_card (visibility-gated per viewer) shared by every tab.
final _upcomingGamesByVenueProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
      final rows =
          await Supabase.instance.client
                  .from(SupabaseConfig.vGameCardTable)
                  .select('venue_id')
                  .eq('is_cancelled', false)
                  .gt('end_at', DateTime.now().toUtc().toIso8601String())
                  .not('venue_id', 'is', null)
                  .limit(300)
              as List<dynamic>;
      final counts = <String, int>{};
      for (final r in rows) {
        final id = (r as Map)['venue_id'] as String?;
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    });

class _AllVenuesList extends ConsumerWidget {
  const _AllVenuesList({required this.sport});

  final Sport sport;

  String get sportId => sport.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyEnabled = ref.watch(nearbyVenuesFilterEnabledProvider);
    final locState = nearbyEnabled
        ? ref.watch(activeLocationProvider).valueOrNull
        : null;
    final location = locState is ActiveLocationReady ? locState.location : null;
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
        loading: () => const ListingSkeleton(),
        error: (_, __) => const ListingError(message: "Couldn't load venues"),
        data: (venues) => venues.isEmpty
            ? _buildEmpty(
                hint:
                    'No venues within ${(location.nearbyRadiusMeters / 1000).round()} km — try widening your search radius.',
              )
            : _buildCards(
                ref,
                venues
                    .map(
                      (v) => _VenueCardData(
                        id: v.id,
                        name: v.nameEn,
                        city: v.city,
                        area: v.area,
                        pricePerHour: v.pricePerHour,
                        isIndoor: v.isIndoor,
                        distanceLabel: v.distanceLabel,
                        gamesCount: gameCounts[v.id] ?? 0,
                      ),
                    )
                    .toList(),
              ),
      );
    }

    final filters = VenuesBySportFilters(sportId: sportId, isActive: true);
    final venuesAsync = ref.watch(venuesBySportWithFiltersProvider(filters));

    return venuesAsync.when(
      loading: () => const ListingSkeleton(),
      error: (_, __) => const ListingError(message: "Couldn't load venues"),
      data: (venues) => venues.isEmpty
          ? _buildEmpty()
          : _buildCards(
              ref,
              venues
                  .map(
                    (v) => _VenueCardData(
                      id: v.id,
                      name: v.nameEn,
                      city: v.city,
                      area: v.area,
                      pricePerHour: v.pricePerHour,
                      isIndoor: v.isIndoor,
                      gamesCount: gameCounts[v.id] ?? 0,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCards(WidgetRef ref, List<_VenueCardData> venues) {
    return DabblerRefresh(
      onRefresh: () async {
        ref.invalidate(nearbyVenuesProvider);
        ref.invalidate(venuesBySportWithFiltersProvider);
        ref.invalidate(_upcomingGamesByVenueProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.only(
          top: DabblerSpacing.space4,
          bottom: DabblerSpacing.space8,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: venues.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: DabblerSpacing.space4),
        itemBuilder: (context, i) => _VenueCard(venue: venues[i]),
      ),
    );
  }

  Widget _buildEmpty({String? hint}) {
    return ListingEmpty(
      icon: 'building-3',
      title: 'No venues found',
      text: hint ?? 'Try selecting a different sport.',
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

/// A venue on the design system's venue card (`Listings.dc.html:750-820`).
/// The app has no venue photo, so the card draws no cover; distance, price,
/// setting and upcoming games keep their old places as the card's area line,
/// price row and tags.
class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});

  final _VenueCardData venue;

  @override
  Widget build(BuildContext context) {
    final locationLine = [
      if (venue.area?.isNotEmpty == true) venue.area!,
      venue.city,
    ].join(', ');

    final String? priceLabel = venue.pricePerHour == null
        ? null
        : (venue.pricePerHour! > 0
              ? 'AED ${venue.pricePerHour!.toStringAsFixed(0)}/hr'
              : 'Free');

    final tags = <Widget>[
      if (venue.gamesCount > 0)
        DabblerBadge(
          label: venue.gamesCount == 1
              ? '1 upcoming game'
              : '${venue.gamesCount} upcoming games',
        ),
      if (venue.isIndoor != null)
        DabblerBadge(
          label: venue.isIndoor! ? 'Indoor' : 'Outdoor',
          tone: DabblerBadgeTone.warning,
        ),
    ];

    return DabblerCardVenue(
      name: venue.name,
      area: locationLine,
      distance: venue.distanceLabel,
      tags: tags,
      price: priceLabel,
      onTap: () => context.push(RoutePaths.venueDetail(venue.id)),
      semanticLabel: venue.name,
    );
  }
}

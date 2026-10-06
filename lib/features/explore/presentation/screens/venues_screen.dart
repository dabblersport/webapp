import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_chips.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/venues/presentation/providers/nearby_venues_provider.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/providers.dart' hide nearbyVenuesProvider;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
// MaterialPageRoute is the navigation route the favourites action pushes, kept
// exactly as it was; it paints nothing of its own.
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// =============================================================================
// SCREEN
// =============================================================================

class VenuesScreen extends ConsumerWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportsAsync = ref.watch(activeSportsByProfileCountryProvider);

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
    ref.read(nearbyVenueSortProvider.notifier).state = NearbySortOrder.nearest;
  }

  void _openFilters() {
    showListingFilterSheet(
      context,
      onReset: _resetFilters,
      builder: (_) => const _VenuesFilterBody(),
      footerBuilder: (ctx) => DabblerButton(
        label: AppLocalizations.of(ctx).listing_show_venues,
        fullWidth: true,
        onPressed: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nearby = ref.watch(nearbyVenuesFilterEnabledProvider);
    final radius = ref.watch(nearbyRadiusProvider);
    final sort = ref.watch(nearbyVenueSortProvider);
    final locState = ref.watch(activeLocationProvider).valueOrNull;
    final isOrganiser =
        ref.watch(profileControllerProvider).profile?.profileType ==
        'organiser';
    final sports = widget.sports;

    final active = <DabblerFilterRailItem>[
      if (nearby)
        DabblerFilterRailItem(
          label: nearbyRadiusLabel(l, radius),
          onRemove: () =>
              ref.read(nearbyVenuesFilterEnabledProvider.notifier).state =
                  false,
        ),
      if (sort != NearbySortOrder.nearest)
        DabblerFilterRailItem(
          label: l.listing_sort_soonest,
          onRemove: () => ref.read(nearbyVenueSortProvider.notifier).state =
              NearbySortOrder.nearest,
        ),
    ];

    return DabblerPage(
      topBar: DabblerPageHeader(
        title: AppLocalizations.of(context).nav_venues,
        locationLabel: locState is ActiveLocationReady
            ? locState.location.area.name
            : l.listing_set_location,
        onLocationPressed: () => HomeLocationPickerSheet.show(context),
        actions: <DabblerPageHeaderAction>[
          if (isOrganiser)
            DabblerPageHeaderAction(
              icon: 'add',
              semanticLabel: l.listing_add_venue,
              onPressed: () => context.push(RoutePaths.createVenueSubmission),
            ),
          DabblerPageHeaderAction(
            icon: 'heart',
            semanticLabel: l.listing_saved_venues,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SportsLibraryScreen(initialTabIndex: 1),
              ),
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
      body: sports.isEmpty
          ? const SizedBox.shrink()
          : ListingTabs(
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
                  ListingPage(
                    filters: active,
                    clearAllLabel: l.listing_clear_all,
                    onClearAll: _resetFilters,
                    body: _AllVenuesList(
                      sport: sport,
                      onChangeFilters: _openFilters,
                    ),
                  ),
              ],
            ),
    );
  }
}

// =============================================================================
// FILTER SHEET
// =============================================================================

/// Distance and Sort by — the design's groups the app has a feature for.
/// Indoor / outdoor, price per hour and rating have no filter behind them.
class _VenuesFilterBody extends ConsumerWidget {
  const _VenuesFilterBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
            nearbyVenuesFilterEnabledProvider,
          ),
        ),
        DabblerFilterGroup(
          label: l.listing_group_sort,
          children: nearbySortChips(context, ref, nearbyVenueSortProvider),
        ),
      ],
    );
  }
}

// =============================================================================
// ALL VENUES LIST
// =============================================================================

class _AllVenuesList extends ConsumerWidget {
  const _AllVenuesList({required this.sport, required this.onChangeFilters});

  final Sport sport;
  final VoidCallback onChangeFilters;

  String get sportId => sport.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final nearbyEnabled = ref.watch(nearbyVenuesFilterEnabledProvider);
    final locState = nearbyEnabled
        ? ref.watch(activeLocationProvider).valueOrNull
        : null;
    final location = locState is ActiveLocationReady ? locState.location : null;

    // Nearby path: PostGIS RPC filtered by the active location + radius.
    // While the filter is on but location isn't ready (locating/denied),
    // fall back to the unfiltered list.
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
        loading: _loading,
        error: (_, __) => _error(context, ref),
        data: (venues) => venues.isEmpty
            ? _empty(
                context,
                hint: l.listing_venues_radius_text(
                  (location.nearbyRadiusMeters / 1000).round(),
                ),
              )
            : _cards(
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
                        sports: v.sportNames,
                      ),
                    )
                    .toList(),
              ),
      );
    }

    final filters = VenuesBySportFilters(sportId: sportId, isActive: true);
    final venuesAsync = ref.watch(venuesBySportWithFiltersProvider(filters));

    return venuesAsync.when(
      loading: _loading,
      error: (_, __) => _error(context, ref),
      data: (venues) => venues.isEmpty
          ? _empty(context)
          : _cards(
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
                      sports: [sport.localizedName(context)],
                      amenities: v.amenities,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _loading() =>
      const ListingSkeletons(kind: DabblerListingSkeletonKind.venue);

  Widget _error(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: ListingLayout.gutter,
    ),
    child: Center(
      child: DabblerEmptyState.error(
        title: AppLocalizations.of(context).listing_load_venues_failed,
        size: DabblerEmptyStateSize.inline,
        onRetry: () {
          ref.invalidate(nearbyVenuesProvider);
          ref.invalidate(venuesBySportWithFiltersProvider);
        },
        retryLabel: AppLocalizations.of(context).feed_retry,
      ),
    ),
  );

  Widget _empty(BuildContext context, {String? hint}) => ListingEmpty(
    // `Listings.dc.html:740` — the bold location glyph.
    icon: 'location',
    title: AppLocalizations.of(context).listing_venues_none_title,
    text: hint ?? AppLocalizations.of(context).listing_venues_none_text,
    action: DabblerButton(
      label: AppLocalizations.of(context).listing_change_filters,
      onPressed: onChangeFilters,
    ),
  );

  Widget _cards(WidgetRef ref, List<_VenueCardData> venues) {
    return DabblerRefresh(
      onRefresh: () async {
        ref.invalidate(nearbyVenuesProvider);
        ref.invalidate(venuesBySportWithFiltersProvider);
      },
      child: ListView(
        padding: ListingLayout.listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < venues.length; i++) ...[
            if (i > 0) const DabblerGap.v(ListingLayout.venueCardGap),
            _VenueCard(venue: venues[i]),
          ],
        ],
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
    this.sports = const [],
    this.amenities = const [],
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

  /// The sports the venue is listed under.
  final List<String> sports;

  /// Raw amenity names; the ones with a glyph show as facilities.
  final List<String> amenities;
}

/// A venue on the design system's venue card (`Listings.dc.html:750-820`).
/// The app has no venue photo, rating, review count or status badges ("Top
/// rated", "Instant booking"), so the card draws no cover, no rating and no
/// badges — the frame's photo-less card (`v.hasPhoto` false); the favourite
/// heart toggles `venue_favorites`.
class _VenueCard extends ConsumerStatefulWidget {
  const _VenueCard({required this.venue});

  final _VenueCardData venue;

  @override
  ConsumerState<_VenueCard> createState() => _VenueCardState();
}

class _VenueCardState extends ConsumerState<_VenueCard> {
  bool? _optimistic;
  bool _busy = false;

  Future<void> _toggle(bool currently) async {
    if (_busy) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) return;
    setState(() {
      _busy = true;
      _optimistic = !currently;
    });
    final repository = ref.read(games_providers.venuesRepositoryProvider);
    final result = await repository.toggleVenueFavorite(
      widget.venue.id,
      userId,
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _busy = false;
        _optimistic = currently;
      }),
      (_) {
        ref.invalidate(favoriteVenuesForCurrentUserProvider);
        ref.invalidate(favoriteVenueIdsForCurrentUserProvider);
        setState(() {
          _busy = false;
          _optimistic = null;
        });
      },
    );
  }

  /// Amenity text → the design's facility glyph; unknown amenities draw none.
  static const Map<String, String> _amenityIcons = {
    'park': 'car',
    'shower': 'drop',
    'locker': 'lock',
    'changing': 'lock',
    'cafe': 'cup',
    'coffee': 'cup',
    'light': 'flash',
    'shop': 'shop',
  };

  static String? _iconFor(String amenity) {
    final a = amenity.toLowerCase();
    for (final e in _amenityIcons.entries) {
      if (a.contains(e.key)) return e.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final venue = widget.venue;
    final favIds = ref
        .watch(favoriteVenueIdsForCurrentUserProvider)
        .maybeWhen(data: (ids) => ids, orElse: () => <String>{});
    final isFav = _optimistic ?? favIds.contains(venue.id);

    final locationLine = [
      if (venue.area?.isNotEmpty == true) venue.area!,
      venue.city,
    ].join(', ');

    final String? priceLabel = venue.pricePerHour == null
        ? null
        : (venue.pricePerHour! > 0
              ? l.listing_price_per_hour(venue.pricePerHour!.toStringAsFixed(0))
              : l.listing_free);

    return DabblerCardVenue(
      name: venue.name,
      area: locationLine,
      tags: [
        if (venue.distanceLabel != null)
          DabblerCardVenue.distanceTag(
            label: l.listing_km_away(venue.distanceLabel!),
          ),
        // The setting, as the meetup card tags it (`Listings.dc.html:1866`).
        if (venue.isIndoor != null)
          DabblerListingTag(
            label: venue.isIndoor! ? l.listing_indoor : l.listing_outdoor,
            tone: DabblerListingTagTone.brandTint,
          ),
      ],
      sports: [
        for (final s in venue.sports) DabblerListingTag.outlined(label: s),
      ],
      facilities: [
        for (final a in venue.amenities)
          if (_iconFor(a) != null)
            DabblerCardVenue.facility(icon: _iconFor(a)!, label: a),
      ],
      favourite: DabblerFavouriteButton(
        selected: isFav,
        semanticLabel: isFav ? l.listing_remove_saved : l.listing_save_venue,
        onPressed: _busy ? null : () => _toggle(isFav),
      ),
      price: priceLabel,
      priceCaption: priceLabel == null ? null : l.listing_starting_from,
      trailing: DabblerButton(
        label: l.listing_view_venue,
        onPressed: () => context.push(RoutePaths.venueDetail(venue.id)),
      ),
      onTap: () => context.push(RoutePaths.venueDetail(venue.id)),
      semanticLabel: venue.name,
    );
  }
}

import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_chips.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_scaffold.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart'
    show formatDistanceMeters;
import 'package:dabbler/features/venues/domain/venue_listing_filters.dart';
import 'package:dabbler/features/venues/presentation/providers/nearby_venues_provider.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/providers.dart' hide nearbyVenuesProvider;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
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
    ref.read(nearbyVenueSortProvider.notifier).state = VenueSortOrder.distance;
    ref.read(venueIndoorFilterProvider.notifier).state = null;
    ref.read(venueMaxPriceFilterProvider.notifier).state = null;
    ref.read(venueMinRatingFilterProvider.notifier).state = null;
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
    final indoor = ref.watch(venueIndoorFilterProvider);
    final maxPrice = ref.watch(venueMaxPriceFilterProvider);
    final minRating = ref.watch(venueMinRatingFilterProvider);
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
      if (indoor != null)
        DabblerFilterRailItem(
          label: indoor ? l.listing_indoor : l.listing_outdoor,
          onRemove: () =>
              ref.read(venueIndoorFilterProvider.notifier).state = null,
        ),
      if (maxPrice != null)
        DabblerFilterRailItem(
          label: l.listing_price_up_to(maxPrice.toStringAsFixed(0)),
          onRemove: () =>
              ref.read(venueMaxPriceFilterProvider.notifier).state = null,
        ),
      if (minRating != null)
        DabblerFilterRailItem(
          label: l.listing_rating_and_up(minRating.toStringAsFixed(1)),
          onRemove: () =>
              ref.read(venueMinRatingFilterProvider.notifier).state = null,
        ),
      if (sort != VenueSortOrder.distance)
        DabblerFilterRailItem(
          label: _sortLabel(l, sort),
          onRemove: () => ref.read(nearbyVenueSortProvider.notifier).state =
              VenueSortOrder.distance,
        ),
    ];

    return DabblerPage(
      body: sports.isEmpty
          ? const SizedBox.shrink()
          : ListingScaffold(
              head: DabblerListingHead.tint,
              header: DabblerPageHeader(
                safeArea: false,
                contentPadding: DabblerPageHeader.listingVenuesPadding,
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
                      onPressed: () =>
                          context.push(RoutePaths.createVenueSubmission),
                    ),
                  DabblerPageHeaderAction(
                    icon: 'heart',
                    semanticLabel: l.fav_title,
                    onPressed: () => context.push(
                      '${RoutePaths.favourites}?tab=${FavouriteKind.venue.name}',
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
                for (final sport in sports)
                  DabblerTabItem(
                    id: sport.id,
                    label: sport.localizedName(context),
                  ),
              ],
              filters: active,
              clearAllLabel: l.listing_clear_all,
              onClearAll: _resetFilters,
              pages: [for (final sport in sports) _AllVenuesList(sport: sport)],
            ),
    );
  }
}

// =============================================================================
// FILTER SHEET
// =============================================================================

String _sortLabel(AppLocalizations l, VenueSortOrder sort) => switch (sort) {
  VenueSortOrder.distance => l.listing_venue_sort_distance,
  VenueSortOrder.rating => l.listing_venue_sort_rating,
  VenueSortOrder.price => l.listing_venue_sort_price,
};

/// The venues filter groups (`Listings.dc.html:1832-1839`): Distance,
/// Indoor / outdoor, Price per hour, Rating and Sort by.
class _VenuesFilterBody extends ConsumerWidget {
  const _VenuesFilterBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final indoor = ref.watch(venueIndoorFilterProvider);
    final maxPrice = ref.watch(venueMaxPriceFilterProvider);
    final minRating = ref.watch(venueMinRatingFilterProvider);
    final sort = ref.watch(nearbyVenueSortProvider);
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
          label: l.listing_group_setting,
          children: [
            for (final value in const [true, false])
              DabblerChip(
                label: value ? l.listing_indoor : l.listing_outdoor,
                selected: indoor == value,
                onTap: () =>
                    ref.read(venueIndoorFilterProvider.notifier).state =
                        indoor == value ? null : value,
              ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_price_hour,
          children: [
            for (final price in kVenueMaxPricePresets)
              DabblerChip(
                label: l.listing_price_up_to(price.toStringAsFixed(0)),
                selected: maxPrice == price,
                onTap: () =>
                    ref.read(venueMaxPriceFilterProvider.notifier).state =
                        price,
              ),
            DabblerChip(
              label: l.listing_any_price,
              selected: maxPrice == null,
              onTap: () =>
                  ref.read(venueMaxPriceFilterProvider.notifier).state = null,
            ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_rating,
          children: [
            for (final rating in kVenueMinRatingPresets)
              DabblerChip(
                label: l.listing_rating_and_up(rating.toStringAsFixed(1)),
                selected: minRating == rating,
                onTap: () =>
                    ref.read(venueMinRatingFilterProvider.notifier).state =
                        minRating == rating ? null : rating,
              ),
          ],
        ),
        DabblerFilterGroup(
          label: l.listing_group_sort,
          children: [
            for (final value in VenueSortOrder.values)
              DabblerChip(
                label: _sortLabel(l, value),
                selected: sort == value,
                onTap: () =>
                    ref.read(nearbyVenueSortProvider.notifier).state = value,
              ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// ALL VENUES LIST
// =============================================================================

class _AllVenuesList extends ConsumerWidget {
  const _AllVenuesList({required this.sport});

  final Sport sport;

  String get sportId => sport.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final nearbyEnabled = ref.watch(nearbyVenuesFilterEnabledProvider);
    final locState = ref.watch(activeLocationProvider).valueOrNull;
    final location = locState is ActiveLocationReady ? locState.location : null;
    final sort = ref.watch(nearbyVenueSortProvider);
    final indoor = ref.watch(venueIndoorFilterProvider);
    final maxPrice = ref.watch(venueMaxPriceFilterProvider);
    final minRating = ref.watch(venueMinRatingFilterProvider);

    // Nearby path: PostGIS RPC filtered by the active location + radius.
    // While the filter is on but location isn't ready (locating/denied),
    // fall back to the unfiltered list.
    if (nearbyEnabled && location != null) {
      final params = (
        lat: location.lat,
        lng: location.lng,
        radiusMeters: location.nearbyRadiusMeters,
        sportId: sportId,
        sortOrder: sort,
        indoor: indoor,
        maxPrice: maxPrice,
        minRating: minRating,
      );
      final nearbyAsync = ref.watch(nearbyVenuesProvider(params));

      return nearbyAsync.when(
        loading: _loading,
        error: (_, __) => _error(context, ref),
        data: (venues) => venues.isEmpty
            ? _empty(
                context,
                ref,
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
                        name: isArabic && (v.nameAr?.isNotEmpty ?? false)
                            ? v.nameAr!
                            : v.nameEn,
                        city: v.city,
                        area: v.area,
                        pricePerHour: v.pricePerHour,
                        isIndoor: v.isIndoor,
                        // KAN-446: missing coordinates read as unavailable.
                        distanceLabel: v.latitude == null || v.longitude == null
                            ? null
                            : v.distanceLabel,
                        sports: _sportNames(isArabic, v.sports, v.sportsAr),
                        amenities: v.amenities,
                        coverUrl: v.coverUrl,
                        rating: v.rating,
                        ratingCount: v.ratingCount,
                        isVerified: v.isVerified,
                        isOpenNow: v.isOpenNow,
                        favoriteCount: v.favoriteCount,
                        favouritedByMe: v.favouritedByMe,
                      ),
                    )
                    .toList(),
              ),
      );
    }

    final filters = VenuesBySportFilters(
      sportId: sportId,
      isActive: true,
      isIndoor: indoor,
      maxPrice: maxPrice,
      minRating: minRating,
      sortOrder: sort,
      limit: 200,
    );
    final venuesAsync = ref.watch(venuesBySportWithFiltersProvider(filters));

    return venuesAsync.when(
      loading: _loading,
      error: (_, __) => _error(context, ref),
      data: (rows) {
        // The view has one row per venue and sport setting; keep the first.
        final seen = <String>{};
        final venues = [
          for (final v in rows)
            if (seen.add(v.id)) v,
        ];
        double? metres(VenueWithSportModel v) =>
            location == null || v.latitude == null || v.longitude == null
            ? null
            : haversineMeters(
                location.lat,
                location.lng,
                v.latitude!,
                v.longitude!,
              );
        if (sort == VenueSortOrder.distance && location != null) {
          venues.sort(
            (a, b) => (metres(a) ?? double.infinity).compareTo(
              metres(b) ?? double.infinity,
            ),
          );
        }
        if (venues.isEmpty) return _empty(context, ref);
        return _cards(
          ref,
          venues.map((v) {
            final m = metres(v);
            return _VenueCardData(
              id: v.id,
              name: isArabic && (v.nameAr?.isNotEmpty ?? false)
                  ? v.nameAr!
                  : v.nameEn,
              city: v.city,
              area: v.area,
              pricePerHour: v.pricePerHour,
              isIndoor: v.isIndoor,
              distanceLabel: m == null ? null : formatDistanceMeters(m),
              sports: _sportNames(isArabic, v.sports, v.sportsAr),
              amenities: v.amenities,
              coverUrl: v.coverUrl,
              rating: v.rating,
              ratingCount: v.ratingCount,
              isVerified: v.isVerified,
              isOpenNow: v.isOpenNow,
              favoriteCount: v.favoriteCount,
              favouritedByMe: v.favouritedByMe,
            );
          }).toList(),
        );
      },
    );
  }

  static List<String> _sportNames(
    bool isArabic,
    List<String> en,
    List<String> ar,
  ) => isArabic && ar.isNotEmpty ? ar : en;

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

  Widget _empty(BuildContext context, WidgetRef ref, {String? hint}) =>
      ListingEmpty(
        // `Listings.dc.html:740` — the bold location glyph.
        icon: 'location',
        title: AppLocalizations.of(context).listing_venues_none_title,
        // With a filter applied the useful advice is to loosen it, not to try
        // another sport.
        text: _filtersApplied(ref)
            ? AppLocalizations.of(context).listing_venues_none_filters_text
            : hint ?? AppLocalizations.of(context).listing_venues_none_text,
        action: DabblerButton(
          label: AppLocalizations.of(context).listing_expand_search,
          onPressed: () => _expandSearch(ref),
        ),
      );

  bool _filtersApplied(WidgetRef ref) =>
      ref.read(venueIndoorFilterProvider) != null ||
      ref.read(venueMaxPriceFilterProvider) != null ||
      ref.read(venueMinRatingFilterProvider) != null;

  /// "Expand search area" (`Listings.dc.html:760`): widens the radius to the
  /// next step while the distance filter is on; otherwise (nothing to widen)
  /// it clears the indoor, price and rating filters that narrowed the list.
  void _expandSearch(WidgetRef ref) {
    final enabled = ref.read(nearbyVenuesFilterEnabledProvider);
    final radius = ref.read(nearbyRadiusProvider);
    final next = enabled ? nextVenueRadius(radius) : null;
    if (next != null) {
      ref.read(activeLocationProvider.notifier).setRadiusOverride(next);
      return;
    }
    ref.read(venueIndoorFilterProvider.notifier).state = null;
    ref.read(venueMaxPriceFilterProvider.notifier).state = null;
    ref.read(venueMinRatingFilterProvider.notifier).state = null;
  }

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
    this.coverUrl,
    this.rating,
    this.ratingCount = 0,
    this.isVerified = false,
    this.isOpenNow = false,
    this.favoriteCount = 0,
    this.favouritedByMe = false,
  });

  final String id;
  final String name;
  final String city;
  final String? area;
  final double? pricePerHour;
  final bool? isIndoor;

  /// Formatted distance (e.g. "1.2 km"); null when there is no ready active
  /// location or the venue lacks a coordinate (the card then shows
  /// "Distance unavailable").
  final String? distanceLabel;

  /// The sports the venue is listed under.
  final List<String> sports;

  /// `amenities_catalog` keys; the ones with a glyph show as facilities.
  final List<String> amenities;

  final String? coverUrl;

  /// Aggregate rating (null: not rated yet) and its review count.
  final double? rating;
  final int ratingCount;
  final bool isVerified;
  final bool isOpenNow;

  /// `favorites` rows for the venue, and whether the viewer has one.
  final int favoriteCount;
  final bool favouritedByMe;
}

/// A venue on the design system's venue card (`Listings.dc.html:750-820`):
/// the 170px cover (a placeholder until the venue has a photo), the aggregate
/// rating, the "Top rated" / "Verified" / "Open now" badges, the distance chip,
/// every sport and the keyed facilities; the heart toggles the favourite
/// (`toggle_favorite`, `favorites` table) and the share glyph shares the
/// venue's link.
class _VenueCard extends ConsumerStatefulWidget {
  const _VenueCard({required this.venue});

  final _VenueCardData venue;

  @override
  ConsumerState<_VenueCard> createState() => _VenueCardState();
}

class _VenueCardState extends ConsumerState<_VenueCard> {
  /// The favourite as the viewer sees it: set on a tap (optimistic), and back
  /// to the previous state if the toggle fails. Null: the list's own.
  ({int count, bool mine})? _favourite;
  bool _busy = false;

  Future<void> _toggle(({int count, bool mine}) current) async {
    if (_busy) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) return;
    setState(() {
      _busy = true;
      _favourite = (
        count: current.mine
            ? (current.count > 0 ? current.count - 1 : 0)
            : current.count + 1,
        mine: !current.mine,
      );
    });
    final repository = ref.read(games_providers.venuesRepositoryProvider);
    final result = await repository.toggleVenueFavorite(widget.venue.id);
    if (!mounted) return;
    result.fold(
      (_) {
        setState(() {
          _busy = false;
          _favourite = current;
        });
        showFavouriteToast(context, FavouriteKind.venue, added: null);
      },
      (favourited) {
        ref.invalidate(favoriteVenuesForCurrentUserProvider);
        ref.invalidate(favoriteVenueIdsForCurrentUserProvider);
        // Reconcile with the server's `favourited`: the count follows it.
        final base = current.mine ? current.count - 1 : current.count;
        setState(() {
          _busy = false;
          _favourite = (
            count: favourited
                ? (base < 0 ? 0 : base) + 1
                : (base < 0 ? 0 : base),
            mine: favourited,
          );
        });
        showFavouriteToast(context, FavouriteKind.venue, added: favourited);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final venue = widget.venue;
    final fav =
        _favourite ?? (count: venue.favoriteCount, mine: venue.favouritedByMe);
    final colors = DabblerColors.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final catalog = ref
        .watch(venueAmenityCatalogProvider)
        .maybeWhen(
          data: (c) => c,
          orElse: () => const <String, VenueAmenityLabel>{},
        );
    final rating = venue.rating;
    final rated = rating != null && venue.ratingCount > 0;

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
      // The cover slot always draws; without a photo it is the sunken fill
      // with the gallery glyph.
      cover: DabblerImage(
        url: venue.coverUrl,
        height: DabblerCardVenue.coverHeight,
        radius: BorderRadius.zero,
        placeholderGlyph: true,
      ),
      area: locationLine,
      tags: [
        // KAN-446: the tag always shows; without a distance it says so.
        DabblerCardVenue.distanceTag(
          label: venue.distanceLabel == null
              ? l.listing_distance_unavailable
              : l.listing_km_away(venue.distanceLabel!),
        ),
        if (rated)
          DabblerCardVenue.rating(
            rating: rating.toStringAsFixed(1),
            reviews: l.listing_reviews_count(venue.ratingCount.toString()),
          ),
        if (rated && rating >= kVenueTopRated)
          DabblerBadge(
            label: l.listing_badge_top_rated,
            status: colors.warning,
            tone: DabblerBadgeTone.warning,
          ),
        if (venue.isVerified)
          DabblerBadge(
            label: l.listing_badge_verified,
            status: colors.success,
            tone: DabblerBadgeTone.success,
          ),
        if (venue.isOpenNow)
          DabblerBadge(
            label: l.listing_badge_open_now,
            status: colors.info,
            tone: DabblerBadgeTone.info,
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
        for (final key in venue.amenities)
          if (kVenueAmenityIcons[key] != null)
            DabblerCardVenue.facility(
              icon: kVenueAmenityIcons[key]!,
              label: isArabic
                  ? (catalog[key]?.ar ?? catalog[key]?.en ?? key)
                  : (catalog[key]?.en ?? key),
            ),
      ],
      // The heart alone (Listings 2026-10-08b `:795-799`): no chip, no count,
      // no share; red and bold when favourited.
      favourite: DabblerFeedAction(
        icon: 'heart',
        metrics: DabblerFeedMetrics.drawn,
        weight: fav.mine ? DabblerIconWeight.bold : DabblerIconWeight.linear,
        color: fav.mine ? colors.error.base : null,
        semanticLabel: fav.mine ? l.listing_remove_saved : l.listing_save_venue,
        onTap: _busy ? null : () => _toggle(fav),
      ),
      price: priceLabel,
      priceCaption: priceLabel == null ? null : l.listing_starting_from,
      // The button leads the price row (`:836-840`).
      actionFirst: true,
      trailing: DabblerButton(
        label: l.listing_view_venue,
        onPressed: () => context.push(RoutePaths.venueDetail(venue.id)),
      ),
      onTap: () => context.push(RoutePaths.venueDetail(venue.id)),
      semanticLabel: venue.name,
    );
  }
}

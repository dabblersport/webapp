/// KAN-629 Route 2: Places API (New) Place Details with a Dabbler-styled card.
///
/// Prepared and NOT live: nothing here makes a network call. Place Details and
/// Place Photos quotas for the experiment project are 0, so any live source
/// would be refused by Google. [PlacesDetailsSource.disabled] is the only
/// implementation on this branch; it never reaches the network, so with the
/// experiment flag off (the default) or on, no Place Details request exists.
///
/// Terms (Google Maps Platform, read 2026-10-23): only the place ID may be
/// stored; every other Places field and photo must be fetched live for the
/// view and never cached, mirrored or copied to another store. The Google
/// Maps logo (or the text "Google Maps") must be shown when Places data
/// appears without a Google map, photo authors are credited, and each photo
/// links back through its `googleMapsUri`.
library;

/// Field mask for one Place Details request. Billing is at the highest SKU in
/// the mask: `rating`, `userRatingCount` and `currentOpeningHours` are
/// Enterprise, `displayName` and `googleMapsUri` are Pro, `photos` metadata is
/// Essentials IDs Only.
const String kPlacesDetailsFieldMask =
    'id,displayName,rating,userRatingCount,currentOpeningHours.openNow,'
    'googleMapsUri,photos.name,photos.widthPx,photos.heightPx,'
    'photos.authorAttributions,photos.googleMapsUri';

/// One author credit for a photo.
class PlacesPhotoAttribution {
  const PlacesPhotoAttribution({
    required this.displayName,
    this.uri,
    this.photoUri,
  });

  final String displayName;
  final String? uri;
  final String? photoUri;
}

/// A Google photo reference: the media is fetched live from [mediaName] and is
/// never stored.
class PlacesPhotoRef {
  const PlacesPhotoRef({
    required this.mediaName,
    required this.attributions,
    this.googleMapsUri,
  });

  final String mediaName;
  final List<PlacesPhotoAttribution> attributions;
  final String? googleMapsUri;
}

/// The Google fields a Dabbler card can show. Held in memory for the view only.
class PlacesDetails {
  const PlacesDetails({
    required this.placeId,
    this.name,
    this.rating,
    this.userRatingCount,
    this.openNow,
    this.googleMapsUri,
    this.photo,
  });

  final String placeId;
  final String? name;
  final double? rating;
  final int? userRatingCount;
  final bool? openNow;
  final String? googleMapsUri;
  final PlacesPhotoRef? photo;
}

/// Where a card gets Google details from.
abstract class PlacesDetailsSource {
  const PlacesDetailsSource();

  /// Never reaches the network and always answers null.
  const factory PlacesDetailsSource.disabled() = _DisabledPlacesDetailsSource;

  Future<PlacesDetails?> fetch(String placeId);
}

class _DisabledPlacesDetailsSource extends PlacesDetailsSource {
  const _DisabledPlacesDetailsSource();

  @override
  Future<PlacesDetails?> fetch(String placeId) async => null;
}

/// Cost model for the Route 2 request pattern (USD list prices, read
/// 2026-10-23): one Enterprise Place Details request plus one Place Details
/// Photos request per venue per live view, nothing cached.
class PlacesRoute2Cost {
  const PlacesRoute2Cost._();

  static const int enterpriseFreePerMonth = 1000;
  static const int photosFreePerMonth = 1000;
  static const double enterprisePer1000 = 20;
  static const double photosPer1000 = 7;

  /// Monthly spend for [venues] per view and [views] views a month.
  static double monthlyUsd({required int venues, required int views}) {
    final calls = venues * views;
    final details = (calls - enterpriseFreePerMonth).clamp(0, calls);
    final photos = (calls - photosFreePerMonth).clamp(0, calls);
    return details * enterprisePer1000 / 1000 + photos * photosPer1000 / 1000;
  }

  /// The largest daily request count that stays inside both free allowances
  /// over a 30-day month, i.e. the quota number that keeps the bill at USD 0.
  static int get zeroCostDailyQuota =>
      (enterpriseFreePerMonth < photosFreePerMonth
          ? enterpriseFreePerMonth
          : photosFreePerMonth) ~/
      30;
}

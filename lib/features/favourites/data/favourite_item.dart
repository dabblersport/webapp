import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';

/// One favourited venue, game or meetup as the Favourites screen lists it:
/// just what its row says, read from the type's listing view.
class FavouriteItem {
  const FavouriteItem({
    required this.id,
    required this.kind,
    required this.title,
    this.titleAr,
    this.area,
    this.rating,
    this.latitude,
    this.longitude,
    this.place,
    this.startAt,
    this.endAt,
    this.playersIn,
    this.capacity,
    this.going,
    this.cancelled = false,
  });

  final String id;
  final FavouriteKind kind;
  final String title;

  /// A venue's Arabic name; other kinds have one title.
  final String? titleAr;

  /// Venue: the neighbourhood (or city).
  final String? area;

  /// Venue: the average rating, null when unrated.
  final double? rating;

  /// Venue: where it is, for the distance from the viewer.
  final double? latitude;
  final double? longitude;

  /// Game: the venue; meetup: the place.
  final String? place;

  /// Game / meetup start and end.
  final DateTime? startAt;
  final DateTime? endAt;

  /// Game: players in and capacity; meetup: how many are going.
  final int? playersIn;
  final int? capacity;
  final int? going;

  final bool cancelled;

  String name(String languageCode) {
    final ar = titleAr;
    return languageCode == 'ar' && ar != null && ar.trim().isNotEmpty
        ? ar
        : title;
  }

  /// Ended: cancelled, or past its end (its start when it has no end). Venues
  /// never end.
  bool endedAt(DateTime now) {
    if (kind == FavouriteKind.venue) return false;
    if (cancelled) return true;
    final end = endAt ?? startAt;
    return end != null && end.isBefore(now);
  }
}

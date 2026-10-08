import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';

/// The games listing's derived copy and card status, kept out of the screen so
/// each rule is testable on its own (`Listings.2026-10-08.dc.html`).

/// The sort's chip label, in the filter sheet and in the applied rail.
String gamesSortLabel(AppLocalizations l, NearbySortOrder o) => switch (o) {
  NearbySortOrder.nearest => l.listing_sort_nearest,
  NearbySortOrder.defaultOrder => l.listing_sort_soonest,
};

/// The empty state's text (`Listings.2026-10-08.dc.html:212`: "Nothing within
/// 5 km in the next 3 days. Widen the date or sport."), naming the radius when
/// the distance filter is on ([radiusMeters] non-null) and the date window
/// when a date filter is on. With neither (a skill filter alone), a general
/// line.
String gamesEmptyText(
  AppLocalizations l, {
  required int? radiusMeters,
  required GamesDateFilter date,
}) {
  final String? window = switch (date) {
    GamesDateFilter.any => null,
    GamesDateFilter.today => l.listing_window_today,
    GamesDateFilter.tomorrow => l.listing_window_tomorrow,
    GamesDateFilter.thisWeek => l.listing_window_days(7),
    GamesDateFilter.thisWeekend => l.listing_window_weekend,
  };
  final int? km = radiusMeters == null ? null : (radiusMeters / 1000).round();
  if (km != null && window != null) {
    return l.listing_games_empty_radius_window(km, window);
  }
  if (km != null) return l.listing_games_empty_radius(km);
  if (window != null) return l.listing_games_empty_window(window);
  return l.listing_games_empty_fallback;
}

/// What a game card's players bar says, most urgent first.
enum GamesCardStatus { full, startsSoon, almostFull, open }

/// Under this many minutes before the start, a game "Starts soon".
const int kGamesStartsSoonMinutes = 60;

/// The card's status: full, then starting within [kGamesStartsSoonMinutes]
/// (client side, from the start time), then two or fewer spots, else open.
GamesCardStatus gamesCardStatus({
  required int spotsRemaining,
  required DateTime? startsAt,
  required DateTime now,
}) {
  if (spotsRemaining <= 0) return GamesCardStatus.full;
  if (startsAt != null) {
    final Duration left = startsAt.difference(now);
    if (!left.isNegative && left.inMinutes < kGamesStartsSoonMinutes) {
      return GamesCardStatus.startsSoon;
    }
  }
  if (spotsRemaining <= 2) return GamesCardStatus.almostFull;
  return GamesCardStatus.open;
}

/// The players bar's note for [status].
String gamesStatusNote(
  AppLocalizations l,
  GamesCardStatus status,
  int spotsRemaining,
) => switch (status) {
  GamesCardStatus.full => l.listing_full,
  GamesCardStatus.startsSoon => l.listing_starts_soon,
  GamesCardStatus.almostFull => l.listing_spots_almost_full(spotsRemaining),
  GamesCardStatus.open => l.listing_spots_left(spotsRemaining),
};

/// The players bar's tone (`Listings.2026-10-08.dc.html:1891,1895,1899`):
/// info while there is room, warning when almost full, error when full or
/// starting soon.
DabblerProgressBarTone gamesStatusTone(GamesCardStatus status) =>
    switch (status) {
      GamesCardStatus.full => DabblerProgressBarTone.error,
      GamesCardStatus.startsSoon => DabblerProgressBarTone.error,
      GamesCardStatus.almostFull => DabblerProgressBarTone.warning,
      GamesCardStatus.open => DabblerProgressBarTone.info,
    };

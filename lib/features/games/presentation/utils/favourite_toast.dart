import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// What a favourite heart was tapped on; names the toast's subject.
enum FavouriteKind { game, venue, meetup }

/// The toast's words and tone for a favourite toggle (CEO 2026-10-08): added is
/// a success, removed is neutral, and [added] null (the toggle failed) is the
/// error, whatever the kind.
DabblerToastSpec favouriteToastSpec(
  AppLocalizations l,
  FavouriteKind kind,
  bool? added,
) {
  if (added == null) {
    return DabblerToastSpec(
      message: l.fav_toast_error,
      tone: DabblerToastTone.error,
    );
  }
  final message = switch ((kind, added)) {
    (FavouriteKind.game, true) => l.fav_toast_game_added,
    (FavouriteKind.game, false) => l.fav_toast_game_removed,
    (FavouriteKind.venue, true) => l.fav_toast_venue_added,
    (FavouriteKind.venue, false) => l.fav_toast_venue_removed,
    (FavouriteKind.meetup, true) => l.fav_toast_meetup_added,
    (FavouriteKind.meetup, false) => l.fav_toast_meetup_removed,
  };
  return DabblerToastSpec(
    message: message,
    tone: added ? DabblerToastTone.success : DabblerToastTone.neutral,
  );
}

/// Shows the favourite toast on the app's toast host. [added] is the server's
/// answer (`favourited`), or null when the toggle failed. Does nothing when
/// [context] is gone or no host is mounted.
void showFavouriteToast(
  BuildContext context,
  FavouriteKind kind, {
  required bool? added,
}) {
  if (!context.mounted) return;
  DabblerToastProvider.maybeOf(
    context,
  )?.show(favouriteToastSpec(AppLocalizations.of(context), kind, added));
}

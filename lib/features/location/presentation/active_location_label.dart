import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The text of every location chip (KAN-586): the area, the city alone after a
/// city change, "<area> · Last known" when Auto is unavailable, otherwise the
/// "Set location" prompt.
String activeLocationLabel(AppLocalizations l, ActiveLocationState? s) {
  if (s is ActiveLocationReady) {
    final String place = s.location.area.name;
    return s.location.source == ActiveLocationSource.lastKnown
        ? l.location_last_known_label(place)
        : place;
  }
  if (s is ActiveLocationCityOnly) return s.city;
  return l.listing_set_location;
}

/// Whether tapping the chip opens the manual "Set location" drawer rather than
/// the picker: denied, a city without an area, or a last-known location that
/// the user should change by hand. Never asks the OS for permission.
bool activeLocationNeedsManualChange(ActiveLocationState? s) =>
    s is ActiveLocationDenied ||
    s is ActiveLocationCityOnly ||
    (s is ActiveLocationReady &&
        s.location.source == ActiveLocationSource.lastKnown);

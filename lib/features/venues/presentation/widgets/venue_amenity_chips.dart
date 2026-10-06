import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// The normalised form of an amenity key: lower case, words split on `_`, `-`
/// or whitespace, joined by `_` (`Changing rooms` -> `changing_rooms`).
String normalizeAmenityKey(String key) => key
    .trim()
    .toLowerCase()
    .split(RegExp(r'[\s_\-]+'))
    .where((w) => w.isNotEmpty)
    .join('_');

/// The icon for an amenity key, from the design's facility set
/// (`Details.dc.html:896-903`: car, lock, drop, cup, flash, wifi). Keys the
/// design does not draw take the generic tick.
String amenityIconName(String key) {
  switch (normalizeAmenityKey(key)) {
    case 'parking':
    case 'free_parking':
      return 'car';
    case 'wifi':
      return 'wifi';
    case 'lighting':
    case 'floodlights':
      return 'flash';
    case 'gym':
      return 'activity';
    case 'restaurant':
    case 'cafe':
    case 'cafeteria':
    case 'snack_bar':
      return 'cup';
    case 'locker_rooms':
    case 'locker_room':
    case 'changing_rooms':
    case 'changing':
      return 'lock';
    case 'shower':
    case 'showers':
      return 'drop';
    default:
      return 'tick-circle';
  }
}

/// The human, localised name of an amenity key. An unknown key is humanised
/// (`some_new_thing` -> `Some new thing`), never shown raw.
String amenityLabel(AppLocalizations l10n, String key) {
  switch (normalizeAmenityKey(key)) {
    case 'outdoor':
      return l10n.venue_amenity_outdoor;
    case 'indoor':
      return l10n.venue_amenity_indoor;
    case 'parking':
    case 'free_parking':
      return l10n.venue_amenity_parking;
    case 'washrooms':
      return l10n.venue_amenity_washrooms;
    case 'changing_rooms':
    case 'changing':
      return l10n.venue_amenity_changing_rooms;
    case 'locker_room':
    case 'locker_rooms':
      return l10n.venue_amenity_locker_room;
    case 'shower':
    case 'showers':
      return l10n.venue_amenity_showers;
    case 'lighting':
    case 'floodlights':
      return l10n.venue_amenity_lighting;
    case 'cafeteria':
    case 'cafe':
    case 'restaurant':
    case 'snack_bar':
      return l10n.venue_amenity_cafeteria;
    case 'wifi':
      return l10n.venue_amenity_wifi;
    case 'first_aid':
      return l10n.venue_amenity_first_aid;
    case 'accessibility':
      return l10n.venue_amenity_accessibility;
    case 'gym':
      return l10n.venue_amenity_gym;
    case 'equipment_rental':
      return l10n.venue_amenity_equipment_rental;
    case 'air_conditioning':
      return l10n.venue_amenity_air_conditioning;
    case 'spectator_seating':
      return l10n.venue_amenity_spectator_seating;
    case 'vending':
      return l10n.venue_amenity_vending;
  }
  final words = normalizeAmenityKey(key).replaceAll('_', ' ');
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}

/// The venue Facilities chips: a wrapping run of static compact
/// [DabblerChip]s, a glyph before a human label (`Details.dc.html:441-449`).
class VenueAmenityChips extends StatelessWidget {
  const VenueAmenityChips({super.key, required this.amenities});

  final List<String> amenities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: DabblerSpacing.space3,
      runSpacing: DabblerSpacing.space3,
      children: [
        for (final a in amenities)
          DabblerChip(
            label: amenityLabel(l10n, a),
            compact: true,
            leadingIcon: DabblerIcon(amenityIconName(a)),
          ),
      ],
    );
  }
}

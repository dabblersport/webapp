import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Distance and Sort-by chip groups of the listing filter sheets
/// (`Listings.dc.html`, the `DISTANCE` group and the `Sort by` group).
///
/// Data and callbacks only: these return design-system chips, bound to the
/// listing's own enabled/sort providers and to the app-level active location.

/// The radius presets of the Distance group, in metres.
const List<int> kNearbyRadiusPresets = <int>[5000, 10000];

/// "Within N km" label for [meters].
String nearbyRadiusLabel(int meters) => 'Within ${(meters / 1000).round()} km';

/// "Within 5 km", "Within 10 km", "Any distance". Picking a preset turns the
/// nearby filter on at that radius; "Any distance" turns it off.
List<Widget> nearbyDistanceChips(
  WidgetRef ref,
  StateProvider<bool> enabledProvider,
) {
  final bool enabled = ref.watch(enabledProvider);
  final int radius = ref.watch(nearbyRadiusProvider);
  return <Widget>[
    for (final int meters in kNearbyRadiusPresets)
      DabblerChip(
        label: nearbyRadiusLabel(meters),
        selected: enabled && radius == meters,
        onTap: () {
          ref.read(enabledProvider.notifier).state = true;
          ref.read(activeLocationProvider.notifier).setRadiusOverride(meters);
        },
      ),
    DabblerChip(
      label: 'Any distance',
      selected: !enabled,
      onTap: () => ref.read(enabledProvider.notifier).state = false,
    ),
  ];
}

/// "Nearest" and "Starting soonest", bound to [sortProvider].
List<Widget> nearbySortChips(
  WidgetRef ref,
  StateProvider<NearbySortOrder> sortProvider,
) {
  final NearbySortOrder sort = ref.watch(sortProvider);
  return <Widget>[
    DabblerChip(
      label: 'Nearest',
      selected: sort == NearbySortOrder.nearest,
      onTap: () =>
          ref.read(sortProvider.notifier).state = NearbySortOrder.nearest,
    ),
    DabblerChip(
      label: 'Starting soonest',
      selected: sort == NearbySortOrder.defaultOrder,
      onTap: () =>
          ref.read(sortProvider.notifier).state = NearbySortOrder.defaultOrder,
    ),
  ];
}

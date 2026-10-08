import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/l10n/app_localizations.dart';
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
String nearbyRadiusLabel(AppLocalizations l, int meters) =>
    l.listing_within_km((meters / 1000).round());

/// "Within 5 km", "Within 10 km", "Any distance". Picking a preset turns the
/// nearby filter on at that radius; "Any distance" turns it off.
///
/// The radius is the active location's ([nearbyRadiusProvider]) unless the
/// listing keeps its own: then pass [radiusProvider] and the presets write
/// there instead of overriding the location's radius.
List<Widget> nearbyDistanceChips(
  BuildContext context,
  WidgetRef ref,
  StateProvider<bool> enabledProvider, {
  StateProvider<int>? radiusProvider,
}) {
  final AppLocalizations l = AppLocalizations.of(context);
  final bool enabled = ref.watch(enabledProvider);
  final StateProvider<int>? own = radiusProvider;
  final int radius = own != null
      ? ref.watch(own)
      : ref.watch(nearbyRadiusProvider);
  return <Widget>[
    for (final int meters in kNearbyRadiusPresets)
      DabblerChip(
        label: nearbyRadiusLabel(l, meters),
        selected: enabled && radius == meters,
        onTap: () {
          ref.read(enabledProvider.notifier).state = true;
          if (own != null) {
            ref.read(own.notifier).state = meters;
          } else {
            ref.read(activeLocationProvider.notifier).setRadiusOverride(meters);
          }
        },
      ),
    DabblerChip(
      label: l.listing_any_distance,
      selected: !enabled,
      onTap: () => ref.read(enabledProvider.notifier).state = false,
    ),
  ];
}

/// "Nearest" and "Starting soonest", bound to [sortProvider].
List<Widget> nearbySortChips(
  BuildContext context,
  WidgetRef ref,
  StateProvider<NearbySortOrder> sortProvider,
) {
  final AppLocalizations l = AppLocalizations.of(context);
  final NearbySortOrder sort = ref.watch(sortProvider);
  return <Widget>[
    DabblerChip(
      label: l.listing_sort_nearest,
      selected: sort == NearbySortOrder.nearest,
      onTap: () =>
          ref.read(sortProvider.notifier).state = NearbySortOrder.nearest,
    ),
    DabblerChip(
      label: l.listing_sort_soonest,
      selected: sort == NearbySortOrder.defaultOrder,
      onTap: () =>
          ref.read(sortProvider.notifier).state = NearbySortOrder.defaultOrder,
    ),
  ];
}

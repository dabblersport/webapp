import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/presentation/widgets/save_location_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';

/// The Saved places "add" flow (KAN-589), shared by Settings > Location and the
/// home location picker's "Add location".
///
/// Starts from this device's current location (no GPS read and no permission
/// request: the OS permission is asked once, elsewhere). With no point to start
/// from, the manual "Set location" drawer opens instead. The sheet searches any
/// place by name; no street address is asked for.
Future<void> startAddSavedPlace(BuildContext context, WidgetRef ref) async {
  final active = ref.read(activeLocationProvider).valueOrNull;
  if (active is! ActiveLocationReady) {
    await showSetLocationDrawer(context);
    return;
  }
  final ActiveLocation loc = active.location;
  final area = await ref.read(
    resolvedNearestAreaProvider((lat: loc.lat, lng: loc.lng)).future,
  );
  if (!context.mounted) return;
  if (area == null) {
    await showSetLocationDrawer(context);
    return;
  }
  await SaveLocationSheet.show(
    context,
    lat: loc.lat,
    lng: loc.lng,
    areaId: area.id,
    areaName: area.name,
  );
}

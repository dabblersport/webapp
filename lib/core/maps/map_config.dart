import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';

/// OSM standard tiles: free and keyless (T-100). Low traffic only.
const String kOsmTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// The app id sent as the tile User-Agent (T-100: a correct
/// `userAgentPackageName` is required by the OSM tile policy).
const String kMapUserAgentPackageName = 'app.dabbler.pro';

/// Dubai city centre: the map centre until the device has a location.
const LatLng kMapDefaultCentre = LatLng(25.2048, 55.2708);

/// Pan and zoom, no rotation, so north stays up.
const InteractionOptions kMapInteraction = InteractionOptions(
  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
);

/// Replaces the network [TileLayer] (tests stub tiles). Null in the app.
final mapTileLayerOverrideProvider = Provider<Widget Function()?>(
  (ref) => null,
);

/// The OSM tile layer every Dabbler map uses.
Widget osmTileLayer(Widget Function()? stub) {
  if (stub != null) return stub();
  return TileLayer(
    urlTemplate: kOsmTileUrlTemplate,
    userAgentPackageName: kMapUserAgentPackageName,
  );
}

/// Asks the OS for the device position once. `GpsService` goes through
/// `LocationPermissionState.requestOnce`, so the system prompt shows at most
/// once ever; a denial is returned, never re-asked (CEO 2026-10-13).
final mapLocatorProvider = Provider<Future<LocationResult> Function()>((ref) {
  final GpsService gps = ref.watch(gpsServiceProvider);
  return () => gps.getCurrentLocation(cap: GpsService.fixCap);
});

/// Opens the existing manual "Set location" drawer on a denied location.
final mapSetLocationOpenerProvider =
    Provider<Future<void> Function(BuildContext)>(
      (ref) => showSetLocationDrawer,
    );

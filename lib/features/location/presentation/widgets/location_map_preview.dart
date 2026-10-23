import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/config/mapbox_config.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Dubai city centre: the map centre while the device has no location yet.
const LatLng kDefaultMapCentre = LatLng(25.2048, 55.2708);

/// The Mapbox public token, from the same sources the place search uses.
String mapboxTileToken() {
  if (MapboxConfig.accessToken.isNotEmpty) return MapboxConfig.accessToken;
  try {
    return Environment.mapboxAccessToken;
  } catch (_) {
    return '';
  }
}

/// The Mapbox token the map uses. Tests override it.
final mapTokenProvider = Provider<String>((ref) => mapboxTileToken());

/// Replaces the network [TileLayer] (render tests stub tiles). Null in the app.
final mapTileLayerBuilderProvider = Provider<Widget Function()?>((ref) => null);

/// The map on Settings > Location (KAN-589). Always shown: centred on the
/// device's active location with a pin, or on [kDefaultMapCentre] with no pin
/// while there is none. With no Mapbox token it shows a "Map unavailable"
/// state instead of an empty box.
class LocationMapPreview extends ConsumerWidget {
  const LocationMapPreview({super.key});

  static const double _zoomPlace = 15;
  static const double _zoomDefault = 11;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final state = ref.watch(activeLocationProvider).valueOrNull;
    final String accessToken = ref.watch(mapTokenProvider);
    final tileLayerBuilder = ref.watch(mapTileLayerBuilderProvider);

    final LatLng? pin = state is ActiveLocationReady
        ? LatLng(state.location.lat, state.location.lng)
        : null;
    final LatLng centre = pin ?? kDefaultMapCentre;

    return DabblerSurface(
      radius: DabblerRadius.card,
      height: DabblerSizing.mediaPreviewHeight,
      child: accessToken.isEmpty
          ? Center(
              child: DabblerEmptyState(
                icon: 'location-slash',
                title: l10n.location_map_unavailable,
              ),
            )
          : FlutterMap(
              key: ValueKey('${centre.latitude},${centre.longitude}'),
              options: MapOptions(
                initialCenter: centre,
                initialZoom: pin != null ? _zoomPlace : _zoomDefault,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                if (tileLayerBuilder != null)
                  tileLayerBuilder()
                else
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token={accessToken}',
                    additionalOptions: {'accessToken': accessToken},
                    userAgentPackageName: 'com.dabbler.app',
                  ),
                if (pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pin,
                        width: DabblerSizing.iconLg,
                        height: DabblerSizing.iconLg,
                        child: DabblerIcon(
                          'location',
                          weight: DabblerIconWeight.bold,
                          color: colors.brandPrimary,
                          size: DabblerSizing.iconLg,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

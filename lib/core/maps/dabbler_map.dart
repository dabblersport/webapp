import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/core/maps/map_config.dart';
import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// One tappable pin on a [DabblerMap].
class DabblerMapMarker {
  const DabblerMapMarker({
    required this.id,
    required this.point,
    this.icon = 'location',
  });

  final String id;
  final LatLng point;
  final String icon;
}

/// The reusable Dabbler map (KAN-667): OSM tiles, a user-location marker,
/// tappable markers and the OSM attribution.
///
/// Location rule (CEO 2026-10-13): on mount the OS is asked once. A grant
/// centres the map on the user; a denial opens the existing manual
/// "Set location" drawer once and never re-prompts.
class DabblerMap extends ConsumerStatefulWidget {
  const DabblerMap({
    super.key,
    this.markers = const <DabblerMapMarker>[],
    this.onMarkerTap,
    this.showUserLocation = true,
    this.initialCenter = kMapDefaultCentre,
    this.initialZoom = 12,
    this.controller,
  });

  final List<DabblerMapMarker> markers;
  final ValueChanged<DabblerMapMarker>? onMarkerTap;

  /// When false the map neither locates the user nor opens the drawer.
  final bool showUserLocation;
  final LatLng initialCenter;
  final double initialZoom;
  final MapController? controller;

  @override
  ConsumerState<DabblerMap> createState() => _DabblerMapState();
}

class _DabblerMapState extends ConsumerState<DabblerMap> {
  static const double _zoomUser = 15;

  late final MapController _controller = widget.controller ?? MapController();
  LatLng? _user;
  bool _located = false;

  @override
  void initState() {
    super.initState();
    if (widget.showUserLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    }
  }

  Future<void> _locate() async {
    if (_located || !mounted) return;
    _located = true;
    final LocationResult result = await ref.read(mapLocatorProvider)();
    if (!mounted) return;
    if (result is LocationSuccess) {
      final LatLng user = LatLng(result.lat, result.lng);
      setState(() => _user = user);
      _controller.move(user, _zoomUser);
    } else if (result is LocationDenied ||
        result is LocationDeniedForever ||
        result is LocationServiceOff) {
      await ref.read(mapSetLocationOpenerProvider)(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget Function()? stub = ref.watch(mapTileLayerOverrideProvider);

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        interactionOptions: kMapInteraction,
      ),
      children: [
        osmTileLayer(stub),
        MarkerLayer(
          markers: [
            for (final DabblerMapMarker m in widget.markers)
              Marker(
                point: m.point,
                width: DabblerSizing.iconLg,
                height: DabblerSizing.iconLg,
                child: GestureDetector(
                  key: ValueKey('map-marker-${m.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onMarkerTap?.call(m),
                  child: DabblerIcon(
                    m.icon,
                    weight: DabblerIconWeight.bold,
                    color: colors.brandPrimary,
                    size: DabblerSizing.iconLg,
                  ),
                ),
              ),
            if (_user != null)
              Marker(
                point: _user!,
                width: DabblerSizing.iconLg,
                height: DabblerSizing.iconLg,
                child: DabblerIcon(
                  'gps',
                  weight: DabblerIconWeight.bold,
                  color: colors.textPrimary,
                  size: DabblerSizing.iconLg,
                  key: const ValueKey('map-user-marker'),
                ),
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: DabblerSurface(
            variant: DabblerSurfaceVariant.sunken,
            padding: const EdgeInsets.all(DabblerSpacing.space1),
            child: DabblerText(
              l10n.map_attribution_osm,
              style: DabblerType.caption1,
            ),
          ),
        ),
      ],
    );
  }
}

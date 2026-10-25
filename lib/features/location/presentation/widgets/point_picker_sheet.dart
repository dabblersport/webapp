import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/presentation/widgets/location_map_preview.dart';
import 'package:dabbler/features/location/presentation/widgets/location_search_field.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// "Set location" (KAN-589): pick a point, not a city. Search for a place, or
/// tap the map to move the pin; "Use this location" makes that point this
/// device's location. The city / area list is only the fallback the drawer
/// shows when location access is denied or unavailable.
///
/// Never asks the OS for permission on its own: "Use current location" does,
/// through the one-prompt rule inside the GPS service.
class PointPickerSheet extends ConsumerStatefulWidget {
  const PointPickerSheet({super.key});

  @override
  ConsumerState<PointPickerSheet> createState() => _PointPickerSheetState();
}

class _PointPickerSheetState extends ConsumerState<PointPickerSheet> {
  static const double _zoom = 14;

  final MapController _map = MapController();
  LatLng? _pin;
  String? _label;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final ActiveLocationState? s = ref.read(activeLocationProvider).valueOrNull;
    if (s is ActiveLocationReady) {
      _pin = LatLng(s.location.lat, s.location.lng);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _pick(LatLng point, {String? label}) {
    setState(() {
      _pin = point;
      _label = label;
    });
  }

  void _onSearch(MapboxPlace place) {
    final LatLng p = LatLng(place.lat, place.lng);
    _pick(p, label: place.name);
    _map.move(p, 15);
  }

  Future<void> _use() async {
    final LatLng? pin = _pin;
    if (pin == null || _busy) return;
    final toast = DabblerToastProvider.of(context);
    final l10n = AppLocalizations.of(context);
    final NavigatorState nav = Navigator.of(context);
    setState(() => _busy = true);
    await ref
        .read(activeLocationProvider.notifier)
        .useMapPoint(pin.latitude, pin.longitude, label: _label);
    if (!mounted) return;
    nav.pop();
    toast.show(
      DabblerToastSpec(
        message: l10n.manual_location_set_toast(
          _label ?? l10n.location_point_selected,
        ),
        tone: DabblerToastTone.success,
      ),
    );
  }

  Future<void> _useCurrent() async {
    if (_busy) return;
    final NavigatorState nav = Navigator.of(context);
    final BuildContext host = nav.context;
    final toast = DabblerToastProvider.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final AutoSwitchResult r = await ref
        .read(activeLocationProvider.notifier)
        .switchToAuto();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == AutoSwitchResult.applied) {
      nav.pop();
      return;
    }
    if (r == AutoSwitchResult.denied) {
      // Never re-prompts: the city / area list is the last fallback.
      nav.pop();
      if (host.mounted) await showSetLocationDrawer(host);
      return;
    }
    toast.show(DabblerToastSpec(message: l10n.location_timeout));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final String token = ref.watch(mapTokenProvider);
    final LatLng centre = _pin ?? kDefaultMapCentre;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerButton(
          label: l10n.location_use_current,
          icon: 'gps',
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          loading: _busy,
          disabled: _busy,
          onPressed: _useCurrent,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        LocationSearchField(
          hintText: l10n.saved_places_search_hint,
          proximity: centre,
          onSelected: _onSearch,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerSurface(
          radius: DabblerRadius.card,
          height: DabblerSizing.mediaPreviewHeight,
          child: token.isEmpty
              ? Center(
                  child: DabblerEmptyState(
                    icon: 'location-slash',
                    title: l10n.location_map_unavailable,
                  ),
                )
              : FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: centre,
                    initialZoom: _pin == null ? 11 : _zoom,
                    interactionOptions: kLocationMapInteraction,
                    onTap: (_, point) => _pick(point),
                  ),
                  children: [
                    mapboxTileLayer(
                      token,
                      ref.watch(mapTileLayerBuilderProvider),
                    ),
                    if (_pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pin!,
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
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerText(
          l10n.location_point_hint,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerButton(
          label: l10n.location_point_use,
          fullWidth: true,
          loading: _busy,
          disabled: _pin == null || _busy,
          onPressed: _use,
        ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}

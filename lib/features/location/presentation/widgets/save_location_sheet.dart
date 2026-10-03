import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/presentation/widgets/location_search_field.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';

/// Bottom sheet for saving or using a GPS-resolved location.
///
/// Usage:
/// ```dart
/// SaveLocationSheet.show(
///   context,
///   lat: 25.2,
///   lng: 55.3,
///   areaId: 'uuid',
///   areaName: 'Downtown',
///   accuracyMeters: 8.0,
///   onUseOnce: (lat, lng, areaId) { /* attach to post */ },
/// );
/// ```
class SaveLocationSheet extends ConsumerStatefulWidget {
  const SaveLocationSheet({
    super.key,
    required this.lat,
    required this.lng,
    required this.areaId,
    required this.areaName,
    this.accuracyMeters,
    this.onUseOnce,
    this.tileLayerBuilder,
  });

  /// Test seam: replaces the network [TileLayer] (render tests stub tiles).
  /// Null in the app.
  @visibleForTesting
  final Widget Function()? tileLayerBuilder;

  final double lat;
  final double lng;
  final String areaId;
  final String areaName;
  final double? accuracyMeters;

  /// Called when the user taps "Use once" — no DB write.
  final void Function(double lat, double lng, String areaId)? onUseOnce;

  static Future<void> show(
    BuildContext context, {
    required double lat,
    required double lng,
    required String areaId,
    required String areaName,
    double? accuracyMeters,
    void Function(double lat, double lng, String areaId)? onUseOnce,
  }) {
    return showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.85],
      builder: (_) => SaveLocationSheet(
        lat: lat,
        lng: lng,
        areaId: areaId,
        areaName: areaName,
        accuracyMeters: accuracyMeters,
        onUseOnce: onUseOnce,
      ),
    );
  }

  @override
  ConsumerState<SaveLocationSheet> createState() => _SaveLocationSheetState();
}

class _SaveLocationSheetState extends ConsumerState<SaveLocationSheet> {
  ProfileLocationLabel? _selectedLabel;
  final _customNameController = TextEditingController();
  final _mapController = MapController();
  bool _isPrimary = false;
  bool _isSaving = false;

  // Mutable location state — updated when user picks a Mapbox place.
  late double _lat = widget.lat;
  late double _lng = widget.lng;
  late String _areaId = widget.areaId;
  late String _areaName = widget.areaName;

  @override
  void dispose() {
    _customNameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool get _canSave => _selectedLabel != null;

  LatLng? get _activeProximity {
    final locState = ref.read(activeLocationProvider).valueOrNull;
    if (locState is ActiveLocationReady) {
      final loc = locState.location;
      return LatLng(loc.lat, loc.lng);
    }
    return null;
  }

  /// Accuracy tone: null (neutral badge) when unknown, then success /
  /// warning / error at the same 20 m and 100 m thresholds as before.
  DabblerStatusColor? _accuracyStatus(DabblerColors colors) {
    final m = widget.accuracyMeters;
    if (m == null) return null;
    if (m < 20) return colors.success;
    if (m < 100) return colors.warning;
    return colors.error;
  }

  String _accuracyText() {
    final m = widget.accuracyMeters;
    if (m == null) return 'Unknown accuracy';
    return '± ${m.toStringAsFixed(0)} m';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    await ref
        .read(profileLocationNotifierProvider.notifier)
        .saveLocation(
          lat: _lat,
          lng: _lng,
          areaId: _areaId,
          label: _selectedLabel!,
          labelCustom: _selectedLabel == ProfileLocationLabel.custom
              ? _customNameController.text.trim()
              : null,
          isPrimary: _isPrimary,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
    }
  }

  void _useOnce() {
    widget.onUseOnce?.call(_lat, _lng, _areaId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final accuracy = _accuracyStatus(colors);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          0,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title (handle and close come from DabblerSheet; the emoji the
            // old title carried is dropped, CEO rule).
            DabblerText('Save this location', style: DabblerType.title3),
            const SizedBox(height: DabblerSpacing.space5),

            // Mapbox place search
            LocationSearchField(
              hintText: 'Search for a place…',
              proximity: _activeProximity,
              onSelected: (place) async {
                final repo = ref.read(areaRepositoryV2Provider);
                final resolved = await repo.resolveNearest(
                  place.lat,
                  place.lng,
                );
                if (!mounted) return;
                setState(() {
                  _lat = place.lat;
                  _lng = place.lng;
                  _areaName = place.name;
                  if (resolved != null) _areaId = resolved.id;
                });
                _mapController.move(LatLng(place.lat, place.lng), 15);
              },
            ),
            const SizedBox(height: DabblerSpacing.space4),

            // Map thumbnail — flutter_map tiles are content inside the DS
            // surface; the marker is a DS icon.
            DabblerSurface(
              radius: DabblerRadius.card,
              height: DabblerSizing.mediaPreviewHeight,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_lat, _lng),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  if (widget.tileLayerBuilder != null)
                    widget.tileLayerBuilder!()
                  else
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.dabbler.app',
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_lat, _lng),
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
            const SizedBox(height: DabblerSpacing.space4),

            // Area name + accuracy badge
            Row(
              children: [
                DabblerIcon(
                  'location',
                  size: DabblerSizing.iconInline,
                  color: colors.brandPrimary,
                ),
                const SizedBox(width: DabblerSpacing.space1),
                Expanded(
                  child: DabblerText(_areaName, style: DabblerType.headline),
                ),
                DabblerBadge(label: _accuracyText(), status: accuracy),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space8),

            // Label picker
            DabblerText('Label', style: DabblerType.headline),
            const SizedBox(height: DabblerSpacing.space3),
            Wrap(
              spacing: DabblerSpacing.space3,
              runSpacing: DabblerSpacing.space3,
              children: ProfileLocationLabel.values.map((label) {
                return DabblerChip(
                  label: label.displayName,
                  selected: _selectedLabel == label,
                  onTap: () => setState(() => _selectedLabel = label),
                );
              }).toList(),
            ),
            const SizedBox(height: DabblerSpacing.space4),

            // Custom name field
            if (_selectedLabel == ProfileLocationLabel.custom) ...[
              DabblerTextField(
                controller: _customNameController,
                placeholder: 'e.g. My gym, Parents\' house',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: DabblerSpacing.space4),
            ],

            // Primary toggle
            DabblerInputRow(
              title: 'Set as primary location',
              trailing: DabblerToggle(
                checked: _isPrimary,
                semanticLabel: 'Set as primary location',
                onChanged: (v) => setState(() => _isPrimary = v),
              ),
              onTap: () => setState(() => _isPrimary = !_isPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space6),

            // Save button
            DabblerButton(
              label: 'Save location',
              fullWidth: true,
              loading: _isSaving,
              disabled: !_canSave || _isSaving,
              onPressed: _save,
            ),
            const SizedBox(height: DabblerSpacing.space3),

            // Use once button
            if (widget.onUseOnce != null)
              DabblerButton(
                label: 'Use once',
                tone: DabblerButtonTone.text,
                fullWidth: true,
                onPressed: _useOnce,
              ),
          ],
        ),
      ),
    );
  }
}

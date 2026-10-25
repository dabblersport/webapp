import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/presentation/saved_place_labels.dart';
import 'package:dabbler/features/location/presentation/widgets/location_map_preview.dart'
    show kLocationMapInteraction;
import 'package:dabbler/features/location/presentation/widgets/location_search_field.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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
    return showAppSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      title: AppLocalizations.of(context).saved_places_save_title,
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

  /// A label is chosen, and a custom label (Gym, ...) has a name.
  bool get _canSave =>
      _selectedLabel != null &&
      (_selectedLabel != ProfileLocationLabel.custom ||
          _customNameController.text.trim().isNotEmpty);

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

  String _accuracyText(AppLocalizations l10n) {
    final m = widget.accuracyMeters;
    if (m == null) return l10n.saved_places_accuracy_unknown;
    return '± ${m.toStringAsFixed(0)} m';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    final outcome = await ref
        .read(profileLocationNotifierProvider.notifier)
        .savePlace(
          lat: _lat,
          lng: _lng,
          areaId: _areaId,
          label: _selectedLabel!,
          labelCustom: _selectedLabel == ProfileLocationLabel.custom
              ? _customNameController.text.trim()
              : null,
          isPrimary: _isPrimary,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (outcome != SavePlaceOutcome.saved) {
      final l10n = AppLocalizations.of(context);
      DabblerToastProvider.of(context).show(
        DabblerToastSpec(
          message: outcome == SavePlaceOutcome.duplicate
              ? l10n.saved_places_duplicate
              : l10n.saved_places_save_failed,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  /// Moves the pin to a searched place or a tapped point (KAN-589), and takes
  /// the nearest Area's id (and name, when the point has none of its own).
  Future<void> _movePin(double lat, double lng, {String? name}) async {
    setState(() {
      _lat = lat;
      _lng = lng;
      if (name != null) _areaName = name;
    });
    Area? resolved;
    try {
      resolved = await ref
          .read(areaRepositoryV2Provider)
          .resolveNearest(lat, lng);
    } catch (_) {
      resolved = null; // offline: the pin moves, the Area id stays
    }
    if (!mounted || _lat != lat || _lng != lng) return;
    final Area? area = resolved;
    if (area == null) return;
    setState(() {
      _areaId = area.id;
      if (name == null) _areaName = area.name;
    });
  }

  void _useOnce() {
    widget.onUseOnce?.call(_lat, _lng, _areaId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final accuracy = _accuracyStatus(colors);
    final l10n = AppLocalizations.of(context);

    // The DabblerSheet owns the surface, the title and the body inset and
    // scrolls; this returns the content only. The keyboard inset is a trailing
    // gap so the last row can scroll clear of the keyboard.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mapbox place search
        LocationSearchField(
          hintText: l10n.saved_places_search_hint,
          proximity: _activeProximity,
          onSelected: (place) async {
            await _movePin(place.lat, place.lng, name: place.name);
            if (!mounted) return;
            _mapController.move(LatLng(place.lat, place.lng), 15);
          },
        ),
        const DabblerGap.v(DabblerSpacing.space4),

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
              interactionOptions: kLocationMapInteraction,
              onTap: (_, point) => _movePin(point.latitude, point.longitude),
            ),
            children: [
              if (widget.tileLayerBuilder != null)
                widget.tileLayerBuilder!()
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
        const DabblerGap.v(DabblerSpacing.space4),

        // Area name + accuracy badge
        Row(
          children: [
            DabblerIcon(
              'location',
              size: DabblerSizing.iconInline,
              color: colors.brandPrimary,
            ),
            const DabblerGap.h(DabblerSpacing.space1),
            Expanded(
              child: DabblerText(_areaName, style: DabblerType.headline),
            ),
            DabblerBadge(label: _accuracyText(l10n), status: accuracy),
          ],
        ),
        const DabblerGap.v(DabblerSpacing.space8),

        // Label picker
        DabblerText(l10n.saved_places_label, style: DabblerType.headline),
        const DabblerGap.v(DabblerSpacing.space3),
        Wrap(
          spacing: DabblerSpacing.space3,
          runSpacing: DabblerSpacing.space3,
          children: ProfileLocationLabel.values.map((label) {
            return DabblerChip(
              label: savedPlaceLabelName(l10n, label),
              selected: _selectedLabel == label,
              onTap: () => setState(() => _selectedLabel = label),
            );
          }).toList(),
        ),
        const DabblerGap.v(DabblerSpacing.space4),

        // Custom name field
        if (_selectedLabel == ProfileLocationLabel.custom) ...[
          DabblerTextField(
            controller: _customNameController,
            placeholder: l10n.saved_places_custom_hint,
            onChanged: (_) => setState(() {}),
          ),
          const DabblerGap.v(DabblerSpacing.space4),
        ],

        // Primary toggle
        DabblerInputRow(
          title: l10n.saved_places_primary_toggle,
          trailing: DabblerToggle(
            checked: _isPrimary,
            semanticLabel: l10n.saved_places_primary_toggle,
            onChanged: (v) => setState(() => _isPrimary = v),
          ),
          onTap: () => setState(() => _isPrimary = !_isPrimary),
        ),
        const DabblerGap.v(DabblerSpacing.space6),

        // Save button
        DabblerButton(
          label: l10n.saved_places_save_action,
          fullWidth: true,
          loading: _isSaving,
          disabled: !_canSave || _isSaving,
          onPressed: _save,
        ),
        const DabblerGap.v(DabblerSpacing.space3),

        // Use once button
        if (widget.onUseOnce != null)
          DabblerButton(
            label: l10n.saved_places_use_once,
            tone: DabblerButtonTone.text,
            fullWidth: true,
            onPressed: _useOnce,
          ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}

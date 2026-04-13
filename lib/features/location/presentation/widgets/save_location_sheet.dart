import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:dabbler/data/models/profile_location.dart';
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
  });

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) => SaveLocationSheet(
          lat: lat,
          lng: lng,
          areaId: areaId,
          areaName: areaName,
          accuracyMeters: accuracyMeters,
          onUseOnce: onUseOnce,
        ),
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
  late final String _areaId = widget.areaId;
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

  Color _accuracyColor(ColorScheme cs) {
    final m = widget.accuracyMeters;
    if (m == null) return cs.onSurfaceVariant;
    if (m < 20) return Colors.green;
    if (m < 100) return Colors.orange;
    return cs.error;
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              '📍 Save this location',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Mapbox place search
            LocationSearchField(
              hintText: 'Search for a place\u2026',
              proximity: _activeProximity,
              onSelected: (place) {
                setState(() {
                  _lat = place.lat;
                  _lng = place.lng;
                  _areaName = place.name;
                });
                _mapController.move(LatLng(place.lat, place.lng), 15);
              },
            ),
            const SizedBox(height: 12),

            // Map thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
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
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.dabbler.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_lat, _lng),
                          width: 32,
                          height: 32,
                          child: Icon(
                            Icons.location_pin,
                            color: cs.primary,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Area name + accuracy badge
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _areaName,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _accuracyColor(cs).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accuracyColor(cs).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _accuracyText(),
                    style: tt.labelSmall?.copyWith(
                      color: _accuracyColor(cs),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Label picker
            Text(
              'Label',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ProfileLocationLabel.values.map((label) {
                final selected = _selectedLabel == label;
                return ChoiceChip(
                  label: Text(label.displayName),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedLabel = label),
                  selectedColor: cs.primaryContainer,
                  labelStyle: TextStyle(
                    color: selected ? cs.onPrimaryContainer : cs.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Custom name field
            if (_selectedLabel == ProfileLocationLabel.custom) ...[
              TextField(
                controller: _customNameController,
                decoration: InputDecoration(
                  hintText: 'e.g. My gym, Parents\' house',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],

            // Primary toggle
            SwitchListTile.adaptive(
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v),
              title: Text('Set as primary location', style: tt.bodyMedium),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: cs.onPrimary,
              activeTrackColor: cs.primary,
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave && !_isSaving ? _save : null,
                child: _isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text('Save location'),
              ),
            ),
            const SizedBox(height: 8),

            // Use once button
            if (widget.onUseOnce != null)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _useOnce,
                  child: const Text('Use once'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

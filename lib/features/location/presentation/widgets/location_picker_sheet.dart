import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/presentation/widgets/location_search_field.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';

/// Sealed result type for the location picker.
class LocationPickerResult {
  const LocationPickerResult._({
    this.type = LocationPickerType.currentLocation,
    this.displayName,
    this.lat,
    this.lng,
    this.venueId,
    this.areaId,
  });

  final LocationPickerType type;
  final String? displayName;
  final double? lat;
  final double? lng;
  final String? venueId;
  final String? areaId;

  factory LocationPickerResult.currentLocation({
    required String name,
    required double lat,
    required double lng,
  }) => LocationPickerResult._(
    type: LocationPickerType.currentLocation,
    displayName: name,
    lat: lat,
    lng: lng,
  );

  factory LocationPickerResult.venue({
    required String id,
    required String name,
    double? lat,
    double? lng,
  }) => LocationPickerResult._(
    type: LocationPickerType.venue,
    venueId: id,
    displayName: name,
    lat: lat,
    lng: lng,
  );

  factory LocationPickerResult.area({
    required String id,
    required String name,
  }) => LocationPickerResult._(
    type: LocationPickerType.area,
    areaId: id,
    displayName: name,
  );

  factory LocationPickerResult.mapboxPlace(MapboxPlace place) =>
      LocationPickerResult._(
        type: LocationPickerType.mapboxPlace,
        displayName: place.name,
        lat: place.lat,
        lng: place.lng,
      );
}

enum LocationPickerType { currentLocation, venue, area, mapboxPlace }

/// Bottom sheet for picking a location to attach to a post.
///
/// Three modes:
/// 1. Use my current location — resolves via GPS
/// 2. Tag a venue — searchable list from `venues` table
/// 3. Pick an area — list of active areas
class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key});

  static Future<LocationPickerResult?> show(BuildContext context) {
    return showAdaptiveSheet<LocationPickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LocationPickerSheet(),
    );
  }

  @override
  ConsumerState<LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  _PickerMode _mode = _PickerMode.menu;
  bool _loadingGps = false;

  // Venue search state
  final _venueController = TextEditingController();
  Timer? _venueDebounce;

  @override
  void dispose() {
    _venueDebounce?.cancel();
    _venueController.dispose();
    super.dispose();
  }

  // ── GPS ────────────────────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingGps = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        setState(() => _loadingGps = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      String name = 'Current location';

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          name = pm.subLocality?.isNotEmpty == true
              ? pm.subLocality!
              : pm.locality?.isNotEmpty == true
              ? pm.locality!
              : pm.administrativeArea ?? 'Current location';
        }
      } catch (_) {
        // Keep default name on geocoding failure.
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        LocationPickerResult.currentLocation(
          name: name,
          lat: position.latitude,
          lng: position.longitude,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      setState(() => _loadingGps = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle ──
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title + back ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_mode != _PickerMode.menu)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _mode = _PickerMode.menu),
                    ),
                  Text(
                    _title,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: switch (_mode) {
                _PickerMode.menu => _buildMenu(cs, tt, scrollController),
                _PickerMode.venue => _buildVenueSearch(
                  cs,
                  tt,
                  scrollController,
                ),
                _PickerMode.area => _buildAreaList(cs, tt, scrollController),
                _PickerMode.placeSearch => _buildPlaceSearch(cs, tt),
              },
            ),
          ],
        );
      },
    );
  }

  String get _title => switch (_mode) {
    _PickerMode.menu => 'Add Location',
    _PickerMode.venue => 'Tag a Venue',
    _PickerMode.area => 'Pick an Area',
    _PickerMode.placeSearch => 'Search a Place',
  };

  // ── Menu ───────────────────────────────────────────────────────────

  Widget _buildMenu(
    ColorScheme cs,
    TextTheme tt,
    ScrollController scrollController,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _MenuTile(
          icon: Iconsax.gps,
          label: 'Use my current location',
          subtitle: 'Attach GPS coordinates',
          isLoading: _loadingGps,
          onTap: _loadingGps ? null : _useCurrentLocation,
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: Iconsax.building,
          label: 'Tag a venue',
          subtitle: 'Search for a sports venue',
          onTap: () => setState(() => _mode = _PickerMode.venue),
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: Iconsax.map,
          label: 'Pick an area',
          subtitle: 'Select a neighborhood or city',
          onTap: () => setState(() => _mode = _PickerMode.area),
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: 8),
        _MenuTile(
          icon: Iconsax.search_normal,
          label: 'Search a place',
          subtitle: 'Find an address or point of interest',
          onTap: () => setState(() => _mode = _PickerMode.placeSearch),
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }

  // ── Venue Search ───────────────────────────────────────────────────

  Widget _buildVenueSearch(
    ColorScheme cs,
    TextTheme tt,
    ScrollController scrollController,
  ) {
    final query = _venueController.text.trim();
    final venuesAsync = query.length >= 2
        ? ref.watch(venueSearchProvider(query))
        : const AsyncData<List<Map<String, dynamic>>>([]);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _venueController,
            autofocus: true,
            onChanged: (val) {
              _venueDebounce?.cancel();
              _venueDebounce = Timer(const Duration(milliseconds: 350), () {
                if (mounted) setState(() {});
              });
            },
            style: tt.bodyLarge?.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search venues...',
              hintStyle: tt.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: venuesAsync.when(
            data: (venues) {
              if (venues.isEmpty && query.length >= 2) {
                return Center(
                  child: Text(
                    'No venues found',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }
              return ListView.builder(
                controller: scrollController,
                itemCount: venues.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (_, i) {
                  final v = venues[i];
                  final name = v['name_en'] as String? ?? 'Unknown';
                  final city = v['city'] as String? ?? '';
                  return ListTile(
                    leading: Icon(Iconsax.building, color: cs.primary),
                    title: Text(name),
                    subtitle: city.isNotEmpty ? Text(city) : null,
                    onTap: () {
                      Navigator.of(context).pop(
                        LocationPickerResult.venue(
                          id: v['id'] as String,
                          name: name,
                          lat: (v['latitude'] as num?)?.toDouble(),
                          lng: (v['longitude'] as num?)?.toDouble(),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => Center(
              child: Text(
                'Error loading venues',
                style: tt.bodyMedium?.copyWith(color: cs.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Area List ──────────────────────────────────────────────────────

  Widget _buildAreaList(
    ColorScheme cs,
    TextTheme tt,
    ScrollController scrollController,
  ) {
    final areasAsync = ref.watch(activeAreasProvider);

    return areasAsync.when(
      data: (areas) {
        if (areas.isEmpty) {
          return Center(
            child: Text(
              'No areas available',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: areas.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (_, i) {
            final area = areas[i];
            return ListTile(
              leading: Icon(Iconsax.map, color: cs.primary),
              title: Text(area.name),
              subtitle: Text('${area.city}, ${area.country}'),
              onTap: () {
                Navigator.of(
                  context,
                ).pop(LocationPickerResult.area(id: area.id, name: area.name));
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(
        child: Text(
          'Error loading areas',
          style: tt.bodyMedium?.copyWith(color: cs.error),
        ),
      ),
    );
  }

  // ── Mapbox Place Search ────────────────────────────────────────────

  Widget _buildPlaceSearch(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LocationSearchField(
        autofocus: true,
        hintText: 'Search for an address or place\u2026',
        onSelected: (place) {
          Navigator.of(context).pop(LocationPickerResult.mapboxPlace(place));
        },
      ),
    );
  }
}

// ── Picker mode ──────────────────────────────────────────────────────

enum _PickerMode { menu, venue, area, placeSearch }

// ── Menu tile ────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.cs,
    required this.tt,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: cs.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

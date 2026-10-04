import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/presentation/widgets/location_picker_row.dart';
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
    // Was showAdaptiveSheet + a DraggableScrollableSheet (0.6, 0.4-0.9);
    // the DabblerSheet snaps between the same 0.6 and 0.9 heights.
    return showDabblerSheet<LocationPickerResult>(
      context: context,
      detents: const <double>[0.6, 0.9],
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
        DabblerToastProvider.of(
          context,
        ).show(const DabblerToastSpec(message: 'Location permission denied'));
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
      DabblerToastProvider.of(
        context,
      ).show(DabblerToastSpec(message: 'Could not get location: $e'));
      setState(() => _loadingGps = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The DabblerSheet body is already a scroll view, so this shrink-wraps
    // (the old DraggableScrollableSheet hosted its own lists).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Title + back ── (handle and close come from DabblerSheet)
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: DabblerSpacing.space5,
            end: DabblerSpacing.space5,
            bottom: DabblerSpacing.space3,
          ),
          child: Row(
            children: [
              if (_mode != _PickerMode.menu) ...[
                DabblerButton.icon(
                  tone: DabblerButtonTone.text,
                  icon: 'arrow-left',
                  mirrorInRtl: true,
                  semanticLabel: 'Back',
                  onPressed: () => setState(() => _mode = _PickerMode.menu),
                ),
                const DabblerGap.h(DabblerSpacing.space2),
              ],
              Expanded(child: DabblerText(_title, style: DabblerType.headline)),
            ],
          ),
        ),

        // ── Content ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space5,
          ),
          child: switch (_mode) {
            _PickerMode.menu => _buildMenu(),
            _PickerMode.venue => _buildVenueSearch(),
            _PickerMode.area => _buildAreaList(),
            _PickerMode.placeSearch => _buildPlaceSearch(),
          },
        ),
      ],
    );
  }

  String get _title => switch (_mode) {
    _PickerMode.menu => 'Add Location',
    _PickerMode.venue => 'Tag a Venue',
    _PickerMode.area => 'Pick an Area',
    _PickerMode.placeSearch => 'Search a Place',
  };

  // ── Menu ───────────────────────────────────────────────────────────

  Widget _buildMenu() {
    return _Stack(
      children: [
        _MenuTile(
          icon: 'gps',
          label: 'Use my current location',
          subtitle: 'Attach GPS coordinates',
          isLoading: _loadingGps,
          onTap: _loadingGps ? null : _useCurrentLocation,
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        _MenuTile(
          icon: 'building',
          label: 'Tag a venue',
          subtitle: 'Search for a sports venue',
          onTap: () => setState(() => _mode = _PickerMode.venue),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        _MenuTile(
          icon: 'map',
          label: 'Pick an area',
          subtitle: 'Select a neighborhood or city',
          onTap: () => setState(() => _mode = _PickerMode.area),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        _MenuTile(
          icon: 'search-normal',
          label: 'Search a place',
          subtitle: 'Find an address or point of interest',
          onTap: () => setState(() => _mode = _PickerMode.placeSearch),
        ),
      ],
    );
  }

  // ── Venue Search ───────────────────────────────────────────────────

  void _onVenueQueryChanged(String _) {
    _venueDebounce?.cancel();
    _venueDebounce = Timer(DabblerMotion.debounceSearch, () {
      if (mounted) setState(() {});
    });
  }

  Widget _buildVenueSearch() {
    final colors = DabblerColors.of(context);
    final query = _venueController.text.trim();
    final venuesAsync = query.length >= 2
        ? ref.watch(venueSearchProvider(query))
        : const AsyncData<List<Map<String, dynamic>>>([]);

    return _Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space3),
          child: DabblerSearchField(
            controller: _venueController,
            autofocus: true,
            placeholder: 'Search venues...',
            onChanged: _onVenueQueryChanged,
            onCleared: () => _onVenueQueryChanged(''),
          ),
        ),
        venuesAsync.when(
          data: (venues) {
            if (venues.isEmpty && query.length >= 2) {
              return const _Pad(
                child: DabblerEmptyState(
                  icon: 'building',
                  text: 'No venues found',
                ),
              );
            }
            return _Stack(
              children: [
                for (final v in venues)
                  Builder(
                    builder: (_) {
                      final name = v['name_en'] as String? ?? 'Unknown';
                      final city = v['city'] as String? ?? '';
                      return PickerRow(
                        leading: DabblerIcon(
                          'building',
                          size: DabblerSizing.iconMd,
                          color: colors.brandPrimary,
                        ),
                        title: name,
                        subtitle: city.isNotEmpty ? city : null,
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
                  ),
              ],
            );
          },
          loading: () => const _Pad(child: DabblerSpinner()),
          error: (e, _) => const _Pad(
            child: DabblerEmptyState.error(
              title: 'Error loading venues',
              size: DabblerEmptyStateSize.inline,
            ),
          ),
        ),
      ],
    );
  }

  // ── Area List ──────────────────────────────────────────────────────

  Widget _buildAreaList() {
    final colors = DabblerColors.of(context);
    final areasAsync = ref.watch(activeAreasProvider);

    return areasAsync.when(
      data: (areas) {
        if (areas.isEmpty) {
          return const _Pad(
            child: DabblerEmptyState(icon: 'map', text: 'No areas available'),
          );
        }
        return _Stack(
          children: [
            for (final area in areas)
              PickerRow(
                leading: DabblerIcon(
                  'map',
                  size: DabblerSizing.iconMd,
                  color: colors.brandPrimary,
                ),
                title: area.name,
                subtitle: '${area.city}, ${area.country}',
                onTap: () {
                  Navigator.of(context).pop(
                    LocationPickerResult.area(id: area.id, name: area.name),
                  );
                },
              ),
          ],
        );
      },
      loading: () => const _Pad(child: DabblerSpinner()),
      error: (e, _) => const _Pad(
        child: DabblerEmptyState.error(
          title: 'Error loading areas',
          size: DabblerEmptyStateSize.inline,
        ),
      ),
    );
  }

  // ── Mapbox Place Search ────────────────────────────────────────────

  Widget _buildPlaceSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space3),
      child: LocationSearchField(
        autofocus: true,
        hintText: 'Search for an address or place…',
        onSelected: (place) {
          Navigator.of(context).pop(LocationPickerResult.mapboxPlace(place));
        },
      ),
    );
  }
}

/// A shrink-wrapped, full-width column (the sheet body scrolls).
class _Stack extends StatelessWidget {
  const _Stack({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

/// Centred loading / empty / error block.
class _Pad extends StatelessWidget {
  const _Pad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DabblerSpacing.space8),
    child: Center(child: child),
  );
}

// ── Picker mode ──────────────────────────────────────────────────────

enum _PickerMode { menu, venue, area, placeSearch }

// ── Menu tile ────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.isLoading = false,
  });

  final String icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DabblerInputRow(
      flat: true,
      leading: DabblerIconTile.named(icon),
      title: label,
      subtitle: subtitle,
      trailing: isLoading
          ? const DabblerSpinner(size: DabblerSpinnerSize.sm)
          : const DabblerChevron(),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}

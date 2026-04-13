import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/presentation/screens/saved_locations_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';

/// Home-screen location picker.
///
/// Drives [ActiveLocationNotifier] — does not return a value.
/// Three sections: GPS / Saved locations / Browse by area.
class HomeLocationPickerSheet extends ConsumerStatefulWidget {
  const HomeLocationPickerSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<HomeLocationPickerSheet> createState() =>
      _HomeLocationPickerSheetState();
}

class _HomeLocationPickerSheetState
    extends ConsumerState<HomeLocationPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _gpsLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final savedAsync = ref.watch(profileLocationNotifierProvider);
    final currentState = ref.watch(activeLocationProvider).valueOrNull;

    return Column(
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
          child: Row(
            children: [
              Text(
                '📍 Your Location',
                style:
                    tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            children: [
              // ── GPS ────────────────────────────────────────────────────
              _SectionLabel(label: 'Current Location', cs: cs, tt: tt),
              _GpsTile(
                isLoading: _gpsLoading,
                onTap: () => _useGps(),
              ),
              const Divider(height: 24, indent: 20, endIndent: 20),

              // ── Saved locations ────────────────────────────────────────
              _SectionLabel(label: 'Saved Locations', cs: cs, tt: tt),
              savedAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (locations) => Column(
                  children: [
                    ...locations.map((loc) => _SavedTile(
                          location: loc,
                          isSelected: currentState is ActiveLocationReady &&
                              currentState.location.savedLocationId == loc.id,
                          onTap: () => _useSaved(loc),
                        )),
                    ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined),
                      title: const Text('Add location'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SavedLocationsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24, indent: 20, endIndent: 20),

              // ── Browse by area ─────────────────────────────────────────
              _SectionLabel(label: 'Browse by Area', cs: cs, tt: tt),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search areas…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(height: 8),
              _AreaBrowser(
                query: _query,
                currentState: currentState,
                onSelected: (area) => _useManual(area),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _useGps() async {
    setState(() => _gpsLoading = true);
    final result = await ref.read(gpsServiceProvider).getCurrentLocation();
    if (!mounted) return;
    setState(() => _gpsLoading = false);

    switch (result) {
      case LocationSuccess():
        await ref.read(activeLocationProvider.notifier).useGpsLocation();
        if (mounted) Navigator.of(context).pop();
      case LocationDeniedForever():
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location access required'),
            content: const Text(
              'Location permission is permanently denied. '
              'Open Settings to enable it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      case LocationServiceOff():
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please enable location services')),
          );
        }
      case LocationDenied():
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permission denied')),
          );
        }
      case LocationTimeout():
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not get location — try again')),
          );
        }
      case LocationError(:final message):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $message')),
          );
        }
    }
  }

  Future<void> _useSaved(ProfileLocation location) async {
    await ref.read(activeLocationProvider.notifier).useSavedLocation(location);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _useManual(Area area) async {
    await ref.read(activeLocationProvider.notifier).useManualArea(area);
    if (mounted) Navigator.of(context).pop();
  }
}

// =============================================================================
// HELPERS
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.cs,
    required this.tt,
  });

  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _GpsTile extends StatelessWidget {
  const _GpsTile({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.my_location, color: cs.primary),
      title: const Text('Use my current location'),
      subtitle: isLoading
          ? Text('Detecting…',
              style: TextStyle(color: cs.onSurfaceVariant))
          : null,
      trailing: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cs.primary),
            )
          : Icon(Icons.gps_fixed, size: 16, color: cs.primary),
      onTap: isLoading ? null : onTap,
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.location,
    required this.isSelected,
    required this.onTap,
  });

  final ProfileLocation location;
  final bool isSelected;
  final VoidCallback onTap;

  IconData _icon() => switch (location.label) {
        ProfileLocationLabel.home => Icons.home_outlined,
        ProfileLocationLabel.work => Icons.work_outlined,
        ProfileLocationLabel.school => Icons.school_outlined,
        ProfileLocationLabel.current => Icons.my_location_outlined,
        ProfileLocationLabel.custom => Icons.place_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading:
          Icon(_icon(), color: isSelected ? cs.primary : cs.onSurface),
      title: Text(
        location.effectiveLabel,
        style: TextStyle(
          fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? cs.primary : cs.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.radio_button_checked, color: cs.primary)
          : const Icon(Icons.radio_button_unchecked),
      onTap: onTap,
    );
  }
}

// =============================================================================
// AREA BROWSER
// =============================================================================

class _AreaBrowser extends ConsumerWidget {
  const _AreaBrowser({
    required this.query,
    required this.currentState,
    required this.onSelected,
  });

  final String query;
  final ActiveLocationState? currentState;
  final void Function(Area area) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final areaRepo = ref.watch(areaRepositoryV2Provider);

    return FutureBuilder<Map<String, List<Area>>>(
      future: areaRepo.areasByDistrict(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final grouped = snapshot.data!;
        final q = query.toLowerCase();

        final filtered = q.isEmpty
            ? grouped
            : <String, List<Area>>{
                for (final entry in grouped.entries)
                  if (entry.value.any((a) =>
                      a.name.toLowerCase().contains(q) ||
                      a.city.toLowerCase().contains(q)))
                    entry.key: entry.value
                        .where((a) =>
                            a.name.toLowerCase().contains(q) ||
                            a.city.toLowerCase().contains(q))
                        .toList(),
              };

        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No areas match "$query"',
                style:
                    tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }

        double? activeLat;
        double? activeLng;
        if (currentState is ActiveLocationReady) {
          activeLat =
              (currentState as ActiveLocationReady).location.lat;
          activeLng =
              (currentState as ActiveLocationReady).location.lng;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in filtered.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  entry.key,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ...entry.value.map((area) {
                final distM = (activeLat != null && activeLng != null)
                    ? _haversineM(
                        activeLat, activeLng, area.centerLat, area.centerLng)
                    : null;
                final isSelected = currentState is ActiveLocationReady &&
                    (currentState as ActiveLocationReady).location.area.id ==
                        area.id;
                return ListTile(
                  leading: isSelected
                      ? Icon(Icons.radio_button_checked, color: cs.primary)
                      : const Icon(Icons.radio_button_unchecked),
                  title: Text(
                    area.name,
                    style: TextStyle(
                      color: isSelected ? cs.primary : cs.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: distM != null
                      ? Text(_fmt(distM),
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant))
                      : null,
                  onTap: () => onSelected(area),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  static double _haversineM(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _fmt(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

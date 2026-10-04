import 'dart:math' as math;

import 'package:dabbler_design_system/dabbler_design_system.dart';
// Route type only (non-visual): "Add location" keeps its existing push.
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/presentation/screens/saved_locations_screen.dart';
import 'package:dabbler/features/location/presentation/widgets/location_picker_row.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Home-screen location picker (design H06, City picker).
///
/// Drives [ActiveLocationNotifier] — does not return a value.
/// Three sections: GPS / Saved locations / Browse by area.
///
/// Body only: the sheet surface, drag handle, close affordance and scrim come
/// from [showDabblerSheet] (see [show]).
class HomeLocationPickerSheet extends ConsumerStatefulWidget {
  const HomeLocationPickerSheet({super.key, required this.scrollController});

  /// Kept for existing callers (home screen, app top bar). The DabblerSheet
  /// body is its own scroll view, so the picker no longer attaches it.
  final ScrollController scrollController;

  /// Opens the picker in a [DabblerSheet] at 0.85 of the viewport, the same
  /// presentation the home screen uses.
  static Future<void> show(BuildContext context) {
    return showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.66],
      pageBackground: true,
      showCloseButton: false,
      builder: (_) => const _PickerHost(),
    );
  }

  @override
  ConsumerState<HomeLocationPickerSheet> createState() =>
      _HomeLocationPickerSheetState();
}

/// Owns the scroll controller [HomeLocationPickerSheet] expects.
class _PickerHost extends StatefulWidget {
  const _PickerHost();

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HomeLocationPickerSheet(scrollController: _controller);
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
    final l10n = AppLocalizations.of(context);
    final savedAsync = ref.watch(profileLocationNotifierProvider);
    final currentState = ref.watch(activeLocationProvider).valueOrNull;

    // The frame's order: header with Done, search, saved places as chips,
    // "Use current location", then the areas grouped by district. The
    // DabblerSheet body already scrolls, so this shrink-wraps.
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        bottom: DabblerSpacing.space9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DabblerText(
                  l10n.home_location_title,
                  style: DabblerType.headline,
                ),
              ),
              DabblerButton(
                label: l10n.home_location_done,
                tone: DabblerButtonTone.neutral,
                size: DabblerButtonSize.small,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space4),
          DabblerSearchField(
            controller: _searchController,
            placeholder: l10n.home_location_search,
            onChanged: (v) => setState(() => _query = v.trim()),
            onCleared: () => setState(() => _query = ''),
          ),
          const SizedBox(height: DabblerSpacing.space4),
          savedAsync.when(
            loading: () => const DabblerSkeleton.text(lines: 1),
            error: (_, __) => const SizedBox.shrink(),
            data: (locations) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final loc in locations)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: DabblerSpacing.space2,
                      ),
                      child: DabblerChip(
                        label: loc.effectiveLabel,
                        selected:
                            currentState is ActiveLocationReady &&
                            currentState.location.savedLocationId == loc.id,
                        leadingIcon: DabblerIcon(
                          _savedIcon(loc),
                          size: DabblerSizing.iconSm,
                        ),
                        onTap: () => _useSaved(loc),
                      ),
                    ),
                  DabblerChip(
                    label: l10n.home_location_add,
                    leadingIcon: const DabblerIcon(
                      'location-add',
                      size: DabblerSizing.iconSm,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SavedLocationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DabblerSpacing.space4),
          _GpsTile(isLoading: _gpsLoading, onTap: () => _useGps()),
          _AreaBrowser(
            query: _query,
            currentState: currentState,
            onSelected: (area) => _useManual(area),
          ),
        ],
      ),
    );
  }

  static String _savedIcon(ProfileLocation location) =>
      switch (location.label) {
        ProfileLocationLabel.home => 'home-2',
        ProfileLocationLabel.work => 'briefcase',
        ProfileLocationLabel.school => 'teacher',
        ProfileLocationLabel.current => 'gps',
        ProfileLocationLabel.custom => 'location',
      };

  void _toast(String message) {
    DabblerToastProvider.of(context).show(DabblerToastSpec(message: message));
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
        await showDabblerDialog<void>(
          context: context,
          builder: (ctx) => DabblerDialog(
            onClose: () => Navigator.pop(ctx),
            title: 'Location access required',
            description:
                'Location permission is permanently denied. '
                'Open Settings to enable it.',
            secondaryAction: DabblerDialogAction(
              label: 'Cancel',
              onPressed: () => Navigator.pop(ctx),
            ),
            primaryAction: DabblerDialogAction(
              label: 'Open Settings',
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
            ),
          ),
        );
      case LocationServiceOff():
        if (mounted) _toast('Please enable location services');
      case LocationDenied():
        if (mounted) _toast('Location permission denied');
      case LocationTimeout():
        if (mounted) _toast('Could not get location — try again');
      case LocationError(:final message):
        if (mounted) _toast('Error: $message');
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

class _GpsTile extends StatelessWidget {
  const _GpsTile({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return PickerRow(
      brand: true,
      leading: DabblerIcon(
        'gps',
        size: DabblerSizing.iconMd,
        weight: DabblerIconWeight.bold,
        color: colors.brandPrimary,
      ),
      title: AppLocalizations.of(context).home_location_use_current,
      trailing: isLoading
          ? const DabblerSpinner(size: DabblerSpinnerSize.sm)
          : null,
      onTap: isLoading ? null : onTap,
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
    final colors = DabblerColors.of(context);
    final areaRepo = ref.watch(areaRepositoryV2Provider);

    return FutureBuilder<Map<String, List<Area>>>(
      future: areaRepo.areasByDistrict(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(DabblerSpacing.space5),
            child: Center(child: DabblerSpinner()),
          );
        }

        final grouped = snapshot.data!;
        final q = query.toLowerCase();

        final filtered = q.isEmpty
            ? grouped
            : <String, List<Area>>{
                for (final entry in grouped.entries)
                  if (entry.value.any(
                    (a) =>
                        a.name.toLowerCase().contains(q) ||
                        a.city.toLowerCase().contains(q),
                  ))
                    entry.key: entry.value
                        .where(
                          (a) =>
                              a.name.toLowerCase().contains(q) ||
                              a.city.toLowerCase().contains(q),
                        )
                        .toList(),
              };

        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space8),
            child: DabblerEmptyState(
              icon: 'search-normal',
              text: AppLocalizations.of(context).home_location_no_match(query),
            ),
          );
        }

        double? activeLat;
        double? activeLng;
        if (currentState is ActiveLocationReady) {
          activeLat = (currentState as ActiveLocationReady).location.lat;
          activeLng = (currentState as ActiveLocationReady).location.lng;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in filtered.entries) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: DabblerSpacing.space5,
                  bottom: DabblerSpacing.space2,
                ),
                child: DabblerText(
                  entry.key,
                  style: DabblerType.caption1,
                  tone: DabblerTextTone.secondary,
                ),
              ),
              ...entry.value.map((area) {
                final distM = (activeLat != null && activeLng != null)
                    ? _haversineM(
                        activeLat,
                        activeLng,
                        area.centerLat,
                        area.centerLng,
                      )
                    : null;
                final isSelected =
                    currentState is ActiveLocationReady &&
                    (currentState as ActiveLocationReady).location.area.id ==
                        area.id;
                return PickerRow(
                  selected: isSelected,
                  leading: DabblerIcon(
                    'location',
                    size: DabblerSizing.iconMd,
                    weight: isSelected
                        ? DabblerIconWeight.bold
                        : DabblerIconWeight.linear,
                    color: isSelected
                        ? colors.brandPrimary
                        : colors.textSecondary,
                  ),
                  title: area.name,
                  subtitle: distM != null ? _fmt(distM) : area.city,
                  trailing: isSelected
                      ? DabblerIcon(
                          'tick-circle',
                          size: DabblerSizing.iconMd,
                          weight: DabblerIconWeight.bold,
                          color: colors.brandPrimary,
                        )
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
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
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

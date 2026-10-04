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
import 'package:dabbler/features/location/presentation/widgets/home_location_places.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// "Change location" sheet (Listings.dc.html:313-366, the frame the three
/// listings share).
///
/// Drives [ActiveLocationNotifier] — does not return a value. One flat list of
/// [DabblerListRow]s under the search field: "Use current location", then the
/// saved locations (the frame's "Recent" group; the app has no recents, so its
/// saved places take that slot) with the "Add location" row, then the areas
/// grouped by district in the same row style.
///
/// [show] gives the sheet its own header (display title, hairline, Cancel). A
/// host that opens this widget inside its own `showDabblerSheet` (Home does)
/// gets the same header drawn in the body.
class HomeLocationPickerSheet extends ConsumerStatefulWidget {
  const HomeLocationPickerSheet({
    super.key,
    required this.scrollController,
    this.showHeader = true,
    this.frameHeader = false,
  });

  /// Draws the header the Home Feed frame draws (`Home Feed.dc.html` city
  /// sheet): the title in the 17/22 headline step beside a "Done" pill, with no
  /// hairline under it. Default false keeps the Listings frame's header, which
  /// the Games and Venues screens open.
  final bool frameHeader;

  /// Kept for existing callers (home screen, app top bar). The DabblerSheet
  /// body is its own scroll view, so the picker no longer attaches it.
  final ScrollController scrollController;

  /// Draws the title row and its hairline in the body. [show] turns it off
  /// because the sheet route draws the same header.
  final bool showHeader;

  /// Opens the picker in a [DabblerSheet] at 0.66 of the viewport.
  static Future<void> show(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.66],
      pageBackground: true,
      showCloseButton: false,
      headerDivider: true,
      title: l10n.home_location_title,
      headerActionBuilder: (ctx) => DabblerButton(
        label: l10n.home_location_cancel,
        tone: DabblerButtonTone.neutral,
        size: DabblerButtonSize.small,
        onPressed: () => Navigator.of(ctx).pop(),
      ),
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
      HomeLocationPickerSheet(scrollController: _controller, showHeader: false);
}

class _HomeLocationPickerSheetState
    extends ConsumerState<HomeLocationPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _gpsLoading = false;
  late final Future<Map<String, List<Area>>> _areas = ref
      .read(areaRepositoryV2Provider)
      .areasByDistrict();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(profileLocationNotifierProvider).valueOrNull;
    final currentState = ref.watch(activeLocationProvider).valueOrNull;

    // The DabblerSheet body already scrolls, so this shrink-wraps.
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader && widget.frameHeader) ...[
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
            // 12 of header padding and 12 of gap before the search field.
            const SizedBox(height: DabblerSpacing.space8),
          ] else if (widget.showHeader) ...[
            Row(
              children: [
                Expanded(
                  child: DabblerText(
                    l10n.home_location_title,
                    style: DabblerType.title3,
                  ),
                ),
                DabblerButton(
                  label: l10n.home_location_cancel,
                  tone: DabblerButtonTone.neutral,
                  size: DabblerButtonSize.small,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space4),
            const DabblerDivider(),
            const SizedBox(height: DabblerSpacing.space4),
          ] else
            const SizedBox(height: DabblerSpacing.space4),
          DabblerSearchField(
            controller: _searchController,
            metrics: widget.frameHeader
                ? DabblerFeedMetrics.drawn
                : DabblerFeedMetrics.touch,
            placeholder: widget.frameHeader
                ? l10n.home_location_search
                : l10n.home_location_search_venues,
            onChanged: (v) => setState(() => _query = v.trim()),
            onCleared: () => setState(() => _query = ''),
          ),
          SizedBox(
            height: widget.frameHeader
                ? DabblerSpacing.space4
                : DabblerSpacing.space3,
          ),
          DabblerListRow(
            flat: true,
            brand: true,
            metrics: widget.frameHeader
                ? DabblerFeedMetrics.drawn
                : DabblerFeedMetrics.touch,
            leading: DabblerIcon(
              'gps',
              size: widget.frameHeader
                  ? DabblerHomeFrame.listRowGlyph
                  : DabblerSizing.iconRow,
              weight: DabblerIconWeight.bold,
              color: DabblerColors.of(context).brandPrimary,
            ),
            title: l10n.home_location_use_current,
            trailing: _gpsLoading
                ? const DabblerSpinner(size: DabblerSpinnerSize.sm)
                : null,
            onTap: _gpsLoading ? null : _useGps,
          ),
          HomeLocationPlaces(
            frame: widget.frameHeader,
            areas: _areas,
            saved: saved ?? const <ProfileLocation>[],
            query: _query,
            currentState: currentState,
            onSaved: _useSaved,
            onArea: _useManual,
            onAdd: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SavedLocationsScreen()),
            ),
          ),
        ],
      ),
    );
  }

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

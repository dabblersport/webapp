import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler/core/services/location_permission_state.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/presentation/widgets/point_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// KAN-526: when location permission is denied and there is no active
/// location, a location surface offers the manual "Set location" drawer
/// ([ManualLocationDrawer]) instead of failing silently or asking the OS again.
/// Nothing here ever requests permission.

/// Whether location access is denied or unavailable on this device, so the
/// city / area list is the only way left to set a location. Reads the platform
/// state and never asks: a first-time "denied" is not a refusal until the one
/// prompt was used (KAN-521).
Future<bool> locationAccessDenied() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return true;
    final LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.deniedForever) return true;
    if (p == LocationPermission.denied) return await LocationPermissionState.asked();
    return false;
  } catch (_) {
    return false;
  }
}

/// Opens the one "Set location" drawer (KAN-589): a point picker (search a
/// place or move the pin). The city / area list is its fallback, shown only
/// when location access is denied or unavailable.
Future<void> showSetLocationDrawer(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final bool list =
      container.read(activeLocationProvider).valueOrNull
          is ActiveLocationDenied ||
      await locationAccessDenied();
  if (!context.mounted) return;
  return showAppSheet<void>(
    context: context,
    title: AppLocalizations.of(context).listing_set_location,
    detent: DabblerSheetDetent.content,
    builder: (_) =>
        list ? const ManualLocationDrawer() : const PointPickerSheet(),
  );
}

/// Whether the active location settled to denied (no location to use).
bool isActiveLocationDenied(WidgetRef ref) =>
    ref.watch(activeLocationProvider).valueOrNull is ActiveLocationDenied;

/// Wraps a location surface: opens the "Set location" drawer ONCE per visit
/// (per mounted instance) when the active location is denied AND the OS prompt
/// was already used (KAN-521: it cannot be asked again). Before that one prompt
/// the location introduction owns asking, so nothing opens on its own. Dismissing it
/// leaves the surface as it is; the surface's visible "Set location" action
/// reopens it.
class SetLocationWhenDenied extends ConsumerStatefulWidget {
  const SetLocationWhenDenied({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SetLocationWhenDenied> createState() =>
      _SetLocationWhenDeniedState();
}

class _SetLocationWhenDeniedState extends ConsumerState<SetLocationWhenDenied> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<ActiveLocationState>>(
      activeLocationProvider,
      (_, next) => _maybeOpen(next.valueOrNull),
      fireImmediately: true,
    );
  }

  void _maybeOpen(ActiveLocationState? state) {
    if (_shown || state is! ActiveLocationDenied) return;
    _shown = true;
    _openIfAsked();
  }

  Future<void> _openIfAsked() async {
    bool asked;
    try {
      asked = await LocationPermissionState.asked();
    } catch (_) {
      asked = false;
    }
    if (!asked || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showSetLocationDrawer(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

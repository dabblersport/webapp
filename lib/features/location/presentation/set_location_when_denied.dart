import 'package:dabbler/core/services/location_permission_state.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-526: when location permission is denied and there is no active
/// location, a location surface offers the manual "Set location" drawer
/// ([ManualLocationDrawer]) instead of failing silently or asking the OS again.
/// Nothing here ever requests permission.

/// Opens the one manual location drawer, titled "Set location".
Future<void> showSetLocationDrawer(BuildContext context) {
  return showDabblerSheet<void>(
    context: context,
    title: AppLocalizations.of(context).listing_set_location,
    detent: DabblerSheetDetent.content,
    builder: (_) => const ManualLocationDrawer(),
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

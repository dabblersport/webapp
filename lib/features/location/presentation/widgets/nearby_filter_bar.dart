import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

/// Compact toggle bar for filtering a list by nearby distance.
///
/// Reusable across the games and venues tabs: each screen passes its own
/// enabled/sort state so the two lists filter independently.
///
/// States:
/// - Off: "Nearby" chip; tapping enables the filter (which lazily resolves
///   the active location).
/// - On + location ready: selected chip with area + radius, a close button to
///   disable, and a trailing "Filter" chip that opens [NearbyFilterSheet].
/// - On + locating: spinner chip.
/// - On + denied/error: error chip; tapping retries GPS.
class NearbyFilterBar extends ConsumerWidget {
  const NearbyFilterBar({
    super.key,
    required this.enabledProvider,
    required this.sortProvider,
  });

  final StateProvider<bool> enabledProvider;
  final StateProvider<NearbySortOrder> sortProvider;

  Future<void> _openFilterSheet(BuildContext context, WidgetRef ref) async {
    final result = await NearbyFilterSheet.show(context);
    if (result == null) return;
    ref.read(sortProvider.notifier).state = result.sortOrder;
    // Radius updates are applied live by NearbyRadiusSlider inside the sheet.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(enabledProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space2,
        DabblerSpacing.space6,
        DabblerSpacing.space2,
      ),
      child: Row(
        children: [
          if (!enabled)
            DabblerChip(
              label: 'Nearby',
              leadingIcon: const DabblerIcon('location'),
              onTap: () => ref.read(enabledProvider.notifier).state = true,
            )
          else
            Expanded(child: _buildEnabled(context, ref)),
        ],
      ),
    );
  }

  Widget _buildEnabled(BuildContext context, WidgetRef ref) {
    final locAsync = ref.watch(activeLocationProvider);
    final locState = locAsync.valueOrNull;

    void disable() => ref.read(enabledProvider.notifier).state = false;

    if (locAsync.isLoading || locState is ActiveLocationLoading) {
      return Row(
        children: [
          const DabblerChip(
            label: 'Locating…',
            leadingIcon: DabblerSpinner(size: DabblerSpinnerSize.sm),
          ),
          _DismissButton(onTap: disable),
        ],
      );
    }

    if (locState is ActiveLocationReady) {
      final loc = locState.location;
      final km = (loc.nearbyRadiusMeters / 1000).round();
      return Row(
        children: [
          Flexible(
            child: DabblerChip(
              label: '${loc.area.name} · $km km',
              selected: true,
              leadingIcon: const DabblerIcon('location'),
            ),
          ),
          _DismissButton(onTap: disable),
          const SizedBox(width: DabblerSpacing.space2),
          DabblerChip(
            label: 'Filter',
            leadingIcon: const DabblerIcon('setting-4'),
            onTap: () => _openFilterSheet(context, ref),
          ),
        ],
      );
    }

    // Denied / error — tap retries GPS.
    return Row(
      children: [
        Flexible(
          child: DabblerChip(
            label: 'Location unavailable — tap to retry',
            leadingIcon: DabblerIcon(
              'location-slash',
              color: DabblerColors.of(context).error.solid,
            ),
            onTap: () =>
                ref.read(activeLocationProvider.notifier).useGpsLocation(),
          ),
        ),
        _DismissButton(onTap: disable),
      ],
    );
  }
}

/// Disables the nearby filter. DabblerChip has no trailing dismiss slot, so
/// the close glyph is a small icon button beside the chip.
class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DabblerButton.icon(
      tone: DabblerButtonTone.text,
      icon: 'close-circle',
      semanticLabel: 'Turn off nearby',
      size: DabblerButtonSize.small,
      onPressed: onTap,
    );
  }
}

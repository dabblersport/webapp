import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

/// Compact toggle bar for filtering a list by nearby distance.
///
/// Reusable across the games and venues tabs: each screen passes its own
/// enabled/sort state so the two lists filter independently.
///
/// States:
/// - Off: outlined "Nearby" chip; tapping enables the filter (which lazily
///   resolves the active location).
/// - On + location ready: filled chip with area + radius, an ✕ to disable,
///   and a trailing filter button that opens [NearbyFilterSheet].
/// - On + locating: progress chip.
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          if (!enabled)
            _NearbyChip.off(
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
          _NearbyChip.locating(onDismiss: disable),
        ],
      );
    }

    if (locState is ActiveLocationReady) {
      final loc = locState.location;
      final km = (loc.nearbyRadiusMeters / 1000).round();
      return Row(
        children: [
          Flexible(
            child: _NearbyChip.on(
              label: '${loc.area.name} · $km km',
              onDismiss: disable,
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(onTap: () => _openFilterSheet(context, ref)),
        ],
      );
    }

    // Denied / error — tap retries GPS.
    return Row(
      children: [
        Flexible(
          child: _NearbyChip.unavailable(
            onTap: () =>
                ref.read(activeLocationProvider.notifier).useGpsLocation(),
            onDismiss: disable,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// CHIP
// =============================================================================

class _NearbyChip extends StatelessWidget {
  const _NearbyChip({
    required this.label,
    this.onTap,
    this.onDismiss,
    this.filled = false,
    this.error = false,
    this.busy = false,
  });

  factory _NearbyChip.off({required VoidCallback onTap}) =>
      _NearbyChip(label: 'Nearby', onTap: onTap);

  factory _NearbyChip.on({
    required String label,
    required VoidCallback onDismiss,
  }) =>
      _NearbyChip(label: label, onDismiss: onDismiss, filled: true);

  factory _NearbyChip.locating({required VoidCallback onDismiss}) =>
      _NearbyChip(label: 'Locating…', onDismiss: onDismiss, busy: true);

  factory _NearbyChip.unavailable({
    required VoidCallback onTap,
    required VoidCallback onDismiss,
  }) =>
      _NearbyChip(
        label: 'Location unavailable — tap to retry',
        onTap: onTap,
        onDismiss: onDismiss,
        error: true,
      );

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool filled;
  final bool error;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color bg;
    final Color fg;
    if (filled) {
      bg = cs.primary;
      fg = cs.onPrimary;
    } else if (error) {
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
    } else {
      bg = cs.primary.withValues(alpha: 0.1);
      fg = cs.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(
                error ? Iconsax.location_slash_copy : Iconsax.location_copy,
                size: 14,
                color: fg,
              ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: tt.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close, size: 14, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FILTER BUTTON
// =============================================================================

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.setting_4_copy, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              'Filter',
              style: tt.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

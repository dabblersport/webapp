import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_radius_slider.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

// =============================================================================
// RESULT TYPES
// =============================================================================

class NearbyFilterResult {
  const NearbyFilterResult({
    required this.radiusMeters,
    required this.sortOrder,
  });
  final int radiusMeters;
  final NearbySortOrder sortOrder;
}

// =============================================================================
// SHEET
// =============================================================================

class NearbyFilterSheet extends ConsumerStatefulWidget {
  const NearbyFilterSheet({super.key});

  static Future<NearbyFilterResult?> show(BuildContext context) {
    return showModalBottomSheet<NearbyFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const NearbyFilterSheet(),
    );
  }

  @override
  ConsumerState<NearbyFilterSheet> createState() => _NearbyFilterSheetState();
}

class _NearbyFilterSheetState extends ConsumerState<NearbyFilterSheet> {
  NearbySortOrder _sortOrder = NearbySortOrder.defaultOrder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radiusMeters = ref.watch(nearbyRadiusProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 20),

          Text(
            'Filter nearby',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // ── Search radius ───────────────────────────────────────────────
          const NearbyRadiusSlider(),
          const SizedBox(height: 24),

          // ── Sort by ─────────────────────────────────────────────────────
          Text(
            'Sort by',
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SortChip(
                label: 'Nearest first',
                selected: _sortOrder == NearbySortOrder.nearest,
                cs: cs,
                onTap: () =>
                    setState(() => _sortOrder = NearbySortOrder.nearest),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: 'Default',
                selected: _sortOrder == NearbySortOrder.defaultOrder,
                cs: cs,
                onTap: () =>
                    setState(() => _sortOrder = NearbySortOrder.defaultOrder),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Apply ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                NearbyFilterResult(
                  radiusMeters: radiusMeters,
                  sortOrder: _sortOrder,
                ),
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SORT CHIP
// =============================================================================

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

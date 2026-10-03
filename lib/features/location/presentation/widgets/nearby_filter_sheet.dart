import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
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

/// Body of the "Filter nearby" sheet. Surface, handle, title and scrim come
/// from [showDabblerSheet]; the Apply action is the body's last row so it
/// shares the body's state (sort order).
class NearbyFilterSheet extends ConsumerStatefulWidget {
  const NearbyFilterSheet({super.key});

  static Future<NearbyFilterResult?> show(BuildContext context) {
    return showDabblerSheet<NearbyFilterResult>(
      context: context,
      title: 'Filter nearby',
      detent: DabblerSheetDetent.content,
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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final radiusMeters = ref.watch(nearbyRadiusProvider);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom + DabblerSpacing.space8,
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        top: DabblerSpacing.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search radius ───────────────────────────────────────────────
          const NearbyRadiusSlider(),
          const SizedBox(height: DabblerSpacing.space8),

          // ── Sort by ─────────────────────────────────────────────────────
          Text(
            'Sort by',
            style: DabblerType.headline
                .resolveForDirection(direction)
                .copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: DabblerSpacing.space3),
          Wrap(
            spacing: DabblerSpacing.space3,
            runSpacing: DabblerSpacing.space3,
            children: [
              DabblerChip(
                label: 'Nearest first',
                selected: _sortOrder == NearbySortOrder.nearest,
                onTap: () =>
                    setState(() => _sortOrder = NearbySortOrder.nearest),
              ),
              DabblerChip(
                label: 'Default',
                selected: _sortOrder == NearbySortOrder.defaultOrder,
                onTap: () =>
                    setState(() => _sortOrder = NearbySortOrder.defaultOrder),
              ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space9),

          // ── Apply ───────────────────────────────────────────────────────
          DabblerButton(
            label: 'Apply',
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(
              NearbyFilterResult(
                radiusMeters: radiusMeters,
                sortOrder: _sortOrder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

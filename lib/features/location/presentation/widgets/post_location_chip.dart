import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/providers/location_providers.dart';

/// A compact chip that shows a post's location.
///
/// Displays `location_name` if available, otherwise resolves and caches the
/// area name from `area_id`. Tapping opens a feed filtered by the post's area.
class PostLocationChip extends ConsumerWidget {
  const PostLocationChip({
    super.key,
    required this.areaId,
    this.locationName,
    this.onTap,
  });

  /// The post's `area_id` — always non-null for posts from `feed_posts`.
  final String areaId;

  /// Optional human-readable name (e.g. venue name or user-typed label).
  final String? locationName;

  /// Called when the chip is tapped. If null, defaults to no-op.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If we already have a location_name, show it directly.
    if (locationName != null && locationName!.isNotEmpty) {
      return _buildChip(context, locationName!);
    }

    // Otherwise resolve the area name from the cached provider.
    final areaNameAsync = ref.watch(areaNameProvider(areaId));

    return areaNameAsync.when(
      data: (name) => _buildChip(context, name),
      loading: () => _buildChip(context, '...'),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildChip(BuildContext context, String label) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerIcon('location', size: 12, color: colors.textSecondary),
          const SizedBox(width: DabblerSpacing.space1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DabblerType.footnote
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

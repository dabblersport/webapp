import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // If we already have a location_name, show it directly.
    if (locationName != null && locationName!.isNotEmpty) {
      return _buildChip(context: context, label: locationName!, cs: cs, tt: tt);
    }

    // Otherwise resolve the area name from the cached provider.
    final areaNameAsync = ref.watch(areaNameProvider(areaId));

    return areaNameAsync.when(
      data: (name) => _buildChip(context: context, label: name, cs: cs, tt: tt),
      loading: () => _buildChip(context: context, label: '...', cs: cs, tt: tt),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.location, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

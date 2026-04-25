import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

/// Tappable location bar shown at the top of the home screen.
///
/// ```
/// 📍 Dubai Marina  ▾        [🔄]
///    JLT & Marina · Dubai
/// ```
///
/// - Shows area name + district · city
/// - GPS icon / saved label / pin icon as source indicator
/// - Refresh button only when source == gps
/// - Shimmer while loading
/// - "Set your location" CTA when denied
/// - Tap (except refresh) → opens [LocationPickerSheet]
class HomeLocationBar extends ConsumerWidget {
  const HomeLocationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final locationAsync = ref.watch(activeLocationProvider);

    return locationAsync.when(
      loading: () => _ShimmerBar(cs: cs),
      error: (_, __) => _DeniedBar(cs: cs),
      data: (state) => switch (state) {
        ActiveLocationLoading() => _ShimmerBar(cs: cs),
        ActiveLocationDenied() => _DeniedBar(cs: cs),
        ActiveLocationError() => _DeniedBar(cs: cs),
        ActiveLocationReady(:final location) => _ReadyBar(
          location: location,
          cs: cs,
          radius: ref.watch(nearbyRadiusProvider),
          onTap: () => _openPicker(context),
          onRefresh: () => ref.read(activeLocationProvider.notifier).refresh(),
        ),
      },
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) =>
            HomeLocationPickerSheet(scrollController: scrollController),
      ),
    );
  }
}

// =============================================================================
// READY STATE
// =============================================================================

class _ReadyBar extends StatelessWidget {
  const _ReadyBar({
    required this.location,
    required this.cs,
    required this.radius,
    required this.onTap,
    required this.onRefresh,
  });

  final ActiveLocation location;
  final ColorScheme cs;
  final int radius;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final radiusKm = (radius / 1000).round();
    final subtitle =
        '${location.area.district} · ${location.area.city}  ·  $radiusKm km';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          location.area.name,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Source indicator
            _SourceBadge(location: location, cs: cs),
            const SizedBox(width: 4),
            // Refresh button — only for GPS source
            if (location.source == ActiveLocationSource.gps)
              IconButton(
                onPressed: onRefresh,
                icon: Icon(Icons.refresh, size: 18, color: cs.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Refresh location',
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.location, required this.cs});
  final ActiveLocation location;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    switch (location.source) {
      case ActiveLocationSource.gps:
        return Icon(Icons.gps_fixed, size: 14, color: cs.primary);
      case ActiveLocationSource.saved:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            location.savedLocationLabel ?? 'Saved',
            style: tt.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case ActiveLocationSource.manual:
        return Icon(Icons.push_pin_outlined, size: 14, color: cs.primary);
    }
  }
}

// =============================================================================
// SHIMMER PLACEHOLDER
// =============================================================================

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Shimmer.fromColors(
        baseColor: cs.surfaceContainerHigh,
        highlightColor: cs.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 14,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 100,
              height: 10,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DENIED STATE
// =============================================================================

class _DeniedBar extends StatelessWidget {
  const _DeniedBar({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          builder: (ctx, sc) => HomeLocationPickerSheet(scrollController: sc),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_off_outlined, size: 18, color: cs.error),
            const SizedBox(width: 8),
            Text(
              'Set your location',
              style: tt.bodyMedium?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 12, color: cs.error),
          ],
        ),
      ),
    );
  }
}

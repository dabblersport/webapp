import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

/// Tappable location bar shown at the top of the home screen.
///
/// ```
/// [pin] Dubai Marina  v        [refresh]
///       JLT & Marina · Dubai
/// ```
///
/// - Shows area name + district · city
/// - GPS icon / saved label / pin icon as source indicator
/// - Refresh button only when source == gps
/// - Skeleton while loading
/// - "Set your location" CTA when denied
/// - Tap (except refresh) → opens [HomeLocationPickerSheet]
class HomeLocationBar extends ConsumerWidget {
  const HomeLocationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(activeLocationProvider);

    return locationAsync.when(
      loading: () => const _SkeletonBar(),
      error: (_, __) => const _DeniedBar(),
      data: (state) => switch (state) {
        ActiveLocationLoading() => const _SkeletonBar(),
        ActiveLocationDenied() => const _DeniedBar(),
        ActiveLocationError() => const _DeniedBar(),
        ActiveLocationReady(:final location) => _ReadyBar(
          location: location,
          radius: ref.watch(nearbyRadiusProvider),
          onTap: () => HomeLocationPickerSheet.show(context),
          onRefresh: () => ref.read(activeLocationProvider.notifier).refresh(),
        ),
      },
    );
  }
}

// =============================================================================
// READY STATE
// =============================================================================

class _ReadyBar extends StatelessWidget {
  const _ReadyBar({
    required this.location,
    required this.radius,
    required this.onTap,
    required this.onRefresh,
  });

  final ActiveLocation location;
  final int radius;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final radiusKm = (radius / 1000).round();
    final subtitle =
        '${location.area.district} · ${location.area.city}  ·  $radiusKm km';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DabblerSpacing.space6,
          vertical: DabblerSpacing.space2,
        ),
        child: Row(
          children: [
            DabblerIcon(
              'location',
              weight: DabblerIconWeight.bold,
              size: DabblerSizing.iconSm,
              color: colors.brandPrimary,
            ),
            const SizedBox(width: DabblerSpacing.space2),
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
                          style: DabblerType.headline
                              .resolveForDirection(direction)
                              .copyWith(color: colors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: DabblerSpacing.space1),
                      DabblerIcon(
                        'arrow-down',
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: DabblerType.footnote
                        .resolveForDirection(direction)
                        .copyWith(color: colors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Source indicator
            _SourceBadge(location: location),
            const SizedBox(width: DabblerSpacing.space1),
            // Refresh button — only for GPS source
            if (location.source == ActiveLocationSource.gps)
              DabblerButton.icon(
                tone: DabblerButtonTone.text,
                icon: 'refresh',
                semanticLabel: 'Refresh location',
                size: DabblerButtonSize.small,
                onPressed: onRefresh,
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.location});
  final ActiveLocation location;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    switch (location.source) {
      case ActiveLocationSource.gps:
        return DabblerIcon('gps', size: 14, color: colors.brandPrimary);
      case ActiveLocationSource.saved:
        return DabblerBadge(label: location.savedLocationLabel ?? 'Saved');
      case ActiveLocationSource.manual:
        return DabblerIcon(
          'location-tick',
          size: 14,
          color: colors.brandPrimary,
        );
    }
  }
}

// =============================================================================
// SKELETON PLACEHOLDER
// =============================================================================

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerSkeleton.rect(width: 140, height: 14),
          SizedBox(height: DabblerSpacing.space1),
          DabblerSkeleton.rect(width: 100, height: 10),
        ],
      ),
    );
  }
}

// =============================================================================
// DENIED STATE
// =============================================================================

class _DeniedBar extends StatelessWidget {
  const _DeniedBar();

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final ink = colors.error.strong;
    return GestureDetector(
      onTap: () => HomeLocationPickerSheet.show(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DabblerSpacing.space6,
          vertical: DabblerSpacing.space3,
        ),
        child: Row(
          children: [
            DabblerIcon(
              'location-slash',
              size: DabblerSizing.iconSm,
              color: ink,
            ),
            const SizedBox(width: DabblerSpacing.space3),
            Text(
              'Set your location',
              style: DabblerType.headline
                  .resolveForDirection(Directionality.of(context))
                  .copyWith(color: ink),
            ),
            const SizedBox(width: DabblerSpacing.space1),
            DabblerChevron(color: ink),
          ],
        ),
      ),
    );
  }
}

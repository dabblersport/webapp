import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';

/// Inline chip that opens [LocationPickerSheet] and writes the result
/// into [PostComposerNotifier] via [setLocationFromPickerResult].
class ComposerLocationChip extends ConsumerWidget {
  const ComposerLocationChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postComposerProvider);
    final cs = Theme.of(context).colorScheme;
    final hasLoc = state.hasLocation || state.hasVenue;

    if (hasLoc) {
      final label = state.venueName ?? state.locationName ?? 'Location';
      final emoji = state.hasVenue ? '🏟️' : '📍';

      return Container(
        height: 36,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () {
                final notifier = ref.read(postComposerProvider.notifier);
                if (state.hasVenue) {
                  notifier.clearVenue();
                } else {
                  notifier.clearLocation();
                }
              },
              child: Icon(Icons.close, size: 16, color: cs.onPrimaryContainer),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        final result = await LocationPickerSheet.show(context);
        if (result != null) {
          ref
              .read(postComposerProvider.notifier)
              .setLocationFromPickerResult(result);
        }
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Location',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

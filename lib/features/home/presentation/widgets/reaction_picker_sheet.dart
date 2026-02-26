import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Bottom sheet that displays a grid of vibes (reactions) for a post.
///
/// Tapping a vibe toggles the reaction: adds if not yet reacted, removes if
/// already present. The sheet closes after a single tap.
class ReactionPickerSheet extends ConsumerWidget {
  const ReactionPickerSheet({
    super.key,
    required this.postId,
    required this.myReactions,
  });

  final String postId;

  /// Vibe IDs the current user has already reacted with.
  final Set<String> myReactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibesAsync = ref.watch(vibesProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'React with a Vibe',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),

              // ── Grid ──
              Expanded(
                child: vibesAsync.when(
                  data: (vibes) {
                    if (vibes.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No vibes available'),
                      );
                    }
                    return GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: vibes.length,
                      itemBuilder: (context, index) {
                        final vibe = vibes[index];
                        final isSelected = myReactions.contains(vibe.id);
                        return _VibeCell(
                          vibe: vibe,
                          isSelected: isSelected,
                          onTap: () =>
                              _onVibeTapped(context, ref, vibe, isSelected),
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load vibes: $e'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onVibeTapped(
    BuildContext context,
    WidgetRef ref,
    Vibe vibe,
    bool isSelected,
  ) {
    final actions = ref.read(postActionsProvider.notifier);
    if (isSelected) {
      actions.removeReaction(postId, vibe.id);
    } else {
      actions.reactToPost(postId, vibe.id);
    }
    Navigator.of(context).pop();
  }
}

class _VibeCell extends StatelessWidget {
  const _VibeCell({
    required this.vibe,
    required this.isSelected,
    required this.onTap,
  });

  final Vibe vibe;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final emoji = vibe.emoji ?? '';
    final label = vibe.labelEn.isNotEmpty
        ? vibe.labelEn
        : vibe.key[0].toUpperCase() + vibe.key.substring(1);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: cs.primary, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                fontSize: 9,
                color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

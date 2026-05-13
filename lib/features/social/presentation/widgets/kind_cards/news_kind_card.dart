import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/home/presentation/widgets/reaction_picker_sheet.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/features/social/utils/post_sport_label.dart';

/// News-style card: horizontal layout with image thumbnail on the right,
/// headline-weight body text on the left, and a blue accent stripe.
class NewsKindCard extends ConsumerWidget {
  const NewsKindCard({super.key, required this.post});

  final Post post;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt);
  }

  String? _firstImageUrl(List<dynamic> media) {
    if (media.isEmpty) return null;
    final first = media.first;
    if (first is Map) {
      return (first['url'] ?? first['uri'] ?? first['src'])?.toString();
    }
    if (first is String && first.startsWith('http')) return first;
    return null;
  }

  List<MapEntry<dynamic, dynamic>> _reactionEntries() {
    final rawBreakdown = post.reactionBreakdown['breakdown'];
    if (rawBreakdown is Map) {
      return rawBreakdown.entries
          .where((e) => e.value is int && (e.value as int) > 0)
          .toList();
    }
    return [];
  }

  void _showReactionPicker(BuildContext context, Set<String> myReactions) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) =>
          ReactionPickerSheet(postId: post.id, myReactions: myReactions),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final imageUrl = _firstImageUrl(post.media);
    final timeAgo = _relativeTime(post.createdAt);

    final myReactions =
        ref.watch(myReactionsProvider(post.id)).valueOrNull ?? <String>{};
    final vibesList = ref.watch(vibesProvider).valueOrNull ?? [];
    final entries = _reactionEntries();
    final totalReactions = entries.fold<int>(0, (s, e) => s + (e.value as int));

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main content row ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Text content ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kind label + time
                        Row(
                          children: [
                            Icon(
                              Icons.article_rounded,
                              size: 14,
                              color: const Color(0xFF2193B0),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'NEWS',
                              style: tt.labelSmall?.copyWith(
                                color: const Color(0xFF2193B0),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timeAgo,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Headline body
                        if (post.body != null && post.body!.trim().isNotEmpty)
                          Text(
                            post.body!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),

                        // Sport chip
                        if (post.sport != null &&
                            post.sport!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            resolvePostSportLabel(context, ref, post),
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Thumbnail ──
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                    ),
                    child: SizedBox(
                      width: 100,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Reaction chips ──
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: entries.take(5).map((entry) {
                  final vibeKey = entry.key.toString();
                  final count = entry.value as int;
                  final matchedVibe = vibesList
                      .where((v) => v.key == vibeKey)
                      .firstOrNull;
                  final emoji = matchedVibe?.emoji ?? vibeKey;
                  final isMyReaction =
                      matchedVibe != null &&
                      myReactions.contains(matchedVibe.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        if (matchedVibe == null) return;
                        final actions = ref.read(postActionsProvider.notifier);
                        if (isMyReaction) {
                          actions.removeReaction(post.id, matchedVibe.id);
                        } else {
                          actions.reactToPost(post.id, matchedVibe.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isMyReaction
                              ? cs.primaryContainer
                              : cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: isMyReaction
                              ? Border.all(color: cs.primary, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          '$emoji $count',
                          style: tt.labelSmall?.copyWith(
                            color: isMyReaction ? cs.onPrimaryContainer : null,
                            fontWeight: isMyReaction ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Action bar ──
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.md,
            ),
            child: Row(
              children: [
                // React button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showReactionPicker(context, myReactions),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.add_circle_copy,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      if (totalReactions > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$totalReactions',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

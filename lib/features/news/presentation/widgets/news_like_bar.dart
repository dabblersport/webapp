import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/social/providers/post_providers.dart' show myReactionsProvider, postActionsProvider;

const _newsReactions = [
  _NewsReaction(id: 'bbcccbeb-e506-4906-8a58-018659d0a43d', emoji: '❤️', label: 'Loving'),
  _NewsReaction(id: '477472a9-7535-42b6-b08d-d6054eee9856', emoji: '💪', label: 'Determined'),
  _NewsReaction(id: '350a7cca-b044-4b22-8c96-add0dd39c059', emoji: '🔥', label: 'Motivated'),
  _NewsReaction(id: '177211d5-73a4-4835-a7f2-48fd238c778d', emoji: '🏅', label: 'Proud'),
  _NewsReaction(id: 'f4a9f402-2dbd-40a9-8a6c-61cbea065145', emoji: '🥲', label: 'Disappointed'),
  _NewsReaction(id: '4af43b42-a0f3-4008-812b-0b40548e32f6', emoji: '😡', label: 'Angry'),
];

class _NewsReaction {
  const _NewsReaction({required this.id, required this.emoji, required this.label});
  final String id;
  final String emoji;
  final String label;
}

final newsReactionCountsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, newsId) async {
  final db = Supabase.instance.client;
  final allowedIds = _newsReactions.map((r) => r.id).toList();
  final rows = await db
      .from('reactions')
      .select('vibe_id')
      .eq('parent_activity_id', newsId)
      .inFilter('vibe_id', allowedIds) as List;
  final counts = <String, int>{};
  for (final row in rows) {
    final id = row['vibe_id'] as String;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
});

class NewsLikeBar extends ConsumerWidget {
  const NewsLikeBar({
    super.key,
    required this.newsId,
    required this.commentCount,
    required this.viewCount,
    this.onCommentTap,
  });

  final String newsId;
  final int commentCount;
  final int viewCount;
  final VoidCallback? onCommentTap;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final myReactions = ref.watch(myReactionsProvider(newsId)).valueOrNull ?? const <String>{};
    final reactionCounts = ref.watch(newsReactionCountsProvider(newsId)).valueOrNull ?? {};

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 6 fixed reactions (loving + 5 sports emotions)
          for (final reaction in _newsReactions) ...[
            _EmojiItem(
              reaction: reaction,
              count: reactionCounts[reaction.id] ?? 0,
              selected: myReactions.contains(reaction.id),
              tt: tt,
              cs: cs,
              onTap: () async {
                if (myReactions.contains(reaction.id)) {
                  await ref
                      .read(postActionsProvider.notifier)
                      .removeReaction(newsId, reaction.id);
                } else {
                  await ref
                      .read(postActionsProvider.notifier)
                      .reactToPost(newsId, reaction.id);
                }
                ref.invalidate(newsReactionCountsProvider(newsId));
              },
            ),
            const SizedBox(width: 12),
          ],

          // Comment
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCommentTap,
            child: _ActionItem(
              icon: Iconsax.message_copy,
              count: commentCount,
              color: cs.onSurfaceVariant,
              tt: tt,
              fmt: _fmt,
            ),
          ),
          const SizedBox(width: 12),

          // Views
          _ActionItem(
            icon: Iconsax.eye_copy,
            count: viewCount,
            color: cs.onSurfaceVariant,
            tt: tt,
            fmt: _fmt,
          ),
        ],
      ),
    );
  }
}

class _EmojiItem extends StatelessWidget {
  const _EmojiItem({
    required this.reaction,
    required this.count,
    required this.selected,
    required this.tt,
    required this.cs,
    required this.onTap,
  });

  final _NewsReaction reaction;
  final int count;
  final bool selected;
  final TextTheme tt;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: selected
            ? BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 16)),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text(
                count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}K' : '$count',
                style: tt.bodySmall?.copyWith(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.count,
    required this.color,
    required this.tt,
    required this.fmt,
  });

  final IconData icon;
  final int count;
  final Color color;
  final TextTheme tt;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        if (count > 0) ...[
          const SizedBox(width: 3),
          Text(fmt(count), style: tt.bodySmall?.copyWith(color: color)),
        ],
      ],
    );
  }
}

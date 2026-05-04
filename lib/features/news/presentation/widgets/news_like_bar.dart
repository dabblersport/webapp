import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/features/home/presentation/widgets/reaction_picker_sheet.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';

/// Like/reaction/comment/views bar for news articles.
///
/// Visually identical to the post card action bar — uses the same icon set,
/// sizes, spacing, and count formatting. Likes and reactions route through the
/// shared post providers since news shares public_activities.id space.
class NewsLikeBar extends ConsumerWidget {
  const NewsLikeBar({
    super.key,
    required this.newsId,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    this.onCommentTap,
  });

  final String newsId;
  final int likeCount;
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

    final isLikedAsync = ref.watch(hasLikedProvider(newsId));
    final isLiked = isLikedAsync.valueOrNull ?? false;

    final myReactionsAsync = ref.watch(myReactionsProvider(newsId));
    final myReactions = myReactionsAsync.valueOrNull ?? const <String>{};

    return Row(
      children: [
        // ── Like ────────────────────────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            if (isLiked) {
              await ref.read(postActionsProvider.notifier).unlikePost(newsId);
            } else {
              await ref.read(postActionsProvider.notifier).likePost(newsId);
            }
          },
          child: _ActionItem(
            icon: isLiked ? Iconsax.heart : Iconsax.heart_copy,
            count: likeCount,
            color: isLiked ? cs.error : cs.onSurfaceVariant,
            tt: tt,
            fmt: _fmt,
          ),
        ),
        const SizedBox(width: 16),

        // ── Reactions ────────────────────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showAdaptiveSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            showDragHandle: false,
            builder: (_) => ReactionPickerSheet(
              postId: newsId,
              myReactions: myReactions,
            ),
          ),
          child: _ActionItem(
            icon: Iconsax.add_circle_copy,
            count: myReactions.length,
            color: myReactions.isNotEmpty ? cs.primary : cs.onSurfaceVariant,
            tt: tt,
            fmt: _fmt,
          ),
        ),
        const SizedBox(width: 16),

        // ── Comment ──────────────────────────────────────────────────────────
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
        const SizedBox(width: 16),

        // ── Views ────────────────────────────────────────────────────────────
        _ActionItem(
          icon: Iconsax.eye_copy,
          count: viewCount,
          color: cs.onSurfaceVariant,
          tt: tt,
          fmt: _fmt,
        ),
      ],
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

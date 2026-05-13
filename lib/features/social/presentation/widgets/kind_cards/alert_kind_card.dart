import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/utils/post_sport_label.dart';

/// Alert card: red-tinted surface with a warning icon and prominent body.
/// Designed to grab attention — compact but visually urgent.
class AlertKindCard extends StatelessWidget {
  const AlertKindCard({super.key, required this.post});

  final Post post;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final timeAgo = _relativeTime(post.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + label + time ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: cs.error,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ALERT',
                style: tt.labelMedium?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: tt.bodySmall?.copyWith(
                  color: cs.onErrorContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          // ── Body ──
          if (post.body != null && post.body!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              post.body!,
              style: tt.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],

          // ── Sport tag ──
          if (post.sport != null && post.sport!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Consumer(
              builder: (context, ref, _) => Text(
                resolvePostSportLabel(context, ref, post),
                style: tt.labelSmall?.copyWith(
                  color: cs.onErrorContainer.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/utils/post_sport_label.dart';

/// Announcement card: bold gradient banner at the top with a megaphone icon,
/// followed by prominent body text on a tinted surface.
class AnnouncementKindCard extends StatelessWidget {
  const AnnouncementKindCard({super.key, required this.post});

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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF7A18).withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gradient banner ──
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF7A18), Color(0xFFFFB347)],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'ANNOUNCEMENT',
                  style: tt.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // ── Body content ──
          Container(
            color: cs.surfaceContainerLow,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.body != null && post.body!.trim().isNotEmpty)
                  Text(
                    post.body!,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                if (post.sport != null && post.sport!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Consumer(
                    builder: (context, ref, _) => Chip(
                      label: Text(resolvePostSportLabel(context, ref, post)),
                      labelStyle: tt.labelSmall?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                      backgroundColor: cs.secondaryContainer,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

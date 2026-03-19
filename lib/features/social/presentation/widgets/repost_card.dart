import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'feed_post_card.dart';

/// Card used in the feed when a post has `originType == OriginType.repost`.
///
/// Structure:
///   - Full author header (avatar, name, badge, time, meta row)
///   - Optional quote text (the repost body)
///   - Embedded original post card
class RepostCard extends ConsumerWidget {
  const RepostCard({super.key, required this.post});

  final Post post;

  Future<void> _navigateToAuthorProfile(
    BuildContext ctx,
    WidgetRef ref,
    Post p,
  ) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final myProfileId = await ref.read(myProfileIdProvider.future);
    if (!ctx.mounted) return;
    if (p.authorUserId == currentUserId && p.authorProfileId == myProfileId) {
      ctx.go(RoutePaths.profile);
    } else {
      ctx.push(
        '${RoutePaths.userProfile}/${p.authorUserId}?profileId=${p.authorProfileId}',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final original = post.originalPost;

    final author = (post.authorDisplayName ?? '').trim();
    final authorLabel = author.isEmpty ? 'Anonymous' : author;
    final isAnonymous = author.isEmpty;
    final timeAgo = _relativeTime(post.createdAt);
    final typeLabel = _postTypeLabel(post.postType);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ Avatar with sport emoji ═══
          GestureDetector(
            onTap: isAnonymous
                ? null
                : () => _navigateToAuthorProfile(context, ref, post),
            child: SizedBox(
              width: 48,
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _RepostAuthorAvatar(
                    avatarUrl: post.authorAvatarUrl,
                    label: authorLabel,
                    radius: 22,
                    isAnonymous: isAnonymous,
                    cs: cs,
                  ),
                  if (!isAnonymous && post.authorSportEmoji != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            post.authorSportEmoji!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ═══ Content column (all repost content) ═══
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Author name + persona badge + time ──
                Row(
                  children: [
                    Flexible(
                      flex: 0,
                      child: GestureDetector(
                        onTap: isAnonymous
                            ? null
                            : () =>
                                  _navigateToAuthorProfile(context, ref, post),
                        child: Text(
                          authorLabel,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (post.personaTypeSnapshot != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: post.personaTypeSnapshot == 'organiser'
                              ? cs.tertiaryContainer
                              : cs.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          post.personaTypeSnapshot == 'organiser'
                              ? 'Organiser'
                              : 'Player',
                          style: tt.labelSmall?.copyWith(
                            color: post.personaTypeSnapshot == 'organiser'
                                ? cs.onTertiaryContainer
                                : cs.onErrorContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                  ],
                ),

                // ── Repost meta row ──
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 12, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Repost',
                      style: tt.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    _dotSep(tt, cs),
                    Text(
                      _kindLabel(post.kind),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (typeLabel != null) ...[
                      _dotSep(tt, cs),
                      Flexible(
                        child: Text(
                          typeLabel,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Quote text (optional) ──
                if (post.body != null && post.body!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      post.body!,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        height: 1.4,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // ── Embedded original post ──
                if (original != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FeedPostCard(post: original, isEmbedded: true),
                    ),
                  ),

                // If original post is missing (e.g. deleted), show placeholder
                if (original == null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Original post is no longer available.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
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

// ── Helpers ─────────────────────────────────────────────────────────

String _relativeTime(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat.MMMd().format(createdAt);
}

String _kindLabel(PostKind kind) {
  switch (kind) {
    case PostKind.moment:
      return 'Moment';
    case PostKind.dab:
      return 'Dab';
    case PostKind.kickin:
      return 'Kick-In';
  }
}

String? _postTypeLabel(PostType type) {
  switch (type) {
    case PostType.moment:
      return 'My Story';
    case PostType.dab:
      return null;
    case PostType.kickIn:
      return 'Kick-In';
  }
}

Widget _dotSep(TextTheme tt, ColorScheme cs) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Text('·', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
  );
}

// ── Avatar widget ───────────────────────────────────────────────────

class _RepostAuthorAvatar extends StatelessWidget {
  const _RepostAuthorAvatar({
    required this.avatarUrl,
    required this.label,
    required this.radius,
    required this.isAnonymous,
    required this.cs,
  });

  final String? avatarUrl;
  final String label;
  final double radius;
  final bool isAnonymous;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (isAnonymous) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.errorContainer,
        child: Icon(Icons.person_off, size: radius, color: cs.error),
      );
    }

    return DSAvatar(
      size: AvatarSize.medium,
      customDimension: radius * 2,
      imageUrl: avatarUrl,
      displayName: label,
      context: AvatarContext.social,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      hasBorder: false,
    );
  }

  // ignore: unused_element
  Widget _initials() => Text(
    label[0].toUpperCase(),
    style: TextStyle(
      fontSize: radius * 0.8,
      fontWeight: FontWeight.w600,
      color: cs.onPrimaryContainer,
    ),
  );
}

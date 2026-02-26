import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/reaction_picker_sheet.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Shared post card used in Feed, ProfileScreen, and UserProfileScreen.
///
/// This is a 1:1 extraction of `_HomePostCard` so that all surfaces render
/// posts with exactly the same visual style and interactive behaviour.
class FeedPostCard extends ConsumerStatefulWidget {
  const FeedPostCard({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard> {
  Post get post => widget.post;

  // ── Navigation ──────────────────────────────────────────────────────

  Future<void> _navigateToAuthorProfile(BuildContext ctx, Post p) async {
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

  // ── Optimistic like state ───────────────────────────────────────────

  late int _localLikeCount;
  bool? _optimisticLiked;

  @override
  void initState() {
    super.initState();
    _localLikeCount = post.likeCount;
  }

  @override
  void didUpdateWidget(FeedPostCard old) {
    super.didUpdateWidget(old);
    if (old.post.likeCount != widget.post.likeCount) {
      _localLikeCount = widget.post.likeCount;
    }
  }

  Future<void> _handleLikeTap(bool currentlyLiked) async {
    final nowLiked = !currentlyLiked;
    setState(() {
      _optimisticLiked = nowLiked;
      _localLikeCount = nowLiked
          ? _localLikeCount + 1
          : (_localLikeCount - 1).clamp(0, double.maxFinite).toInt();
    });

    final bool success;
    if (nowLiked) {
      success = await ref.read(postActionsProvider.notifier).likePost(post.id);
    } else {
      success = await ref
          .read(postActionsProvider.notifier)
          .unlikePost(post.id);
    }

    if (!success && mounted) {
      setState(() {
        _optimisticLiked = currentlyLiked;
        _localLikeCount = currentlyLiked
            ? _localLikeCount + 1
            : (_localLikeCount - 1).clamp(0, double.maxFinite).toInt();
      });
    }
  }

  void _showReactionPicker(Set<String> myReactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ReactionPickerSheet(postId: post.id, myReactions: myReactions),
    );
  }

  // ── Reaction helpers ────────────────────────────────────────────────

  List<MapEntry<dynamic, dynamic>> _reactionBreakdownEntries(Post post) {
    final rawBreakdown = post.reactionBreakdown['breakdown'];
    if (rawBreakdown is Map) {
      return rawBreakdown.entries
          .where((e) => e.value is int && (e.value as int) > 0)
          .toList();
    }
    return [];
  }

  Widget _buildReactIcon(Set<String> myReactions, ColorScheme cs) {
    if (myReactions.isNotEmpty) {
      final vibesList = ref.watch(vibesProvider).valueOrNull ?? [];
      for (final vId in myReactions) {
        final match = vibesList.where((v) => v.id == vId).firstOrNull;
        if (match != null && match.emoji != null && match.emoji!.isNotEmpty) {
          return Text(match.emoji!, style: const TextStyle(fontSize: 18));
        }
      }
    }
    return Icon(
      Icons.add_reaction_outlined,
      size: 18,
      color: cs.onSurfaceVariant,
    );
  }

  // ── Data helpers ────────────────────────────────────────────────────

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

  IconData _visibilityIcon(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return Icons.public;
      case PostVisibility.followers:
        return Icons.people_outline;
      case PostVisibility.circle:
        return Icons.group_outlined;
      case PostVisibility.squad:
        return Icons.groups_outlined;
      case PostVisibility.private:
        return Icons.lock_outline;
      case PostVisibility.link:
        return Icons.link;
    }
  }

  String? _originLabel(OriginType origin) {
    switch (origin) {
      case OriginType.manual:
        return null;
      case OriginType.game:
        return 'Game';
      case OriginType.achievement:
        return 'Achievement';
      case OriginType.venue:
        return 'Venue';
      case OriginType.admin:
        return 'Admin';
      case OriginType.system:
        return 'System';
      case OriginType.repost:
        return 'Repost';
    }
  }

  Color _parseHexColor(String? hex, ColorScheme cs) {
    if (hex == null || hex.isEmpty) return cs.secondaryContainer;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return cs.secondaryContainer;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return cs.secondaryContainer;
    return Color(0xFF000000 | value);
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  String? _expiryLabel(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return 'Expires in ${diff.inDays}d';
    if (diff.inHours > 0) return 'Expires in ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Expires in ${diff.inMinutes}m';
    return 'Expiring soon';
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasLikedAsync = ref.watch(hasLikedProvider(post.id));
    final hasLiked = _optimisticLiked ?? hasLikedAsync.valueOrNull ?? false;
    final myReactionsAsync = ref.watch(myReactionsProvider(post.id));
    final myReactions = myReactionsAsync.valueOrNull ?? <String>{};
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final author = (post.authorDisplayName ?? '').trim();
    final authorLabel = author.isEmpty ? 'Anonymous' : author;
    final isAnonymous = author.isEmpty;
    final timeAgo = _relativeTime(post.createdAt);
    final typeLabel = _postTypeLabel(post.postType);
    final originLabel = _originLabel(post.originType);
    final imageUrl = _firstImageUrl(post.media);
    final hasImage = imageUrl != null;
    final expiryText = _expiryLabel(post.expiresAt);
    final hasLocation = post.geoLat != null && post.geoLng != null;

    return GestureDetector(
      onTap: () => context.push('${RoutePaths.socialPostDetail}/${post.id}'),
      child: Container(
        //margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Author row ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: isAnonymous
                        ? null
                        : () => _navigateToAuthorProfile(context, post),
                    child: _AuthorAvatar(
                      avatarUrl: resolveAvatarUrl(post.authorAvatarUrl),
                      label: authorLabel,
                      radius: 20,
                      isAnonymous: isAnonymous,
                      cs: cs,
                      tt: tt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: isAnonymous
                          ? null
                          : () => _navigateToAuthorProfile(context, post),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  authorLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (post.personaTypeSnapshot != null) ...[
                                const SizedBox(width: 6),
                                _MetaBadge(
                                  label: post.personaTypeSnapshot == 'organiser'
                                      ? '🎯 Org'
                                      : '🎮 Player',
                                  color: cs.tertiaryContainer,
                                  textColor: cs.onTertiaryContainer,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                _visibilityIcon(post.visibility),
                                size: 12,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeAgo,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              _dotSep(tt, cs),
                              Text(
                                _kindLabel(post.kind),
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
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
                              if (post.isEdited) ...[
                                _dotSep(tt, cs),
                                Text(
                                  'edited',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (post.isPinned)
                    Icon(Icons.push_pin, size: 16, color: cs.primary),
                ],
              ),
            ),

            // ═══ Contextual metadata chips ═══
            if (originLabel != null ||
                post.lang != null ||
                hasLocation ||
                post.requiresModeration ||
                expiryText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (originLabel != null)
                      _MetaBadge(
                        label: '🔗 $originLabel',
                        color: cs.secondaryContainer,
                        textColor: cs.onSecondaryContainer,
                      ),
                    if (hasLocation)
                      _MetaBadge(
                        label: '📍 Location',
                        color: cs.secondaryContainer,
                        textColor: cs.onSecondaryContainer,
                      ),
                    if (post.lang != null && post.lang!.isNotEmpty)
                      _MetaBadge(
                        label: '🌐 ${post.lang!.toUpperCase()}',
                        color: cs.surfaceContainerHigh,
                        textColor: cs.onSurfaceVariant,
                      ),
                    if (post.requiresModeration)
                      _MetaBadge(
                        label: '⏳ Pending review',
                        color: cs.errorContainer,
                        textColor: cs.onErrorContainer,
                      ),
                    if (expiryText != null)
                      _MetaBadge(
                        label: '⏱ $expiryText',
                        color: cs.errorContainer,
                        textColor: cs.onErrorContainer,
                      ),
                  ],
                ),
              ),

            // ═══ Image ═══
            if (hasImage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHigh,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ═══ Body text ═══
            if (post.body != null && post.body!.trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16, hasImage ? 10 : 8, 16, 0),
                child: Text(
                  post.body!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                ),
              ),

            // ═══ Tags ═══
            if (post.tags.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: post.tags.skip(1).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: tt.labelSmall?.copyWith(color: cs.primary),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ═══ Reaction breakdown chips ═══
            if (_reactionBreakdownEntries(post).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Builder(
                  builder: (context) {
                    final vibesList =
                        ref.watch(vibesProvider).valueOrNull ?? [];
                    final entries = _reactionBreakdownEntries(post);
                    return Row(
                      children: [
                        ...entries.take(5).map((entry) {
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
                                final actions = ref.read(
                                  postActionsProvider.notifier,
                                );
                                if (isMyReaction) {
                                  actions.removeReaction(
                                    post.id,
                                    matchedVibe.id,
                                  );
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
                                      ? Border.all(
                                          color: cs.primary,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: Text(
                                  '$emoji $count',
                                  style: tt.labelSmall?.copyWith(
                                    color: isMyReaction
                                        ? cs.onPrimaryContainer
                                        : null,
                                    fontWeight: isMyReaction
                                        ? FontWeight.w700
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),

            // ═══ Bottom row: vibe chips (left) + actions (right) ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              child: Row(
                children: [
                  // ── Vibe + sport chips ──
                  if (post.vibes.isNotEmpty ||
                      (post.sport != null && post.sport!.isNotEmpty))
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (post.sport != null && post.sport!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    post.sport!,
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ...post.vibes.take(3).map((vibe) {
                              final color = _parseHexColor(vibe.colorHex, cs);
                              final emoji = vibe.emoji ?? '';
                              final label = vibe.labelEn.isNotEmpty
                                  ? vibe.labelEn
                                  : vibe.key[0].toUpperCase() +
                                        vibe.key.substring(1);
                              final chipText = emoji.isNotEmpty
                                  ? '$emoji $label'
                                  : label;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    chipText,
                                    style: tt.labelSmall?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    )
                  else
                    const Spacer(),

                  // ── Actions ──
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (post.viewCount > 0) ...[
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(post.viewCount),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      if (post.commentCount > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(post.commentCount),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleLikeTap(hasLiked),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: hasLiked ? cs.error : cs.onSurfaceVariant,
                            ),
                            if (_localLikeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                _formatCount(_localLikeCount),
                                style: tt.bodySmall?.copyWith(
                                  color: hasLiked
                                      ? cs.error
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showReactionPicker(myReactions),
                        child: _buildReactIcon(myReactions, cs),
                      ),
                      if (post.allowReposts) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.repeat_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotSep(TextTheme tt, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        '·',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared helper widgets (extracted from home_screen.dart)
// ═══════════════════════════════════════════════════════════════════════════════

/// Circular author avatar with image / initials fallback.
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.avatarUrl,
    required this.label,
    required this.radius,
    required this.isAnonymous,
    required this.cs,
    required this.tt,
  });

  final String? avatarUrl;
  final String label;
  final double radius;
  final bool isAnonymous;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (isAnonymous) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.errorContainer,
        child: Icon(Icons.person_off, size: radius, color: cs.error),
      );
    }

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.primaryContainer,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                _Initials(label: label, radius: radius, cs: cs),
            errorWidget: (_, __, ___) =>
                _Initials(label: label, radius: radius, cs: cs),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: _Initials(label: label, radius: radius, cs: cs),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.label,
    required this.radius,
    required this.cs,
  });

  final String label;
  final double radius;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Text(
    label[0].toUpperCase(),
    style: TextStyle(
      fontSize: radius * 0.8,
      fontWeight: FontWeight.w600,
      color: cs.onPrimaryContainer,
    ),
  );
}

/// Small colored badge for metadata chips.
class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

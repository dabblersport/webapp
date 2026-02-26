import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/comment.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/reaction_picker_sheet.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

/// Displays a single post with its comments — matching the dark social-app
/// reference: rounded-avatar header, body card with vibe + reactions,
/// gift/heart action buttons, empty-state encouragement, fixed comment input.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSending = false;
  bool _hasText = false;
  RealtimeChannel? _realtimeChannel;

  /// Navigate to the author's profile.
  /// Own **active** profile → ProfileScreen; everyone else → UserProfileScreen.
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

  /// Navigate to a comment author's profile.
  Future<void> _navigateToCommentAuthorProfile(
    BuildContext ctx,
    PostComment comment,
  ) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final myProfileId = await ref.read(myProfileIdProvider.future);
    if (!ctx.mounted) return;
    if (comment.authorUserId == currentUserId &&
        comment.authorProfileId == myProfileId) {
      ctx.go(RoutePaths.profile);
    } else {
      ctx.push(
        '${RoutePaths.userProfile}/${comment.authorUserId}?profileId=${comment.authorProfileId}',
      );
    }
  }

  /// When non-null the user is replying to this comment.
  PostComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onTextChanged);
    // Fire-and-forget view recording.
    Future.microtask(() {
      ref.read(postActionsProvider.notifier).recordView(widget.postId);
    });
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final db = Supabase.instance.client;
    _realtimeChannel = db
        .channel('post_detail_${widget.postId}')
        // Post row updated (like_count, comment_count, reaction_breakdown)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.postId,
          ),
          callback: (_) {
            if (mounted) ref.invalidate(postDetailProvider(widget.postId));
          },
        )
        // New comment added
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.postId,
          ),
          callback: (_) {
            if (mounted) {
              ref.invalidate(postCommentsProvider(widget.postId));
              ref.invalidate(postDetailProvider(widget.postId));
            }
          },
        )
        // Comment deleted
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'post_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.postId,
          ),
          callback: (_) {
            if (mounted) {
              ref.invalidate(postCommentsProvider(widget.postId));
              ref.invalidate(postDetailProvider(widget.postId));
            }
          },
        )
        .subscribe();
  }

  void _onTextChanged() {
    final hasText = _commentController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _commentController.removeListener(_onTextChanged);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment(String postId) async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    await ref
        .read(postActionsProvider.notifier)
        .addComment(
          postId: postId,
          body: body,
          parentCommentId: _replyingTo?.id,
        );
    _commentController.clear();
    if (mounted) {
      setState(() {
        _isSending = false;
        _replyingTo = null;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return '${(diff.inDays / 30).floor()}mo';
  }

  /// Parse hex from DB (e.g. "#6AC47E") into Color.
  Color _parseHexColor(String? hex, ColorScheme cs) {
    if (hex == null || hex.isEmpty) return cs.primary;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return cs.primary;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return cs.primary;
    return Color(0xFF000000 | value);
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

  String _sportEmoji(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
      case 'soccer':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      case 'padel':
        return '🏓';
      case 'cricket':
        return '🏏';
      case 'volleyball':
        return '🏐';
      case 'swimming':
        return '🏊';
      case 'running':
        return '🏃';
      default:
        return '🏅';
    }
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

  void _showReactionPicker(String postId, Set<String> myReactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ReactionPickerSheet(postId: postId, myReactions: myReactions),
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

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: cs.error)),
        ),
        data: (post) => Column(
          children: [
            // ── Scrollable content ──
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Safe-area top spacing
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 8,
                    ),
                  ),

                  // ═══ Header: back + avatar + name/time + menu ═══
                  SliverToBoxAdapter(
                    child: _buildHeader(context, post, cs, tt),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ═══ Post body card ═══
                  SliverToBoxAdapter(
                    child: _buildPostCard(context, post, cs, tt),
                  ),

                  // ═══ Reaction breakdown chips ═══
                  SliverToBoxAdapter(
                    child: _buildReactionChips(context, post, cs, tt),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ═══ Action buttons (react + repost + heart) ═══
                  SliverToBoxAdapter(
                    child: _buildActionButtons(context, post, cs, tt),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // ═══ Comments section ═══
                  _buildCommentsSliver(context, commentsAsync, cs, tt),

                  // Bottom padding
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ),
                ],
              ),
            ),

            // ── Fixed comment input bar ──
            _buildCommentInput(context, post.id, cs, tt),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(
    BuildContext context,
    Post post,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final author = (post.authorDisplayName ?? '').trim();
    final authorLabel = author.isEmpty ? 'Anonymous' : author;
    final isAnonymous = author.isEmpty;
    final typeLabel = _postTypeLabel(post.postType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
          ),

          const SizedBox(width: 4),

          // Avatar — tappable, shows real profile image
          GestureDetector(
            onTap: isAnonymous
                ? null
                : () => _navigateToAuthorProfile(context, post),
            child: _buildAvatarTile(
              avatarUrl: resolveAvatarUrl(post.authorAvatarUrl),
              label: authorLabel,
              isAnonymous: isAnonymous,
              cs: cs,
              tt: tt,
            ),
          ),

          const SizedBox(width: 12),

          // Name + subtitle — also tappable
          Expanded(
            child: GestureDetector(
              onTap: isAnonymous
                  ? null
                  : () => _navigateToAuthorProfile(context, post),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + persona badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          authorLabel,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
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
                  // Subtitle: visibility · time · kind · type · edited
                  Row(
                    children: [
                      Icon(
                        _visibilityIcon(post.visibility),
                        size: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _relativeTime(post.createdAt),
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

          if (post.isPinned) Icon(Icons.push_pin, size: 16, color: cs.primary),

          // Three-dot menu
          IconButton(
            onPressed: () {
              // TODO: post actions menu
            },
            icon: Icon(Icons.more_horiz, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Rounded-square avatar tile with real image support and initials fallback.
  Widget _buildAvatarTile({
    required String? avatarUrl,
    required String label,
    required bool isAnonymous,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    const double size = 48;
    const double radius = 12;

    if (isAnonymous) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(child: Icon(Icons.person_off, size: 22, color: cs.error)),
      );
    }

    Widget child;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initials(label, cs, tt),
        errorWidget: (_, __, ___) => _initials(label, cs, tt),
      );
    } else {
      child = _initials(label, cs, tt);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _initials(String label, ColorScheme cs, TextTheme tt) => Center(
    child: Text(
      label[0].toUpperCase(),
      style: tt.titleMedium?.copyWith(
        color: cs.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // POST BODY CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPostCard(
    BuildContext context,
    Post post,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final originLabel = _originLabel(post.originType);
    final expiryText = _expiryLabel(post.expiresAt);
    final hasLocation = post.geoLat != null && post.geoLng != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Contextual metadata chips ──
            if (originLabel != null ||
                post.lang != null ||
                hasLocation ||
                post.requiresModeration ||
                expiryText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                        color: cs.surfaceContainerHighest,
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

            // ── Post text (full, no truncation) ──
            if (post.body != null && post.body!.trim().isNotEmpty)
              Text(
                post.body!,
                style: tt.bodyLarge?.copyWith(color: cs.onSurface, height: 1.5),
              ),

            // ── Image ──
            if (post.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMediaImage(post, cs),
              ),
            ],

            // ── Tags ──
            if (post.tags.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: post.tags.skip(1).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$tag',
                      style: tt.labelSmall?.copyWith(color: cs.primary),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 10),

            // ── Bottom row: vibe + sport chips (left) + counters (right) ──
            Row(
              children: [
                // Vibe + sport chips
                if (post.vibes.isNotEmpty ||
                    (post.sport != null && post.sport!.isNotEmpty))
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Sport chip
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
                                  '${_sportEmoji(post.sport!)} ${post.sport}',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          // Vibe chips
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

                // Counters grouped at the end
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
                      size: 16,
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
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    if (post.likeCount > 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        _formatCount(post.likeCount),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (post.allowReposts) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.repeat_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaImage(Post post, ColorScheme cs) {
    final first = post.media.first;
    String? url;
    if (first is Map) {
      url = (first['url'] ?? first['uri'] ?? first['src'])?.toString();
    } else if (first is String && first.startsWith('http')) {
      url = first;
    }
    if (url == null) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: cs.surfaceContainerHigh,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTION BUTTONS (React + Repost + Heart)
  // ═══════════════════════════════════════════════════════════════════════

  /// Resolve the first emoji the user reacted with, from their reaction IDs.
  String? _myFirstEmoji(Set<String> myReactions) {
    if (myReactions.isEmpty) return null;
    final vibesList = ref.watch(vibesProvider).valueOrNull ?? [];
    for (final vId in myReactions) {
      final match = vibesList.where((v) => v.id == vId).firstOrNull;
      if (match != null && match.emoji != null && match.emoji!.isNotEmpty) {
        return match.emoji;
      }
    }
    return null;
  }

  /// Reaction breakdown chips shown between the post card and action buttons.
  Widget _buildReactionChips(
    BuildContext context,
    Post post,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final vibesList = ref.watch(vibesProvider).valueOrNull ?? [];
    final myReactionsAsync = ref.watch(myReactionsProvider(post.id));
    final myReactions = myReactionsAsync.valueOrNull ?? <String>{};

    // breakdown is nested: {"total": N, "breakdown": {"vibe_key": count}}
    final rawBreakdown = post.reactionBreakdown['breakdown'];
    final breakdown = rawBreakdown is Map
        ? rawBreakdown.entries
              .where((e) => e.value is int && (e.value as int) > 0)
              .toList()
        : <MapEntry<dynamic, dynamic>>[];

    if (breakdown.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: breakdown.map((entry) {
          final vibeKey = entry.key.toString();
          final count = entry.value as int;
          final matchedVibe = vibesList
              .where((v) => v.key == vibeKey)
              .firstOrNull;
          final emoji = matchedVibe?.emoji ?? vibeKey;
          final isMyReaction =
              matchedVibe != null && myReactions.contains(matchedVibe.id);

          return GestureDetector(
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isMyReaction
                    ? cs.primaryContainer
                    : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: isMyReaction
                    ? Border.all(color: cs.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                '$emoji $count',
                style: tt.labelMedium?.copyWith(
                  color: isMyReaction ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: isMyReaction ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    Post post,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final hasLikedAsync = ref.watch(hasLikedProvider(post.id));
    final isLiked = hasLikedAsync.valueOrNull ?? false;
    final hasRepostedAsync = ref.watch(hasRepostedProvider(post.id));
    final isReposted = hasRepostedAsync.valueOrNull ?? false;
    final myReactionsAsync = ref.watch(myReactionsProvider(post.id));
    final myReactions = myReactionsAsync.valueOrNull ?? <String>{};
    final hasReacted = myReactions.isNotEmpty;
    final pickedEmoji = _myFirstEmoji(myReactions);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // React button — show picked emoji or fallback icon
        _EmojiActionButton(
          emoji: pickedEmoji,
          fallbackIcon: Icons.add_reaction_outlined,
          isActive: hasReacted,
          cs: cs,
          onTap: () => _showReactionPicker(post.id, myReactions),
        ),

        const SizedBox(width: 16),

        // Repost button
        if (post.allowReposts) ...[
          _ActionButton(
            icon: isReposted ? Icons.repeat_on_rounded : Icons.repeat_rounded,
            isActive: isReposted,
            cs: cs,
            onTap: () {
              if (!isReposted) {
                ref.read(postActionsProvider.notifier).repostPost(post.id);
              }
            },
          ),
          const SizedBox(width: 16),
        ],

        // Heart / like button
        _ActionButton(
          icon: isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          isActive: isLiked,
          cs: cs,
          onTap: () {
            if (isLiked) {
              ref.read(postActionsProvider.notifier).unlikePost(post.id);
            } else {
              ref.read(postActionsProvider.notifier).likePost(post.id);
            }
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COMMENTS SECTION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCommentsSliver(
    BuildContext context,
    AsyncValue<List<PostComment>> commentsAsync,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return commentsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Could not load comments',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyComments(cs, tt),
          );
        }

        // Group: top-level (parentCommentId == null) and their replies.
        final topLevel = <PostComment>[];
        final repliesByParent = <String, List<PostComment>>{};
        for (final c in comments) {
          if (c.parentCommentId == null) {
            topLevel.add(c);
          } else {
            repliesByParent.putIfAbsent(c.parentCommentId!, () => []).add(c);
          }
        }

        return SliverList.builder(
          itemCount: topLevel.length,
          itemBuilder: (context, index) {
            final parent = topLevel[index];
            final replies = repliesByParent[parent.id] ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Parent comment
                _buildCommentTile(parent, cs, tt, isReply: false),
                // Replies (indented)
                for (final reply in replies)
                  _buildCommentTile(reply, cs, tt, isReply: true),
                // Divider
                if (index < topLevel.length - 1)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyComments(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Show them some participation',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to comment!',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.back_hand_outlined,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(
    PostComment comment,
    ColorScheme cs,
    TextTheme tt, {
    required bool isReply,
  }) {
    final name = (comment.authorDisplayName ?? '').trim();
    final displayName = name.isEmpty ? 'Anonymous' : name;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    final avatarRadius = isReply ? 12.0 : 16.0;
    final leftPad = isReply ? 52.0 : 16.0; // indent replies under parent avatar

    return Padding(
      padding: EdgeInsets.only(left: leftPad, right: 16, top: 12, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment author avatar — tappable to navigate to profile
          GestureDetector(
            onTap: name.isEmpty
                ? null
                : () => _navigateToCommentAuthorProfile(context, comment),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: name.isEmpty
                  ? cs.errorContainer
                  : cs.primaryContainer,
              child: Text(
                initial,
                style: (isReply ? tt.labelSmall : tt.labelSmall)?.copyWith(
                  color: name.isEmpty ? cs.error : cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: isReply ? 10 : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(comment.createdAt),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                ),
                // Reply action — only on top-level comments
                if (!isReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _replyingTo = comment);
                        // Focus the input field
                        FocusScope.of(context).requestFocus(FocusNode());
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          FocusScope.of(context).requestFocus(FocusNode());
                        });
                      },
                      child: Text(
                        'Reply',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
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

  // ═══════════════════════════════════════════════════════════════════════
  // COMMENT INPUT BAR (fixed at bottom)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCommentInput(
    BuildContext context,
    String postId,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Replying to …" banner
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Replying to ${(_replyingTo!.authorDisplayName ?? 'Anonymous').trim()}',
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Text field
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? 'Write a reply...'
                          : 'Write a comment...',
                      hintStyle: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(postId),
                  ),
                ),

                // GIF button
                IconButton(
                  onPressed: () {
                    // TODO: GIF picker
                  },
                  icon: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.onSurfaceVariant, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GIF',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),

                // Emoji button
                IconButton(
                  onPressed: () {
                    // TODO: emoji/sticker picker
                  },
                  icon: Icon(
                    Icons.emoji_emotions_outlined,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                ),

                // Send button (visible when typing) / spinner when sending
                if (_isSending)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_hasText)
                  IconButton(
                    onPressed: () => _submitComment(postId),
                    icon: Icon(Icons.send_rounded, size: 22, color: cs.primary),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Avatar tile used in the post header ──────────────────────────────────
}

// ═════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON — rounded dark container with icon (gift / heart style)
// ═════════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.isActive,
    required this.cs,
    this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 26,
          color: isActive ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Action button that shows an emoji text instead of an icon when available.
class _EmojiActionButton extends StatelessWidget {
  const _EmojiActionButton({
    this.emoji,
    required this.fallbackIcon,
    required this.isActive,
    required this.cs,
    this.onTap,
  });

  final String? emoji;
  final IconData fallbackIcon;
  final bool isActive;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: cs.primary, width: 1.5) : null,
        ),
        child: Center(
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 26))
              : Icon(fallbackIcon, size: 26, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
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

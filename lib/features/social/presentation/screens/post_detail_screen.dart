import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/comment.dart';
import 'package:dabbler/data/models/place.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/reaction_picker_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/quote_repost_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/gif_picker_sheet.dart';
import 'package:dabbler/features/places/presentation/widgets/place_picker_sheet.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

/// Displays a single post with its comments in a Twitter / Threads–inspired
/// layout: flat content, full timestamp, engagement stats row, horizontal
/// action bar, and threaded replies.
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
  bool _isUploading = false;
  RealtimeChannel? _realtimeChannel;

  // ── Comment attachment state ──
  String? _attachedImageUrl;
  String? _attachedGifUrl;
  Place? _attachedPlace;

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
    final hasContent =
        _commentController.text.trim().isNotEmpty ||
        _attachedImageUrl != null ||
        _attachedGifUrl != null;
    if (hasContent != _hasText) setState(() => _hasText = hasContent);
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
    final hasAttachment = _attachedImageUrl != null || _attachedGifUrl != null;
    final includeLocation = body.isNotEmpty && _attachedPlace != null;
    if ((body.isEmpty && !hasAttachment) || _isSending) return;

    setState(() => _isSending = true);
    await ref
        .read(postActionsProvider.notifier)
        .addComment(
          postId: postId,
          body: body.isNotEmpty ? body : '',
          parentCommentId: _replyingTo?.id,
          imageUrl: _attachedImageUrl,
          gifUrl: _attachedGifUrl,
          locationName: includeLocation ? _attachedPlace!.name : null,
          locationLat: includeLocation ? _attachedPlace!.latitude : null,
          locationLng: includeLocation ? _attachedPlace!.longitude : null,
        );
    _commentController.clear();
    if (mounted) {
      setState(() {
        _isSending = false;
        _replyingTo = null;
        _attachedImageUrl = null;
        _attachedGifUrl = null;
        _attachedPlace = null;
        _hasText = false;
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

  /// Full date+time for the detail view (e.g. "3:42 PM · Mar 18, 2026").
  String _fullTimestamp(DateTime dt) {
    final time = DateFormat.jm().format(dt); // 3:42 PM
    final date = DateFormat.yMMMd().format(dt); // Mar 18, 2026
    return '$time · $date';
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
        return Iconsax.global_copy;
      case PostVisibility.followers:
        return Iconsax.people_copy;
      case PostVisibility.circle:
        return Iconsax.people_copy;
      case PostVisibility.squad:
        return Iconsax.profile_2user_copy;
      case PostVisibility.private:
        return Iconsax.lock_copy;
      case PostVisibility.link:
        return Iconsax.share_copy;
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

  int _reactionCount(Post post) {
    final rawBreakdown = post.reactionBreakdown['breakdown'];
    if (rawBreakdown is! Map) return 0;

    return rawBreakdown.values.whereType<int>().fold<int>(
      0,
      (sum, count) => sum + count,
    );
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
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) =>
          ReactionPickerSheet(postId: postId, myReactions: myReactions),
    );
  }

  void _showRepostMenu(Post post) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showAdaptiveSheet(
      context: context,
      isScrollControlled: false,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Iconsax.refresh_copy, color: cs.onSurface),
              title: Text('Repost', style: tt.bodyLarge),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(postActionsProvider.notifier).repostPost(post.id);
              },
            ),
            ListTile(
              leading: Icon(Iconsax.edit_2_copy, color: cs.onSurface),
              title: Text('Quote Repost', style: tt.bodyLarge),
              onTap: () {
                Navigator.of(ctx).pop();
                showAdaptiveSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  showDragHandle: false,
                  builder: (_) => QuoteRepostSheet(originalPost: post),
                );
              },
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

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_copy, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Post',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: cs.error)),
        ),
        data: (Post post) => Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ── Author row ──
                  SliverToBoxAdapter(
                    child: _buildAuthorRow(context, post, cs, tt),
                  ),

                  // ── Post body text ──
                  if (post.body != null && post.body!.trim().isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Text(
                          post.body!,
                          style: tt.titleMedium?.copyWith(
                            color: cs.onSurface,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                  // ── Media ──
                  if (post.media.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildMediaImage(post, cs),
                        ),
                      ),
                    ),

                  // ── Tags ──
                  if (post.tags.length > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: post.tags.skip(1).map((tag) {
                            return Text(
                              '#$tag',
                              style: tt.bodyMedium?.copyWith(color: cs.primary),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  // ── Vibes & sport chips ──
                  if (post.vibes.isNotEmpty ||
                      (post.sport != null && post.sport!.isNotEmpty))
                    SliverToBoxAdapter(child: _buildVibeChips(post, cs, tt)),

                  // ── Contextual metadata badges ──
                  SliverToBoxAdapter(child: _buildContextBadges(post, cs, tt)),

                  // ── Timestamp + view count row ──
                  SliverToBoxAdapter(child: _buildTimestampRow(post, cs, tt)),

                  // ── Engagement stats row ──
                  SliverToBoxAdapter(
                    child: _buildEngagementStats(post, cs, tt),
                  ),

                  // ── Action bar ──
                  SliverToBoxAdapter(
                    child: _buildActionBar(context, post, cs, tt),
                  ),

                  // ── Replies header ──
                  SliverToBoxAdapter(
                    child: commentsAsync.when(
                      data: (c) => c.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(
                                'Replies',
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),

                  // ── Comments / replies ──
                  _buildCommentsSliver(context, commentsAsync, cs, tt),

                  // Bottom safe-area pad
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ),
                ],
              ),
            ),
            _buildCommentInput(context, post.id, cs, tt),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUTHOR ROW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAuthorRow(
    BuildContext context,
    Post post,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final author = (post.authorDisplayName ?? '').trim();
    final authorLabel = author.isEmpty ? 'Anonymous' : author;
    final isAnonymous = author.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular avatar
          GestureDetector(
            onTap: isAnonymous
                ? null
                : () => _navigateToAuthorProfile(context, post),
            child: _buildCircleAvatar(
              url: post.authorAvatarUrl,
              label: authorLabel,
              isAnonymous: isAnonymous,
              radius: 22,
              cs: cs,
              tt: tt,
              sport: post.sport,
            ),
          ),
          const SizedBox(width: 12),

          // Name column
          Expanded(
            child: GestureDetector(
              onTap: isAnonymous
                  ? null
                  : () => _navigateToAuthorProfile(context, post),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display name + persona badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          authorLabel,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (post.personaTypeSnapshot != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: post.personaTypeSnapshot == 'organiser'
                                ? cs.tertiaryContainer
                                : cs.errorContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.personaTypeSnapshot == 'organiser'
                                ? '🎯 Org'
                                : '🎮 Player',
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
                    ],
                  ),
                  const SizedBox(height: 1),
                  // Subtitle: kind · type
                  Row(
                    children: [
                      Text(
                        _kindLabel(post.kind),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (_postTypeLabel(post.postType) != null) ...[
                        _dotSep(tt, cs),
                        Flexible(
                          child: Text(
                            _postTypeLabel(post.postType)!,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
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
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Iconsax.location_copy, size: 16, color: cs.primary),
            ),

          // More menu
          IconButton(
            onPressed: () {
              // TODO: post actions menu
            },
            icon: Icon(Iconsax.more_copy, color: cs.onSurfaceVariant, size: 20),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CIRCLE AVATAR (Twitter / Threads style)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCircleAvatar({
    required String? url,
    required String label,
    required bool isAnonymous,
    required double radius,
    required ColorScheme cs,
    required TextTheme tt,
    String? sport,
  }) {
    if (isAnonymous) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.errorContainer,
        child: Icon(Iconsax.slash_copy, size: radius, color: cs.error),
      );
    }

    final avatar = DSAvatar(
      size: AvatarSize.medium,
      customDimension: radius * 2,
      imageUrl: url,
      displayName: label,
      context: AvatarContext.social,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      hasBorder: false,
    );

    if (sport == null || sport.isEmpty) return avatar;

    // Sport emoji badge
    return SizedBox(
      width: radius * 2 + 6,
      height: radius * 2 + 6,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(alignment: Alignment.topLeft, child: avatar),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _sportEmoji(sport),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // VIBES & SPORT CHIPS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildVibeChips(Post post, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
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
            ...post.vibes.take(3).map((vibe) {
              final color = _parseHexColor(vibe.colorHex, cs);
              final emoji = vibe.emoji ?? '';
              final label = vibe.labelEn.isNotEmpty
                  ? vibe.labelEn
                  : vibe.key[0].toUpperCase() + vibe.key.substring(1);
              final chipText = emoji.isNotEmpty ? '$emoji $label' : label;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONTEXT BADGES (origin, lang, location, moderation, expiry)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildContextBadges(Post post, ColorScheme cs, TextTheme tt) {
    final originLabel = _originLabel(post.originType);
    final expiryText = _expiryLabel(post.expiresAt);
    final hasLocation = post.geoLat != null && post.geoLng != null;

    if (originLabel == null &&
        !hasLocation &&
        (post.lang == null || post.lang!.isEmpty) &&
        !post.requiresModeration &&
        expiryText == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TIMESTAMP + VIEW COUNT (Twitter-style)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTimestampRow(Post post, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _fullTimestamp(post.createdAt),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (post.isEdited) ...[
                _dotSep(tt, cs),
                Text(
                  'Edited',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              _dotSep(tt, cs),
              Icon(
                _visibilityIcon(post.visibility),
                size: 14,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
          if (post.viewCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_formatCount(post.viewCount)} Views',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ENGAGEMENT STATS ROW (Reposts · Likes · Comments)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEngagementStats(Post post, ColorScheme cs, TextTheme tt) {
    final reactionCount = _reactionCount(post);
    final reactionChips = _reactionChipWidgets(post, cs, tt);
    final hasAny =
        post.repostCount > 0 ||
        reactionCount > 0 ||
        post.likeCount > 0 ||
        post.commentCount > 0;

    if (!hasAny) return const SizedBox.shrink();

    final statItems = <Widget>[
      if (post.repostCount > 0)
        _buildEngagementStatItem(
          value: _formatCount(post.repostCount),
          label: post.repostCount == 1 ? 'Repost' : 'Reposts',
          cs: cs,
          tt: tt,
        ),
      if (reactionCount > 0)
        _buildEngagementStatItem(
          value: _formatCount(reactionCount),
          label: reactionCount == 1 ? 'Reaction' : 'Reactions',
          cs: cs,
          tt: tt,
        ),
      if (post.likeCount > 0)
        _buildEngagementStatItem(
          value: _formatCount(post.likeCount),
          label: post.likeCount == 1 ? 'Like' : 'Likes',
          cs: cs,
          tt: tt,
        ),
      if (post.commentCount > 0)
        _buildEngagementStatItem(
          value: _formatCount(post.commentCount),
          label: post.commentCount == 1 ? 'Reply' : 'Replies',
          cs: cs,
          tt: tt,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [...statItems, ...reactionChips],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildEngagementStatItem({
    required String value,
    required String label,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTION BAR (horizontal icons — Twitter style)
  // ═══════════════════════════════════════════════════════════════════════

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

  Widget _buildActionBar(
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
    final canRepost = post.allowReposts && post.originType != OriginType.repost;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Comment
                _PostActionIcon(
                  icon: Iconsax.message_copy,
                  onTap: () {
                    // Focus the comment input
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                  cs: cs,
                ),

                // Repost
                if (canRepost)
                  _PostActionIcon(
                    icon: isReposted ? Iconsax.refresh : Iconsax.refresh_copy,
                    isActive: isReposted,
                    activeColor: cs.tertiary,
                    onTap: () {
                      if (isReposted) {
                        ref
                            .read(postActionsProvider.notifier)
                            .undoRepost(post.id);
                        return;
                      }
                      _showRepostMenu(post);
                    },
                    cs: cs,
                  ),

                // Like / heart
                _PostActionIcon(
                  icon: isLiked ? Iconsax.heart : Iconsax.heart_copy,
                  isActive: isLiked,
                  activeColor: cs.error,
                  onTap: () {
                    if (isLiked) {
                      ref
                          .read(postActionsProvider.notifier)
                          .unlikePost(post.id);
                    } else {
                      ref.read(postActionsProvider.notifier).likePost(post.id);
                    }
                  },
                  cs: cs,
                ),

                // React — emoji or fallback icon
                GestureDetector(
                  onTap: () => _showReactionPicker(post.id, myReactions),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: hasReacted && pickedEmoji != null
                        ? Text(
                            pickedEmoji,
                            style: const TextStyle(fontSize: 20),
                          )
                        : Icon(
                            Iconsax.add_circle_copy,
                            size: 22,
                            color: cs.onSurfaceVariant,
                          ),
                  ),
                ),

                // Share
                _PostActionIcon(
                  icon: Iconsax.share_copy,
                  onTap: () {
                    // TODO: share
                  },
                  cs: cs,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REACTION CHIPS (below action bar)
  // ═══════════════════════════════════════════════════════════════════════

  List<Widget> _reactionChipWidgets(Post post, ColorScheme cs, TextTheme tt) {
    final vibesList = ref.watch(vibesProvider).valueOrNull ?? [];
    final myReactionsAsync = ref.watch(myReactionsProvider(post.id));
    final myReactions = myReactionsAsync.valueOrNull ?? <String>{};

    final rawBreakdown = post.reactionBreakdown['breakdown'];
    final breakdown = rawBreakdown is Map
        ? rawBreakdown.entries
              .where((e) => e.value is int && (e.value as int) > 0)
              .toList()
        : <MapEntry<dynamic, dynamic>>[];

    if (breakdown.isEmpty) return const <Widget>[];

    return breakdown.map((entry) {
      final vibeKey = entry.key.toString();
      final count = entry.value as int;
      final matchedVibe = vibesList.where((v) => v.key == vibeKey).firstOrNull;
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
            color: isMyReaction ? cs.primaryContainer : cs.surfaceContainerHigh,
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
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MEDIA IMAGE
  // ═══════════════════════════════════════════════════════════════════════

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
          child: Icon(Iconsax.gallery_slash_copy, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COMMENTS / REPLIES (threaded)
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
            final hasReplies = replies.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Parent comment with optional thread line
                _buildThreadedComment(
                  parent,
                  cs,
                  tt,
                  isReply: false,
                  hasReplies: hasReplies,
                ),
                // Replies
                for (int i = 0; i < replies.length; i++)
                  _buildThreadedComment(
                    replies[i],
                    cs,
                    tt,
                    isReply: true,
                    hasReplies: false,
                  ),
                // Separator between top-level threads
                if (index < topLevel.length - 1)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant.withValues(alpha: 0.15),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThreadedComment(
    PostComment comment,
    ColorScheme cs,
    TextTheme tt, {
    required bool isReply,
    required bool hasReplies,
  }) {
    final name = (comment.authorDisplayName ?? '').trim();
    final displayName = name.isEmpty ? 'Anonymous' : name;
    final isAnonymous = name.isEmpty;
    final avatarRadius = isReply ? 14.0 : 18.0;
    final leftPad = isReply ? 56.0 : 16.0;

    return IntrinsicHeight(
      child: Padding(
        padding: EdgeInsets.only(left: leftPad, right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + thread line
            SizedBox(
              width: avatarRadius * 2,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: isAnonymous
                        ? null
                        : () =>
                              _navigateToCommentAuthorProfile(context, comment),
                    child: DSAvatar(
                      size: AvatarSize.medium,
                      customDimension: avatarRadius * 2,
                      imageUrl: comment.authorAvatarUrl,
                      displayName: displayName,
                      context: AvatarContext.social,
                      backgroundColor: isAnonymous
                          ? cs.errorContainer
                          : cs.primaryContainer,
                      foregroundColor: isAnonymous
                          ? cs.error
                          : cs.onPrimaryContainer,
                      hasBorder: false,
                    ),
                  ),
                  // Thread connector line
                  if (hasReplies && !isReply)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 4),
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + time
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _relativeTime(comment.createdAt),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Body
                    if (comment.body.isNotEmpty)
                      Text(
                        comment.body,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                      ),
                    // Image attachment
                    if (comment.imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: Image.network(
                              comment.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                height: 100,
                                color: cs.surfaceContainerHighest,
                                child: Center(
                                  child: Icon(
                                    Iconsax.gallery_slash_copy,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // GIF attachment
                    if (comment.gifUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: Image.network(
                                  comment.gifUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: cs.surfaceContainerHighest,
                                    child: Center(
                                      child: Icon(
                                        Iconsax.gallery_slash_copy,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'GIF',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Location attachment
                    if (comment.locationName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.location_copy,
                              size: 14,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                comment.locationName!,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Mini action row
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Reply action
                        if (!isReply)
                          GestureDetector(
                            onTap: () {
                              setState(() => _replyingTo = comment);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Iconsax.message_copy,
                                  size: 16,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyComments(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.message_copy,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No replies yet',
              style: tt.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to reply!',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COMMENT INPUT (fixed at bottom)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _pickCommentImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    final result = await ref
        .read(postRepositoryProvider)
        .uploadCommentMedia(picked);
    if (mounted) {
      result.fold(
        (failure) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        (url) => setState(() {
          _attachedImageUrl = url;
          _attachedGifUrl = null; // only one visual attachment
          _isUploading = false;
          _hasText = true;
        }),
      );
    }
  }

  void _showGifPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => GifPickerSheet(
          scrollController: scrollController,
          onSelected: (gifUrl) {
            Navigator.pop(ctx);
            setState(() {
              _attachedGifUrl = gifUrl;
              _attachedImageUrl = null; // only one visual attachment
              _hasText = true;
            });
          },
        ),
      ),
    );
  }

  Future<void> _pickCommentLocation() async {
    final place = await PlacePickerSheet.show(context);
    if (place != null && mounted) {
      setState(() {
        _attachedPlace = place;
      });
    }
  }

  Widget _buildAttachmentPreview(ColorScheme cs, TextTheme tt) {
    final items = <Widget>[];

    // Image preview
    if (_attachedImageUrl != null) {
      items.add(
        _buildRemovableChip(
          cs: cs,
          tt: tt,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _attachedImageUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Iconsax.gallery_slash_copy,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          onRemove: () => setState(() {
            _attachedImageUrl = null;
            _onTextChanged();
          }),
        ),
      );
    }

    // GIF preview
    if (_attachedGifUrl != null) {
      items.add(
        _buildRemovableChip(
          cs: cs,
          tt: tt,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Image.network(
                  _attachedGifUrl!,
                  width: 80,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 60,
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      Iconsax.gallery_slash_copy,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          onRemove: () => setState(() {
            _attachedGifUrl = null;
            _onTextChanged();
          }),
        ),
      );
    }

    // Location chip
    if (_attachedPlace != null) {
      items.add(
        _buildRemovableChip(
          cs: cs,
          tt: tt,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.location_copy,
                  size: 14,
                  color: cs.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    _attachedPlace!.name,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          onRemove: () => setState(() => _attachedPlace = null),
        ),
      );
    }

    // Uploading indicator
    if (_isUploading) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: items),
      ),
    );
  }

  Widget _buildRemovableChip({
    required ColorScheme cs,
    required TextTheme tt,
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.close_circle_copy,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(
    BuildContext context,
    String postId,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final hasVisualAttachment =
        _attachedImageUrl != null || _attachedGifUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        8,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Replying to …" banner
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Row(
                children: [
                  Icon(
                    Iconsax.message_copy,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Replying to ${(_replyingTo!.authorDisplayName ?? 'Anonymous').trim()}',
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(color: cs.primary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Iconsax.close_circle_copy,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Attachment previews
          _buildAttachmentPreview(cs, tt),

          Row(
            children: [
              // Attachment buttons
              _CommentAttachButton(
                icon: Iconsax.gallery_copy,
                onTap: hasVisualAttachment || _isUploading
                    ? null
                    : () => _pickCommentImage(ImageSource.gallery),
                cs: cs,
              ),
              _CommentAttachButton(
                icon: Iconsax.gallery_copy,
                onTap: hasVisualAttachment || _isUploading
                    ? null
                    : _showGifPicker,
                cs: cs,
              ),
              _CommentAttachButton(
                icon: Iconsax.location_copy,
                onTap: _pickCommentLocation,
                cs: cs,
                isActive: _attachedPlace != null,
              ),
              const SizedBox(width: 4),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Post your reply…',
                      hintStyle: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(postId),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send
              if (_isSending)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: _hasText ? () => _submitComment(postId) : null,
                  icon: Icon(
                    Iconsax.send_2_copy,
                    color: _hasText ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// POST ACTION ICON (Twitter-style action bar button)
// ═════════════════════════════════════════════════════════════════════════════

class _PostActionIcon extends StatelessWidget {
  const _PostActionIcon({
    required this.icon,
    required this.onTap,
    required this.cs,
    this.isActive = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isActive;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? (activeColor ?? cs.primary) : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COMMENT ATTACHMENT BUTTON (small icon before the text field)
// ═════════════════════════════════════════════════════════════════════════════

class _CommentAttachButton extends StatelessWidget {
  const _CommentAttachButton({
    required this.icon,
    required this.onTap,
    required this.cs,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 22,
          color: isActive
              ? cs.primary
              : enabled
              ? cs.onSurfaceVariant
              : cs.onSurfaceVariant.withValues(alpha: 0.3),
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

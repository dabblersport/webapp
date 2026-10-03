import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/comment.dart';
import 'package:dabbler/data/models/place.dart';
import 'package:dabbler/features/home/presentation/widgets/home_feed_parts.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/home/presentation/widgets/home_reaction_sheet.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/post_media_carousel.dart';
import 'package:dabbler/features/social/presentation/widgets/quote_repost_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/gif_picker_sheet.dart';
import 'package:dabbler/features/venues/presentation/widgets/place_picker_sheet.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/social/utils/post_sport_label.dart';

/// Post detail (design rows P01-P03): the post as the design-system post row,
/// its replies as threaded rows, and the reply composer pinned at the bottom.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    @visibleForTesting this.debugAttachedImageUrl,
  });
  final String postId;

  /// Test-only: starts the composer with this image already attached.
  final String? debugAttachedImageUrl;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentFocusNode = FocusNode();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isSending = false;
  bool _hasText = false;
  bool _isUploading = false;

  PostComment? _replyingTo;
  String? _attachedImageUrl;
  String? _attachedGifUrl;
  Place? _attachedPlace;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _attachedImageUrl = widget.debugAttachedImageUrl;
    _hasText = _attachedImageUrl != null;
    _commentController.addListener(_onTextChanged);
    Future.microtask(
      () => ref.read(postActionsProvider.notifier).recordView(widget.postId),
    );
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final db = Supabase.instance.client;
    void refresh({bool comments = false}) {
      if (!mounted) return;
      if (comments) ref.invalidate(postCommentsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
    }

    PostgresChangeFilter eq(String column) => PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: column,
      value: widget.postId,
    );

    _realtimeChannel = db
        .channel('post_detail_${widget.postId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          filter: eq('id'),
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: eq('parent_activity_id'),
          callback: (_) => refresh(comments: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          filter: eq('parent_activity_id'),
          callback: (_) => refresh(comments: true),
        )
        .subscribe();
  }

  void _onTextChanged() {
    final has =
        _commentController.text.trim().isNotEmpty ||
        _attachedImageUrl != null ||
        _attachedGifUrl != null;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _commentController
      ..removeListener(_onTextChanged)
      ..dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toast(
    String message, {
    DabblerToastTone tone = DabblerToastTone.neutral,
  }) {
    DabblerToastProvider.maybeOf(
      context,
    )?.show(DabblerToastSpec(message: message, tone: tone));
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _openProfile({
    required String? authorUserId,
    required String? authorProfileId,
  }) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final myProfileId = await ref.read(myProfileIdProvider.future);
    if (!mounted) return;

    if (authorUserId == currentUserId && authorProfileId == myProfileId) {
      context.go(RoutePaths.profile);
    } else if (authorUserId != null) {
      context.push(
        '${RoutePaths.userProfile}/$authorUserId?profileId=$authorProfileId',
      );
    }
  }

  // ── Comment actions ─────────────────────────────────────────────────────────

  Future<void> _submitComment(String postId) async {
    final body = _commentController.text.trim();
    final hasAttachment = _attachedImageUrl != null || _attachedGifUrl != null;
    if ((body.isEmpty && !hasAttachment) || _isSending) return;

    setState(() => _isSending = true);

    final includeLocation = body.isNotEmpty && _attachedPlace != null;
    await ref
        .read(postActionsProvider.notifier)
        .addComment(
          postId: postId,
          body: body,
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

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    final result = await ref
        .read(postRepositoryProvider)
        .uploadCommentMedia(picked);
    if (!mounted) return;

    result.fold(
      (err) {
        setState(() => _isUploading = false);
        _toast('Upload failed: ${err.message}', tone: DabblerToastTone.error);
      },
      (url) => setState(() {
        _attachedImageUrl = url;
        _attachedGifUrl = null;
        _isUploading = false;
        _hasText = true;
      }),
    );
  }

  void _showGifPicker() {
    showGifPickerSheet(
      context,
      onSelected: (url) {
        setState(() {
          _attachedGifUrl = url;
          _attachedImageUrl = null;
          _hasText = true;
        });
      },
    );
  }

  Future<void> _pickLocation() async {
    final place = await PlacePickerSheet.show(context);
    if (place != null && mounted) setState(() => _attachedPlace = place);
  }

  void _copyLink(Post post) {
    Clipboard.setData(ClipboardData(text: post.id));
    _toast('Link copied');
  }

  /// A content-sized sheet holding a column of full-width buttons.
  void _showActionSheet(List<Widget> Function(BuildContext ctx) buttons) {
    showDabblerSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      builder: (ctx) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space2,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, b) in buttons(ctx).indexed) ...[
              if (i > 0) const SizedBox(height: DabblerSpacing.space3),
              b,
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetButton(
    BuildContext ctx,
    String label,
    String icon,
    VoidCallback action, {
    bool destructive = false,
  }) => DabblerButton(
    label: label,
    icon: icon,
    tone: destructive
        ? DabblerButtonTone.destructive
        : DabblerButtonTone.neutral,
    fullWidth: true,
    onPressed: () {
      Navigator.of(ctx).pop();
      action();
    },
  );

  void _showRepostMenu(Post post) {
    _showActionSheet(
      (ctx) => [
        _sheetButton(
          ctx,
          'Repost',
          'refresh',
          () => ref.read(postActionsProvider.notifier).repostPost(post.id),
        ),
        _sheetButton(
          ctx,
          'Quote Repost',
          'edit-2',
          () => showQuoteRepostSheet(context, post),
        ),
      ],
    );
  }

  void _showPostMenu(Post post, String? myProfileId) {
    final isOwner = myProfileId != null && post.authorProfileId == myProfileId;
    _showActionSheet(
      (ctx) => [
        _sheetButton(ctx, 'Copy link', 'copy', () => _copyLink(post)),
        if (isOwner)
          _sheetButton(
            ctx,
            'Delete post',
            'trash',
            () => _confirmDeletePost(post.id),
            destructive: true,
          )
        else ...[
          _sheetButton(
            ctx,
            'Report post',
            'flag',
            () => showReportDialog(
              context,
              targetType: ReportTargetType.post,
              targetId: post.id,
              targetUserId: post.authorUserId,
            ),
            destructive: true,
          ),
          _sheetButton(
            ctx,
            'Block user',
            'user-remove',
            () => _blockAuthor(post.authorUserId),
            destructive: true,
          ),
        ],
      ],
    );
  }

  Future<void> _blockAuthor(String targetUserId) async {
    final result = await ref
        .read(blockRepositoryProvider)
        .blockUser(targetUserId);
    if (!mounted) return;
    result.fold(
      (failure) => _toast('Failed to block user: ${failure.message}'),
      (_) {
        ref.invalidate(blockedUserIdsProvider);
        ref
            .read(feedNotifierProvider.notifier)
            .removePostsByAuthor(targetUserId);
        _toast('User blocked. Their content is now hidden.');
      },
    );
  }

  Future<void> _confirmDeletePost(String postId) async {
    final confirmed = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: 'Delete post?',
        description: 'This cannot be undone.',
        destructive: true,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: 'Delete',
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(postActionsProvider.notifier).deletePost(postId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showCommentMenu(PostComment comment, String? myProfileId) {
    final isOwner =
        myProfileId != null && comment.authorProfileId == myProfileId;
    _showActionSheet(
      (ctx) => [
        if (isOwner)
          _sheetButton(
            ctx,
            'Delete reply',
            'trash',
            () => ref
                .read(postActionsProvider.notifier)
                .deleteComment(commentId: comment.id, postId: comment.postId),
            destructive: true,
          )
        else
          _sheetButton(
            ctx,
            'Report',
            'flag',
            () => showReportDialog(
              context,
              targetType: ReportTargetType.comment,
              targetId: comment.id,
              targetUserId: comment.authorUserId,
            ),
          ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _fullTimestamp(DateTime dt) =>
      '${DateFormat.jm().format(dt)} · ${DateFormat.yMMMd().format(dt)}';

  String? _visibilityLabel(PostVisibility v) => switch (v) {
    PostVisibility.public => null,
    PostVisibility.followers => 'Followers',
    PostVisibility.circle => 'Circle',
    PostVisibility.squad => 'Squad',
    PostVisibility.private => 'Private',
    PostVisibility.link => 'Link only',
  };

  String _visibilityIcon(PostVisibility v) => switch (v) {
    PostVisibility.public => 'global',
    PostVisibility.followers || PostVisibility.circle => 'people',
    PostVisibility.squad => 'profile-2user',
    PostVisibility.private => 'lock',
    PostVisibility.link => 'share',
  };

  String? _expiryLabel(DateTime? exp) {
    if (exp == null) return null;
    final diff = exp.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return 'Expires in ${diff.inDays}d';
    if (diff.inHours > 0) return 'Expires in ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Expires in ${diff.inMinutes}m';
    return 'Expiring soon';
  }

  String _originLabel(OriginType o) => switch (o) {
    OriginType.game => 'Game',
    OriginType.achievement => 'Achievement',
    OriginType.venue => 'Venue',
    OriginType.admin => 'Admin',
    OriginType.system => 'System',
    _ => '',
  };

  TextStyle _type(DabblerTypeStyle step, Color color, {FontWeight? weight}) =>
      homeType(context, step, color, weight: weight);

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final myProfileId = ref.watch(myProfileIdProvider).valueOrNull;
    final post = postAsync.valueOrNull;

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Post',
        onBack: () => context.pop(),
        actions: [
          if (post != null)
            DabblerNavigationAction(
              icon: 'more',
              label: 'More options',
              onPressed: () => _showPostMenu(post, myProfileId),
            ),
        ],
      ),
      bottomBar: post == null ? null : _buildCommentBar(post.id),
      body: postAsync.when(
        loading: () => const Center(child: DabblerSpinner()),
        error: (e, _) => DabblerEmptyState.error(
          title: 'Could not load post',
          text: e.toString(),
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
        data: (post) => _buildScrollContent(post, myProfileId),
      ),
    );
  }

  Widget _buildScrollContent(Post post, String? myProfileId) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final isAuthor = myProfileId != null && post.authorProfileId == myProfileId;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space6,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.originType == OriginType.repost)
                  HomePostRow.resolve(post, detail: _postDetail(post))
                else
                  _buildPostRow(post, isAuthor),
                _buildDetails(post, isAuthor: isAuthor),
                const DabblerDivider(),
              ],
            ),
          ),
        ),
        _buildCommentsSection(commentsAsync, myProfileId),
        const SliverToBoxAdapter(
          child: SizedBox(height: DabblerSpacing.space6),
        ),
      ],
    );
  }

  /// The post itself, fed to [DabblerPostRow] the way `HomePostRow` feeds it,
  /// with detail-screen callbacks (no self-navigation, reply focuses the
  /// composer, share copies the link, more opens this screen's menu).
  Widget _buildPostRow(Post post, bool isAuthor) {
    final isLiked = ref.watch(hasLikedProvider(post.id)).valueOrNull ?? false;
    final isReposted =
        ref.watch(hasRepostedProvider(post.id)).valueOrNull ?? false;
    final myReactions =
        ref.watch(myReactionsProvider(post.id)).valueOrNull ?? <String>{};
    final myProfileId = ref.watch(myProfileIdProvider).valueOrNull;
    final canRepost = post.allowReposts && post.originType != OriginType.repost;
    final name = (post.authorDisplayName ?? '').trim();
    final label = name.isEmpty ? 'Anonymous' : name;
    final actions = ref.read(postActionsProvider.notifier);
    final hasMedia = PostMediaCarousel.imageUrls(post.media).isNotEmpty;

    return DabblerPostRow(
      name: label,
      seed: label,
      imageUrl: post.authorAvatarUrl,
      onAuthorTap: name.isEmpty
          ? null
          : () => _openProfile(
              authorUserId: post.authorUserId,
              authorProfileId: post.authorProfileId,
            ),
      roleLabel: post.personaTypeSnapshot == null
          ? null
          : (post.personaTypeSnapshot == 'organiser' ? 'Org' : 'Player'),
      kindBadge: post.isPinned
          ? const DabblerBadge(label: 'Pinned', tone: DabblerBadgeTone.primary)
          : null,
      media: hasMedia
          ? PostMediaCarousel(media: post.media, carouselHeight: 280)
          : null,
      onRepost: canRepost
          ? () =>
                isReposted ? actions.undoRepost(post.id) : _showRepostMenu(post)
          : null,
      reposts: post.repostCount,
      reposted: isReposted,
      reactions: _reactionSummary(post, myReactions),
      views: isAuthor ? post.viewCount : null,
      time: homeRelativeTime(post.createdAt),
      place: post.locationName ?? '',
      segments: <DabblerPostSegment>[
        if (post.body?.trim().isNotEmpty == true)
          DabblerPostSegment(post.body!),
        for (final tag in post.tags.skip(1))
          DabblerPostSegment(' #$tag', link: true),
      ],
      sportLabel: post.sport?.isNotEmpty == true
          ? resolvePostSportLabel(context, ref, post)
          : null,
      likes: post.likeCount,
      replies: post.commentCount,
      liked: isLiked,
      vibed: myReactions.isNotEmpty,
      divider: false,
      onLike: () =>
          isLiked ? actions.unlikePost(post.id) : actions.likePost(post.id),
      onVibe: () => showHomeReactionSheet(
        context,
        postId: post.id,
        myReactions: myReactions,
      ),
      onComment: () => _commentFocusNode.requestFocus(),
      onShare: () => _copyLink(post),
      onMore: () => _showPostMenu(post, myProfileId),
      detail: _postDetail(post),
    );
  }

  /// The full timestamp line under the post row, for a post or a repost.
  DabblerPostDetail _postDetail(Post post) => DabblerPostDetail(
    timestamp: _fullTimestamp(post.createdAt),
    editedLabel: post.isEdited ? 'Edited' : null,
    visibilityLabel: _visibilityLabel(post.visibility),
    visibilityIcon: _visibilityIcon(post.visibility),
  );

  /// Reaction-breakdown chips; tapping one toggles that vibe.
  Widget? _reactionSummary(Post post, Set<String> myReactions) {
    final raw = post.reactionBreakdown['breakdown'];
    if (raw is! Map) return null;
    final entries = raw.entries
        .where((e) => e.value is int && (e.value as int) > 0)
        .toList();
    if (entries.isEmpty) return null;
    final vibes = ref.watch(vibesProvider).valueOrNull ?? const [];
    return Wrap(
      spacing: DabblerSpacing.space2,
      runSpacing: DabblerSpacing.space1,
      children: [
        for (final entry in entries)
          Builder(
            builder: (_) {
              final key = entry.key.toString();
              final matched = vibes.where((v) => v.key == key).firstOrNull;
              final mine = matched != null && myReactions.contains(matched.id);
              final label = matched == null
                  ? key
                  : (matched.labelEn.isNotEmpty
                        ? matched.labelEn
                        : matched.key);
              return DabblerChip(
                label: '$label ${entry.value}',
                selected: mine,
                onTap: () {
                  if (matched == null) return;
                  final actions = ref.read(postActionsProvider.notifier);
                  mine
                      ? actions.removeReaction(post.id, matched.id)
                      : actions.reactToPost(post.id, matched.id);
                },
              );
            },
          ),
      ],
    );
  }

  /// Vibes and context badges under the post row; the post row (or the
  /// repost's, via `HomePostRow.resolve(detail:)`) carries the timestamp line.
  Widget _buildDetails(Post post, {required bool isAuthor}) {
    final colors = DabblerColors.of(context);
    final expiry = _expiryLabel(post.expiresAt);
    final visLabel = _visibilityLabel(post.visibility);
    final hasGeo = post.geoLat != null && post.geoLng != null;
    final origin =
        post.originType != OriginType.manual &&
            post.originType != OriginType.repost
        ? _originLabel(post.originType)
        : '';

    final badges = <Widget>[
      for (final vibe in post.vibes.take(5))
        DabblerChip(
          label: vibe.labelEn.isNotEmpty ? vibe.labelEn : vibe.key,
          vibe: DabblerVibe.fromKey(vibe.key),
        ),
      if (origin.isNotEmpty) DabblerBadge(label: origin),
      if (hasGeo)
        DabblerBadge(
          label: post.locationName ?? 'Location',
          icon: const DabblerIcon('location', size: 12),
        ),
      if (post.lang?.isNotEmpty == true)
        DabblerBadge(label: post.lang!.toUpperCase()),
      if (visLabel != null)
        DabblerBadge(
          label: visLabel,
          icon: DabblerIcon(_visibilityIcon(post.visibility), size: 12),
        ),
      if (post.requiresModeration)
        const DabblerBadge(
          label: 'Pending review',
          tone: DabblerBadgeTone.warning,
        ),
      if (expiry != null)
        DabblerBadge(label: expiry, tone: DabblerBadgeTone.warning),
    ];

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badges.isNotEmpty) ...[
            Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space2,
              children: badges,
            ),
            const SizedBox(height: DabblerSpacing.space3),
          ],
          if (isAuthor && post.viewCount > 0)
            Text(
              '${homeCompactCount(post.viewCount)} Views',
              style: _type(
                DabblerType.footnote,
                colors.textSecondary,
                weight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  // ── Comments section ─────────────────────────────────────────────────────────

  Widget _buildCommentsSection(
    AsyncValue<List<PostComment>> commentsAsync,
    String? myProfileId,
  ) {
    final colors = DabblerColors.of(context);
    return commentsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space10),
          child: Center(child: DabblerSpinner()),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: DabblerEmptyState(
          icon: 'danger',
          text: 'Could not load replies',
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: DabblerEmptyState(
                icon: 'message',
                title: 'No replies yet',
                text: 'Be the first to reply!',
              ),
            ),
          );
        }

        final topLevel = <PostComment>[];
        final children = <String, List<PostComment>>{};
        for (final c in comments) {
          if (c.parentCommentId == null) {
            topLevel.add(c);
          } else {
            children.putIfAbsent(c.parentCommentId!, () => []).add(c);
          }
        }

        Widget row(
          PostComment c, {
          required PostComment thread,
          bool reply = false,
        }) => _commentRow(
          c,
          reply: reply,
          onReply: () => setState(() {
            _replyingTo = thread;
            _commentFocusNode.requestFocus();
          }),
          onLongPress: () => _showCommentMenu(c, myProfileId),
        );

        return SliverPadding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space6,
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (topLevel.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: DabblerSpacing.space5,
                      bottom: DabblerSpacing.space1,
                    ),
                    child: Text(
                      'Replies',
                      style: _type(
                        DabblerType.headline,
                        colors.textPrimary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              SliverList.builder(
                itemCount: topLevel.length,
                itemBuilder: (context, i) {
                  final parent = topLevel[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      row(parent, thread: parent),
                      for (final r
                          in children[parent.id] ?? const <PostComment>[])
                        row(r, thread: parent, reply: true),
                      if (i != topLevel.length - 1) const DabblerDivider(),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// One reply, on [DabblerCommentRow]. Replies to a reply nest one level
  /// and carry no Reply action, as before.
  Widget _commentRow(
    PostComment c, {
    required bool reply,
    required VoidCallback onReply,
    required VoidCallback onLongPress,
  }) {
    final name = (c.authorDisplayName ?? '').trim();
    final displayName = name.isEmpty ? 'Anonymous' : name;
    final colors = DabblerColors.of(context);

    Widget media(String url, {bool gif = false}) => DabblerImage(
      url: url,
      aspectRatio: 16 / 9,
      radius: DabblerRadius.lgAll,
      overlay: gif ? const DabblerBadge(label: 'GIF') : null,
    );

    final attachments = <Widget>[
      if (c.imageUrl != null) media(c.imageUrl!),
      if (c.gifUrl != null) media(c.gifUrl!, gif: true),
      if (c.locationName != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DabblerIcon('location', size: 13, color: colors.brandPrimary),
            const SizedBox(width: DabblerSpacing.space1),
            Flexible(
              child: Text(
                c.locationName!,
                overflow: TextOverflow.ellipsis,
                style: _type(
                  DabblerType.caption1,
                  colors.brandPrimary,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
    ];

    return DabblerCommentRow(
      name: displayName,
      seed: displayName,
      imageUrl: c.authorAvatarUrl,
      time: homeRelativeTime(c.createdAt),
      body: c.body,
      depth: reply ? 1 : 0,
      showLike: false,
      divider: false,
      attachments: attachments.isEmpty ? null : attachments,
      onLongPress: onLongPress,
      onReply: reply ? null : onReply,
      onAuthorTap: name.isEmpty
          ? null
          : () => _openProfile(
              authorUserId: c.authorUserId,
              authorProfileId: c.authorProfileId,
            ),
    );
  }

  // ── Comment input bar ────────────────────────────────────────────────────────

  Widget _buildCommentBar(String postId) {
    final hasVisual = _attachedImageUrl != null || _attachedGifUrl != null;
    final canAttach = !hasVisual && !_isUploading;
    final replyName = (_replyingTo?.authorDisplayName ?? '').trim();
    final showAttachments = hasVisual || _attachedPlace != null || _isUploading;

    return DabblerReplyComposer(
      controller: _commentController,
      focusNode: _commentFocusNode,
      placeholder: _replyingTo != null ? 'Reply…' : 'Post your reply…',
      replyingTo: _replyingTo == null
          ? null
          : (replyName.isEmpty ? 'Anonymous' : replyName),
      onCancelReply: () => setState(() => _replyingTo = null),
      sending: _isSending,
      // Text or an attached image/GIF makes a reply sendable, as before.
      canSendEmpty: _hasText,
      sendLabel: 'Send reply',
      onSend: (_) => _submitComment(postId),
      attachActions: [
        DabblerReplyComposerAction(
          icon: 'gallery',
          label: 'Add image',
          onTap: canAttach ? () => _pickImage(ImageSource.gallery) : null,
        ),
        DabblerReplyComposerAction.text(
          label: 'GIF',
          onTap: canAttach ? _showGifPicker : null,
        ),
        DabblerReplyComposerAction(
          icon: 'location',
          label: 'Add location',
          onTap: _pickLocation,
          active: _attachedPlace != null,
        ),
      ],
      attachments: showAttachments ? _buildAttachmentRow() : null,
    );
  }

  Widget _buildAttachmentRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_isUploading)
            const SizedBox(
              width: 60,
              height: 60,
              child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
            ),
          if (_attachedImageUrl != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: DabblerSpacing.space2,
              ),
              child: DabblerAttachmentChip(
                thumbnail: DabblerImage(url: _attachedImageUrl),
                thumbnailSize: 60,
                borderRadius: DabblerRadius.mdAll,
                semanticLabel: 'Image',
                removeLabel: 'Remove image',
                onRemove: () => setState(() {
                  _attachedImageUrl = null;
                  _onTextChanged();
                }),
              ),
            ),
          if (_attachedGifUrl != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: DabblerSpacing.space2,
              ),
              child: DabblerAttachmentChip(
                thumbnail: DabblerImage(
                  url: _attachedGifUrl,
                  overlay: const DabblerBadge(label: 'GIF'),
                ),
                size: const Size(80, 60),
                borderRadius: DabblerRadius.mdAll,
                semanticLabel: 'GIF',
                removeLabel: 'Remove GIF',
                onRemove: () => setState(() {
                  _attachedGifUrl = null;
                  _onTextChanged();
                }),
              ),
            ),
          if (_attachedPlace != null)
            DabblerAttachmentChip(
              icon: 'location',
              label: _attachedPlace!.name,
              removeLabel: 'Remove location',
              onRemove: () => setState(() => _attachedPlace = null),
            ),
        ],
      ),
    );
  }
}

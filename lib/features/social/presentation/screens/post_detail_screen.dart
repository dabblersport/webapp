import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/comment.dart';
import 'package:dabbler/data/models/place.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/reaction_picker_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/quote_repost_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/gif_picker_sheet.dart';
import 'package:dabbler/features/venues/presentation/widgets/place_picker_sheet.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/social/utils/post_sport_label.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

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
    _commentController.addListener(_onTextChanged);
    Future.microtask(
      () => ref.read(postActionsProvider.notifier).recordView(widget.postId),
    );
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final db = Supabase.instance.client;
    _realtimeChannel = db
        .channel('post_detail_${widget.postId}')
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
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'parent_activity_id',
            value: widget.postId,
          ),
          callback: (_) {
            if (mounted) {
              ref.invalidate(postCommentsProvider(widget.postId));
              ref.invalidate(postDetailProvider(widget.postId));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'parent_activity_id',
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
    await ref.read(postActionsProvider.notifier).addComment(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${err.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, sc) => GifPickerSheet(
          scrollController: sc,
          onSelected: (url) {
            Navigator.pop(ctx);
            setState(() {
              _attachedGifUrl = url;
              _attachedImageUrl = null;
              _hasText = true;
            });
          },
        ),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final place = await PlacePickerSheet.show(context);
    if (place != null && mounted) setState(() => _attachedPlace = place);
  }

  void _showReactionPicker(String postId, Set<String> myReactions) {
    showAdaptiveSheet<void>(
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
    showAdaptiveSheet<void>(
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
                Navigator.pop(ctx);
                ref.read(postActionsProvider.notifier).repostPost(post.id);
              },
            ),
            ListTile(
              leading: Icon(Iconsax.edit_2_copy, color: cs.onSurface),
              title: Text('Quote Repost', style: tt.bodyLarge),
              onTap: () {
                Navigator.pop(ctx);
                showAdaptiveSheet<void>(
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

  void _showPostMenu(Post post, String? myProfileId) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOwner = myProfileId != null && post.authorProfileId == myProfileId;

    showAdaptiveSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Iconsax.copy_copy, color: cs.onSurface),
              title: Text('Copy link', style: tt.bodyLarge),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: post.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
            if (isOwner)
              ListTile(
                leading: Icon(Iconsax.trash_copy, color: cs.error),
                title: Text(
                  'Delete post',
                  style: tt.bodyLarge?.copyWith(color: cs.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeletePost(post.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(postActionsProvider.notifier).deletePost(postId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showCommentMenu(PostComment comment, String? myProfileId) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOwner =
        myProfileId != null && comment.authorProfileId == myProfileId;

    showAdaptiveSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              ListTile(
                leading: Icon(Iconsax.trash_copy, color: cs.error),
                title: Text(
                  'Delete reply',
                  style: tt.bodyLarge?.copyWith(color: cs.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(postActionsProvider.notifier)
                      .deleteComment(
                        commentId: comment.id,
                        postId: comment.postId,
                      );
                },
              )
            else
              ListTile(
                leading: Icon(Iconsax.flag_copy, color: cs.onSurface),
                title: Text('Report', style: tt.bodyLarge),
                onTap: () => Navigator.pop(ctx),
              ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return '${(diff.inDays / 30).floor()}mo';
  }

  String _fullTimestamp(DateTime dt) =>
      '${DateFormat.jm().format(dt)} · ${DateFormat.yMMMd().format(dt)}';

  String _formatCount(int n) {
    if (n >= 1_000_000) return '${(n / 1_000_000).toStringAsFixed(1)}M';
    if (n >= 1_000) return '${(n / 1_000).toStringAsFixed(1)}K';
    return '$n';
  }

  Color _hexColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return fallback;
    final val = int.tryParse(clean, radix: 16);
    return val == null ? fallback : Color(0xFF000000 | val);
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

  String? _visibilityLabel(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return null;
      case PostVisibility.followers:
        return 'Followers';
      case PostVisibility.circle:
        return 'Circle';
      case PostVisibility.squad:
        return 'Squad';
      case PostVisibility.private:
        return 'Private';
      case PostVisibility.link:
        return 'Link only';
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

  String? _expiryLabel(DateTime? exp) {
    if (exp == null) return null;
    final diff = exp.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return 'Expires in ${diff.inDays}d';
    if (diff.inHours > 0) return 'Expires in ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Expires in ${diff.inMinutes}m';
    return 'Expiring soon';
  }

  int _totalReactions(Post post) {
    final raw = post.reactionBreakdown['breakdown'];
    if (raw is! Map) return 0;
    return raw.values.whereType<int>().fold(0, (s, v) => s + v);
  }

  String? _myFirstReactionEmoji(Set<String> myReactions) {
    if (myReactions.isEmpty) return null;
    final vibes = ref.watch(vibesProvider).valueOrNull ?? [];
    for (final id in myReactions) {
      final v = vibes.where((v) => v.id == id).firstOrNull;
      if (v?.emoji?.isNotEmpty == true) return v!.emoji;
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final myProfileId = ref.watch(myProfileIdProvider).valueOrNull;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(cs, tt, postAsync.valueOrNull, myProfileId),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(e, cs, tt),
        data: (post) => Column(
          children: [
            Expanded(child: _buildScrollContent(post, cs, tt, myProfileId)),
            _buildCommentBar(post.id, cs, tt),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(
    ColorScheme cs,
    TextTheme tt,
    Post? post,
    String? myProfileId,
  ) {
    return AppBar(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left_copy, color: cs.onSurface),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Post',
        style: tt.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      centerTitle: false,
      actions: [
        if (post != null)
          IconButton(
            icon: Icon(Iconsax.more_copy, color: cs.onSurface, size: 20),
            onPressed: () => _showPostMenu(post, myProfileId),
          ),
      ],
    );
  }

  Widget _buildError(Object e, ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.warning_2_copy,
              size: 48,
              color: cs.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load post',
              style: tt.titleMedium?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              e.toString(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(postDetailProvider(widget.postId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollContent(
    Post post,
    ColorScheme cs,
    TextTheme tt,
    String? myProfileId,
  ) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final isAuthor =
        myProfileId != null && post.authorProfileId == myProfileId;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── Original post (if this is a repost) ──
        if (post.originType == OriginType.repost && post.originalPost != null)
          SliverToBoxAdapter(
            child: _buildRepostBanner(post.originalPost!, cs, tt),
          ),

        // ── Author + metadata ──
        SliverToBoxAdapter(child: _buildHeader(post, cs, tt, myProfileId)),

        // ── Post body ──
        if (post.body?.trim().isNotEmpty == true)
          SliverToBoxAdapter(child: _buildBody(post, cs, tt)),

        // ── Media ──
        if (post.media.isNotEmpty)
          SliverToBoxAdapter(child: _buildMedia(post, cs)),

        // ── Tags ──
        if (post.tags.length > 1)
          SliverToBoxAdapter(child: _buildTags(post, cs, tt)),

        // ── Vibes + sport ──
        if (post.vibes.isNotEmpty ||
            (post.sport?.isNotEmpty == true))
          SliverToBoxAdapter(child: _buildVibeChips(post, cs, tt)),

        // ── Context badges ──
        SliverToBoxAdapter(child: _buildContextBadges(post, cs, tt)),

        // ── Timestamp row ──
        SliverToBoxAdapter(
          child: _buildTimestampRow(post, cs, tt, isAuthor: isAuthor),
        ),

        // ── Engagement stats ──
        SliverToBoxAdapter(child: _buildEngagementRow(post, cs, tt)),

        // ── Action bar ──
        SliverToBoxAdapter(child: _buildActionBar(post, cs, tt)),

        // ── Divider ──
        SliverToBoxAdapter(
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.15),
          ),
        ),

        // ── Comments ──
        _buildCommentsSection(commentsAsync, myProfileId, cs, tt),

        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ),
      ],
    );
  }

  // ── Repost banner ───────────────────────────────────────────────────────────

  Widget _buildRepostBanner(Post original, ColorScheme cs, TextTheme tt) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.refresh_copy, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Reposted from ${original.authorDisplayName ?? 'Unknown'}',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (original.body?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              original.body!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ],
        ],
      ),
    );
  }

  // ── Header (author row + persona) ───────────────────────────────────────────

  Widget _buildHeader(
    Post post,
    ColorScheme cs,
    TextTheme tt,
    String? myProfileId,
  ) {
    final name = (post.authorDisplayName ?? '').trim();
    final label = name.isEmpty ? 'Anonymous' : name;
    final isAnon = name.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: isAnon
                ? null
                : () => _openProfile(
                      authorUserId: post.authorUserId,
                      authorProfileId: post.authorProfileId,
                    ),
            child: _avatar(
              url: post.authorAvatarUrl,
              label: label,
              isAnon: isAnon,
              radius: 22,
              sport: post.sport,
              cs: cs,
              tt: tt,
            ),
          ),
          const SizedBox(width: 12),

          // Name + subtitle
          Expanded(
            child: GestureDetector(
              onTap: isAnon
                  ? null
                  : () => _openProfile(
                        authorUserId: post.authorUserId,
                        authorProfileId: post.authorProfileId,
                      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (post.personaTypeSnapshot != null) ...[
                        const SizedBox(width: 6),
                        _PersonaBadge(
                          type: post.personaTypeSnapshot!,
                          cs: cs,
                          tt: tt,
                        ),
                      ],
                      if (post.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Iconsax.location_copy,
                          size: 14,
                          color: cs.primary,
                        ),
                      ],
                    ],
                  ),
                  if (post.authorUsername?.isNotEmpty == true)
                    Text(
                      '@${post.authorUsername}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Post body ───────────────────────────────────────────────────────────────

  Widget _buildBody(Post post, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        post.body!,
        style: tt.bodyLarge?.copyWith(
          color: cs.onSurface,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // ── Media ───────────────────────────────────────────────────────────────────

  Widget _buildMedia(Post post, ColorScheme cs) {
    final first = post.media.first;
    String? url;
    if (first is Map) {
      url = (first['url'] ?? first['uri'] ?? first['src'])?.toString();
    } else if (first is String && first.startsWith('http')) {
      url = first;
    }
    if (url == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: cs.surfaceContainerHighest,
              child: Icon(
                Iconsax.gallery_slash_copy,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tags ────────────────────────────────────────────────────────────────────

  Widget _buildTags(Post post, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: post.tags.skip(1).map((tag) {
          return GestureDetector(
            onTap: () {},
            child: Text(
              '#$tag',
              style: tt.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Vibes + sport chips ─────────────────────────────────────────────────────

  Widget _buildVibeChips(Post post, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (post.sport?.isNotEmpty == true)
              _Chip(
                label: '${_sportEmoji(post.sport!)} ${resolvePostSportLabel(context, ref, post)}',
                bgColor: cs.secondaryContainer,
                textColor: cs.onSecondaryContainer,
                tt: tt,
              ),
            ...post.vibes.take(5).map((vibe) {
              final color = _hexColor(vibe.colorHex, cs.primary);
              final emoji = vibe.emoji ?? '';
              final name =
                  vibe.labelEn.isNotEmpty
                      ? vibe.labelEn
                      : vibe.key[0].toUpperCase() + vibe.key.substring(1);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _Chip(
                  label: emoji.isNotEmpty ? '$emoji $name' : name,
                  bgColor: color.withValues(alpha: 0.15),
                  textColor: color,
                  tt: tt,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Context badges ──────────────────────────────────────────────────────────

  Widget _buildContextBadges(Post post, ColorScheme cs, TextTheme tt) {
    final expiry = _expiryLabel(post.expiresAt);
    final hasGeo = post.geoLat != null && post.geoLng != null;
    final visLabel = _visibilityLabel(post.visibility);

    final badges = <Widget>[
      if (post.originType != OriginType.manual &&
          post.originType != OriginType.repost)
        _MetaBadge(
          label: '🔗 ${_originLabel(post.originType)}',
          bg: cs.secondaryContainer,
          fg: cs.onSecondaryContainer,
          tt: tt,
        ),
      if (hasGeo)
        _MetaBadge(
          label: '📍 ${post.locationName ?? 'Location'}',
          bg: cs.secondaryContainer,
          fg: cs.onSecondaryContainer,
          tt: tt,
        ),
      if (post.lang?.isNotEmpty == true)
        _MetaBadge(
          label: '🌐 ${post.lang!.toUpperCase()}',
          bg: cs.surfaceContainerHighest,
          fg: cs.onSurfaceVariant,
          tt: tt,
        ),
      if (visLabel != null)
        _MetaBadge(
          label: visLabel,
          bg: cs.surfaceContainerHighest,
          fg: cs.onSurfaceVariant,
          tt: tt,
          icon: _visibilityIcon(post.visibility),
        ),
      if (post.requiresModeration)
        _MetaBadge(
          label: 'Pending review',
          bg: cs.errorContainer,
          fg: cs.onErrorContainer,
          tt: tt,
          icon: Iconsax.clock_copy,
        ),
      if (expiry != null)
        _MetaBadge(
          label: expiry,
          bg: cs.errorContainer,
          fg: cs.onErrorContainer,
          tt: tt,
        ),
    ];

    if (badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(spacing: 6, runSpacing: 4, children: badges),
    );
  }

  String _originLabel(OriginType o) {
    switch (o) {
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
      default:
        return '';
    }
  }

  // ── Timestamp row ───────────────────────────────────────────────────────────

  Widget _buildTimestampRow(
    Post post,
    ColorScheme cs,
    TextTheme tt, {
    required bool isAuthor,
  }) {
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
                _dot(cs, tt),
                Text(
                  'Edited',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              _dot(cs, tt),
              Icon(
                _visibilityIcon(post.visibility),
                size: 14,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
          if (isAuthor && post.viewCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${_formatCount(post.viewCount)} Views',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  // ── Engagement row ──────────────────────────────────────────────────────────

  Widget _buildEngagementRow(Post post, ColorScheme cs, TextTheme tt) {
    final totalReactions = _totalReactions(post);
    final vibes = ref.watch(vibesProvider).valueOrNull ?? [];
    final myReactions = ref.watch(myReactionsProvider(post.id)).valueOrNull ?? {};

    final stats = <_StatItem>[
      if (post.repostCount > 0)
        _StatItem(_formatCount(post.repostCount), 'Repost${post.repostCount == 1 ? '' : 's'}'),
      if (totalReactions > 0)
        _StatItem(_formatCount(totalReactions), 'Reaction${totalReactions == 1 ? '' : 's'}'),
      if (post.likeCount > 0)
        _StatItem(_formatCount(post.likeCount), 'Like${post.likeCount == 1 ? '' : 's'}'),
      if (post.commentCount > 0)
        _StatItem(_formatCount(post.commentCount), post.commentCount == 1 ? 'Reply' : 'Replies'),
    ];

    // Reaction breakdown chips
    final rawBreakdown = post.reactionBreakdown['breakdown'];
    final breakdown =
        rawBreakdown is Map
            ? rawBreakdown.entries
                  .where((e) => e.value is int && (e.value as int) > 0)
                  .toList()
            : <MapEntry<dynamic, dynamic>>[];

    if (stats.isEmpty && breakdown.isEmpty) return const SizedBox.shrink();

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
              children: [
                ...stats.map(
                  (s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.value,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        s.label,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ...breakdown.map((entry) {
                  final key = entry.key.toString();
                  final count = entry.value as int;
                  final matched =
                      vibes.where((v) => v.key == key).firstOrNull;
                  final emoji = matched?.emoji ?? key;
                  final isMe =
                      matched != null && myReactions.contains(matched.id);
                  return GestureDetector(
                    onTap: () {
                      if (matched == null) return;
                      final actions = ref.read(postActionsProvider.notifier);
                      isMe
                          ? actions.removeReaction(post.id, matched.id)
                          : actions.reactToPost(post.id, matched.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? cs.primaryContainer
                            : cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: isMe
                            ? Border.all(color: cs.primary, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        '$emoji $count',
                        style: tt.labelMedium?.copyWith(
                          color: isMe ? cs.onPrimaryContainer : cs.onSurface,
                          fontWeight:
                              isMe ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  // ── Action bar ──────────────────────────────────────────────────────────────

  Widget _buildActionBar(Post post, ColorScheme cs, TextTheme tt) {
    final isLiked = ref.watch(hasLikedProvider(post.id)).valueOrNull ?? false;
    final isReposted =
        ref.watch(hasRepostedProvider(post.id)).valueOrNull ?? false;
    final myReactions =
        ref.watch(myReactionsProvider(post.id)).valueOrNull ?? {};
    final hasReacted = myReactions.isNotEmpty;
    final pickedEmoji = _myFirstReactionEmoji(myReactions);
    final canRepost = post.allowReposts && post.originType != OriginType.repost;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Comment
          _ActionButton(
            icon: Iconsax.message_copy,
            onTap: () => _commentFocusNode.requestFocus(),
            cs: cs,
          ),

          // Repost
          if (canRepost)
            _ActionButton(
              icon: isReposted ? Iconsax.refresh : Iconsax.refresh_copy,
              isActive: isReposted,
              activeColor: cs.tertiary,
              onTap: () => isReposted
                  ? ref.read(postActionsProvider.notifier).undoRepost(post.id)
                  : _showRepostMenu(post),
              cs: cs,
            ),

          // Like
          _ActionButton(
            icon: isLiked ? Iconsax.heart : Iconsax.heart_copy,
            isActive: isLiked,
            activeColor: cs.error,
            onTap: () => isLiked
                ? ref.read(postActionsProvider.notifier).unlikePost(post.id)
                : ref.read(postActionsProvider.notifier).likePost(post.id),
            cs: cs,
          ),

          // React
          GestureDetector(
            onTap: () => _showReactionPicker(post.id, myReactions),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: hasReacted && pickedEmoji != null
                  ? Text(pickedEmoji, style: const TextStyle(fontSize: 20))
                  : Icon(
                      Iconsax.add_circle_copy,
                      size: 22,
                      color: cs.onSurfaceVariant,
                    ),
            ),
          ),

          // Share
          _ActionButton(
            icon: Iconsax.share_copy,
            onTap: () {
              Clipboard.setData(ClipboardData(text: post.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied')),
              );
            },
            cs: cs,
          ),
        ],
      ),
    );
  }

  // ── Comments section ─────────────────────────────────────────────────────────

  Widget _buildCommentsSection(
    AsyncValue<List<PostComment>> commentsAsync,
    String? myProfileId,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return commentsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Could not load replies',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyReplies(cs, tt),
          );
        }

        // Build parent → children map
        final topLevel = <PostComment>[];
        final children = <String, List<PostComment>>{};
        for (final c in comments) {
          if (c.parentCommentId == null) {
            topLevel.add(c);
          } else {
            children.putIfAbsent(c.parentCommentId!, () => []).add(c);
          }
        }

        // Replies header
        return SliverMainAxisGroup(
          slivers: [
            if (topLevel.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Replies',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            SliverList.builder(
              itemCount: topLevel.length,
              itemBuilder: (context, i) {
                final parent = topLevel[i];
                final replies = children[parent.id] ?? [];
                return _CommentThread(
                  parent: parent,
                  replies: replies,
                  myProfileId: myProfileId,
                  isLastThread: i == topLevel.length - 1,
                  onReply: (c) => setState(() {
                    _replyingTo = c;
                    _commentFocusNode.requestFocus();
                  }),
                  onLongPress: (c) => _showCommentMenu(c, myProfileId),
                  onAvatarTap: (c) => _openProfile(
                    authorUserId: c.authorUserId,
                    authorProfileId: c.authorProfileId,
                  ),
                  timeAgo: _timeAgo,
                  cs: cs,
                  tt: tt,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyReplies(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.message_copy,
              size: 52,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'No replies yet',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

  // ── Comment input bar ────────────────────────────────────────────────────────

  Widget _buildCommentBar(String postId, ColorScheme cs, TextTheme tt) {
    final hasVisual = _attachedImageUrl != null || _attachedGifUrl != null;

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
          // Replying-to banner
          if (_replyingTo != null)
            _ReplyBanner(
              name:
                  (_replyingTo!.authorDisplayName ?? 'Anonymous').trim().isEmpty
                      ? 'Anonymous'
                      : _replyingTo!.authorDisplayName!.trim(),
              onDismiss: () => setState(() => _replyingTo = null),
              cs: cs,
              tt: tt,
            ),

          // Attachment previews
          if (_attachedImageUrl != null ||
              _attachedGifUrl != null ||
              _attachedPlace != null ||
              _isUploading)
            _buildAttachmentRow(cs, tt),

          Row(
            children: [
              // Image
              _AttachButton(
                icon: Iconsax.gallery_copy,
                enabled: !hasVisual && !_isUploading,
                onTap: () => _pickImage(ImageSource.gallery),
                cs: cs,
              ),
              // GIF
              _AttachButton(
                icon: Iconsax.video_square_copy,
                enabled: !hasVisual && !_isUploading,
                onTap: _showGifPicker,
                cs: cs,
                label: 'GIF',
              ),
              // Location
              _AttachButton(
                icon: Iconsax.location_copy,
                enabled: true,
                isActive: _attachedPlace != null,
                onTap: _pickLocation,
                cs: cs,
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
                    focusNode: _commentFocusNode,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? 'Reply…'
                          : 'Post your reply…',
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
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send / loading
              _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
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

  Widget _buildAttachmentRow(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_isUploading)
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (_attachedImageUrl != null)
              _RemovableAttachment(
                onRemove: () {
                  setState(() {
                    _attachedImageUrl = null;
                    _onTextChanged();
                  });
                },
                cs: cs,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _attachedImageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (_attachedGifUrl != null)
              _RemovableAttachment(
                onRemove: () {
                  setState(() {
                    _attachedGifUrl = null;
                    _onTextChanged();
                  });
                },
                cs: cs,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.network(
                        _attachedGifUrl!,
                        width: 80,
                        height: 60,
                        fit: BoxFit.cover,
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
              ),
            if (_attachedPlace != null)
              _RemovableAttachment(
                onRemove: () => setState(() => _attachedPlace = null),
                cs: cs,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
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
                        constraints: const BoxConstraints(maxWidth: 120),
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
              ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Widget _dot(ColorScheme cs, TextTheme tt) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Text(
      '·',
      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    ),
  );

  Widget _avatar({
    required String? url,
    required String label,
    required bool isAnon,
    required double radius,
    required String? sport,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    if (isAnon) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: cs.errorContainer,
        child: Icon(Iconsax.slash_copy, size: radius, color: cs.error),
      );
    }

    final av = DSAvatar(
      size: AvatarSize.medium,
      customDimension: radius * 2,
      imageUrl: url,
      displayName: label,
      context: AvatarContext.social,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      hasBorder: false,
    );

    if (sport == null || sport.isEmpty) return av;

    return SizedBox(
      width: radius * 2 + 6,
      height: radius * 2 + 6,
      child: Stack(
        children: [
          Positioned.fill(child: Align(alignment: Alignment.topLeft, child: av)),
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
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thread widget ─────────────────────────────────────────────────────────────

class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.parent,
    required this.replies,
    required this.myProfileId,
    required this.isLastThread,
    required this.onReply,
    required this.onLongPress,
    required this.onAvatarTap,
    required this.timeAgo,
    required this.cs,
    required this.tt,
  });

  final PostComment parent;
  final List<PostComment> replies;
  final String? myProfileId;
  final bool isLastThread;
  final ValueChanged<PostComment> onReply;
  final ValueChanged<PostComment> onLongPress;
  final ValueChanged<PostComment> onAvatarTap;
  final String Function(DateTime) timeAgo;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(
          comment: parent,
          isReply: false,
          hasReplies: replies.isNotEmpty,
          onReply: () => onReply(parent),
          onLongPress: () => onLongPress(parent),
          onAvatarTap: () => onAvatarTap(parent),
          timeAgo: timeAgo,
          cs: cs,
          tt: tt,
        ),
        for (final reply in replies)
          _CommentRow(
            comment: reply,
            isReply: true,
            hasReplies: false,
            onReply: () => onReply(parent), // reply to the parent thread
            onLongPress: () => onLongPress(reply),
            onAvatarTap: () => onAvatarTap(reply),
            timeAgo: timeAgo,
            cs: cs,
            tt: tt,
          ),
        if (!isLastThread)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: cs.outlineVariant.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}

// ── Single comment row ────────────────────────────────────────────────────────

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.isReply,
    required this.hasReplies,
    required this.onReply,
    required this.onLongPress,
    required this.onAvatarTap,
    required this.timeAgo,
    required this.cs,
    required this.tt,
  });

  final PostComment comment;
  final bool isReply;
  final bool hasReplies;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final VoidCallback onAvatarTap;
  final String Function(DateTime) timeAgo;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final name = (comment.authorDisplayName ?? '').trim();
    final displayName = name.isEmpty ? 'Anonymous' : name;
    final isAnon = name.isEmpty;
    final avatarRadius = isReply ? 14.0 : 18.0;
    final leftPad = isReply ? 52.0 : 16.0;

    return GestureDetector(
      onLongPress: onLongPress,
      child: IntrinsicHeight(
        child: Padding(
          padding: EdgeInsets.only(left: leftPad, right: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar column with optional thread line
              SizedBox(
                width: avatarRadius * 2,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: isAnon ? null : onAvatarTap,
                      child: DSAvatar(
                        size: AvatarSize.medium,
                        customDimension: avatarRadius * 2,
                        imageUrl: comment.authorAvatarUrl,
                        displayName: displayName,
                        context: AvatarContext.social,
                        backgroundColor: isAnon
                            ? cs.errorContainer
                            : cs.primaryContainer,
                        foregroundColor: isAnon
                            ? cs.error
                            : cs.onPrimaryContainer,
                        hasBorder: false,
                      ),
                    ),
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
                      // Name + timestamp
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
                            timeAgo(comment.createdAt),
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
                                  height: 80,
                                  color: cs.surfaceContainerHighest,
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
                                      height: 80,
                                      color: cs.surfaceContainerHighest,
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

                      // Location
                      if (comment.locationName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.location_copy,
                                size: 13,
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

                      // Actions row
                      const SizedBox(height: 8),
                      if (!isReply)
                        GestureDetector(
                          onTap: onReply,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.message_copy,
                                size: 15,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.cs,
    this.isActive = false,
    this.label,
  });

  final IconData icon;
  final bool enabled;
  final bool isActive;
  final VoidCallback onTap;
  final ColorScheme cs;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? cs.primary
        : enabled
        ? cs.onSurfaceVariant
        : cs.onSurfaceVariant.withValues(alpha: 0.3);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: label != null
            ? Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              )
            : Icon(icon, size: 22, color: color),
      ),
    );
  }
}

class _RemovableAttachment extends StatelessWidget {
  const _RemovableAttachment({
    required this.child,
    required this.onRemove,
    required this.cs,
  });

  final Widget child;
  final VoidCallback onRemove;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
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
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({
    required this.name,
    required this.onDismiss,
    required this.cs,
    required this.tt,
  });

  final String name;
  final VoidCallback onDismiss;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        children: [
          Icon(Iconsax.message_copy, size: 13, color: cs.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Replying to $name',
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: cs.primary),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Iconsax.close_circle_copy,
                size: 15,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaBadge extends StatelessWidget {
  const _PersonaBadge({
    required this.type,
    required this.cs,
    required this.tt,
  });

  final String type;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final isOrg = type == 'organiser';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOrg ? cs.tertiaryContainer : cs.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOrg ? '🎯 Org' : '🎮 Player',
        style: tt.labelSmall?.copyWith(
          color: isOrg ? cs.onTertiaryContainer : cs.onErrorContainer,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.tt,
  });

  final String? label;
  final Color bgColor;
  final Color textColor;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (label == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label!,
        style: tt.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.label,
    required this.bg,
    required this.fg,
    required this.tt,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final TextTheme tt;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem(this.value, this.label);
  final String value;
  final String label;
}

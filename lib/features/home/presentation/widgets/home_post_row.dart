import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/location/presentation/widgets/post_location_chip.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/post_media_carousel.dart';
import 'package:dabbler/features/social/presentation/widgets/quote_repost_sheet.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'home_feed_parts.dart';
import 'home_reaction_sheet.dart';

/// Home's post row — the design's feed row, built from design-system parts.
///
/// Same data and callbacks as the shared `FeedPostCard`: tapping the row opens
/// post detail, the avatar and name open the author, like is optimistic, the
/// "+" opens the vibe picker, repost / quote-repost / undo, and the report and
/// block controls (App Review guideline 1.2) are all kept.
///
/// Reposts and the allocated kinds render through [HomePostRow.resolve].
class HomePostRow extends ConsumerStatefulWidget {
  const HomePostRow({
    super.key,
    required this.post,
    this.isEmbedded = false,
    this.showNearbyChipInHeader = false,
  });

  final Post post;
  final bool isEmbedded;
  final bool showNearbyChipInHeader;

  /// The row for [post]: a repost shows its quote and the embedded original, an
  /// allocated kind shows its kind badge, everything else is the plain row.
  static Widget resolve(Post post, {bool showNearbyChipInHeader = false}) {
    if (post.originType == OriginType.repost) {
      return HomeRepostRow(post: post);
    }
    return HomePostRow(
      post: post,
      showNearbyChipInHeader: showNearbyChipInHeader,
    );
  }

  @override
  ConsumerState<HomePostRow> createState() => _HomePostRowState();
}

class _HomePostRowState extends ConsumerState<HomePostRow> {
  Post get post => widget.post;

  late int _localLikeCount;
  bool? _optimisticLiked;

  @override
  void initState() {
    super.initState();
    _localLikeCount = post.likeCount;
  }

  @override
  void didUpdateWidget(HomePostRow old) {
    super.didUpdateWidget(old);
    if (old.post.likeCount != widget.post.likeCount) {
      _localLikeCount = widget.post.likeCount;
    }
  }

  void _toast(String message) {
    DabblerToastProvider.maybeOf(context)?.show(DabblerToastSpec(message: message));
  }

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

  // ── Like ────────────────────────────────────────────────────────────

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
      success = await ref.read(postActionsProvider.notifier).unlikePost(post.id);
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

  // ── Sheets ──────────────────────────────────────────────────────────

  void _showRepostMenu() {
    final l10n = AppLocalizations.of(context);
    showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.35],
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
            DabblerButton(
              label: l10n.post_card_menu_repost,
              icon: 'refresh',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(postActionsProvider.notifier).repostPost(post.id);
              },
            ),
            const SizedBox(height: DabblerSpacing.space3),
            DabblerButton(
              label: l10n.post_card_menu_quote_repost,
              icon: 'edit-2',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                // The quote composer is the shared sheet (legacy widgets).
                showAdaptiveSheet(
                  context: context,
                  isScrollControlled: true,
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

  void _showMoreMenu({required bool isAuthor}) {
    showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.3],
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
            DabblerButton(
              label: 'Report post',
              icon: 'flag',
              tone: DabblerButtonTone.destructive,
              fullWidth: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                // The report form is the shared dialog (legacy widgets).
                _showLegacyReportDialog(
                  context,
                  postId: post.id,
                  authorUserId: post.authorUserId,
                );
              },
            ),
            if (!isAuthor) ...[
              const SizedBox(height: DabblerSpacing.space3),
              DabblerButton(
                label: 'Block user',
                icon: 'user-remove',
                tone: DabblerButtonTone.destructive,
                fullWidth: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _blockAuthor();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _blockAuthor() async {
    final targetUserId = post.authorUserId;
    final result = await ref.read(blockRepositoryProvider).blockUser(targetUserId);
    if (!mounted) return;
    result.fold(
      (failure) => _toast('Failed to block user: ${failure.message}'),
      (_) {
        // Blocking removes this user's content from the loaded feed at once.
        ref.invalidate(blockedUserIdsProvider);
        ref.read(feedNotifierProvider.notifier).removePostsByAuthor(targetUserId);
        _toast('User blocked. Their content is now hidden.');
      },
    );
  }

  // ── Data helpers ────────────────────────────────────────────────────

  List<MapEntry<dynamic, dynamic>> _reactionBreakdownEntries(Post post) {
    final rawBreakdown = post.reactionBreakdown['breakdown'];
    if (rawBreakdown is Map) {
      return rawBreakdown.entries
          .where((e) => e.value is int && (e.value as int) > 0)
          .toList();
    }
    return [];
  }

  String _kindLabel(PostKind kind, AppLocalizations l10n) {
    switch (kind) {
      case PostKind.original:
        return l10n.post_type_original;
      case PostKind.news:
        return l10n.post_type_news;
      case PostKind.announcement:
        return l10n.post_type_announcement;
      case PostKind.alert:
        return l10n.post_type_alert;
      case PostKind.highlight:
        return l10n.post_type_highlight;
      case PostKind.general:
        return l10n.post_type_general;
      case PostKind.feature:
        return l10n.post_type_feature;
    }
  }

  String? _postTypeLabel(PostType type, AppLocalizations l10n) {
    switch (type) {
      case PostType.moment:
        return l10n.post_card_kind_moment;
      case PostType.dab:
        return l10n.post_card_kind_dab;
      case PostType.kickIn:
        return l10n.post_card_kind_kick_in;
      case PostType.allocated:
        return null;
    }
  }

  String _visibilityIcon(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return 'global';
      case PostVisibility.followers:
      case PostVisibility.circle:
        return 'people';
      case PostVisibility.squad:
        return 'profile-2user';
      case PostVisibility.private:
        return 'lock';
      case PostVisibility.link:
        return 'share';
    }
  }

  String? _originLabel(OriginType origin, AppLocalizations l10n) {
    switch (origin) {
      case OriginType.manual:
        return null;
      case OriginType.game:
        return l10n.post_card_kind_game;
      case OriginType.achievement:
        return l10n.post_card_kind_achievement;
      case OriginType.venue:
        return l10n.post_card_kind_venue;
      case OriginType.admin:
        return l10n.post_card_kind_admin;
      case OriginType.system:
        return l10n.post_card_kind_system;
      case OriginType.repost:
        return l10n.post_card_kind_repost;
    }
  }

  String? _expiryLabel(DateTime? expiresAt, AppLocalizations l10n) {
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return l10n.post_card_expired;
    if (diff.inDays > 0) return l10n.post_card_expires_in_days(diff.inDays);
    if (diff.inHours > 0) return l10n.post_card_expires_in_hours(diff.inHours);
    if (diff.inMinutes > 0) {
      return l10n.post_card_expires_in_minutes(diff.inMinutes);
    }
    return l10n.post_card_expiring_soon;
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);

    final hasLiked =
        _optimisticLiked ?? ref.watch(hasLikedProvider(post.id)).valueOrNull ?? false;
    final hasReposted =
        ref.watch(hasRepostedProvider(post.id)).valueOrNull ?? false;
    final myReactions =
        ref.watch(myReactionsProvider(post.id)).valueOrNull ?? <String>{};
    final myProfileId = ref.watch(myProfileIdProvider).valueOrNull;
    final isAuthor = myProfileId != null && post.authorProfileId == myProfileId;

    final author = (post.authorDisplayName ?? '').trim();
    final isAnonymous = author.isEmpty;
    final authorLabel = isAnonymous ? l10n.post_card_author_anonymous : author;
    // Allocated posts carry their kind (news, alert, …) instead of a type.
    final typeLabel = post.postType == PostType.allocated
        ? _kindLabel(post.kind, l10n)
        : _postTypeLabel(post.postType, l10n);
    final originLabel = _originLabel(post.originType, l10n);
    final expiryText = _expiryLabel(post.expiresAt, l10n);
    final hasImage = PostMediaCarousel.imageUrls(post.media).isNotEmpty;
    final canRepost = post.allowReposts && post.originType != OriginType.repost;
    final hasBody = post.body != null && post.body!.trim().isNotEmpty;
    final reactionEntries = _reactionBreakdownEntries(post);
    final reactionTotal =
        reactionEntries.fold<int>(0, (s, e) => s + (e.value as int));

    final TextStyle name = homeType(
      context,
      DabblerType.subheadline,
      colors.textPrimary,
      weight: DabblerType.semibold,
    );
    final TextStyle meta =
        homeType(context, DabblerType.caption1, colors.textSecondary);

    final Widget dot = Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space1),
      child: Text('·', style: meta),
    );

    final Widget header = Row(
      children: [
        Flexible(
          child: GestureDetector(
            onTap: isAnonymous ? null : () => _navigateToAuthorProfile(context, post),
            child: Text(
              authorLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: name,
            ),
          ),
        ),
        if (post.personaTypeSnapshot != null) ...[
          dot,
          Text(
            post.personaTypeSnapshot == 'organiser'
                ? l10n.post_card_persona_organiser
                : l10n.post_card_persona_player,
            style: meta,
          ),
        ],
        if (widget.showNearbyChipInHeader) ...[
          const Spacer(),
          DabblerIcon('location', size: 12, color: colors.brandPrimary),
          const SizedBox(width: DabblerSpacing.space1),
          Text(
            l10n.post_card_near_you,
            style: homeType(context, DabblerType.caption2, colors.brandPrimary),
          ),
        ] else
          const Spacer(),
        if (post.isPinned) ...[
          const SizedBox(width: DabblerSpacing.space1),
          DabblerIcon('location', size: 14, color: colors.brandPrimary),
        ],
        if (typeLabel != null) ...[
          const SizedBox(width: DabblerSpacing.space2),
          DabblerBadge(label: typeLabel, tone: DabblerBadgeTone.warning),
        ],
      ],
    );

    final Widget metaRow = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: DabblerSpacing.space2,
      runSpacing: DabblerSpacing.space1,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DabblerIcon(
              _visibilityIcon(post.visibility),
              size: 13,
              color: colors.textTertiary,
            ),
            const SizedBox(width: DabblerSpacing.space1),
            Text(homeRelativeTime(post.createdAt), style: meta),
            if (post.isEdited) ...[
              dot,
              Text(
                l10n.post_card_edited,
                style: meta.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        if (originLabel != null) DabblerBadge(label: originLabel),
        if (post.areaId != null)
          PostLocationChip(areaId: post.areaId!, locationName: post.locationName),
        if (post.requiresModeration)
          const DabblerBadge(label: 'Pending review', tone: DabblerBadgeTone.warning),
        if (expiryText != null)
          DabblerBadge(label: expiryText, tone: DabblerBadgeTone.warning),
      ],
    );

    final Widget actions = Row(
      children: [
        HomeTap(
          onTap: () => _handleLikeTap(hasLiked),
          label: 'Like',
          child: HomeActionItem(
            icon: 'heart',
            weight: hasLiked ? DabblerIconWeight.bold : DabblerIconWeight.linear,
            count: _localLikeCount,
            color: hasLiked ? colors.brandPrimary : colors.textSecondary,
          ),
        ),
        const SizedBox(width: DabblerSpacing.space6),
        HomeTap(
          onTap: () => showHomeReactionSheet(
            context,
            postId: post.id,
            myReactions: myReactions,
          ),
          label: 'React',
          child: HomeActionItem(
            icon: 'add-square',
            count: reactionTotal,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: DabblerSpacing.space6),
        HomeActionItem(
          icon: 'message-text',
          count: post.commentCount,
          color: colors.textSecondary,
        ),
        if (canRepost) ...[
          const SizedBox(width: DabblerSpacing.space6),
          HomeTap(
            onTap: () {
              if (hasReposted) {
                ref.read(postActionsProvider.notifier).undoRepost(post.id);
                return;
              }
              _showRepostMenu();
            },
            label: 'Repost',
            child: HomeActionItem(
              icon: 'refresh',
              weight:
                  hasReposted ? DabblerIconWeight.bold : DabblerIconWeight.linear,
              count: post.repostCount,
              color: hasReposted ? colors.brandPrimary : colors.textSecondary,
            ),
          ),
        ],
        if (isAuthor) ...[
          const SizedBox(width: DabblerSpacing.space6),
          HomeActionItem(
            icon: 'eye',
            count: post.viewCount,
            color: colors.textSecondary,
          ),
        ],
        const Spacer(),
        // Every post carries a control to flag it as objectionable
        // (App Review guideline 1.2).
        HomeTap(
          onTap: () => _showMoreMenu(isAuthor: isAuthor),
          label: 'More',
          child: DabblerIcon('more-circle', size: 20, color: colors.textSecondary),
        ),
      ],
    );

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: DabblerSpacing.space1),
        metaRow,
        if (hasImage)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
            // DS GAP: no media / carousel component; the shared carousel draws
            // the post's own images.
            child: PostMediaCarousel(media: post.media, borderRadius: DabblerRadius.lg),
          ),
        if (hasBody)
          Padding(
            padding: EdgeInsetsDirectional.only(
              top: hasImage ? DabblerSpacing.space3 : DabblerSpacing.space2,
            ),
            child: Text(
              post.body!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: homeType(context, DabblerType.subheadline, colors.textPrimary),
            ),
          ),
        if (post.vibes.isNotEmpty || (post.sport != null && post.sport!.isNotEmpty))
          Padding(
            padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
            child: Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space1,
              children: [
                if (post.sport != null && post.sport!.isNotEmpty)
                  Consumer(
                    builder: (context, ref, _) {
                      final sports = ref.watch(sportsProvider).valueOrNull ?? [];
                      final matched =
                          sports.where((s) => s.id == post.sportId).firstOrNull;
                      final text =
                          matched?.localizedName(context) ?? post.sport!;
                      final emoji = matched?.emoji ?? '';
                      return DabblerBadge(
                        label: emoji.isNotEmpty && !text.startsWith(emoji)
                            ? '$emoji $text'
                            : text,
                      );
                    },
                  ),
                for (final vibe in post.vibes.take(3))
                  DabblerBadge(
                    label: [
                      if ((vibe.emoji ?? '').isNotEmpty) vibe.emoji!,
                      vibe.labelEn.isNotEmpty
                          ? vibe.labelEn
                          : vibe.key[0].toUpperCase() + vibe.key.substring(1),
                    ].join(' '),
                  ),
              ],
            ),
          ),
        if (post.tags.length > 1)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space2),
            child: Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space1,
              children: [
                for (final tag in post.tags.skip(1))
                  Text(
                    '#$tag',
                    style: homeType(
                      context,
                      DabblerType.caption1,
                      colors.brandPrimary,
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
          child: actions,
        ),
        if (reactionEntries.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space2),
            child: Consumer(
              builder: (context, ref, _) {
                final vibes = ref.watch(vibesProvider).valueOrNull ?? [];
                return Wrap(
                  spacing: DabblerSpacing.space2,
                  runSpacing: DabblerSpacing.space1,
                  children: [
                    for (final entry in reactionEntries.take(5))
                      Builder(
                        builder: (context) {
                          final vibeKey = entry.key.toString();
                          final count = entry.value as int;
                          final matched =
                              vibes.where((v) => v.key == vibeKey).firstOrNull;
                          final emoji = matched?.emoji ?? vibeKey;
                          final mine = matched != null &&
                              myReactions.contains(matched.id);
                          return DabblerChip(
                            label: '$emoji $count',
                            selected: mine,
                            onTap: () {
                              if (matched == null) return;
                              final a = ref.read(postActionsProvider.notifier);
                              if (mine) {
                                a.removeReaction(post.id, matched.id);
                              } else {
                                a.reactToPost(post.id, matched.id);
                              }
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );

    final Widget body = Padding(
      padding: widget.isEmbedded
          ? const EdgeInsets.all(DabblerSpacing.space4)
          : const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space6,
              vertical: DabblerSpacing.space5,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isEmbedded) ...[
            GestureDetector(
              onTap: isAnonymous ? null : () => _navigateToAuthorProfile(context, post),
              child: HomeAvatar(name: authorLabel, imageUrl: post.authorAvatarUrl),
            ),
            const SizedBox(width: DabblerSpacing.space3),
          ],
          Expanded(child: content),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('${RoutePaths.socialPostDetail}/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (post.commentCount > 0)
            HomeThreadPreview(postId: post.id, isEmbedded: widget.isEmbedded),
        ],
      ),
    );
  }
}

/// Opens the shared report form. The form is a shared legacy Material dialog
/// (it needs Material's dialog route), not part of Home's presentation.
void _showLegacyReportDialog(
  BuildContext context, {
  required String postId,
  required String authorUserId,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => ReportDialog(
      targetType: ReportTargetType.post,
      targetId: postId,
      targetUserId: authorUserId,
    ),
  );
}

/// A repost: the reposter's header, an optional quote, and the original post
/// embedded in a [DabblerCard].
class HomeRepostRow extends ConsumerWidget {
  const HomeRepostRow({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);
    final original = post.originalPost;
    final author = (post.authorDisplayName ?? '').trim();
    final isAnonymous = author.isEmpty;
    final authorLabel = isAnonymous ? l10n.post_card_author_anonymous : author;

    Future<void> openAuthor() async {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final myProfileId = await ref.read(myProfileIdProvider.future);
      if (!context.mounted) return;
      if (post.authorUserId == currentUserId &&
          post.authorProfileId == myProfileId) {
        context.go(RoutePaths.profile);
      } else {
        context.push(
          '${RoutePaths.userProfile}/${post.authorUserId}?profileId=${post.authorProfileId}',
        );
      }
    }

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: isAnonymous ? null : openAuthor,
            child: HomeAvatar(name: authorLabel, imageUrl: post.authorAvatarUrl),
          ),
          const SizedBox(width: DabblerSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: isAnonymous ? null : openAuthor,
                        child: Text(
                          authorLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: homeType(
                            context,
                            DabblerType.subheadline,
                            colors.textPrimary,
                            weight: DabblerType.semibold,
                          ),
                        ),
                      ),
                    ),
                    if (post.personaTypeSnapshot != null) ...[
                      const SizedBox(width: DabblerSpacing.space2),
                      DabblerBadge(
                        label: post.personaTypeSnapshot == 'organiser'
                            ? l10n.post_card_persona_organiser
                            : l10n.post_card_persona_player,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DabblerSpacing.space1),
                Row(
                  children: [
                    DabblerIcon('refresh', size: 13, color: colors.brandPrimary),
                    const SizedBox(width: DabblerSpacing.space1),
                    Text(
                      '${l10n.post_card_kind_repost} · ${homeRelativeTime(post.createdAt)}',
                      style: homeType(
                        context,
                        DabblerType.caption1,
                        colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (post.body != null && post.body!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: DabblerSpacing.space2,
                    ),
                    child: Text(
                      post.body!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: homeType(
                        context,
                        DabblerType.subheadline,
                        colors.textPrimary,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: DabblerSpacing.space3,
                  ),
                  child: DabblerCard(
                    padding: EdgeInsets.zero,
                    child: original != null
                        ? HomePostRow(post: original, isEmbedded: true)
                        : Padding(
                            padding: const EdgeInsets.all(DabblerSpacing.space4),
                            child: Text(
                              l10n.repost_card_unavailable,
                              style: homeType(
                                context,
                                DabblerType.footnote,
                                colors.textSecondary,
                              ),
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

/// The latest comment shown under a post, as a thread.
class HomeThreadPreview extends ConsumerWidget {
  const HomeThreadPreview({
    super.key,
    required this.postId,
    required this.isEmbedded,
  });

  final String postId;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DabblerColors.of(context);
    final l10n = AppLocalizations.of(context);
    final asyncComment = ref.watch(latestCommentProvider(postId));

    return asyncComment.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (comment) {
        if (comment == null) return const SizedBox.shrink();
        final name = comment.authorDisplayName ?? l10n.post_card_user_fallback;
        final hasBody = comment.body.trim().isNotEmpty;
        final hasLocation =
            comment.locationName != null && comment.locationName!.isNotEmpty;
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            isEmbedded ? 0 : DabblerSpacing.space10 + DabblerSpacing.space8,
            0,
            DabblerSpacing.space6,
            DabblerSpacing.space4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeAvatar(
                name: name,
                imageUrl: comment.authorAvatarUrl,
                size: DabblerAvatarSize.xs,
              ),
              const SizedBox(width: DabblerSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: homeType(
                              context,
                              DabblerType.footnote,
                              colors.textPrimary,
                              weight: DabblerType.semibold,
                            ),
                          ),
                        ),
                        const SizedBox(width: DabblerSpacing.space2),
                        Text(
                          homeRelativeTime(comment.createdAt),
                          style: homeType(
                            context,
                            DabblerType.caption1,
                            colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (hasBody)
                      Text(
                        comment.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: homeType(
                          context,
                          DabblerType.footnote,
                          colors.textPrimary,
                        ),
                      ),
                    if (hasLocation)
                      Row(
                        children: [
                          DabblerIcon('location', size: 12, color: colors.textTertiary),
                          const SizedBox(width: DabblerSpacing.space1),
                          Text(
                            comment.locationName!,
                            style: homeType(
                              context,
                              DabblerType.caption1,
                              colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/news/news_comment.dart';
import 'package:dabbler/features/home/presentation/widgets/home_news_rows.dart'
    show
        homeNewsReactionCountsProvider,
        showHomeNewsReactionPicker,
        toggleHomeNewsReaction;
import 'package:dabbler/features/news/providers/news_actions_provider.dart';
import 'package:dabbler/features/news/providers/news_comments_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show myReactionsProvider;

/// One news story (design X01, "Article").
class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({super.key, required this.item});

  final FeedNewsItem item;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  final _scrollController = ScrollController();
  final _commentController = TextEditingController();
  final _commentsKey = GlobalKey();
  bool _submitting = false;
  late int _localCommentCount;

  @override
  void initState() {
    super.initState();
    _localCommentCount = widget.item.commentCount;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _scrollToComments() {
    final ctx = _commentsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
      );
    }
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _submitting) return;
    setState(() => _submitting = true);

    final titleSnapshot = Map<String, String>.from(
      widget.item.title.map((k, v) => MapEntry(k, v)),
    );

    final result = await ref
        .read(newsActionsProvider.notifier)
        .addComment(widget.item.newsId, body, titleSnapshot);

    if (mounted) {
      setState(() => _submitting = false);
      result.fold((_) => null, (comment) {
        _commentController.clear();
        setState(() => _localCommentCount++);
        ref
            .read(newsCommentsProvider(widget.item.newsId).notifier)
            .append(comment);
      });
    }
  }

  TextStyle _type(DabblerTypeStyle step, Color color, {FontWeight? weight}) =>
      step
          .resolveForDirection(Directionality.of(context))
          .copyWith(color: color, fontWeight: weight);

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final item = widget.item;
    final title = item.localizedTitle(lang);
    final body = item.localizedBody(lang);
    final dateStr = DateFormat('MMM d, yyyy').format(item.createdAt.toLocal());
    final commentsAsync = ref.watch(newsCommentsProvider(item.newsId));
    final mine =
        ref.watch(myReactionsProvider(item.newsId)).valueOrNull ??
        const <String>{};
    final counts =
        ref.watch(homeNewsReactionCountsProvider(item.newsId)).valueOrNull ??
        const <String, int>{};
    final likes = counts.values.fold<int>(0, (a, b) => a + b);

    const side = DabblerSpacing.space6;

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: item.feedLabel ?? 'News',
        onBack: () => context.pop(),
      ),
      bottomBar: _CommentBar(
        controller: _commentController,
        submitting: _submitting,
        onSubmit: _submitComment,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                side,
                DabblerSpacing.space2,
                side,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.coverImageUrl != null) ...[
                    DabblerImage(
                      url: item.coverImageUrl,
                      aspectRatio: 4 / 5,
                      semanticLabel: title,
                    ),
                    const SizedBox(height: DabblerSpacing.space6),
                  ],
                  Row(
                    children: [
                      if (item.feedLabel != null) ...[
                        DabblerBadge(label: item.feedLabel!),
                        const SizedBox(width: DabblerSpacing.space3),
                      ],
                      if (item.isPinned) ...[
                        DabblerIcon(
                          'bookmark-2',
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: DabblerSpacing.space2),
                      ],
                      Text(
                        dateStr,
                        style: _type(DabblerType.caption1, colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: DabblerSpacing.space4),
                  Text(
                    title,
                    style: _type(DabblerType.title1, colors.textPrimary),
                  ),
                  if (item.sourceLabel != null) ...[
                    const SizedBox(height: DabblerSpacing.space4),
                    Row(
                      children: [
                        DabblerAvatar(
                          seed: item.sourceLabel!,
                          size: DabblerAvatarSize.sm,
                        ),
                        const SizedBox(width: DabblerSpacing.space3),
                        Expanded(
                          child: Text(
                            item.sourceLabel!,
                            style: _type(
                              DabblerType.subheadline,
                              colors.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: DabblerSpacing.space6),
                  const DabblerDivider(),
                  const SizedBox(height: DabblerSpacing.space5),
                  if (body.isNotEmpty)
                    Text(
                      body,
                      style: _type(DabblerType.body, colors.textPrimary),
                    ),
                  const SizedBox(height: DabblerSpacing.space7),
                  Wrap(
                    spacing: DabblerSpacing.space2,
                    runSpacing: DabblerSpacing.space2,
                    children: [
                      DabblerButton(
                        label: '$likes',
                        icon: 'heart',
                        tone: mine.isNotEmpty
                            ? DabblerButtonTone.primary
                            : DabblerButtonTone.secondary,
                        size: DabblerButtonSize.small,
                        semanticLabel: 'Like',
                        onPressed: () =>
                            toggleHomeNewsReaction(ref, item.newsId, mine),
                      ),
                      DabblerButton(
                        label: 'React',
                        icon: 'emoji-happy',
                        tone: DabblerButtonTone.secondary,
                        size: DabblerButtonSize.small,
                        onPressed: () => showHomeNewsReactionPicker(
                          context,
                          ref,
                          item.newsId,
                          mine,
                        ),
                      ),
                      DabblerButton(
                        label: '$_localCommentCount',
                        icon: 'message',
                        tone: DabblerButtonTone.secondary,
                        size: DabblerButtonSize.small,
                        semanticLabel: 'Comments',
                        onPressed: _scrollToComments,
                      ),
                    ],
                  ),
                  const SizedBox(height: DabblerSpacing.space7),
                  const DabblerDivider(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            key: _commentsKey,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                side,
                DabblerSpacing.space5,
                side,
                DabblerSpacing.space1,
              ),
              child: Text(
                'Comments',
                style: _type(DabblerType.headline, colors.textPrimary),
              ),
            ),
          ),
          commentsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(DabblerSpacing.space8),
                child: Center(child: DabblerSpinner()),
              ),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (comments) => comments.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        side,
                        DabblerSpacing.space4,
                        side,
                        DabblerSpacing.space10,
                      ),
                      child: Text(
                        'Be the first to comment.',
                        style: _type(
                          DabblerType.subheadline,
                          colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _CommentRow(comment: comments[i], lang: lang),
                      childCount: comments.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: DabblerSpacing.space10),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.lang});

  final NewsComment comment;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);
    final displayName =
        comment.authorDisplayName ?? comment.authorUsername ?? 'User';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DabblerAvatar(
            seed: displayName,
            imageUrl: comment.authorAvatarUrl,
            size: DabblerAvatarSize.sm,
          ),
          const SizedBox(width: DabblerSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DabblerType.footnote
                            .resolveForDirection(dir)
                            .copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Text(
                      timeago.format(comment.createdAt, locale: lang),
                      style: DabblerType.caption2
                          .resolveForDirection(dir)
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: DabblerSpacing.space1),
                Text(
                  comment.body,
                  style: DabblerType.subheadline
                      .resolveForDirection(dir)
                      .copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBar extends StatelessWidget {
  const _CommentBar({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          border: Border(top: BorderSide(color: colors.borderDefault)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space4,
            vertical: DabblerSpacing.space2,
          ),
          child: Row(
            children: [
              Expanded(
                child: DabblerTextField(
                  controller: controller,
                  placeholder: 'Add a comment…',
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: DabblerSpacing.space2),
              DabblerButton.icon(
                icon: 'send-1',
                semanticLabel: 'Send',
                loading: submitting,
                onPressed: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

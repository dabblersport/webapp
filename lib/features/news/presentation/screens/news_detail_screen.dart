import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/news/presentation/widgets/news_comment_tile.dart';
import 'package:dabbler/features/news/presentation/widgets/news_label_badge.dart';
import 'package:dabbler/features/news/presentation/widgets/news_like_bar.dart';
import 'package:dabbler/features/news/providers/news_actions_provider.dart';
import 'package:dabbler/features/news/providers/news_comments_provider.dart';

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

    final result = await ref.read(newsActionsProvider.notifier).addComment(
          widget.item.newsId,
          body,
          titleSnapshot,
        );

    if (mounted) {
      setState(() => _submitting = false);
      result.fold(
        (_) => null,
        (comment) {
          _commentController.clear();
          setState(() => _localCommentCount++);
          ref
              .read(newsCommentsProvider(widget.item.newsId).notifier)
              .append(comment);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final lang = locale.languageCode;
    final cs = Theme.of(context).colorScheme;
    final item = widget.item;
    final title = item.localizedTitle(lang);
    final body = item.localizedBody(lang);
    final dateStr = DateFormat('MMM d, yyyy').format(item.createdAt.toLocal());
    final commentsAsync = ref.watch(newsCommentsProvider(item.newsId));

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.sizeOf(context).width * 9 / 16,
            pinned: true,
            backgroundColor: cs.surface,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _CoverHero(item: item),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + date row
                  Row(
                    children: [
                      if (item.feedLabel != null) ...[
                        NewsLabelBadge(item.feedLabel!),
                        const SizedBox(width: 10),
                      ],
                      if (item.isPinned) ...[
                        Icon(
                          Iconsax.bookmark_2_copy,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                  ),
                  if (item.sourceLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.sourceLabel!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (body.isNotEmpty)
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface,
                        height: 1.7,
                      ),
                    ),
                  const SizedBox(height: 24),
                  NewsLikeBar(
                    newsId: item.newsId,
                    commentCount: _localCommentCount,
                    viewCount: item.viewCount,
                    onCommentTap: _scrollToComments,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                ],
              ),
            ),
          ),
          // Comments heading
          SliverToBoxAdapter(
            key: _commentsKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          // Comments list
          commentsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (comments) => comments.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: Text(
                        'Be the first to comment.',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => NewsCommentTile(comment: comments[i]),
                      childCount: comments.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      bottomNavigationBar: _CommentBar(
        controller: _commentController,
        submitting: _submitting,
        onSubmit: _submitComment,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 8),
            submitting
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: onSubmit,
                    icon: Icon(Iconsax.send_1, color: cs.primary),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CoverHero extends StatelessWidget {
  const _CoverHero({required this.item});
  final FeedNewsItem item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.coverImageUrl != null)
          CachedNetworkImage(
            imageUrl: item.coverImageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade800),
            errorWidget: (_, __, ___) =>
                Container(color: Colors.grey.shade800),
          )
        else
          Container(color: Colors.grey.shade800),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.4),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

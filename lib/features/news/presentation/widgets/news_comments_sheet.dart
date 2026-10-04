import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/news/providers/news_actions_provider.dart';
import 'package:dabbler/features/news/providers/news_comments_provider.dart';

/// The comments sheet of `Article.dc.html` (inline Sheet titled with the
/// comment count): the comment list with the composer in the footer.
Future<void> showNewsCommentsSheet(
  BuildContext context, {
  required FeedNewsItem item,
  required String lang,
  required int count,
  required VoidCallback onPosted,
}) {
  return showDabblerSheet<void>(
    context: context,
    title: AppLocalizations.of(context).sfx_comments_count(count),
    detent: DabblerSheetDetent.content,
    showCloseButton: false,
    builder: (_) => _CommentsList(newsId: item.newsId, lang: lang),
    footerBuilder: (_) => _CommentComposer(item: item, onPosted: onPosted),
  );
}

class _CommentsList extends ConsumerWidget {
  const _CommentsList({required this.newsId, required this.lang});

  final String newsId;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(newsCommentsProvider(newsId))
        .when(
          loading: () => const Center(child: DabblerSpinner()),
          error: (_, __) => const SizedBox.shrink(),
          data: (comments) => comments.isEmpty
              ? DabblerText(
                  AppLocalizations.of(context).sfx_be_first,
                  style: DabblerType.subheadline,
                  tone: DabblerTextTone.secondary,
                )
              : Column(
                  children: [
                    for (final c in comments)
                      DabblerCommentRow(
                        name: c.authorDisplayName ?? c.authorUsername ?? 'User',
                        imageUrl: c.authorAvatarUrl,
                        time: timeago.format(c.createdAt, locale: lang),
                        body: c.body,
                        showLike: false,
                      ),
                  ],
                ),
        );
  }
}

class _CommentComposer extends ConsumerStatefulWidget {
  const _CommentComposer({required this.item, required this.onPosted});

  final FeedNewsItem item;
  final VoidCallback onPosted;

  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final titleSnapshot = Map<String, String>.from(
      widget.item.title.map((k, v) => MapEntry(k, v)),
    );
    final result = await ref
        .read(newsActionsProvider.notifier)
        .addComment(widget.item.newsId, body, titleSnapshot);
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold((_) => null, (comment) {
      _controller.clear();
      widget.onPosted();
      ref
          .read(newsCommentsProvider(widget.item.newsId).notifier)
          .append(comment);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: DabblerSpacing.space3,
      children: [
        Expanded(
          child: DabblerTextField(
            controller: _controller,
            placeholder: AppLocalizations.of(context).sfx_add_comment,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
          ),
        ),
        DabblerButton.icon(
          icon: 'send-2',
          tone: DabblerButtonTone.primary,
          semanticLabel: AppLocalizations.of(context).sfx_send,
          loading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

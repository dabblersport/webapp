import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/home/presentation/widgets/home_news_rows.dart'
    show
        homeNewsReactionCountsProvider,
        showHomeNewsReactionPicker,
        toggleHomeNewsReaction;
import 'package:dabbler/features/news/presentation/widgets/news_comments_sheet.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show myReactionsProvider;

/// The user-agent / accept headers the news CDN requires for cover images —
/// the map the pre-migration cover `CachedNetworkImage` sent. Flutter web
/// ignores request headers on image loads.
const Map<String, String> _coverHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

/// One news story (`Article.dc.html`, frame Article).
class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({super.key, required this.item});

  final FeedNewsItem item;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  final _scrollController = ScrollController();
  late int _localCommentCount;

  @override
  void initState() {
    super.initState();
    _localCommentCount = widget.item.commentCount;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openComments(String lang) => showNewsCommentsSheet(
    context,
    item: widget.item,
    lang: lang,
    onPosted: () => setState(() => _localCommentCount++),
  );

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).languageCode;
    final item = widget.item;
    final title = item.localizedTitle(lang);
    final body = item.localizedBody(lang);
    final when = timeago.format(item.createdAt.toLocal(), locale: lang);
    final mine =
        ref.watch(myReactionsProvider(item.newsId)).valueOrNull ??
        const <String>{};
    final counts =
        ref.watch(homeNewsReactionCountsProvider(item.newsId)).valueOrNull ??
        const <String, int>{};
    final likes = counts.values.fold<int>(0, (a, b) => a + b);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: title,
        scrollController: _scrollController,
        onBack: () => context.pop(),
      ),
      bottomBar: Row(
        spacing: DabblerSpacing.space3,
        children: [
          DabblerButton(
            label: '$likes',
            icon: 'heart',
            tone: mine.isNotEmpty
                ? DabblerButtonTone.primary
                : DabblerButtonTone.outlined,
            semanticLabel: 'Like',
            onPressed: () => toggleHomeNewsReaction(ref, item.newsId, mine),
            // Long-press opens the reaction picker, as the original like bar
            // did.
            onLongPress: () =>
                showHomeNewsReactionPicker(context, ref, item.newsId, mine),
          ),
          DabblerButton(
            label: '$_localCommentCount',
            icon: 'message-text',
            tone: DabblerButtonTone.outlined,
            semanticLabel: 'Comments',
            onPressed: () => _openComments(lang),
          ),
          const Spacer(),
          DabblerButton(label: 'Discuss', onPressed: () => _openComments(lang)),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
          vertical: DabblerSpacing.space4,
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DabblerSpacing.space5,
            children: [
              Row(
                spacing: DabblerSpacing.space3,
                children: [
                  if (item.feedLabel != null)
                    DabblerBadge(label: item.feedLabel!),
                  DabblerText(
                    when,
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                  ),
                ],
              ),
              DabblerText(title, style: DabblerType.title1),
              if (item.sourceLabel != null)
                Row(
                  spacing: DabblerSpacing.space3,
                  children: [
                    DabblerAvatar(
                      seed: item.sourceLabel!,
                      size: DabblerAvatarSize.sm,
                    ),
                    Expanded(
                      child: DabblerText(
                        item.sourceLabel!,
                        style: DabblerType.subheadline,
                        weight: DabblerTextWeight.semibold,
                      ),
                    ),
                  ],
                ),
              if (item.coverImageUrl != null)
                DabblerImage(
                  url: item.coverImageUrl,
                  aspectRatio: 4 / 5,
                  semanticLabel: title,
                  headers: _coverHeaders,
                ),
              if (body.isNotEmpty) DabblerText(body, style: DabblerType.body),
            ],
          ),
        ],
      ),
    );
  }
}

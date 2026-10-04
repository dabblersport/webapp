import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show myReactionsProvider, postActionsProvider;
import 'package:dabbler/utils/constants/route_constants.dart';

void _openNews(BuildContext context, FeedNewsItem item) => context.pushNamed(
  RouteNames.newsDetail,
  pathParameters: {'newsId': item.newsId},
  extra: item,
);

/// One news story, drawn by [DabblerNewsCard] (cover: [DabblerImage]).
///
/// On the Most Recent feed [onDismiss] adds a swipe-to-hide action
/// ([DabblerSwipeAction]); it calls the same callback as before (the hide-news
/// confirmation).
class HomeNewsCard extends ConsumerWidget {
  const HomeNewsCard({super.key, required this.item, this.onDismiss});

  final FeedNewsItem item;

  /// Set on the Most Recent feed: swiping the story toward the end asks to
  /// hide news (the callback opens the confirmation sheet).
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    final mine =
        ref.watch(myReactionsProvider(item.newsId)).valueOrNull ??
        const <String>{};
    final counts =
        ref.watch(homeNewsReactionCountsProvider(item.newsId)).valueOrNull ??
        const <String, int>{};
    final likes = counts.values.fold<int>(0, (a, b) => a + b);
    final body = item.localizedBody(lang);
    final url = item.coverImageUrl;

    final Widget card = DabblerNewsCard(
      metrics: DabblerFeedMetrics.drawn,
      media: url == null
          ? null
          : DabblerImage(url: url, radius: BorderRadius.zero),
      sportLabel: item.feedLabel,
      title: item.localizedTitle(lang),
      excerpt: body.isEmpty ? null : body,
      time: timeago.format(item.createdAt, locale: lang),
      likes: likes,
      comments: item.commentCount,
      views: item.viewCount,
      liked: mine.isNotEmpty,
      onTap: () => _openNews(context, item),
      onLike: () => toggleHomeNewsReaction(ref, item.newsId, mine),
      onLikeLongPress: () =>
          showHomeNewsReactionPicker(context, ref, item.newsId, mine),
      onComment: () => _openNews(context, item),
    );

    final VoidCallback? hide = onDismiss;
    if (hide == null) return card;

    return DabblerSwipeAction(
      actions: [
        DabblerSwipeActionItem(
          label: 'Hide',
          icon: 'eye-slash',
          onPressed: hide,
        ),
      ],
      child: card,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// News reactions (tap the heart toggles the default reaction)
// ─────────────────────────────────────────────────────────────────────────────

/// The six reactions a news item takes (same ids as the previous like bar).
class _NewsReaction {
  const _NewsReaction(this.id, this.label);
  final String id;
  final String label;
}

const List<_NewsReaction> _newsReactions = <_NewsReaction>[
  _NewsReaction('bbcccbeb-e506-4906-8a58-018659d0a43d', 'Loving'),
  _NewsReaction('477472a9-7535-42b6-b08d-d6054eee9856', 'Determined'),
  _NewsReaction('350a7cca-b044-4b22-8c96-add0dd39c059', 'Motivated'),
  _NewsReaction('177211d5-73a4-4835-a7f2-48fd238c778d', 'Proud'),
  _NewsReaction('f4a9f402-2dbd-40a9-8a6c-61cbea065145', 'Disappointed'),
  _NewsReaction('4af43b42-a0f3-4008-812b-0b40548e32f6', 'Angry'),
];

final homeNewsReactionCountsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, newsId) async {
      final db = Supabase.instance.client;
      final allowedIds = _newsReactions.map((r) => r.id).toList();
      final rows =
          await db
                  .from(SupabaseConfig.reactionsTable)
                  .select('vibe_id')
                  .eq('parent_activity_id', newsId)
                  .inFilter('vibe_id', allowedIds)
              as List;
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['vibe_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    });

/// The six-reaction picker the news heart opens on a long press (it was a
/// floating overlay before; it is a design-system sheet now). Choosing one
/// replaces the user's current reaction; choosing the current one removes it.
Future<void> showHomeNewsReactionPicker(
  BuildContext context,
  WidgetRef ref,
  String newsId,
  Set<String> mine,
) {
  return showDabblerSheet<void>(
    context: context,
    title: 'React',
    detent: DabblerSheetDetent.content,
    builder: (ctx) => Wrap(
      spacing: DabblerSpacing.space2,
      runSpacing: DabblerSpacing.space2,
      children: [
        for (final r in _newsReactions)
          DabblerChip(
            label: r.label,
            selected: mine.contains(r.id),
            onTap: () async {
              Navigator.of(ctx).pop();
              final actions = ref.read(postActionsProvider.notifier);
              if (mine.contains(r.id)) {
                await actions.removeReaction(newsId, r.id);
              } else {
                for (final id in mine) {
                  await actions.removeReaction(newsId, id);
                }
                await actions.reactToPost(newsId, r.id);
              }
              ref.invalidate(homeNewsReactionCountsProvider(newsId));
              ref.invalidate(myReactionsProvider(newsId));
            },
          ),
      ],
    ),
  );
}

/// Toggles the user's reaction on a news item: tapping when they have reacted
/// removes it, otherwise the default (the first) reaction is set.
Future<void> toggleHomeNewsReaction(
  WidgetRef ref,
  String newsId,
  Set<String> mine,
) async {
  final actions = ref.read(postActionsProvider.notifier);
  if (mine.isNotEmpty) {
    for (final id in mine) {
      await actions.removeReaction(newsId, id);
    }
  } else {
    await actions.reactToPost(newsId, _newsReactions.first.id);
  }
  ref.invalidate(homeNewsReactionCountsProvider(newsId));
  ref.invalidate(myReactionsProvider(newsId));
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity (Following)
// ─────────────────────────────────────────────────────────────────────────────

/// A `public_activities` row, drawn by [DabblerActivityRow].
class HomeActivityRow extends StatelessWidget {
  const HomeActivityRow({super.key, required this.activity});

  final PublicActivity activity;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final hasNewsTarget =
        activity.activityType == PublicActivityType.comment &&
        activity.targetNewsId != null;
    final newsTitle = activity.localizedTargetTitle(locale);

    return DabblerActivityRow(
      metrics: DabblerFeedMetrics.drawn,
      leading: DabblerAvatar(
        seed: activity.actorUsername,
        imageUrl: activity.actorAvatarUrl,
        size: DabblerAvatarSize.sm,
      ),
      actor: activity.actorUsername,
      verb: activity.actionLabel,
      subject: hasNewsTarget && newsTitle.isNotEmpty ? newsTitle : null,
      when: timeago.format(
        activity.createdAt,
        allowFromNow: true,
        locale: locale,
      ),
      thumbnail: hasNewsTarget && activity.targetCoverImageUrl != null
          ? DabblerImage(
              url: activity.targetCoverImageUrl,
              radius: BorderRadius.zero,
            )
          : null,
      onTap: hasNewsTarget ? () => _navigateToNews(context) : null,
    );
  }

  void _navigateToNews(BuildContext context) {
    final newsId = activity.targetNewsId!;
    // A minimal item for the route — the detail screen fetches the rest.
    final item = FeedNewsItem(
      newsId: newsId,
      id: activity.parentActivityId ?? newsId,
      title: activity.targetTitle,
      body: const {},
      likeCount: 0,
      commentCount: 0,
      viewCount: 0,
      tags: const [],
      isPinned: false,
      priorityScore: 0,
      createdAt: activity.createdAt,
      coverImageUrl: activity.targetCoverImageUrl,
    );
    context.pushNamed(
      RouteNames.newsDetail,
      pathParameters: {'newsId': newsId},
      extra: item,
    );
  }
}

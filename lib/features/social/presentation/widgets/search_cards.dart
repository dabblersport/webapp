import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/home/presentation/widgets/home_feed_parts.dart'
    show homeRelativeTime;
import 'package:intl/intl.dart';

import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/search/comment_search_result.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Strips the search grammar (`@`, `#`, `/g `…) so only the typed words are
/// highlighted.
String searchNeedle(String query) => query
    .trim()
    .replaceAll(RegExp(r'^[@#]'), '')
    .replaceAll(RegExp(r'^/[a-z]\s*'), '')
    .trim();

String _formatWhen(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = day.difference(today).inDays;
  final time = DateFormat('h:mm a').format(dt);
  if (diff == 0) return 'Today · $time';
  if (diff == 1) return 'Tomorrow · $time';
  if (diff > 0 && diff < 7) return '${DateFormat('EEE').format(dt)} · $time';
  return DateFormat('d MMM · h:mm a').format(dt);
}

/// The white result card every result list is drawn on
/// (`Search.dc.html:188-215`): one hairline card, 12 inside.
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DabblerCard(
    variant: DabblerCardVariant.white,
    radius: DabblerRadius.lg,
    padding: const EdgeInsets.all(DabblerSpacing.space4),
    onTap: onTap,
    child: child,
  );
}

/// A person: avatar, name with the match highlighted, handle, Follow
/// (`Search.dc.html:238-254`).
class SearchPersonCard extends StatelessWidget {
  const SearchPersonCard({
    super.key,
    required this.profile,
    required this.query,
    required this.onTap,
  });

  final Profile profile;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DabblerCard(
    variant: DabblerCardVariant.white,
    radius: DabblerRadius.lg,
    width: DabblerSizing.railCardWidth - DabblerSpacing.space6,
    padding: const EdgeInsets.symmetric(
      horizontal: DabblerSpacing.space4,
      vertical: DabblerSpacing.space5,
    ),
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: DabblerSpacing.space3,
      children: [
        DabblerAvatar(
          seed: profile.id,
          imageUrl: profile.avatarUrl,
          size: DabblerAvatarSize.md,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DabblerHighlightedText(
              text: profile.displayName,
              query: searchNeedle(query),
              style: DabblerType.subheadline,
              fontWeight: DabblerHighlightedText.matchWeight,
              maxLines: 1,
            ),
            DabblerText(
              '\u2066@${profile.username}\u2069',
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        DabblerButton(
          label: AppLocalizations.of(context).sfx_follow,
          size: DabblerButtonSize.small,
          fullWidth: true,
          onPressed: onTap,
        ),
      ],
    ),
  );
}

/// A person as a list row (`View_all_people`): avatar, highlighted name,
/// handle, Follow.
class SearchPersonRow extends StatelessWidget {
  const SearchPersonRow({
    super.key,
    required this.profile,
    required this.query,
    required this.onTap,
  });

  final Profile profile;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DabblerInputRow(
    leading: DabblerAvatar(
      seed: profile.id,
      imageUrl: profile.avatarUrl,
      size: DabblerAvatarSize.md,
    ),
    titleSpan: DabblerInputRow.highlightSpan(
      profile.displayName,
      searchNeedle(query),
      DabblerColors.of(context),
    ),
    titleSemibold: true,
    subtitle: '\u2066@${profile.username}\u2069',
    trailing: DabblerButton(
      label: AppLocalizations.of(context).sfx_follow,
      size: DabblerButtonSize.small,
      onPressed: onTap,
    ),
    flat: true,
    onTap: onTap,
  );
}

/// A hashtag as a tappable card (`Search.dc.html:196-203`).
class SearchHashtagCard extends StatelessWidget {
  const SearchHashtagCard({
    super.key,
    required this.hashtag,
    required this.query,
  });

  final HashtagSearchResult hashtag;
  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pushNamed(
        RouteNames.hashtagFeed,
        pathParameters: {'slug': hashtag.slug},
        queryParameters: {'postCount': '${hashtag.postCount}'},
      ),
      child: DabblerSurface(
        radius: DabblerRadius.lg,
        borderColor: colors.brandPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: DabblerSpacing.space5,
          vertical: DabblerSpacing.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerHighlightedText(
              text: '\u2066#${hashtag.slug}\u2069',
              query: searchNeedle(query),
              style: DabblerType.subheadline,
              fontWeight: DabblerHighlightedText.matchWeight,
              maxLines: 1,
            ),
            DabblerText(
              AppLocalizations.of(context).sfx_posts_count(hashtag.postCount),
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A hashtag as a grid card of `View_all_hashtags` (`Search.dc.html`): icon
/// tile, the tag with the match highlighted, the post count. The frame's
/// growth badge, "N today" and Follow have no data or feature in the app.
class SearchHashtagGridCard extends StatelessWidget {
  const SearchHashtagGridCard({
    super.key,
    required this.hashtag,
    required this.query,
  });

  final HashtagSearchResult hashtag;
  final String query;

  @override
  Widget build(BuildContext context) => DabblerCard(
    variant: DabblerCardVariant.white,
    radius: DabblerRadius.lg,
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: DabblerSpacing.space4,
      vertical: DabblerSpacing.space5,
    ),
    onTap: () => context.pushNamed(
      RouteNames.hashtagFeed,
      pathParameters: {'slug': hashtag.slug},
      queryParameters: {'postCount': '${hashtag.postCount}'},
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DabblerSpacing.space3,
      children: [
        const DabblerIconTile.named(
          'hashtag',
          weight: DabblerIconWeight.bold,
          tone: DabblerIconTileTone.sunken,
          size: DabblerSizing.iconXl,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DabblerHighlightedText(
              text: '\u2066#${hashtag.slug}\u2069',
              query: searchNeedle(query),
              style: DabblerType.footnote,
              fontWeight: DabblerHighlightedText.matchWeight,
              maxLines: 1,
            ),
            DabblerText(
              AppLocalizations.of(context).sfx_posts_count(hashtag.postCount),
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ),
      ],
    ),
  );
}

/// A leading tile + a title line + a meta line, with an optional trailing
/// block — the games / venues / meet-ups card (`Search.dc.html:260-293`).
class SearchTileCard extends StatelessWidget {
  const SearchTileCard({
    super.key,
    required this.icon,
    required this.title,
    required this.query,
    this.meta,
    this.trailing,
    this.onTap,
  });

  final String icon;
  final String title;
  final String query;
  final Widget? meta;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SearchResultCard(
    onTap: onTap,
    child: Row(
      spacing: DabblerSpacing.space4,
      children: [
        DabblerIconTile.named(
          icon,
          weight: DabblerIconWeight.bold,
          tone: DabblerIconTileTone.sunken,
          size: DabblerSizing.tileSm,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DabblerSpacing.space1,
            children: [
              DabblerHighlightedText(
                text: title,
                query: searchNeedle(query),
                style: DabblerType.subheadline,
                fontWeight: DabblerHighlightedText.matchWeight,
                maxLines: 1,
              ),
              ?meta,
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class SearchGameCard extends StatelessWidget {
  const SearchGameCard({super.key, required this.game, required this.query});

  final GameModel game;
  final String query;

  @override
  Widget build(BuildContext context) {
    final spots = game.maxPlayers > 0
        ? '${game.currentPlayers}/${game.maxPlayers}'
        : '—';
    return SearchTileCard(
      icon: 'game',
      title: game.title,
      query: query,
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
      meta: Row(
        spacing: DabblerSpacing.space2,
        children: [
          DabblerBadge(label: game.sport, tone: DabblerBadgeTone.warning),
          Expanded(
            child: DabblerText(
              _formatWhen(game.scheduledDate),
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DabblerText(
            spots,
            style: DabblerType.subheadline,
            tone: DabblerTextTone.brand,
            weight: DabblerTextWeight.bold,
          ),
          DabblerText(
            AppLocalizations.of(context).sfx_spots,
            style: DabblerType.caption2,
            tone: DabblerTextTone.secondary,
          ),
        ],
      ),
    );
  }
}

class SearchVenueCard extends StatelessWidget {
  const SearchVenueCard({super.key, required this.venue, required this.query});

  final Venue venue;
  final String query;

  @override
  Widget build(BuildContext context) => SearchTileCard(
    icon: 'buildings',
    title: venue.name,
    query: query,
    meta: venue.address == null
        ? null
        : DabblerText(
            venue.address!,
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
  );
}

class SearchMeetupCard extends StatelessWidget {
  const SearchMeetupCard({
    super.key,
    required this.meetup,
    required this.query,
  });

  final MeetupSearchResult meetup;
  final String query;

  @override
  Widget build(BuildContext context) => SearchTileCard(
    icon: 'calendar',
    title: meetup.title,
    query: query,
    meta: meetup.startAt == null
        ? null
        : DabblerText(
            _formatWhen(meetup.startAt!),
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
          ),
  );
}

class SearchPostCard extends StatelessWidget {
  const SearchPostCard({super.key, required this.post, required this.query});

  final PostSearchResult post;
  final String query;

  @override
  Widget build(BuildContext context) => SearchResultCard(
    onTap: () => context.push('${RoutePaths.socialPostDetail}/${post.id}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DabblerSpacing.space2,
      children: [
        Row(
          spacing: DabblerSpacing.space3,
          children: [
            DabblerAvatar(
              seed: post.authorDisplayName ?? post.id,
              size: DabblerAvatarSize.sm,
            ),
            Expanded(
              child: DabblerText(
                post.authorDisplayName ?? 'Post',
                style: DabblerType.subheadline,
                weight: DabblerTextWeight.semibold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        DabblerHighlightedText(
          text: post.body,
          query: searchNeedle(query),
          style: DabblerType.subheadline,
          maxLines: 3,
        ),
      ],
    ),
  );
}

/// A post as a flat row of `View_all_posts` (`Search.dc.html`): avatar, author
/// and age on one line, the body with the match highlighted, a hairline under.
class SearchPostRow extends StatelessWidget {
  const SearchPostRow({super.key, required this.post, required this.query});

  final PostSearchResult post;
  final String query;

  @override
  Widget build(BuildContext context) {
    final created = post.createdAt;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('${RoutePaths.socialPostDetail}/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DabblerSpacing.space5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DabblerSpacing.space4,
            children: [
              DabblerAvatar(
                seed: post.authorDisplayName ?? post.id,
                size: DabblerAvatarSize.sm,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DabblerSpacing.space2,
                  children: [
                    Row(
                      spacing: DabblerSpacing.space2,
                      children: [
                        Flexible(
                          child: DabblerText(
                            post.authorDisplayName ?? '',
                            style: DabblerType.footnote,
                            weight: DabblerTextWeight.semibold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (created != null) ...[
                          const DabblerText(
                            '\u00b7',
                            style: DabblerType.caption1,
                            tone: DabblerTextTone.secondary,
                          ),
                          DabblerText(
                            homeRelativeTime(created),
                            style: DabblerType.caption1,
                            tone: DabblerTextTone.secondary,
                          ),
                        ],
                      ],
                    ),
                    DabblerHighlightedText(
                      text: post.body,
                      query: searchNeedle(query),
                      style: DabblerType.subheadline,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DabblerSpacing.space5),
          const DabblerDivider(),
        ],
      ),
    );
  }
}

class SearchCommentCard extends StatelessWidget {
  const SearchCommentCard({
    super.key,
    required this.comment,
    required this.query,
  });

  final CommentSearchResult comment;
  final String query;

  @override
  Widget build(BuildContext context) => SearchResultCard(
    onTap: () =>
        context.push('${RoutePaths.socialPostDetail}/${comment.postId}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DabblerSpacing.space1,
      children: [
        DabblerHighlightedText(
          text: comment.snippet,
          query: searchNeedle(query),
          style: DabblerType.subheadline,
          maxLines: 3,
        ),
        if (comment.postTitle != null)
          Row(
            spacing: DabblerSpacing.space2,
            children: [
              const DabblerIcon('message-text', size: DabblerSizing.iconXs),
              Expanded(
                child: DabblerText(
                  AppLocalizations.of(context).sfx_on_post(comment.postTitle!),
                  style: DabblerType.caption1,
                  tone: DabblerTextTone.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

/// A game as the events row of `View_all_events` (date tile, kind, Join). The
/// card and Join both open the game.
class SearchGameEventCard extends StatelessWidget {
  const SearchGameEventCard({
    super.key,
    required this.game,
    required this.query,
  });

  final GameModel game;
  final String query;

  @override
  Widget build(BuildContext context) {
    final d = game.scheduledDate;
    void open() => context.push(RoutePaths.gameDetail(game.id));
    return DabblerCardEventResult(
      month: DateFormat('MMM').format(d),
      day: DateFormat('d').format(d),
      kind: AppLocalizations.of(context).sfx_kind_game,
      kindIcon: 'game',
      time: _formatWhen(d),
      title: game.title,
      query: searchNeedle(query),
      place: (game.venueName ?? '').isEmpty ? null : game.venueName,
      meta: game.maxPlayers > 0
          ? AppLocalizations.of(
              context,
            ).sfx_spots_meta(game.currentPlayers, game.maxPlayers)
          : null,
      actionLabel: AppLocalizations.of(context).sfx_join,
      onAction: open,
      onTap: open,
    );
  }
}

/// A meet-up as the events row of `View_all_events`. The app has no RSVP or
/// meet-up detail route, so it carries no action.
class SearchMeetupEventCard extends StatelessWidget {
  const SearchMeetupEventCard({
    super.key,
    required this.meetup,
    required this.query,
  });

  final MeetupSearchResult meetup;
  final String query;

  @override
  Widget build(BuildContext context) {
    final d = meetup.startAt;
    return DabblerCardEventResult(
      month: d == null ? '' : DateFormat('MMM').format(d),
      day: d == null ? '' : DateFormat('d').format(d),
      kind: AppLocalizations.of(context).sfx_kind_meetup,
      kindIcon: 'calendar',
      time: d == null ? '' : _formatWhen(d),
      title: meetup.title,
      query: searchNeedle(query),
    );
  }
}

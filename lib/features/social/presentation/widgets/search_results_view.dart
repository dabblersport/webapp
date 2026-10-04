import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/search_cards.dart';

const EdgeInsetsDirectional _gutter = EdgeInsetsDirectional.fromSTEB(
  DabblerSpacing.space6,
  DabblerSpacing.space5,
  DabblerSpacing.space6,
  DabblerSpacing.space10,
);

/// The results area: the sectioned overview for [SearchMode.all]
/// (`Search_results`), or one section as a full list (`View_all_*`).
class SearchResultsView extends StatelessWidget {
  const SearchResultsView({
    super.key,
    required this.state,
    required this.mode,
    required this.onViewAll,
    required this.onProfileTap,
  });

  final SearchState state;
  final SearchMode mode;
  final ValueChanged<SearchMode> onViewAll;
  final ValueChanged<Profile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    if (state.error != null && !state.hasResults) {
      return Center(child: DabblerEmptyState.error(title: state.error!));
    }
    if (!state.hasResults && !state.isLoading) {
      return Center(
        child: DabblerEmptyState(
          icon: 'search-normal',
          title: 'No results for "${state.query}"',
          size: DabblerEmptyStateSize.page,
        ),
      );
    }
    if (!state.hasResults) {
      return ListView(
        padding: _gutter,
        children: const [
          DabblerSkeleton.card(),
          SizedBox(height: DabblerSpacing.space3),
          DabblerSkeleton.text(),
        ],
      );
    }
    return mode == SearchMode.all
        ? _Overview(
            state: state,
            onViewAll: onViewAll,
            onProfileTap: onProfileTap,
          )
        : _FullList(state: state, mode: mode, onProfileTap: onProfileTap);
  }
}

String _modeLabel(SearchMode mode) => switch (mode) {
  SearchMode.profiles => 'people',
  SearchMode.hashtags => 'hashtags',
  SearchMode.games => 'games',
  SearchMode.venues => 'venues',
  SearchMode.posts => 'posts',
  SearchMode.comments => 'comments',
  SearchMode.meetups => 'meet-ups',
  SearchMode.all => 'results',
};

class _Overview extends StatelessWidget {
  const _Overview({
    required this.state,
    required this.onViewAll,
    required this.onProfileTap,
  });

  final SearchState state;
  final ValueChanged<SearchMode> onViewAll;
  final ValueChanged<Profile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final b = state.bundle;
    final q = state.query;

    Widget section(
      String title,
      String icon,
      SearchMode mode,
      Widget content,
    ) => DabblerSection(
      compact: true,
      icon: icon,
      title: title,
      action: DabblerTextLink(
        label: 'View all',
        underline: false,
        trailingIcon: 'arrow-circle-right',
        onPressed: () => onViewAll(mode),
      ),
      children: [content],
    );

    Widget stack(List<Widget> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DabblerSpacing.space3,
      children: rows,
    );

    return ListView(
      padding: _gutter,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DabblerSpacing.space8,
          children: [
            DabblerCard(
              variant: DabblerCardVariant.outlined,
              radius: DabblerRadius.lg,
              padding: const EdgeInsets.symmetric(
                horizontal: DabblerSpacing.space5,
                vertical: DabblerSpacing.space4,
              ),
              child: Row(
                spacing: DabblerSpacing.space3,
                children: [
                  const DabblerIcon(
                    'search-normal',
                    size: DabblerSizing.iconXs,
                  ),
                  Expanded(
                    child: DabblerText.rich(
                      [
                        const DabblerTextSpan('Showing results for '),
                        DabblerTextSpan(
                          '"$q"',
                          tone: DabblerTextTone.brand,
                          weight: DabblerTextWeight.semibold,
                        ),
                      ],
                      style: DabblerType.footnote,
                      tone: DabblerTextTone.secondary,
                    ),
                  ),
                  DabblerText(
                    '~${b.totalCount}',
                    style: DabblerType.footnote,
                    weight: DabblerTextWeight.semibold,
                  ),
                ],
              ),
            ),
            if (b.profiles.isNotEmpty)
              section(
                'People',
                'people',
                SearchMode.profiles,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DabblerSpacing.space3,
                      children: [
                        for (final p in b.profiles.take(8))
                          SearchPersonCard(
                            profile: p,
                            query: q,
                            onTap: () => onProfileTap(p),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (b.hashtags.isNotEmpty)
              section(
                'Hashtags',
                'hashtag',
                SearchMode.hashtags,
                Wrap(
                  spacing: DabblerSpacing.space3,
                  runSpacing: DabblerSpacing.space3,
                  children: [
                    for (final h in b.hashtags.take(8))
                      SearchHashtagCard(hashtag: h, query: q),
                  ],
                ),
              ),
            if (b.games.isNotEmpty)
              section(
                'Games',
                'game',
                SearchMode.games,
                stack([
                  for (final g in b.games.take(3))
                    SearchGameCard(game: g, query: q),
                ]),
              ),
            if (b.venues.isNotEmpty)
              section(
                'Venues',
                'buildings',
                SearchMode.venues,
                stack([
                  for (final v in b.venues.take(8))
                    SearchVenueCard(venue: v, query: q),
                ]),
              ),
            if (b.posts.isNotEmpty)
              section(
                'Posts',
                'message-text',
                SearchMode.posts,
                stack([
                  for (final p in b.posts.take(3))
                    SearchPostCard(post: p, query: q),
                ]),
              ),
            if (b.comments.isNotEmpty)
              section(
                'Comments',
                'sms',
                SearchMode.comments,
                stack([
                  for (final c in b.comments.take(3))
                    SearchCommentCard(comment: c, query: q),
                ]),
              ),
            if (b.meetups.isNotEmpty)
              section(
                'Meet-ups',
                'calendar',
                SearchMode.meetups,
                stack([
                  for (final m in b.meetups.take(3))
                    SearchMeetupCard(meetup: m, query: q),
                ]),
              ),
          ],
        ),
      ],
    );
  }
}

class _FullList extends StatelessWidget {
  const _FullList({
    required this.state,
    required this.mode,
    required this.onProfileTap,
  });

  final SearchState state;
  final SearchMode mode;
  final ValueChanged<Profile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final b = state.bundle;
    final q = state.query;
    final List<Widget> rows = switch (mode) {
      SearchMode.profiles => [
        for (final p in b.profiles)
          SearchPersonRow(profile: p, query: q, onTap: () => onProfileTap(p)),
      ],
      SearchMode.hashtags => [
        Wrap(
          spacing: DabblerSpacing.space3,
          runSpacing: DabblerSpacing.space3,
          children: [
            for (final h in b.hashtags) SearchHashtagCard(hashtag: h, query: q),
          ],
        ),
      ],
      SearchMode.games => [
        for (final g in b.games) SearchGameCard(game: g, query: q),
      ],
      SearchMode.venues => [
        for (final v in b.venues) SearchVenueCard(venue: v, query: q),
      ],
      SearchMode.posts => [
        for (final p in b.posts) SearchPostCard(post: p, query: q),
      ],
      SearchMode.comments => [
        for (final c in b.comments) SearchCommentCard(comment: c, query: q),
      ],
      SearchMode.meetups => [
        for (final m in b.meetups) SearchMeetupCard(meetup: m, query: q),
      ],
      SearchMode.all => const [],
    };
    final label = _modeLabel(mode);
    if (rows.isEmpty || (mode == SearchMode.hashtags && b.hashtags.isEmpty)) {
      return Center(
        child: DabblerEmptyState(
          icon: 'search-normal',
          title: 'No $label found',
        ),
      );
    }
    final count = rows.length == 1 && mode == SearchMode.hashtags
        ? b.hashtags.length
        : rows.length;
    return ListView(
      padding: _gutter,
      children: [
        DabblerText(
          '$count $label for "$q"',
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        const SizedBox(height: DabblerSpacing.space5),
        if (mode == SearchMode.profiles)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DabblerSpacing.space3,
            children: rows,
          ),
      ],
    );
  }
}

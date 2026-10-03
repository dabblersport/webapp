import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/search/comment_search_result.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/providers/search_history_provider.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

// =============================================================================
// Search tabs — order MUST match SearchNotifier._tabIndexForMode.
//   0 → All, 1 → People, 2 → Posts, 3 → Games, 4 → Venues,
//   5 → Comments, 6 → Hashtags, 7 → Meetups
// =============================================================================

class SearchTab {
  final String key;
  final String label;

  /// Design-system icon name (kebab-case, see [DabblerIcon]).
  final String icon;
  const SearchTab({required this.key, required this.label, required this.icon});
}

const List<SearchTab> _kSearchTabs = [
  SearchTab(key: 'all', label: 'All', icon: 'search-normal'),
  SearchTab(key: 'people', label: 'People', icon: 'people'),
  SearchTab(key: 'posts', label: 'Posts', icon: 'message'),
  SearchTab(key: 'games', label: 'Games', icon: 'game'),
  SearchTab(key: 'venues', label: 'Venues', icon: 'buildings'),
  SearchTab(key: 'comments', label: 'Comments', icon: 'messages-2'),
  SearchTab(key: 'hashtags', label: 'Hashtags', icon: 'hashtag'),
  SearchTab(key: 'meetups', label: 'Meet-ups', icon: 'calendar'),
];

/// Strips the search grammar (`@`, `#`, `/g `…) so only the typed words are
/// highlighted — same cleaning the screen always applied.
String _needle(String query) => query
    .trim()
    .replaceAll(RegExp(r'^[@#]'), '')
    .replaceAll(RegExp(r'^/[a-z]\s*'), '')
    .trim();

/// The row title with every typed-word match highlighted, as the
/// pre-migration result tiles did (`_HighlightedText`).
InlineSpan _hl(BuildContext context, String text, String query) =>
    DabblerInputRow.highlightSpan(
      text,
      _needle(query),
      DabblerColors.of(context),
    );

const EdgeInsetsDirectional _gutter = EdgeInsetsDirectional.symmetric(
  horizontal: DabblerSpacing.space6,
);

/// Social search screen — empty / results / view-all states.
class SocialSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? searchType;

  const SocialSearchScreen({super.key, this.initialQuery, this.searchType});

  @override
  ConsumerState<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends ConsumerState<SocialSearchScreen> {
  late TextEditingController _searchController;
  late int _tabIndex;

  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  /// When non-null, the screen is in "View all" drilldown mode for that
  /// section. Tapping back clears it.
  SearchMode? _viewAllMode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');

    final initialTabIndex = widget.searchType != null
        ? _kSearchTabs.indexWhere((t) => t.key == widget.searchType)
        : 0;
    _tabIndex = initialTabIndex.clamp(0, _kSearchTabs.length - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _triggerSearch(widget.initialQuery!);
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search helpers
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(DabblerMotion.debounceSearch, () {
      _triggerSearch(query.trim());
    });
  }

  void _triggerSearch(String query) {
    if (query.isEmpty) {
      ref.read(searchProvider.notifier).clear();
      return;
    }
    ref.read(recentSearchHistoryProvider.notifier).add(query);
    ref.read(searchProvider.notifier).search(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clear();
    _searchFocus.requestFocus();
  }

  void _maybeAutoSwitchTab(SearchState state) {
    final idx = state.forcedTabIndex;
    if (idx >= 0 && idx < _kSearchTabs.length && _tabIndex != idx) {
      setState(() => _tabIndex = idx);
    }
  }

  void _openViewAll(SearchMode mode) => setState(() => _viewAllMode = mode);

  void _closeViewAll() => setState(() => _viewAllMode = null);

  // ---------------------------------------------------------------------------
  // Build — one layout at every width.
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final recentSearches = ref.watch(recentSearchHistoryProvider);

    ref.listen<SearchState>(searchProvider, (_, next) {
      _maybeAutoSwitchTab(next);
    });

    if (_viewAllMode != null) {
      return _ViewAllScreen(
        mode: _viewAllMode!,
        query: searchState.query,
        state: searchState,
        onBack: _closeViewAll,
        onProfileTap: _navigateToSearchProfile,
      );
    }

    final tab = _kSearchTabs[_tabIndex];
    final hint = _tabIndex == 0
        ? 'Search people, games, posts…'
        : 'Search ${tab.label.toLowerCase()}…';
    final hasQuery = searchState.query.isNotEmpty;

    return DabblerPage(
      topBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerNavigationTopBar.titled(onBack: () => context.pop()),
          Padding(
            padding: _gutter,
            child: DabblerSearchField(
              controller: _searchController,
              focusNode: _searchFocus,
              placeholder: hint,
              onChanged: _onSearchChanged,
              onSubmitted: _triggerSearch,
              onCleared: _clearSearch,
            ),
          ),
          if (hasQuery)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: DabblerSpacing.space2,
              ),
              child: DabblerTabs(
                scrollable: true,
                value: tab.key,
                onChanged: (k) => setState(
                  () => _tabIndex = _kSearchTabs.indexWhere((t) => t.key == k),
                ),
                items: [
                  for (final t in _kSearchTabs)
                    DabblerTabItem(
                      id: t.key,
                      label: t.label,
                      icon: DabblerIcon(t.icon, size: DabblerSizing.iconInline),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: DabblerSpacing.space3),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: hasQuery
                ? _ResultsRouter(
                    state: searchState,
                    tabIndex: _tabIndex,
                    onViewAll: _openViewAll,
                    onProfileTap: _navigateToSearchProfile,
                  )
                : _EmptyState(
                    recentSearches: recentSearches,
                    onPickRecent: (q) {
                      _searchController.text = q;
                      _triggerSearch(q);
                    },
                    onRemoveRecent: (q) => ref
                        .read(recentSearchHistoryProvider.notifier)
                        .remove(q),
                    onClearRecent: () =>
                        ref.read(recentSearchHistoryProvider.notifier).clear(),
                    onTapGrammar: (prefix) {
                      _searchController.text = prefix;
                      _searchController.selection = TextSelection.collapsed(
                        offset: prefix.length,
                      );
                      _searchFocus.requestFocus();
                    },
                  ),
          ),
          if (searchState.isLoading) const _SearchingIndicator(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile navigation
  // ---------------------------------------------------------------------------

  Future<void> _navigateToSearchProfile(Profile profile) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final myProfileId = await ref.read(myProfileIdProvider.future);
    if (!mounted) return;
    if (profile.userId == currentUserId && profile.id == myProfileId) {
      context.go(RoutePaths.profile);
    } else {
      context.push(
        '${RoutePaths.userProfile}/${profile.userId}?profileId=${profile.id}',
      );
    }
  }
}

class _SearchingIndicator extends StatelessWidget {
  const _SearchingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Positioned(
      top: DabblerSpacing.space4,
      left: 0,
      right: 0,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(DabblerRadius.pill),
            border: Border.all(color: colors.borderDefault),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space4,
              vertical: DabblerSpacing.space2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DabblerSpinner(size: DabblerSpinnerSize.sm),
                const SizedBox(width: DabblerSpacing.space2),
                const DabblerText(
                  'Searching…',
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                  weight: DabblerTextWeight.semibold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EMPTY STATE — recent / shortcuts / grammar / quick filters
// Static placeholders for suggestions until backend RPCs land.
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.recentSearches,
    required this.onPickRecent,
    required this.onRemoveRecent,
    required this.onClearRecent,
    required this.onTapGrammar,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onPickRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onTapGrammar;

  static const _grammar = [
    (tag: '@', label: 'people', icon: 'user'),
    (tag: '#', label: 'hashtags', icon: 'hashtag'),
    (tag: '/g', label: 'games', icon: 'game'),
    (tag: '/v', label: 'venues', icon: 'location'),
    (tag: '/p', label: 'posts', icon: 'document-text'),
    (tag: '/c', label: 'comments', icon: 'message'),
    (tag: '/m', label: 'meetups', icon: 'calendar'),
  ];

  static const _filters = [
    (label: 'Near me', icon: 'location', active: true),
    (label: 'Today', icon: 'clock', active: false),
    (label: 'This week', icon: '', active: false),
    (label: 'Friends only', icon: '', active: false),
    (label: 'Popular', icon: '', active: false),
    (label: 'Free entry', icon: '', active: false),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    Widget section(DabblerSection s) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space5,
        DabblerSpacing.space6,
        0,
      ),
      child: s,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space11),
      children: [
        if (recentSearches.isNotEmpty)
          section(
            DabblerSection(
              title: 'Recent',
              action: DabblerButton(
                label: 'Clear',
                tone: DabblerButtonTone.text,
                size: DabblerButtonSize.small,
                onPressed: onClearRecent,
              ),
              children: [
                Wrap(
                  spacing: DabblerSpacing.space2,
                  runSpacing: DabblerSpacing.space2,
                  children: [
                    for (final q in recentSearches)
                      _RecentItem(
                        query: q,
                        onTap: () => onPickRecent(q),
                        onRemove: () => onRemoveRecent(q),
                      ),
                  ],
                ),
              ],
            ),
          ),
        section(
          DabblerSection(
            children: [
              for (final c in const [
                (
                  icon: 'people',
                  title: 'People nearby',
                  sub: 'Find players near you',
                ),
                (icon: 'game', title: 'Popular games', sub: 'Open spots today'),
                (
                  icon: 'activity',
                  title: 'Trending posts',
                  sub: 'What everyone’s on',
                ),
              ])
                DabblerInputRow(
                  leading: DabblerIcon(
                    c.icon,
                    size: DabblerSizing.iconMd,
                    color: colors.brandPrimary,
                  ),
                  title: c.title,
                  subtitle: c.sub,
                  trailing: const DabblerChevron(),
                ),
            ],
          ),
        ),
        section(
          DabblerSection(
            title: 'SEARCH SMARTER',
            children: [
              Wrap(
                spacing: DabblerSpacing.space2,
                runSpacing: DabblerSpacing.space2,
                children: [
                  for (final g in _grammar)
                    DabblerChip(
                      label: 'Search ${g.label}',
                      leadingIcon: DabblerIcon(
                        g.icon,
                        size: DabblerSizing.iconInline,
                      ),
                      onTap: () => onTapGrammar(
                        g.tag == '@' || g.tag == '#' ? g.tag : '${g.tag} ',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        section(
          DabblerSection(
            title: 'QUICK FILTERS',
            children: [
              Wrap(
                spacing: DabblerSpacing.space2,
                runSpacing: DabblerSpacing.space2,
                children: [
                  for (final f in _filters)
                    DabblerChip(
                      label: f.label,
                      selected: f.active,
                      leadingIcon: f.icon.isEmpty
                          ? null
                          : DabblerIcon(f.icon, size: DabblerSizing.iconInline),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A recent query: the chip searches it, the trailing close removes it.
class _RecentItem extends StatelessWidget {
  const _RecentItem({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DabblerChip(
      key: ValueKey('recent-$query'),
      label: query,
      leadingIcon: const DabblerIcon('clock', size: DabblerSizing.iconInline),
      onTap: onTap,
      onRemove: onRemove,
      removeSemanticLabel: 'Remove $query',
    );
  }
}

// =============================================================================
// RESULTS ROUTER — All tab → sectioned scroll, specific tab → full list
// =============================================================================

class _ResultsRouter extends StatelessWidget {
  const _ResultsRouter({
    required this.state,
    required this.tabIndex,
    required this.onViewAll,
    required this.onProfileTap,
  });

  final SearchState state;
  final int tabIndex;
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
      return const _ResultsSkeleton();
    }

    final b = state.bundle;
    final q = state.query;
    switch (tabIndex) {
      case 1:
        return _ResultList(
          empty: 'No people found',
          children: [
            for (final p in b.profiles)
              _PersonRow(profile: p, query: q, onTap: () => onProfileTap(p)),
          ],
        );
      case 2:
        return _ResultList(
          empty: 'No posts found',
          children: [for (final p in b.posts) _PostTile(post: p, query: q)],
        );
      case 3:
        return _ResultList(
          empty: 'No games found',
          children: [for (final g in b.games) _GameRow(game: g, query: q)],
        );
      case 4:
        return _ResultList(
          empty: 'No venues found',
          children: [for (final v in b.venues) _VenueRow(venue: v, query: q)],
        );
      case 5:
        return _ResultList(
          empty: 'No comments found',
          children: [
            for (final c in b.comments) _CommentTile(comment: c, query: q),
          ],
        );
      case 6:
        return _ResultList(
          empty: 'No hashtags found',
          children: _rankedHashtags(context, b.hashtags, q),
        );
      case 7:
        return _ResultList(
          empty: 'No meetups found',
          children: [
            for (final m in b.meetups) _MeetupRow(meetup: m, query: q),
          ],
        );
      default:
        return _AllTabSections(
          state: state,
          onViewAll: onViewAll,
          onProfileTap: onProfileTap,
        );
    }
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.all(DabblerSpacing.space6),
      children: const [
        DabblerSkeleton.card(),
        SizedBox(height: DabblerSpacing.space3),
        DabblerSkeleton.text(),
      ],
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.empty, required this.children});
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Center(
        child: DabblerEmptyState(icon: 'search-normal', title: empty),
      );
    }
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space4,
        DabblerSpacing.space6,
        DabblerSpacing.space11,
      ),
      itemCount: children.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: DabblerSpacing.space2),
      itemBuilder: (_, i) => children[i],
    );
  }
}

List<Widget> _rankedHashtags(
  BuildContext context,
  List<HashtagSearchResult> hashtags,
  String query,
) {
  return [
    for (var i = 0; i < hashtags.length; i++)
      _HashtagRow(
        hashtag: hashtags[i],
        query: query,
        leading: SizedBox(
          width: DabblerSpacing.space8,
          child: DabblerText(
            '${i + 1}',
            textAlign: TextAlign.center,
            style: DabblerType.headline,
            tone: DabblerTextTone.secondary,
            weight: DabblerTextWeight.heavy,
          ),
        ),
      ),
  ];
}

// =============================================================================
// ALL TAB — sectioned previews with View all actions
// =============================================================================

class _AllTabSections extends StatelessWidget {
  const _AllTabSections({
    required this.state,
    required this.onViewAll,
    required this.onProfileTap,
  });

  final SearchState state;
  final ValueChanged<SearchMode> onViewAll;
  final ValueChanged<Profile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final b = state.bundle;
    final q = state.query;

    Widget section(String title, SearchMode mode, List<Widget> rows) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space5,
        DabblerSpacing.space6,
        0,
      ),
      child: DabblerSection(
        title: title,
        action: DabblerButton(
          label: 'View all',
          tone: DabblerButtonTone.text,
          size: DabblerButtonSize.small,
          onPressed: () => onViewAll(mode),
        ),
        children: rows,
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space11),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space6,
            DabblerSpacing.space4,
            DabblerSpacing.space6,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: DabblerText.rich([
                  const DabblerTextSpan('Showing results for '),
                  DabblerTextSpan(
                    '"$q"',
                    tone: DabblerTextTone.brand,
                    weight: DabblerTextWeight.semibold,
                  ),
                ], style: DabblerType.footnote),
              ),
              DabblerText(
                '~${b.totalCount}',
                style: DabblerType.caption1,
                tone: DabblerTextTone.secondary,
                weight: DabblerTextWeight.semibold,
              ),
            ],
          ),
        ),
        if (b.profiles.isNotEmpty)
          section('People', SearchMode.profiles, [
            for (final p in b.profiles.take(8))
              _PersonRow(profile: p, query: q, onTap: () => onProfileTap(p)),
          ]),
        if (b.hashtags.isNotEmpty)
          section('Hashtags', SearchMode.hashtags, [
            for (final h in b.hashtags.take(8))
              _HashtagRow(
                hashtag: h,
                query: q,
                leading: DabblerIcon(
                  'hashtag',
                  size: DabblerSizing.iconRow,
                  color: colors.brandPrimary,
                ),
              ),
          ]),
        if (b.games.isNotEmpty)
          section('Games', SearchMode.games, [
            for (final g in b.games.take(3)) _GameRow(game: g, query: q),
          ]),
        if (b.venues.isNotEmpty)
          section('Venues', SearchMode.venues, [
            for (final v in b.venues.take(8)) _VenueRow(venue: v, query: q),
          ]),
        if (b.posts.isNotEmpty)
          section('Posts', SearchMode.posts, [
            for (final p in b.posts.take(3)) _PostTile(post: p, query: q),
          ]),
        if (b.comments.isNotEmpty)
          section('Comments', SearchMode.comments, [
            for (final c in b.comments.take(3))
              _CommentTile(comment: c, query: q),
          ]),
        if (b.meetups.isNotEmpty)
          section('Meet-ups', SearchMode.meetups, [
            for (final m in b.meetups.take(3)) _MeetupRow(meetup: m, query: q),
          ]),
      ],
    );
  }
}

// =============================================================================
// RESULT ROWS
// =============================================================================

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.profile,
    required this.query,
    required this.onTap,
  });
  final Profile profile;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DabblerInputRow(
      leading: DabblerAvatar(
        seed: profile.id,
        imageUrl: profile.avatarUrl,
        size: DabblerAvatarSize.sm,
      ),
      titleSpan: _hl(context, profile.displayName, query),
      subtitle: '@${profile.username}',
      trailing: DabblerButton(
        label: 'Follow',
        size: DabblerButtonSize.small,
        onPressed: onTap,
      ),
      onTap: onTap,
    );
  }
}

class _HashtagRow extends StatelessWidget {
  const _HashtagRow({
    required this.hashtag,
    required this.query,
    required this.leading,
  });
  final HashtagSearchResult hashtag;
  final String query;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return DabblerInputRow(
      leading: leading,
      titleSpan: _hl(context, '#${hashtag.slug}', query),
      subtitle: '${hashtag.postCount} posts',
      trailing: const DabblerChevron(),
      onTap: () => context.pushNamed(
        RouteNames.hashtagFeed,
        pathParameters: {'slug': hashtag.slug},
        queryParameters: {'postCount': '${hashtag.postCount}'},
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.query});
  final GameModel game;
  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final spotsText = game.maxPlayers > 0
        ? '${game.currentPlayers}/${game.maxPlayers}'
        : '—';
    return DabblerInputRow(
      leading: DabblerSportIcon.fromKey(
        game.sport.toLowerCase(),
        size: DabblerSizing.iconMd,
        color: colors.brandPrimary,
      ),
      titleSpan: _hl(context, game.title, query),
      subtitle: [
        game.sport,
        if ((game.venueName ?? '').isNotEmpty) game.venueName!,
        _formatGameWhen(game.scheduledDate),
      ].join(' · '),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DabblerText(
            spotsText,
            style: DabblerType.subheadline,
            weight: DabblerTextWeight.heavy,
          ),
          const DabblerText(
            'spots',
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
          ),
        ],
      ),
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venue, required this.query});
  final Venue venue;
  final String query;

  @override
  Widget build(BuildContext context) {
    return DabblerInputRow(
      leading: DabblerIcon(
        'buildings',
        size: DabblerSizing.iconMd,
        color: DabblerColors.of(context).brandPrimary,
      ),
      titleSpan: _hl(context, venue.name, query),
      subtitle: venue.address,
    );
  }
}

class _MeetupRow extends StatelessWidget {
  const _MeetupRow({required this.meetup, required this.query});
  final MeetupSearchResult meetup;
  final String query;

  @override
  Widget build(BuildContext context) {
    return DabblerInputRow(
      leading: DabblerIcon(
        'calendar',
        size: DabblerSizing.iconMd,
        color: DabblerColors.of(context).brandPrimary,
      ),
      titleSpan: _hl(context, meetup.title, query),
      subtitle: meetup.startAt != null
          ? _formatGameWhen(meetup.startAt!)
          : null,
      trailing: const DabblerBadge(label: 'RSVP'),
    );
  }
}

/// A text result (post body / comment snippet) with the match highlighted.
/// `PostSearchResult` is not a feed `Post`, so `resolvePostLayout` cannot
/// take it (DS gap recorded in the KAN-417 report).
class _TextResult extends StatelessWidget {
  const _TextResult({
    required this.header,
    required this.text,
    required this.query,
    required this.onTap,
  });
  final Widget header;
  final String text;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(DabblerRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space5,
            vertical: DabblerSpacing.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: DabblerSpacing.space2),
              DabblerHighlightedText(
                text: text,
                query: _needle(query),
                style: DabblerType.subheadline,
                color: colors.textSecondary,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.query});
  final PostSearchResult post;
  final String query;

  @override
  Widget build(BuildContext context) {
    return _TextResult(
      text: post.body,
      query: query,
      onTap: () => context.push('${RoutePaths.socialPostDetail}/${post.id}'),
      header: Row(
        children: [
          DabblerAvatar(
            seed: post.authorDisplayName ?? post.id,
            size: DabblerAvatarSize.xs,
          ),
          const SizedBox(width: DabblerSpacing.space3),
          Expanded(
            child: DabblerText(
              post.authorDisplayName ?? 'Post',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DabblerType.footnote,
              weight: DabblerTextWeight.bold,
            ),
          ),
          if (post.createdAt != null)
            DabblerText(
              _relativeTime(post.createdAt!),
              style: DabblerType.caption1,
              tone: DabblerTextTone.tertiary,
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.query});
  final CommentSearchResult comment;
  final String query;

  @override
  Widget build(BuildContext context) {
    return _TextResult(
      text: comment.snippet,
      query: query,
      onTap: () =>
          context.push('${RoutePaths.socialPostDetail}/${comment.postId}'),
      header: comment.postTitle == null
          ? const SizedBox.shrink()
          : DabblerText.rich(
              [
                const DabblerTextSpan('on '),
                DabblerTextSpan(
                  comment.postTitle!,
                  tone: DabblerTextTone.brand,
                  weight: DabblerTextWeight.semibold,
                ),
              ],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DabblerType.caption1,
              tone: DabblerTextTone.secondary,
            ),
    );
  }
}

String _formatGameWhen(DateTime dt) {
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

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(dt);
}

// =============================================================================
// VIEW ALL — drilled-in single-section screen with sort sub-tabs
// =============================================================================

class _ViewAllScreen extends StatefulWidget {
  const _ViewAllScreen({
    required this.mode,
    required this.query,
    required this.state,
    required this.onBack,
    required this.onProfileTap,
  });
  final SearchMode mode;
  final String query;
  final SearchState state;
  final VoidCallback onBack;
  final ValueChanged<Profile> onProfileTap;

  @override
  State<_ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<_ViewAllScreen> {
  String _sort = 'top';

  static const _sorts = ['top', 'recent', 'popular'];

  @override
  Widget build(BuildContext context) {
    final label = _modeLabel(widget.mode);
    final count = _itemCount();

    return DabblerPage(
      topBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerNavigationTopBar.titled(
            title: 'All $label for "${widget.query}"',
            onBack: widget.onBack,
          ),
          DabblerTabs(
            value: _sort,
            onChanged: (k) => setState(() => _sort = k),
            items: [
              for (final k in _sorts)
                DabblerTabItem(
                  id: k,
                  label: k[0].toUpperCase() + k.substring(1),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space6,
              DabblerSpacing.space4,
              DabblerSpacing.space6,
              DabblerSpacing.space1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DabblerText.rich(
                    [
                      DabblerTextSpan(
                        '$count ',
                        tone: DabblerTextTone.primary,
                        weight: DabblerTextWeight.heavy,
                      ),
                      DabblerTextSpan('$label · sorted by $_sort'),
                    ],
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                  ),
                ),
                const DabblerBadge(label: 'Trending only'),
              ],
            ),
          ),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  int _itemCount() {
    final b = widget.state.bundle;
    switch (widget.mode) {
      case SearchMode.profiles:
        return b.profiles.length;
      case SearchMode.posts:
        return b.posts.length;
      case SearchMode.games:
        return b.games.length;
      case SearchMode.venues:
        return b.venues.length;
      case SearchMode.comments:
        return b.comments.length;
      case SearchMode.hashtags:
        return b.hashtags.length;
      case SearchMode.meetups:
        return b.meetups.length;
      case SearchMode.all:
        return b.totalCount;
    }
  }

  Widget _buildList(BuildContext context) {
    final b = widget.state.bundle;
    final q = widget.query;
    switch (widget.mode) {
      case SearchMode.hashtags:
        return _ResultList(
          empty: 'No hashtags found',
          children: [
            ..._rankedHashtags(context, b.hashtags, q),
            if (b.hashtags.isNotEmpty)
              const DabblerButton(
                label: 'Load more',
                tone: DabblerButtonTone.outlined,
                fullWidth: true,
              ),
          ],
        );
      case SearchMode.profiles:
        return _ResultList(
          empty: 'No people found',
          children: [
            for (final p in b.profiles)
              _PersonRow(
                profile: p,
                query: q,
                onTap: () => widget.onProfileTap(p),
              ),
          ],
        );
      case SearchMode.games:
        return _ResultList(
          empty: 'No games found',
          children: [for (final g in b.games) _GameRow(game: g, query: q)],
        );
      case SearchMode.venues:
        return _ResultList(
          empty: 'No venues found',
          children: [for (final v in b.venues) _VenueRow(venue: v, query: q)],
        );
      case SearchMode.posts:
        return _ResultList(
          empty: 'No posts found',
          children: [for (final p in b.posts) _PostTile(post: p, query: q)],
        );
      case SearchMode.comments:
        return _ResultList(
          empty: 'No comments found',
          children: [
            for (final c in b.comments) _CommentTile(comment: c, query: q),
          ],
        );
      case SearchMode.meetups:
        return _ResultList(
          empty: 'No meetups found',
          children: [
            for (final m in b.meetups) _MeetupRow(meetup: m, query: q),
          ],
        );
      case SearchMode.all:
        return const SizedBox.shrink();
    }
  }
}

String _modeLabel(SearchMode mode) {
  switch (mode) {
    case SearchMode.profiles:
      return 'people';
    case SearchMode.hashtags:
      return 'hashtags';
    case SearchMode.games:
      return 'games';
    case SearchMode.venues:
      return 'venues';
    case SearchMode.posts:
      return 'posts';
    case SearchMode.comments:
      return 'comments';
    case SearchMode.meetups:
      return 'meet-ups';
    case SearchMode.all:
      return 'results';
  }
}

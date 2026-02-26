import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/search/comment_search_result.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Social search screen — powered by rpc_unified_search_sectioned.
///
/// Tab order (must stay in sync with [SearchNotifier._tabIndexForMode]):
///   0 → All
///   1 → People
///   2 → Posts
///   3 → Games
///   4 → Venues
///   5 → Comments
///   6 → Hashtags
///   7 → Meetups
class SocialSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? searchType;

  const SocialSearchScreen({super.key, this.initialQuery, this.searchType});

  @override
  ConsumerState<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends ConsumerState<SocialSearchScreen>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late TabController _tabController;

  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  static const List<SearchTab> _searchTabs = [
    SearchTab(key: 'all', label: 'All', icon: Icons.search),
    SearchTab(key: 'people', label: 'People', icon: Icons.group),
    SearchTab(key: 'posts', label: 'Posts', icon: Icons.chat_bubble_outline),
    SearchTab(key: 'games', label: 'Games', icon: Icons.sports_esports),
    SearchTab(key: 'venues', label: 'Venues', icon: Icons.location_city),
    SearchTab(key: 'comments', label: 'Comments', icon: Icons.comment_outlined),
    SearchTab(key: 'hashtags', label: 'Hashtags', icon: Icons.tag),
    SearchTab(key: 'meetups', label: 'Meetups', icon: Icons.event_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');

    final initialTabIndex = widget.searchType != null
        ? _searchTabs.indexWhere((t) => t.key == widget.searchType)
        : 0;

    _tabController = TabController(
      length: _searchTabs.length,
      vsync: this,
      initialIndex: initialTabIndex.clamp(0, _searchTabs.length - 1),
    );

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
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search helpers
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _triggerSearch(query.trim());
    });
  }

  void _triggerSearch(String query) {
    if (query.isEmpty) {
      ref.read(searchProvider.notifier).clear();
      return;
    }
    ref.read(searchProvider.notifier).search(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clear();
    _searchFocus.requestFocus();
  }

  /// Auto-switch the tab when the notifier sets a [forcedTabIndex].
  void _maybeAutoSwitchTab(SearchState state) {
    final idx = state.forcedTabIndex;
    if (idx >= 0 && idx < _searchTabs.length && _tabController.index != idx) {
      _tabController.animateTo(idx);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(searchProvider);

    // Auto-switch tab whenever forcedTabIndex changes.
    ref.listen<SearchState>(searchProvider, (_, next) {
      _maybeAutoSwitchTab(next);
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            onSubmitted: _triggerSearch,
            decoration: InputDecoration(
              hintText: _buildHintText(),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: searchState.query.isNotEmpty
                  ? IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _searchTabs
              .map(
                (tab) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(tab.label),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: Column(
        children: [
          if (searchState.query.isEmpty)
            Expanded(child: _buildRecentAndSuggestions()),
          if (searchState.query.isNotEmpty)
            Expanded(child: _buildSearchResults(searchState)),
        ],
      ),
    );
  }

  String _buildHintText() {
    final tab = _searchTabs[_tabController.index];
    return 'Search ${tab.label.toLowerCase()}... (@, #, /g, /v, /p, /c, /m)';
  }

  // ---------------------------------------------------------------------------
  // Empty-state: recent & suggestions
  // ---------------------------------------------------------------------------

  Widget _buildRecentAndSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('Suggestions', [
            _buildSuggestionItem('People nearby', Icons.group),
            _buildSuggestionItem('Popular games today', Icons.sports_esports),
            _buildSuggestionItem('Trending posts', Icons.trending_up),
          ]),
          const SizedBox(height: 16),
          _buildPrefixHelp(),
          const SizedBox(height: 24),
          _buildQuickFilters(),
        ],
      ),
    );
  }

  /// Hint card showing supported prefix grammar.
  Widget _buildPrefixHelp() {
    final theme = Theme.of(context);
    final hints = [
      ('@username', 'Search people'),
      ('#tag', 'Search hashtags'),
      ('/g query', 'Search games'),
      ('/v query', 'Search venues'),
      ('/p query', 'Search posts'),
      ('/c query', 'Search comments'),
      ('/m query', 'Search meetups'),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Grammar',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: hints
                  .map(
                    (h) => ActionChip(
                      label: Text(
                        '${h.$1}  ${h.$2}',
                        style: theme.textTheme.bodySmall,
                      ),
                      onPressed: () {
                        _searchController.text = h.$1;
                        _searchController.selection =
                            TextSelection.fromPosition(
                              TextPosition(offset: h.$1.length),
                            );
                        _onSearchChanged(h.$1);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search results
  // ---------------------------------------------------------------------------

  Widget _buildSearchResults(SearchState searchState) {
    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null && !searchState.hasResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              searchState.error!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _triggerSearch(searchState.query),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!searchState.hasResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No results for "${searchState.query}"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final b = searchState.bundle;
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAllTab(searchState),
        _buildPeopleList(b.profiles),
        _buildPostsList(b.posts),
        _buildGamesList(b.games),
        _buildVenuesList(b.venues),
        _buildCommentsList(b.comments),
        _buildHashtagsList(b.hashtags),
        _buildMeetupsList(b.meetups),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // "All" tab — sectioned preview
  // ---------------------------------------------------------------------------

  Widget _buildAllTab(SearchState s) {
    final b = s.bundle;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (b.profiles.isNotEmpty) ...[
          _sectionHeader('People', b.profiles.length),
          ...b.profiles.take(3).map(_buildProfileTile),
          const SizedBox(height: 16),
        ],
        if (b.posts.isNotEmpty) ...[
          _sectionHeader('Posts', b.posts.length),
          ...b.posts.take(3).map(_buildPostTile),
          const SizedBox(height: 16),
        ],
        if (b.games.isNotEmpty) ...[
          _sectionHeader('Games', b.games.length),
          ...b.games.take(3).map(_buildGameTile),
          const SizedBox(height: 16),
        ],
        if (b.venues.isNotEmpty) ...[
          _sectionHeader('Venues', b.venues.length),
          ...b.venues.take(3).map(_buildVenueTile),
          const SizedBox(height: 16),
        ],
        if (b.comments.isNotEmpty) ...[
          _sectionHeader('Comments', b.comments.length),
          ...b.comments.take(3).map(_buildCommentTile),
          const SizedBox(height: 16),
        ],
        if (b.hashtags.isNotEmpty) ...[
          _sectionHeader('Hashtags', b.hashtags.length),
          ...b.hashtags.take(3).map(_buildHashtagTile),
          const SizedBox(height: 16),
        ],
        if (b.meetups.isNotEmpty) ...[
          _sectionHeader('Meetups', b.meetups.length),
          ...b.meetups.take(3).map(_buildMeetupTile),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Individual tab lists
  // ---------------------------------------------------------------------------

  Widget _buildPeopleList(List<Profile> profiles) {
    if (profiles.isEmpty) return _emptyTab('No people found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: profiles.length,
      itemBuilder: (_, i) => _buildProfileTile(profiles[i]),
    );
  }

  Widget _buildPostsList(List<PostSearchResult> posts) {
    if (posts.isEmpty) return _emptyTab('No posts found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (_, i) => _buildPostTile(posts[i]),
    );
  }

  Widget _buildGamesList(List<GameModel> games) {
    if (games.isEmpty) return _emptyTab('No games found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: games.length,
      itemBuilder: (_, i) => _buildGameTile(games[i]),
    );
  }

  Widget _buildVenuesList(List<Venue> venues) {
    if (venues.isEmpty) return _emptyTab('No venues found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: venues.length,
      itemBuilder: (_, i) => _buildVenueTile(venues[i]),
    );
  }

  Widget _buildCommentsList(List<CommentSearchResult> comments) {
    if (comments.isEmpty) return _emptyTab('No comments found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: comments.length,
      itemBuilder: (_, i) => _buildCommentTile(comments[i]),
    );
  }

  Widget _buildHashtagsList(List<HashtagSearchResult> hashtags) {
    if (hashtags.isEmpty) return _emptyTab('No hashtags found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hashtags.length,
      itemBuilder: (_, i) => _buildHashtagTile(hashtags[i]),
    );
  }

  Widget _buildMeetupsList(List<MeetupSearchResult> meetups) {
    if (meetups.isEmpty) return _emptyTab('No meetups found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetups.length,
      itemBuilder: (_, i) => _buildMeetupTile(meetups[i]),
    );
  }

  Widget _emptyTab(String message) {
    return Center(
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  // ---------------------------------------------------------------------------
  // Result tiles
  // ---------------------------------------------------------------------------

  Widget _buildProfileTile(Profile profile) {
    final resolvedAvatar = resolveAvatarUrl(profile.avatarUrl);
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: resolvedAvatar != null
            ? NetworkImage(resolvedAvatar)
            : null,
        child: resolvedAvatar == null
            ? Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : '?',
              )
            : null,
      ),
      title: Text(profile.displayName),
      subtitle: Text('@${profile.username}'),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => _navigateToSearchProfile(profile),
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Navigate to a profile from search results.
  /// Own **active** profile → ProfileScreen; everyone else → UserProfileScreen.
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

  Widget _buildPostTile(PostSearchResult post) {
    final body = post.body;
    final snippet = body.length > 80 ? '${body.substring(0, 80)}…' : body;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.article_outlined),
        title: Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: post.createdAt != null
            ? Text(_formatDate(post.createdAt!))
            : null,
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push('${RoutePaths.socialPostDetail}/${post.id}'),
      ),
    );
  }

  Widget _buildGameTile(GameModel game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.sports, size: 20),
        ),
        title: Text(game.title),
        subtitle: Text('${game.sport} · ${_formatDate(game.scheduledDate)}'),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push('${RoutePaths.games}/${game.id}'),
      ),
    );
  }

  Widget _buildVenueTile(Venue venue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          child: const Icon(Icons.location_on_outlined, size: 20),
        ),
        title: Text(venue.name),
        subtitle: venue.address != null ? Text(venue.address!) : null,
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () {
          // TODO(router): navigate to venue detail when route exists.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${venue.name} — venue detail coming soon')),
          );
        },
      ),
    );
  }

  /// Comment result tile.
  ///
  /// Navigates to the parent post. GoRouter does not support anchor fragments
  /// (#comment-id), so the post detail screen receives only the post ID.
  Widget _buildCommentTile(CommentSearchResult comment) {
    final snippet = comment.snippet.length > 80
        ? '${comment.snippet.substring(0, 80)}…'
        : comment.snippet;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: const Icon(Icons.comment_outlined, size: 20),
        ),
        title: Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          comment.postTitle != null ? 'On: ${comment.postTitle}' : 'View post',
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () =>
            context.push('${RoutePaths.socialPostDetail}/${comment.postId}'),
      ),
    );
  }

  /// Hashtag result tile.
  ///
  /// TODO(router): add /hashtag/:slug route when ready.
  Widget _buildHashtagTile(HashtagSearchResult hashtag) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        child: const Icon(Icons.tag, size: 20),
      ),
      title: Text('#${hashtag.slug}'),
      subtitle: Text('${hashtag.postCount} posts'),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        // TODO(router): context.push('/hashtag/${hashtag.slug}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('#${hashtag.slug} — hashtag feed coming soon'),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildMeetupTile(MeetupSearchResult meetup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.event_outlined, size: 20),
        ),
        title: Text(meetup.title),
        subtitle: meetup.startAt != null
            ? Text(_formatDate(meetup.startAt!))
            : null,
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () {
          // TODO(router): navigate to meetup detail when route exists.
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSuggestionItem(String text, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(text),
      trailing: const Icon(Icons.north_east, size: 16),
      onTap: () {
        _searchController.text = text;
        _triggerSearch(text);
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildQuickFilters() {
    const filters = [
      'Near me',
      'Today',
      'This week',
      'Friends only',
      'Popular',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Filters',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters
              .map((f) => FilterChip(label: Text(f), onSelected: (_) {}))
              .toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class SearchTab {
  final String key;
  final String label;
  final IconData icon;

  const SearchTab({required this.key, required this.label, required this.icon});
}

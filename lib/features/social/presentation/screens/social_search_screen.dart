import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/post.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Social search screen with global search capabilities
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

  final List<SearchTab> _searchTabs = const [
    SearchTab(key: 'all', label: 'All', icon: Icons.search),
    SearchTab(key: 'people', label: 'People', icon: Icons.group),
    SearchTab(key: 'posts', label: 'Posts', icon: Icons.chat_bubble_outline),
    SearchTab(key: 'games', label: 'Games', icon: Icons.sports_esports),
    SearchTab(key: 'venues', label: 'Venues', icon: Icons.location_city),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');

    final initialTabIndex = widget.searchType != null
        ? _searchTabs.indexWhere((tab) => tab.key == widget.searchType)
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(searchProvider);

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
              hintText:
                  'Search ${_searchTabs[_tabController.index].label.toLowerCase()}...',
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
          const SizedBox(height: 24),
          _buildQuickFilters(),
        ],
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

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAllTab(searchState),
        _buildPeopleList(searchState.profiles),
        _buildPostsList(searchState.posts),
        _buildGamesList(searchState.games),
        _buildVenuesList(searchState.venues),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // "All" tab — shows a mixed preview from each category
  // ---------------------------------------------------------------------------

  Widget _buildAllTab(SearchState s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (s.profiles.isNotEmpty) ...[
          _sectionHeader('People', s.profiles.length),
          ...s.profiles.take(3).map(_buildProfileTile),
          const SizedBox(height: 16),
        ],
        if (s.posts.isNotEmpty) ...[
          _sectionHeader('Posts', s.posts.length),
          ...s.posts.take(3).map(_buildPostTile),
          const SizedBox(height: 16),
        ],
        if (s.games.isNotEmpty) ...[
          _sectionHeader('Games', s.games.length),
          ...s.games.take(3).map(_buildGameTile),
          const SizedBox(height: 16),
        ],
        if (s.venues.isNotEmpty) ...[
          _sectionHeader('Venues', s.venues.length),
          ...s.venues.take(3).map(_buildVenueTile),
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

  Widget _buildPostsList(List<Post> posts) {
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

  Widget _emptyTab(String message) {
    return Center(
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  // ---------------------------------------------------------------------------
  // Result tiles
  // ---------------------------------------------------------------------------

  Widget _buildProfileTile(Profile profile) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile.avatarUrl != null
            ? NetworkImage(profile.avatarUrl!)
            : null,
        child: profile.avatarUrl == null
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
      onTap: () => context.push('${RoutePaths.userProfile}/${profile.userId}'),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPostTile(Post post) {
    final body = post.body ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.article_outlined),
        title: Text(
          body.length > 80 ? '${body.substring(0, 80)}…' : body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_formatDate(post.createdAt)),
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
        onTap: () {},
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

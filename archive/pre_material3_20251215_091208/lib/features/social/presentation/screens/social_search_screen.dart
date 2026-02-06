import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  String _currentQuery = '';

  final List<SearchTab> _searchTabs = [
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
    _currentQuery = widget.initialQuery ?? '';

    final initialTabIndex = widget.searchType != null
        ? _searchTabs.indexWhere((tab) => tab.key == widget.searchType)
        : 0;

    _tabController = TabController(
      length: _searchTabs.length,
      vsync: this,
      initialIndex: initialTabIndex.clamp(0, _searchTabs.length - 1),
    );

    // Auto-focus search bar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentQuery.isEmpty) {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentQuery = query.trim();
    });

    // Perform search with debouncing
    _performSearch(query.trim());
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
    });
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            onSubmitted: _performSearch,
            decoration: InputDecoration(
              hintText:
                  'Search ${_searchTabs[_tabController.index].label.toLowerCase()}...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _currentQuery.isNotEmpty
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
          // Recent searches and suggestions when no query
          if (_currentQuery.isEmpty)
            Expanded(child: _buildRecentAndSuggestions()),

          // Search results when query exists
          if (_currentQuery.isNotEmpty) Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildRecentAndSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          _buildSection('Recent Searches', [
            _buildRecentSearchItem('John Doe', Icons.person),
            _buildRecentSearchItem('Basketball game', Icons.sports_esports),
            _buildRecentSearchItem('Central Park Courts', Icons.location_city),
          ]),
          const SizedBox(height: 24),

          // Suggested searches
          _buildSection('Suggestions', [
            _buildSuggestionItem('People nearby', Icons.group),
            _buildSuggestionItem('Popular games today', Icons.sports_esports),
            _buildSuggestionItem('Trending posts', Icons.trending_up),
          ]),
          const SizedBox(height: 24),

          // Quick filters
          _buildQuickFilters(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return TabBarView(
      controller: _tabController,
      children: _searchTabs.map((tab) => _buildTabContent(tab.key)).toList(),
    );
  }

  Widget _buildTabContent(String tabKey) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Results header
          Row(
            children: [
              Text(
                'Results for "$_currentQuery"',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 16),
                label: const Text('Filter'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Placeholder results
          ...List.generate(5, (index) => _buildResultItem(tabKey, index)),
        ],
      ),
    );
  }

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

  Widget _buildRecentSearchItem(String text, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.grey),
      title: Text(text),
      trailing: IconButton(
        onPressed: () {
          // Remove from recent searches
        },
        icon: const Icon(Icons.close, size: 16),
      ),
      onTap: () {
        _searchController.text = text;
        _onSearchChanged(text);
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSuggestionItem(String text, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(text),
      trailing: const Icon(Icons.north_east, size: 16),
      onTap: () {
        _searchController.text = text;
        _onSearchChanged(text);
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildQuickFilters() {
    final filters = [
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
              .map(
                (filter) =>
                    FilterChip(label: Text(filter), onSelected: (selected) {}),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResultItem(String tabKey, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text('${index + 1}'),
        ),
        title: Text('$tabKey Result ${index + 1}'),
        subtitle: Text('Sample subtitle for $_currentQuery'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to result detail
          switch (tabKey) {
            case 'people':
              context.push('/social/profile/user${index + 1}');
              break;
            case 'posts':
              context.push('/social/post/post${index + 1}');
              break;
            case 'games':
              context.push('/games/game${index + 1}');
              break;
            case 'venues':
              context.push('/venues/venue${index + 1}');
              break;
          }
        },
      ),
    );
  }
}

class SearchTab {
  final String key;
  final String label;
  final IconData icon;

  const SearchTab({required this.key, required this.label, required this.icon});
}

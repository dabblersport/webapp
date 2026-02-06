import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/data/models/rewards/leaderboard_entry.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/tier.dart';
import '../../domain/repositories/rewards_repository.dart';
import '../controllers/leaderboard_controller.dart';
import '../providers/rewards_providers.dart';
import '../widgets/leaderboard_filters.dart';
import '../widgets/leaderboards/leaderboard_item.dart';
import '../widgets/podium_widget.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _podiumAnimationController;
  late AnimationController _listAnimationController;
  late TabController _tabController;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  // Tab indices for leaderboard types
  static const int _globalTab = 0;
  static const int _friendsTab = 1;
  static const int _localTab = 2;
  static const int _sportTab = 3;

  // Time range options
  final List<TimeFrame> _timeRanges = [
    TimeFrame.today,
    TimeFrame.thisWeek,
    TimeFrame.thisMonth,
    TimeFrame.allTime,
  ];

  int _selectedTimeRangeIndex = 3; // Default to All-time
  bool _showFilters = false;
  final bool _showUserRankOnly = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();

    // Initialize leaderboard data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLeaderboard();
    });
  }

  void _setupAnimations() {
    _podiumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreEntries();
      }
    });
  }

  @override
  void dispose() {
    _podiumAnimationController.dispose();
    _listAnimationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardState = ref.watch(leaderboardControllerProvider);

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(leaderboardState),
          SliverToBoxAdapter(child: _buildTimeRangeSelector()),
          _buildTabBar(),
          _buildTabContent(leaderboardState),
        ],
      ),
      floatingActionButton: _buildFloatingActions(leaderboardState),
    );
  }

  Widget _buildSliverAppBar(LeaderboardState state) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: context.colors.surface,
      elevation: 0,
      surfaceTintColor: context.colors.surface,
      leading: IconButton(
        icon: Icon(LucideIcons.arrowLeft, color: context.colors.onSurface),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerLowest,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.trophy,
                          color: Color(0xFFF59E0B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leaderboard',
                              style: context.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${state.entries.length} players competing',
                              style: context.textTheme.bodyLarge?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            if (state.userRank != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Your rank: #${state.userRank}',
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Leaderboard stats
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.outline.withValues(
                              alpha: 0.1,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.trophy,
                              color: context.colors.primary,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getSelectedTabTitle(),
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          'Leaderboard',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colors.onSurface,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_showFilters ? LucideIcons.filterX : LucideIcons.filter),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          color: context.colors.onSurface,
        ),
        PopupMenuButton<String>(
          icon: Icon(LucideIcons.moreVertical, color: context.colors.onSurface),
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _refreshLeaderboard();
                break;
              case 'share':
                _shareLeaderboard();
                break;
              case 'export':
                _exportLeaderboard();
                break;
              case 'search':
                _showSearchDialog();
                break;
              case 'my_rank':
                _scrollToUserRank();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 12),
                  Text('Refresh'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(LucideIcons.share2),
                  SizedBox(width: 12),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(LucideIcons.download),
                  SizedBox(width: 12),
                  Text('Export'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(LucideIcons.search),
                  SizedBox(width: 12),
                  Text('Search Users'),
                ],
              ),
            ),
            if (state.userRank != null)
              const PopupMenuItem(
                value: 'my_rank',
                child: Row(
                  children: [
                    Icon(LucideIcons.mapPin),
                    SizedBox(width: 12),
                    Text('Go to My Rank'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: _timeRanges.asMap().entries.map((entry) {
          final index = entry.key;
          final timeRange = entry.value;
          final isSelected = index == _selectedTimeRangeIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onTimeRangeChanged(index, timeRange),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getTimeRangeLabel(timeRange),
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? context.colors.onPrimary
                        : context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.3, end: 0);
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colors.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: context.colors.primary,
          ),
          labelColor: context.colors.onPrimary,
          unselectedLabelColor: context.colors.onSurfaceVariant,
          labelStyle: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Global'),
            Tab(text: 'Friends'),
            Tab(text: 'Local'),
            Tab(text: 'Sport'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(LeaderboardState state) {
    if (_showFilters) {
      return SliverToBoxAdapter(
        child: LeaderboardFilters(
          onFiltersChanged: _onFiltersChanged,
          onClose: () => setState(() => _showFilters = false),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.5, end: 0),
      );
    }

    if (state.isLoading && state.entries.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: context.colors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading leaderboard...',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colors.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.alertTriangle,
                size: 64,
                color: context.colors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load leaderboard',
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshLeaderboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.entries.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.trophy,
                size: 64,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No leaderboard data',
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              Text(
                'Be the first to start competing!',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Podium for top 3
        if (state.entries.length >= 3) _buildPodiumSection(state),

        // Leaderboard list
        _buildLeaderboardList(state),

        // Load more indicator
        if (state.hasMorePages)
          Container(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: state.isLoading
                  ? CircularProgressIndicator(color: context.colors.primary)
                  : ElevatedButton(
                      onPressed: _loadMoreEntries,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.surfaceContainerLowest,
                        foregroundColor: context.colors.onSurface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: context.colors.outline.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Load More'),
                    ),
            ),
          ),

        // Bottom spacing
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildPodiumSection(LeaderboardState state) {
    return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(LucideIcons.crown, color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text(
                    'Top Performers',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colors.onSurface,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              PodiumWidget(
                entries: state.entries.take(3).toList(),
                animationController: _podiumAnimationController,
                onEntryTapped: _onLeaderboardEntryTapped,
                showConfetti: true,
                showCrowns: true,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildLeaderboardList(LeaderboardState state) {
    final nonPodiumEntries = state.entries.skip(3).toList();

    if (nonPodiumEntries.isEmpty) return Container();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.entries.length >= 3) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Text(
                'Full Rankings',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
            ),
          ],

          // User's rank highlight if not in top visible entries
          if (state.userEntry != null &&
              state.userEntry!.currentRank > 10 &&
              !_showUserRankOnly)
            _buildUserRankHighlight(state.userEntry!),

          // Nearby ranks section
          if (state.userEntry != null && state.userEntry!.currentRank > 3)
            _buildNearbyRanks(state),

          // Main leaderboard list
          ...nonPodiumEntries.asMap().entries.map((entry) {
            final leaderboardEntry = entry.value;

            return LeaderboardItem(
              user: _convertEntryToUser(leaderboardEntry),
              onTap: () => _onLeaderboardEntryTapped(leaderboardEntry),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUserRankHighlight(LeaderboardEntry userEntry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPin, color: context.colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Current Rank',
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LeaderboardItem(
            user: _convertEntryToUser(userEntry),
            onTap: () => _onLeaderboardEntryTapped(userEntry),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.3, end: 0);
  }

  Widget _buildNearbyRanks(LeaderboardState state) {
    // This would show users ranked just above and below the current user
    // For now, we'll show a placeholder
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Players Near Your Rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Loading nearby players...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions(LeaderboardState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.userRank != null && state.userRank! > 10)
          FloatingActionButton(
            heroTag: "my_rank",
            onPressed: _scrollToUserRank,
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            elevation: 2,
            child: const Icon(LucideIcons.mapPin),
          ),

        const SizedBox(height: 16),

        FloatingActionButton.extended(
          heroTag: "refresh",
          onPressed: _refreshLeaderboard,
          backgroundColor: context.colors.surfaceContainerLowest,
          foregroundColor: context.colors.onSurface,
          elevation: 2,
          icon: const Icon(LucideIcons.refreshCw),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  // Helper methods and actions
  String _getSelectedTabTitle() {
    switch (_tabController.index) {
      case _globalTab:
        return 'Global\nRankings';
      case _friendsTab:
        return 'Friends\nRankings';
      case _localTab:
        return 'Local\nRankings';
      case _sportTab:
        return 'Sport\nRankings';
      default:
        return 'Rankings';
    }
  }

  String _getTimeRangeLabel(TimeFrame timeFrame) {
    switch (timeFrame) {
      case TimeFrame.today:
        return 'Today';
      case TimeFrame.thisWeek:
        return 'Week';
      case TimeFrame.thisMonth:
        return 'Month';
      case TimeFrame.thisYear:
        return 'Year';
      case TimeFrame.allTime:
        return 'All Time';
    }
  }

  void _initializeLeaderboard() {
    final controller = ref.read(leaderboardControllerProvider.notifier);
    controller.loadLeaderboard();

    // Start podium animation after data loads
    _podiumAnimationController.forward();
    _listAnimationController.forward();
  }

  void _onTabChanged(int index) {
    final leaderboardType = _getLeaderboardTypeFromTab(index);
    ref
        .read(leaderboardControllerProvider.notifier)
        .changeLeaderboardType(leaderboardType);

    // Reset animations
    _podiumAnimationController.reset();
    _listAnimationController.reset();
    _podiumAnimationController.forward();
    _listAnimationController.forward();
  }

  void _onTimeRangeChanged(int index, TimeFrame timeFrame) {
    setState(() {
      _selectedTimeRangeIndex = index;
    });

    ref.read(leaderboardControllerProvider.notifier).changeTimeFrame(timeFrame);
  }

  LeaderboardType _getLeaderboardTypeFromTab(int tabIndex) {
    switch (tabIndex) {
      case _globalTab:
        return LeaderboardType.overall;
      case _friendsTab:
        return LeaderboardType.friends;
      case _localTab:
        return LeaderboardType.friends;
      case _sportTab:
        return LeaderboardType.sport;
      default:
        return LeaderboardType.overall;
    }
  }

  void _onFiltersChanged(Map<String, dynamic> filters) {
    // Apply filters would be handled through state changes
    setState(() {
      _showFilters = false;
    });
  }

  void _onLeaderboardEntryTapped(LeaderboardEntry entry) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.username} - ${entry.getFormattedRank()}'),
        backgroundColor: context.colors.primary,
      ),
    );
  }

  void _loadMoreEntries() {
    ref.read(leaderboardControllerProvider.notifier).loadMoreEntries();
  }

  Future<void> _refreshLeaderboard() async {
    HapticFeedback.mediumImpact();
    _refreshIndicatorKey.currentState?.show();

    await ref.read(leaderboardControllerProvider.notifier).loadLeaderboard();

    // Reset animations
    _podiumAnimationController.reset();
    _listAnimationController.reset();

    // Restart animations after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _podiumAnimationController.forward();
      _listAnimationController.forward();
    });
  }

  void _shareLeaderboard() {
    final state = ref.read(leaderboardControllerProvider);
    final timeRange = _getTimeRangeLabel(_timeRanges[_selectedTimeRangeIndex]);
    final tabTitle = _getSelectedTabTitle().replaceAll('\n', ' ');

    String shareText = 'Check out the $tabTitle ($timeRange) in Dabbler!';

    if (state.userRank != null) {
      shareText += ' I\'m currently ranked #${state.userRank}!';
    }

    Share.share(shareText);
  }

  void _exportLeaderboard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Users'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter username...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (query) {
            ref
                .read(leaderboardControllerProvider.notifier)
                .updateSearchQuery(query);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _scrollToUserRank() {
    final state = ref.read(leaderboardControllerProvider);
    if (state.userRank != null) {
      // Calculate approximate scroll position
      final userRankIndex = state.userRank! - 1;
      final itemHeight = 80.0; // Approximate height of each list item
      final podiumHeight = state.entries.length >= 3 ? 300.0 : 0.0;
      final headerHeight = 200.0;

      final scrollPosition =
          headerHeight + podiumHeight + (userRankIndex * itemHeight);

      _scrollController.animateTo(
        scrollPosition.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      HapticFeedback.lightImpact();
    }
  }

  String _getCurrentUserId() {
    return 'current_user_id';
  }

  LeaderboardUser _convertEntryToUser(LeaderboardEntry entry) {
    return LeaderboardUser(
      id: entry.userId,
      username: entry.username,
      displayName: entry.username, // Using username as displayName for now
      avatarUrl: entry.avatarUrl,
      points: entry.totalPoints.toInt(),
      tier: _convertTierLevelToBadgeTier(entry.tier),
      rank: entry.currentRank,
      previousRank: entry.previousRank,
      achievements: const [],
      isFriend: false,
      isCurrentUser: entry.userId == _getCurrentUserId(),
      lastActive: entry.lastActiveAt,
      weeklyPoints: 0,
      monthlyPoints: 0,
      pointsPerDay: 0.0,
    );
  }

  BadgeTier _convertTierLevelToBadgeTier(TierLevel tierLevel) {
    // Map TierLevel to BadgeTier based on progression
    switch (tierLevel) {
      case TierLevel.freshPlayer:
      case TierLevel.rookie:
      case TierLevel.novice:
        return BadgeTier.bronze;
      case TierLevel.amateur:
      case TierLevel.enthusiast:
      case TierLevel.competitor:
        return BadgeTier.silver;
      case TierLevel.skilled:
      case TierLevel.expert:
      case TierLevel.veteran:
        return BadgeTier.gold;
      case TierLevel.elite:
      case TierLevel.master:
      case TierLevel.grandmaster:
        return BadgeTier.platinum;
      case TierLevel.legend:
      case TierLevel.champion:
      case TierLevel.dabbler:
        return BadgeTier.diamond;
    }
  }
}

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_feed_controller.dart'
    show ActivityFeedState;
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/presentation/widgets/activity_event_card.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';

/// **Activities Screen** - RPC-based Activity Feed
///
/// **Features:**
/// - Fetches data exclusively via rpc_get_activity_feed RPC
/// - Period filtering: All, Upcoming, Present, Past
/// - Cursor-based pagination
/// - Analytics tracking for user interactions
/// - Empty states, loading states, and error handling
/// - Future-proof: handles unknown subject types gracefully
///
/// Built from the design system only. No design frame exists for this screen:
/// it keeps its structure (titled bar, category chip rail, time-bucket
/// sections of activity rows) with design-system defaults.
class ActivitiesScreenV2 extends ConsumerStatefulWidget {
  const ActivitiesScreenV2({super.key});

  @override
  ConsumerState<ActivitiesScreenV2> createState() => _ActivitiesScreenV2State();
}

class _ActivitiesScreenV2State extends ConsumerState<ActivitiesScreenV2> {
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  bool _hasTrackedTabOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _authService.getCurrentUser();
      if (user != null) {
        // Load initial activities (all periods)
        ref.read(activityFeedControllerProvider.notifier).loadActivities('all');

        // Track analytics
        _trackTabOpened();
      }
    });

    // Set up scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls near the bottom (80% of scroll extent)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final state = ref.read(activityFeedControllerProvider);
      if (!state.isLoadingMore && state.hasMore && state.error == null) {
        ref.read(activityFeedControllerProvider.notifier).loadMore();
      }
    }
  }

  Future<void> _trackTabOpened() async {
    if (_hasTrackedTabOpened) return;
    _hasTrackedTabOpened = true;

    final analytics = ref.read(activityAnalyticsDatasourceProvider);
    await analytics.trackActivityTabOpened(source: 'bottom_nav');
  }

  Future<void> _handleItemTap(ActivityFeedEvent event) async {
    final analytics = ref.read(activityAnalyticsDatasourceProvider);
    await analytics.trackActivityItemClicked(
      subjectType: event.subjectType,
      verb: event.verb,
      timeBucket: event.timeBucket,
    );

    // TODO: Navigate to detail screen based on subject_type and subject_id
    // For now, we just track the analytics
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'All Activities',
        onBack: () => context.go('/home'),
      ),
      body: user == null
          ? _buildSignInPrompt(context)
          : DabblerRefresh(
              onRefresh: () async {
                await ref
                    .read(activityFeedControllerProvider.notifier)
                    .refresh();
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Category Filter Chips
                  const DabblerGap.sliver(DabblerSpacing.space4),
                  SliverPadding(
                    padding: DabblerInsets.screen,
                    sliver: SliverToBoxAdapter(
                      child: _buildCategoryFilters(context),
                    ),
                  ),
                  // Activities List
                  SliverPadding(
                    padding: DabblerInsets.screen,
                    sliver: _buildActivitiesList(context),
                  ),
                  const DabblerGap.sliver(DabblerSpacing.floatingBarClearance),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryFilters(BuildContext context) {
    final state = ref.watch(activityFeedControllerProvider);

    final categories = <Map<String, String?>>[
      {'name': 'All', 'value': null},
      {'name': 'Games', 'value': 'Games'},
      {'name': 'Booking', 'value': 'Booking'},
      {'name': 'Community', 'value': 'Community'},
      {'name': 'Payment', 'value': 'Payment'},
      {'name': 'Rewards', 'value': 'Rewards'},
    ];

    return DabblerChipRail(
      size: DabblerChipSize.small,
      items: [
        for (final category in categories)
          _categoryItem(state, category['name']!, category['value']),
      ],
    );
  }

  DabblerChipRailItem _categoryItem(
    ActivityFeedState state,
    String name,
    String? value,
  ) {
    final isSelected = state.currentCategory == value;
    // Count activities for this category
    final count = value == null
        ? state.activities.length
        : _getCategoryCount(state.activities, value);
    return DabblerChipRailItem(
      label: name,
      count: count > 0 ? '$count' : null,
      selected: isSelected,
      onTap: () {
        if (!isSelected) {
          ref
              .read(activityFeedControllerProvider.notifier)
              .changeCategory(value);
        }
      },
    );
  }

  int _getCategoryCount(List<ActivityFeedEvent> activities, String category) {
    final categoryMap = {
      'Games': 'game',
      'Booking': 'booking',
      'Community': 'social',
      'Payment': 'payment',
      'Rewards': 'reward',
    };

    final subjectType = categoryMap[category];
    if (subjectType == null) return 0;

    return activities
        .where((activity) => activity.subjectType == subjectType)
        .length;
  }

  Widget _buildActivitiesList(BuildContext context) {
    final state = ref.watch(activityFeedControllerProvider);

    // Loading state (initial load)
    if (state.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: DabblerSpinner(label: 'Loading activities...')),
      );
    }

    // Error state
    if (state.error != null && state.activities.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(context, state.error!),
      );
    }

    // Empty state
    if (state.activities.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(context, state.currentPeriod),
      );
    }

    // Get filtered activities based on category
    final filteredActivities = state.filteredActivities;

    // Empty state after filtering
    if (filteredActivities.isEmpty && state.activities.isNotEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyFilteredState(
          context,
          state.currentCategory ?? 'All',
        ),
      );
    }

    // Group activities by time_bucket
    final groupedActivities = _groupActivitiesByTimeBucket(filteredActivities);

    // Build list items (one section per time bucket)
    final listItems = <Widget>[];
    for (final entry in groupedActivities.entries) {
      final timeBucket = entry.key;
      final activities = entry.value;

      listItems.add(const DabblerGap.v(DabblerSpacing.space4));
      listItems.add(
        DabblerSection(
          title: _sectionTitle(timeBucket),
          children: [
            for (final event in activities)
              ActivityEventCard(
                event: event,
                onTap: () => _handleItemTap(event),
              ),
          ],
        ),
      );
    }

    // Add loading more indicator
    if (state.isLoadingMore) {
      listItems.add(const Center(child: DabblerSpinner(label: 'Loading more')));
    }

    // Add "no more items" indicator
    if (!state.hasMore && filteredActivities.isNotEmpty) {
      listItems.add(
        Center(
          child: DabblerText(
            'No more activities',
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
        ),
      );
    }

    // Build list
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < listItems.length) {
          return listItems[index];
        }
        return const SizedBox.shrink();
      }, childCount: listItems.length),
    );
  }

  Map<String, List<ActivityFeedEvent>> _groupActivitiesByTimeBucket(
    List<ActivityFeedEvent> activities,
  ) {
    final grouped = <String, List<ActivityFeedEvent>>{};

    for (final activity in activities) {
      final bucket = activity.timeBucket;
      grouped.putIfAbsent(bucket, () => []).add(activity);
    }

    // Order: upcoming, present, past
    final ordered = <String, List<ActivityFeedEvent>>{};
    if (grouped.containsKey('upcoming')) {
      ordered['upcoming'] = grouped['upcoming']!;
    }
    if (grouped.containsKey('present')) {
      ordered['present'] = grouped['present']!;
    }
    if (grouped.containsKey('past')) {
      ordered['past'] = grouped['past']!;
    }

    return ordered;
  }

  String _sectionTitle(String timeBucket) {
    switch (timeBucket) {
      case 'upcoming':
        return 'Upcoming';
      case 'present':
        return 'Present';
      case 'past':
        return 'All Activities';
      default:
        return timeBucket;
    }
  }

  Widget _buildEmptyState(BuildContext context, String period) {
    return DabblerEmptyState(
      icon: 'calendar-remove',
      title: 'No activity yet',
      text: 'Create a game to see your activity here.',
      size: DabblerEmptyStateSize.page,
      action: period == 'all'
          ? DabblerButton(
              label: 'Find Sports Games',
              icon: 'search-normal',
              onPressed: () => context.go('/sports'),
            )
          : null,
    );
  }

  Widget _buildEmptyFilteredState(BuildContext context, String category) {
    return DabblerEmptyState(
      icon: 'filter-search',
      title: 'No $category activities',
      text: 'Try selecting a different category or period.',
      size: DabblerEmptyStateSize.page,
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return DabblerEmptyState.error(
      title: 'Something went wrong',
      text: 'We couldn\'t load your activities. Please try again.',
      retryLabel: 'Retry',
      onRetry: () {
        final state = ref.read(activityFeedControllerProvider);
        ref
            .read(activityFeedControllerProvider.notifier)
            .loadActivities(state.currentPeriod);
      },
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: DabblerEmptyState(
        icon: 'user-remove',
        title: 'Sign in to view activities',
        text: 'Track your games, bookings, and more',
        size: DabblerEmptyStateSize.page,
        action: DabblerButton(
          label: 'Sign In',
          onPressed: () => context.go(RoutePaths.authWelcome),
        ),
      ),
    );
  }
}

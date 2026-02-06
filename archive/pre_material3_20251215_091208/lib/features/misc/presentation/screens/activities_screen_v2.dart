import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: user == null
            ? _buildSignInPrompt(context)
            : RefreshIndicator(
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
                    // Header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      sliver: SliverToBoxAdapter(child: _buildHeader(context)),
                    ),
                    // Category Filter Chips
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: _buildCategoryFilters(context),
                      ),
                    ),
                    // Activities List
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                      sliver: _buildActivitiesList(context),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.dashboard_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Activities',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(BuildContext context) {
    final state = ref.watch(activityFeedControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final categories = <Map<String, String?>>[
      {'name': 'All', 'value': null},
      {'name': 'Games', 'value': 'Games'},
      {'name': 'Booking', 'value': 'Booking'},
      {'name': 'Community', 'value': 'Community'},
      {'name': 'Payment', 'value': 'Payment'},
      {'name': 'Rewards', 'value': 'Rewards'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final categoryValue = category['value'];
          final isSelected = state.currentCategory == categoryValue;
          final categoryName = category['name']!;

          // Count activities for this category
          final count = categoryValue == null
              ? state.activities.length
              : _getCategoryCount(state.activities, categoryValue);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    categoryName,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.onPrimary.withOpacity(0.3)
                            : colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onSelected: (selected) {
                if (selected) {
                  ref
                      .read(activityFeedControllerProvider.notifier)
                      .changeCategory(categoryValue);
                }
              },
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHigh,
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        }).toList(),
      ),
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
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading activities...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
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

    // Build list items (headers + activities)
    final listItems = <Widget>[];
    for (final entry in groupedActivities.entries) {
      final timeBucket = entry.key;
      final activities = entry.value;

      // Add section header
      listItems.add(_buildSectionHeader(context, timeBucket));

      // Add activities for this section
      for (final event in activities) {
        listItems.add(
          ActivityEventCard(event: event, onTap: () => _handleItemTap(event)),
        );
      }
    }

    // Add loading more indicator
    if (state.isLoadingMore) {
      listItems.add(
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Add "no more items" indicator
    if (!state.hasMore && filteredActivities.isNotEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No more activities',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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

  Widget _buildSectionHeader(BuildContext context, String timeBucket) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String title;
    switch (timeBucket) {
      case 'upcoming':
        title = 'Upcoming';
        break;
      case 'present':
        title = 'Present';
        break;
      case 'past':
        title = 'All Activities';
        break;
      default:
        title = timeBucket;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String period) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final title = 'No activity yet';
    final message = 'Create a game to see your activity here.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (period == 'all') ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/sports'),
              icon: const Icon(Icons.search),
              label: const Text('Find Sports Games'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyFilteredState(BuildContext context, String category) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No $category activities',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different category or period.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t load your activities. Please try again.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final state = ref.read(activityFeedControllerProvider);
              ref
                  .read(activityFeedControllerProvider.notifier)
                  .loadActivities(state.currentPeriod);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to view activities',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your games, bookings, and more',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/phone-input'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

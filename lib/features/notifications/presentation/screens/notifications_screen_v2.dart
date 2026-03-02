import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../data/models/notification_model.dart';
import '../providers/notifications_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import '../providers/notification_center_badge_providers.dart';

class NotificationsScreenV2 extends ConsumerStatefulWidget {
  const NotificationsScreenV2({super.key});

  @override
  ConsumerState<NotificationsScreenV2> createState() =>
      _NotificationsScreenV2State();
}

class _NotificationsScreenV2State extends ConsumerState<NotificationsScreenV2> {
  final AuthService _authService = AuthService();
  String _selectedFilter = 'All';
  String _selectedTab = 'Notifications'; // 'Notifications' or 'Activity'

  @override
  void initState() {
    super.initState();

    // Load initial activity feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityFeedControllerProvider.notifier).loadActivities('all');
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.getCurrentUserId();

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications')),
      );
    }

    final notificationState = ref.watch(
      notificationsControllerProvider(userId),
    );
    final activityState = ref.watch(activityFeedControllerProvider);

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () => _selectedTab == 'Notifications'
            ? _refresh(userId)
            : _refreshActivity(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () =>
                              context.canPop() ? context.pop() : context.go('/home'),
                          icon: const Icon(Iconsax.home_copy),
                          style: IconButton.styleFrom(
                            backgroundColor: context.colorScheme.categoryActivities
                                .withValues(alpha: 0.0),
                            foregroundColor: context.colorScheme.onSurface,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTab == 'Notifications'
                                    ? 'Notifications'
                                    : 'Activity',
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: context.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () {
                            setState(() {
                              _selectedTab = _selectedTab == 'Notifications'
                                  ? 'Activity'
                                  : 'Notifications';
                              _selectedFilter = 'All';
                            });

                            if (_selectedTab == 'Activity') {
                              ref.read(lastSeenActivityAtProvider.notifier).markNow();
                            }
                          },
                          icon: Icon(
                            _selectedTab == 'Notifications'
                                ? Iconsax.activity_copy
                                : Iconsax.notification_copy,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: context.colorScheme.categoryActivities
                                .withValues(alpha: 0.0),
                            foregroundColor: context.colorScheme.onSurface,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFilterSection(
                    _selectedTab == 'Notifications' ? notificationState : null,
                    activityState,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (_selectedTab == 'Notifications')
                    _buildStatsBar(notificationState),
                  _selectedTab == 'Notifications'
                      ? _buildNotificationsList(userId, notificationState)
                      : _buildActivityList(activityState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(notificationState, activityState) {
    final activitiesScheme = context.getCategoryTheme('activities');

    final filters = _selectedTab == 'Notifications'
        ? [
            {'label': 'All', 'icon': Iconsax.archive_copy},
            {'label': 'Games', 'icon': Iconsax.game_copy},
            {'label': 'Bookings', 'icon': Iconsax.calendar_copy},
            {'label': 'Social', 'icon': Iconsax.people_copy},
            {'label': 'Achievements', 'icon': Iconsax.medal_copy},
          ]
        : [
            {'label': 'All', 'icon': Iconsax.archive_copy},
            {'label': 'Games', 'icon': Iconsax.game_copy},
            {'label': 'Booking', 'icon': Iconsax.calendar_copy},
            {'label': 'Community', 'icon': Iconsax.people_copy},
            {'label': 'Payment', 'icon': Iconsax.card_copy},
            {'label': 'Rewards', 'icon': Iconsax.star_1_copy},
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(color: Colors.transparent),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 24),
            ...filters.map((filter) {
              final isSelected = _selectedFilter == filter['label'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter['label'] as String;
                  });

                  // Update activity category filter if on Activity tab
                  if (_selectedTab == 'Activity') {
                    final category = filter['label'] == 'All'
                        ? null
                        : filter['label'] as String;
                    ref
                        .read(activityFeedControllerProvider.notifier)
                        .changeCategory(category);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activitiesScheme.primary
                        : activitiesScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? activitiesScheme.onPrimary
                            : activitiesScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        filter['label'] as String,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? activitiesScheme.onPrimary
                              : activitiesScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(state) {
    final activitiesScheme = context.getCategoryTheme('activities');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: context.colorTokens.stroke)),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.notification_status_copy,
            size: 16,
            color: activitiesScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '${state.unreadCount} unread',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorTokens.neutral,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${state.notifications.length} total',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorTokens.neutralOpacity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(String userId, state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 8),
            Text('Error: ${state.error}', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref
                  .read(notificationsControllerProvider(userId).notifier)
                  .refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyState();
    }

    // Filter notifications based on selected filter
    List<AppNotification> filteredNotifications = state.notifications;
    if (_selectedFilter != 'All') {
      filteredNotifications = state.notifications.where((n) {
        switch (_selectedFilter) {
          case 'Games':
            return n.kindKey.startsWith('game');
          case 'Bookings':
            return n.kindKey.startsWith('booking');
          case 'Social':
            return n.kindKey.startsWith('friend') ||
                n.kindKey.startsWith('social');
          case 'Achievements':
            return n.kindKey.startsWith('achievement') ||
                n.kindKey.startsWith('loyalty');
          default:
            return true;
        }
      }).toList();
    }

    return Column(
      children: [
        ...filteredNotifications.map((notification) {
          return _buildNotificationCard(userId, notification);
        }),
        if (state.hasMore)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildNotificationCard(String userId, AppNotification notification) {
    final activitiesScheme = context.getCategoryTheme('activities');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.all(6),
          leading: _getNotificationIcon(
            notification.kindKey,
            notification.priority,
          ),
          title: Text(
            notification.title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: notification.isRead
                  ? FontWeight.normal
                  : FontWeight.bold,
              color: context.colorTokens.neutral,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.body != null &&
                  notification.body!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  notification.body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorTokens.neutralOpacity,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatTime(notification.createdAt),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorTokens.neutralOpacity,
                ),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: activitiesScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: () => _handleNotificationTap(userId, notification),
        ),
        Divider(height: 1, thickness: 1, color: context.colorTokens.stroke),
      ],
    );
  }

  Widget _getNotificationIcon(String kindKey, NotifyPriority priority) {
    IconData icon;
    final activitiesScheme = context.getCategoryTheme('activities');
    final Color color = activitiesScheme.primary;

    final double bgAlpha = switch (priority) {
      NotifyPriority.urgent => 0.24,
      NotifyPriority.high => 0.18,
      _ => 0.12,
    };

    if (kindKey.startsWith('game')) {
      icon = Iconsax.game_copy;
    } else if (kindKey.startsWith('booking')) {
      icon = Iconsax.calendar_copy;
    } else if (kindKey.startsWith('friend')) {
      icon = Iconsax.user_add_copy;
    } else if (kindKey.startsWith('achievement')) {
      icon = Iconsax.medal_copy;
    } else if (kindKey.startsWith('loyalty')) {
      icon = Iconsax.card_copy;
    } else if (kindKey.startsWith('system')) {
      icon = Iconsax.warning_2_copy;
    } else {
      icon = Iconsax.notification_copy;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.notification_bing_copy,
            size: 64,
            color: context.colorTokens.neutralOpacity,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: context.textTheme.headlineSmall?.copyWith(
              color: context.colorTokens.neutral,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when something happens',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorTokens.neutralOpacity,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNotificationTap(
    String userId,
    AppNotification notification,
  ) async {
    final controller = ref.read(
      notificationsControllerProvider(userId).notifier,
    );

    // Mark as read + clicked (fire-and-forget, don't block navigation)
    if (!notification.isRead) {
      controller.markAsRead(notification.id);
    }
    controller.markClicked(notification.id);

    final route = _resolveNotificationRoute(notification);
    if (route != null && mounted) {
      context.push(route);
    }
  }

  /// Resolves the deeplink for a notification.
  ///
  /// Priority:
  ///   1. `actionRoute` (set by the trigger / backend)
  ///   2. `payload['action_route']` (fallback stored in JSONB context)
  ///   3. `kindKey` + `payload` entity ids (client-side mapping)
  String? _resolveNotificationRoute(AppNotification notification) {
    // 1. Explicit action route from DB
    final direct = notification.actionRoute;
    if (direct != null && direct.trim().isNotEmpty) return direct;

    final ctx = notification.payload;

    // 2. Embedded action_route inside context JSONB
    if (ctx != null && ctx.isNotEmpty) {
      final embedded = ctx['action_route'];
      if (embedded is String && embedded.trim().isNotEmpty) return embedded;
    }

    // 3. Kind-key + context fallback
    return _routeFromKindKey(notification.kindKey, ctx);
  }

  String? _routeFromKindKey(String kindKey, Map<String, dynamic>? ctx) {
    switch (kindKey) {
      // ── Social: post-targeted ──────────────────────────────────
      case 'social.post_liked':
      case 'social.post_commented':
      case 'social.mentioned_in_post':
        final postId =
            _ctxString(ctx, 'entity_id') ?? _ctxString(ctx, 'post_id');
        if (postId != null) return '${RoutePaths.socialPostDetail}/$postId';
        return null;

      // ── Social: comment-targeted ───────────────────────────────
      case 'social.comment_liked':
      case 'social.mentioned_in_comment':
        final postId = _ctxString(ctx, 'post_id');
        if (postId != null) return '${RoutePaths.socialPostDetail}/$postId';
        // Comment-level deep link not available; fall back to post
        final entityId = _ctxString(ctx, 'entity_id');
        if (entityId != null) return '${RoutePaths.socialPostDetail}/$entityId';
        return null;

      // ── Social: profile-targeted ───────────────────────────────
      case 'social.followed':
      case 'social.circle_joined':
        final actorId =
            _ctxString(ctx, 'actor_user_id') ??
            _ctxFirstInList(ctx, 'follower_user_ids') ??
            _ctxFirstInList(ctx, 'actor_user_ids');
        if (actorId != null) return '${RoutePaths.userProfile}/$actorId';
        return null;

      // ── Friends ────────────────────────────────────────────────
      case 'friend.requested':
        return RoutePaths.socialFriends;

      case 'friend.accepted':
        final actorId = _ctxString(ctx, 'actor_user_id');
        if (actorId != null) return '${RoutePaths.userProfile}/$actorId';
        return RoutePaths.socialFriends;

      // ── Games ──────────────────────────────────────────────────
      case 'game.invited':
      case 'game.updated':
      case 'game.join_request':
      case 'game.waitlist_promoted':
      case 'game.reminder':
        final gameId =
            _ctxString(ctx, 'entity_id') ?? _ctxString(ctx, 'game_id');
        if (gameId != null) return '${RoutePaths.games}/$gameId';
        return RoutePaths.games;

      // ── Bookings ───────────────────────────────────────────────
      case 'arena.payment_required':
        final bookingId = _ctxString(ctx, 'entity_id');
        if (bookingId != null) return '${RoutePaths.games}/$bookingId';
        return null;

      // ── Rewards ────────────────────────────────────────────────
      case 'reward.badge_awarded':
        return RoutePaths.profile;

      // ── Meetups / Squads ───────────────────────────────────────
      case 'meetup.invited':
      case 'squad.invited':
        return null; // No dedicated screen yet; mark read only

      default:
        return null;
    }
  }

  /// Safe string extraction from a nullable context map.
  String? _ctxString(Map<String, dynamic>? ctx, String key) {
    if (ctx == null) return null;
    final v = ctx[key];
    if (v == null) return null;
    final s = v is String ? v : v.toString();
    return s.trim().isNotEmpty ? s : null;
  }

  /// Extract the first element from a JSON array stored in the context map.
  /// Handles aggregated notifications where `actor_user_ids` / `follower_user_ids`
  /// are arrays instead of a single value.
  String? _ctxFirstInList(Map<String, dynamic>? ctx, String key) {
    if (ctx == null) return null;
    final v = ctx[key];
    if (v is List && v.isNotEmpty) {
      final first = v.first;
      if (first == null) return null;
      final s = first is String ? first : first.toString();
      return s.trim().isNotEmpty ? s : null;
    }
    return null;
  }

  Future<void> _refresh(String userId) async {
    await ref.read(notificationsControllerProvider(userId).notifier).refresh();
  }

  Future<void> _refreshActivity() async {
    await ref.read(activityFeedControllerProvider.notifier).refresh();
  }

  Widget _buildActivityList(activityState) {
    if (activityState.isLoading && activityState.activities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (activityState.activities.isEmpty) {
      return _buildEmptyActivityState();
    }

    final activities = activityState.filteredActivities;

    return Column(
      children: [
        ...activities.map((activity) {
          return _buildActivityCard(activity);
        }),
        if (activityState.hasMore)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityFeedEvent activity) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _getActivityIcon(activity.subjectType),
          title: Text(
            _getActivityTitle(activity),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorTokens.neutral,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                _getActivityDescription(activity),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorTokens.neutralOpacity,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _formatTime(activity.happenedAt),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorTokens.neutralOpacity,
                    ),
                  ),
                  if (activity.timeBucket != 'past') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getTimeBucketColor(
                          activity.timeBucket,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        activity.timeBucket.toUpperCase(),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: _getTimeBucketColor(activity.timeBucket),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          onTap: () => _handleActivityTap(activity),
        ),
        Divider(height: 1, thickness: 1, color: context.colorTokens.stroke),
      ],
    );
  }

  Widget _getActivityIcon(String subjectType) {
    IconData icon;
    final activitiesScheme = context.getCategoryTheme('activities');
    final color = activitiesScheme.primary;

    switch (subjectType) {
      case 'game':
        icon = Iconsax.game_copy;
        break;
      case 'booking':
        icon = Iconsax.calendar_copy;
        break;
      case 'social':
        icon = Iconsax.people_copy;
        break;
      case 'payment':
        icon = Iconsax.card_copy;
        break;
      case 'reward':
        icon = Iconsax.star_1_copy;
        break;
      default:
        icon = Iconsax.info_circle_copy;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _getActivityTitle(ActivityFeedEvent activity) {
    final payload = activity.payload ?? {};

    // Try to get a meaningful title from payload
    if (payload.containsKey('game_name')) {
      return payload['game_name'] as String;
    } else if (payload.containsKey('venue_name')) {
      return payload['venue_name'] as String;
    } else if (payload.containsKey('user_name')) {
      return payload['user_name'] as String;
    }

    // Fallback to subject type and verb
    return '${activity.subjectType.toUpperCase()} ${activity.verb}';
  }

  String _getActivityDescription(ActivityFeedEvent activity) {
    final payload = activity.payload ?? {};

    // Construct description from payload data
    final parts = <String>[];

    if (payload.containsKey('description')) {
      parts.add(payload['description'] as String);
    } else {
      // Build description from verb and subject
      parts.add(
        '${activity.verb.replaceAll('_', ' ')} ${activity.subjectType}',
      );
    }

    if (payload.containsKey('location')) {
      parts.add('at ${payload['location']}');
    }

    if (payload.containsKey('participants_count')) {
      parts.add('${payload['participants_count']} participants');
    }

    return parts.join(' • ');
  }

  Color _getTimeBucketColor(String timeBucket) {
    final activitiesScheme = context.getCategoryTheme('activities');
    switch (timeBucket) {
      case 'present':
      case 'upcoming':
        return activitiesScheme.primary;
      default:
        return context.colorTokens.neutralOpacity;
    }
  }

  void _handleActivityTap(ActivityFeedEvent activity) {
    final payload = activity.payload ?? {};

    // Navigate based on activity type
    if (payload.containsKey('action_route')) {
      context.push(payload['action_route'] as String);
    } else {
      // Default navigation based on subject type
      switch (activity.subjectType) {
        case 'game':
          context.push('/games/${activity.subjectId}');
          break;
        case 'booking':
          context.push('/bookings/${activity.subjectId}');
          break;
        case 'social':
          context.push('/profile');
          break;
      }
    }
  }

  Widget _buildEmptyActivityState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.activity_copy,
            size: 64,
            color: context.colorTokens.neutralOpacity,
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: context.textTheme.headlineSmall?.copyWith(
              color: context.colorTokens.neutral,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your activity will appear here',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorTokens.neutralOpacity,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

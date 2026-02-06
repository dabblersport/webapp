import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../data/notifications_repository.dart';
import '../providers/notifications_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/core/design_system/layouts/two_section_layout.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TwoSectionLayout(
        category: 'activities',
        topSection: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                  icon: const Icon(Iconsax.home_copy),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colorScheme.categoryActivities
                        .withValues(alpha: 0.2),
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
                        style: context.textTheme.headlineSmall?.copyWith(
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
                      _selectedFilter = 'All'; // Reset filter when switching
                    });
                  },
                  icon: Icon(
                    _selectedTab == 'Notifications'
                        ? Iconsax.activity_copy
                        : Iconsax.notification_copy,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colorScheme.categoryActivities
                        .withValues(alpha: 0.2),
                    foregroundColor: context.colorScheme.onSurface,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFilterSection(
              _selectedTab == 'Notifications' ? notificationState : null,
              activityState,
            ),
          ],
        ),
        bottomSection: Column(
          children: [
            if (_selectedTab == 'Notifications')
              _buildStatsBar(notificationState),
            _selectedTab == 'Notifications'
                ? _buildNotificationsList(userId, notificationState)
                : _buildActivityList(activityState),
          ],
        ),
        onRefresh: () => _selectedTab == 'Notifications'
            ? _refresh(userId)
            : _refreshActivity(),
      ),
    );
  }

  Widget _buildFilterSection(notificationState, activityState) {
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
          children: filters.map((filter) {
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
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colorTokens.button
                      : context.colorTokens.btnBase,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? context.colorTokens.onBtn
                          : context.colorTokens.neutralOpacity,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filter['label'] as String,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? context.colorTokens.onBtn
                            : context.colorTokens.neutralOpacity,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsBar(state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: context.colorTokens.stroke)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active,
            size: 16,
            color: context.colorTokens.button,
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

    if (state.notifications.isEmpty) {
      return _buildEmptyState();
    }

    // Filter notifications based on selected filter
    List<NotificationItem> filteredNotifications = state.notifications;
    if (_selectedFilter != 'All') {
      filteredNotifications = state.notifications.where((n) {
        switch (_selectedFilter) {
          case 'Games':
            return n.type == NotificationType.gameInvite ||
                n.type == NotificationType.gameUpdate;
          case 'Bookings':
            return n.type == NotificationType.bookingConfirmation ||
                n.type == NotificationType.bookingReminder;
          case 'Social':
            return n.type == NotificationType.friendRequest;
          case 'Achievements':
            return n.type == NotificationType.achievement ||
                n.type == NotificationType.loyaltyPoints;
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

  Widget _buildNotificationCard(String userId, NotificationItem notification) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref
            .read(notificationsControllerProvider(userId).notifier)
            .deleteNotification(notification.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorTokens.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colorTokens.stroke),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _getNotificationIcon(
            notification.type,
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
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorTokens.neutralOpacity,
                ),
              ),
              const SizedBox(height: 8),
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
                    color: context.colorTokens.button,
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: () => _handleNotificationTap(userId, notification),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(
    NotificationType type,
    NotificationPriority priority,
  ) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.gameInvite:
      case NotificationType.gameUpdate:
        icon = Icons.sports_esports;
        color = Colors.blue;
        break;
      case NotificationType.bookingConfirmation:
      case NotificationType.bookingReminder:
        icon = Icons.calendar_today;
        color = Colors.green;
        break;
      case NotificationType.friendRequest:
        icon = Icons.person_add;
        color = Colors.purple;
        break;
      case NotificationType.achievement:
        icon = Icons.military_tech;
        color = Colors.amber;
        break;
      case NotificationType.loyaltyPoints:
        icon = Icons.paid;
        color = Colors.orange;
        break;
      case NotificationType.systemAlert:
        icon = Icons.warning_amber;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    if (priority == NotificationPriority.urgent) {
      color = Colors.red;
    } else if (priority == NotificationPriority.high) {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
            Icons.notifications_off,
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
    NotificationItem notification,
  ) async {
    // Mark as read
    if (!notification.isRead) {
      await ref
          .read(notificationsControllerProvider(userId).notifier)
          .markAsRead(notification.id);
    }

    // Navigate if action route exists
    if (notification.actionRoute != null && mounted) {
      context.push(notification.actionRoute!);
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    try {
      await ref
          .read(notificationsControllerProvider(userId).notifier)
          .markAllAsRead();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorTokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorTokens.stroke),
      ),
      child: ListTile(
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
    );
  }

  Widget _getActivityIcon(String subjectType) {
    IconData icon;
    Color color;

    switch (subjectType) {
      case 'game':
        icon = Icons.sports_esports;
        color = Colors.blue;
        break;
      case 'booking':
        icon = Icons.calendar_today;
        color = Colors.green;
        break;
      case 'social':
        icon = Icons.group;
        color = Colors.purple;
        break;
      case 'payment':
        icon = Icons.payment;
        color = Colors.orange;
        break;
      case 'reward':
        icon = Icons.star;
        color = Colors.amber;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
    switch (timeBucket) {
      case 'present':
        return Colors.green;
      case 'upcoming':
        return Colors.orange;
      default:
        return Colors.grey;
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
            Icons.timeline,
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

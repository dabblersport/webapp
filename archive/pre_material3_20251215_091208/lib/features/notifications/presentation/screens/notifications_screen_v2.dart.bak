import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../data/notifications_repository.dart';
import '../providers/notifications_providers.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/widgets/custom_app_bar.dart';
import 'package:dabbler/themes/app_theme.dart';

class NotificationsScreenV2 extends ConsumerStatefulWidget {
  const NotificationsScreenV2({super.key});

  @override
  ConsumerState<NotificationsScreenV2> createState() =>
      _NotificationsScreenV2State();
}

class _NotificationsScreenV2State extends ConsumerState<NotificationsScreenV2> {
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final userId = _authService.getCurrentUserId();
      if (userId != null) {
        ref.read(notificationsControllerProvider(userId).notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.getCurrentUserId();

    if (userId == null) {
      return Scaffold(
        appBar: CustomAppBar(
          actionIcon: LucideIcons.bell,
          onActionPressed: () {},
        ),
        body: const Center(child: Text('Please sign in to view notifications')),
      );
    }

    final state = ref.watch(notificationsControllerProvider(userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        actionIcon: LucideIcons.checkCheck,
        onActionPressed: () => _markAllAsRead(userId),
      ),
      body: Column(
        children: [
          _buildFilterSection(state),
          _buildStatsBar(state),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(userId),
              child: _buildNotificationsList(userId, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(state) {
    final filters = [
      {'label': 'All', 'icon': LucideIcons.inbox},
      {'label': 'Games', 'icon': LucideIcons.gamepad2},
      {'label': 'Bookings', 'icon': LucideIcons.calendar},
      {'label': 'Social', 'icon': LucideIcons.users},
      {'label': 'Achievements', 'icon': LucideIcons.award},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
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
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? context.colors.onPrimary
                          : context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filter['label'] as String,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? context.colors.onPrimary
                            : context.colors.onSurfaceVariant,
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
        color: context.colors.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.bellDot, size: 16, color: context.colors.primary),
          const SizedBox(width: 8),
          Text(
            '${state.unreadCount} unread',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${state.notifications.length} total',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
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

    return ListView.builder(
      controller: _scrollController,
      itemCount: filteredNotifications.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= filteredNotifications.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final notification = filteredNotifications[index];
        return _buildNotificationCard(userId, notification);
      },
    );
  }

  Widget _buildNotificationCard(String userId, NotificationItem notification) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
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
          color: notification.isRead
              ? context.colors.surface
              : context.colors.primaryContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colors.outline.withValues(alpha: 0.1),
          ),
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
              color: context.colors.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(notification.createdAt),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
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
                    color: context.colors.primary,
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
        icon = LucideIcons.gamepad2;
        color = Colors.blue;
        break;
      case NotificationType.bookingConfirmation:
      case NotificationType.bookingReminder:
        icon = LucideIcons.calendar;
        color = Colors.green;
        break;
      case NotificationType.friendRequest:
        icon = LucideIcons.userPlus;
        color = Colors.purple;
        break;
      case NotificationType.achievement:
        icon = LucideIcons.award;
        color = Colors.amber;
        break;
      case NotificationType.loyaltyPoints:
        icon = LucideIcons.coins;
        color = Colors.orange;
        break;
      case NotificationType.systemAlert:
        icon = LucideIcons.alertTriangle;
        color = Colors.red;
        break;
      default:
        icon = LucideIcons.bell;
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
            LucideIcons.bellOff,
            size: 64,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: context.textTheme.headlineSmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when something happens',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
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

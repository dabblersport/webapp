import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Notifications screen showing social notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.settings), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Social'),
            Tab(text: 'Games'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Notifications
          _buildNotificationsList(showAll: true),

          // Social Notifications
          _buildNotificationsList(showAll: false, filterType: 'social'),

          // Game Notifications
          _buildNotificationsList(showAll: false, filterType: 'games'),
        ],
      ),
    );
  }

  Widget _buildNotificationsList({bool showAll = true, String? filterType}) {
    final notifications = _getNotifications(showAll, filterType);

    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.bell, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final isUnread = notification['isUnread'] as bool;

        return Container(
          color: isUnread ? Colors.blue.withOpacity(0.05) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getNotificationColor(
                notification['type'] as String,
              ),
              child: Icon(
                _getNotificationIcon(notification['type'] as String),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              notification['title'] as String,
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['body'] as String,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['time'] as String,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            trailing: isUnread
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () {
              setState(() {
                notification['isUnread'] = false;
              });
            },
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getNotifications(
    bool showAll,
    String? filterType,
  ) {
    final allNotifications = [
      {
        'id': '1',
        'type': 'friend_request',
        'category': 'social',
        'title': 'Friend Request',
        'body': 'John Doe sent you a friend request',
        'time': '2 minutes ago',
        'isUnread': true,
      },
      {
        'id': '2',
        'type': 'game_invite',
        'category': 'games',
        'title': 'Game Invitation',
        'body': 'You\'re invited to join Basketball at Central Park',
        'time': '1 hour ago',
        'isUnread': true,
      },
      {
        'id': '3',
        'type': 'like',
        'category': 'social',
        'title': 'Post Liked',
        'body': 'Sarah liked your post about the championship',
        'time': '3 hours ago',
        'isUnread': false,
      },
      {
        'id': '4',
        'type': 'comment',
        'category': 'social',
        'title': 'New Comment',
        'body': 'Mike commented on your post: "Great game!"',
        'time': '5 hours ago',
        'isUnread': false,
      },
      {
        'id': '5',
        'type': 'game_reminder',
        'category': 'games',
        'title': 'Game Reminder',
        'body': 'Your game starts in 1 hour at Downtown Court',
        'time': '1 day ago',
        'isUnread': false,
      },
      {
        'id': '6',
        'type': 'message',
        'category': 'social',
        'title': 'New Message',
        'body': 'Alex sent you a message',
        'time': '2 days ago',
        'isUnread': false,
      },
    ];

    if (showAll) {
      return allNotifications;
    }

    return allNotifications.where((notification) {
      return notification['category'] == filterType;
    }).toList();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request':
        return LucideIcons.userPlus;
      case 'game_invite':
        return LucideIcons.calendar;
      case 'like':
        return LucideIcons.heart;
      case 'comment':
        return LucideIcons.messageCircle;
      case 'game_reminder':
        return LucideIcons.clock;
      case 'message':
        return LucideIcons.mail;
      default:
        return LucideIcons.bell;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'friend_request':
        return Colors.blue;
      case 'game_invite':
        return Colors.green;
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.purple;
      case 'game_reminder':
        return Colors.orange;
      case 'message':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

// notifications_repository.dart
// Production-ready Supabase notifications repository for Flutter
// Supports keyset pagination, realtime updates, and comprehensive filtering

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// ENUMS
// ============================================================================

enum NotificationType {
  gameInvite,
  gameUpdate,
  bookingConfirmation,
  bookingReminder,
  friendRequest,
  achievement,
  loyaltyPoints,
  generalUpdate,
  systemAlert;

  static NotificationType fromDb(String value) {
    switch (value) {
      case 'game_invite':
        return NotificationType.gameInvite;
      case 'game_update':
        return NotificationType.gameUpdate;
      case 'booking_confirmation':
        return NotificationType.bookingConfirmation;
      case 'booking_reminder':
        return NotificationType.bookingReminder;
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'achievement':
        return NotificationType.achievement;
      case 'loyalty_points':
        return NotificationType.loyaltyPoints;
      case 'general_update':
        return NotificationType.generalUpdate;
      case 'system_alert':
        return NotificationType.systemAlert;
      default:
        return NotificationType.generalUpdate;
    }
  }

  String toDb() {
    switch (this) {
      case NotificationType.gameInvite:
        return 'game_invite';
      case NotificationType.gameUpdate:
        return 'game_update';
      case NotificationType.bookingConfirmation:
        return 'booking_confirmation';
      case NotificationType.bookingReminder:
        return 'booking_reminder';
      case NotificationType.friendRequest:
        return 'friend_request';
      case NotificationType.achievement:
        return 'achievement';
      case NotificationType.loyaltyPoints:
        return 'loyalty_points';
      case NotificationType.generalUpdate:
        return 'general_update';
      case NotificationType.systemAlert:
        return 'system_alert';
    }
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent;

  static NotificationPriority fromDb(String value) {
    switch (value) {
      case 'low':
        return NotificationPriority.low;
      case 'normal':
        return NotificationPriority.normal;
      case 'high':
        return NotificationPriority.high;
      case 'urgent':
        return NotificationPriority.urgent;
      default:
        return NotificationPriority.normal;
    }
  }

  String toDb() => name; // low, normal, high, urgent
}

// ============================================================================
// MODELS
// ============================================================================

/// Pagination cursor for keyset pagination
class NotificationCursor {
  final DateTime createdAt;
  final String id;

  const NotificationCursor({required this.createdAt, required this.id});

  Map<String, dynamic> toMap() => {
    'created_at': createdAt.toIso8601String(),
    'id': id,
  };

  factory NotificationCursor.fromMap(Map<String, dynamic> map) {
    return NotificationCursor(
      createdAt: DateTime.parse(map['created_at'] as String),
      id: map['id'] as String,
    );
  }

  @override
  String toString() => 'NotificationCursor(createdAt: $createdAt, id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationCursor &&
        other.createdAt == createdAt &&
        other.id == id;
  }

  @override
  int get hashCode => createdAt.hashCode ^ id.hashCode;
}

/// Immutable notification item model
class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String? imageUrl;
  final String? actionText;
  final String? actionRoute;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.isRead,
    this.data,
    this.imageUrl,
    this.actionText,
    this.actionRoute,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create cursor for pagination
  NotificationCursor get cursor =>
      NotificationCursor(createdAt: createdAt, id: id);

  /// Parse from Supabase row
  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      type: NotificationType.fromDb(map['type'] as String),
      priority: NotificationPriority.fromDb(
        map['priority'] as String? ?? 'normal',
      ),
      isRead: map['is_read'] as bool? ?? false,
      data: map['data'] as Map<String, dynamic>?,
      imageUrl: map['image_url'] as String?,
      actionText: map['action_text'] as String?,
      actionRoute: map['action_route'] as String?,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to Supabase row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type.toDb(),
      'priority': priority.toDb(),
      'is_read': isRead,
      'data': data,
      'image_url': imageUrl,
      'action_text': actionText,
      'action_route': actionRoute,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create copy with updated fields
  NotificationItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    bool? isRead,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionText,
    String? actionRoute,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      imageUrl: imageUrl ?? this.imageUrl,
      actionText: actionText ?? this.actionText,
      actionRoute: actionRoute ?? this.actionRoute,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'NotificationItem(id: $id, title: $title, isRead: $isRead)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class RepoException implements Exception {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  RepoException(this.message, {this.error, this.stackTrace});

  @override
  String toString() =>
      'RepoException: $message${error != null ? ' ($error)' : ''}';
}

// ============================================================================
// REPOSITORY
// ============================================================================

class NotificationsRepository {
  final SupabaseClient _client;

  // Cache for realtime subscriptions
  final Map<String, RealtimeChannel> _subscriptions = {};

  NotificationsRepository(this._client);

  /// List notifications with keyset pagination and filters
  ///
  /// Example indexes (assumed to exist):
  /// ```sql
  /// create index on notifications (user_id, is_read, created_at desc);
  /// create index on notifications (user_id, created_at desc, id desc);
  /// ```
  Future<List<NotificationItem>> list({
    required String userId,
    int limit = 20,
    NotificationCursor? cursor,
    String? typeFilter,
    String? priorityFilter,
    bool? isRead,
  }) async {
    try {
      // Start query
      var query = _client.from('notifications').select().eq('user_id', userId);

      // Apply type filter
      if (typeFilter != null) {
        query = query.eq('type', typeFilter);
      }

      // Apply priority filter
      if (priorityFilter != null) {
        query = query.eq('priority', priorityFilter);
      }

      // Apply is_read filter
      if (isRead != null) {
        query = query.eq('is_read', isRead);
      }

      // Apply keyset pagination cursor
      if (cursor != null) {
        // Keyset pagination: created_at < cursor OR (created_at = cursor AND id < cursor.id)
        final cursorTime = cursor.createdAt.toIso8601String();
        final cursorId = cursor.id;

        query = query.or(
          'created_at.lt.$cursorTime,and(created_at.eq.$cursorTime,id.lt.$cursorId)',
        );
      }

      // Order and limit
      final response = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => NotificationItem.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      throw RepoException(
        'Failed to list notifications',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Create a new notification
  ///
  /// RLS policy (assumed):
  /// ```sql
  /// create policy "Users can insert own notifications"
  /// on notifications for insert
  /// with check (auth.uid() = user_id);
  /// ```
  Future<NotificationItem> create({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.normal,
    String? actionRoute,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionText,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _client
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type.toDb(),
            'priority': priority.toDb(),
            'action_route': actionRoute,
            'data': data,
            'image_url': imageUrl,
            'action_text': actionText,
            'is_read': false,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      return NotificationItem.fromMap(response);
    } catch (e, stack) {
      throw RepoException(
        'Failed to create notification',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Mark notification as read
  ///
  /// RLS policy (assumed):
  /// ```sql
  /// create policy "Users can update own notifications"
  /// on notifications for update
  /// using (auth.uid() = user_id);
  /// ```
  Future<void> markRead({required String notificationId}) async {
    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e, stack) {
      throw RepoException(
        'Failed to mark notification as read',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Mark notification as unread
  Future<void> markUnread({required String notificationId}) async {
    try {
      await _client
          .from('notifications')
          .update({
            'is_read': false,
            'read_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e, stack) {
      throw RepoException(
        'Failed to mark notification as unread',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Mark all notifications as read for a user (single statement)
  Future<void> markAllReadForUser({required String userId}) async {
    try {
      final now = DateTime.now().toIso8601String();

      await _client
          .from('notifications')
          .update({'is_read': true, 'read_at': now, 'updated_at': now})
          .eq('user_id', userId)
          .eq('is_read', false); // Only update unread notifications
    } catch (e, stack) {
      throw RepoException(
        'Failed to mark all notifications as read',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Delete a notification
  ///
  /// RLS policy (assumed):
  /// ```sql
  /// create policy "Users can delete own notifications"
  /// on notifications for delete
  /// using (auth.uid() = user_id);
  /// ```
  Future<void> delete({required String notificationId}) async {
    try {
      await _client.from('notifications').delete().eq('id', notificationId);
    } catch (e, stack) {
      throw RepoException(
        'Failed to delete notification',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Subscribe to realtime notifications for a user
  ///
  /// Listens to INSERT and UPDATE events on the notifications table
  /// filtered by user_id. Emits NotificationItem instances.
  ///
  /// Example usage:
  /// ```dart
  /// final subscription = repo.subscribeUserNotifications(userId);
  /// subscription.listen((notification) {
  ///   print('New/Updated: ${notification.title}');
  /// });
  /// ```
  Stream<NotificationItem> subscribeUserNotifications(String userId) {
    final controller = StreamController<NotificationItem>.broadcast();

    // Clean up any existing subscription for this user
    final channelKey = 'notifications_$userId';
    _subscriptions[channelKey]?.unsubscribe();

    // Create new realtime channel
    final channel = _client
        .channel(channelKey)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final notification = NotificationItem.fromMap(payload.newRecord);
              controller.add(notification);
            } catch (e) {
              controller.addError(
                RepoException('Failed to parse INSERT payload', error: e),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final notification = NotificationItem.fromMap(payload.newRecord);
              controller.add(notification);
            } catch (e) {
              controller.addError(
                RepoException('Failed to parse UPDATE payload', error: e),
              );
            }
          },
        )
        .subscribe();

    _subscriptions[channelKey] = channel;

    // Clean up on stream close
    controller.onCancel = () {
      _subscriptions[channelKey]?.unsubscribe();
      _subscriptions.remove(channelKey);
    };

    return controller.stream;
  }

  /// Unsubscribe from all realtime channels
  void dispose() {
    for (final channel in _subscriptions.values) {
      channel.unsubscribe();
    }
    _subscriptions.clear();
  }
}

// ============================================================================
// USAGE EXAMPLE (Minimal UI Integration)
// ============================================================================

/*
// 1. Initialize repository
final repo = NotificationsRepository(Supabase.instance.client);

// 2. ChangeNotifier example for UI integration
class NotificationsController extends ChangeNotifier {
  final NotificationsRepository _repo;
  final String _userId;
  
  List<NotificationItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  NotificationCursor? _cursor;
  StreamSubscription? _realtimeSub;

  NotificationsController(this._repo, this._userId) {
    _init();
  }

  List<NotificationItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  void _init() {
    // Load first page
    loadMore();
    
    // Subscribe to realtime updates
    _realtimeSub = _repo.subscribeUserNotifications(_userId).listen(
      (notification) {
        // Handle INSERT: prepend new notification
        if (!_items.any((item) => item.id == notification.id)) {
          _items.insert(0, notification);
          notifyListeners();
        } else {
          // Handle UPDATE: patch existing item
          final index = _items.indexWhere((item) => item.id == notification.id);
          if (index != -1) {
            _items[index] = notification;
            notifyListeners();
          }
        }
      },
      onError: (error) {
      },
    );
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final newItems = await _repo.list(
        userId: _userId,
        limit: 20,
        cursor: _cursor,
      );

      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        _items.addAll(newItems);
        _cursor = newItems.last.cursor;
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    await loadMore();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repo.markRead(notificationId: notificationId);
      // Update will come via realtime subscription
    } catch (e) {
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repo.markAllReadForUser(userId: _userId);
      // Updates will come via realtime subscription
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}

// 3. Widget usage
class NotificationsScreen extends StatefulWidget {
  final String userId;
  const NotificationsScreen({required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsController _controller;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final repo = NotificationsRepository(Supabase.instance.client);
    _controller = NotificationsController(repo, widget.userId);
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _controller.markAllAsRead,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _controller.items.length + 
                         (_controller.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _controller.items.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final item = _controller.items[index];
                return ListTile(
                  leading: item.isRead 
                    ? const Icon(Icons.check_circle_outline)
                    : const Icon(Icons.circle, size: 12),
                  title: Text(item.title),
                  subtitle: Text(item.message),
                  onTap: () async {
                    // Mark as read
                    if (!item.isRead) {
                      await _controller.markAsRead(item.id);
                    }
                    
                    // Navigate if action route exists
                    if (item.actionRoute != null && context.mounted) {
                      Navigator.pushNamed(context, item.actionRoute!);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
*/

// ============================================================================
// TESTING NOTES
// ============================================================================

/*
Unit Testing Guide:

1. Mock SupabaseClient:
   - Use packages like `mockito` or `mocktail`
   - Mock PostgrestFilterBuilder chain methods
   - Mock RealtimeChannel for subscription tests

2. Repository Tests:
   ```dart
   test('list() applies keyset pagination correctly', () async {
     final mockClient = MockSupabaseClient();
     final repo = NotificationsRepository(mockClient);
     
     when(() => mockClient.from('notifications'))
       .thenReturn(mockPostgrestBuilder);
     
     // Test cursor logic
     final cursor = NotificationCursor(
       createdAt: DateTime(2025, 1, 1),
       id: 'test-id',
     );
     
     await repo.list(userId: 'user-123', cursor: cursor);
     
     verify(() => mockPostgrestBuilder.or(
       'created_at.lt.2025-01-01T00:00:00.000,'
       'and(created_at.eq.2025-01-01T00:00:00.000,id.lt.test-id)'
     )).called(1);
   });
   
   test('markAllReadForUser updates only unread', () async {
     // Verify .eq('is_read', false) is called
   });
   
   test('subscribeUserNotifications emits on INSERT', () async {
     final mockChannel = MockRealtimeChannel();
     // Setup mock to trigger INSERT callback
     // Assert stream emits NotificationItem
   });
   ```

3. Index Verification (in DB):
   ```sql
   -- Verify these indexes exist for optimal performance
   \d notifications
   
   -- Should show:
   -- idx_notifications_user_read_created: (user_id, is_read, created_at DESC)
   -- idx_notifications_user_created_id: (user_id, created_at DESC, id DESC)
   ```

4. RLS Policy Tests:
   - Test that user A cannot read user B's notifications
   - Test that updates respect user_id ownership
   - Use Supabase test helpers or integration tests
*/

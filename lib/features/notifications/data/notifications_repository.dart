import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'models/notification_model.dart';

/// Contract for all notification data operations.
///
/// Implementations must target `public.notifications` directly
/// (not a view) and return [Result] types for FP consistency.
abstract class NotificationsRepository {
  /// Fetch a page of notifications for the current user.
  ///
  /// Uses keyset pagination: pass [cursor] (the `created_at` of the last item
  /// from the previous page) to load older rows. First page: omit [cursor].
  Future<Result<List<AppNotification>, Failure>> getPage({
    int limit = 20,
    DateTime? cursor,
  });

  /// Mark a single notification as read. Sets `is_read = true` and
  /// `read_at = now()`.
  Future<Result<void, Failure>> markAsRead(String id);

  /// Record that the user tapped / interacted with a notification.
  /// Sets `clicked_at = now()` and increments `interaction_count`.
  Future<Result<void, Failure>> markClicked(String id);

  /// Mark **all** unread notifications as read for the current user.
  Future<Result<void, Failure>> markAllRead();

  /// Return the count of unread notifications for the current user.
  Future<Result<int, Failure>> getUnreadCount();
}

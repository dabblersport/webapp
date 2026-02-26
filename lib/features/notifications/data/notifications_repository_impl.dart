import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'models/notification_model.dart';
import 'notifications_repository.dart';

/// Supabase-backed implementation of [NotificationsRepository].
///
/// Targets `public.notifications` directly (no views).
/// RLS ensures only rows where `to_user_id = auth.uid()` are visible.
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._client);

  final SupabaseClient _client;

  // ── Table constant ───────────────────────────────────────────────────

  static const _table = 'notifications';

  // ── Read ─────────────────────────────────────────────────────────────

  @override
  Future<Result<List<AppNotification>, Failure>> getPage({
    int limit = 20,
    DateTime? cursor,
  }) {
    return Result.guard(() async {
      var query = _client.from(_table).select();

      if (cursor != null) {
        query = query.lt('created_at', cursor.toUtc().toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return rows
          .map((row) => AppNotification.fromJson(row))
          .toList(growable: false);
    }, Failure.from);
  }

  @override
  Future<Result<int, Failure>> getUnreadCount() {
    return Result.guard(() async {
      final response = await _client
          .from(_table)
          .select('id')
          .eq('is_read', false);

      return (response as List).length;
    }, Failure.from);
  }

  // ── Write ────────────────────────────────────────────────────────────

  @override
  Future<Result<void, Failure>> markAsRead(String id) {
    return Result.guard(() async {
      await _client
          .from(_table)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    }, Failure.from);
  }

  @override
  Future<Result<void, Failure>> markClicked(String id) {
    return Result.guard(() async {
      // First fetch current interaction_count so we can increment it.
      // (Supabase PostgREST doesn't support `column = column + 1` natively.)
      final row = await _client
          .from(_table)
          .select('interaction_count')
          .eq('id', id)
          .maybeSingle();

      final currentCount = (row?['interaction_count'] as int?) ?? 0;

      await _client
          .from(_table)
          .update({
            'clicked_at': DateTime.now().toUtc().toIso8601String(),
            'interaction_count': currentCount + 1,
          })
          .eq('id', id);
    }, Failure.from);
  }

  @override
  Future<Result<void, Failure>> markAllRead() {
    return Result.guard(() async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from(_table)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('to_user_id', userId)
          .eq('is_read', false);
    }, Failure.from);
  }
}

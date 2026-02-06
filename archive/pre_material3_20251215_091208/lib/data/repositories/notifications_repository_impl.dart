import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/fp/failure.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import 'package:dabbler/data/models/notification.dart';
import 'notifications_repository.dart';
import 'base_repository.dart';
import 'package:meta/meta.dart';

@immutable
class NotificationsRepositoryImpl extends BaseRepository
    implements NotificationsRepository {
  const NotificationsRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<Result<List<AppNotification>, Failure>> getLatest({
    int limit = 50,
    DateTime? since,
  }) async {
    return guard<List<AppNotification>>(() async {
      final uid = _uid;
      if (uid == null) {
        throw AuthException('Not authenticated');
      }

      var query = _db.from('notifications').select().eq('user_id', uid);

      if (since != null) {
        query = query.gte('created_at', since.toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map((r) => AppNotification.fromMap(r)).toList();
    });
  }

  @override
  Future<Result<AppNotification?, Failure>> getById(String id) async {
    return guard<AppNotification?>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      final rows = await _db
          .from('notifications')
          .select()
          .eq('id', id)
          .limit(1)
          .maybeSingle();

      if (rows == null) return null;
      return AppNotification.fromMap(rows);
    });
  }

  @override
  Future<Result<int, Failure>> markAsRead(String id) async {
    return guard<int>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      final now = DateTime.now().toUtc().toIso8601String();

      final res = await _db
          .from('notifications')
          .update({'read_at': now})
          .eq('id', id)
          .eq('user_id', uid);

      // PostgREST returns updated rows by default (unless prefer: return=minimal).
      // Count might not be present in all versions; fall back to length.
      if (res is List) return res.length;
      if (res is Map && res['count'] is int) return res['count'] as int;
      return 1; // optimistic default if update didn't throw and wasn't minimal
    });
  }

  @override
  Future<Result<int, Failure>> markAllAsRead({DateTime? before}) async {
    return guard<int>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      final now = DateTime.now().toUtc().toIso8601String();

      var query = _db
          .from('notifications')
          .update({'read_at': now})
          .eq('user_id', uid)
          .isFilter('read_at', null);

      if (before != null) {
        query = query.lte('created_at', before.toIso8601String());
      }

      final res = await query;
      if (res is List) return res.length;
      if (res is Map && res['count'] is int) return res['count'] as int;
      // If "return=minimal" is set globally, you can do an extra count; keep simple:
      return 0;
    });
  }

  @override
  Stream<List<AppNotification>> watchUserNotifications({int limit = 50}) {
    final uid = _uid;
    if (uid == null) {
      // Return an empty stream if unauthenticated.
      return const Stream<List<AppNotification>>.empty();
    }

    // Simple realtime stream using Supabase's .stream API.
    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map<AppNotification>((r) => AppNotification.fromMap(asMap(r)))
              .toList(),
        );
  }
}

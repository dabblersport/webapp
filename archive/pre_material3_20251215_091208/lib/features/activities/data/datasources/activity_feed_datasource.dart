import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_feed_event.dart';

/// Data source for fetching activity feed from Supabase RPC.
///
/// This is the single source of truth for activity data. The UI must not
/// reconstruct or classify activities - only read and render what this returns.
class ActivityFeedDatasource {
  final SupabaseClient _supabase;

  ActivityFeedDatasource(this._supabase);

  /// Fetches activity feed from rpc_get_activity_feed RPC.
  ///
  /// Parameters:
  /// - [period]: 'all' | 'past' | 'present' | 'upcoming'
  /// - [limit]: Maximum number of items to return (default: 50)
  /// - [cursor]: Timestamp cursor for pagination (happened_at < cursor)
  ///
  /// Returns a list of ActivityFeedEvent objects.
  /// Throws an exception if the RPC call fails.
  Future<List<ActivityFeedEvent>> getActivityFeed({
    required String period,
    int limit = 50,
    DateTime? cursor,
  }) async {
    try {
      final response = await _supabase.rpc(
        'rpc_get_activity_feed',
        params: {
          '_period': period,
          '_limit': limit,
          '_cursor': cursor?.toIso8601String(),
        },
      );

      // RPC returns a list of maps
      if (response is List) {
        return response
            .map(
              (item) =>
                  ActivityFeedEvent.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }

      throw Exception('Unexpected response format from rpc_get_activity_feed');
    } catch (e) {
      // Re-throw with context for better error handling
      throw Exception('Failed to fetch activity feed: $e');
    }
  }
}

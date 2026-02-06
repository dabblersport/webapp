import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data source for tracking analytics events via Supabase RPC.
///
/// Uses fire-and-forget pattern - analytics should never block the UI
/// or crash the app. All errors are silently handled.
class ActivityAnalyticsDatasource {
  final SupabaseClient _supabase;

  ActivityAnalyticsDatasource(this._supabase);

  /// Tracks an analytics event using rpc_track_event RPC.
  ///
  /// This is a fire-and-forget operation. Errors are silently ignored
  /// to ensure analytics never impacts the user experience.
  ///
  /// Parameters:
  /// - [eventName]: Machine-friendly event name (snake_case)
  /// - [properties]: JSON properties with extra context
  Future<void> trackEvent({
    required String eventName,
    Map<String, dynamic> properties = const {},
  }) async {
    try {
      // RPC returns void, so we await the call directly
      // The response will be null/empty for void-returning functions
      final response = await _supabase.rpc(
        'rpc_track_event',
        params: {'_event_name': eventName, '_properties': properties},
      );

      // For void-returning RPCs, response might be null or empty
      // We don't need to process it, just ensure the call completed
      if (kDebugMode && response != null) {}
    } catch (e) {
      // Log error for debugging but don't crash the app
      if (kDebugMode) {}
      // Silently ignore analytics errors - they should never crash the app
    }
  }

  /// Tracks when the Activity tab is opened.
  ///
  /// Properties:
  /// - [source]: Where the tab was opened from (e.g., 'bottom_nav', 'drawer')
  Future<void> trackActivityTabOpened({String source = 'unknown'}) async {
    await trackEvent(
      eventName: 'activity_tab_opened',
      properties: {'source': source},
    );
  }

  /// Tracks when the user changes the period filter.
  ///
  /// Properties:
  /// - [period]: The selected period ('all' | 'past' | 'upcoming' | 'present')
  Future<void> trackActivityPeriodChanged(String period) async {
    await trackEvent(
      eventName: 'activity_period_changed',
      properties: {'period': period},
    );
  }

  /// Tracks when the user clicks/taps an activity item.
  ///
  /// Properties:
  /// - [subjectType]: Type of entity (e.g., 'game', 'payment')
  /// - [verb]: Action verb (e.g., 'created', 'joined')
  /// - [timeBucket]: Time bucket ('past' | 'present' | 'upcoming')
  Future<void> trackActivityItemClicked({
    required String subjectType,
    required String verb,
    required String timeBucket,
  }) async {
    await trackEvent(
      eventName: 'activity_item_clicked',
      properties: {
        'subject_type': subjectType,
        'verb': verb,
        'time_bucket': timeBucket,
      },
    );
  }
}

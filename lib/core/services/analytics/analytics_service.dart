import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';

typedef AnalyticsProps = Map<String, Object?>;

/// Central analytics façade. Emits to `rpc_track_event` — the same RPC
/// already proven live in `ActivityAnalyticsDatasource`. Fire-and-forget:
/// analytics must never throw into a caller or block the UI.
class AnalyticsService {
  // Allow instantiation for use in mixins
  const AnalyticsService();

  static String? _userId;

  static Future<void> trackEvent(String name, [AnalyticsProps? props]) async {
    final client = Supabase.instance.client;
    final properties = <String, Object?>{
      if (_userId != null) 'user_id': _userId,
      ...?props,
    };
    try {
      await client.rpc(
        SupabaseConfig.rpcTrackEventFn,
        params: {'_event_name': name, '_properties': properties},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AnalyticsService.trackEvent could not deliver "$name": $e');
      }
    }
  }

  static Future<void> trackScreen(
    String screenName, [
    AnalyticsProps? props,
  ]) async {
    await trackEvent('screen_view', {'screen_name': screenName, ...?props});
  }

  static Future<void> setUser(String userId, [AnalyticsProps? traits]) async {
    _userId = userId;
    await trackEvent('identify', {'user_id': userId, ...?traits});
  }

  static Future<void> reset() async {
    _userId = null;
  }

  // Game creation tracking
  Future<void> trackGameCreationStep({
    required String step,
    required String sportType,
    Map<String, dynamic>? additionalData,
  }) async {
    await trackEvent('game_creation_step', {
      'step': step,
      'sport_type': sportType,
      ...?additionalData,
    });
  }

  Future<void> trackGameCreated({
    required String gameId,
    required String sportType,
    required int playerCount,
    double? price,
    required String venueType,
    required String duration,
  }) async {
    await trackEvent('game_created', {
      'game_id': gameId,
      'sport_type': sportType,
      'player_count': playerCount,
      'price': price,
      'venue_type': venueType,
      'duration': duration,
    });
  }

  Future<void> trackGameJoined({
    required String gameId,
    required String sportType,
    required String joinMethod,
    required int timeToJoin,
  }) async {
    await trackEvent('game_joined', {
      'game_id': gameId,
      'sport_type': sportType,
      'join_method': joinMethod,
      'time_to_join': timeToJoin,
    });
  }

  Future<void> trackGameConfirmed({
    required String gameId,
    required String sportType,
  }) async {
    await trackEvent('game_confirmed', {
      'game_id': gameId,
      'sport_type': sportType,
    });
  }

  Future<void> trackGameSearch({
    required String query,
    required int resultsCount,
    required String sportType,
    required Map<String, dynamic> filters,
  }) async {
    await trackEvent('game_search', {
      'query': query,
      'results_count': resultsCount,
      'sport_type': sportType,
      'filters': filters,
    });
  }

  Future<void> trackFilterUsed({
    required String filterType,
    required dynamic filterValue,
    required int resultsCount,
  }) async {
    await trackEvent('filter_used', {
      'filter_type': filterType,
      'filter_value': filterValue,
      'results_count': resultsCount,
    });
  }

  Future<void> trackGameCheckIn({
    required String gameId,
    required String sportType,
    required String checkInMethod,
    required bool successful,
    String? errorReason,
  }) async {
    await trackEvent('game_check_in', {
      'game_id': gameId,
      'sport_type': sportType,
      'check_in_method': checkInMethod,
      'successful': successful,
      if (errorReason != null) 'error_reason': errorReason,
    });
  }

  Future<void> trackVenueSelected({
    required String venueId,
    required String venueName,
    required String sportType,
    required String selectionMethod,
  }) async {
    await trackEvent('venue_selected', {
      'venue_id': venueId,
      'venue_name': venueName,
      'sport_type': sportType,
      'selection_method': selectionMethod,
    });
  }

  Future<void> trackScreenView({
    required String screenName,
    Map<String, dynamic>? properties,
  }) async {
    await trackScreen(screenName, properties);
  }

  Future<void> trackFeatureUsed({
    required String featureName,
    Map<String, dynamic>? context,
  }) async {
    await trackEvent('feature_used', {
      'feature_name': featureName,
      ...?context,
    });
  }

  Future<void> trackError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    await trackEvent('error', {
      'error_type': errorType,
      'error_message': errorMessage,
      if (stackTrace != null) 'stack_trace': stackTrace,
      ...?context,
    });
  }

  Future<void> trackGameEngagement({
    required String gameId,
    required String sportType,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    await trackEvent('game_engagement', {
      'game_id': gameId,
      'sport_type': sportType,
      'action': action,
      ...?metadata,
    });
  }

  Future<void> trackSearchResultClicked({
    required String gameId,
    required int position,
    required String sportType,
    String? query,
  }) async {
    await trackEvent('search_result_clicked', {
      'game_id': gameId,
      'position': position,
      'sport_type': sportType,
      if (query != null) 'query': query,
    });
  }

  Future<void> trackCheckInAttempt({
    required String gameId,
    required bool success,
    String? failureReason,
  }) async {
    await trackEvent('check_in_attempt', {
      'game_id': gameId,
      'success': success,
      if (failureReason != null) 'failure_reason': failureReason,
    });
  }

  Future<void> trackPerformanceMetric({
    required String metricName,
    required num value,
    Map<String, dynamic>? tags,
  }) async {
    await trackEvent('performance_metric', {
      'metric_name': metricName,
      'value': value,
      ...?tags,
    });
  }
}

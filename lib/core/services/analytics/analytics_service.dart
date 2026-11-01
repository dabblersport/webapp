import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';

typedef AnalyticsProps = Map<String, Object?>;

/// Central analytics façade. Emits to `rpc_track_event` — the same RPC
/// already proven live in `ActivityAnalyticsDatasource`. Fire-and-forget:
/// analytics must never throw into a caller or block the UI.
class AnalyticsService {
  // Allow instantiation for use in mixins
  const AnalyticsService();

  /// Test seams: replace the RPC call and the signed-in user lookup.
  @visibleForTesting
  static Future<void> Function(String name, AnalyticsProps props)? sinkOverride;
  @visibleForTesting
  static String? Function()? userIdOverride;

  // Accounts whose signup was already sent in this process.
  static final Set<String> _signupSent = <String>{};

  @visibleForTesting
  static void resetForTest() {
    sinkOverride = null;
    userIdOverride = null;
    _signupSent.clear();
  }

  static String? _currentUserId() {
    final override = userIdOverride;
    if (override != null) return override();
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  // The RPC stores auth.uid() in the user_id column; it is not repeated here.
  static Future<void> trackEvent(String name, [AnalyticsProps? props]) async {
    final properties = <String, Object?>{...?props};
    try {
      final sink = sinkOverride;
      if (sink != null) {
        await sink(name, properties);
        return;
      }
      await Supabase.instance.client.rpc(
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
    await trackEvent('identify', {...?traits});
  }

  /// Launch event `signup`, once per newly created account. [method] is one
  /// of `otp`, `google`, `apple`.
  static Future<void> trackSignup({required String method}) async {
    final uid = _currentUserId();
    if (uid != null && !_signupSent.add(uid)) return;
    await trackEvent('signup', {'method': method});
  }

  /// Fires `signup` only when an OAuth sign-in resolved to a new account
  /// (no profile yet); a returning user resolves to another result.
  static Future<void> trackOAuthSignup(
    GoogleSignInResult result, {
    required String provider,
  }) async {
    if (result is GoogleSignInResultGoToOnboarding ||
        result is GoogleSignInResultGoToPhoneOtp) {
      await trackSignup(method: provider);
    }
  }

  /// Launch event `check_in`: the daily check-in, after it succeeded.
  Future<void> trackCheckIn({int? streakCount, bool? firstToday}) async {
    await trackEvent('check_in', {
      if (streakCount != null) 'streak_count': streakCount,
      if (firstToday != null) 'first_today': firstToday,
    });
  }

  static Future<void> reset() async {
    _signupSent.clear();
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

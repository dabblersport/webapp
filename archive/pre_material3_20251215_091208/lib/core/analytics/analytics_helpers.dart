import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:flutter/material.dart';

/// Mixin to provide easy access to analytics tracking
mixin AnalyticsTrackingMixin {
  final AnalyticsService _analytics = AnalyticsService();

  /// Track game creation funnel step
  Future<void> trackGameCreationStep(
    String step,
    String sportType, [
    Map<String, dynamic>? data,
  ]) {
    return _analytics.trackGameCreationStep(
      step: step,
      sportType: sportType,
      additionalData: data,
    );
  }

  /// Track game creation completion
  Future<void> trackGameCreated({
    required String gameId,
    required String sportType,
    required int playerCount,
    double? price,
    required String venueType,
    required String duration,
  }) {
    return _analytics.trackGameCreated(
      gameId: gameId,
      sportType: sportType,
      playerCount: playerCount,
      price: price,
      venueType: venueType,
      duration: duration,
    );
  }

  /// Track game join
  Future<void> trackGameJoined(
    String gameId,
    String sportType,
    String joinMethod,
    int timeToJoin,
  ) {
    return _analytics.trackGameJoined(
      gameId: gameId,
      sportType: sportType,
      joinMethod: joinMethod,
      timeToJoin: timeToJoin,
    );
  }

  /// Track search query
  Future<void> trackSearch(
    String query,
    int resultsCount,
    String sportType,
    Map<String, dynamic> filters,
  ) {
    return _analytics.trackGameSearch(
      query: query,
      resultsCount: resultsCount,
      sportType: sportType,
      filters: filters,
    );
  }

  /// Track filter usage
  Future<void> trackFilter(
    String filterType,
    dynamic filterValue,
    int resultsCount,
  ) {
    return _analytics.trackFilterUsed(
      filterType: filterType,
      filterValue: filterValue,
      resultsCount: resultsCount,
    );
  }

  /// Track check-in
  Future<void> trackCheckIn(
    String gameId,
    String sportType,
    String method,
    bool successful, [
    String? error,
  ]) {
    return _analytics.trackGameCheckIn(
      gameId: gameId,
      sportType: sportType,
      checkInMethod: method,
      successful: successful,
      errorReason: error,
    );
  }

  /// Track venue selection
  Future<void> trackVenueSelection({
    required String venueId,
    required String venueName,
    required String sportType,
    required double distanceKm,
    double? price,
    required String source,
  }) {
    return _analytics.trackVenueSelected(
      venueId: venueId,
      venueName: venueName,
      sportType: sportType,
      selectionMethod: source,
    );
  }

  /// Track screen view
  Future<void> trackScreen(String screenName, [String? screenClass]) {
    return _analytics.trackScreenView(
      screenName: screenName,
      properties: screenClass != null ? {'screen_class': screenClass} : null,
    );
  }

  /// Track feature usage
  Future<void> trackFeature(
    String featureName, [
    Map<String, dynamic>? context,
  ]) {
    return _analytics.trackFeatureUsed(
      featureName: featureName,
      context: context,
    );
  }

  /// Track error
  Future<void> trackError(
    String errorType,
    String errorMessage, [
    String? stackTrace,
    String? screen,
  ]) {
    return _analytics.trackError(
      errorType: errorType,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      context: screen != null ? {'screen': screen} : null,
    );
  }

  /// Track engagement
  Future<void> trackEngagement(
    String gameId,
    String action,
    Duration timeSpent, [
    String? source,
  ]) {
    return _analytics.trackGameEngagement(
      gameId: gameId,
      sportType: '', // TODO: Add sport type parameter
      action: action,
      metadata: {
        'time_spent': timeSpent.inSeconds,
        if (source != null) 'source': source,
      },
    );
  }
}

/// Wrapper widget to automatically track screen views

class AnalyticsScreenWrapper extends StatefulWidget {
  final String screenName;
  final String? screenClass;
  final Widget child;
  final Map<String, dynamic>? additionalData;

  const AnalyticsScreenWrapper({
    super.key,
    required this.screenName,
    this.screenClass,
    required this.child,
    this.additionalData,
  });

  @override
  State<AnalyticsScreenWrapper> createState() => _AnalyticsScreenWrapperState();
}

class _AnalyticsScreenWrapperState extends State<AnalyticsScreenWrapper>
    with AnalyticsTrackingMixin {
  DateTime? _screenStartTime;

  @override
  void initState() {
    super.initState();
    _screenStartTime = DateTime.now();

    // Track screen view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      trackScreen(widget.screenName, widget.screenClass);
    });
  }

  @override
  void dispose() {
    // Track screen time spent
    if (_screenStartTime != null) {
      final timeSpent = DateTime.now().difference(_screenStartTime!);
      trackEngagement('screen_${widget.screenName}', 'time_spent', timeSpent);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Game creation analytics helper
class GameCreationAnalytics {
  static const String _sportSelection = 'sport_selection';
  static const String _venueSelection = 'venue_selection';
  static const String _playerSettings = 'player_settings';
  static const String _priceSettings = 'price_settings';
  static const String _timeSettings = 'time_settings';
  static const String _reviewAndCreate = 'review_and_create';
  static const String _abandoned = 'abandoned';

  static Future<void> trackSportSelection(String sportType) {
    return AnalyticsService().trackGameCreationStep(
      step: _sportSelection,
      sportType: sportType,
    );
  }

  static Future<void> trackVenueSelection(
    String sportType,
    String venueType,
    double distance,
  ) {
    return AnalyticsService().trackGameCreationStep(
      step: _venueSelection,
      sportType: sportType,
      additionalData: {'venue_type': venueType, 'distance_km': distance},
    );
  }

  static Future<void> trackPlayerSettings(
    String sportType,
    int minPlayers,
    int maxPlayers,
  ) {
    return AnalyticsService().trackGameCreationStep(
      step: _playerSettings,
      sportType: sportType,
      additionalData: {'min_players': minPlayers, 'max_players': maxPlayers},
    );
  }

  static Future<void> trackPriceSettings(String sportType, double? price) {
    return AnalyticsService().trackGameCreationStep(
      step: _priceSettings,
      sportType: sportType,
      additionalData: {'price': price ?? 0.0, 'is_free': price == null},
    );
  }

  static Future<void> trackTimeSettings(
    String sportType,
    DateTime dateTime,
    int duration,
  ) {
    return AnalyticsService().trackGameCreationStep(
      step: _timeSettings,
      sportType: sportType,
      additionalData: {
        'game_date': dateTime.toIso8601String(),
        'duration_minutes': duration,
        'day_of_week': dateTime.weekday,
        'hour_of_day': dateTime.hour,
      },
    );
  }

  static Future<void> trackReviewAndCreate(String sportType) {
    return AnalyticsService().trackGameCreationStep(
      step: _reviewAndCreate,
      sportType: sportType,
    );
  }

  static Future<void> trackCompleted({
    required String gameId,
    required String sportType,
    required int playerCount,
    double? price,
    required String venueType,
    required String duration,
  }) {
    return AnalyticsService().trackGameCreated(
      gameId: gameId,
      sportType: sportType,
      playerCount: playerCount,
      price: price,
      venueType: venueType,
      duration: duration,
    );
  }

  static Future<void> trackAbandoned(
    String sportType,
    String lastStep,
    String reason,
  ) {
    return AnalyticsService().trackGameCreationStep(
      step: _abandoned,
      sportType: sportType,
      additionalData: {'last_step': lastStep, 'abandon_reason': reason},
    );
  }
}

/// Search analytics helper
class SearchAnalytics {
  static Future<void> trackQuery({
    required String query,
    required int resultsCount,
    required String sportType,
    Map<String, dynamic>? filters,
    String? location,
  }) {
    final filterData = filters ?? {};
    if (location != null) {
      filterData['location'] = location;
    }
    return AnalyticsService().trackGameSearch(
      query: query,
      resultsCount: resultsCount,
      sportType: sportType,
      filters: filterData,
    );
  }

  static Future<void> trackResultClick({
    required String gameId,
    required String query,
    required int position,
    required String sportType,
  }) {
    return AnalyticsService().trackSearchResultClicked(
      gameId: gameId,
      query: query,
      position: position,
      sportType: sportType,
    );
  }

  static Future<void> trackFilterUsage(
    String filterType,
    dynamic value,
    int resultsCount,
  ) {
    return AnalyticsService().trackFilterUsed(
      filterType: filterType,
      filterValue: value,
      resultsCount: resultsCount,
    );
  }

  static Future<void> trackEmptyResults(
    String query,
    Map<String, dynamic> filters,
  ) {
    return AnalyticsService().trackGameSearch(
      query: query,
      resultsCount: 0,
      sportType: 'any',
      filters: filters,
    );
  }
}

/// Check-in analytics helper
class CheckInAnalytics {
  static Future<void> trackAttempt({
    required String gameId,
    required String sportType,
    required String method,
    required bool successful,
    String? error,
    int? attemptNumber,
  }) {
    return Future.wait([
      AnalyticsService().trackGameCheckIn(
        gameId: gameId,
        sportType: sportType,
        checkInMethod: method,
        successful: successful,
        errorReason: error,
      ),
      AnalyticsService().trackCheckInAttempt(
        gameId: gameId,
        success: successful,
        failureReason: error,
      ),
    ]);
  }

  static Future<void> trackMethodPreference(
    String preferredMethod,
    String reason,
  ) {
    return AnalyticsService().trackFeatureUsed(
      featureName: 'checkin_method_preference',
      context: {'preferred_method': preferredMethod, 'reason': reason},
    );
  }

  static Future<void> trackLocationPermissionRequest(
    bool granted,
    String reason,
  ) {
    return AnalyticsService().trackFeatureUsed(
      featureName: 'location_permission_request',
      context: {'granted': granted, 'reason': reason},
    );
  }
}

/// Performance analytics helper
class PerformanceAnalytics {
  static Future<void> trackScreenLoadTime(
    String screenName,
    Duration loadTime,
  ) {
    return AnalyticsService().trackPerformanceMetric(
      metricName: 'screen_load_time',
      value: loadTime.inMilliseconds.toDouble(),
      tags: {'screen_name': screenName, 'unit': 'ms'},
    );
  }

  static Future<void> trackApiResponseTime(
    String endpoint,
    Duration responseTime,
  ) {
    return AnalyticsService().trackPerformanceMetric(
      metricName: 'api_response_time',
      value: responseTime.inMilliseconds.toDouble(),
      tags: {'endpoint': endpoint, 'unit': 'ms'},
    );
  }

  static Future<void> trackImageLoadTime(String imageUrl, Duration loadTime) {
    return AnalyticsService().trackPerformanceMetric(
      metricName: 'image_load_time',
      value: loadTime.inMilliseconds.toDouble(),
      tags: {'image_url': imageUrl, 'unit': 'ms'},
    );
  }

  static Future<void> trackMemoryUsage(double memoryMb) {
    return AnalyticsService().trackPerformanceMetric(
      metricName: 'memory_usage',
      value: memoryMb,
      tags: {'unit': 'mb'},
    );
  }
}

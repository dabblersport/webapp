enum SessionStatus {
  scheduled,
  preparing,
  inProgress,
  paused,
  overtime,
  completed,
  cancelled,
  abandoned,
}

enum WeatherCondition {
  sunny,
  partlyCloudy,
  cloudy,
  overcast,
  lightRain,
  rain,
  heavyRain,
  drizzle,
  snow,
  windy,
  hot,
  cold,
  humid,
}

enum SessionType {
  regular,
  tournament,
  practice,
  friendly,
  training,
  competitive,
}

class Score {
  final String teamOrPlayerId;
  final String teamOrPlayerName;
  final int points;
  final Map<String, dynamic> stats; // Additional stats like sets, games, etc.

  const Score({
    required this.teamOrPlayerId,
    required this.teamOrPlayerName,
    required this.points,
    this.stats = const {},
  });

  Score copyWith({
    String? teamOrPlayerId,
    String? teamOrPlayerName,
    int? points,
    Map<String, dynamic>? stats,
  }) {
    return Score(
      teamOrPlayerId: teamOrPlayerId ?? this.teamOrPlayerId,
      teamOrPlayerName: teamOrPlayerName ?? this.teamOrPlayerName,
      points: points ?? this.points,
      stats: stats ?? this.stats,
    );
  }
}

class GameEvent {
  final String id;
  final String
  type; // 'goal', 'point', 'penalty', 'substitution', 'timeout', etc.
  final DateTime timestamp;
  final String? playerId;
  final String? playerName;
  final String? teamId;
  final String description;
  final Map<String, dynamic> metadata;

  const GameEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.playerId,
    this.playerName,
    this.teamId,
    required this.description,
    this.metadata = const {},
  });

  GameEvent copyWith({
    String? id,
    String? type,
    DateTime? timestamp,
    String? playerId,
    String? playerName,
    String? teamId,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return GameEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      teamId: teamId ?? this.teamId,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }
}

class GameSession {
  final String id;
  final String gameId;
  final String venueId;
  final String? bookingId;

  // Basic session info
  final SessionType type;
  final SessionStatus status;
  final String? description;
  final String? rules; // Special rules for this session

  // Timing details
  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final int? scheduledDurationMinutes;
  final List<DateTime> pausedTimes; // Track pause/resume times
  final List<DateTime> resumedTimes;

  // Environmental conditions
  final WeatherCondition? weatherCondition;
  final double? temperature; // In Celsius
  final double? humidity; // Percentage
  final String? windSpeed; // e.g., "5 km/h"
  final String? surfaceCondition; // 'excellent', 'good', 'fair', 'poor'

  // Scoring and competition
  final List<Score> scores;
  final String? winnerId; // Team or player ID
  final String? winnerName;
  final bool isDraw;
  final String? gameResult; // Final score summary

  // Game events and timeline
  final List<GameEvent> events;
  final List<String> timeouts; // Track timeouts called
  final int? currentPeriod; // Current set, quarter, half, etc.
  final int? totalPeriods;

  // Equipment and setup
  final List<String> requiredEquipment;
  final List<String> providedEquipment;
  final String? equipmentNotes;
  final String? setupNotes;

  // Officials and supervision
  final String? refereeId;
  final String? refereeName;
  final List<String> officialIds;
  final String? supervisorId;

  // Media and documentation
  final List<String> photos; // Photo URLs
  final List<String> videos; // Video URLs
  final String? streamingUrl; // Live stream if available
  final bool isLiveStreaming;

  // Player participation tracking
  final List<String> checkedInPlayerIds;
  final List<String> noShowPlayerIds;
  final List<String> injuredPlayerIds;
  final Map<String, DateTime> playerCheckInTimes;
  final Map<String, DateTime> playerCheckOutTimes;

  // Session quality and feedback
  final double? sessionRating; // Overall session rating (1-5)
  final String? sessionFeedback;
  final List<String> issues; // Any problems during the session
  final List<String> highlights; // Notable moments

  // Cancellation/Abandonment details
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? abandonmentReason;

  // Administrative details
  final String? createdBy; // User ID who created the session
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastUpdatedBy;

  const GameSession({
    required this.id,
    required this.gameId,
    required this.venueId,
    this.bookingId,
    required this.type,
    required this.status,
    this.description,
    this.rules,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.scheduledDurationMinutes,
    this.pausedTimes = const [],
    this.resumedTimes = const [],
    this.weatherCondition,
    this.temperature,
    this.humidity,
    this.windSpeed,
    this.surfaceCondition,
    this.scores = const [],
    this.winnerId,
    this.winnerName,
    this.isDraw = false,
    this.gameResult,
    this.events = const [],
    this.timeouts = const [],
    this.currentPeriod,
    this.totalPeriods,
    this.requiredEquipment = const [],
    this.providedEquipment = const [],
    this.equipmentNotes,
    this.setupNotes,
    this.refereeId,
    this.refereeName,
    this.officialIds = const [],
    this.supervisorId,
    this.photos = const [],
    this.videos = const [],
    this.streamingUrl,
    this.isLiveStreaming = false,
    this.checkedInPlayerIds = const [],
    this.noShowPlayerIds = const [],
    this.injuredPlayerIds = const [],
    this.playerCheckInTimes = const {},
    this.playerCheckOutTimes = const {},
    this.sessionRating,
    this.sessionFeedback,
    this.issues = const [],
    this.highlights = const [],
    this.cancellationReason,
    this.cancelledAt,
    this.cancelledBy,
    this.abandonmentReason,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastUpdatedBy,
  });

  /// Get actual session duration in minutes
  int? get actualDurationMinutes {
    if (actualStartTime == null || actualEndTime == null) return null;

    var duration = actualEndTime!.difference(actualStartTime!);

    // Subtract paused time
    for (int i = 0; i < pausedTimes.length; i++) {
      final pausedAt = pausedTimes[i];
      final resumedAt = i < resumedTimes.length
          ? resumedTimes[i]
          : actualEndTime!;
      duration = duration - resumedAt.difference(pausedAt);
    }

    return duration.inMinutes;
  }

  /// Get scheduled duration in minutes
  int get scheduledDurationMinutesCalculated {
    return scheduledDurationMinutes ??
        scheduledEndTime.difference(scheduledStartTime).inMinutes;
  }

  /// Check if session is currently active
  bool get isActive {
    return status == SessionStatus.inProgress ||
        status == SessionStatus.overtime;
  }

  /// Check if session is currently paused
  bool get isPaused {
    return status == SessionStatus.paused;
  }

  /// Check if session can be started
  bool canStart() {
    return status == SessionStatus.scheduled ||
        status == SessionStatus.preparing;
  }

  /// Check if session can be paused
  bool canPause() {
    return status == SessionStatus.inProgress;
  }

  /// Check if session can be resumed
  bool canResume() {
    return status == SessionStatus.paused;
  }

  /// Check if session can be completed
  bool canComplete() {
    return status == SessionStatus.inProgress ||
        status == SessionStatus.paused ||
        status == SessionStatus.overtime;
  }

  /// Check if session can be cancelled
  bool canCancel() {
    return status == SessionStatus.scheduled ||
        status == SessionStatus.preparing;
  }

  /// Check if session can be abandoned (during play)
  bool canAbandon() {
    return status == SessionStatus.inProgress ||
        status == SessionStatus.paused ||
        status == SessionStatus.overtime;
  }

  /// Get session status display text
  String get statusText {
    switch (status) {
      case SessionStatus.scheduled:
        return 'Scheduled';
      case SessionStatus.preparing:
        return 'Preparing';
      case SessionStatus.inProgress:
        return 'In Progress';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.overtime:
        return 'Overtime';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.cancelled:
        return 'Cancelled';
      case SessionStatus.abandoned:
        return 'Abandoned';
    }
  }

  /// Get weather condition display text
  String get weatherText {
    switch (weatherCondition) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.partlyCloudy:
        return 'Partly Cloudy';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.overcast:
        return 'Overcast';
      case WeatherCondition.lightRain:
        return 'Light Rain';
      case WeatherCondition.rain:
        return 'Rain';
      case WeatherCondition.heavyRain:
        return 'Heavy Rain';
      case WeatherCondition.drizzle:
        return 'Drizzle';
      case WeatherCondition.snow:
        return 'Snow';
      case WeatherCondition.windy:
        return 'Windy';
      case WeatherCondition.hot:
        return 'Hot';
      case WeatherCondition.cold:
        return 'Cold';
      case WeatherCondition.humid:
        return 'Humid';
      case null:
        return 'Unknown';
    }
  }

  /// Get temperature display text
  String get temperatureText {
    if (temperature == null) return 'Unknown';
    return '${temperature!.round()}°C';
  }

  /// Check if weather is suitable for outdoor play
  bool get isWeatherSuitableForOutdoor {
    switch (weatherCondition) {
      case WeatherCondition.heavyRain:
      case WeatherCondition.snow:
        return false;
      case WeatherCondition.rain:
        return false; // Generally not suitable
      default:
        return true;
    }
  }

  /// Get current score display
  String get currentScoreText {
    if (scores.isEmpty) return '0 - 0';
    if (scores.length == 1) return '${scores[0].points}';
    if (scores.length == 2) return '${scores[0].points} - ${scores[1].points}';
    return scores.map((s) => s.points).join(' - ');
  }

  /// Get winning team/player
  Score? get winningScore {
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a.points > b.points ? a : b);
  }

  /// Check if session is running late
  bool get isRunningLate {
    if (status != SessionStatus.scheduled) return false;
    return DateTime.now().isAfter(
      scheduledStartTime.add(const Duration(minutes: 15)),
    );
  }

  /// Time until session starts
  Duration timeUntilStart() {
    final now = DateTime.now();
    if (now.isAfter(scheduledStartTime)) {
      return Duration.zero;
    }
    return scheduledStartTime.difference(now);
  }

  /// Get session progress percentage (0-100)
  double? get progressPercentage {
    if (actualStartTime == null) return 0.0;
    if (actualEndTime != null) return 100.0;

    final now = DateTime.now();
    final elapsed = now.difference(actualStartTime!).inMinutes;
    final scheduled = scheduledDurationMinutesCalculated;

    return (elapsed / scheduled * 100).clamp(0.0, 100.0);
  }

  /// Get total paused time in minutes
  int get totalPausedMinutes {
    int totalPaused = 0;
    for (int i = 0; i < pausedTimes.length; i++) {
      final pausedAt = pausedTimes[i];
      final resumedAt = i < resumedTimes.length
          ? resumedTimes[i]
          : DateTime.now(); // If still paused
      totalPaused += resumedAt.difference(pausedAt).inMinutes;
    }
    return totalPaused;
  }

  /// Add a score update
  GameSession addScore(
    String teamOrPlayerId,
    String teamOrPlayerName,
    int points, {
    Map<String, dynamic>? stats,
  }) {
    final existingScoreIndex = scores.indexWhere(
      (s) => s.teamOrPlayerId == teamOrPlayerId,
    );
    List<Score> updatedScores = List.from(scores);

    if (existingScoreIndex >= 0) {
      updatedScores[existingScoreIndex] = scores[existingScoreIndex].copyWith(
        points: points,
        stats: stats,
      );
    } else {
      updatedScores.add(
        Score(
          teamOrPlayerId: teamOrPlayerId,
          teamOrPlayerName: teamOrPlayerName,
          points: points,
          stats: stats ?? {},
        ),
      );
    }

    return copyWith(scores: updatedScores);
  }

  /// Add a game event
  GameSession addEvent(GameEvent event) {
    final updatedEvents = List<GameEvent>.from(events)..add(event);
    return copyWith(events: updatedEvents);
  }

  /// Check in a player
  GameSession checkInPlayer(String playerId) {
    final updatedCheckedIn = List<String>.from(checkedInPlayerIds)
      ..add(playerId);
    final updatedCheckInTimes = Map<String, DateTime>.from(playerCheckInTimes);
    updatedCheckInTimes[playerId] = DateTime.now();

    return copyWith(
      checkedInPlayerIds: updatedCheckedIn,
      playerCheckInTimes: updatedCheckInTimes,
    );
  }

  GameSession copyWith({
    String? id,
    String? gameId,
    String? venueId,
    String? bookingId,
    SessionType? type,
    SessionStatus? status,
    String? description,
    String? rules,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    int? scheduledDurationMinutes,
    List<DateTime>? pausedTimes,
    List<DateTime>? resumedTimes,
    WeatherCondition? weatherCondition,
    double? temperature,
    double? humidity,
    String? windSpeed,
    String? surfaceCondition,
    List<Score>? scores,
    String? winnerId,
    String? winnerName,
    bool? isDraw,
    String? gameResult,
    List<GameEvent>? events,
    List<String>? timeouts,
    int? currentPeriod,
    int? totalPeriods,
    List<String>? requiredEquipment,
    List<String>? providedEquipment,
    String? equipmentNotes,
    String? setupNotes,
    String? refereeId,
    String? refereeName,
    List<String>? officialIds,
    String? supervisorId,
    List<String>? photos,
    List<String>? videos,
    String? streamingUrl,
    bool? isLiveStreaming,
    List<String>? checkedInPlayerIds,
    List<String>? noShowPlayerIds,
    List<String>? injuredPlayerIds,
    Map<String, DateTime>? playerCheckInTimes,
    Map<String, DateTime>? playerCheckOutTimes,
    double? sessionRating,
    String? sessionFeedback,
    List<String>? issues,
    List<String>? highlights,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? abandonmentReason,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastUpdatedBy,
  }) {
    return GameSession(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      venueId: venueId ?? this.venueId,
      bookingId: bookingId ?? this.bookingId,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      scheduledDurationMinutes:
          scheduledDurationMinutes ?? this.scheduledDurationMinutes,
      pausedTimes: pausedTimes ?? this.pausedTimes,
      resumedTimes: resumedTimes ?? this.resumedTimes,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      surfaceCondition: surfaceCondition ?? this.surfaceCondition,
      scores: scores ?? this.scores,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      isDraw: isDraw ?? this.isDraw,
      gameResult: gameResult ?? this.gameResult,
      events: events ?? this.events,
      timeouts: timeouts ?? this.timeouts,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      providedEquipment: providedEquipment ?? this.providedEquipment,
      equipmentNotes: equipmentNotes ?? this.equipmentNotes,
      setupNotes: setupNotes ?? this.setupNotes,
      refereeId: refereeId ?? this.refereeId,
      refereeName: refereeName ?? this.refereeName,
      officialIds: officialIds ?? this.officialIds,
      supervisorId: supervisorId ?? this.supervisorId,
      photos: photos ?? this.photos,
      videos: videos ?? this.videos,
      streamingUrl: streamingUrl ?? this.streamingUrl,
      isLiveStreaming: isLiveStreaming ?? this.isLiveStreaming,
      checkedInPlayerIds: checkedInPlayerIds ?? this.checkedInPlayerIds,
      noShowPlayerIds: noShowPlayerIds ?? this.noShowPlayerIds,
      injuredPlayerIds: injuredPlayerIds ?? this.injuredPlayerIds,
      playerCheckInTimes: playerCheckInTimes ?? this.playerCheckInTimes,
      playerCheckOutTimes: playerCheckOutTimes ?? this.playerCheckOutTimes,
      sessionRating: sessionRating ?? this.sessionRating,
      sessionFeedback: sessionFeedback ?? this.sessionFeedback,
      issues: issues ?? this.issues,
      highlights: highlights ?? this.highlights,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      abandonmentReason: abandonmentReason ?? this.abandonmentReason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'GameSession{id: $id, game: $gameId, status: $status, scheduled: $scheduledStartTime}';
  }
}

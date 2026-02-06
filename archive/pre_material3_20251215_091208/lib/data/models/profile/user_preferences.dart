enum GameDuration { short, medium, long, any } // 30min, 1hr, 2hr+, flexible

enum TeamSize { small, medium, large, any } // 2-6, 6-12, 12+, flexible

enum TravelWillingness { local, moderate, high } // 5mi, 15mi, 30mi+

enum AgeRangePreference { similar, younger, older, any }

enum GenderMixPreference { mixed, sameGender, any }

class TimeSlot {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final int startHour; // 0-23
  final int endHour; // 0-23

  const TimeSlot({
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
  });

  bool isAvailable(DateTime dateTime) {
    if (dateTime.weekday != dayOfWeek) return false;
    final hour = dateTime.hour;
    return hour >= startHour && hour <= endHour;
  }

  Map<String, dynamic> toJson() {
    return {'dayOfWeek': dayOfWeek, 'startHour': startHour, 'endHour': endHour};
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      dayOfWeek: json['dayOfWeek'] as int,
      startHour: json['startHour'] as int,
      endHour: json['endHour'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSlot &&
        other.dayOfWeek == dayOfWeek &&
        other.startHour == startHour &&
        other.endHour == endHour;
  }

  @override
  int get hashCode => Object.hash(dayOfWeek, startHour, endHour);
}

class UserPreferences {
  // User identification
  final String userId;

  // Game preferences
  final List<String>
  preferredSports; // sport IDs - for compatibility with use case
  final List<String> preferredGameTypes; // sport IDs - existing property
  final GameDuration preferredDuration;
  final TeamSize preferredTeamSize;
  final List<String> skillLevelPreferences; // beginner, intermediate, etc.
  final String?
  skillLevel; // single skill level - for compatibility with use case
  final int? minPlayers; // for compatibility with use case
  final int? maxPlayers; // for compatibility with use case
  final String? competitionLevel; // for compatibility with use case
  final String? playerType; // for compatibility with use case

  // Location preferences
  final double maxTravelRadius; // in miles
  final double? maxTravelDistance; // in km - for compatibility with use case
  final List<String> preferredVenues; // venue IDs
  final List<String> preferredLocations; // for compatibility with use case
  final TravelWillingness travelWillingness;
  final bool preferOutdoor;
  final bool preferIndoor;

  // Availability preferences
  final List<TimeSlot> weeklyAvailability;
  final Map<String, List<String>>
  availableTimeSlots; // for compatibility with use case
  final int advanceBookingDays; // how far ahead willing to book
  final int minimumNoticeHours; // minimum notice for games
  final List<String> unavailableDates; // ISO date strings

  // Social preferences
  final bool openToNewPlayers;
  final bool openToNewSports; // for compatibility with use case
  final AgeRangePreference ageRangePreference;
  final GenderMixPreference genderMixPreference;
  final bool preferFriendsOfFriends;
  final int maxGroupSize;
  final int minGroupSize;
  final List<String> languagesSpoken; // for compatibility with use case

  // Competition preferences
  final bool preferCompetitive;
  final bool preferCasual;
  final bool acceptWaitlist;
  final bool autoAcceptInvites;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserPreferences({
    required this.userId,
    this.preferredSports = const [],
    this.preferredGameTypes = const [],
    this.preferredDuration = GameDuration.any,
    this.preferredTeamSize = TeamSize.any,
    this.skillLevelPreferences = const [],
    this.skillLevel,
    this.minPlayers,
    this.maxPlayers,
    this.competitionLevel,
    this.playerType,
    this.maxTravelRadius = 15.0,
    this.maxTravelDistance,
    this.preferredVenues = const [],
    this.preferredLocations = const [],
    this.travelWillingness = TravelWillingness.moderate,
    this.preferOutdoor = true,
    this.preferIndoor = true,
    this.weeklyAvailability = const [],
    this.availableTimeSlots = const {},
    this.advanceBookingDays = 14,
    this.minimumNoticeHours = 4,
    this.unavailableDates = const [],
    this.openToNewPlayers = true,
    this.openToNewSports = true,
    this.ageRangePreference = AgeRangePreference.any,
    this.genderMixPreference = GenderMixPreference.any,
    this.preferFriendsOfFriends = false,
    this.maxGroupSize = 20,
    this.minGroupSize = 4,
    this.preferCompetitive = false,
    this.preferCasual = true,
    this.acceptWaitlist = true,
    this.autoAcceptInvites = false,
    this.languagesSpoken = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Checks if user is available at a specific date/time
  bool isAvailableAt(DateTime dateTime) {
    // Check if date is in unavailable dates
    final dateStr = dateTime.toIso8601String().split('T')[0];
    if (unavailableDates.contains(dateStr)) return false;

    // Check if time falls within weekly availability
    return weeklyAvailability.any((slot) => slot.isAvailable(dateTime));
  }

  /// Checks if game meets minimum notice requirement
  bool hasEnoughNotice(DateTime gameDateTime) {
    final now = DateTime.now();
    final hoursUntilGame = gameDateTime.difference(now).inHours;
    return hoursUntilGame >= minimumNoticeHours;
  }

  /// Checks if game is within advance booking window
  bool isWithinBookingWindow(DateTime gameDateTime) {
    final now = DateTime.now();
    final daysUntilGame = gameDateTime.difference(now).inDays;
    return daysUntilGame <= advanceBookingDays;
  }

  /// Returns compatibility score (0-100) with a game
  int getGameCompatibilityScore(Map<String, dynamic> game) {
    int score = 0;

    // Sport compatibility
    final gameSport = game['sportId'] as String?;
    if (gameSport != null && preferredGameTypes.contains(gameSport)) {
      score += 30;
    }

    // Duration compatibility
    final gameDuration = game['duration'] as int?; // minutes
    if (gameDuration != null && _isDurationCompatible(gameDuration)) {
      score += 20;
    }

    // Team size compatibility
    final teamSize = game['maxPlayers'] as int?;
    if (teamSize != null && _isTeamSizeCompatible(teamSize)) {
      score += 20;
    }

    // Distance compatibility
    final distance = game['distance'] as double?;
    if (distance != null && distance <= maxTravelRadius) {
      score += 15;
    }

    // Timing compatibility
    final gameDateTime = game['dateTime'] as DateTime?;
    if (gameDateTime != null && isAvailableAt(gameDateTime)) {
      score += 15;
    }

    return score.clamp(0, 100);
  }

  bool _isDurationCompatible(int durationMinutes) {
    switch (preferredDuration) {
      case GameDuration.short:
        return durationMinutes <= 60;
      case GameDuration.medium:
        return durationMinutes > 60 && durationMinutes <= 120;
      case GameDuration.long:
        return durationMinutes > 120;
      case GameDuration.any:
        return true;
    }
  }

  bool _isTeamSizeCompatible(int teamSize) {
    switch (preferredTeamSize) {
      case TeamSize.small:
        return teamSize <= 6;
      case TeamSize.medium:
        return teamSize > 6 && teamSize <= 12;
      case TeamSize.large:
        return teamSize > 12;
      case TeamSize.any:
        return true;
    }
  }

  /// Gets available time slots for a specific day
  List<TimeSlot> getAvailabilityForDay(int dayOfWeek) {
    return weeklyAvailability
        .where((slot) => slot.dayOfWeek == dayOfWeek)
        .toList();
  }

  /// Creates a copy with updated fields
  UserPreferences copyWith({
    String? userId,
    List<String>? preferredSports,
    List<String>? preferredGameTypes,
    GameDuration? preferredDuration,
    TeamSize? preferredTeamSize,
    List<String>? skillLevelPreferences,
    String? skillLevel,
    int? minPlayers,
    int? maxPlayers,
    String? competitionLevel,
    String? playerType,
    double? maxTravelRadius,
    double? maxTravelDistance,
    List<String>? preferredVenues,
    List<String>? preferredLocations,
    TravelWillingness? travelWillingness,
    bool? preferOutdoor,
    bool? preferIndoor,
    List<TimeSlot>? weeklyAvailability,
    Map<String, List<String>>? availableTimeSlots,
    int? advanceBookingDays,
    int? minimumNoticeHours,
    List<String>? unavailableDates,
    bool? openToNewPlayers,
    bool? openToNewSports,
    AgeRangePreference? ageRangePreference,
    GenderMixPreference? genderMixPreference,
    bool? preferFriendsOfFriends,
    int? maxGroupSize,
    int? minGroupSize,
    bool? preferCompetitive,
    bool? preferCasual,
    bool? acceptWaitlist,
    bool? autoAcceptInvites,
    List<String>? languagesSpoken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      preferredSports: preferredSports ?? this.preferredSports,
      preferredGameTypes: preferredGameTypes ?? this.preferredGameTypes,
      preferredDuration: preferredDuration ?? this.preferredDuration,
      preferredTeamSize: preferredTeamSize ?? this.preferredTeamSize,
      skillLevelPreferences:
          skillLevelPreferences ?? this.skillLevelPreferences,
      skillLevel: skillLevel ?? this.skillLevel,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      competitionLevel: competitionLevel ?? this.competitionLevel,
      playerType: playerType ?? this.playerType,
      maxTravelRadius: maxTravelRadius ?? this.maxTravelRadius,
      maxTravelDistance: maxTravelDistance ?? this.maxTravelDistance,
      preferredVenues: preferredVenues ?? this.preferredVenues,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      travelWillingness: travelWillingness ?? this.travelWillingness,
      preferOutdoor: preferOutdoor ?? this.preferOutdoor,
      preferIndoor: preferIndoor ?? this.preferIndoor,
      weeklyAvailability: weeklyAvailability ?? this.weeklyAvailability,
      availableTimeSlots: availableTimeSlots ?? this.availableTimeSlots,
      advanceBookingDays: advanceBookingDays ?? this.advanceBookingDays,
      minimumNoticeHours: minimumNoticeHours ?? this.minimumNoticeHours,
      unavailableDates: unavailableDates ?? this.unavailableDates,
      openToNewPlayers: openToNewPlayers ?? this.openToNewPlayers,
      openToNewSports: openToNewSports ?? this.openToNewSports,
      ageRangePreference: ageRangePreference ?? this.ageRangePreference,
      genderMixPreference: genderMixPreference ?? this.genderMixPreference,
      preferFriendsOfFriends:
          preferFriendsOfFriends ?? this.preferFriendsOfFriends,
      maxGroupSize: maxGroupSize ?? this.maxGroupSize,
      minGroupSize: minGroupSize ?? this.minGroupSize,
      preferCompetitive: preferCompetitive ?? this.preferCompetitive,
      preferCasual: preferCasual ?? this.preferCasual,
      acceptWaitlist: acceptWaitlist ?? this.acceptWaitlist,
      autoAcceptInvites: autoAcceptInvites ?? this.autoAcceptInvites,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates UserPreferences from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['userId'] as String? ?? '',
      preferredSports: List<String>.from(
        json['preferredSports'] as List? ?? [],
      ),
      preferredGameTypes: List<String>.from(
        json['preferredGameTypes'] as List? ?? [],
      ),
      preferredDuration: GameDuration.values.firstWhere(
        (e) => e.toString().split('.').last == json['preferredDuration'],
        orElse: () => GameDuration.any,
      ),
      preferredTeamSize: TeamSize.values.firstWhere(
        (e) => e.toString().split('.').last == json['preferredTeamSize'],
        orElse: () => TeamSize.any,
      ),
      skillLevelPreferences: List<String>.from(
        json['skillLevelPreferences'] as List? ?? [],
      ),
      skillLevel: json['skillLevel'] as String?,
      minPlayers: json['minPlayers'] as int?,
      maxPlayers: json['maxPlayers'] as int?,
      competitionLevel: json['competitionLevel'] as String?,
      playerType: json['playerType'] as String?,
      maxTravelRadius: (json['maxTravelRadius'] as num?)?.toDouble() ?? 15.0,
      maxTravelDistance: (json['maxTravelDistance'] as num?)?.toDouble(),
      preferredVenues: List<String>.from(
        json['preferredVenues'] as List? ?? [],
      ),
      preferredLocations: List<String>.from(
        json['preferredLocations'] as List? ?? [],
      ),
      travelWillingness: TravelWillingness.values.firstWhere(
        (e) => e.toString().split('.').last == json['travelWillingness'],
        orElse: () => TravelWillingness.moderate,
      ),
      preferOutdoor: json['preferOutdoor'] as bool? ?? true,
      preferIndoor: json['preferIndoor'] as bool? ?? true,
      weeklyAvailability:
          (json['weeklyAvailability'] as List?)
              ?.map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availableTimeSlots:
          _parseAvailableTimeSlots(json['availableTimeSlots']) ?? {},
      advanceBookingDays: json['advanceBookingDays'] as int? ?? 14,
      minimumNoticeHours: json['minimumNoticeHours'] as int? ?? 4,
      unavailableDates: List<String>.from(
        json['unavailableDates'] as List? ?? [],
      ),
      openToNewPlayers: json['openToNewPlayers'] as bool? ?? true,
      openToNewSports: json['openToNewSports'] as bool? ?? true,
      ageRangePreference: AgeRangePreference.values.firstWhere(
        (e) => e.toString().split('.').last == json['ageRangePreference'],
        orElse: () => AgeRangePreference.any,
      ),
      genderMixPreference: GenderMixPreference.values.firstWhere(
        (e) => e.toString().split('.').last == json['genderMixPreference'],
        orElse: () => GenderMixPreference.any,
      ),
      preferFriendsOfFriends: json['preferFriendsOfFriends'] as bool? ?? false,
      maxGroupSize: json['maxGroupSize'] as int? ?? 20,
      minGroupSize: json['minGroupSize'] as int? ?? 4,
      preferCompetitive: json['preferCompetitive'] as bool? ?? false,
      preferCasual: json['preferCasual'] as bool? ?? true,
      acceptWaitlist: json['acceptWaitlist'] as bool? ?? true,
      autoAcceptInvites: json['autoAcceptInvites'] as bool? ?? false,
      languagesSpoken: List<String>.from(
        json['languagesSpoken'] as List? ?? [],
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Converts UserPreferences to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'preferredSports': preferredSports,
      'preferredGameTypes': preferredGameTypes,
      'preferredDuration': preferredDuration.toString().split('.').last,
      'preferredTeamSize': preferredTeamSize.toString().split('.').last,
      'skillLevelPreferences': skillLevelPreferences,
      'skillLevel': skillLevel,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'competitionLevel': competitionLevel,
      'playerType': playerType,
      'maxTravelRadius': maxTravelRadius,
      'maxTravelDistance': maxTravelDistance,
      'preferredVenues': preferredVenues,
      'preferredLocations': preferredLocations,
      'travelWillingness': travelWillingness.toString().split('.').last,
      'preferOutdoor': preferOutdoor,
      'preferIndoor': preferIndoor,
      'weeklyAvailability': weeklyAvailability
          .map((slot) => slot.toJson())
          .toList(),
      'availableTimeSlots': availableTimeSlots,
      'advanceBookingDays': advanceBookingDays,
      'minimumNoticeHours': minimumNoticeHours,
      'unavailableDates': unavailableDates,
      'openToNewPlayers': openToNewPlayers,
      'openToNewSports': openToNewSports,
      'ageRangePreference': ageRangePreference.toString().split('.').last,
      'genderMixPreference': genderMixPreference.toString().split('.').last,
      'preferFriendsOfFriends': preferFriendsOfFriends,
      'maxGroupSize': maxGroupSize,
      'minGroupSize': minGroupSize,
      'preferCompetitive': preferCompetitive,
      'preferCasual': preferCasual,
      'acceptWaitlist': acceptWaitlist,
      'autoAcceptInvites': autoAcceptInvites,
      'languagesSpoken': languagesSpoken,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences &&
        other.userId == userId &&
        _listEquals(other.preferredSports, preferredSports) &&
        _listEquals(other.preferredGameTypes, preferredGameTypes) &&
        other.preferredDuration == preferredDuration &&
        other.preferredTeamSize == preferredTeamSize &&
        _listEquals(other.skillLevelPreferences, skillLevelPreferences) &&
        other.skillLevel == skillLevel &&
        other.minPlayers == minPlayers &&
        other.maxPlayers == maxPlayers &&
        other.competitionLevel == competitionLevel &&
        other.playerType == playerType &&
        other.maxTravelRadius == maxTravelRadius &&
        other.maxTravelDistance == maxTravelDistance &&
        _listEquals(other.preferredVenues, preferredVenues) &&
        _listEquals(other.preferredLocations, preferredLocations) &&
        other.travelWillingness == travelWillingness &&
        other.preferOutdoor == preferOutdoor &&
        other.preferIndoor == preferIndoor &&
        _listEquals(other.weeklyAvailability, weeklyAvailability) &&
        _mapEquals(other.availableTimeSlots, availableTimeSlots) &&
        other.advanceBookingDays == advanceBookingDays &&
        other.minimumNoticeHours == minimumNoticeHours &&
        _listEquals(other.unavailableDates, unavailableDates) &&
        other.openToNewPlayers == openToNewPlayers &&
        other.openToNewSports == openToNewSports &&
        other.ageRangePreference == ageRangePreference &&
        other.genderMixPreference == genderMixPreference &&
        other.preferFriendsOfFriends == preferFriendsOfFriends &&
        other.maxGroupSize == maxGroupSize &&
        other.minGroupSize == minGroupSize &&
        other.preferCompetitive == preferCompetitive &&
        other.preferCasual == preferCasual &&
        other.acceptWaitlist == acceptWaitlist &&
        other.autoAcceptInvites == autoAcceptInvites &&
        _listEquals(other.languagesSpoken, languagesSpoken) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    // Break up into smaller chunks since Object.hash() has a 20-argument limit
    final hash1 = Object.hash(
      userId,
      Object.hashAll(preferredSports),
      Object.hashAll(preferredGameTypes),
      preferredDuration,
      preferredTeamSize,
      Object.hashAll(skillLevelPreferences),
      skillLevel,
      minPlayers,
      maxPlayers,
      competitionLevel,
      playerType,
      maxTravelRadius,
      maxTravelDistance,
      Object.hashAll(preferredVenues),
      Object.hashAll(preferredLocations),
      travelWillingness,
      preferOutdoor,
      preferIndoor,
      Object.hashAll(weeklyAvailability),
      availableTimeSlots,
    );

    final hash2 = Object.hash(
      advanceBookingDays,
      minimumNoticeHours,
      Object.hashAll(unavailableDates),
      openToNewPlayers,
      openToNewSports,
      ageRangePreference,
      genderMixPreference,
      preferFriendsOfFriends,
      maxGroupSize,
      minGroupSize,
      preferCompetitive,
      preferCasual,
      acceptWaitlist,
      autoAcceptInvites,
      Object.hashAll(languagesSpoken),
      createdAt,
      updatedAt,
    );

    return Object.hash(hash1, hash2);
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  static Map<String, List<String>>? _parseAvailableTimeSlots(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      final result = <String, List<String>>{};
      for (final entry in value.entries) {
        if (entry.value is List) {
          result[entry.key] = List<String>.from(entry.value);
        }
      }
      return result;
    }
    return null;
  }
}

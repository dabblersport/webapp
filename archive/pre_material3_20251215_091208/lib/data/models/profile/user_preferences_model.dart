import 'package:dabbler/data/models/profile/user_preferences.dart';

class UserPreferencesModel extends UserPreferences {
  const UserPreferencesModel({
    required super.userId,
    super.preferredSports,
    super.preferredGameTypes,
    super.preferredDuration,
    super.preferredTeamSize,
    super.skillLevelPreferences,
    super.skillLevel,
    super.minPlayers,
    super.maxPlayers,
    super.competitionLevel,
    super.playerType,
    super.maxTravelRadius,
    super.maxTravelDistance,
    super.preferredVenues,
    super.preferredLocations,
    super.travelWillingness,
    super.preferOutdoor,
    super.preferIndoor,
    super.weeklyAvailability,
    super.availableTimeSlots,
    super.advanceBookingDays,
    super.minimumNoticeHours,
    super.unavailableDates,
    super.openToNewPlayers,
    super.openToNewSports,
    super.ageRangePreference,
    super.genderMixPreference,
    super.preferFriendsOfFriends,
    super.maxGroupSize,
    super.minGroupSize,
    super.preferCompetitive,
    super.preferCasual,
    super.acceptWaitlist,
    super.autoAcceptInvites,
    super.languagesSpoken,
    super.createdAt,
    super.updatedAt,
  });

  /// Creates UserPreferencesModel from domain entity
  factory UserPreferencesModel.fromEntity(UserPreferences entity) {
    return UserPreferencesModel(
      userId: entity.userId,
      preferredSports: entity.preferredSports,
      preferredGameTypes: entity.preferredGameTypes,
      preferredDuration: entity.preferredDuration,
      preferredTeamSize: entity.preferredTeamSize,
      skillLevelPreferences: entity.skillLevelPreferences,
      skillLevel: entity.skillLevel,
      minPlayers: entity.minPlayers,
      maxPlayers: entity.maxPlayers,
      competitionLevel: entity.competitionLevel,
      playerType: entity.playerType,
      maxTravelRadius: entity.maxTravelRadius,
      maxTravelDistance: entity.maxTravelDistance,
      preferredVenues: entity.preferredVenues,
      preferredLocations: entity.preferredLocations,
      travelWillingness: entity.travelWillingness,
      preferOutdoor: entity.preferOutdoor,
      preferIndoor: entity.preferIndoor,
      weeklyAvailability: entity.weeklyAvailability,
      availableTimeSlots: entity.availableTimeSlots,
      advanceBookingDays: entity.advanceBookingDays,
      minimumNoticeHours: entity.minimumNoticeHours,
      unavailableDates: entity.unavailableDates,
      openToNewPlayers: entity.openToNewPlayers,
      openToNewSports: entity.openToNewSports,
      ageRangePreference: entity.ageRangePreference,
      genderMixPreference: entity.genderMixPreference,
      preferFriendsOfFriends: entity.preferFriendsOfFriends,
      maxGroupSize: entity.maxGroupSize,
      minGroupSize: entity.minGroupSize,
      preferCompetitive: entity.preferCompetitive,
      preferCasual: entity.preferCasual,
      acceptWaitlist: entity.acceptWaitlist,
      autoAcceptInvites: entity.autoAcceptInvites,
      languagesSpoken: entity.languagesSpoken,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Creates UserPreferencesModel from JSON (Supabase response)
  factory UserPreferencesModel.fromJson(Map<String, dynamic> json) {
    return UserPreferencesModel(
      userId: json['userId'] as String? ?? '',
      preferredSports: _parseStringList(json['preferred_sports']),
      preferredGameTypes: _parseStringList(json['preferred_game_types']),
      preferredDuration: _parseGameDuration(json['preferred_duration']),
      preferredTeamSize: _parseTeamSize(json['preferred_team_size']),
      skillLevelPreferences: _parseStringList(json['skill_level_preferences']),
      skillLevel: json['skill_level'] as String?,
      minPlayers: json['min_players'] as int?,
      maxPlayers: json['max_players'] as int?,
      competitionLevel: json['competition_level'] as String?,
      playerType: json['player_type'] as String?,
      maxTravelRadius:
          _parseDoubleWithDefault(json['max_travel_radius'], 15.0) ?? 15.0,
      maxTravelDistance: _parseDoubleWithDefault(
        json['max_travel_distance'],
        null,
      ),
      preferredVenues: _parseStringList(json['preferred_venues']),
      preferredLocations: _parseStringList(json['preferred_locations']),
      travelWillingness: _parseTravelWillingness(json['travel_willingness']),
      preferOutdoor: _parseBoolWithDefault(json['prefer_outdoor'], true),
      preferIndoor: _parseBoolWithDefault(json['prefer_indoor'], true),
      weeklyAvailability: _parseTimeSlotList(json['weekly_availability']),
      availableTimeSlots:
          _parseAvailableTimeSlots(json['available_time_slots']) ?? {},
      advanceBookingDays: _parseIntWithDefault(
        json['advance_booking_days'],
        14,
      ),
      minimumNoticeHours: _parseIntWithDefault(json['minimum_notice_hours'], 4),
      unavailableDates: _parseStringList(json['unavailable_dates']),
      openToNewPlayers: _parseBoolWithDefault(
        json['open_to_new_players'],
        true,
      ),
      openToNewSports: _parseBoolWithDefault(json['open_to_new_sports'], true),
      ageRangePreference: _parseAgeRangePreference(
        json['age_range_preference'],
      ),
      genderMixPreference: _parseGenderMixPreference(
        json['gender_mix_preference'],
      ),
      preferFriendsOfFriends: _parseBoolWithDefault(
        json['prefer_friends_of_friends'],
        false,
      ),
      maxGroupSize: _parseIntWithDefault(json['max_group_size'], 20),
      minGroupSize: _parseIntWithDefault(json['min_group_size'], 4),
      preferCompetitive: _parseBoolWithDefault(
        json['prefer_competitive'],
        false,
      ),
      preferCasual: _parseBoolWithDefault(json['prefer_casual'], true),
      acceptWaitlist: _parseBoolWithDefault(json['accept_waitlist'], true),
      autoAcceptInvites: _parseBoolWithDefault(
        json['auto_accept_invites'],
        false,
      ),
      languagesSpoken: _parseStringList(json['languages_spoken']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Creates UserPreferencesModel from complex Supabase response with nested data
  factory UserPreferencesModel.fromSupabaseResponse(Map<String, dynamic> json) {
    // Handle nested availability data from separate table
    final availabilityData = json['user_availability'] as List?;
    final weeklyAvailability = availabilityData != null
        ? _parseAvailabilityFromList(availabilityData)
        : _parseTimeSlotList(json['weekly_availability']);

    return UserPreferencesModel(
      userId: json['userId'] as String? ?? '',
      preferredSports:
          _parseGameTypesFromRelations(json) ??
          _parseStringList(json['preferred_sports']),
      preferredGameTypes:
          _parseGameTypesFromRelations(json) ??
          _parseStringList(json['preferred_game_types']),
      preferredDuration: _parseGameDuration(json['preferred_duration']),
      preferredTeamSize: _parseTeamSize(json['preferred_team_size']),
      skillLevelPreferences: _parseStringList(json['skill_level_preferences']),
      skillLevel: json['skill_level'] as String?,
      minPlayers: json['min_players'] as int?,
      maxPlayers: json['max_players'] as int?,
      competitionLevel: json['competition_level'] as String?,
      playerType: json['player_type'] as String?,
      maxTravelRadius:
          _parseDoubleWithDefault(json['max_travel_radius'], 15.0) ?? 15.0,
      maxTravelDistance: _parseDoubleWithDefault(
        json['max_travel_distance'],
        null,
      ),
      preferredVenues:
          _parseLocationsFromRelations(json) ??
          _parseStringList(json['preferred_venues']),
      preferredLocations:
          _parseLocationsFromRelations(json) ??
          _parseStringList(json['preferred_locations']),
      travelWillingness: _parseTravelWillingness(json['travel_willingness']),
      preferOutdoor: _parseBoolWithDefault(json['prefer_outdoor'], true),
      preferIndoor: _parseBoolWithDefault(json['prefer_indoor'], true),
      weeklyAvailability: weeklyAvailability,
      availableTimeSlots:
          _parseAvailableTimeSlots(json['available_time_slots']) ?? {},
      advanceBookingDays: _parseIntWithDefault(
        json['advance_booking_days'],
        14,
      ),
      minimumNoticeHours: _parseIntWithDefault(json['minimum_notice_hours'], 4),
      unavailableDates: _parseStringList(json['unavailable_dates']),
      openToNewPlayers: _parseBoolWithDefault(
        json['open_to_new_players'],
        true,
      ),
      openToNewSports: _parseBoolWithDefault(json['open_to_new_sports'], true),
      ageRangePreference: _parseAgeRangePreference(
        json['age_range_preference'],
      ),
      genderMixPreference: _parseGenderMixPreference(
        json['gender_mix_preference'],
      ),
      preferFriendsOfFriends: _parseBoolWithDefault(
        json['prefer_friends_of_friends'],
        false,
      ),
      maxGroupSize: _parseIntWithDefault(json['max_group_size'], 20),
      minGroupSize: _parseIntWithDefault(json['min_group_size'], 4),
      preferCompetitive: _parseBoolWithDefault(
        json['prefer_competitive'],
        false,
      ),
      preferCasual: _parseBoolWithDefault(json['prefer_casual'], true),
      acceptWaitlist: _parseBoolWithDefault(json['accept_waitlist'], true),
      autoAcceptInvites: _parseBoolWithDefault(
        json['auto_accept_invites'],
        false,
      ),
      languagesSpoken: _parseStringList(json['languages_spoken']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converts UserPreferencesModel to JSON for API requests
  @override
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'preferred_sports': preferredSports,
      'preferred_game_types': preferredGameTypes,
      'preferred_duration': preferredDuration.toString().split('.').last,
      'preferred_team_size': preferredTeamSize.toString().split('.').last,
      'skill_level_preferences': skillLevelPreferences,
      'skill_level': skillLevel,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      'competition_level': competitionLevel,
      'player_type': playerType,
      'max_travel_radius': maxTravelRadius,
      'max_travel_distance': maxTravelDistance,
      'preferred_venues': preferredVenues,
      'preferred_locations': preferredLocations,
      'travel_willingness': travelWillingness.toString().split('.').last,
      'prefer_outdoor': preferOutdoor,
      'prefer_indoor': preferIndoor,
      'weekly_availability': weeklyAvailability
          .map((slot) => slot.toJson())
          .toList(),
      'available_time_slots': availableTimeSlots,
      'advance_booking_days': advanceBookingDays,
      'minimum_notice_hours': minimumNoticeHours,
      'unavailable_dates': unavailableDates,
      'open_to_new_players': openToNewPlayers,
      'open_to_new_sports': openToNewSports,
      'age_range_preference': ageRangePreference.toString().split('.').last,
      'gender_mix_preference': genderMixPreference.toString().split('.').last,
      'prefer_friends_of_friends': preferFriendsOfFriends,
      'max_group_size': maxGroupSize,
      'min_group_size': minGroupSize,
      'prefer_competitive': preferCompetitive,
      'prefer_casual': preferCasual,
      'accept_waitlist': acceptWaitlist,
      'auto_accept_invites': autoAcceptInvites,
      'languages_spoken': languagesSpoken,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Converts to JSON for database updates
  Map<String, dynamic> toUpdateJson() {
    return {
      'userId': userId,
      'preferred_sports': preferredSports,
      'preferred_game_types': preferredGameTypes,
      'preferred_duration': preferredDuration.toString().split('.').last,
      'preferred_team_size': preferredTeamSize.toString().split('.').last,
      'skill_level_preferences': skillLevelPreferences,
      'skill_level': skillLevel,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      'competition_level': competitionLevel,
      'player_type': playerType,
      'max_travel_radius': maxTravelRadius,
      'max_travel_distance': maxTravelDistance,
      'preferred_venues': preferredVenues,
      'preferred_locations': preferredLocations,
      'travel_willingness': travelWillingness.toString().split('.').last,
      'prefer_outdoor': preferOutdoor,
      'prefer_indoor': preferIndoor,
      'weekly_availability': weeklyAvailability
          .map((slot) => slot.toJson())
          .toList(),
      'available_time_slots': availableTimeSlots,
      'advance_booking_days': advanceBookingDays,
      'minimum_notice_hours': minimumNoticeHours,
      'unavailable_dates': unavailableDates,
      'open_to_new_players': openToNewPlayers,
      'open_to_new_sports': openToNewSports,
      'age_range_preference': ageRangePreference.toString().split('.').last,
      'gender_mix_preference': genderMixPreference.toString().split('.').last,
      'prefer_friends_of_friends': preferFriendsOfFriends,
      'max_group_size': maxGroupSize,
      'min_group_size': minGroupSize,
      'prefer_competitive': preferCompetitive,
      'prefer_casual': preferCasual,
      'accept_waitlist': acceptWaitlist,
      'auto_accept_invites': autoAcceptInvites,
      'languages_spoken': languagesSpoken,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Creates separate records for availability table
  List<Map<String, dynamic>> toAvailabilityRecords(String userId) {
    final records = <Map<String, dynamic>>[];

    for (final slot in weeklyAvailability) {
      records.add({
        'user_id': userId,
        'day_of_week': slot.dayOfWeek,
        'start_hour': slot.startHour,
        'end_hour': slot.endHour,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return records;
  }

  /// Creates separate records for notification settings table
  List<Map<String, dynamic>> toNotificationRecords(String userId) {
    final now = DateTime.now().toIso8601String();

    // Create notification preference records based on the notification settings
    // This would typically be stored in a separate notifications table
    return [
      {
        'user_id': userId,
        'push_notifications': true, // Default to true
        'email_notifications': true, // Default to true
        'sms_notifications': false, // Default to false
        'game_invites': true,
        'game_updates': true,
        'game_reminders': true,
        'booking_confirmations': true,
        'booking_reminders': true,
        'friend_requests': true,
        'achievements': true,
        'loyalty_points': true,
        'created_at': now,
        'updated_at': now,
      },
    ];
  }

  // Helper parsing methods

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      if (value.isEmpty) return [];
      if (value.startsWith('[') && value.endsWith(']')) {
        try {
          final cleaned = value.substring(1, value.length - 1);
          if (cleaned.isEmpty) return [];
          return cleaned
              .split(',')
              .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (e) {
          return [];
        }
      }
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  static List<TimeSlot> _parseTimeSlotList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static GameDuration _parseGameDuration(dynamic value) {
    if (value == null) return GameDuration.any;
    if (value is String) {
      return GameDuration.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => GameDuration.any,
      );
    }
    return GameDuration.any;
  }

  static TeamSize _parseTeamSize(dynamic value) {
    if (value == null) return TeamSize.any;
    if (value is String) {
      return TeamSize.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => TeamSize.any,
      );
    }
    return TeamSize.any;
  }

  static TravelWillingness _parseTravelWillingness(dynamic value) {
    if (value == null) return TravelWillingness.moderate;
    if (value is String) {
      return TravelWillingness.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => TravelWillingness.moderate,
      );
    }
    return TravelWillingness.moderate;
  }

  static AgeRangePreference _parseAgeRangePreference(dynamic value) {
    if (value == null) return AgeRangePreference.any;
    if (value is String) {
      return AgeRangePreference.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => AgeRangePreference.any,
      );
    }
    return AgeRangePreference.any;
  }

  static GenderMixPreference _parseGenderMixPreference(dynamic value) {
    if (value == null) return GenderMixPreference.any;
    if (value is String) {
      return GenderMixPreference.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => GenderMixPreference.any,
      );
    }
    return GenderMixPreference.any;
  }

  static List<TimeSlot> _parseAvailabilityFromList(
    List<dynamic> availabilityData,
  ) {
    final timeSlots = <TimeSlot>[];

    for (final item in availabilityData) {
      if (item is Map<String, dynamic>) {
        final timeSlot = TimeSlot(
          dayOfWeek: item['day_of_week'] as int,
          startHour: item['start_hour'] as int,
          endHour: item['end_hour'] as int,
        );
        timeSlots.add(timeSlot);
      }
    }

    return timeSlots;
  }

  static List<String>? _parseGameTypesFromRelations(Map<String, dynamic> json) {
    if (json.containsKey('user_game_types') &&
        json['user_game_types'] is List) {
      final gameTypes = json['user_game_types'] as List;
      return gameTypes
          .map((e) => e['game_type']?['name'] as String?)
          .where((e) => e != null)
          .cast<String>()
          .toList();
    }
    return null;
  }

  static List<String>? _parseLocationsFromRelations(Map<String, dynamic> json) {
    if (json.containsKey('user_locations') && json['user_locations'] is List) {
      final locations = json['user_locations'] as List;
      return locations
          .map((e) => e['location']?['name'] as String?)
          .where((e) => e != null)
          .cast<String>()
          .toList();
    }
    return null;
  }

  static int _parseIntWithDefault(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double? _parseDoubleWithDefault(dynamic value, double? defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return defaultValue;
  }

  static bool _parseBoolWithDefault(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return defaultValue;
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

  /// Creates a copy with updated fields
  @override
  UserPreferencesModel copyWith({
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
    return UserPreferencesModel(
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

  /// Converts back to domain entity
  UserPreferences toEntity() {
    return UserPreferences(
      userId: userId,
      preferredSports: preferredSports,
      preferredGameTypes: preferredGameTypes,
      preferredDuration: preferredDuration,
      preferredTeamSize: preferredTeamSize,
      skillLevelPreferences: skillLevelPreferences,
      skillLevel: skillLevel,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      competitionLevel: competitionLevel,
      playerType: playerType,
      maxTravelRadius: maxTravelRadius,
      maxTravelDistance: maxTravelDistance,
      preferredVenues: preferredVenues,
      preferredLocations: preferredLocations,
      travelWillingness: travelWillingness,
      preferOutdoor: preferOutdoor,
      preferIndoor: preferIndoor,
      weeklyAvailability: weeklyAvailability,
      availableTimeSlots: availableTimeSlots,
      advanceBookingDays: advanceBookingDays,
      minimumNoticeHours: minimumNoticeHours,
      unavailableDates: unavailableDates,
      openToNewPlayers: openToNewPlayers,
      openToNewSports: openToNewSports,
      ageRangePreference: ageRangePreference,
      genderMixPreference: genderMixPreference,
      preferFriendsOfFriends: preferFriendsOfFriends,
      maxGroupSize: maxGroupSize,
      minGroupSize: minGroupSize,
      preferCompetitive: preferCompetitive,
      preferCasual: preferCasual,
      acceptWaitlist: acceptWaitlist,
      autoAcceptInvites: autoAcceptInvites,
      languagesSpoken: languagesSpoken,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

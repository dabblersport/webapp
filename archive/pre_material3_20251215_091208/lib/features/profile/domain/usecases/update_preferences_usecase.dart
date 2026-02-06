import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_preferences.dart';
import '../repositories/preferences_repository.dart';

/// Parameters for updating preferences
class UpdatePreferencesParams {
  final String userId;
  final List<String>? preferredSports;
  final String? skillLevel;
  final List<String>? preferredLocations;
  final double? maxTravelDistance;
  final Map<String, List<String>>? availableTimeSlots;
  final List<String>? preferredGameTypes;
  final int? minPlayers;
  final int? maxPlayers;
  final String? competitionLevel;
  final bool? openToNewSports;
  final String? playerType;
  final List<String>? languagesSpoken;

  const UpdatePreferencesParams({
    required this.userId,
    this.preferredSports,
    this.skillLevel,
    this.preferredLocations,
    this.maxTravelDistance,
    this.availableTimeSlots,
    this.preferredGameTypes,
    this.minPlayers,
    this.maxPlayers,
    this.competitionLevel,
    this.openToNewSports,
    this.playerType,
    this.languagesSpoken,
  });

  bool get hasUpdates =>
      preferredSports != null ||
      skillLevel != null ||
      preferredLocations != null ||
      maxTravelDistance != null ||
      availableTimeSlots != null ||
      preferredGameTypes != null ||
      minPlayers != null ||
      maxPlayers != null ||
      competitionLevel != null ||
      openToNewSports != null ||
      playerType != null ||
      languagesSpoken != null;
}

/// Result of preferences update operation
class UpdatePreferencesResult {
  final UserPreferences updatedPreferences;
  final List<String> warnings;
  final Map<String, dynamic> changedPreferences;
  final double matchingScore;

  const UpdatePreferencesResult({
    required this.updatedPreferences,
    required this.warnings,
    required this.changedPreferences,
    required this.matchingScore,
  });
}

/// Use case for updating user preferences with validation and compatibility scoring
class UpdatePreferencesUseCase {
  final PreferencesRepository _preferencesRepository;

  UpdatePreferencesUseCase(this._preferencesRepository);

  Future<Either<Failure, UpdatePreferencesResult>> call(
    UpdatePreferencesParams params,
  ) async {
    try {
      // Validate input parameters
      final validationResult = _validateParams(params);
      if (validationResult.isLeft) {
        return Left(validationResult.leftOrNull()!);
      }

      // Get current preferences for comparison
      final currentPreferencesResult = await _preferencesRepository
          .getPreferences(params.userId);
      if (currentPreferencesResult.isLeft) {
        return Left(currentPreferencesResult.leftOrNull()!);
      }

      final currentPreferences = currentPreferencesResult.rightOrNull()!;

      // Apply business rules and constraints
      final processedParams = _applyBusinessRules(params, currentPreferences);
      if (processedParams.isLeft) {
        return Left(processedParams.leftOrNull()!);
      }

      final finalParams = processedParams.rightOrNull()!;

      // Create updated preferences with new values
      final updatedPreferences = UserPreferences(
        userId: currentPreferences.userId,
        preferredSports:
            finalParams.preferredSports ?? currentPreferences.preferredSports,
        preferredGameTypes:
            finalParams.preferredGameTypes ??
            currentPreferences.preferredGameTypes,
        preferredDuration: currentPreferences.preferredDuration,
        preferredTeamSize: currentPreferences.preferredTeamSize,
        skillLevelPreferences: currentPreferences.skillLevelPreferences,
        skillLevel: finalParams.skillLevel ?? currentPreferences.skillLevel,
        minPlayers: finalParams.minPlayers ?? currentPreferences.minPlayers,
        maxPlayers: finalParams.maxPlayers ?? currentPreferences.maxPlayers,
        competitionLevel:
            finalParams.competitionLevel ?? currentPreferences.competitionLevel,
        playerType: finalParams.playerType ?? currentPreferences.playerType,
        maxTravelRadius: currentPreferences.maxTravelRadius,
        maxTravelDistance:
            finalParams.maxTravelDistance ??
            currentPreferences.maxTravelDistance,
        preferredVenues: currentPreferences.preferredVenues,
        preferredLocations:
            finalParams.preferredLocations ??
            currentPreferences.preferredLocations,
        travelWillingness: currentPreferences.travelWillingness,
        preferOutdoor: currentPreferences.preferOutdoor,
        preferIndoor: currentPreferences.preferIndoor,
        weeklyAvailability: currentPreferences.weeklyAvailability,
        availableTimeSlots:
            finalParams.availableTimeSlots ??
            currentPreferences.availableTimeSlots,
        advanceBookingDays: currentPreferences.advanceBookingDays,
        minimumNoticeHours: currentPreferences.minimumNoticeHours,
        unavailableDates: currentPreferences.unavailableDates,
        openToNewPlayers: currentPreferences.openToNewPlayers,
        openToNewSports:
            finalParams.openToNewSports ?? currentPreferences.openToNewSports,
        ageRangePreference: currentPreferences.ageRangePreference,
        genderMixPreference: currentPreferences.genderMixPreference,
        preferFriendsOfFriends: currentPreferences.preferFriendsOfFriends,
        maxGroupSize: currentPreferences.maxGroupSize,
        minGroupSize: currentPreferences.minGroupSize,
        preferCompetitive: currentPreferences.preferCompetitive,
        preferCasual: currentPreferences.preferCasual,
        acceptWaitlist: currentPreferences.acceptWaitlist,
        autoAcceptInvites: currentPreferences.autoAcceptInvites,
        languagesSpoken:
            finalParams.languagesSpoken ?? currentPreferences.languagesSpoken,
        createdAt: currentPreferences.createdAt,
        updatedAt: DateTime.now(),
      );

      // Perform the preferences update
      final updateResult = await _preferencesRepository.updatePreferences(
        params.userId,
        updatedPreferences,
      );
      if (updateResult.isLeft) {
        return Left(updateResult.leftOrNull()!);
      }

      final finalUpdatedPreferences = updateResult.rightOrNull()!;

      // Calculate changed preferences
      final changedPreferences = _calculateChangedPreferences(
        currentPreferences,
        finalUpdatedPreferences,
      );

      // Calculate matching score for finding compatible players
      final matchingScore = _calculateMatchingScore(finalUpdatedPreferences);

      // Generate warnings
      final warnings = _generateWarnings(
        finalUpdatedPreferences,
        changedPreferences,
      );

      return Right(
        UpdatePreferencesResult(
          updatedPreferences: finalUpdatedPreferences,
          warnings: warnings,
          changedPreferences: changedPreferences,
          matchingScore: matchingScore,
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Preferences update failed: $e'));
    }
  }

  /// Validate input parameters
  Either<Failure, void> _validateParams(UpdatePreferencesParams params) {
    final errors = <String>[];

    // Validate skill level
    if (params.skillLevel != null) {
      const validSkillLevels = [
        'beginner',
        'intermediate',
        'advanced',
        'professional',
      ];
      if (!validSkillLevels.contains(params.skillLevel!.toLowerCase())) {
        errors.add('Invalid skill level');
      }
    }

    // Validate max travel distance
    if (params.maxTravelDistance != null) {
      if (params.maxTravelDistance! < 0 || params.maxTravelDistance! > 1000) {
        errors.add('Max travel distance must be between 0 and 1000 km');
      }
    }

    // Validate player counts
    if (params.minPlayers != null && params.minPlayers! < 2) {
      errors.add('Minimum players must be at least 2');
    }

    if (params.maxPlayers != null && params.maxPlayers! > 100) {
      errors.add('Maximum players cannot exceed 100');
    }

    if (params.minPlayers != null && params.maxPlayers != null) {
      if (params.minPlayers! > params.maxPlayers!) {
        errors.add('Minimum players cannot exceed maximum players');
      }
    }

    // Validate competition level
    if (params.competitionLevel != null) {
      const validCompetitionLevels = [
        'casual',
        'competitive',
        'tournament',
        'professional',
      ];
      if (!validCompetitionLevels.contains(
        params.competitionLevel!.toLowerCase(),
      )) {
        errors.add('Invalid competition level');
      }
    }

    // Validate player type
    if (params.playerType != null) {
      const validPlayerTypes = [
        'team_player',
        'individual',
        'captain',
        'substitute',
        'coach',
      ];
      if (!validPlayerTypes.contains(params.playerType!.toLowerCase())) {
        errors.add('Invalid player type');
      }
    }

    // Validate available time slots
    if (params.availableTimeSlots != null) {
      for (final entry in params.availableTimeSlots!.entries) {
        if (!_isValidDay(entry.key)) {
          errors.add('Invalid day: ${entry.key}');
        }
        for (final timeSlot in entry.value) {
          if (!_isValidTimeSlot(timeSlot)) {
            errors.add('Invalid time slot: $timeSlot');
          }
        }
      }
    }

    // Validate languages
    if (params.languagesSpoken != null) {
      for (final language in params.languagesSpoken!) {
        if (!_isValidLanguage(language)) {
          errors.add('Invalid language code: $language');
        }
      }
    }

    if (errors.isNotEmpty) {
      return Left(ValidationFailure(message: errors.join(', ')));
    }

    return const Right(null);
  }

  /// Apply business rules and constraints
  Either<Failure, UpdatePreferencesParams> _applyBusinessRules(
    UpdatePreferencesParams params,
    UserPreferences currentPreferences,
  ) {
    var processedParams = params;

    // Business Rule: Beginner skill level should have casual competition level
    if (params.skillLevel == 'beginner' && params.competitionLevel == null) {
      processedParams = UpdatePreferencesParams(
        userId: params.userId,
        preferredSports: params.preferredSports,
        skillLevel: params.skillLevel,
        preferredLocations: params.preferredLocations,
        maxTravelDistance: params.maxTravelDistance,
        availableTimeSlots: params.availableTimeSlots,
        preferredGameTypes: params.preferredGameTypes,
        minPlayers: params.minPlayers,
        maxPlayers: params.maxPlayers,
        competitionLevel: 'casual',
        openToNewSports: params.openToNewSports,
        playerType: params.playerType,
        languagesSpoken: params.languagesSpoken,
      );
    }

    // Business Rule: Professional skill level should increase max travel distance
    if (params.skillLevel == 'professional' &&
        params.maxTravelDistance == null) {
      processedParams = UpdatePreferencesParams(
        userId: processedParams.userId,
        preferredSports: processedParams.preferredSports,
        skillLevel: processedParams.skillLevel,
        preferredLocations: processedParams.preferredLocations,
        maxTravelDistance:
            50.0, // Default higher travel distance for professionals
        availableTimeSlots: processedParams.availableTimeSlots,
        preferredGameTypes: processedParams.preferredGameTypes,
        minPlayers: processedParams.minPlayers,
        maxPlayers: processedParams.maxPlayers,
        competitionLevel: processedParams.competitionLevel,
        openToNewSports: processedParams.openToNewSports,
        playerType: processedParams.playerType,
        languagesSpoken: processedParams.languagesSpoken,
      );
    }

    return Right(processedParams);
  }

  /// Calculate which preferences have changed
  Map<String, dynamic> _calculateChangedPreferences(
    UserPreferences current,
    UserPreferences updated,
  ) {
    final changes = <String, dynamic>{};

    if (!_listEquals(current.preferredSports, updated.preferredSports)) {
      changes['preferred_sports'] = {
        'old': current.preferredSports,
        'new': updated.preferredSports,
      };
    }

    if (current.skillLevel != updated.skillLevel) {
      changes['skill_level'] = {
        'old': current.skillLevel,
        'new': updated.skillLevel,
      };
    }

    if (!_listEquals(current.preferredLocations, updated.preferredLocations)) {
      changes['preferred_locations'] = {
        'old': current.preferredLocations,
        'new': updated.preferredLocations,
      };
    }

    if (current.maxTravelDistance != updated.maxTravelDistance) {
      changes['max_travel_distance'] = {
        'old': current.maxTravelDistance,
        'new': updated.maxTravelDistance,
      };
    }

    if (!_mapEquals(current.availableTimeSlots, updated.availableTimeSlots)) {
      changes['available_time_slots'] = {
        'old': current.availableTimeSlots,
        'new': updated.availableTimeSlots,
      };
    }

    if (!_listEquals(current.preferredGameTypes, updated.preferredGameTypes)) {
      changes['preferred_game_types'] = {
        'old': current.preferredGameTypes,
        'new': updated.preferredGameTypes,
      };
    }

    if (current.competitionLevel != updated.competitionLevel) {
      changes['competition_level'] = {
        'old': current.competitionLevel,
        'new': updated.competitionLevel,
      };
    }

    if (current.openToNewSports != updated.openToNewSports) {
      changes['open_to_new_sports'] = {
        'old': current.openToNewSports,
        'new': updated.openToNewSports,
      };
    }

    return changes;
  }

  /// Calculate matching score for finding compatible players
  double _calculateMatchingScore(UserPreferences preferences) {
    double score = 0.0;
    int factors = 0;

    // Sports diversity
    if (preferences.preferredSports.isNotEmpty) {
      score += preferences.preferredSports.length * 10.0;
      factors++;
    }

    // Time availability
    if (preferences.availableTimeSlots.isNotEmpty) {
      final totalSlots = preferences.availableTimeSlots.values.fold<int>(
        0,
        (sum, slots) => sum + slots.length,
      );
      score += totalSlots * 5.0;
      factors++;
    }

    // Flexibility (open to new sports)
    if (preferences.openToNewSports) {
      score += 20.0;
      factors++;
    }

    // Location flexibility
    if (preferences.maxTravelDistance != null &&
        preferences.maxTravelDistance! > 10) {
      score += 15.0;
      factors++;
    }

    // Language diversity
    if (preferences.languagesSpoken.length > 1) {
      score += preferences.languagesSpoken.length * 5.0;
      factors++;
    }

    return factors > 0 ? (score / factors).clamp(0.0, 100.0) : 0.0;
  }

  /// Generate warnings for the user
  List<String> _generateWarnings(
    UserPreferences preferences,
    Map<String, dynamic> changedPreferences,
  ) {
    final warnings = <String>[];

    // Warning: No preferred sports
    if (preferences.preferredSports.isEmpty) {
      warnings.add('Consider adding preferred sports to find better matches.');
    }

    // Warning: Very limited availability
    final totalAvailableSlots = preferences.availableTimeSlots.values.fold<int>(
      0,
      (sum, slots) => sum + slots.length,
    );
    if (totalAvailableSlots < 3) {
      warnings.add('Limited availability may reduce game opportunities.');
    }

    // Warning: Very short travel distance
    if (preferences.maxTravelDistance != null &&
        preferences.maxTravelDistance! < 5) {
      warnings.add('Short travel distance may limit game options.');
    }

    // Warning: Not open to new sports
    if (!preferences.openToNewSports) {
      warnings.add('Being open to new sports can increase game opportunities.');
    }

    // Warning: Skill level vs competition level mismatch
    if (preferences.skillLevel == 'beginner' &&
        preferences.competitionLevel == 'professional') {
      warnings.add('Skill level and competition level seem mismatched.');
    }

    return warnings;
  }

  // Helper methods
  bool _isValidDay(String day) {
    const validDays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return validDays.contains(day.toLowerCase());
  }

  bool _isValidTimeSlot(String timeSlot) {
    // Basic time slot validation (e.g., "09:00-12:00", "evening", "morning")
    return RegExp(r'^\d{2}:\d{2}-\d{2}:\d{2}$').hasMatch(timeSlot) ||
        [
          'morning',
          'afternoon',
          'evening',
          'night',
        ].contains(timeSlot.toLowerCase());
  }

  bool _isValidLanguage(String language) {
    // Basic language code validation (ISO 639-1)
    return RegExp(r'^[a-z]{2}$').hasMatch(language.toLowerCase());
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

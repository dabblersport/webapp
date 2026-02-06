import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_preferences.dart';

/// Repository interface for user preferences related to games, location, and social settings
/// Handles complex data like availability schedules and location-based preferences
abstract class PreferencesRepository {
  /// Retrieves user preferences by user ID
  /// Returns [UserPreferences] on success or [Failure] on error
  Future<Either<Failure, UserPreferences>> getPreferences(String userId);

  /// Updates user preferences
  /// Returns updated [UserPreferences] on success or [Failure] on error
  Future<Either<Failure, UserPreferences>> updatePreferences(
    String userId,
    UserPreferences preferences,
  );

  /// Updates a specific preference category
  /// [category] - Category to update (e.g., 'game_types', 'locations', 'availability')
  /// [data] - New data for the category
  /// Returns updated [UserPreferences] on success or [Failure] on error
  Future<Either<Failure, UserPreferences>> updatePreferenceCategory(
    String userId,
    String category,
    dynamic data,
  );

  /// Gets game preferences (types, skill levels, group sizes, etc.)
  /// Returns game preferences data on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> getGamePreferences(
    String userId,
  );

  /// Updates game preferences
  /// [preferences] - Map of game preference keys to values
  /// Returns updated preferences on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> updateGamePreferences(
    String userId,
    Map<String, dynamic> preferences,
  );

  /// Adds a preferred game type
  /// [gameType] - Game type to add to preferences
  /// Returns updated list on success or [Failure] on error
  Future<Either<Failure, List<String>>> addPreferredGameType(
    String userId,
    String gameType,
  );

  /// Removes a preferred game type
  /// [gameType] - Game type to remove from preferences
  /// Returns updated list on success or [Failure] on error
  Future<Either<Failure, List<String>>> removePreferredGameType(
    String userId,
    String gameType,
  );

  /// Gets location preferences
  /// Returns location data on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> getLocationPreferences(
    String userId,
  );

  /// Updates location preferences
  /// [preferences] - Location preference data
  /// Returns updated preferences on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> updateLocationPreferences(
    String userId,
    Map<String, dynamic> preferences,
  );

  /// Adds a preferred location
  /// [location] - Location to add to preferences
  /// [coordinates] - Optional latitude/longitude coordinates
  /// Returns updated list on success or [Failure] on error
  Future<Either<Failure, List<String>>> addPreferredLocation(
    String userId,
    String location, {
    Map<String, double>? coordinates,
  });

  /// Removes a preferred location
  /// [location] - Location to remove from preferences
  /// Returns updated list on success or [Failure] on error
  Future<Either<Failure, List<String>>> removePreferredLocation(
    String userId,
    String location,
  );

  /// Updates maximum travel distance for games
  /// [distance] - Maximum distance in kilometers
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> updateMaxTravelDistance(
    String userId,
    double distance,
  );

  /// Gets availability schedule for a user
  /// Returns weekly availability data on success or [Failure] on error
  Future<Either<Failure, Map<String, List<TimeSlot>>>> getAvailabilitySchedule(
    String userId,
  );

  /// Updates complete availability schedule
  /// [schedule] - Map of day names to list of available time slots
  /// Returns updated schedule on success or [Failure] on error
  Future<Either<Failure, Map<String, List<TimeSlot>>>>
  updateAvailabilitySchedule(
    String userId,
    Map<String, List<TimeSlot>> schedule,
  );

  /// Updates availability for a specific day
  /// [dayOfWeek] - Day to update (e.g., 'monday', 'tuesday')
  /// [timeSlots] - List of available time slots for that day
  /// Returns updated schedule on success or [Failure] on error
  Future<Either<Failure, Map<String, List<TimeSlot>>>> updateDayAvailability(
    String userId,
    String dayOfWeek,
    List<TimeSlot> timeSlots,
  );

  /// Adds a time slot to availability
  /// [dayOfWeek] - Day to add the time slot to
  /// [timeSlot] - Time slot to add
  /// Returns updated schedule on success or [Failure] on error
  Future<Either<Failure, Map<String, List<TimeSlot>>>> addAvailabilitySlot(
    String userId,
    String dayOfWeek,
    TimeSlot timeSlot,
  );

  /// Removes a time slot from availability
  /// [dayOfWeek] - Day to remove the time slot from
  /// [timeSlot] - Time slot to remove
  /// Returns updated schedule on success or [Failure] on error
  Future<Either<Failure, Map<String, List<TimeSlot>>>> removeAvailabilitySlot(
    String userId,
    String dayOfWeek,
    TimeSlot timeSlot,
  );

  /// Checks if user is available at a specific time
  /// [dateTime] - The date and time to check
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> isAvailableAt(String userId, DateTime dateTime);

  /// Gets social preferences (age ranges, gender preference, etc.)
  /// Returns social preferences data on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> getSocialPreferences(
    String userId,
  );

  /// Updates social preferences
  /// [preferences] - Social preference data
  /// Returns updated preferences on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> updateSocialPreferences(
    String userId,
    Map<String, dynamic> preferences,
  );

  /// Updates preferred age ranges for game partners
  /// [ageRanges] - List of preferred age ranges
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> updatePreferredAgeRanges(
    String userId,
    List<int> ageRanges,
  );

  /// Updates gender preference for game partners
  /// [preference] - Gender preference ('any', 'male', 'female', 'non-binary')
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> updateGenderPreference(
    String userId,
    String? preference,
  );

  /// Gets default preferences template based on criteria
  /// [sportTypes] - Sports the user is interested in
  /// [location] - User's location for location-based defaults
  /// [experience] - User's experience level
  /// Returns default preferences template on success or [Failure] on error
  Future<Either<Failure, UserPreferences>> getDefaultPreferencesTemplate({
    List<String>? sportTypes,
    String? location,
    String? experience,
  });

  /// Applies a preferences template to a user
  /// [template] - Template preferences to apply
  /// [overwriteExisting] - Whether to overwrite existing preferences
  /// Returns updated preferences on success or [Failure] on error
  Future<Either<Failure, UserPreferences>> applyPreferencesTemplate(
    String userId,
    UserPreferences template, {
    bool overwriteExisting = false,
  });

  /// Validates preference data before saving
  /// [preferences] - Preferences data to validate
  /// Returns list of validation errors (empty if valid) on success or [Failure] on error
  Future<Either<Failure, List<String>>> validatePreferences(
    UserPreferences preferences,
  );

  /// Validates availability schedule for conflicts and constraints
  /// [schedule] - Schedule to validate
  /// Returns list of validation errors (empty if valid) on success or [Failure] on error
  Future<Either<Failure, List<String>>> validateAvailabilitySchedule(
    Map<String, List<TimeSlot>> schedule,
  );

  /// Gets preferences that are compatible with another user
  /// Used for matchmaking and game recommendations
  /// [otherUserId] - ID of user to check compatibility with
  /// Returns compatibility data on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> getCompatibilityWith(
    String userId,
    String otherUserId,
  );

  /// Calculates a compatibility score with another user
  /// Returns score from 0.0 to 100.0 on success or [Failure] on error
  Future<Either<Failure, double>> calculateCompatibilityScore(
    String userId,
    String otherUserId,
  );

  /// Imports preferences from external sources
  /// [source] - Source of the data (e.g., 'calendar', 'social_media')
  /// [data] - External preference data
  /// Returns updated preferences on success or [Failure] on error
  Future<Either<Failure, UserPreferences>> importPreferences(
    String userId,
    String source,
    Map<String, dynamic> data,
  );

  /// Exports preferences data for backup or migration
  /// Returns preferences data as JSON on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> exportPreferences(
    String userId,
  );

  /// Updates competitive level preference
  /// [level] - Competitive level from 1 (casual) to 10 (highly competitive)
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> updateCompetitiveLevel(
    String userId,
    int level,
  );

  /// Updates social preference level
  /// [level] - Social preference from 1 (prefer solo) to 10 (very social)
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> updateSocialPreference(
    String userId,
    int level,
  );

  /// Updates advance notice requirement for game invitations
  /// [hours] - Number of hours advance notice required
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> updateAdvanceNoticeHours(
    String userId,
    int hours,
  );

  /// Enables or disables auto-accept for game invitations
  /// [enabled] - Whether to auto-accept invitations that match preferences
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> setAutoAcceptInvitations(
    String userId,
    bool enabled,
  );

  /// Enables or disables automatic matchmaking
  /// [enabled] - Whether to participate in automatic matchmaking
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> setAutoMatchmaking(String userId, bool enabled);
}

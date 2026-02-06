import 'package:dabbler/data/models/core/game_creation_model.dart';

/// Maps GameCreationModel to database payload format
/// Ensures all required fields are present and properly formatted
class GameCreationMapper {
  /// Converts GameCreationModel to the exact format expected by the games table
  /// Returns a Map with all required fields for game creation
  static Map<String, dynamic> toDatabasePayload({
    required GameCreationModel model,
    required String hostUserId,
    required String hostProfileId,
  }) {
    // Validate required fields
    if (model.gameTitle == null || model.gameTitle!.isEmpty) {
      throw Exception('Game title is required');
    }
    if (model.selectedSport == null) {
      throw Exception('Sport selection is required');
    }
    if (model.selectedDate == null) {
      throw Exception('Game date is required');
    }
    if (model.selectedVenueSlot?.timeSlot.startTime == null) {
      throw Exception('Start time is required');
    }
    if (model.selectedVenueSlot?.timeSlot.endTime == null) {
      throw Exception('End time is required');
    }
    if (model.maxPlayers == null) {
      throw Exception('Maximum players is required');
    }
    if (model.skillLevel == null) {
      throw Exception('Skill level is required');
    }
    if (model.participationMode == null) {
      throw Exception('Participation mode is required');
    }

    // Combine date and time into start_at and end_at timestamps
    final startDateTime = DateTime(
      model.selectedDate!.year,
      model.selectedDate!.month,
      model.selectedDate!.day,
      model.selectedVenueSlot!.timeSlot.startTime.hour,
      model.selectedVenueSlot!.timeSlot.startTime.minute,
    );
    final endDateTime = DateTime(
      model.selectedDate!.year,
      model.selectedDate!.month,
      model.selectedDate!.day,
      model.selectedVenueSlot!.timeSlot.endTime.hour,
      model.selectedVenueSlot!.timeSlot.endTime.minute,
    );

    // Parse skill level to integer
    final skillInt = _parseSkillLevelToInt(model.skillLevel!);

    // Map participation mode to listing visibility
    final listingVisibility =
        model.participationMode == ParticipationMode.public
        ? 'public'
        : 'private';

    // Build rules JSON object with payment and other settings
    final rules = <String, dynamic>{
      if (model.paymentSplit != null) 'payment_split': model.paymentSplit!.name,
      if (model.totalCost != null) 'total_cost': model.totalCost,
      if (model.customPaymentSplit != null)
        'custom_payment_split': model.customPaymentSplit,
      if (model.maxWaitlistSize != null)
        'max_waitlist_size': model.maxWaitlistSize,
      if (model.sendReminders != null) 'send_reminders': model.sendReminders,
      if (model.reminderTime != null)
        'reminder_time': model.reminderTime!.toIso8601String(),
    };

    // Prepare game data for database
    final gameData = <String, dynamic>{
      'title': model.gameTitle!,
      'sport': model.selectedSport!,
      'game_type': model.gameType ?? 'pickup', // Default to pickup if not set
      'start_at': startDateTime.toIso8601String(),
      'end_at': endDateTime.toIso8601String(),
      'capacity': model.maxPlayers!,
      'host_user_id': hostUserId,
      'host_profile_id': hostProfileId,
      'min_skill': skillInt,
      'max_skill': skillInt,
      'listing_visibility': listingVisibility,
      'join_policy': 'open', // Default join policy
      'allow_spectators': model.allowSpectators ?? false,
      'is_cancelled': false,
      'allows_waitlist':
          model.allowWaitlist ?? false, // Optional, defaults to false
      'rules': rules,
    };

    // Add optional fields only if provided by user
    if (model.gameDescription != null && model.gameDescription!.isNotEmpty) {
      gameData['description'] = model.gameDescription;
    }

    // Add venue_space_id if selected and is a valid UUID format
    if (model.selectedVenueSlot?.venueId != null) {
      final venueId = model.selectedVenueSlot!.venueId;
      // Check if it's a valid UUID (contains hyphens and is proper length)
      if (venueId.contains('-') && venueId.length >= 36) {
        gameData['venue_space_id'] = venueId;
      }
    }

    return gameData;
  }

  /// Helper method to parse skill level string to integer
  /// Returns skill level as integer: 1=beginner, 2=intermediate, 3=advanced, 0=mixed
  static int _parseSkillLevelToInt(String skillLevel) {
    switch (skillLevel.toLowerCase()) {
      case 'beginner':
        return 1;
      case 'intermediate':
        return 2;
      case 'advanced':
        return 3;
      case 'mixed':
      default:
        return 0;
    }
  }
}

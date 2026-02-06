import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/profile/user_preferences.dart';
import '../../domain/usecases/update_preferences_usecase.dart';
import 'package:dabbler/core/fp/failure.dart';

/// State for user preferences management
class PreferencesState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final UserPreferences? preferences;
  final Map<String, dynamic> pendingChanges;
  final bool hasUnsavedChanges;
  final DateTime? lastSyncTime;
  final double compatibilityScore;

  const PreferencesState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.preferences,
    this.pendingChanges = const {},
    this.hasUnsavedChanges = false,
    this.lastSyncTime,
    this.compatibilityScore = 0.0,
  });

  PreferencesState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    UserPreferences? preferences,
    Map<String, dynamic>? pendingChanges,
    bool? hasUnsavedChanges,
    DateTime? lastSyncTime,
    double? compatibilityScore,
  }) {
    return PreferencesState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      preferences: preferences ?? this.preferences,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
    );
  }
}

/// Controller for user preferences with complex scheduling and validation
class PreferencesController extends StateNotifier<PreferencesState> {
  final UpdatePreferencesUseCase? _updatePreferencesUseCase;

  PreferencesController({UpdatePreferencesUseCase? updatePreferencesUseCase})
    : _updatePreferencesUseCase = updatePreferencesUseCase,
      super(const PreferencesState());

  /// Load user preferences
  Future<void> loadPreferences(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Note: This would typically load from repository
      // For now, we'll create a basic preferences object
      const preferences = UserPreferences(
        userId: '',
        preferredGameTypes: ['basketball', 'soccer'],
        preferredDuration: GameDuration.medium,
        preferredTeamSize: TeamSize.medium,
        maxTravelRadius: 10.0,
        travelWillingness: TravelWillingness.moderate,
        weeklyAvailability: [],
        openToNewPlayers: true,
        ageRangePreference: AgeRangePreference.similar,
        genderMixPreference: GenderMixPreference.mixed,
        preferCompetitive: false,
        preferCasual: true,
      );

      // Calculate initial compatibility score
      final compatibilityScore = _calculateCompatibilityScore(preferences);

      state = state.copyWith(
        isLoading: false,
        preferences: preferences,
        lastSyncTime: DateTime.now(),
        pendingChanges: {},
        hasUnsavedChanges: false,
        compatibilityScore: compatibilityScore,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(error),
      );
    }
  }

  /// Update preferred game types
  Future<void> updateGameTypes(List<String> gameTypes) async {
    if (gameTypes.length > 5) {
      state = state.copyWith(errorMessage: 'You can select up to 5 game types');
      return;
    }

    await _updateField('preferredGameTypes', gameTypes);
  }

  /// Update game duration preference
  Future<void> updateGameDuration(GameDuration duration) async {
    await _updateField(
      'preferredDuration',
      duration.toString().split('.').last,
    );
  }

  /// Update team size preference
  Future<void> updateTeamSize(TeamSize teamSize) async {
    await _updateField(
      'preferredTeamSize',
      teamSize.toString().split('.').last,
    );
  }

  /// Update travel radius
  Future<void> updateTravelRadius(double radius) async {
    if (radius < 1.0 || radius > 100.0) {
      state = state.copyWith(
        errorMessage: 'Travel radius must be between 1-100 miles',
      );
      return;
    }
    await _updateField('maxTravelRadius', radius);
  }

  /// Update travel willingness
  Future<void> updateTravelWillingness(TravelWillingness willingness) async {
    await _updateField(
      'travelWillingness',
      willingness.toString().split('.').last,
    );
  }

  /// Update age range preference
  Future<void> updateAgeRangePreference(AgeRangePreference preference) async {
    await _updateField(
      'ageRangePreference',
      preference.toString().split('.').last,
    );
  }

  /// Update gender mix preference
  Future<void> updateGenderMixPreference(GenderMixPreference preference) async {
    await _updateField(
      'genderMixPreference',
      preference.toString().split('.').last,
    );
  }

  /// Toggle competitive preference
  Future<void> togglePreferCompetitive(bool prefer) async {
    await _updateField('preferCompetitive', prefer);
  }

  /// Toggle casual preference
  Future<void> togglePreferCasual(bool prefer) async {
    await _updateField('preferCasual', prefer);
  }

  /// Toggle openness to new players
  Future<void> toggleOpenToNewPlayers(bool open) async {
    await _updateField('openToNewPlayers', open);
  }

  /// Add time slot to availability
  Future<void> addTimeSlot(TimeSlot timeSlot) async {
    final currentPreferences = state.preferences;
    if (currentPreferences == null) return;

    final currentSlots = List<TimeSlot>.from(
      currentPreferences.weeklyAvailability,
    );

    // Check for overlapping time slots
    final hasOverlap = currentSlots.any(
      (slot) => _timeSlotsOverlap(slot, timeSlot),
    );

    if (hasOverlap) {
      state = state.copyWith(
        errorMessage: 'Time slot overlaps with existing availability',
      );
      return;
    }

    currentSlots.add(timeSlot);
    await _updateField(
      'weeklyAvailability',
      currentSlots.map((s) => s.toJson()).toList(),
    );
  }

  /// Remove time slot from availability
  Future<void> removeTimeSlot(TimeSlot timeSlot) async {
    final currentPreferences = state.preferences;
    if (currentPreferences == null) return;

    final currentSlots = List<TimeSlot>.from(
      currentPreferences.weeklyAvailability,
    );
    currentSlots.removeWhere((slot) => slot == timeSlot);

    await _updateField(
      'weeklyAvailability',
      currentSlots.map((s) => s.toJson()).toList(),
    );
  }

  /// Save all pending changes
  Future<bool> saveAllChanges() async {
    if (state.preferences == null || !state.hasUnsavedChanges) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final params = UpdatePreferencesParams(
        userId: 'current-user-id', // Would come from auth
        preferredGameTypes:
            state.pendingChanges['preferredGameTypes'] as List<String>?,
        maxTravelDistance: state.pendingChanges['maxTravelRadius'] as double?,
      );

      if (_updatePreferencesUseCase == null) {
        state = state.copyWith(isSaving: false, lastSyncTime: DateTime.now());
        return true;
      }

      final result = await _updatePreferencesUseCase.call(params);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: _getFailureMessage(failure),
          );
          return false;
        },
        (updateResult) {
          // Recalculate compatibility score
          final compatibilityScore = _calculateCompatibilityScore(
            updateResult.updatedPreferences,
          );

          state = state.copyWith(
            isSaving: false,
            preferences: updateResult.updatedPreferences,
            pendingChanges: {},
            hasUnsavedChanges: false,
            lastSyncTime: DateTime.now(),
            compatibilityScore: compatibilityScore,
          );

          return true;
        },
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _getErrorMessage(error),
      );
      return false;
    }
  }

  /// Reset preferences to defaults
  Future<void> resetToDefaults() async {
    const defaultPreferences = UserPreferences(userId: '');

    final allChanges = {
      'preferredGameTypes': defaultPreferences.preferredGameTypes,
      'preferredDuration': defaultPreferences.preferredDuration
          .toString()
          .split('.')
          .last,
      'preferredTeamSize': defaultPreferences.preferredTeamSize
          .toString()
          .split('.')
          .last,
      'maxTravelRadius': defaultPreferences.maxTravelRadius,
      'travelWillingness': defaultPreferences.travelWillingness
          .toString()
          .split('.')
          .last,
      'openToNewPlayers': defaultPreferences.openToNewPlayers,
      'ageRangePreference': defaultPreferences.ageRangePreference
          .toString()
          .split('.')
          .last,
      'genderMixPreference': defaultPreferences.genderMixPreference
          .toString()
          .split('.')
          .last,
      'preferCompetitive': defaultPreferences.preferCompetitive,
      'preferCasual': defaultPreferences.preferCasual,
    };

    final compatibilityScore = _calculateCompatibilityScore(defaultPreferences);

    state = state.copyWith(
      preferences: defaultPreferences,
      pendingChanges: allChanges,
      hasUnsavedChanges: true,
      compatibilityScore: compatibilityScore,
    );
  }

  /// Get availability for a specific day
  List<TimeSlot> getAvailabilityForDay(int dayOfWeek) {
    final preferences = state.preferences;
    if (preferences == null) return [];

    return preferences.weeklyAvailability
        .where((slot) => slot.dayOfWeek == dayOfWeek)
        .toList();
  }

  /// Check if user is available at specific time
  bool isAvailableAt(DateTime dateTime) {
    final preferences = state.preferences;
    if (preferences == null) return false;

    return preferences.weeklyAvailability.any(
      (slot) => slot.isAvailable(dateTime),
    );
  }

  /// Get total hours of availability per week
  double get totalWeeklyAvailability {
    final preferences = state.preferences;
    if (preferences == null) return 0.0;

    double totalHours = 0.0;

    for (final slot in preferences.weeklyAvailability) {
      final duration = slot.endHour - slot.startHour;
      totalHours += duration.toDouble();
    }

    return totalHours;
  }

  /// Get preferences summary for display
  Map<String, dynamic> get preferencesSummary {
    final preferences = state.preferences;
    if (preferences == null) return {};

    return {
      'gameTypes': preferences.preferredGameTypes.length,
      'duration': preferences.preferredDuration.toString().split('.').last,
      'teamSize': preferences.preferredTeamSize.toString().split('.').last,
      'travelRadius': '${preferences.maxTravelRadius.toInt()} mi',
      'weeklyAvailability': '${totalWeeklyAvailability.toInt()} hours',
      'openToNewPlayers': preferences.openToNewPlayers ? 'Yes' : 'No',
      'agePreference': preferences.ageRangePreference
          .toString()
          .split('.')
          .last,
      'genderPreference': preferences.genderMixPreference
          .toString()
          .split('.')
          .last,
      'competitiveLevel': preferences.preferCompetitive
          ? 'Competitive'
          : 'Casual',
      'compatibilityScore': state.compatibilityScore.toInt(),
    };
  }

  /// Update a single field
  Future<void> _updateField(String field, dynamic value) async {
    await _updateFields({field: value});
  }

  /// Update multiple fields
  Future<void> _updateFields(Map<String, dynamic> fields) async {
    final currentPreferences = state.preferences;
    if (currentPreferences == null) return;

    final updatedPendingChanges = Map<String, dynamic>.from(
      state.pendingChanges,
    );
    updatedPendingChanges.addAll(fields);

    // Apply changes to current preferences for immediate UI update
    UserPreferences updatedPreferences = currentPreferences;

    for (final entry in fields.entries) {
      switch (entry.key) {
        case 'preferredGameTypes':
          updatedPreferences = updatedPreferences.copyWith(
            preferredGameTypes: entry.value as List<String>,
          );
          break;
        case 'preferredDuration':
          final duration = GameDuration.values.firstWhere(
            (e) => e.toString().split('.').last == entry.value,
            orElse: () => GameDuration.any,
          );
          updatedPreferences = updatedPreferences.copyWith(
            preferredDuration: duration,
          );
          break;
        case 'preferredTeamSize':
          final teamSize = TeamSize.values.firstWhere(
            (e) => e.toString().split('.').last == entry.value,
            orElse: () => TeamSize.any,
          );
          updatedPreferences = updatedPreferences.copyWith(
            preferredTeamSize: teamSize,
          );
          break;
        case 'maxTravelRadius':
          updatedPreferences = updatedPreferences.copyWith(
            maxTravelRadius: entry.value as double,
          );
          break;
        case 'travelWillingness':
          final willingness = TravelWillingness.values.firstWhere(
            (e) => e.toString().split('.').last == entry.value,
            orElse: () => TravelWillingness.moderate,
          );
          updatedPreferences = updatedPreferences.copyWith(
            travelWillingness: willingness,
          );
          break;
        case 'openToNewPlayers':
          updatedPreferences = updatedPreferences.copyWith(
            openToNewPlayers: entry.value as bool,
          );
          break;
        case 'preferCompetitive':
          updatedPreferences = updatedPreferences.copyWith(
            preferCompetitive: entry.value as bool,
          );
          break;
        case 'preferCasual':
          updatedPreferences = updatedPreferences.copyWith(
            preferCasual: entry.value as bool,
          );
          break;
      }
    }

    final compatibilityScore = _calculateCompatibilityScore(updatedPreferences);

    state = state.copyWith(
      preferences: updatedPreferences,
      pendingChanges: updatedPendingChanges,
      hasUnsavedChanges: true,
      compatibilityScore: compatibilityScore,
    );
  }

  /// Calculate compatibility score based on preferences completeness
  double _calculateCompatibilityScore(UserPreferences preferences) {
    double score = 0.0;

    // Game types (20%)
    score += (preferences.preferredGameTypes.isNotEmpty ? 20.0 : 0.0);

    // Duration and team size preferences (20%)
    if (preferences.preferredDuration != GameDuration.any) score += 10.0;
    if (preferences.preferredTeamSize != TeamSize.any) score += 10.0;

    // Travel preferences (15%)
    if (preferences.maxTravelRadius > 0) score += 15.0;

    // Availability (25%)
    final weeklyHours = totalWeeklyAvailability;
    if (weeklyHours > 0) {
      score += (weeklyHours * 2.5).clamp(0.0, 25.0); // Max 25 points
    }

    // Social preferences (20%)
    if (preferences.ageRangePreference != AgeRangePreference.any) score += 10.0;
    if (preferences.genderMixPreference != GenderMixPreference.any) {
      score += 10.0;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Check if two time slots overlap
  bool _timeSlotsOverlap(TimeSlot slot1, TimeSlot slot2) {
    if (slot1.dayOfWeek != slot2.dayOfWeek) return false;

    return slot1.startHour < slot2.endHour && slot2.startHour < slot1.endHour;
  }

  /// Convert error to user-friendly message
  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  /// Convert failure to user-friendly message
  String _getFailureMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ValidationFailure:
        return failure.message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      case ServerFailure:
        return 'Server error. Please try again later.';
      default:
        return failure.message;
    }
  }
}

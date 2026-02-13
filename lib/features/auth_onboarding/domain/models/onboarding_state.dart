import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_state.freezed.dart';

/// Represents the current step in the onboarding flow
enum OnboardingStep {
  /// Initial state - checking if user needs onboarding
  checking,

  /// User has 2 profiles - should go to profile switcher
  completed,

  /// Collecting basic info (age, gender)
  collectingBasicInfo,

  /// User selecting persona (player/organiser/host)
  selectingPersona,

  /// Creating profile in DB (FIRST DB WRITE)
  creatingProfile,

  /// Creating persona extension table row (SECOND DB WRITE)
  creatingPersonaExtension,

  /// User selecting primary sport
  selectingPrimarySport,

  /// Creating sport_profiles entry (THIRD DB WRITE)
  creatingSportProfile,

  /// Finalizing onboarding (LAST DB WRITE)
  finalizing,

  /// Error occurred - can retry
  error,
}

/// Collected onboarding data (in-memory until profile creation)
@freezed
class OnboardingData with _$OnboardingData {
  const factory OnboardingData({
    // Basic info
    int? age,
    String? gender, // 'male' | 'female'
    // Persona
    String? personaType, // 'player' | 'organiser' | 'host'
    // Profile info
    String? displayName,
    String? username,
    String? city,
    String? country,
    String? language,

    // Sports
    String? preferredSport, // Single preferred sport slug
    List<String>? interestsSlugs, // List of sports.slug
    String? primarySportId, // UUID from sports.id
    // DB state
    String? profileId, // Set after profile creation
    bool? personaExtensionCreated,
    bool? sportProfileCreated,
  }) = _OnboardingData;

  const OnboardingData._();

  /// Check if basic info is complete
  bool get hasBasicInfo => age != null && gender != null;

  /// Check if persona is selected
  bool get hasPersona => personaType != null;

  /// Check if profile data is ready for creation
  bool get canCreateProfile =>
      hasBasicInfo && hasPersona && username != null && displayName != null;

  /// Check if profile exists in DB
  bool get hasProfile => profileId != null;
}

/// Onboarding state for the controller
@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(OnboardingStep.checking) OnboardingStep step,
    @Default(OnboardingData()) OnboardingData data,
    @Default(false) bool isLoading,
    String? error,

    // Resume info
    int? existingProfileCount,
    bool? hasIncompleteOnboarding,
  }) = _OnboardingState;

  const OnboardingState._();

  /// Create state with loading
  OnboardingState setLoading(bool loading) =>
      copyWith(isLoading: loading, error: null);

  /// Create state with error
  OnboardingState setError(String errorMessage) => copyWith(
    step: OnboardingStep.error,
    isLoading: false,
    error: errorMessage,
  );

  /// Move to next step
  OnboardingState nextStep(OnboardingStep next) =>
      copyWith(step: next, isLoading: false, error: null);
}

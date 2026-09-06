import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_state.dart';
import 'package:dabbler/features/auth_onboarding/data/repositories/onboarding_repository.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';

/// Provider for onboarding repository
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository();
});

/// Provider for onboarding controller
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
      return OnboardingController(
        repository: ref.watch(onboardingRepositoryProvider),
      );
    });

/// Controller for onboarding flow
///
/// The single onboarding write path is the transactional RPC from KAN-48.
/// This controller's remaining job is narrowly to resume a legacy damaged
/// row from before that RPC existed (T-037/T-038) — it has no write half.
class OnboardingController extends StateNotifier<OnboardingState> {
  final OnboardingRepository _repository;

  OnboardingController({required OnboardingRepository repository})
    : _repository = repository,
      super(const OnboardingState());

  /// ═══════════════════════════════════════════════════════════════
  /// RESUME CHECK (Called on app start after auth)
  /// ═══════════════════════════════════════════════════════════════

  /// Check DB state and determine where to resume onboarding
  ///
  /// Logic:
  /// - 0 profiles → start from beginning
  /// - 1 profile with onboard=false → resume from incomplete step
  /// - 1 profile with onboard=true → onboarding complete
  /// - 2 profiles → go to profile switcher
  Future<void> checkResumeState() async {
    state = state.setLoading(true);
    routerRefreshNotifier.notifyAuthStateChanged();

    final result = await _repository.getUserProfiles();

    result.fold(
      // Error loading profiles
      (failure) {
        final failureMsg = (failure as Failure?)?.message ?? 'Unknown error';
        state = state.setError('Failed to load profile: $failureMsg');
        routerRefreshNotifier.notifyAuthStateChanged();
      },

      // Success - determine state
      (profiles) async {
        final profileCount = profiles.length;

        // Case 1: 2 profiles → onboarding complete, go to switcher
        if (profileCount >= 2) {
          state = state.copyWith(
            step: OnboardingStep.completed,
            existingProfileCount: profileCount,
            isLoading: false,
          );
          routerRefreshNotifier.notifyAuthStateChanged();
          return;
        }

        // Case 2: 0 profiles → start fresh
        if (profileCount == 0) {
          state = state.nextStep(OnboardingStep.collectingBasicInfo);
          routerRefreshNotifier.notifyAuthStateChanged();
          return;
        }

        // Case 3: 1 profile → check completion status
        final profile = profiles.first;
        final onboardComplete = profile['onboard'] as bool? ?? false;

        if (onboardComplete) {
          // Onboarding already complete
          state = state.copyWith(
            step: OnboardingStep.completed,
            existingProfileCount: 1,
            isLoading: false,
          );
          routerRefreshNotifier.notifyAuthStateChanged();
          return;
        }

        // Profile exists but onboarding incomplete → RESUME
        await _resumeFromProfile(profile);
      },
    );
  }

  /// Resume onboarding from existing incomplete profile
  Future<void> _resumeFromProfile(Map<String, dynamic> profile) async {
    final profileId = profile['id'] as String;
    // Nullable: `persona_type` is NULL on legacy damaged rows (T-038
    // Decision 5). A non-nullable cast here threw inside this `unawaited`
    // future, i.e. an unhandled async error instead of a redirect.
    final personaType = profile['persona_type'] as String?;

    // Restore data from DB
    final restoredData = OnboardingData(
      profileId: profileId,
      personaType: personaType,
      age: profile['age'] as int?,
      gender: profile['gender'] as String?,
      displayName: profile['display_name'] as String?,
      username: profile['username'] as String?,
      city: profile['city'] as String?,
      country: profile['country'] as String?,
      language: profile['language'] as String?,
      preferredSport: profile['preferred_sport'] as String?,
      interestIds: (profile['interests'] as List?)?.cast<String>(),
      primarySportId: profile['primary_sport'] as String?,
    );

    // Determine resume point based on what's completed
    OnboardingStep resumeStep;

    // Check if persona extension exists. A NULL persona_type means there
    // is no persona table to check — treat as no extension, without
    // throwing.
    final hasPersonaExtension = personaType == null
        ? false
        : (await _repository.personaExtensionExists(
            profileId: profileId,
            personaType: personaType,
          )).fold((_) => false, (exists) => exists);

    // Check if sport_profiles exists
    final sportExists = await _repository.sportProfileExists(
      profileId: profileId,
    );
    final hasSportProfile = sportExists.fold((_) => false, (exists) => exists);

    // Resume logic — branches on facts (persona-extension and sport-profile
    // existence), not `profile_completion`, which is NULL on every production
    // row (T-038 Decision 5) and made these branches unreachable.
    final needsSportProfile = personaType == 'player';

    if (!hasPersonaExtension) {
      // Profile created but persona extension missing
      resumeStep = OnboardingStep.creatingPersonaExtension;
    } else if (needsSportProfile && !hasSportProfile) {
      // Persona created but sport profile missing (players only)
      resumeStep = OnboardingStep.selectingPrimarySport;
    } else {
      // Persona extension exists, and sport profile exists or isn't required
      resumeStep = OnboardingStep.finalizing;
    }

    state = state.copyWith(
      step: resumeStep,
      data: restoredData.copyWith(
        personaExtensionCreated: hasPersonaExtension,
        sportProfileCreated: hasSportProfile,
      ),
      existingProfileCount: 1,
      hasIncompleteOnboarding: true,
      isLoading: false,
    );
    routerRefreshNotifier.notifyAuthStateChanged();
  }
}

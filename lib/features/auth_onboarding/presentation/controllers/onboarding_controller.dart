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
/// CRITICAL RESPONSIBILITIES:
/// 1. Check resume state on init
/// 2. Guide user through steps
/// 3. Ensure idempotent DB writes
/// 4. Handle errors gracefully
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
    final personaType = profile['persona_type'] as String;
    final profileCompletion = profile['profile_completion'] as String?;

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
      interestsSlugs: (profile['interests'] as List?)?.cast<String>(),
      primarySportId: profile['primary_sport_id'] as String?,
    );

    // Determine resume point based on what's completed
    OnboardingStep resumeStep;

    // Check if persona extension exists
    final personaExists = await _repository.personaExtensionExists(
      profileId: profileId,
      personaType: personaType,
    );
    final hasPersonaExtension = personaExists.fold(
      (_) => false,
      (exists) => exists,
    );

    // Check if sport_profiles exists
    final sportExists = await _repository.sportProfileExists(
      profileId: profileId,
    );
    final hasSportProfile = sportExists.fold((_) => false, (exists) => exists);

    // Resume logic
    if (profileCompletion == 'started' && !hasPersonaExtension) {
      // Profile created but persona extension missing
      resumeStep = OnboardingStep.creatingPersonaExtension;
    } else if (!hasSportProfile) {
      // Persona created but sport profile missing
      resumeStep = OnboardingStep.selectingPrimarySport;
    } else if (profileCompletion == 'sport_added') {
      // Everything exists, just need to finalize
      resumeStep = OnboardingStep.finalizing;
    } else {
      // Unknown state - restart from persona selection
      resumeStep = OnboardingStep.selectingPersona;
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

    // Auto-execute pending DB writes if needed
    if (resumeStep == OnboardingStep.creatingPersonaExtension) {
      await createPersonaExtension();
    } else if (resumeStep == OnboardingStep.finalizing) {
      await finalizeOnboarding();
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 2: Collect Basic Info
  /// ═══════════════════════════════════════════════════════════════

  void setBasicInfo({required int age, required String gender}) {
    state = state.copyWith(
      data: state.data.copyWith(age: age, gender: gender),
    );
  }

  void nextFromBasicInfo() {
    if (!state.data.hasBasicInfo) {
      state = state.setError('Please provide age and gender');
      routerRefreshNotifier.notifyAuthStateChanged();
      return;
    }
    state = state.nextStep(OnboardingStep.selectingPersona);
    routerRefreshNotifier.notifyAuthStateChanged();
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 3: Select Persona
  /// ═══════════════════════════════════════════════════════════════

  void selectPersona(String personaType) {
    if (!['player', 'organiser', 'host'].contains(personaType)) {
      state = state.setError('Invalid persona type');
      routerRefreshNotifier.notifyAuthStateChanged();
      return;
    }

    state = state.copyWith(data: state.data.copyWith(personaType: personaType));
    routerRefreshNotifier.notifyAuthStateChanged();
  }

  /// Set additional profile data before creation
  void setProfileData({
    required String username,
    required String displayName,
    String? city,
    String? country,
    String? language,
    String? preferredSport,
    List<String>? interestsSlugs,
  }) {
    state = state.copyWith(
      data: state.data.copyWith(
        username: username,
        displayName: displayName,
        city: city,
        country: country,
        language: language,
        preferredSport: preferredSport,
        interestsSlugs: interestsSlugs,
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 4: Create Profile (FIRST DB WRITE)
  /// ═══════════════════════════════════════════════════════════════

  Future<void> createProfile() async {
    if (!state.data.canCreateProfile) {
      state = state.setError('Missing required profile data');
      routerRefreshNotifier.notifyAuthStateChanged();
      return;
    }

    state = state.setLoading(true);
    routerRefreshNotifier.notifyAuthStateChanged();

    final result = await _repository.createProfile(
      personaType: state.data.personaType!,
      username: state.data.username!,
      displayName: state.data.displayName!,
      age: state.data.age!,
      gender: state.data.gender!,
      city: state.data.city,
      country: state.data.country,
      language: state.data.language,
      preferredSport: state.data.preferredSport,
      interestsSlugs: state.data.interestsSlugs,
    );

    result.fold(
      (failure) {
        final failureMsg = (failure as Failure?)?.message ?? 'Unknown error';
        state = state.setError('Failed to create profile: $failureMsg');
        routerRefreshNotifier.notifyAuthStateChanged();
      },
      (profile) {
        final profileId = profile['id'] as String;
        state = state.copyWith(
          data: state.data.copyWith(profileId: profileId),
          step: OnboardingStep.creatingPersonaExtension,
          isLoading: false,
        );

        routerRefreshNotifier.notifyAuthStateChanged();

        // Auto-proceed to next DB write
        createPersonaExtension();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 5: Create Persona Extension (SECOND DB WRITE)
  /// ═══════════════════════════════════════════════════════════════

  Future<void> createPersonaExtension() async {
    if (state.data.profileId == null || state.data.personaType == null) {
      state = state.setError('Missing profile ID or persona type');
      routerRefreshNotifier.notifyAuthStateChanged();
      return;
    }

    state = state.setLoading(true);
    routerRefreshNotifier.notifyAuthStateChanged();

    final result = await _repository.createPersonaExtension(
      profileId: state.data.profileId!,
      personaType: state.data.personaType!,
    );

    result.fold(
      (failure) {
        final failureMsg = (failure as Failure?)?.message ?? 'Unknown error';
        state = state.setError(
          'Failed to create persona extension: $failureMsg',
        );
        routerRefreshNotifier.notifyAuthStateChanged();
      },
      (_) {
        state = state.copyWith(
          data: state.data.copyWith(personaExtensionCreated: true),
          step: OnboardingStep.selectingPrimarySport,
          isLoading: false,
        );
        routerRefreshNotifier.notifyAuthStateChanged();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 6: Select Primary Sport & Create Sport Profile
  /// ═══════════════════════════════════════════════════════════════

  void selectPrimarySport(String sportId) {
    state = state.copyWith(data: state.data.copyWith(primarySportId: sportId));
  }

  Future<void> createSportProfile() async {
    if (state.data.profileId == null || state.data.primarySportId == null) {
      state = state.setError('Missing profile ID or sport ID');
      routerRefreshNotifier.notifyAuthStateChanged();
      return;
    }

    state = state.setLoading(true);
    routerRefreshNotifier.notifyAuthStateChanged();

    final result = await _repository.createSportProfile(
      profileId: state.data.profileId!,
      sportId: state.data.primarySportId!,
    );

    result.fold(
      (failure) {
        final failureMsg = (failure as Failure?)?.message ?? 'Unknown error';
        state = state.setError('Failed to create sport profile: $failureMsg');
        routerRefreshNotifier.notifyAuthStateChanged();
      },
      (_) {
        state = state.copyWith(
          data: state.data.copyWith(sportProfileCreated: true),
          step: OnboardingStep.finalizing,
          isLoading: false,
        );

        routerRefreshNotifier.notifyAuthStateChanged();

        // Auto-finalize
        finalizeOnboarding();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 7: Finalize Onboarding (LAST DB WRITE)
  /// ═══════════════════════════════════════════════════════════════

  Future<void> finalizeOnboarding() async {
    if (state.data.profileId == null) {
      state = state.setError('Missing profile ID');
      routerRefreshNotifier.notifyAuthStateChanged();
      return;
    }

    state = state.setLoading(true);
    routerRefreshNotifier.notifyAuthStateChanged();

    final result = await _repository.finalizeOnboarding(
      profileId: state.data.profileId!,
    );

    result.fold(
      (failure) {
        final failureMsg = (failure as Failure?)?.message ?? 'Unknown error';
        state = state.setError('Failed to finalize onboarding: $failureMsg');
        routerRefreshNotifier.notifyAuthStateChanged();
      },
      (_) {
        state = state.copyWith(
          step: OnboardingStep.completed,
          isLoading: false,
        );
        routerRefreshNotifier.notifyAuthStateChanged();
      },
    );
  }

  /// Reset error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset entire onboarding (for testing/debugging only)
  void reset() {
    state = const OnboardingState();
  }
}

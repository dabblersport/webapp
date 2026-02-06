import 'package:dabbler/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/profile/user_profile.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/calculate_profile_completion_usecase.dart';
import 'package:dabbler/core/fp/failure.dart';

/// State for the main profile controller
class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final double completionPercentage;
  final List<String> completionRecommendations;
  final DateTime? lastUpdated;
  final bool hasUnsavedChanges;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.completionPercentage = 0.0,
    this.completionRecommendations = const [],
    this.lastUpdated,
    this.hasUnsavedChanges = false,
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    double? completionPercentage,
    List<String>? completionRecommendations,
    DateTime? lastUpdated,
    bool? hasUnsavedChanges,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      completionRecommendations:
          completionRecommendations ?? this.completionRecommendations,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileState &&
        other.profile == profile &&
        other.isLoading == isLoading &&
        other.isRefreshing == isRefreshing &&
        other.errorMessage == errorMessage &&
        other.completionPercentage == completionPercentage &&
        other.lastUpdated == lastUpdated &&
        other.hasUnsavedChanges == hasUnsavedChanges;
  }

  @override
  int get hashCode {
    return Object.hash(
      profile,
      isLoading,
      isRefreshing,
      errorMessage,
      completionPercentage,
      lastUpdated,
      hasUnsavedChanges,
    );
  }
}

/// Main profile controller managing user profile state
class ProfileController extends StateNotifier<ProfileState> {
  final GetProfileUseCase _getProfileUseCase;
  final UpdateProfileUseCase? _updateProfileUseCase;
  final CalculateProfileCompletionUseCase? _calculateCompletionUseCase;

  ProfileController({
    required GetProfileUseCase getProfileUseCase,
    UpdateProfileUseCase? updateProfileUseCase,
    CalculateProfileCompletionUseCase? calculateCompletionUseCase,
  }) : _getProfileUseCase = getProfileUseCase,
       _updateProfileUseCase = updateProfileUseCase,
       _calculateCompletionUseCase = calculateCompletionUseCase,
       super(const ProfileState());

  /// Initialize profile loading
  Future<void> initialize(String userId) async {
    if (state.profile?.id == userId && !_shouldRefresh()) {
      return; // Profile already loaded and fresh
    }

    await loadProfile(userId);
  }

  /// Load user profile from repository
  Future<void> loadProfile(String userId, {String? profileType}) async {
    state = state.copyWith(
      isLoading: state.profile == null,
      isRefreshing: state.profile != null,
      errorMessage: null,
    );

    try {
      final profile = await _getProfileUseCase(
        userId,
        profileType: profileType,
      );
      if (profile != null) {
        await _updateProfileCompletion(profile);
        state = state.copyWith(
          profile: profile,
          isLoading: false,
          isRefreshing: false,
          lastUpdated: DateTime.now(),
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: 'Profile not found.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    if (state.profile == null) return;
    await loadProfile(state.profile!.id);
  }

  /// Update profile with new data
  Future<bool> updateProfile(UpdateProfileParams params) async {
    if (state.profile == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // For now, return a mock result if use case is not provided
      if (_updateProfileUseCase == null) {
        // Mock successful update
        state = state.copyWith(
          isLoading: false,
          lastUpdated: DateTime.now(),
          hasUnsavedChanges: false,
        );
        return true;
      }

      final result = await _updateProfileUseCase.call(params);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: _getFailureMessage(failure),
          );
          return false;
        },
        (updateResult) {
          state = state.copyWith(
            profile: updateResult.updatedProfile,
            isLoading: false,
            lastUpdated: DateTime.now(),
            completionPercentage: updateResult.completionPercentage,
            hasUnsavedChanges: false,
          );

          // Show warnings if any
          if (updateResult.warnings.isNotEmpty) {}

          return true;
        },
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(error),
      );
      return false;
    }
  }

  /// Update profile completion calculation
  Future<void> _updateProfileCompletion(UserProfile profile) async {
    try {
      final params = CalculateProfileCompletionParams(profile: profile);
      // For now, return mock result if use case is not provided
      if (_calculateCompletionUseCase == null) {
        state = state.copyWith(
          completionPercentage: 75.0,
          completionRecommendations: [
            'Add profile photo',
            'Complete sports profiles',
          ],
        );
        return;
      }

      final result = _calculateCompletionUseCase.call(params);

      result.fold(
        (failure) {
          // Silently fail completion calculation - not critical
        },
        (completionResult) {
          state = state.copyWith(
            completionPercentage: completionResult.completionPercentage,
            completionRecommendations: completionResult.recommendations,
          );
        },
      );
    } catch (error) {
      // Silently fail completion calculation - not critical
    }
  }

  /// Mark profile as having unsaved changes
  void markAsDirty() {
    if (!state.hasUnsavedChanges) {
      state = state.copyWith(hasUnsavedChanges: true);
    }
  }

  /// Clear unsaved changes flag
  void markAsClean() {
    if (state.hasUnsavedChanges) {
      state = state.copyWith(hasUnsavedChanges: false);
    }
  }

  /// Clear error state
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  /// Check if profile data should be refreshed
  bool _shouldRefresh() {
    if (state.lastUpdated == null) return true;

    final now = DateTime.now();
    final difference = now.difference(state.lastUpdated!);

    // Refresh if data is older than 5 minutes
    return difference.inMinutes > 5;
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
      case NotFoundFailure:
        return 'Profile not found.';
      default:
        return failure.message;
    }
  }

  /// Get profile completion status text
  String get completionStatusText {
    final percentage = state.completionPercentage;
    if (percentage >= 90) return 'Excellent profile!';
    if (percentage >= 70) return 'Good profile';
    if (percentage >= 50) return 'Decent profile';
    if (percentage >= 25) return 'Basic profile';
    return 'Incomplete profile';
  }

  /// Get next recommended action
  String? get nextRecommendedAction {
    if (state.completionRecommendations.isEmpty) return null;
    return state.completionRecommendations.first;
  }

  /// Check if profile has critical missing information
  bool get hasCriticalMissingInfo {
    final profile = state.profile;
    if (profile == null) return true;

    return profile.displayName.isEmpty ||
        (profile.email?.isEmpty ?? true) ||
        profile.bio?.isEmpty != false ||
        profile.city?.isEmpty != false;
  }

  /// Get profile strength score (0-100)
  int get profileStrengthScore {
    return state.completionPercentage.round();
  }

  /// Check if user can participate in games
  bool get canParticipateInGames {
    final profile = state.profile;
    if (profile == null) return false;

    return profile.displayName.isNotEmpty &&
        profile.city?.isNotEmpty == true &&
        state.completionPercentage >= 40; // Minimum 40% completion required
  }
}

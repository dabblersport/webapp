import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/profile/privacy_settings.dart';
import '../../domain/usecases/manage_privacy_usecase.dart';
import 'package:dabbler/core/fp/failure.dart';

/// State for privacy management
class PrivacyState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final PrivacySettings? settings;
  final Map<String, dynamic> pendingChanges;
  final bool hasUnsavedChanges;
  final DateTime? lastSyncTime;
  final double privacyScore;
  final List<String> securityWarnings;

  const PrivacyState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.settings,
    this.pendingChanges = const {},
    this.hasUnsavedChanges = false,
    this.lastSyncTime,
    this.privacyScore = 0.0,
    this.securityWarnings = const [],
  });

  PrivacyState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    PrivacySettings? settings,
    Map<String, dynamic>? pendingChanges,
    bool? hasUnsavedChanges,
    DateTime? lastSyncTime,
    double? privacyScore,
    List<String>? securityWarnings,
  }) {
    return PrivacyState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      settings: settings ?? this.settings,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      privacyScore: privacyScore ?? this.privacyScore,
      securityWarnings: securityWarnings ?? this.securityWarnings,
    );
  }
}

/// Controller for privacy settings management
class PrivacyController extends StateNotifier<PrivacyState> {
  final ManagePrivacyUseCase? _managePrivacyUseCase;

  PrivacyController({ManagePrivacyUseCase? managePrivacyUseCase})
    : _managePrivacyUseCase = managePrivacyUseCase,
      super(const PrivacyState());

  /// Load privacy settings
  Future<void> loadPrivacySettings(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      const settings = PrivacySettings(
        profileVisibility: ProfileVisibility.friends,
        showRealName: true,
        showAge: false,
        showLocation: true,
        showPhone: false,
        showEmail: false,
        showStats: true,
        showSportsProfiles: true,
        showGameHistory: true,
        showAchievements: true,
        messagePreference: CommunicationPreference.anyone,
        gameInvitePreference: CommunicationPreference.anyone,
        allowLocationTracking: true,
        allowDataAnalytics: true,
        dataSharingLevel: DataSharingLevel.limited,
        blockedUsers: [],
        showOnlineStatus: true,
        allowGameRecommendations: true,
      );

      final privacyScore = _calculatePrivacyScore(settings);
      final securityWarnings = _generateSecurityWarnings(settings);

      state = state.copyWith(
        isLoading: false,
        settings: settings,
        lastSyncTime: DateTime.now(),
        pendingChanges: {},
        hasUnsavedChanges: false,
        privacyScore: privacyScore,
        securityWarnings: securityWarnings,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(error),
      );
    }
  }

  /// Save all pending changes
  Future<bool> saveAllChanges() async {
    if (state.settings == null || !state.hasUnsavedChanges) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      // If no use case provided, return mock success
      if (_managePrivacyUseCase == null) {
        state = state.copyWith(
          isSaving: false,
          pendingChanges: {},
          hasUnsavedChanges: false,
          lastSyncTime: DateTime.now(),
        );
        return true;
      }

      final params = ManagePrivacyParams(
        userId: 'current-user-id',
        profileVisibility: state.pendingChanges['profileVisibility'] as bool?,
        showEmail: state.pendingChanges['showEmail'] as bool?,
        showPhoneNumber: state.pendingChanges['showPhone'] as bool?,
        showLocation: state.pendingChanges['showLocation'] as bool?,
        showAge: state.pendingChanges['showAge'] as bool?,
        showStatistics: state.pendingChanges['showStats'] as bool?,
        allowDirectMessages: state.pendingChanges['messagePreference'] as bool?,
        allowGameInvitations:
            state.pendingChanges['gameInvitePreference'] as bool?,
        shareDataWithPartners:
            state.pendingChanges['dataSharingLevel'] as bool?,
        allowAnalytics: state.pendingChanges['allowDataAnalytics'] as bool?,
        blockedUsers: state.pendingChanges['blockedUsers'] as List<String>?,
      );

      final result = await _managePrivacyUseCase.call(params);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: _getFailureMessage(failure),
          );
          return false;
        },
        (updateResult) {
          final privacyScore = _calculatePrivacyScore(
            updateResult.updatedSettings,
          );
          final securityWarnings = _generateSecurityWarnings(
            updateResult.updatedSettings,
          );

          state = state.copyWith(
            isSaving: false,
            settings: updateResult.updatedSettings,
            pendingChanges: {},
            hasUnsavedChanges: false,
            lastSyncTime: DateTime.now(),
            privacyScore: privacyScore,
            securityWarnings: securityWarnings,
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

  /// Calculate privacy score (0-100)
  double _calculatePrivacyScore(PrivacySettings settings) {
    double score = 0.0;

    // Profile visibility (25 points)
    switch (settings.profileVisibility) {
      case ProfileVisibility.private:
        score += 25.0;
        break;
      case ProfileVisibility.friends:
        score += 15.0;
        break;
      case ProfileVisibility.public:
        score += 5.0;
        break;
    }

    // Personal info visibility (30 points)
    if (!settings.showRealName) score += 5.0;
    if (!settings.showAge) score += 5.0;
    if (!settings.showLocation) score += 5.0;
    if (!settings.showPhone) score += 8.0;
    if (!settings.showEmail) score += 7.0;

    return score.clamp(0.0, 100.0);
  }

  /// Generate security warnings
  List<String> _generateSecurityWarnings(PrivacySettings settings) {
    final warnings = <String>[];

    if (settings.profileVisibility == ProfileVisibility.public) {
      warnings.add('Your profile is publicly visible');
    }

    if (settings.showPhone) {
      warnings.add('Phone number is visible to others');
    }

    if (settings.showEmail) {
      warnings.add('Email address is visible to others');
    }

    return warnings;
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

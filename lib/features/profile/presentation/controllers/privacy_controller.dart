import 'package:dabbler/core/offline/sync/queueable_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/data/models/profile/privacy_settings_model.dart';
import '../../domain/usecases/manage_privacy_usecase.dart';
import '../../data/repositories/settings_repository_impl.dart';
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
  final SettingsRepositoryImpl? _settingsRepository;

  /// [sync] / [accountId] (KAN-608): a change is applied on the device at
  /// once, stored in the offline queue with its edit time and sent when the
  /// connection allows; without them it is written through as before.
  PrivacyController({
    ManagePrivacyUseCase? managePrivacyUseCase,
    SettingsRepositoryImpl? settingsRepository,
    SettingsSyncNotifier? sync,
    String? accountId,
    OfflineCache? cache,
  }) : _managePrivacyUseCase = managePrivacyUseCase,
       _settingsRepository = settingsRepository,
       _sync = sync,
       _accountId = accountId,
       _cache = cache,
       super(const PrivacyState());

  final SettingsSyncNotifier? _sync;
  final String? _accountId;
  final OfflineCache? _cache;
  static final String _mirrorKey = settingsMirrorKey(SettingKeys.privacy);

  // Privacy is never queued (KAN-657): offline it shows the network error.
  bool _offlineFirst(String userId) =>
      isQueueableSetting(SettingKeys.privacy) &&
      _sync != null &&
      _accountId != null &&
      _accountId == userId;

  OfflineCache get _mirror => _cache ?? OfflineCache.instance;

  /// What the device holds for this account: a change still waiting for the
  /// server, else the last copy the server gave.
  Future<PrivacySettings?> _localSettings(String userId) async {
    final pending = await _sync!.pendingValue(SettingKeys.privacy);
    if (pending != null) return PrivacySettingsModel.fromJson(pending);
    final hit = await _mirror.read(userId, _mirrorKey);
    if (hit == null) return null;
    return PrivacySettingsModel.fromJson(
      Map<String, dynamic>.from(hit.payload as Map),
    );
  }

  /// Load privacy settings from Supabase
  Future<void> loadPrivacySettings(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (_settingsRepository != null) {
        PrivacySettings? settings;
        if (_offlineFirst(userId)) {
          final pending = await _sync!.pendingValue(SettingKeys.privacy);
          if (pending != null)
            settings = PrivacySettingsModel.fromJson(pending);
        }
        if (settings == null) {
          final result = await _settingsRepository.getPrivacySettings(userId);
          settings = result.fold((failure) => null, (loaded) => loaded);
          if (_offlineFirst(userId)) {
            if (settings != null) {
              _mirror.write(
                userId,
                _mirrorKey,
                PrivacySettingsModel.fromEntity(settings).toJson(),
              );
            } else {
              settings = await _localSettings(userId);
            }
          }
          settings ??= const PrivacySettings();
        }

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
        return;
      }

      // Fallback to defaults if no repository
      const settings = PrivacySettings();
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
  Future<bool> saveAllChanges(String userId) async {
    if (state.settings == null) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      // Direct save via repository if available
      if (_settingsRepository != null && _offlineFirst(userId)) {
        // KAN-608: kept on the device and queued; the screen already shows it.
        final settings = state.settings!;
        final value = PrivacySettingsModel.fromEntity(settings).toJson();
        _mirror.write(userId, _mirrorKey, value);
        state = state.copyWith(
          isSaving: false,
          pendingChanges: {},
          hasUnsavedChanges: false,
          lastSyncTime: DateTime.now(),
          privacyScore: _calculatePrivacyScore(settings),
          securityWarnings: _generateSecurityWarnings(settings),
        );
        await _sync!.submit(SettingKeys.privacy, value);
        return true;
      }

      if (_settingsRepository != null) {
        final result = await _settingsRepository.updatePrivacySettings(
          userId,
          state.settings!,
        );

        return await result.fold(
          (failure) {
            state = state.copyWith(
              isSaving: false,
              errorMessage: failure.message,
            );
            return false;
          },
          (updatedSettings) {
            final privacyScore = _calculatePrivacyScore(updatedSettings);
            final securityWarnings = _generateSecurityWarnings(updatedSettings);

            state = state.copyWith(
              isSaving: false,
              settings: updatedSettings,
              pendingChanges: {},
              hasUnsavedChanges: false,
              lastSyncTime: DateTime.now(),
              privacyScore: privacyScore,
              securityWarnings: securityWarnings,
            );
            return true;
          },
        );
      }

      // Fallback: use ManagePrivacyUseCase if no direct repo
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
        userId: userId,
        profileVisibility: state.pendingChanges['profileVisibility'] as bool?,
        showEmail: state.pendingChanges['showEmail'] as bool?,
        showPhoneNumber: state.pendingChanges['showPhone'] as bool?,
        showLocation: state.pendingChanges['showLocation'] as bool?,
        showAge: state.pendingChanges['showAge'] as bool?,
        showStatistics: state.pendingChanges['showStats'] as bool?,
        messagePreference:
            state.pendingChanges['messagePreference']
                as CommunicationPreference?,
        gameInvitePreference:
            state.pendingChanges['gameInvitePreference']
                as CommunicationPreference?,
        shareDataWithPartners:
            state.pendingChanges['dataSharingLevel'] as bool?,
        allowAnalytics: state.pendingChanges['allowDataAnalytics'] as bool?,
        blockedUsers: state.pendingChanges['blockedUsers'] as List<String>?,
      );

      final result = await _managePrivacyUseCase.call(params);

      return await result.fold(
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

  /// Update a specific setting in local state (before saving)
  void updateSetting(String key, dynamic value) {
    if (state.settings == null) return;

    final updated = _applySettingToModel(state.settings!, key, value);
    final privacyScore = _calculatePrivacyScore(updated);
    final securityWarnings = _generateSecurityWarnings(updated);

    state = state.copyWith(
      settings: updated,
      hasUnsavedChanges: true,
      pendingChanges: {...state.pendingChanges, key: value},
      privacyScore: privacyScore,
      securityWarnings: securityWarnings,
    );
  }

  /// Apply a preset (public / friends / private)
  void applyPreset(PrivacySettings presetSettings) {
    final privacyScore = _calculatePrivacyScore(presetSettings);
    final securityWarnings = _generateSecurityWarnings(presetSettings);

    state = state.copyWith(
      settings: presetSettings,
      hasUnsavedChanges: true,
      privacyScore: privacyScore,
      securityWarnings: securityWarnings,
    );
  }

  PrivacySettings _applySettingToModel(
    PrivacySettings current,
    String key,
    dynamic value,
  ) {
    switch (key) {
      // Profile & Identity
      case 'profileVisibility':
        return current.copyWith(profileVisibility: value as ProfileVisibility);
      case 'showRealName':
        return current.copyWith(showRealName: value as bool);
      case 'showAge':
        return current.copyWith(showAge: value as bool);
      case 'showLocation':
        return current.copyWith(showLocation: value as bool);
      case 'showPhone':
        return current.copyWith(showPhone: value as bool);
      case 'showEmail':
        return current.copyWith(showEmail: value as bool);
      case 'showBio':
        return current.copyWith(showBio: value as bool);
      case 'showProfilePhoto':
        return current.copyWith(showProfilePhoto: value as bool);
      case 'showFriendsList':
        return current.copyWith(showFriendsList: value as bool);
      case 'allowProfileIndexing':
        return current.copyWith(allowProfileIndexing: value as bool);

      // Activity & Stats
      case 'showStats':
        return current.copyWith(showStats: value as bool);
      case 'showSportsProfiles':
        return current.copyWith(showSportsProfiles: value as bool);
      case 'showGameHistory':
        return current.copyWith(showGameHistory: value as bool);
      case 'showAchievements':
        return current.copyWith(showAchievements: value as bool);
      case 'showOnlineStatus':
        return current.copyWith(showOnlineStatus: value as bool);
      case 'showActivityStatus':
        return current.copyWith(showActivityStatus: value as bool);
      case 'showCheckIns':
        return current.copyWith(showCheckIns: value as bool);
      case 'showPostsToPublic':
        return current.copyWith(showPostsToPublic: value as bool);

      // Communication
      case 'messagePreference':
        return current.copyWith(
          messagePreference: value as CommunicationPreference,
        );
      case 'gameInvitePreference':
        return current.copyWith(
          gameInvitePreference: value as CommunicationPreference,
        );
      case 'friendRequestPreference':
        return current.copyWith(
          friendRequestPreference: value as CommunicationPreference,
        );

      // Notifications
      case 'allowPushNotifications':
        return current.copyWith(allowPushNotifications: value as bool);
      case 'allowEmailNotifications':
        return current.copyWith(allowEmailNotifications: value as bool);

      // Data & Analytics
      case 'allowLocationTracking':
        return current.copyWith(allowLocationTracking: value as bool);
      case 'allowDataAnalytics':
        return current.copyWith(allowDataAnalytics: value as bool);
      case 'dataSharingLevel':
        return current.copyWith(dataSharingLevel: value as DataSharingLevel);
      case 'allowGameRecommendations':
        return current.copyWith(allowGameRecommendations: value as bool);
      case 'hideFromNearby':
        return current.copyWith(hideFromNearby: value as bool);

      // Security
      case 'twoFactorEnabled':
        return current.copyWith(twoFactorEnabled: value as bool);
      case 'loginAlerts':
        return current.copyWith(loginAlerts: value as bool);

      default:
        return current;
    }
  }

  /// Calculate privacy score (0-100) — mirrors domain model scoring
  double _calculatePrivacyScore(PrivacySettings settings) {
    double score = 0.0;

    // Profile visibility (15 points)
    switch (settings.profileVisibility) {
      case ProfileVisibility.private:
        score += 15.0;
        break;
      case ProfileVisibility.friends:
        score += 10.0;
        break;
      case ProfileVisibility.public:
        score += 0.0;
        break;
    }

    // Identity fields (20 points)
    if (!settings.showRealName) score += 4.0;
    if (!settings.showAge) score += 3.0;
    if (!settings.showLocation) score += 3.0;
    if (!settings.showPhone) score += 4.0;
    if (!settings.showEmail) score += 4.0;
    if (!settings.showBio) score += 1.0;
    if (!settings.showProfilePhoto) score += 1.0;

    // Discoverability (10 points)
    if (!settings.showFriendsList) score += 3.0;
    if (!settings.allowProfileIndexing) score += 4.0;
    if (settings.hideFromNearby) score += 3.0;

    // Communication (10 points)
    if (settings.messagePreference != CommunicationPreference.anyone) {
      score += 4.0;
    }
    if (settings.gameInvitePreference != CommunicationPreference.anyone) {
      score += 3.0;
    }
    if (settings.friendRequestPreference != CommunicationPreference.anyone) {
      score += 3.0;
    }

    // Activity (15 points)
    if (!settings.showStats) score += 2.0;
    if (!settings.showSportsProfiles) score += 2.0;
    if (!settings.showGameHistory) score += 2.0;
    if (!settings.showAchievements) score += 2.0;
    if (!settings.showOnlineStatus) score += 2.0;
    if (!settings.showActivityStatus) score += 2.0;
    if (!settings.showCheckIns) score += 2.0;
    if (!settings.showPostsToPublic) score += 1.0;

    // Data & Analytics (15 points)
    if (!settings.allowLocationTracking) score += 5.0;
    if (!settings.allowDataAnalytics) score += 4.0;
    if (!settings.allowGameRecommendations) score += 2.0;
    switch (settings.dataSharingLevel) {
      case DataSharingLevel.minimal:
        score += 4.0;
        break;
      case DataSharingLevel.limited:
        score += 2.0;
        break;
      case DataSharingLevel.full:
        score += 0.0;
        break;
    }

    // Security (15 points)
    if (settings.twoFactorEnabled) score += 10.0;
    if (settings.loginAlerts) score += 5.0;

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

    if (!settings.twoFactorEnabled) {
      warnings.add('Two-factor authentication is not enabled');
    }

    if (!settings.loginAlerts) {
      warnings.add('Login alerts are disabled');
    }

    if (settings.allowProfileIndexing) {
      warnings.add('Profile is searchable by external services');
    }

    if (settings.showFriendsList) {
      warnings.add('Friends list is visible to others');
    }

    if (settings.messagePreference == CommunicationPreference.anyone) {
      warnings.add('Anyone can send you messages');
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
    if (failure is ValidationFailure) return failure.message;
    if (failure is NetworkFailure) {
      return 'Network error. Please check your connection.';
    }
    if (failure is ServerFailure) {
      return 'Server error. Please try again later.';
    }
    return failure.message;
  }
}

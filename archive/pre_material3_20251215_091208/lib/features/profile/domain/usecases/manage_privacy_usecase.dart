import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';
import '../repositories/settings_repository.dart';

/// Parameters for managing privacy settings
class ManagePrivacyParams {
  final String userId;
  final bool? profileVisibility;
  final bool? showEmail;
  final bool? showPhoneNumber;
  final bool? showLocation;
  final bool? showAge;
  final bool? showStatistics;
  final bool? allowDirectMessages;
  final bool? allowGameInvitations;
  final bool? shareDataWithPartners;
  final bool? allowAnalytics;
  final List<String>? blockedUsers;
  final List<String>? allowedContactsOnly;

  const ManagePrivacyParams({
    required this.userId,
    this.profileVisibility,
    this.showEmail,
    this.showPhoneNumber,
    this.showLocation,
    this.showAge,
    this.showStatistics,
    this.allowDirectMessages,
    this.allowGameInvitations,
    this.shareDataWithPartners,
    this.allowAnalytics,
    this.blockedUsers,
    this.allowedContactsOnly,
  });

  bool get hasUpdates =>
      profileVisibility != null ||
      showEmail != null ||
      showPhoneNumber != null ||
      showLocation != null ||
      showAge != null ||
      showStatistics != null ||
      allowDirectMessages != null ||
      allowGameInvitations != null ||
      shareDataWithPartners != null ||
      allowAnalytics != null ||
      blockedUsers != null ||
      allowedContactsOnly != null;
}

/// Result of privacy settings management operation
class ManagePrivacyResult {
  final PrivacySettings updatedSettings;
  final List<String> warnings;
  final Map<String, dynamic> changedSettings;
  final int privacyScore;

  const ManagePrivacyResult({
    required this.updatedSettings,
    required this.warnings,
    required this.changedSettings,
    required this.privacyScore,
  });
}

/// Use case for managing privacy settings with comprehensive validation and security checks
class ManagePrivacyUseCase {
  final SettingsRepository _settingsRepository;

  ManagePrivacyUseCase(this._settingsRepository);

  Future<Either<Failure, ManagePrivacyResult>> call(
    ManagePrivacyParams params,
  ) async {
    try {
      // Validate input parameters
      final validationResult = _validateParams(params);
      if (validationResult.isLeft) {
        return Left(validationResult.leftOrNull()!);
      }

      // Get current privacy settings for comparison
      final currentSettingsResult = await _settingsRepository
          .getPrivacySettings(params.userId);
      if (currentSettingsResult.isLeft) {
        return Left(currentSettingsResult.leftOrNull()!);
      }

      final currentSettings = currentSettingsResult.rightOrNull()!;

      // Apply business rules and security constraints
      final processedParams = _applySecurityRules(params, currentSettings);
      if (processedParams.isLeft) {
        return Left(processedParams.leftOrNull()!);
      }

      final finalParams = processedParams.rightOrNull()!;

      // Create updated privacy settings with new values
      final updatedSettings = currentSettings.copyWith(
        profileVisibility: finalParams.profileVisibility != null
            ? (finalParams.profileVisibility!
                  ? ProfileVisibility.public
                  : ProfileVisibility.private)
            : null,
        showEmail: finalParams.showEmail,
        showPhone: finalParams.showPhoneNumber,
        showLocation: finalParams.showLocation,
        showAge: finalParams.showAge,
        showStats: finalParams.showStatistics,
        messagePreference: finalParams.allowDirectMessages != null
            ? (finalParams.allowDirectMessages!
                  ? CommunicationPreference.anyone
                  : CommunicationPreference.none)
            : null,
        gameInvitePreference: finalParams.allowGameInvitations != null
            ? (finalParams.allowGameInvitations!
                  ? CommunicationPreference.anyone
                  : CommunicationPreference.none)
            : null,
        allowDataAnalytics: finalParams.allowAnalytics,
        blockedUsers: finalParams.blockedUsers,
      );

      // Perform the privacy settings update
      final updateResult = await _settingsRepository.updatePrivacySettings(
        params.userId,
        updatedSettings,
      );
      if (updateResult.isLeft) {
        return Left(updateResult.leftOrNull()!);
      }

      final finalUpdatedSettings = updateResult.rightOrNull()!;

      // Calculate changed settings
      final changedSettings = _calculateChangedSettings(
        currentSettings,
        finalUpdatedSettings,
      );

      // Calculate privacy score
      final privacyScore = _calculatePrivacyScore(finalUpdatedSettings);

      // Generate warnings
      final warnings = _generateWarnings(finalUpdatedSettings, changedSettings);

      return Right(
        ManagePrivacyResult(
          updatedSettings: finalUpdatedSettings,
          warnings: warnings,
          changedSettings: changedSettings,
          privacyScore: privacyScore,
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Privacy settings update failed: $e'));
    }
  }

  /// Validate input parameters
  Either<Failure, void> _validateParams(ManagePrivacyParams params) {
    final errors = <String>[];

    // Validate blocked users list
    if (params.blockedUsers != null) {
      if (params.blockedUsers!.length > 1000) {
        errors.add('Blocked users list cannot exceed 1000 entries');
      }

      // Check for self-blocking
      if (params.blockedUsers!.contains(params.userId)) {
        errors.add('Cannot block yourself');
      }
    }

    // Validate allowed contacts list
    if (params.allowedContactsOnly != null) {
      if (params.allowedContactsOnly!.length > 5000) {
        errors.add('Allowed contacts list cannot exceed 5000 entries');
      }
    }

    if (errors.isNotEmpty) {
      return Left(ValidationFailure(message: errors.join(', ')));
    }

    return const Right(null);
  }

  /// Apply security rules and constraints
  Either<Failure, ManagePrivacyParams> _applySecurityRules(
    ManagePrivacyParams params,
    PrivacySettings currentSettings,
  ) {
    var processedParams = params;

    // Security Rule: If profile is private, hide sensitive information
    if (params.profileVisibility == false) {
      processedParams = ManagePrivacyParams(
        userId: params.userId,
        profileVisibility: false,
        showEmail: false,
        showPhoneNumber: false,
        showLocation: params.showLocation ?? false,
        showAge: params.showAge ?? false,
        showStatistics: params.showStatistics ?? false,
        allowDirectMessages: params.allowDirectMessages ?? false,
        allowGameInvitations:
            params.allowGameInvitations ??
            true, // Keep game invitations enabled
        shareDataWithPartners: false,
        allowAnalytics: params.allowAnalytics,
        blockedUsers: params.blockedUsers,
        allowedContactsOnly: params.allowedContactsOnly,
      );
    }

    // Security Rule: If data sharing is disabled, disable analytics
    if (params.shareDataWithPartners == false &&
        params.allowAnalytics == null) {
      processedParams = ManagePrivacyParams(
        userId: processedParams.userId,
        profileVisibility: processedParams.profileVisibility,
        showEmail: processedParams.showEmail,
        showPhoneNumber: processedParams.showPhoneNumber,
        showLocation: processedParams.showLocation,
        showAge: processedParams.showAge,
        showStatistics: processedParams.showStatistics,
        allowDirectMessages: processedParams.allowDirectMessages,
        allowGameInvitations: processedParams.allowGameInvitations,
        shareDataWithPartners: false,
        allowAnalytics: false,
        blockedUsers: processedParams.blockedUsers,
        allowedContactsOnly: processedParams.allowedContactsOnly,
      );
    }

    return Right(processedParams);
  }

  /// Calculate which settings have changed
  Map<String, dynamic> _calculateChangedSettings(
    PrivacySettings current,
    PrivacySettings updated,
  ) {
    final changes = <String, dynamic>{};

    if (current.profileVisibility != updated.profileVisibility) {
      changes['profile_visibility'] = {
        'old': current.profileVisibility,
        'new': updated.profileVisibility,
      };
    }

    if (current.showEmail != updated.showEmail) {
      changes['show_email'] = {
        'old': current.showEmail,
        'new': updated.showEmail,
      };
    }

    if (current.showPhone != updated.showPhone) {
      changes['show_phone_number'] = {
        'old': current.showPhone,
        'new': updated.showPhone,
      };
    }

    if (current.showLocation != updated.showLocation) {
      changes['show_location'] = {
        'old': current.showLocation,
        'new': updated.showLocation,
      };
    }

    if (current.showAge != updated.showAge) {
      changes['show_age'] = {'old': current.showAge, 'new': updated.showAge};
    }

    if (current.showStats != updated.showStats) {
      changes['show_statistics'] = {
        'old': current.showStats,
        'new': updated.showStats,
      };
    }

    if (current.messagePreference != updated.messagePreference) {
      changes['allow_direct_messages'] = {
        'old': current.messagePreference == CommunicationPreference.anyone,
        'new': updated.messagePreference == CommunicationPreference.anyone,
      };
    }

    if (current.gameInvitePreference != updated.gameInvitePreference) {
      changes['allow_game_invitations'] = {
        'old': current.gameInvitePreference == CommunicationPreference.anyone,
        'new': updated.gameInvitePreference == CommunicationPreference.anyone,
      };
    }

    if (current.dataSharingLevel != updated.dataSharingLevel) {
      changes['share_data_with_partners'] = {
        'old': current.dataSharingLevel == DataSharingLevel.full,
        'new': updated.dataSharingLevel == DataSharingLevel.full,
      };
    }

    if (current.allowDataAnalytics != updated.allowDataAnalytics) {
      changes['allow_analytics'] = {
        'old': current.allowDataAnalytics,
        'new': updated.allowDataAnalytics,
      };
    }

    if (!_listEquals(current.blockedUsers, updated.blockedUsers)) {
      changes['blocked_users'] = {
        'old_count': current.blockedUsers.length,
        'new_count': updated.blockedUsers.length,
      };
    }

    return changes;
  }

  /// Calculate privacy score (0-100, higher is more private)
  int _calculatePrivacyScore(PrivacySettings settings) {
    int score = 0;

    // Profile visibility
    if (settings.profileVisibility == ProfileVisibility.private) score += 20;

    // Contact information visibility
    if (!settings.showEmail) score += 15;
    if (!settings.showPhone) score += 15;
    if (!settings.showLocation) score += 10;
    if (!settings.showAge) score += 5;

    // Statistics visibility
    if (!settings.showStats) score += 5;

    // Communication settings
    if (settings.messagePreference == CommunicationPreference.none) score += 10;
    if (settings.gameInvitePreference == CommunicationPreference.none) {
      score += 5;
    }

    // Data sharing
    if (settings.dataSharingLevel == DataSharingLevel.minimal) score += 10;
    if (!settings.allowDataAnalytics) score += 5;

    return score;
  }

  /// Generate warnings for the user
  List<String> _generateWarnings(
    PrivacySettings settings,
    Map<String, dynamic> changedSettings,
  ) {
    final warnings = <String>[];

    // Warning: Very private settings may limit functionality
    final privacyScore = _calculatePrivacyScore(settings);
    if (privacyScore > 80) {
      warnings.add(
        'High privacy settings may limit game opportunities and social features.',
      );
    }

    // Warning: Profile completely hidden
    if (settings.profileVisibility == ProfileVisibility.private) {
      warnings.add(
        'Hidden profile may prevent others from finding and inviting you to games.',
      );
    }

    // Warning: Direct messages disabled
    if (settings.messagePreference == CommunicationPreference.none) {
      warnings.add(
        'Disabled direct messages may prevent important game communications.',
      );
    }

    // Warning: Game invitations disabled
    if (settings.gameInvitePreference == CommunicationPreference.none) {
      warnings.add(
        'Disabled game invitations will prevent others from inviting you to games.',
      );
    }

    // Warning: No contact information visible
    if (!settings.showEmail && !settings.showPhone) {
      warnings.add(
        'No visible contact information may make communication difficult.',
      );
    }

    // Warning: Analytics disabled
    if (!settings.allowDataAnalytics) {
      warnings.add(
        'Disabled analytics may prevent personalized recommendations.',
      );
    }

    // Warning: Many blocked users
    if (settings.blockedUsers.length > 100) {
      warnings.add('Large blocked users list may need periodic review.');
    }

    // Warning: Data sharing changes
    if (changedSettings.containsKey('share_data_with_partners')) {
      warnings.add(
        'Data sharing changes may affect app functionality and features.',
      );
    }

    return warnings;
  }

  /// Helper method to compare lists
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

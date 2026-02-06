import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_settings.dart';
import '../repositories/settings_repository.dart';

/// Parameters for changing settings
class ChangeSettingsParams {
  final String userId;
  final ThemeMode? themeMode;
  final String? language;
  final bool? enablePushNotifications;
  final bool? gameInviteNotifications;
  final bool? gameReminderNotifications;
  final bool? socialNotifications;
  final DistanceUnit? distanceUnit;
  final DateFormat? dateFormat;
  final TimeFormat? timeFormat;
  final bool? enableDataSaver;
  final int? reminderMinutesBefore;

  const ChangeSettingsParams({
    required this.userId,
    this.themeMode,
    this.language,
    this.enablePushNotifications,
    this.gameInviteNotifications,
    this.gameReminderNotifications,
    this.socialNotifications,
    this.distanceUnit,
    this.dateFormat,
    this.timeFormat,
    this.enableDataSaver,
    this.reminderMinutesBefore,
  });

  bool get hasUpdates =>
      themeMode != null ||
      language != null ||
      enablePushNotifications != null ||
      gameInviteNotifications != null ||
      gameReminderNotifications != null ||
      socialNotifications != null ||
      distanceUnit != null ||
      dateFormat != null ||
      timeFormat != null ||
      enableDataSaver != null ||
      reminderMinutesBefore != null;
}

/// Result of settings change operation
class ChangeSettingsResult {
  final UserSettings updatedSettings;
  final List<String> warnings;
  final Map<String, dynamic> changedSettings;
  final bool requiresRestart;

  const ChangeSettingsResult({
    required this.updatedSettings,
    required this.warnings,
    required this.changedSettings,
    required this.requiresRestart,
  });
}

/// Use case for changing user settings with validation and business rules
class ChangeSettingsUseCase {
  final SettingsRepository _settingsRepository;

  ChangeSettingsUseCase(this._settingsRepository);

  Future<Either<Failure, ChangeSettingsResult>> call(
    ChangeSettingsParams params,
  ) async {
    try {
      // Validate input parameters
      final validationResult = _validateParams(params);
      if (validationResult.isLeft) {
        return Left(validationResult.leftOrNull()!);
      }

      // Get current settings for comparison
      final currentSettingsResult = await _settingsRepository.getSettings(
        params.userId,
      );
      if (currentSettingsResult.isLeft) {
        return Left(currentSettingsResult.leftOrNull()!);
      }

      final currentSettings = currentSettingsResult.rightOrNull()!;

      // Apply business rules and constraints
      final processedParams = _applyBusinessRules(params, currentSettings);
      if (processedParams.isLeft) {
        return Left(processedParams.leftOrNull()!);
      }

      final finalParams = processedParams.rightOrNull()!;

      // Create updated settings with new values
      final updatedSettings = UserSettings(
        themeMode: finalParams.themeMode ?? currentSettings.themeMode,
        enableAnimations: currentSettings.enableAnimations,
        textScale: currentSettings.textScale,
        highContrastMode: currentSettings.highContrastMode,
        reduceMotion: currentSettings.reduceMotion,
        language: finalParams.language ?? currentSettings.language,
        region: currentSettings.region,
        distanceUnit: finalParams.distanceUnit ?? currentSettings.distanceUnit,
        temperatureUnit: currentSettings.temperatureUnit,
        dateFormat: finalParams.dateFormat ?? currentSettings.dateFormat,
        timeFormat: finalParams.timeFormat ?? currentSettings.timeFormat,
        defaultSport: currentSettings.defaultSport,
        defaultGameDuration: currentSettings.defaultGameDuration,
        defaultMaxPlayers: currentSettings.defaultMaxPlayers,
        defaultIsPublic: currentSettings.defaultIsPublic,
        defaultAllowWaitlist: currentSettings.defaultAllowWaitlist,
        defaultAdvanceNoticeHours: currentSettings.defaultAdvanceNoticeHours,
        enablePushNotifications:
            finalParams.enablePushNotifications ??
            currentSettings.enablePushNotifications,
        gameInviteNotifications:
            finalParams.gameInviteNotifications ??
            currentSettings.gameInviteNotifications,
        gameReminderNotifications:
            finalParams.gameReminderNotifications ??
            currentSettings.gameReminderNotifications,
        gameUpdateNotifications: currentSettings.gameUpdateNotifications,
        socialNotifications:
            finalParams.socialNotifications ??
            currentSettings.socialNotifications,
        systemNotifications: currentSettings.systemNotifications,
        notificationSound: currentSettings.notificationSound,
        vibrationEnabled: currentSettings.vibrationEnabled,
        reminderMinutesBefore:
            finalParams.reminderMinutesBefore ??
            currentSettings.reminderMinutesBefore,
        showTrafficLayer: currentSettings.showTrafficLayer,
        showSatelliteView: currentSettings.showSatelliteView,
        defaultMapZoom: currentSettings.defaultMapZoom,
        autoLocationDetection: currentSettings.autoLocationDetection,
        enableDataSaver:
            finalParams.enableDataSaver ?? currentSettings.enableDataSaver,
        preloadImages: currentSettings.preloadImages,
        backgroundRefresh: currentSettings.backgroundRefresh,
        cacheSize: currentSettings.cacheSize,
        screenReaderEnabled: currentSettings.screenReaderEnabled,
        voiceOverEnabled: currentSettings.voiceOverEnabled,
        largeTextEnabled: currentSettings.largeTextEnabled,
        buttonShapesEnabled: currentSettings.buttonShapesEnabled,
      );

      // Perform the settings update
      final updateResult = await _settingsRepository.updateSettings(
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

      // Check if restart is required
      final requiresRestart = _requiresRestart(changedSettings);

      // Generate warnings
      final warnings = _generateWarnings(finalUpdatedSettings, changedSettings);

      return Right(
        ChangeSettingsResult(
          updatedSettings: finalUpdatedSettings,
          warnings: warnings,
          changedSettings: changedSettings,
          requiresRestart: requiresRestart,
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Settings update failed: $e'));
    }
  }

  /// Validate input parameters
  Either<Failure, void> _validateParams(ChangeSettingsParams params) {
    final errors = <String>[];

    // Validate language
    if (params.language != null) {
      const validLanguages = [
        'en',
        'es',
        'fr',
        'de',
        'it',
        'pt',
        'ar',
        'zh',
        'ja',
        'ko',
      ];
      if (!validLanguages.contains(params.language!.toLowerCase())) {
        errors.add('Unsupported language');
      }
    }

    // Validate reminder time
    if (params.reminderMinutesBefore != null) {
      if (params.reminderMinutesBefore! < 5 ||
          params.reminderMinutesBefore! > 1440) {
        // 5 minutes to 24 hours
        errors.add('Reminder time must be between 5 and 1440 minutes');
      }
    }

    if (errors.isNotEmpty) {
      return Left(ValidationFailure(message: errors.join(', ')));
    }

    return const Right(null);
  }

  /// Apply business rules and constraints
  Either<Failure, ChangeSettingsParams> _applyBusinessRules(
    ChangeSettingsParams params,
    UserSettings currentSettings,
  ) {
    var processedParams = params;

    // Business Rule: If push notifications are disabled, disable all notification types
    if (params.enablePushNotifications == false) {
      processedParams = ChangeSettingsParams(
        userId: params.userId,
        themeMode: params.themeMode,
        language: params.language,
        enablePushNotifications: false,
        gameInviteNotifications: false,
        gameReminderNotifications: false,
        socialNotifications: false,
        distanceUnit: params.distanceUnit,
        dateFormat: params.dateFormat,
        timeFormat: params.timeFormat,
        enableDataSaver: params.enableDataSaver,
        reminderMinutesBefore: params.reminderMinutesBefore,
      );
    }

    // Business Rule: If any notification type is enabled, enable push notifications
    if ((params.gameInviteNotifications == true ||
            params.gameReminderNotifications == true ||
            params.socialNotifications == true) &&
        processedParams.enablePushNotifications != false) {
      processedParams = ChangeSettingsParams(
        userId: processedParams.userId,
        themeMode: processedParams.themeMode,
        language: processedParams.language,
        enablePushNotifications: true,
        gameInviteNotifications: processedParams.gameInviteNotifications,
        gameReminderNotifications: processedParams.gameReminderNotifications,
        socialNotifications: processedParams.socialNotifications,
        distanceUnit: processedParams.distanceUnit,
        dateFormat: processedParams.dateFormat,
        timeFormat: processedParams.timeFormat,
        enableDataSaver: processedParams.enableDataSaver,
        reminderMinutesBefore: processedParams.reminderMinutesBefore,
      );
    }

    return Right(processedParams);
  }

  /// Calculate which settings have changed
  Map<String, dynamic> _calculateChangedSettings(
    UserSettings current,
    UserSettings updated,
  ) {
    final changes = <String, dynamic>{};

    if (current.themeMode != updated.themeMode) {
      changes['theme_mode'] = {
        'old': current.themeMode.toString(),
        'new': updated.themeMode.toString(),
      };
    }

    if (current.language != updated.language) {
      changes['language'] = {'old': current.language, 'new': updated.language};
    }

    if (current.enablePushNotifications != updated.enablePushNotifications) {
      changes['enable_push_notifications'] = {
        'old': current.enablePushNotifications,
        'new': updated.enablePushNotifications,
      };
    }

    if (current.gameInviteNotifications != updated.gameInviteNotifications) {
      changes['game_invite_notifications'] = {
        'old': current.gameInviteNotifications,
        'new': updated.gameInviteNotifications,
      };
    }

    if (current.gameReminderNotifications !=
        updated.gameReminderNotifications) {
      changes['game_reminder_notifications'] = {
        'old': current.gameReminderNotifications,
        'new': updated.gameReminderNotifications,
      };
    }

    if (current.socialNotifications != updated.socialNotifications) {
      changes['social_notifications'] = {
        'old': current.socialNotifications,
        'new': updated.socialNotifications,
      };
    }

    if (current.distanceUnit != updated.distanceUnit) {
      changes['distance_unit'] = {
        'old': current.distanceUnit.toString(),
        'new': updated.distanceUnit.toString(),
      };
    }

    if (current.dateFormat != updated.dateFormat) {
      changes['date_format'] = {
        'old': current.dateFormat.toString(),
        'new': updated.dateFormat.toString(),
      };
    }

    if (current.timeFormat != updated.timeFormat) {
      changes['time_format'] = {
        'old': current.timeFormat.toString(),
        'new': updated.timeFormat.toString(),
      };
    }

    if (current.enableDataSaver != updated.enableDataSaver) {
      changes['enable_data_saver'] = {
        'old': current.enableDataSaver,
        'new': updated.enableDataSaver,
      };
    }

    if (current.reminderMinutesBefore != updated.reminderMinutesBefore) {
      changes['reminder_minutes_before'] = {
        'old': current.reminderMinutesBefore,
        'new': updated.reminderMinutesBefore,
      };
    }

    return changes;
  }

  /// Check if app restart is required
  bool _requiresRestart(Map<String, dynamic> changedSettings) {
    const restartRequiredSettings = ['language', 'theme_mode'];

    return changedSettings.keys.any(
      (key) => restartRequiredSettings.contains(key),
    );
  }

  /// Generate warnings for the user
  List<String> _generateWarnings(
    UserSettings settings,
    Map<String, dynamic> changedSettings,
  ) {
    final warnings = <String>[];

    // Warning: All notifications disabled
    if (!settings.enablePushNotifications) {
      warnings.add(
        'All push notifications are disabled. You may miss important updates.',
      );
    }

    // Warning: Short reminder time
    if (settings.reminderMinutesBefore < 30) {
      warnings.add(
        'Short reminder time may not provide enough notice for games.',
      );
    }

    // Warning: Data saver enabled
    if (settings.enableDataSaver) {
      warnings.add('Data saver mode may limit some features.');
    }

    // Warning: Language change
    if (changedSettings.containsKey('language')) {
      warnings.add('Language change will take effect after app restart.');
    }

    // Warning: Theme change
    if (changedSettings.containsKey('theme_mode')) {
      warnings.add('Theme changes may affect visibility and user experience.');
    }

    return warnings;
  }
}

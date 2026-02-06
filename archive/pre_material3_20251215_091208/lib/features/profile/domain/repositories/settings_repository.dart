import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_settings.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';

/// Repository interface for user settings and privacy preferences
/// Handles both local storage for quick access and remote sync
abstract class SettingsRepository {
  /// Retrieves user settings by user ID
  /// First checks local cache, then remote if needed
  /// Returns [UserSettings] on success or [Failure] on error
  Future<Either<Failure, UserSettings>> getSettings(String userId);

  /// Updates user settings
  /// Updates local cache immediately and syncs with remote
  /// Returns updated [UserSettings] on success or [Failure] on error
  Future<Either<Failure, UserSettings>> updateSettings(
    String userId,
    UserSettings settings,
  );

  /// Updates a single setting value
  /// More efficient than updating entire settings object
  /// [key] - The setting key to update
  /// [value] - The new value
  /// Returns updated [UserSettings] on success or [Failure] on error
  Future<Either<Failure, UserSettings>> updateSetting(
    String userId,
    String key,
    dynamic value,
  );

  /// Updates multiple settings in a single transaction
  /// [updates] - Map of setting keys to new values
  /// Returns updated [UserSettings] on success or [Failure] on error
  Future<Either<Failure, UserSettings>> batchUpdateSettings(
    String userId,
    Map<String, dynamic> updates,
  );

  /// Resets all settings to default values
  /// Returns default [UserSettings] on success or [Failure] on error
  Future<Either<Failure, UserSettings>> resetToDefaults(String userId);

  /// Retrieves privacy settings by user ID
  /// Returns [PrivacySettings] on success or [Failure] on error
  Future<Either<Failure, PrivacySettings>> getPrivacySettings(String userId);

  /// Updates privacy settings
  /// Returns updated [PrivacySettings] on success or [Failure] on error
  Future<Either<Failure, PrivacySettings>> updatePrivacySettings(
    String userId,
    PrivacySettings privacySettings,
  );

  /// Updates a single privacy setting
  /// [key] - The privacy setting key to update
  /// [value] - The new value
  /// Returns updated [PrivacySettings] on success or [Failure] on error
  Future<Either<Failure, PrivacySettings>> updatePrivacySetting(
    String userId,
    String key,
    dynamic value,
  );

  /// Gets notification preferences from settings
  /// Returns map of notification types to enabled status
  /// Returns [Map<String, bool>] on success or [Failure] on error
  Future<Either<Failure, Map<String, bool>>> getNotificationPreferences(
    String userId,
  );

  /// Updates notification preferences
  /// [preferences] - Map of notification types to enabled status
  /// Returns updated preferences on success or [Failure] on error
  Future<Either<Failure, Map<String, bool>>> updateNotificationPreferences(
    String userId,
    Map<String, bool> preferences,
  );

  /// Enables or disables a specific notification type
  /// [notificationType] - The type of notification (e.g., 'game_invites', 'messages')
  /// [enabled] - Whether to enable or disable this notification type
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> setNotificationEnabled(
    String userId,
    String notificationType,
    bool enabled,
  );

  /// Gets theme and display settings
  /// Returns theme configuration on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> getThemeSettings(String userId);

  /// Updates theme and display settings
  /// [themeSettings] - Map of theme configuration
  /// Returns updated theme settings on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> updateThemeSettings(
    String userId,
    Map<String, dynamic> themeSettings,
  );

  /// Gets accessibility settings
  /// Returns accessibility configuration on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> getAccessibilitySettings(
    String userId,
  );

  /// Updates accessibility settings
  /// [accessibilitySettings] - Map of accessibility configuration
  /// Returns updated accessibility settings on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> updateAccessibilitySettings(
    String userId,
    Map<String, dynamic> accessibilitySettings,
  );

  /// Synchronizes local settings with remote server
  /// Used when app starts or when connectivity is restored
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> syncSettings(String userId);

  /// Checks if settings need to be synced
  /// Returns true if local settings are newer than remote
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> needsSync(String userId);

  /// Gets the last sync timestamp for settings
  /// Returns [DateTime] on success or [Failure] on error
  Future<Either<Failure, DateTime?>> getLastSyncTime(String userId);

  /// Clears all local settings cache
  /// Forces fresh fetch from remote on next access
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> clearCache(String userId);

  /// Exports all settings as JSON for backup
  /// Returns settings data on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> exportSettings(String userId);

  /// Imports settings from JSON backup
  /// [settingsData] - Previously exported settings data
  /// [overwriteExisting] - Whether to overwrite existing settings
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> importSettings(
    String userId,
    Map<String, dynamic> settingsData, {
    bool overwriteExisting = false,
  });

  /// Migrates settings from old format to new format
  /// Called automatically when app updates detect schema changes
  /// [fromVersion] - Previous settings schema version
  /// [toVersion] - Target settings schema version
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> migrateSettings(
    String userId,
    int fromVersion,
    int toVersion,
  );

  /// Validates settings data before applying
  /// Returns validation errors if any, or empty list if valid
  /// Returns [List<String>] on success or [Failure] on error
  Future<Either<Failure, List<String>>> validateSettings(
    Map<String, dynamic> settings,
  );

  /// Gets default settings for a new user
  /// Can be customized based on device capabilities, locale, etc.
  /// [deviceInfo] - Optional device information for customization
  /// Returns default [UserSettings] on success or [Failure] on error
  Future<Either<Failure, UserSettings>> getDefaultSettings({
    Map<String, dynamic>? deviceInfo,
  });

  /// Gets default privacy settings for a new user
  /// Uses conservative defaults for privacy
  /// Returns default [PrivacySettings] on success or [Failure] on error
  Future<Either<Failure, PrivacySettings>> getDefaultPrivacySettings();

  /// Backs up settings to cloud storage
  /// Returns backup identifier on success or [Failure] on error
  Future<Either<Failure, String>> backupSettings(String userId);

  /// Restores settings from cloud backup
  /// [backupId] - Identifier of the backup to restore
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> restoreSettings(String userId, String backupId);

  /// Lists available setting backups for a user
  /// Returns list of backup metadata on success or [Failure] on error
  Future<Either<Failure, List<Map<String, dynamic>>>> listBackups(
    String userId,
  );
}

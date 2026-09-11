import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';

/// Repository interface for user privacy preferences.
abstract class SettingsRepository {
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

  /// Gets default privacy settings for a new user
  /// Uses conservative defaults for privacy
  /// Returns default [PrivacySettings] on success or [Failure] on error
  Future<Either<Failure, PrivacySettings>> getDefaultPrivacySettings();
}

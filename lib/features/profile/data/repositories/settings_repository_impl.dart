import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/data/models/profile/privacy_settings_model.dart';
import 'package:dabbler/data/models/profile/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Concrete implementation of [SettingsRepository] backed by Supabase.
///
/// Currently only the privacy-settings surface is wired; other methods
/// (notifications, themes, accessibility, etc.) throw [UnimplementedError]
/// and will be filled in when those features are built out.
class SettingsRepositoryImpl implements SettingsRepository {
  final SupabaseClient _db;

  const SettingsRepositoryImpl(this._db);

  // ---------------------------------------------------------------------------
  // Privacy settings
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, PrivacySettings>> getPrivacySettings(
    String userId,
  ) async {
    try {
      final row = await _db
          .from('privacy_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        // No row yet — return defaults (the backfill migration should have
        // created one, but handle gracefully).
        return const Right(PrivacySettings());
      }

      return Right(PrivacySettingsModel.fromJson(row));
    } on PostgrestException catch (e) {
      return Left(
        ServerFailure(message: 'Failed to load privacy settings: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to load privacy settings: $e'));
    }
  }

  @override
  Future<Either<Failure, PrivacySettings>> updatePrivacySettings(
    String userId,
    PrivacySettings privacySettings,
  ) async {
    try {
      final model = PrivacySettingsModel.fromEntity(privacySettings);
      final payload = model.toJson();
      payload['user_id'] = userId;

      final row = await _db
          .from('privacy_settings')
          .upsert(payload)
          .eq('user_id', userId)
          .select()
          .single();

      return Right(PrivacySettingsModel.fromJson(row));
    } on PostgrestException catch (e) {
      return Left(
        ServerFailure(message: 'Failed to save privacy settings: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to save privacy settings: $e'));
    }
  }

  @override
  Future<Either<Failure, PrivacySettings>> updatePrivacySetting(
    String userId,
    String key,
    dynamic value,
  ) async {
    try {
      final row = await _db
          .from('privacy_settings')
          .update({key: value})
          .eq('user_id', userId)
          .select()
          .single();

      return Right(PrivacySettingsModel.fromJson(row));
    } on PostgrestException catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to update privacy setting: ${e.message}',
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to update privacy setting: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Not yet implemented — future scope
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, UserSettings>> getSettings(String userId) =>
      throw UnimplementedError('getSettings');

  @override
  Future<Either<Failure, UserSettings>> updateSettings(
    String userId,
    UserSettings settings,
  ) => throw UnimplementedError('updateSettings');

  @override
  Future<Either<Failure, UserSettings>> updateSetting(
    String userId,
    String key,
    dynamic value,
  ) => throw UnimplementedError('updateSetting');

  @override
  Future<Either<Failure, UserSettings>> batchUpdateSettings(
    String userId,
    Map<String, dynamic> updates,
  ) => throw UnimplementedError('batchUpdateSettings');

  @override
  Future<Either<Failure, UserSettings>> resetToDefaults(String userId) =>
      throw UnimplementedError('resetToDefaults');

  @override
  Future<Either<Failure, Map<String, bool>>> getNotificationPreferences(
    String userId,
  ) => throw UnimplementedError('getNotificationPreferences');

  @override
  Future<Either<Failure, Map<String, bool>>> updateNotificationPreferences(
    String userId,
    Map<String, bool> preferences,
  ) => throw UnimplementedError('updateNotificationPreferences');

  @override
  Future<Either<Failure, void>> setNotificationEnabled(
    String userId,
    String notificationType,
    bool enabled,
  ) => throw UnimplementedError('setNotificationEnabled');

  @override
  Future<Either<Failure, Map<String, dynamic>>> getThemeSettings(
    String userId,
  ) => throw UnimplementedError('getThemeSettings');

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateThemeSettings(
    String userId,
    Map<String, dynamic> themeSettings,
  ) => throw UnimplementedError('updateThemeSettings');

  @override
  Future<Either<Failure, Map<String, dynamic>>> getAccessibilitySettings(
    String userId,
  ) => throw UnimplementedError('getAccessibilitySettings');

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateAccessibilitySettings(
    String userId,
    Map<String, dynamic> accessibilitySettings,
  ) => throw UnimplementedError('updateAccessibilitySettings');

  @override
  Future<Either<Failure, void>> syncSettings(String userId) =>
      throw UnimplementedError('syncSettings');

  @override
  Future<Either<Failure, bool>> needsSync(String userId) =>
      throw UnimplementedError('needsSync');

  @override
  Future<Either<Failure, DateTime?>> getLastSyncTime(String userId) =>
      throw UnimplementedError('getLastSyncTime');

  @override
  Future<Either<Failure, void>> clearCache(String userId) =>
      throw UnimplementedError('clearCache');

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportSettings(String userId) =>
      throw UnimplementedError('exportSettings');

  @override
  Future<Either<Failure, void>> importSettings(
    String userId,
    Map<String, dynamic> settingsData, {
    bool overwriteExisting = false,
  }) => throw UnimplementedError('importSettings');

  @override
  Future<Either<Failure, void>> migrateSettings(
    String userId,
    int fromVersion,
    int toVersion,
  ) => throw UnimplementedError('migrateSettings');

  @override
  Future<Either<Failure, List<String>>> validateSettings(
    Map<String, dynamic> settings,
  ) => throw UnimplementedError('validateSettings');

  @override
  Future<Either<Failure, UserSettings>> getDefaultSettings({
    Map<String, dynamic>? deviceInfo,
  }) => throw UnimplementedError('getDefaultSettings');

  @override
  Future<Either<Failure, PrivacySettings>> getDefaultPrivacySettings() async =>
      const Right(PrivacySettings());

  @override
  Future<Either<Failure, String>> backupSettings(String userId) =>
      throw UnimplementedError('backupSettings');

  @override
  Future<Either<Failure, void>> restoreSettings(
    String userId,
    String backupId,
  ) => throw UnimplementedError('restoreSettings');

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> listBackups(
    String userId,
  ) => throw UnimplementedError('listBackups');
}

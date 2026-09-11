import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/data/models/profile/privacy_settings_model.dart';
import '../../domain/repositories/settings_repository.dart';

/// Concrete implementation of [SettingsRepository] backed by Supabase.
class SettingsRepositoryImpl implements SettingsRepository {
  final SupabaseClient _db;

  const SettingsRepositoryImpl(this._db);

  @override
  Future<Either<Failure, PrivacySettings>> getPrivacySettings(
    String userId,
  ) async {
    try {
      final row = await _db
          .from(SupabaseConfig.privacySettingsTable)
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
          .from(SupabaseConfig.privacySettingsTable)
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
          .from(SupabaseConfig.privacySettingsTable)
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

  @override
  Future<Either<Failure, PrivacySettings>> getDefaultPrivacySettings() async =>
      const Right(PrivacySettings());
}

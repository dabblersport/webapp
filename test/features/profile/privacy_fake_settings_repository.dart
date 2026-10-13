import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/data/models/profile/privacy_settings_model.dart';
import 'package:dabbler/features/profile/domain/repositories/settings_repository.dart';

/// Hand-written fake: stores settings in memory and records the integer the
/// real repository would upsert (PrivacySettingsModel.toJson). No Supabase.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository(this.stored);

  PrivacySettings stored;
  final List<int> writtenMessagePreference = [];
  final List<int> writtenGameInvitePreference = [];

  @override
  Future<Either<Failure, PrivacySettings>> getPrivacySettings(
    String userId,
  ) async => Right(stored);

  @override
  Future<Either<Failure, PrivacySettings>> updatePrivacySettings(
    String userId,
    PrivacySettings privacySettings,
  ) async {
    final payload = PrivacySettingsModel.fromEntity(privacySettings).toJson();
    writtenMessagePreference.add(payload['message_preference'] as int);
    writtenGameInvitePreference.add(payload['game_invite_preference'] as int);
    stored = PrivacySettingsModel.fromJson(payload);
    return Right(stored);
  }

  @override
  Future<Either<Failure, PrivacySettings>> updatePrivacySetting(
    String userId,
    String key,
    dynamic value,
  ) async => Right(stored);

  @override
  Future<Either<Failure, PrivacySettings>> getDefaultPrivacySettings() async =>
      const Right(PrivacySettings());
}

const kMessagePreferenceInts = {
  CommunicationPreference.anyone: 0,
  CommunicationPreference.friendsOnly: 1,
  CommunicationPreference.organizersOnly: 2,
  CommunicationPreference.none: 3,
};

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/errors/challenge_failures.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/repositories/base_repository.dart';
import 'package:dabbler/data/repositories/challenge_repository.dart';

class ChallengeRepositoryImpl extends BaseRepository
    implements ChallengeRepository {
  const ChallengeRepositoryImpl(super.svc);

  @override
  Future<Result<CreatedChallenge, Failure>> createChallenge({
    required String profileType,
    required String title,
    required String visibility,
    required String sport,
    String? description,
  }) async {
    final sportKey = sport.trim();
    if (sportKey.isEmpty) {
      return const Err(ChallengeSportRequiredFailure());
    }
    final result = await guard(() async {
      final rows = await svc.client.rpc(
        SupabaseConfig.rpcChallengeCreateFn,
        params: {
          'p_profile_type': profileType,
          'p_title': title,
          'p_visibility': visibility,
          'p_sport': sportKey,
          'p_description': description,
        },
      );
      final row = (rows is List ? rows.first : rows) as Map;
      return CreatedChallenge(
        id: row['id'] as String,
        title: row['title'] as String,
        visibility: row['visibility'] as String,
      );
    });
    if (result is Err<CreatedChallenge, Failure>) {
      final cause = result.error.cause;
      if (cause is PostgrestException) {
        final mapped = _mapServerError(cause);
        if (mapped != null) return Err(mapped);
      }
    }
    return result;
  }

  /// Server errors raised with `message = '<code>'` (KAN-678).
  ChallengeCreateFailure? _mapServerError(PostgrestException e) {
    final text = [
      e.message,
      e.details?.toString(),
      e.hint,
      e.code,
    ].whereType<String>().join(' ');
    if (text.contains('sport_required')) {
      return ChallengeSportRequiredFailure(cause: e);
    }
    if (text.contains('invalid_sport')) {
      return ChallengeInvalidSportFailure(cause: e);
    }
    if (text.contains('organiser_required')) {
      return ChallengeOrganiserRequiredFailure(cause: e);
    }
    return null;
  }
}

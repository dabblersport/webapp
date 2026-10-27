import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// The row the challenge-create RPC returns.
class CreatedChallenge {
  const CreatedChallenge({
    required this.id,
    required this.title,
    required this.visibility,
  });

  final String id;
  final String title;
  final String visibility;
}

abstract class ChallengeRepository {
  /// Creates a challenge through the 5-argument challenge-create RPC.
  ///
  /// [sport] is the picked sport key (e.g. `padel`). It is always sent: a blank
  /// key returns [ChallengeSportRequiredFailure] without calling the server.
  Future<Result<CreatedChallenge, Failure>> createChallenge({
    required String profileType,
    required String title,
    required String visibility,
    required String sport,
    String? description,
  });
}

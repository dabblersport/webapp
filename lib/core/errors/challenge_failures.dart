import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// KAN-680: failures the challenge-create RPC raises on purpose. Each one is its
/// own type so a screen can branch on it and show localized copy.
abstract class ChallengeCreateFailure extends Failure {
  const ChallengeCreateFailure({
    required String code,
    required super.message,
    super.cause,
    super.stackTrace,
  }) : super(category: FailureCode.validation, code: code);

  /// User-facing copy for the current locale.
  String localizedMessage(AppLocalizations l10n);
}

/// The sport key was missing or blank (server `sport_required`, or rejected
/// on the client before the call).
class ChallengeSportRequiredFailure extends ChallengeCreateFailure {
  const ChallengeSportRequiredFailure({
    super.message = 'sport_required',
    super.cause,
    super.stackTrace,
  }) : super(code: 'sport_required');

  @override
  String localizedMessage(AppLocalizations l10n) =>
      l10n.challenge_error_sport_required;
}

/// The sport key matches no sport (server `invalid_sport`).
class ChallengeInvalidSportFailure extends ChallengeCreateFailure {
  const ChallengeInvalidSportFailure({
    super.message = 'invalid_sport',
    super.cause,
    super.stackTrace,
  }) : super(code: 'invalid_sport');

  @override
  String localizedMessage(AppLocalizations l10n) =>
      l10n.challenge_error_invalid_sport;
}

/// The caller is not an organiser (server `organiser_required`).
class ChallengeOrganiserRequiredFailure extends ChallengeCreateFailure {
  const ChallengeOrganiserRequiredFailure({
    super.message = 'organiser_required',
    super.cause,
    super.stackTrace,
  }) : super(code: 'organiser_required');

  @override
  String localizedMessage(AppLocalizations l10n) =>
      l10n.challenge_error_organiser_required;
}

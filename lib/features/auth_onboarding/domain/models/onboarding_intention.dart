import 'package:dabbler/l10n/app_localizations.dart';

/// KAN-650: what brings a person to Dabbler. Independent preference data,
/// stored apart from the persona. Behaviour is only ever derived from [key];
/// the English and Arabic labels are display text and are never compared.
enum OnboardingIntention {
  connectPlay('connect_play'),
  playOrganise('play_organise'),
  organise('organise'),
  hostGames('host_games');

  const OnboardingIntention(this.key);

  /// The stable value sent to the server and persisted on the device.
  final String key;

  /// The persona a new account is created with. The first three intentions
  /// are the same Contributor; only host_games is a Partner. Lower-case
  /// DB/API values.
  String get targetPersona => switch (this) {
    OnboardingIntention.hostGames => 'partner',
    _ => 'contributor',
  };

  /// The intention for a stored [key], or null for a missing or unknown key.
  /// There is deliberately no default: an unknown key never invents a choice.
  static OnboardingIntention? fromKey(String? key) {
    for (final intention in values) {
      if (intention.key == key) return intention;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    OnboardingIntention.connectPlay => l10n.onb_intention_connect_play,
    OnboardingIntention.playOrganise => l10n.onb_intention_play_organise,
    OnboardingIntention.organise => l10n.onb_intention_organise,
    OnboardingIntention.hostGames => l10n.onb_intention_host_games,
  };
}

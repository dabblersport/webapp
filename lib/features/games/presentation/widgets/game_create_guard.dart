import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a profile of [profileType] may start Create game under the feature
/// flags (KAN-475). This is the one rule the two Create game route redirects
/// applied twice, copy for copy, and the Create game sheet now applies to
/// every entry point:
///
/// * a `player` is refused while `enablePlayerGameCreation` is off;
/// * an `organiser` is refused while `enableOrganiserGameCreation` is off;
/// * any other profile type (or none yet) is allowed here; the persona rule
///   (`canCreateGameOrMeetup`) is applied separately by `GameCreateGate`.
///
/// The flags are parameters so a test can prove every combination; the
/// defaults are the app's flags.
bool gameCreationAllowed(
  String? profileType, {
  bool playerEnabled = FeatureFlags.enablePlayerGameCreation,
  bool organiserEnabled = FeatureFlags.enableOrganiserGameCreation,
}) {
  if (profileType == 'player' && !playerEnabled) return false;
  if (profileType == 'organiser' && !organiserEnabled) return false;
  return true;
}

/// [gameCreationAllowed] for the signed-in profile read from [container].
bool gameCreationAllowedFor(ProviderContainer container) => gameCreationAllowed(
  container.read(profileControllerProvider).profile?.profileType,
);

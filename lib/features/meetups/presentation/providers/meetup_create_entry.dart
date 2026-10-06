import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the meetups feature is on. Overridable so tests can turn it on.
final meetupsEnabledProvider = Provider<bool>(
  (ref) => FeatureFlags.enableMeetups,
);

/// The active profile's id, the actor that would create the meetup.
final meetupActorProfileIdProvider = Provider<String?>(
  (ref) => ref.watch(profileControllerProvider).profile?.id,
);

/// Whether the Create menu offers "Create meetup".
///
/// Product rule (CEO, 2026-10-06): any signed-in user may create a meet-up,
/// so the tile is offered whenever [meetupsEnabledProvider] is on — whatever
/// the profile state and whatever `can_create_meetup` answers (also before
/// the profile has loaded, and when the check is loading, failing or `false`).
/// The UI carries no role notion. Set for the Alpha test build; revisit
/// before Canary or `main`.
///
/// This authorises nothing; the server stays the authority. If
/// `rpc_create_meetup` refuses, the drawer shows a generic in-sheet message
/// (`meetups_err_create_refused`, via `meetupErrorText`) and stays open.
final canOfferCreateMeetupProvider = Provider<bool>(
  (ref) => ref.watch(meetupsEnabledProvider),
);

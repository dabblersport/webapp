import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
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

/// Whether the Create menu offers "Create meetup": the meetups flag is on
/// AND the active profile's persona may create (`canCreateGameOrMeetup`:
/// player and organiser; not socialiser, not host).
///
/// Product rule (CEO, 2026-10-06, superseding "everyone"): the persona rule
/// is the only role notion in the UI; `can_create_meetup` is not consulted.
/// An unknown persona (profile not loaded yet) hides the tile, so a
/// socialiser or host never sees it flash.
///
/// This authorises nothing; the server stays the authority. If
/// `rpc_create_meetup` refuses (`persona_not_allowed` or `organiser_required`),
/// the drawer shows a generic in-sheet message
/// (`meetups_err_create_refused`, via `meetupErrorText`) and stays open.
final canOfferCreateMeetupProvider = Provider<bool>(
  (ref) =>
      ref.watch(meetupsEnabledProvider) &&
      canCreateGameOrMeetup(ref.watch(activePersonaProvider)),
);

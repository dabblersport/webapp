import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
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
/// Shown while the flag is on and a signed-in profile exists. The server check
/// (`can_create_meetup`) can only *hide* it: an explicit `false` from a working
/// server hides the tile; while the check is loading, or when it fails (the
/// Alpha test build runs before the meetup migrations are applied to the live
/// project, so the RPC errors), the tile is offered. That is fail-open for the
/// UI only, by CEO decision for the Alpha build (2026-10-06): nothing is
/// authorised by it. The server stays the authority — `rpc_create_meetup`
/// refuses a non-organiser with `organiser_required`, and the drawer shows
/// that refusal in place.
final canOfferCreateMeetupProvider = Provider<bool>((ref) {
  if (!ref.watch(meetupsEnabledProvider)) return false;
  final id = ref.watch(meetupActorProfileIdProvider);
  if (id == null) return false;
  return ref
      .watch(canCreateMeetupProvider(id))
      .maybeWhen(data: (bool allowed) => allowed, orElse: () => true);
});

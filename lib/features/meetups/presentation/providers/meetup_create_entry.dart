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

/// The Create menu offers a meet-up only while the flag is on and the server
/// (`can_create_meetup`) says the active profile may create one. A
/// non-organiser never sees it; the RPC still refuses them
/// (`organiser_required`).
final canOfferCreateMeetupProvider = Provider<bool>((ref) {
  if (!ref.watch(meetupsEnabledProvider)) return false;
  final id = ref.watch(meetupActorProfileIdProvider);
  if (id == null) return false;
  return ref.watch(canCreateMeetupProvider(id)).valueOrNull ?? false;
});

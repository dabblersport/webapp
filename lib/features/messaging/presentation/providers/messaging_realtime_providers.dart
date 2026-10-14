import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';

/// Realtime is on only when its flag AND the two flags it hangs on are on
/// (KAN-544). Overridable for tests; every flag is false in committed code.
final messagingRealtimeEnabledProvider = Provider<bool>(
  (ref) =>
      FeatureFlags.messaging &&
      FeatureFlags.enableMessagingGameChat &&
      FeatureFlags.messagingRealtime,
);

/// The signed-in user's id, or null when signed out. Only read when Realtime
/// is enabled, so a build with the flag off never touches Supabase here.
final messagingUserIdProvider = StreamProvider<String?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  String? last = auth.currentUser?.id;
  yield last;
  await for (final change in auth.onAuthStateChange) {
    final id = change.session?.user.id;
    if (id == last) continue; // a token refresh keeps the same user
    last = id;
    yield id;
  }
});

/// Builds the user's channel. Tests override it with a fake.
final messagingWakeChannelFactoryProvider = Provider<WakeChannelFactory>(
  (ref) =>
      (userId) => SupabaseWakeChannel(Supabase.instance.client, userId),
);

/// The ONE private channel of the signed-in user, kept alive for the app.
/// Null when Realtime is off or nobody is signed in. A sign-out, a change of
/// user, or disposal of the container removes the channel.
final messagingWakeChannelProvider = Provider<WakeChannel?>((ref) {
  if (!ref.watch(messagingRealtimeEnabledProvider)) return null;
  final userId = ref.watch(messagingUserIdProvider).valueOrNull;
  if (userId == null) return null;
  final channel = ref.watch(messagingWakeChannelFactoryProvider)(userId);
  ref.onDispose(channel.close);
  return channel;
});

/// The channel status as a stream, starting with the current one.
final messagingWakeStatusProvider = StreamProvider<WakeChannelStatus>((
  ref,
) async* {
  final channel = ref.watch(messagingWakeChannelProvider);
  if (channel == null) return;
  yield channel.status;
  yield* channel.statuses;
});

/// The safety poll while the channel is SUBSCRIBED. A network cadence, not a
/// visual duration.
const int gameChatSafetyPollSeconds = 60;

/// How long after a seq-less (`sync`) wake to look once more if the first
/// fetch found nothing new. A network cadence, not a visual duration.
const int messagingSyncRetrySeconds = 2;

final messagingSyncRetryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: messagingSyncRetrySeconds),
);

/// The cadence the open chat polls at: the normal interval while there is no
/// SUBSCRIBED channel (or Realtime is off: exactly today's behaviour), and the
/// 60 s safety poll while SUBSCRIBED. Null disables polling (tests).
final gameChatEffectivePollProvider = Provider<Duration?>((ref) {
  final base = ref.watch(gameChatPollIntervalProvider);
  if (base == null) return null;
  final channel = ref.watch(messagingWakeChannelProvider);
  if (channel == null) return base;
  final status =
      ref.watch(messagingWakeStatusProvider).valueOrNull ?? channel.status;
  return status == WakeChannelStatus.subscribed
      ? const Duration(seconds: gameChatSafetyPollSeconds)
      : base;
});

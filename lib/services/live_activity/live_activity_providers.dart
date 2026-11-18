// KAN-1005: the Live Activity providers and the app-start wiring.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/feature_flags.dart';

import 'live_activity_controller.dart';
import 'live_activity_service.dart';
import 'live_activity_service_stub.dart';

final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  if (kIsWeb || !FeatureFlags.liveActivities) {
    return const StubLiveActivityService();
  }
  return LiveActivityService.platform();
});

final liveActivityControllerProvider = Provider<LiveActivityController>((ref) {
  final c = LiveActivityController(
    service: ref.watch(liveActivityServiceProvider),
  );
  ref.onDispose(c.dispose);
  return c;
});

/// Owns the lifecycle listener and the auth subscription; both are disposed
/// with the container.
final liveActivityWiringProvider = Provider<void>((ref) {
  final controller = ref.watch(liveActivityControllerProvider);
  controller.start();
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(controller.resumeSync()),
  );
  final auth = Supabase.instance.client.auth.onAuthStateChange.listen(
    (s) => onLiveActivityAuthChange(controller, s.event),
    onError: (Object _) {},
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(auth.cancel());
  });
});

/// Sign-in (and the initial session) syncs; sign-out ends what is shown.
void onLiveActivityAuthChange(
  LiveActivityController controller,
  AuthChangeEvent event,
) {
  switch (event) {
    case AuthChangeEvent.signedIn || AuthChangeEvent.initialSession:
      unawaited(controller.sync());
    case AuthChangeEvent.signedOut:
      unawaited(controller.signedOut());
    default:
      break;
  }
}

/// Called where push is initialised. Does nothing on web or with the flag
/// off; otherwise listens to native events and auth changes and syncs now,
/// on sign-in and on resume, without awaiting (never blocks app start).
void wireLiveActivities(ProviderContainer container) {
  if (kIsWeb || !FeatureFlags.liveActivities) return;
  container.read(liveActivityWiringProvider);
  unawaited(container.read(liveActivityControllerProvider).sync());
}

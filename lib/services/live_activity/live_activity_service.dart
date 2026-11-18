// KAN-1005 (W3-N1): the one Dart interface for Live Activities (iOS
// ActivityKit, Android Live Update). The channel it speaks is
// CHANNEL_CONTRACT.md in this folder. Web, desktop and tests get the stub.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'live_activity_models.dart';
import 'live_activity_service_stub.dart'
    if (dart.library.io) 'live_activity_service_mobile.dart'
    as impl;

export 'live_activity_models.dart';

abstract class LiveActivityService {
  /// The platform implementation: the channel on iOS/Android, else the stub.
  factory LiveActivityService.platform() => impl.createLiveActivityService();

  /// Whether this device can show Live Activities at all.
  Future<bool> isSupported();

  /// Support, permission and push-to-start in one call.
  Future<LiveActivityCapabilities> capabilities();

  /// Starts an activity for [sessionId] from the server's content-state.
  Future<Result<LiveActivityStarted, Failure>> start({
    required String sessionId,
    required LiveActivityContent content,
  });

  /// Replaces the activity's content-state.
  Future<Result<Unit, Failure>> update({
    required String sessionId,
    required String activityId,
    required LiveActivityContent content,
  });

  /// Ends the activity; [content] is its final state when the server sent one.
  Future<Result<Unit, Failure>> end({
    required String sessionId,
    required String activityId,
    LiveActivityContent? content,
    DateTime? dismissalDate,
  });

  /// The activities shown now.
  Future<Result<List<LiveActivityActive>, Failure>> listActive();

  /// Tokens, ends by the user and taps (empty on the stub).
  Stream<LiveActivityEvent> get events;
}

// KAN-1005: the Live Activity stub for web, desktop and unsupported devices.
// Every call does nothing and reports unsupported; nothing throws.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'live_activity_service.dart';

LiveActivityService createLiveActivityService() =>
    const StubLiveActivityService();

class StubLiveActivityService implements LiveActivityService {
  const StubLiveActivityService();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<LiveActivityCapabilities> capabilities() async =>
      LiveActivityCapabilities.unsupported;

  @override
  Future<Result<LiveActivityStarted, Failure>> start({
    required String sessionId,
    required LiveActivityContent content,
  }) async => const Err(liveActivityUnsupported);

  @override
  Future<Result<Unit, Failure>> update({
    required String sessionId,
    required String activityId,
    required LiveActivityContent content,
  }) async => const Err(liveActivityUnsupported);

  @override
  Future<Result<Unit, Failure>> end({
    required String sessionId,
    required String activityId,
    LiveActivityContent? content,
    DateTime? dismissalDate,
  }) async => const Err(liveActivityUnsupported);

  @override
  Future<Result<List<LiveActivityActive>, Failure>> listActive() async =>
      const Ok([]);

  @override
  Stream<LiveActivityEvent> get events => const Stream.empty();
}

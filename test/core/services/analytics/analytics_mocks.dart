import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/check_in/check_in_status.dart';
import 'package:dabbler/data/repositories/check_in_repository.dart';
import 'package:mockito/mockito.dart';

// Hand-written in the shape mockito generates: the build_runner mock builder
// does not run on this SDK, and these two are small.

/// Stands in for the `rpc_track_event` call behind AnalyticsService.
abstract class EventSink {
  Future<void> send(String? name, Map<String, Object?>? props);
}

class MockEventSink extends Mock implements EventSink {
  @override
  Future<void> send(String? name, Map<String, Object?>? props) =>
      (super.noSuchMethod(
            Invocation.method(#send, [name, props]),
            returnValue: Future<void>.value(),
            returnValueForMissingStub: Future<void>.value(),
          )
          as Future<void>);
}

class MockCheckInRepository extends Mock implements CheckInRepository {
  @override
  Future<Result<CheckInResponse, Failure>> performCheckIn({
    Map<String, dynamic>? deviceInfo,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#performCheckIn, [], {#deviceInfo: deviceInfo}),
            returnValue: Future<Result<CheckInResponse, Failure>>.value(
              const Err<CheckInResponse, Failure>(UnknownFailure()),
            ),
          )
          as Future<Result<CheckInResponse, Failure>>);
}

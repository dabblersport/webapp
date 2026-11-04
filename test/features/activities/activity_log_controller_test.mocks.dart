// Mocks for activity_log_controller_test.dart (KAN-852).
//
// Written in the shape mockito's generator emits for @GenerateNiceMocks: a
// full `dart run build_runner build` stalled in this worktree, and a filtered
// one deletes unrelated committed outputs. Regenerating with build_runner
// replaces this file with an equivalent one.

// ignore_for_file: type=lint
import 'dart:async' as _i3;

import 'package:dabbler/core/fp/failure.dart' as _i6;
import 'package:dabbler/core/fp/result.dart' as _i5;
import 'package:dabbler/data/models/social/public_activity.dart' as _i7;
import 'package:dabbler/data/repositories/public_activity_repository.dart'
    as _i4;
import 'package:dabbler/features/activities/data/datasources/activity_feed_datasource.dart'
    as _i2;
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart'
    as _i8;
import 'package:mockito/mockito.dart' as _i1;

/// A nice mock for [_i2.ActivityFeedDatasource].
class MockActivityFeedDatasource extends _i1.Mock
    implements _i2.ActivityFeedDatasource {
  @override
  _i3.Future<List<_i8.ActivityFeedEvent>> getActivityFeed({
    required String? period,
    int? limit = 50,
    DateTime? cursor,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#getActivityFeed, [], {
              #period: period,
              #limit: limit,
              #cursor: cursor,
            }),
            returnValue: _i3.Future<List<_i8.ActivityFeedEvent>>.value(
              <_i8.ActivityFeedEvent>[],
            ),
            returnValueForMissingStub:
                _i3.Future<List<_i8.ActivityFeedEvent>>.value(
                  <_i8.ActivityFeedEvent>[],
                ),
          )
          as _i3.Future<List<_i8.ActivityFeedEvent>>);
}

/// A nice mock for [_i4.PublicActivityRepository].
class MockPublicActivityRepository extends _i1.Mock
    implements _i4.PublicActivityRepository {
  static _i3.Future<_i5.Result<List<_i7.PublicActivity>, _i6.Failure>>
  _empty() => _i3.Future.value(
    const _i5.Ok<List<_i7.PublicActivity>, _i6.Failure>(<_i7.PublicActivity>[]),
  );

  @override
  _i3.Future<_i5.Result<List<_i7.PublicActivity>, _i6.Failure>>
  fetchFollowingActivities({int? limit = 20, int? offset = 0}) =>
      (super.noSuchMethod(
            Invocation.method(#fetchFollowingActivities, [], {
              #limit: limit,
              #offset: offset,
            }),
            returnValue: _empty(),
            returnValueForMissingStub: _empty(),
          )
          as _i3.Future<_i5.Result<List<_i7.PublicActivity>, _i6.Failure>>);

  @override
  _i3.Future<_i5.Result<List<_i7.PublicActivity>, _i6.Failure>>
  fetchUserActivities({
    required String? profileId,
    int? limit = 20,
    int? offset = 0,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#fetchUserActivities, [], {
              #profileId: profileId,
              #limit: limit,
              #offset: offset,
            }),
            returnValue: _empty(),
            returnValueForMissingStub: _empty(),
          )
          as _i3.Future<_i5.Result<List<_i7.PublicActivity>, _i6.Failure>>);
}

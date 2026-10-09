// Mocks for composer_locate_test.dart, written in the shape mockito's
// @GenerateNiceMocks emits (build_runner could not run in this worktree:
// a filtered build crashes in the analyzer linker and a full build exceeds
// 30 minutes). Nice semantics: unstubbed calls return a default.
// ignore_for_file: type=lint
import 'dart:async' as _i3;

import 'package:dabbler/core/services/gps_service.dart' as _i2;
import 'package:dabbler/data/models/area.dart' as _i5;
import 'package:dabbler/data/repositories/area_repository_v2.dart' as _i4;
import 'package:mockito/mockito.dart' as _i1;

class MockGpsService extends _i1.Mock implements _i2.GpsService {
  @override
  _i3.Future<_i2.LocationResult> getCurrentLocation() =>
      (super.noSuchMethod(
            Invocation.method(#getCurrentLocation, []),
            returnValue: _i3.Future<_i2.LocationResult>.value(
              _i2.LocationError('unstubbed'),
            ),
            returnValueForMissingStub: _i3.Future<_i2.LocationResult>.value(
              _i2.LocationError('unstubbed'),
            ),
          )
          as _i3.Future<_i2.LocationResult>);
}

class MockAreaRepository extends _i1.Mock implements _i4.AreaRepository {
  @override
  _i3.Future<List<_i5.Area>> loadAll() =>
      (super.noSuchMethod(
            Invocation.method(#loadAll, []),
            returnValue: _i3.Future<List<_i5.Area>>.value(<_i5.Area>[]),
            returnValueForMissingStub: _i3.Future<List<_i5.Area>>.value(
              <_i5.Area>[],
            ),
          )
          as _i3.Future<List<_i5.Area>>);

  @override
  _i3.Future<_i5.Area?> resolveNearest(double? lat, double? lng) =>
      (super.noSuchMethod(
            Invocation.method(#resolveNearest, [lat, lng]),
            returnValue: _i3.Future<_i5.Area?>.value(),
            returnValueForMissingStub: _i3.Future<_i5.Area?>.value(),
          )
          as _i3.Future<_i5.Area?>);

  @override
  _i3.Future<Map<String, List<_i5.Area>>> areasByDistrict() =>
      (super.noSuchMethod(
            Invocation.method(#areasByDistrict, []),
            returnValue: _i3.Future<Map<String, List<_i5.Area>>>.value(
              <String, List<_i5.Area>>{},
            ),
            returnValueForMissingStub:
                _i3.Future<Map<String, List<_i5.Area>>>.value(
                  <String, List<_i5.Area>>{},
                ),
          )
          as _i3.Future<Map<String, List<_i5.Area>>>);
}

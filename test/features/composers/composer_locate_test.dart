import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'composer_locate_test.mocks.dart';

/// KAN-463 (CTO ruling dreq-d30fdcb3, option b): "Use current location" in
/// the composer reads the device position and names it through the existing
/// read-only `resolveNearest`, never through the app-wide active location.
@GenerateNiceMocks([MockSpec<GpsService>(), MockSpec<AreaRepository>()])
const double lat = 25.2048;
const double lng = 55.2708;

const Area marina = Area(
  id: 'area-1',
  name: 'Dubai Marina',
  district: 'Dubai',
  city: 'Dubai',
  country: 'AE',
  centerLat: lat,
  centerLng: lng,
);

/// Records every state the active location ever takes; the composer must
/// never write it.
class SpyActiveLocation extends ActiveLocationNotifier {
  static int builds = 0;

  @override
  Future<ActiveLocationState> build() async {
    builds++;
    return ActiveLocationDenied();
  }
}

ProviderContainer containerFor(MockGpsService gps, MockAreaRepository areas) {
  final c = ProviderContainer(
    overrides: [
      gpsServiceProvider.overrideWithValue(gps),
      areaRepositoryV2Provider.overrideWithValue(areas),
      activeLocationProvider.overrideWith(SpyActiveLocation.new),
    ],
  );
  addTearDown(c.dispose);
  // Keep the auto-dispose composer alive for the test.
  c.listen(postComposerProvider, (_, __) {});
  return c;
}

void main() {
  late MockGpsService gps;
  late MockAreaRepository areas;

  setUp(() {
    gps = MockGpsService();
    areas = MockAreaRepository();
    SpyActiveLocation.builds = 0;
  });

  test('area resolved sets name and area id', () async {
    when(gps.getCurrentLocation()).thenAnswer(
      (_) async => LocationSuccess(lat: lat, lng: lng, accuracyMeters: 5),
    );
    when(areas.resolveNearest(lat, lng)).thenAnswer((_) async => marina);
    final c = containerFor(gps, areas);

    final outcome = await c
        .read(postComposerProvider.notifier)
        .useCurrentLocation(fallbackName: 'Current location');

    expect(outcome, ComposerLocateOutcome.area);
    final s = c.read(postComposerProvider);
    expect(s.locationName, 'Dubai Marina');
    expect(s.locationTagId, 'area-1');
    expect(s.geoLat, lat);
    expect(s.geoLng, lng);
    expect(s.venueId, isNull);
    verify(areas.resolveNearest(lat, lng)).called(1);
  });

  test('no area sets fallback label and coordinates', () async {
    when(gps.getCurrentLocation()).thenAnswer(
      (_) async => LocationSuccess(lat: lat, lng: lng, accuracyMeters: 5),
    );
    when(areas.resolveNearest(lat, lng)).thenAnswer((_) async => null);
    final c = containerFor(gps, areas);

    final outcome = await c
        .read(postComposerProvider.notifier)
        .useCurrentLocation(fallbackName: 'Current location');

    expect(outcome, ComposerLocateOutcome.coordinates);
    final s = c.read(postComposerProvider);
    expect(s.locationName, 'Current location');
    expect(s.locationTagId, isNull);
    expect(s.geoLat, lat);
    expect(s.geoLng, lng);
  });

  final failures = <String, LocationResult Function()>{
    'denied': LocationDenied.new,
    'denied forever': LocationDeniedForever.new,
    'service off': LocationServiceOff.new,
    'timeout': LocationTimeout.new,
    'error': () => LocationError('boom'),
  };
  for (final e in failures.entries) {
    test('denied leaves state untouched (${e.key})', () async {
      when(gps.getCurrentLocation()).thenAnswer((_) async => e.value());
      final c = containerFor(gps, areas);
      final n = c.read(postComposerProvider.notifier);
      n.setRawLocation(name: 'Kept', lat: 1, lng: 2);
      final before = c.read(postComposerProvider);

      final outcome = await n.useCurrentLocation(
        fallbackName: 'Current location',
      );

      expect(outcome, ComposerLocateOutcome.unavailable);
      expect(identical(c.read(postComposerProvider), before), isTrue);
      verifyNever(areas.resolveNearest(any, any));
    });
  }

  test('denied leaves state untouched (gps throws)', () async {
    when(
      gps.getCurrentLocation(),
    ).thenAnswer((_) async => throw StateError('x'));
    final c = containerFor(gps, areas);
    final before = c.read(postComposerProvider);

    final outcome = await c
        .read(postComposerProvider.notifier)
        .useCurrentLocation(fallbackName: 'Current location');

    expect(outcome, ComposerLocateOutcome.unavailable);
    expect(identical(c.read(postComposerProvider), before), isTrue);
  });

  test('active location is never written', () async {
    when(gps.getCurrentLocation()).thenAnswer(
      (_) async => LocationSuccess(lat: lat, lng: lng, accuracyMeters: 5),
    );
    when(areas.resolveNearest(lat, lng)).thenAnswer((_) async => marina);
    final c = containerFor(gps, areas);
    final seen = <AsyncValue<ActiveLocationState>>[];
    c.listen(activeLocationProvider, (_, next) => seen.add(next));
    await c.read(activeLocationProvider.future);
    final settled = c.read(activeLocationProvider);
    seen.clear();

    await c
        .read(postComposerProvider.notifier)
        .useCurrentLocation(fallbackName: 'Current location');
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty, reason: 'activeLocationProvider was written');
    expect(identical(c.read(activeLocationProvider), settled), isTrue);
    expect(SpyActiveLocation.builds, 1);
    // The composer asked the GPS once, itself — not via the active location.
    verify(gps.getCurrentLocation()).called(1);
  });
}

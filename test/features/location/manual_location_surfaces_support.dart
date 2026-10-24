import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/data/manual_location_catalog.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-526 shared checks for the four location surfaces. The fake is the
/// platform the geolocator plugin talks to (as in the KAN-521 tests): it
/// counts every requestPermission call.
class CountingGeoPlatform extends GeolocatorPlatform {
  CountingGeoPlatform(this.permission);

  LocationPermission permission;
  int requestCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      throw const PermissionDeniedException('denied');

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;
}

/// Installs the fake platform and the device's "OS prompt already used" flag.
CountingGeoPlatform installGeo({
  LocationPermission permission = LocationPermission.deniedForever,
  bool asked = true,
}) {
  SharedPreferences.setMockInitialValues({'location_permission_asked': asked});
  final original = GeolocatorPlatform.instance;
  final fake = CountingGeoPlatform(permission);
  GeolocatorPlatform.instance = fake;
  addTearDown(() => GeolocatorPlatform.instance = original);
  return fake;
}

/// KAN-640: the app's own city and area lists, as the manual flow reads them.
class FakeManualCatalog implements ManualLocationCatalog {
  static const dubai = CatalogCity(
    code: 'dubai',
    nameEn: 'Dubai',
    nameAr: 'دبي',
  );

  @override
  Future<List<CatalogCity>> citiesOf(String countryName) async =>
      countryName == 'United Arab Emirates'
      ? const <CatalogCity>[
          CatalogCity(code: 'abu_dhabi', nameEn: 'Abu Dhabi', nameAr: 'أبوظبي'),
          dubai,
        ]
      : const <CatalogCity>[];

  @override
  Future<List<CatalogArea>> areasOf(CatalogCity city) async =>
      city.code == 'dubai'
      ? const <CatalogArea>[
          CatalogArea(name: 'Downtown Dubai', lat: 25.1972, lng: 55.2744),
          CatalogArea(name: 'Dubai Marina', lat: 25.0805, lng: 55.1403),
        ]
      : const <CatalogArea>[];
}

final fakeCatalogOverride = manualLocationCatalogProvider.overrideWithValue(
  FakeManualCatalog(),
);

/// Walks the drawer: country (when it asks), then the city, then the area.
Future<void> pickDubaiArea(
  WidgetTester tester, {
  String country = 'United Arab Emirates',
  String city = 'Dubai',
  String area = 'Downtown Dubai',
}) async {
  if (find.text(country).evaluate().isNotEmpty &&
      find.text(city).evaluate().isEmpty) {
    await tester.ensureVisible(find.text(country).last);
    await tester.tap(find.text(country).last);
    await frames(tester, 5);
  }
  await tester.ensureVisible(find.text(city).last);
  await tester.tap(find.text(city).last);
  await frames(tester, 5);
  final tile = find.text(area).last;
  await tester.ensureVisible(tile);
  await tester.tap(tile);
}

Future<void> frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer containerFor(WidgetTester tester, Finder surface) =>
    ProviderScope.containerOf(tester.element(surface.first));

/// Denied + asked: the drawer opens once on its own; picking a place updates
/// the active location AND LocationService; the surface shows it; no prompt.
Future<void> expectPickFlow(
  WidgetTester tester,
  CountingGeoPlatform fake,
  Finder surface,
) async {
  await frames(tester);
  expect(find.byType(ManualLocationDrawer), findsOneWidget);
  expect(find.text('Set location'), findsWidgets);

  await pickDubaiArea(tester);
  await frames(tester);
  // Let the success toast finish.
  await tester.pump(const Duration(seconds: 6));
  await frames(tester, 3);

  expect(find.byType(ManualLocationDrawer), findsNothing);
  final state = containerFor(
    tester,
    surface,
  ).read(activeLocationProvider).valueOrNull;
  expect(state, isA<ActiveLocationReady>());
  final loc = (state as ActiveLocationReady).location;
  expect((loc.lat, loc.lng), (25.1972, 55.2744));
  expect(LocationService().currentArea, 'Downtown Dubai');
  expect(LocationService().currentPosition?.latitude, 25.1972);
  // The surface now reads the chosen place.
  expect(find.text('Downtown Dubai'), findsWidgets);
  expect(fake.requestCalls, 0);
}

/// Dismissing leaves the fallback with a visible "Set location" action; it
/// never reopens by itself, and the action reopens it.
Future<void> expectDismissFlow(
  WidgetTester tester,
  CountingGeoPlatform fake,
  Finder surface,
) async {
  await frames(tester);
  expect(find.byType(ManualLocationDrawer), findsOneWidget);
  Navigator.of(tester.element(find.byType(ManualLocationDrawer))).pop();
  await frames(tester);
  expect(find.byType(ManualLocationDrawer), findsNothing);

  // Rebuild the location several times: still no loop.
  final c = containerFor(tester, surface);
  for (var i = 0; i < 3; i++) {
    c.invalidate(activeLocationProvider);
    await frames(tester, 5);
  }
  expect(find.byType(ManualLocationDrawer), findsNothing);
  expect(
    c.read(activeLocationProvider).valueOrNull,
    isA<ActiveLocationDenied>(),
  );

  final action = find.text('Set location');
  expect(action, findsOneWidget);
  await tester.tap(action);
  await frames(tester);
  expect(find.byType(ManualLocationDrawer), findsOneWidget);
  expect(fake.requestCalls, 0);
}

/// Permission granted with a location: the drawer never opens by itself.
Future<void> expectNoDrawer(
  WidgetTester tester,
  CountingGeoPlatform fake,
) async {
  await frames(tester);
  expect(find.byType(ManualLocationDrawer), findsNothing);
  expect(fake.requestCalls, 0);
}

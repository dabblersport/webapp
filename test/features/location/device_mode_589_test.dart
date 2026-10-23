import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:dabbler/features/location/presentation/device_location_section.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-589: Settings > Location "Location on this device". Auto / Manual is
/// per device and persists; Auto asks the OS at most once; a denial opens the
/// manual "Set location" drawer, never re-prompts, and the mode stays Manual.

const _marina = Area(
  id: 'area-marina',
  name: 'Dubai Marina',
  district: 'Marina',
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.08,
  centerLng: 55.14,
);

class _Areas implements AreaRepository {
  @override
  Future<List<Area>> loadAll() async => [_marina];
  @override
  Future<Area?> resolveNearest(double lat, double lng) async => _marina;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => <ProfileLocation>[];
}

class _Platform extends GeolocatorPlatform {
  _Platform(this.permission);
  final LocationPermission permission;
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
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 25.08,
    longitude: 55.14,
    timestamp: DateTime(2026),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

Future<void> _frames(WidgetTester tester, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<DeviceLocation?> _stored() async => DeviceLocationStore(
  await SharedPreferences.getInstance(),
  accountId: null,
).read();

Future<_Platform> _pump(
  WidgetTester tester, {
  required LocationPermission permission,
  required Future<void> Function(DeviceLocationStore) seed,
}) async {
  SharedPreferences.setMockInitialValues({'location_permission_asked': true});
  final original = GeolocatorPlatform.instance;
  final platform = _Platform(permission);
  GeolocatorPlatform.instance = platform;
  addTearDown(() => GeolocatorPlatform.instance = original);
  await seed(
    DeviceLocationStore(await SharedPreferences.getInstance(), accountId: null),
  );
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileLocationNotifierProvider.overrideWith(_NoSaved.new),
        areaRepositoryV2Provider.overrideWithValue(_Areas()),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
        home: const Scaffold(body: DeviceLocationSection()),
      ),
    ),
  );
  await _frames(tester);
  return platform;
}

Future<void> _seedManual(DeviceLocationStore s) =>
    s.setManual(city: 'Dubai', area: 'Dubai Marina', lat: 25.08, lng: 55.14);

Future<void> _seedAuto(DeviceLocationStore s) => s.applyAutoFix(
  city: 'Dubai',
  area: 'Dubai Marina',
  lat: 25.08,
  lng: 55.14,
  explicit: true,
);

void main() {
  testWidgets('Manual shows the place and a Change action', (tester) async {
    await _pump(
      tester,
      permission: LocationPermission.always,
      seed: _seedManual,
    );
    expect(find.text('Location on this device'), findsOneWidget);
    expect(find.text('Dubai Marina'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('Auto / Manual control uses the segmentedCard variant', (
    tester,
  ) async {
    await _pump(
      tester,
      permission: LocationPermission.always,
      seed: _seedManual,
    );
    final DabblerTabs tabs = tester.widget(find.byType(DabblerTabs));
    expect(tabs.variant, DabblerTabsVariant.segmentedCard);
  });

  testWidgets(
    'Auto (granted) switches to Auto and writes it to the device store',
    (tester) async {
      final p = await _pump(
        tester,
        permission: LocationPermission.always,
        seed: _seedManual,
      );
      await tester.tap(find.text('Auto'));
      await _frames(tester);
      final DeviceLocation? stored = await _stored();
      expect(stored?.mode, DeviceLocationMode.auto);
      expect(stored?.provenance, DeviceLocationProvenance.gps);
      expect(find.text('Change'), findsNothing); // Auto hides the manual row
      expect(p.requestCalls, 0);
    },
  );

  testWidgets('Manual from Auto keeps the place as this device\'s Manual '
      'choice and persists', (tester) async {
    await _pump(tester, permission: LocationPermission.always, seed: _seedAuto);
    expect(find.text('Change'), findsNothing);
    await tester.tap(find.text('Manual'));
    await _frames(tester);
    final DeviceLocation? stored = await _stored();
    expect(stored?.mode, DeviceLocationMode.manual);
    expect(stored?.provenance, DeviceLocationProvenance.manual);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('Auto with permission denied opens the Set location drawer, '
      'never re-prompts, and the mode stays Manual', (tester) async {
    final p = await _pump(
      tester,
      permission: LocationPermission.denied,
      seed: _seedManual,
    );
    await tester.tap(find.text('Auto'));
    await _frames(tester);
    expect(find.byType(ManualLocationDrawer), findsOneWidget);
    expect(find.text('Set location'), findsWidgets);
    expect(p.requestCalls, 0); // the OS was asked once before (asked == true)
    expect((await _stored())?.mode, DeviceLocationMode.manual);
    expect(find.text('Change'), findsOneWidget);
  });

  test('a stored Auto mode is Auto again after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _Platform(LocationPermission.always);
    addTearDown(() => GeolocatorPlatform.instance = original);
    await _seedAuto(
      DeviceLocationStore(
        await SharedPreferences.getInstance(),
        accountId: null,
      ),
    );
    final c = ProviderContainer(
      overrides: [
        profileLocationNotifierProvider.overrideWith(_NoSaved.new),
        areaRepositoryV2Provider.overrideWithValue(_Areas()),
      ],
    );
    addTearDown(c.dispose);
    await c.read(activeLocationProvider.future);
    expect(isAutoMode(c.read(activeLocationProvider).valueOrNull), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('a stored Manual mode stays Manual after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    await _seedManual(
      DeviceLocationStore(
        await SharedPreferences.getInstance(),
        accountId: null,
      ),
    );
    final c = ProviderContainer(
      overrides: [
        profileLocationNotifierProvider.overrideWith(_NoSaved.new),
        areaRepositoryV2Provider.overrideWithValue(_Areas()),
      ],
    );
    addTearDown(c.dispose);
    await c.read(activeLocationProvider.future);
    expect(isAutoMode(c.read(activeLocationProvider).valueOrNull), isFalse);
  });
}

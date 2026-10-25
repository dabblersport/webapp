import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:dabbler/features/location/presentation/active_location_label.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/presentation/widgets/location_map_preview.dart';
import 'package:dabbler/features/location/presentation/widgets/point_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import 'manual_location_surfaces_support.dart';

/// KAN-589 (CPO decision, D-035): the device location is the point itself.
/// Three paths: access granted, access denied, and a point outside every
/// covered Area. The Area is optional; saving a point never waits on it.

const _marina = Area(
  id: 'area-marina',
  name: 'Dubai Marina',
  district: 'Marina',
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.08,
  centerLng: 55.14,
);

/// The lookup answers [resolveTo] (null = outside every covered Area), or
/// fails the way it does with no network when [offline].
class _Areas implements AreaRepository {
  _Areas({this.resolveTo, this.offline = false});
  final Area? resolveTo;
  final bool offline;
  @override
  Future<List<Area>> loadAll() async =>
      offline ? throw Exception('offline') : [_marina];
  @override
  Future<Area?> resolveNearest(double lat, double lng) async =>
      offline ? throw Exception('offline') : resolveTo;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const <ProfileLocation>[];
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
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 24.4539,
    longitude: 54.3773,
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

ProviderContainer _container(AreaRepository areas) {
  final c = ProviderContainer(
    overrides: [
      profileLocationNotifierProvider.overrideWith(_NoSaved.new),
      areaRepositoryV2Provider.overrideWithValue(areas),
      mapTokenProvider.overrideWithValue('pk.test'),
      mapTileLayerBuilderProvider.overrideWithValue(
        () => const SizedBox.shrink(),
      ),
      // The manual drawer reads the shared country; keep it off Supabase.
      selectedCountryProvider.overrideWith((ref) => FakeCountry()),
      fakeCatalogOverride,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<DeviceLocation> _stored() async => DeviceLocationStore(
  await SharedPreferences.getInstance(),
  accountId: null,
).read()!;

String _label(ProviderContainer c) => activeLocationLabel(
  AppLocalizationsEn(),
  c.read(activeLocationProvider).valueOrNull,
);

const _manualMarina = <String, Object>{
  'device_location.-.city': 'Dubai',
  'device_location.-.area': 'Dubai Marina',
  'device_location.-.lat': 25.08,
  'device_location.-.lng': 55.14,
  'device_location.-.mode': 'manual',
  'device_location.-.provenance': 'manual',
  'device_location.-.updatedAt': '2026-10-20T10:00:00.000',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  group('granted: the device coordinates are the location', () {
    test('inside a covered Area it reads "Current location", not the area '
        'name', () async {
      GeolocatorPlatform.instance = _Platform(LocationPermission.always);
      SharedPreferences.setMockInitialValues(_manualMarina);
      final c = _container(_Areas(resolveTo: _marina));
      await c.read(activeLocationProvider.future);

      final r = await c.read(activeLocationProvider.notifier).switchToAuto();

      expect(r, AutoSwitchResult.applied);
      final loc = (c.read(activeLocationProvider).value as ActiveLocationReady)
          .location;
      expect(loc.source, ActiveLocationSource.gps);
      expect(loc.lat, 24.4539);
      expect(loc.lng, 54.3773);
      expect(_label(c), 'Current location');
      expect((await _stored()).mode, DeviceLocationMode.auto);
    });

    test('outside every covered Area the coordinates are still saved and '
        'used', () async {
      GeolocatorPlatform.instance = _Platform(LocationPermission.always);
      SharedPreferences.setMockInitialValues(_manualMarina);
      final c = _container(_Areas());
      await c.read(activeLocationProvider.future);

      final r = await c.read(activeLocationProvider.notifier).switchToAuto();

      expect(r, AutoSwitchResult.applied);
      final s = c.read(activeLocationProvider).value;
      expect(s, isA<ActiveLocationReady>());
      final loc = (s as ActiveLocationReady).location;
      expect(loc.area.id, 'point');
      expect(loc.lat, 24.4539);
      expect(loc.lng, 54.3773);
      expect(isAutoMode(s), isTrue);
      expect(_label(c), 'Current location');
      final stored = await _stored();
      expect(stored.lat, 24.4539);
      expect(stored.lng, 54.3773);
      expect(stored.area, isNull);
      expect(stored.mode, DeviceLocationMode.auto);
    });

    test(
      'with no network the coordinates still win over the old area',
      () async {
        GeolocatorPlatform.instance = _Platform(LocationPermission.always);
        SharedPreferences.setMockInitialValues({});
        final c = _container(_Areas(offline: true));
        await c.read(activeLocationProvider.future);

        await c.read(activeLocationProvider.notifier).useGpsLocation();

        final s = c.read(activeLocationProvider).value;
        expect(s, isA<ActiveLocationReady>());
        expect((s as ActiveLocationReady).location.lat, 24.4539);
        expect(_label(c), 'Current location');
      },
    );
  });

  group('denied: no re-prompt, the manual fallback', () {
    test(
      'switchToAuto reports denied, asks nothing and changes nothing',
      () async {
        final platform = _Platform(LocationPermission.deniedForever);
        GeolocatorPlatform.instance = platform;
        SharedPreferences.setMockInitialValues({
          ..._manualMarina,
          'location_permission_asked': true,
        });
        final c = _container(_Areas(resolveTo: _marina));
        await c.read(activeLocationProvider.future);

        final r = await c.read(activeLocationProvider.notifier).switchToAuto();

        expect(r, AutoSwitchResult.denied);
        expect(platform.requestCalls, 0);
        expect(_label(c), 'Dubai Marina');
        expect((await _stored()).mode, DeviceLocationMode.manual);
      },
    );
  });

  group('a picked point is the location', () {
    test('outside every covered Area it is saved as Manual with its '
        'coordinates and no area', () async {
      GeolocatorPlatform.instance = _Platform(LocationPermission.always);
      SharedPreferences.setMockInitialValues({});
      final c = _container(_Areas());
      await c.read(activeLocationProvider.future);

      await c
          .read(activeLocationProvider.notifier)
          .useMapPoint(30.0444, 31.2357);

      final loc = (c.read(activeLocationProvider).value as ActiveLocationReady)
          .location;
      expect(loc.source, ActiveLocationSource.manual);
      expect(loc.lat, 30.0444);
      expect(loc.lng, 31.2357);
      expect(_label(c), 'Selected location');
      final stored = await _stored();
      expect(stored.lat, 30.0444);
      expect(stored.area, isNull);
      expect(stored.mode, DeviceLocationMode.manual);
    });

    test('a searched place keeps its name; a nearby Area only adds its '
        'city', () async {
      GeolocatorPlatform.instance = _Platform(LocationPermission.always);
      SharedPreferences.setMockInitialValues({});
      final c = _container(_Areas(resolveTo: _marina));
      await c.read(activeLocationProvider.future);

      await c
          .read(activeLocationProvider.notifier)
          .useMapPoint(25.08, 55.14, label: 'Pier 7');

      final loc = (c.read(activeLocationProvider).value as ActiveLocationReady)
          .location;
      expect(_label(c), 'Pier 7');
      expect(loc.area.city, 'Dubai');
      expect(loc.lat, 25.08);
    });
  });

  group('Set location drawer', () {
    Future<void> open(WidgetTester tester, ProviderContainer c) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            builder: (context, child) => DabblerToastProvider(child: child!),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: DabblerDesignSystemTheme.withFonts(
              DabblerDesignSystemTheme.withTokens(renderThemeBase()),
              locale: const Locale('en'),
            ),
            home: Builder(
              builder: (context) => Center(
                child: GestureDetector(
                  onTap: () => showSetLocationDrawer(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    setUpAll(() async => loadRenderFonts());

    testWidgets('access granted: a point picker, not the city list', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _Platform(LocationPermission.always);
      SharedPreferences.setMockInitialValues(_manualMarina);
      final c = _container(_Areas());
      await c.read(activeLocationProvider.future);

      await open(tester, c);

      expect(find.byType(PointPickerSheet), findsOneWidget);
      expect(find.byType(ManualLocationDrawer), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Use this location'), findsOneWidget);
    });

    testWidgets('tapping the map moves the pin; "Use this location" saves '
        'that point', (tester) async {
      GeolocatorPlatform.instance = _Platform(LocationPermission.always);
      SharedPreferences.setMockInitialValues(_manualMarina);
      final c = _container(_Areas());
      await c.read(activeLocationProvider.future);
      await open(tester, c);

      final Offset centre = tester.getCenter(find.byType(FlutterMap));
      await tester.tapAt(centre + const Offset(60, 20));
      // The map waits out a possible double tap before it reports the tap.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Use this location'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final loc = (c.read(activeLocationProvider).value as ActiveLocationReady)
          .location;
      expect(loc.source, ActiveLocationSource.manual);
      expect(loc.lat, isNot(25.08));
      expect(loc.lng, greaterThan(55.14));
      expect((await _stored()).lat, loc.lat);
      expect(find.byType(PointPickerSheet), findsNothing);
    });

    testWidgets('access denied: the city / area list is the fallback', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _Platform(LocationPermission.deniedForever);
      SharedPreferences.setMockInitialValues({
        'location_permission_asked': true,
      });
      final c = _container(_Areas());
      await c.read(activeLocationProvider.future);

      await open(tester, c);

      expect(find.byType(ManualLocationDrawer), findsOneWidget);
      expect(find.byType(PointPickerSheet), findsNothing);
    });
  });
}

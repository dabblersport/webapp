import 'dart:io';

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/core/services/location_permission_state.dart';
import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-521 single-prompt rule: the OS location prompt is requested at most
/// once per device, and that survives an app restart. Observed at the
/// platform: the fake counts every requestPermission call.
class _FakePlatform extends GeolocatorPlatform {
  _FakePlatform(this.permission);

  LocationPermission permission;
  LocationPermission afterRequest = LocationPermission.denied;
  int requestCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    permission = afterRequest;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 12.5,
    longitude: 34.5,
    timestamp: DateTime.utc(2026, 10, 14),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// An app restart: the in-memory preferences are dropped and re-read from what
/// was persisted.
Future<void> _restart() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = <String, Object>{
    for (final k in prefs.getKeys()) k: prefs.get(k)!,
  };
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(saved);
}

void main() {
  late GeolocatorPlatform original;
  setUp(() {
    original = GeolocatorPlatform.instance;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  final paths = <String, Future<void> Function()>{
    'intro gateway': () => const GeolocatorPermissionGateway().request(),
    'GpsService (explicit)': () => GpsService().getCurrentLocation(),
    'LocationService (explicit)': () =>
        LocationService().fetchLocation(requestPermission: true),
  };

  group('LocationPermissionState', () {
    test('requestOnce asks the platform once, then only reads', () async {
      final fake = _FakePlatform(LocationPermission.denied);
      GeolocatorPlatform.instance = fake;
      expect(await LocationPermissionState.asked(), isFalse);
      await LocationPermissionState.requestOnce();
      expect(fake.requestCalls, 1);
      expect(await LocationPermissionState.asked(), isTrue);
      final again = await LocationPermissionState.requestOnce();
      expect(fake.requestCalls, 1);
      expect(again, LocationPermission.denied);
    });

    test('the flag is set BEFORE the platform request (a crash mid-prompt '
        'cannot allow a second prompt)', () async {
      late bool askedDuringRequest;
      final fake = _ObservingPlatform(
        onRequest: () async =>
            askedDuringRequest = await LocationPermissionState.asked(),
      );
      GeolocatorPlatform.instance = fake;
      await LocationPermissionState.requestOnce();
      expect(askedDuringRequest, isTrue);
    });

    test('granting later in the OS settings is still honoured', () async {
      final fake = _FakePlatform(LocationPermission.denied);
      GeolocatorPlatform.instance = fake;
      await LocationPermissionState.requestOnce(); // refused
      fake.permission = LocationPermission.whileInUse; // granted in Settings
      expect(
        await LocationPermissionState.requestOnce(),
        LocationPermission.whileInUse,
      );
      expect(fake.requestCalls, 1);
      final r = await GpsService().getCurrentLocation(requestPermission: false);
      expect(r, isA<LocationSuccess>());
    });
  });

  for (final e in paths.entries) {
    test('${e.key}: first explicit request = 1 platform call, the second = 0, '
        'also after a simulated restart', () async {
      final fake = _FakePlatform(LocationPermission.denied);
      GeolocatorPlatform.instance = fake;
      await e.value();
      expect(fake.requestCalls, 1);
      await e.value();
      expect(fake.requestCalls, 1);
      await _restart();
      await e.value();
      expect(fake.requestCalls, 1, reason: 'still 1 after the restart');
    });
  }

  test('one prompt for the whole app: a request on one path blocks every '
      'other path, also after a restart', () async {
    final fake = _FakePlatform(LocationPermission.denied);
    GeolocatorPlatform.instance = fake;
    await paths['intro gateway']!();
    expect(fake.requestCalls, 1);
    await _restart();
    await paths['GpsService (explicit)']!();
    await paths['LocationService (explicit)']!();
    expect(fake.requestCalls, 1);
  });

  test(
    'a device that already asked before this launch is never asked again',
    () async {
      SharedPreferences.setMockInitialValues({
        LocationPermissionState.askedKey: true,
      });
      final fake = _FakePlatform(LocationPermission.denied);
      GeolocatorPlatform.instance = fake;
      for (final p in paths.values) {
        await p();
      }
      expect(fake.requestCalls, 0);
    },
  );

  group('concurrent first requests', () {
    test(
      'overlapping requestOnce calls reach the platform exactly once',
      () async {
        final fake = _SlowPlatform();
        GeolocatorPlatform.instance = fake;
        final results = await Future.wait([
          for (var i = 0; i < 6; i++) LocationPermissionState.requestOnce(),
        ]);
        expect(fake.requestCalls, 1);
        expect(results.toSet().length, 1);
        // later (sequential) calls, also after a restart, still never ask again
        await LocationPermissionState.requestOnce();
        await _restart();
        await LocationPermissionState.requestOnce();
        expect(fake.requestCalls, 1);
      },
    );

    test('overlapping calls from different paths (intro gateway, GpsService, '
        'LocationService) make one platform request', () async {
      final fake = _SlowPlatform();
      GeolocatorPlatform.instance = fake;
      await Future.wait([
        const GeolocatorPermissionGateway().request(),
        GpsService().getCurrentLocation(),
        LocationService().fetchLocation(requestPermission: true),
        const GeolocatorPermissionGateway().request(),
      ]);
      expect(fake.requestCalls, 1);
    });
  });

  group('location picker sheet "Use my current location"', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DabblerToastProvider(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: LocationPickerSheet(
                    header: ValueNotifier(LocationPickerHeader('Add')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> tap(WidgetTester tester) async {
      await tester.tap(find.text('Use my current location'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('first tap asks once; later taps (and after a restart) never '
        'ask again and fall back to the denied toast', (tester) async {
      final fake = _FakePlatform(LocationPermission.denied);
      GeolocatorPlatform.instance = fake;
      await pump(tester);
      await tap(tester);
      expect(fake.requestCalls, 1);
      await tester.runAsync(_restart);
      await tap(tester);
      await tap(tester);
      expect(fake.requestCalls, 1);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(LocationPickerSheet)),
          ).location_permission_denied,
        ),
        findsWidgets,
      );
    });

    testWidgets('already asked on this device: the tap makes 0 requests', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        LocationPermissionState.askedKey: true,
      });
      final fake = _FakePlatform(LocationPermission.denied);
      GeolocatorPlatform.instance = fake;
      await pump(tester);
      await tap(tester);
      expect(fake.requestCalls, 0);
    });
  });

  test('Geolocator.requestPermission is called from one place in lib/: '
      'LocationPermissionState.requestOnce', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.readAsStringSync().contains('Geolocator.requestPermission')) {
        hits.add(f.path);
      }
    }
    expect(hits, ['lib/core/services/location_permission_state.dart']);
  });
}

class _ObservingPlatform extends _FakePlatform {
  _ObservingPlatform({required this.onRequest})
    : super(LocationPermission.denied);

  final Future<void> Function() onRequest;

  @override
  Future<LocationPermission> requestPermission() async {
    await onRequest();
    return super.requestPermission();
  }
}

/// A platform whose permission prompt takes a while to be answered, so that
/// overlapping callers really overlap.
class _SlowPlatform extends _FakePlatform {
  _SlowPlatform() : super(LocationPermission.denied);

  @override
  Future<LocationPermission> requestPermission() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return super.requestPermission();
  }
}

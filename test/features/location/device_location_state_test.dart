import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-586: one per-device current location (city, area, point, Manual/Auto,
/// provenance), scoped to the signed-in account.
Future<DeviceLocationStore> _store(String? account) async {
  return DeviceLocationStore(
    await SharedPreferences.getInstance(),
    accountId: account,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AC1 persistence and account scope', () {
    test('city, area, point, mode and provenance survive a restart', () async {
      await (await _store(
        'u1',
      )).setManual(city: 'Dubai', area: 'Dubai Marina', lat: 25.08, lng: 55.14);
      // A new store object over the same storage is a restart.
      final DeviceLocation l = (await _store('u1')).read()!;
      expect(l.city, 'Dubai');
      expect(l.area, 'Dubai Marina');
      expect((l.lat, l.lng), (25.08, 55.14));
      expect(l.mode, DeviceLocationMode.manual);
      expect(l.provenance, DeviceLocationProvenance.manual);
    });

    test('another account on this device does not see the selection', () async {
      await (await _store(
        'u1',
      )).setManual(city: 'Dubai', area: 'Dubai Marina', lat: 25.08, lng: 55.14);
      expect((await _store('u2')).read(), isNull);
      expect((await _store(null)).read(), isNull);
      expect((await _store('u1')).read()!.city, 'Dubai');
    });
  });

  group('AC2 changing city', () {
    test('a different city clears area and point; distance is off', () async {
      final s = await _store('u1');
      await s.setManual(city: 'Dubai', area: 'Deira', lat: 25.27, lng: 55.31);
      expect(s.read()!.distanceControlsEnabled, isTrue);

      final DeviceLocation next = await s.changeCity('Abu Dhabi');
      expect(next.city, 'Abu Dhabi');
      expect(next.area, isNull);
      expect(next.lat, isNull);
      expect(next.lng, isNull);
      expect(next.distanceControlsEnabled, isFalse);
      // Persisted cleared, not just returned.
      final DeviceLocation stored = s.read()!;
      expect(stored.area, isNull);
      expect(stored.hasPoint, isFalse);
    });

    test('the same city keeps its area and point', () async {
      final s = await _store('u1');
      await s.setManual(city: 'Dubai', area: 'Deira', lat: 25.27, lng: 55.31);
      final DeviceLocation same = await s.changeCity('Dubai');
      expect(same.area, 'Deira');
      expect(same.distanceControlsEnabled, isTrue);
    });

    test('choosing an area afterwards re-enables distance', () async {
      final s = await _store('u1');
      await s.changeCity('Abu Dhabi');
      await s.setManual(
        city: 'Abu Dhabi',
        area: 'Yas Island',
        lat: 24.49,
        lng: 54.6,
      );
      expect(s.read()!.distanceControlsEnabled, isTrue);
    });
  });

  group('AC3 Auto unavailable', () {
    test(
      'keeps the last known point, labelled lastKnown, invents nothing',
      () async {
        final s = await _store('u1');
        await s.applyAutoFix(
          city: 'Dubai',
          area: 'Business Bay',
          lat: 25.18,
          lng: 55.26,
        );
        final DeviceLocation? last = await s.markAutoUnavailable();
        expect(last!.provenance, DeviceLocationProvenance.lastKnown);
        expect((last.lat, last.lng), (25.18, 55.26));
        expect(last.mode, DeviceLocationMode.auto);
      },
    );

    test('with no stored fix there is no point to show', () async {
      final s = await _store('u1');
      expect(await s.markAutoUnavailable(), isNull);
      await s.changeCity('Dubai'); // manual, city only
      expect((await s.markAutoUnavailable())!.hasPoint, isFalse);
    });

    test(
      'a Manual selection is not relabelled when Auto is unavailable',
      () async {
        final s = await _store('u1');
        await s.setManual(city: 'Dubai', area: 'Deira', lat: 25.27, lng: 55.31);
        final DeviceLocation? l = await s.markAutoUnavailable();
        expect(l!.provenance, DeviceLocationProvenance.manual);
        expect(l.mode, DeviceLocationMode.manual);
      },
    );
  });

  group('AC4 per-device independence', () {
    test('device B Auto updates never overwrite device A Manual', () async {
      // Two devices = two separate local storages for the same account.
      SharedPreferences.setMockInitialValues({});
      final SharedPreferences a = await SharedPreferences.getInstance();
      final DeviceLocationStore deviceA = DeviceLocationStore(
        a,
        accountId: 'same-account',
      );
      await deviceA.setManual(
        city: 'Dubai',
        area: 'Dubai Marina',
        lat: 25.08,
        lng: 55.14,
      );

      SharedPreferences.setMockInitialValues({});
      final SharedPreferences b = await SharedPreferences.getInstance();
      final DeviceLocationStore deviceB = DeviceLocationStore(
        b,
        accountId: 'same-account',
      );
      // Device B's Auto fixes move around the country.
      await deviceB.applyAutoFix(
        city: 'Abu Dhabi',
        area: 'Yas Island',
        lat: 24.49,
        lng: 54.6,
      );
      await deviceB.applyAutoFix(
        city: 'Sharjah',
        area: 'Al Majaz',
        lat: 25.33,
        lng: 55.38,
      );
      expect(deviceB.read()!.city, 'Sharjah');
      expect(deviceB.read()!.mode, DeviceLocationMode.auto);

      // Device A is untouched.
      final DeviceLocation a1 = deviceA.read()!;
      expect(a1.city, 'Dubai');
      expect(a1.area, 'Dubai Marina');
      expect(a1.mode, DeviceLocationMode.manual);
    });

    test('on one device an Auto fix does not overwrite Manual either, '
        'unless the user switches back to Auto', () async {
      final s = await _store('u1');
      await s.setManual(city: 'Dubai', area: 'Deira', lat: 25.27, lng: 55.31);
      final DeviceLocation kept = await s.applyAutoFix(
        city: 'Abu Dhabi',
        area: 'Yas Island',
        lat: 24.49,
        lng: 54.6,
      );
      expect(kept.city, 'Dubai');
      expect(s.read()!.area, 'Deira');

      final DeviceLocation auto = await s.applyAutoFix(
        city: 'Abu Dhabi',
        area: 'Yas Island',
        lat: 24.49,
        lng: 54.6,
        explicit: true,
      );
      expect(auto.city, 'Abu Dhabi');
      expect(auto.mode, DeviceLocationMode.auto);
    });

    test('device location touches no profile or service-region key', () async {
      final s = await _store('u1');
      await s.setManual(city: 'Dubai', area: 'Deira', lat: 25.27, lng: 55.31);
      final SharedPreferences p = await SharedPreferences.getInstance();
      expect(
        p.getKeys().every((k) => k.startsWith('device_location.u1.')),
        isTrue,
      );
    });
  });
}

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/location/presentation/active_location_label.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-1022: the chip shows the place name, never the literal "Current
// location" when a name is known.
ActiveLocationReady _ready(
  ActiveLocationSource source, {
  String name = '',
  String city = '',
  String? saved,
}) => ActiveLocationReady(
  ActiveLocation(
    lat: 25.08,
    lng: 55.14,
    area: Area(
      id: 'a',
      name: name,
      district: name,
      city: city,
      country: '',
      centerLat: 25.08,
      centerLng: 55.14,
    ),
    source: source,
    savedLocationLabel: saved,
  ),
);

void main() {
  final l = AppLocalizationsEn();

  test('a device fix with a saved place shows the saved name', () {
    expect(
      activeLocationLabel(
        l,
        _ready(ActiveLocationSource.gps, name: 'Dubai Marina', saved: 'Gym'),
      ),
      'Gym',
    );
  });

  test('a selected saved location shows its name', () {
    expect(
      activeLocationLabel(l, _ready(ActiveLocationSource.saved, saved: 'Home')),
      'Home',
    );
  });

  test('a device fix shows the resolved area name', () {
    expect(
      activeLocationLabel(
        l,
        _ready(ActiveLocationSource.gps, name: 'Dubai Marina', city: 'Dubai'),
      ),
      'Dubai Marina',
    );
  });

  test('a device fix with only a city shows the city', () {
    expect(
      activeLocationLabel(l, _ready(ActiveLocationSource.gps, city: 'Dubai')),
      'Dubai',
    );
  });

  test('a device fix with no resolved name falls back to "Current location"',
      () {
    expect(
      activeLocationLabel(l, _ready(ActiveLocationSource.gps)),
      l.location_current_label,
    );
  });
}

// KAN-697: the pure rules of the Repeat control.
import 'package:dabbler/features/games/domain/models/game_recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSeriesLocation', () {
    test('the venue place wins over the profile place', () {
      final p = resolveSeriesLocation(
        venueGeoLocationId: 'vg',
        venueAreaId: 'va',
        profileGeoLocationId: 'pg',
        profileAreaId: 'pa',
      )!;
      expect((p.geoLocationId, p.areaId), ('vg', 'va'));
    });

    test('a venue with a null or empty id falls back to the profile', () {
      final p = resolveSeriesLocation(
        venueGeoLocationId: 'vg',
        venueAreaId: '',
        profileGeoLocationId: 'pg',
        profileAreaId: 'pa',
      )!;
      expect((p.geoLocationId, p.areaId), ('pg', 'pa'));
    });

    test('nothing usable gives null: no default is invented', () {
      expect(resolveSeriesLocation(), isNull);
      expect(
        resolveSeriesLocation(profileGeoLocationId: 'pg', profileAreaId: null),
        isNull,
      );
    });
  });

  group('seriesOccurrenceCount', () {
    final first = DateTime(2026, 11, 2);

    test('none repeats nothing', () {
      expect(seriesOccurrenceCount(GameRepeat.none, first, null), 0);
    });

    test('no end date counts the cap', () {
      expect(
        seriesOccurrenceCount(GameRepeat.weekly, first, null),
        kMaxSeriesOccurrences,
      );
    });

    test('weekly and every 2 weeks up to an end date, inclusive', () {
      expect(
        seriesOccurrenceCount(GameRepeat.weekly, first, DateTime(2026, 11, 30)),
        5,
      );
      expect(
        seriesOccurrenceCount(
          GameRepeat.biweekly,
          first,
          DateTime(2026, 11, 30),
        ),
        3,
      );
    });

    test('a far end date is capped at 52', () {
      expect(
        seriesOccurrenceCount(GameRepeat.weekly, first, DateTime(2030, 1, 1)),
        kMaxSeriesOccurrences,
      );
    });
  });

  test('an end date must be after the first game', () {
    final first = DateTime(2026, 11, 2, 18);
    expect(seriesEndIsValid(first, DateTime(2026, 11, 2)), isFalse);
    expect(seriesEndIsValid(first, DateTime(2026, 11, 1)), isFalse);
    expect(seriesEndIsValid(first, DateTime(2026, 11, 3)), isTrue);
  });
}

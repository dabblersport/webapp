import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Area _area(String id, String city, String country) => Area(
  id: id,
  name: 'Area $id',
  district: city,
  city: city,
  country: country,
  centerLat: 25,
  centerLng: 55,
);

ActiveLocationReady _ready(Area a) => ActiveLocationReady(
  ActiveLocation(
    lat: 25,
    lng: 55,
    area: a,
    source: ActiveLocationSource.manual,
  ),
);

MeetupListItem _meetup(String id, String title, String? areaId, int day) =>
    MeetupListItem(
      id: id,
      title: title,
      startAt: DateTime.utc(2026, 11, day),
      areaId: areaId,
    );

class _Dubai extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async =>
      ActiveLocationCityOnly('Dubai', country: 'AE');
}

void main() {
  group('listingCityOf', () {
    test('an Area gives its city', () {
      final c = listingCityOf(_ready(_area('a1', 'Dubai', 'AE')));
      expect(c?.name, 'Dubai');
      expect(c?.country, 'AE');
    });

    test('a city without an Area gives that city', () {
      final c = listingCityOf(
        ActiveLocationCityOnly('Doha', country: 'Qatar', countryCode: 'QA'),
      );
      expect(c, const ListingCity('Doha', country: 'Qatar', countryCode: 'QA'));
    });

    test('denied, error and loading have no city', () {
      expect(listingCityOf(ActiveLocationDenied()), isNull);
      expect(listingCityOf(ActiveLocationError('x')), isNull);
      expect(listingCityOf(ActiveLocationLoading()), isNull);
      expect(listingCityOf(null), isNull);
    });
  });

  group('listingCityMissing', () {
    test('loading is not missing: the list loads', () {
      expect(listingCityMissing(const AsyncLoading()), isFalse);
      expect(
        listingCityMissing(
          AsyncData<ActiveLocationState>(ActiveLocationLoading()),
        ),
        isFalse,
      );
    });

    test('settled with no city is missing', () {
      expect(
        listingCityMissing(
          AsyncData<ActiveLocationState>(ActiveLocationDenied()),
        ),
        isTrue,
      );
      expect(
        listingCityMissing(
          AsyncData<ActiveLocationState>(ActiveLocationError('x')),
        ),
        isTrue,
      );
    });

    test('a city is not missing', () {
      expect(
        listingCityMissing(
          AsyncData<ActiveLocationState>(ActiveLocationCityOnly('Dubai')),
        ),
        isFalse,
      );
    });

    test('only a city, no Area, is city-only', () {
      expect(listingCityOnly(ActiveLocationCityOnly('Dubai')), isTrue);
      expect(listingCityOnly(_ready(_area('a1', 'Dubai', 'AE'))), isFalse);
      expect(listingCityOnly(ActiveLocationDenied()), isFalse);
    });
  });

  group('areasOfCity', () {
    final all = <Area>[
      _area('a1', 'Dubai', 'AE'),
      _area('a2', 'dubai', 'United Arab Emirates'),
      _area('a3', 'Paris', 'FR'),
      _area('a4', 'Paris', 'US'),
      _area('a5', 'Abu Dhabi', 'AE'),
    ];

    test('matches the city without regard to case', () {
      final ids = areasOfCity(all, const ListingCity('Dubai')).map((a) => a.id);
      expect(ids, ['a1', 'a2']);
    });

    test('a same-named city of another country is not matched', () {
      final ids = areasOfCity(
        all,
        const ListingCity('Paris', countryCode: 'FR'),
      ).map((a) => a.id);
      expect(ids, ['a3']);
    });

    test('a city with no Areas has none', () {
      expect(areasOfCity(all, const ListingCity('Cairo')), isEmpty);
    });
  });

  group('applyMeetupFilters city and order', () {
    final all = <MeetupListItem>[
      _meetup('m1', 'Zumba in the park', 'a1', 3),
      _meetup('m2', 'aikido basics', 'a1', 1),
      _meetup('m3', 'Padel night', 'other-city', 2),
      _meetup('m4', 'No area meetup', null, 2),
    ];
    final now = DateTime.utc(2026, 10, 30);

    test('only the meetups of the city remain', () {
      final out = applyMeetupFilters(
        all,
        distances: const <String, double>{},
        areaIds: <String>{'a1'},
        now: now,
      );
      expect(out.map((m) => m.id).toSet(), {'m1', 'm2'});
    });

    test('a change of city leaves nothing of the old city', () {
      final out = applyMeetupFilters(
        all,
        distances: const <String, double>{},
        areaIds: <String>{'other-city'},
        now: now,
      );
      expect(out.map((m) => m.id), ['m3']);
    });

    test('with only a city and no sort chosen the order is A to Z', () {
      final out = applyMeetupFilters(
        <MeetupListItem>[
          _meetup('x1', 'Zzz', 'a1', 1),
          _meetup('x2', 'Aaa', 'a1', 9),
        ],
        distances: const <String, double>{},
        areaIds: <String>{'a1'},
        alphabetical: true,
        now: now,
      );
      expect(out.map((m) => m.id), ['x2', 'x1']);
    });

    test('starting soonest, when chosen, orders by start time', () {
      final out = applyMeetupFilters(
        <MeetupListItem>[
          _meetup('x1', 'Aaa', 'a1', 9),
          _meetup('x2', 'Zzz', 'a1', 1),
        ],
        distances: const <String, double>{},
        areaIds: <String>{'a1'},
        now: now,
      );
      expect(out.map((m) => m.id), ['x2', 'x1']);
    });
  });

  test(
    'the sort chip selection: soonest by default, none with only a city',
    () {
      expect(meetupSortSelection(null, cityOnly: false), MeetupSort.soonest);
      expect(meetupSortSelection(null, cityOnly: true), isNull);
      expect(
        meetupSortSelection(MeetupSort.popular, cityOnly: true),
        MeetupSort.popular,
      );
    },
  );

  test('listingCityProvider follows the active location', () async {
    final c = ProviderContainer(
      overrides: [activeLocationProvider.overrideWith(_Dubai.new)],
    );
    addTearDown(c.dispose);
    await c.read(activeLocationProvider.future);
    expect(c.read(listingCityProvider)?.name, 'Dubai');
    expect(c.read(listingCityOnlyProvider), isTrue);
    expect(c.read(listingCityMissingProvider), isFalse);
  });
}

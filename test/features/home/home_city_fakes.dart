/// Fakes for the "Change location" sheet the Home header opens: every data
/// source answered locally. The areas are the frame's own seven
/// (`Home Feed.dc.html`, the city sheet's area list).
library;

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;

Area _area(String id, String name, String district) => Area(
  id: id,
  name: name,
  district: district,
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.1,
  centerLng: 55.2,
);

class FakeAreaRepo implements AreaRepository {
  @override
  Future<Map<String, List<Area>>> areasByDistrict() async =>
      <String, List<Area>>{
        'Nearby areas': <Area>[
          _area('a1', 'Sheikha Fatima Bint Mubarak Street', 'Nearby areas'),
          _area('a2', 'Nad Al Sheba', 'Nearby areas'),
          _area('a3', 'Al Quoz', 'Nearby areas'),
        ],
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSavedLocations extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => <ProfileLocation>[];
}

/// Overrides that let the picker build without a network.
List<Override> cityOverrides(Override areaRepo) => <Override>[
  areaRepo,
  profileLocationNotifierProvider.overrideWith(FakeSavedLocations.new),
];

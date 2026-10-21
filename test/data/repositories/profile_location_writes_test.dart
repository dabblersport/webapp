import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/profile_location_repository_impl.dart';

import '../../helpers/supabase_test_client.dart';

/// KAN-617 criterion 1: saved places (`profile_locations`) never write the
/// public profile's `city` / `country`, on any table.
///
/// Every request the repository sends is recorded and its body inspected.
class _Sent {
  _Sent(this.method, this.table, this.body);
  final String method;
  final String table;
  final Object? body;
  @override
  String toString() => '$method $table $body';
}

const _row = {
  'id': 'loc-1',
  'profile_id': 'p1',
  'geo_location_id': 'geo-1',
  'area_id': 'area-1',
  'lat': 25.2,
  'lng': 55.3,
  'label': 'home',
  'label_custom': null,
  'nearby_radius_meters': 10000,
  'is_primary': true,
  'created_at': '2026-10-21T10:00:00Z',
  'updated_at': '2026-10-21T10:00:00Z',
};

/// Every key at every depth of a decoded JSON body.
Iterable<String> _keys(Object? node) sync* {
  if (node is Map) {
    for (final e in node.entries) {
      yield e.key as String;
      yield* _keys(e.value);
    }
  } else if (node is List) {
    for (final item in node) {
      yield* _keys(item);
    }
  }
}

void main() {
  late List<_Sent> sent;
  late ProfileLocationRepositoryImpl repo;

  setUp(() {
    sent = [];
    final client = buildTestSupabaseClient((http.Request request) async {
      final table = request.url.pathSegments.last;
      final raw = request.body;
      sent.add(
        _Sent(request.method, table, raw.isEmpty ? null : jsonDecode(raw)),
      );
      if (request.method == 'POST') {
        return table == SupabaseConfig.geoLocationsTable
            ? jsonObjectResponse({'id': 'geo-1'}, status: 201, request: request)
            : jsonObjectResponse(_row, status: 201, request: request);
      }
      return emptyOkResponse(request: request);
    });
    repo = ProfileLocationRepositoryImpl(
      SupabaseService(client, SupabaseErrorMapper()),
    );
  });

  void expectNoCityOrCountry() {
    expect(sent, isNotEmpty, reason: 'the operation must issue a write');
    for (final s in sent) {
      final keys = _keys(s.body).toSet();
      expect(keys, isNot(contains('city')), reason: '$s');
      expect(keys, isNot(contains('country')), reason: '$s');
    }
  }

  test('saveLocation (primary and not) writes no city/country', () async {
    for (final primary in [false, true]) {
      sent.clear();
      final result = await repo.saveLocation(
        profileId: 'profile-1',
        lat: 25.2,
        lng: 55.3,
        geoLocationId: 'geo-1',
        areaId: 'area-1',
        label: ProfileLocationLabel.custom,
        labelCustom: 'Gym',
        isPrimary: primary,
      );
      expect(result.isSuccess, isTrue);
      expectNoCityOrCountry();
      // Only the saved-places table is written.
      expect(sent.map((s) => s.table).toSet(), {
        SupabaseConfig.profileLocationsTable,
      });
    }
  });

  test('saveLocation sends the profile id the insert policy checks', () async {
    final result = await repo.saveLocation(
      profileId: 'profile-1',
      lat: 25.2,
      lng: 55.3,
      geoLocationId: 'geo-1',
      areaId: 'area-1',
      label: ProfileLocationLabel.custom,
      labelCustom: 'Gym',
    );
    expect(result.isSuccess, isTrue);
    final body = sent.single.body as Map<String, dynamic>;
    expect(body['profile_id'], 'profile-1');
    expect(body['geo_location_id'], 'geo-1');
  });

  test('resolveGeoLocationId writes no city/country', () async {
    final result = await repo.resolveGeoLocationId(
      lat: 25.2,
      lng: 55.3,
      areaId: 'area-1',
    );
    expect(result.isSuccess, isTrue);
    expectNoCityOrCountry();
    expect(sent.single.table, SupabaseConfig.geoLocationsTable);
  });

  test('setPrimary writes no city/country; the known users write is the '
      'coordinates only', () async {
    final result = await repo.setPrimary(
      'loc-1',
      lat: 25.2,
      lng: 55.3,
      profileId: 'p1',
    );
    expect(result.isSuccess, isTrue);
    expectNoCityOrCountry();

    // KAN-592 owns this write; it is recorded here, not asserted away.
    final users = sent
        .where((s) => s.table == SupabaseConfig.usersTable)
        .toList();
    expect(users, hasLength(1));
    expect((users.single.body as Map).keys.toSet(), {
      'latitude',
      'longitude',
      'last_location_updated_at',
    });
  });

  test('renameLocation writes no city/country', () async {
    final result = await repo.renameLocation(
      'loc-1',
      ProfileLocationLabel.work,
      customName: null,
    );
    expect(result.isSuccess, isTrue);
    expectNoCityOrCountry();
    expect(sent.single.table, SupabaseConfig.profileLocationsTable);
  });

  test('updateRadius writes no city/country', () async {
    final result = await repo.updateRadius('loc-1', 5000);
    expect(result.isSuccess, isTrue);
    expectNoCityOrCountry();
    expect(sent.single.table, SupabaseConfig.profileLocationsTable);
  });

  test('deleteLocation writes no city/country and touches only the saved '
      'places table', () async {
    final result = await repo.deleteLocation('loc-1');
    expect(result.isSuccess, isTrue);
    expectNoCityOrCountry();
    expect(sent.single.method, 'DELETE');
    expect(sent.single.table, SupabaseConfig.profileLocationsTable);
  });
}

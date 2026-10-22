import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

import '../../helpers/supabase_test_client.dart';

/// KAN-617 criteria 1 and 4: the saved-places notifier never writes the public
/// profile's city/country, and changing the primary place leaves the profile
/// provider's city/country as they were.

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _row(String id, {required bool primary}) => {
  'id': id,
  'profile_id': 'p1',
  'geo_location_id': 'geo-$id',
  'area_id': 'area-$id',
  'lat': 25.2,
  'lng': 55.3,
  'label': 'custom',
  'label_custom': 'Place $id',
  'nearby_radius_meters': 10000,
  'is_primary': primary,
  'created_at': '2026-10-21T10:00:00Z',
  'updated_at': '2026-10-21T10:00:00Z',
};

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

UserProfile _profile() => UserProfile(
  id: 'p1',
  userId: 'u1',
  displayName: 'Sam',
  city: 'Dubai',
  country: 'AE',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late List<({String method, String table, Object? body})> sent;
  late ProviderContainer container;
  late _Profile profileNotifier;

  setUp(() {
    sent = [];
    final client = buildTestSupabaseClient((http.Request request) async {
      final table = request.url.pathSegments.last;
      final raw = request.body;
      if (request.method != 'GET') {
        sent.add((
          method: request.method,
          table: table,
          body: raw.isEmpty ? null : jsonDecode(raw),
        ));
      }
      if (request.method == 'GET') {
        return jsonListResponse([
          _row('a', primary: true),
          _row('b', primary: false),
        ], request: request);
      }
      if (request.method == 'POST') {
        return table == SupabaseConfig.geoLocationsTable
            ? jsonObjectResponse(
                {'id': 'geo-new'},
                status: 201,
                request: request,
              )
            : jsonObjectResponse(
                _row('c', primary: false),
                status: 201,
                request: request,
              );
      }
      return emptyOkResponse(request: request);
    });
    profileNotifier = _Profile(ProfileState(profile: _profile()));
    container = ProviderContainer(
      overrides: [
        supabaseServiceProvider.overrideWithValue(
          SupabaseService(client, SupabaseErrorMapper()),
        ),
        profileControllerProvider.overrideWith((ref) => profileNotifier),
      ],
    );
    addTearDown(container.dispose);
  });

  void expectNoCityOrCountryWritten() {
    expect(sent, isNotEmpty);
    for (final s in sent) {
      final keys = _keys(s.body).toSet();
      expect(keys, isNot(contains('city')), reason: '${s.method} ${s.table}');
      expect(
        keys,
        isNot(contains('country')),
        reason: '${s.method} ${s.table}',
      );
    }
  }

  test('every notifier operation writes no city/country', () async {
    final notifier = container.read(profileLocationNotifierProvider.notifier);
    await container.read(profileLocationNotifierProvider.future);

    await notifier.saveLocation(
      lat: 25.2,
      lng: 55.3,
      areaId: 'area-c',
      label: ProfileLocationLabel.custom,
      labelCustom: 'Gym',
      isPrimary: true,
    );
    await notifier.setPrimary('b');
    await notifier.renameLocation('b', ProfileLocationLabel.work);
    await notifier.updateRadius('b', 5000);
    await notifier.updatePrimaryRadius(7000);
    await notifier.deleteLocation('a');

    expectNoCityOrCountryWritten();
    // Each kind of operation reached the server.
    expect(
      sent.map((s) => s.method).toSet(),
      containsAll(['POST', 'PATCH', 'DELETE']),
    );
  });

  test(
    'setPrimary leaves the profile provider city/country unchanged',
    () async {
      await container.read(profileLocationNotifierProvider.future);

      await container
          .read(profileLocationNotifierProvider.notifier)
          .setPrimary('b');

      // The primary place did change ...
      final places = container.read(profileLocationNotifierProvider).value!;
      expect(places.firstWhere((l) => l.id == 'b').isPrimary, isTrue);
      expect(places.firstWhere((l) => l.id == 'a').isPrimary, isFalse);

      // ... and the public profile's city/country did not.
      final profile = container.read(profileControllerProvider).profile!;
      expect(profile.city, 'Dubai');
      expect(profile.country, 'AE');
      expect(identical(profile, profileNotifier.state.profile), isTrue);
    },
  );
}

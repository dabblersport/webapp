import 'dart:async';
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/location/presentation/screens/saved_locations_screen.dart';
import 'package:dabbler/features/location/presentation/widgets/location_map_preview.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/supabase_test_client.dart';
import '../../support/render_mode.dart';

/// KAN-589 round D: the five CEO defects of 2026-10-25, one regression test
/// each: address search, map pan/zoom, one place per location, delete, and a
/// manual choice that applies at once and survives login.

const _marina = Area(
  id: 'area-marina',
  name: 'Dubai Marina',
  district: 'Marina',
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.08,
  centerLng: 55.14,
);

ProfileLocation _place(
  String id, {
  double lat = 25.08,
  double lng = 55.14,
  bool primary = false,
  String custom = 'Gym',
}) => ProfileLocation(
  id: id,
  profileId: 'p1',
  areaId: 'area-marina',
  lat: lat,
  lng: lng,
  label: ProfileLocationLabel.custom,
  labelCustom: custom,
  isPrimary: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Active extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

class _Saved extends ProfileLocationNotifier {
  _Saved(this.places);
  List<ProfileLocation> places;
  final List<String> deleted = [];
  @override
  Future<List<ProfileLocation>> build() async => places;
  @override
  Future<bool> deleteLocation(String locationId) async {
    deleted.add(locationId);
    places = places.where((p) => p.id != locationId).toList();
    state = AsyncData(places);
    return true;
  }
}

class _Areas implements AreaRepository {
  _Areas([this.gate]);
  final Completer<void>? gate;
  @override
  Future<List<Area>> loadAll() async => [_marina];
  @override
  Future<Area?> resolveNearest(double lat, double lng) async {
    await gate?.future;
    return _marina;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Denied extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.deniedForever;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
}

Future<void> _pumpScreen(WidgetTester tester, _Saved saved) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_Active.new),
        profileLocationNotifierProvider.overrideWith(() => saved),
        mapTokenProvider.overrideWithValue('pk.test'),
        mapTileLayerBuilderProvider.overrideWithValue(
          () => const SizedBox.shrink(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        home: const SavedLocationsScreen(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final l = AppLocalizationsEn();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRenderFonts();
  });

  test('defect 1: an address search returns results, worldwide', () async {
    final List<Uri> asked = [];
    // Mapbox answers a London query only when it is not limited to the UAE.
    final client = MockClient((http.Request r) async {
      asked.add(r.url);
      final bool limited = r.url.queryParameters.containsKey('country');
      return http.Response(
        jsonEncode({
          'features': limited
              ? []
              : [
                  {
                    'id': 'f1',
                    'properties': {
                      'name': '221B Baker Street',
                      'full_address': '221B Baker Street, London',
                    },
                    'geometry': {
                      'coordinates': [-0.1586, 51.5238],
                    },
                  },
                ],
        }),
        200,
      );
    });
    final c = ProviderContainer(
      overrides: [
        activeLocationProvider.overrideWith(_Active.new),
        mapTokenProvider.overrideWithValue('pk.test'),
        mapboxHttpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(c.dispose);

    final results = await c.read(
      mapboxGeocodeProvider('221B Baker Street').future,
    );

    expect(results, hasLength(1));
    expect(results.single.name, '221B Baker Street');
    expect(asked.single.queryParameters['access_token'], 'pk.test');
    expect(asked.single.queryParameters.containsKey('country'), isFalse);
  });

  testWidgets('defect 2: the Settings map can be dragged and zoomed '
      '(drag, pinch, mouse wheel)', (tester) async {
    await _pumpScreen(tester, _Saved(const []));
    final FlutterMap map = tester.widget(find.byType(FlutterMap));
    final int flags = map.options.interactionOptions.flags;
    for (final int flag in [
      InteractiveFlag.drag,
      InteractiveFlag.pinchZoom,
      InteractiveFlag.scrollWheelZoom,
      InteractiveFlag.doubleTapZoom,
    ]) {
      expect(InteractiveFlag.hasFlag(flags, flag), isTrue, reason: '$flag');
    }
  });

  test('defect 3: a second place within 25 m of a saved one is refused '
      'and nothing is written', () async {
    final List<String> writes = [];
    final client = buildTestSupabaseClient((http.Request request) async {
      if (request.method == 'GET') {
        return jsonListResponse([
          {
            'id': 'a',
            'profile_id': 'p1',
            'geo_location_id': 'geo-a',
            'area_id': 'area-a',
            'lat': 25.2,
            'lng': 55.3,
            'label': 'custom',
            'label_custom': 'Gym',
            'nearby_radius_meters': 10000,
            'is_primary': true,
            'created_at': '2026-10-21T10:00:00Z',
            'updated_at': '2026-10-21T10:00:00Z',
          },
        ], request: request);
      }
      writes.add('${request.method} ${request.url.pathSegments.last}');
      return request.url.pathSegments.last == SupabaseConfig.geoLocationsTable
          ? jsonObjectResponse({'id': 'geo-new'}, status: 201, request: request)
          : emptyOkResponse(request: request);
    });
    final c = ProviderContainer(
      overrides: [
        supabaseServiceProvider.overrideWithValue(
          SupabaseService(client, SupabaseErrorMapper()),
        ),
        profileControllerProvider.overrideWith(
          (ref) => _Profile(
            ProfileState(
              profile: UserProfile(
                id: 'p1',
                userId: 'u1',
                displayName: 'Sam',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(profileLocationNotifierProvider.future);

    // About 10 m from the saved Gym.
    final bool saved = await c
        .read(profileLocationNotifierProvider.notifier)
        .saveLocation(
          lat: 25.20007,
          lng: 55.30007,
          areaId: 'area-a',
          label: ProfileLocationLabel.custom,
          labelCustom: 'Gym again',
        );

    expect(saved, isFalse);
    expect(writes, isEmpty);
    expect(c.read(profileLocationNotifierProvider).value, hasLength(1));
  });

  testWidgets('defect 4: a saved place is deleted with the trash button '
      'after confirming', (tester) async {
    final saved = _Saved([_place('g1')]);
    await _pumpScreen(tester, saved);
    expect(find.text('Gym'), findsWidgets);

    await tester.tap(find.bySemanticsLabel(l.saved_places_delete).first);
    await tester.pumpAndSettle();
    expect(find.text(l.saved_places_delete_title), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(DabblerDialog),
            matching: find.text(l.saved_places_delete),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(saved.deleted, ['g1']);
    expect(find.text(l.saved_places_delete_title), findsNothing);
    expect(find.text('Gym'), findsNothing);
  });

  group('defect 5: a manual choice', () {
    late GeolocatorPlatform original;
    setUp(() {
      original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _Denied();
      SharedPreferences.setMockInitialValues({
        'location_permission_asked': true,
      });
    });
    tearDown(() => GeolocatorPlatform.instance = original);

    ProviderContainer container(
      String? user,
      List<ProfileLocation> places, [
      Completer<void>? gate,
    ]) {
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(user),
          profileLocationNotifierProvider.overrideWith(() => _Saved(places)),
          areaRepositoryV2Provider.overrideWithValue(_Areas(gate)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('applies at once and still wins over the saved place after '
        'login', () async {
      final gate = Completer<void>();
      final before = container(null, const [], gate);
      await before.read(activeLocationProvider.future);

      // The Area lookup is held: the choice must apply before it answers.
      final pending = before
          .read(activeLocationProvider.notifier)
          .useMapPoint(25.1972, 55.2744, label: 'Burj Khalifa');
      await Future<void>.delayed(Duration.zero);
      final now = before.read(activeLocationProvider).valueOrNull;
      expect(now, isA<ActiveLocationReady>());
      final at = (now! as ActiveLocationReady).location;
      expect(at.source, ActiveLocationSource.manual);
      expect((at.lat, at.lng), (25.1972, 55.2744));
      gate.complete();
      await pending;

      // Sign in: a saved primary place elsewhere must not take over.
      final after = container('u1', [
        _place('home', lat: 25.27, lng: 55.31, primary: true, custom: 'Home'),
      ]);
      final state = await after.read(activeLocationProvider.future);
      expect(state, isA<ActiveLocationReady>());
      final loc = (state as ActiveLocationReady).location;
      expect(loc.source, ActiveLocationSource.manual);
      expect((loc.lat, loc.lng), (25.1972, 55.2744));
      expect(loc.savedLocationId, isNull);
    });
  });
}

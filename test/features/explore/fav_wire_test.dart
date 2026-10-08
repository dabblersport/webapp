import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/games/data/datasources/venues_remote_data_source.dart';
import 'package:dabbler/features/games/data/repositories/venues_repository_impl.dart';
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_favourites.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_setting.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_share.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/features/venues/providers.dart' as venues_providers;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../meetups/meetup_screens_harness.dart';
import '../../support/render_mode.dart';

/// Favourites on the venue and meetup cards (CTO ruling v2): the heart is a
/// favourite with its count, backed by `toggle_favorite`; share has no count.
/// Renders to `fav-wire/app` (set `--dart-define=FAV_WIRE_DIR=...`, and
/// `RENDER_DARK=1` for dark).
const String _shotsDir = String.fromEnvironment(
  'FAV_WIRE_DIR',
  defaultValue: '$kShotsRoot/fav-wire/app',
);

/// Card + toast renders (CEO 2026-10-08): `--dart-define=FAV_TOAST_DIR=<dir>`.
const String _toastDir = String.fromEnvironment(
  'FAV_TOAST_DIR',
  defaultValue: '$kShotsRoot/fav-toast/app',
);
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

class _Location extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.2,
      lng: 55.27,
      source: ActiveLocationSource.saved,
      area: const Area(
        id: 'a1',
        name: 'Dubai Marina',
        district: 'Marina',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.27,
      ),
    ),
  );
}

/// A remote data source that records favourite toggles and can fail them.
class _FakeVenuesRemote implements VenuesRemoteDataSource {
  final List<String> toggles = <String>[];
  bool fail = false;

  /// The server's `favourited` after the toggle.
  bool answer = true;

  @override
  Future<bool> toggleVenueFavorite(String venueId) async {
    toggles.add(venueId);
    if (fail) throw Exception('rpc failed');
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
];

List<VenueWithSportModel> _venues() => const <VenueWithSportModel>[
  VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Elite Football Arena',
    city: 'Dubai',
    area: 'Dubai Silicon Oasis',
    isIndoor: false,
    pricePerHour: 120,
    favoriteCount: 14,
    favouritedByMe: false,
    sports: ['Football'],
    sportsAr: ['كرة القدم'],
  ),
  VenueWithSportModel(
    id: 'v2',
    sportId: 's1',
    nameEn: 'Zayed Indoor Arena',
    city: 'Dubai',
    isIndoor: true,
    pricePerHour: 80,
    favoriteCount: 3,
    favouritedByMe: true,
    sports: ['Football'],
    sportsAr: ['كرة القدم'],
  ),
];

Future<void> _pumpVenues(
  WidgetTester tester,
  _FakeVenuesRemote remote,
  Locale locale,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_Location.new),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        venueAmenityCatalogProvider.overrideWith(
          (ref) async => const <String, VenueAmenityLabel>{},
        ),
        venuesBySportWithFiltersProvider.overrideWith(
          (ref, f) async => _venues(),
        ),
        currentUserIdProvider.overrideWithValue('me'),
        games_providers.venuesRepositoryProvider.overrideWithValue(
          VenuesRepositoryImpl(remoteDataSource: remote),
        ),
        venues_providers.favoriteVenuesForCurrentUserProvider.overrideWith(
          (ref) async => const [],
        ),
        venues_providers.favoriteVenueIdsForCurrentUserProvider.overrideWith(
          (ref) async => <String>{},
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => RepaintBoundary(
          key: const Key('shot'),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: SectionThemed(
          theme: DabblerTheme.main,
          child: const DabblerPage(body: VenuesScreen()),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Share {
  final List<(String, String)> calls = <(String, String)>[];
}

MeetupListItem _meetup(String id, String title) => meetupRow(
  id,
  title: title,
  going: 12,
).copyWith(sportId: 's1', sportNameEn: 'Running', sportNameAr: 'جري');

Future<void> _pumpMeetups(
  WidgetTester tester,
  Locale locale, {
  required Map<String, MeetupFavourite> favourites,
  required MeetupFavouriteToggle toggle,
  required _Share share,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meetupRepositoryProvider.overrideWithValue(
          FakeMeetupRepository()
            ..list = <MeetupListItem>[
              _meetup('a', 'Sunrise run'),
              _meetup('b', 'Hatta trail hike'),
            ],
        ),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        activeLocationProvider.overrideWith(_Location.new),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        meetupSettingsProvider.overrideWith(
          (ref) async => const <String, bool?>{},
        ),
        meetupFavouritesProvider.overrideWith((ref) async => favourites),
        meetupFavouriteToggleProvider.overrideWithValue(toggle),
        meetupShareProvider.overrideWithValue(
          (link, headline) async => share.calls.add((link, headline)),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => RepaintBoundary(
          key: const Key('shot'),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: SectionThemed(
          theme: DabblerTheme.active,
          child: const DabblerPage(body: MeetupsScreen()),
        ),
      ),
    ),
  );
  await settle(tester);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _shootToast(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_toastDir).createSync(recursive: true);
    File('$_toastDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Whether the n-th heart on screen is drawn filled (the viewer's favourite).
bool _filled(WidgetTester tester, int n) => tester
    .widgetList<DabblerListingSocial>(find.byType(DabblerListingSocial))
    .elementAt(n)
    .favourited;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  final String mode = _dark ? 'dark' : 'light';

  group('venue card', () {
    testWidgets('shows the count; the heart toggles optimistically', (
      tester,
    ) async {
      final remote = _FakeVenuesRemote();
      await _pumpVenues(tester, remote, const Locale('en'));
      expect(find.byType(DabblerListingSocial), findsWidgets);
      // First venue: 14, not favourited; second: 3, favourited.
      expect(find.text('14'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(_filled(tester, 0), isFalse);
      await tester.tap(find.bySemanticsLabel('Save venue').first);
      await tester.pump();
      // Optimistic: 15 at once and the heart filled, then the RPC was called
      // with no user id.
      expect(find.text('15'), findsOneWidget);
      expect(_filled(tester, 0), isTrue);
      await settle(tester);
      expect(remote.toggles, ['v1']);
      expect(find.text('15'), findsOneWidget);
      expect(_filled(tester, 0), isTrue);
      expect(find.text('Venue added to favourites'), findsOneWidget);
    }, variant: desktop);

    testWidgets('a failed toggle rolls the heart and count back', (
      tester,
    ) async {
      final remote = _FakeVenuesRemote()..fail = true;
      await _pumpVenues(tester, remote, const Locale('en'));
      await tester.tap(find.bySemanticsLabel('Save venue').first);
      await settle(tester);
      expect(remote.toggles, ['v1']);
      // Rolled back: outline heart, old count.
      expect(_filled(tester, 0), isFalse);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('15'), findsNothing);
      expect(
        find.text("Couldn't update favourites. Try again."),
        findsOneWidget,
      );
    }, variant: desktop);

    testWidgets('unfavouriting decrements', (tester) async {
      await _pumpVenues(
        tester,
        _FakeVenuesRemote()..answer = false,
        const Locale('en'),
      );
      expect(_filled(tester, 1), isTrue);
      await tester.tap(find.bySemanticsLabel('Remove from saved').first);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(_filled(tester, 1), isFalse);
      // The toast follows the server's answer: removed.
      await settle(tester);
      expect(find.text('2'), findsOneWidget);
      expect(_filled(tester, 1), isFalse);
      expect(find.text('Venue removed from favourites'), findsOneWidget);
    }, variant: desktop);

    testWidgets(
      'the heart is at least 45 tall and reachable around the glyph',
      (tester) async {
        final remote = _FakeVenuesRemote();
        await _pumpVenues(tester, remote, const Locale('en'));
        final group = find.byType(DabblerListingSocial).first;
        expect(tester.getSize(group).height, greaterThanOrEqualTo(44));
        final glyph = tester.getRect(
          find.descendant(of: group, matching: find.byType(DabblerIcon)).first,
        );
        await tester.tapAt(glyph.center + Offset(0, glyph.height / 2 + 8));
        await tester.pump();
        expect(remote.toggles, ['v1']);
      },
      variant: desktop,
    );
  });

  group('meetup card', () {
    testWidgets('count, optimistic toggle, server state, share link', (
      tester,
    ) async {
      final share = _Share();
      final calls = <String>[];
      await _pumpMeetups(
        tester,
        const Locale('en'),
        favourites: const {
          'a': (count: 9, mine: false),
          'b': (count: 4, mine: true),
        },
        toggle: (id) async {
          calls.add(id);
          return (count: 10, mine: true);
        },
        share: share,
      );
      expect(find.text('9'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(_filled(tester, 0), isFalse);
      await tester.tap(find.bySemanticsLabel('Add to favourites').first);
      await tester.pump();
      expect(find.text('10'), findsOneWidget);
      expect(_filled(tester, 0), isTrue);
      await settle(tester);
      expect(calls, ['a']);
      expect(_filled(tester, 0), isTrue);
      expect(find.text('Meetup added to favourites'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Share').first);
      await settle(tester);
      expect(share.calls.single.$1, endsWith('/meetups/a'));
    }, variant: desktop);

    testWidgets('a failed toggle rolls back', (tester) async {
      await _pumpMeetups(
        tester,
        const Locale('en'),
        favourites: const {
          'a': (count: 9, mine: false),
          'b': (count: 4, mine: true),
        },
        toggle: (id) async => throw Exception('rpc failed'),
        share: _Share(),
      );
      await tester.tap(find.bySemanticsLabel('Add to favourites').first);
      await settle(tester);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('10'), findsNothing);
      // Rolled back: outline heart again.
      expect(_filled(tester, 0), isFalse);
      expect(
        find.text("Couldn't update favourites. Try again."),
        findsOneWidget,
      );
    }, variant: desktop);

    testWidgets('the group is at least 44 tall', (tester) async {
      await _pumpMeetups(
        tester,
        const Locale('en'),
        favourites: const {},
        toggle: (id) async => (count: 1, mine: true),
        share: _Share(),
      );
      expect(
        tester.getSize(find.byType(DabblerListingSocial).first).height,
        greaterThanOrEqualTo(44),
      );
    }, variant: desktop);
  });

  // Evidence renders: heart off / on, with counts, LTR/RTL.
  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    final l = lookupAppLocalizations(locale);
    for (final (String tag, String label, _FakeVenuesRemote remote, int heart)
        in <(String, String, _FakeVenuesRemote, int)>[
          ('add', l.listing_save_venue, _FakeVenuesRemote(), 0),
          (
            'remove',
            l.listing_remove_saved,
            _FakeVenuesRemote()..answer = false,
            1,
          ),
          ('error', l.listing_save_venue, _FakeVenuesRemote()..fail = true, 0),
        ]) {
      testWidgets('render venue card + toast $tag $mode $dir', (tester) async {
        await _pumpVenues(tester, remote, locale);
        await tester.tap(find.bySemanticsLabel(label).first);
        await settle(tester);
        final toast = switch (tag) {
          'add' => l.fav_toast_venue_added,
          'remove' => l.fav_toast_venue_removed,
          _ => l.fav_toast_error,
        };
        expect(find.text(toast), findsOneWidget);
        // add: filled; remove: outline; error: rolled back to the start.
        expect(_filled(tester, heart), tag == 'add');
        expect(tester.takeException(), isNull);
        await _shootToast(tester, 'card-venue-$tag-$dir');
      }, variant: desktop);
    }

    for (final (String tag, String label, bool server, bool fail, int heart)
        in <(String, String, bool, bool, int)>[
          ('add', l.meetups_favourite, true, false, 0),
          ('remove', l.meetups_unfavourite, false, false, 1),
          ('error', l.meetups_favourite, true, true, 0),
        ]) {
      testWidgets('render meetup card + toast $tag $mode $dir', (tester) async {
        await _pumpMeetups(
          tester,
          locale,
          favourites: const {
            'a': (count: 9, mine: false),
            'b': (count: 4, mine: true),
          },
          toggle: (id) async => fail
              ? throw Exception('rpc failed')
              : (count: server ? 10 : 3, mine: server),
          share: _Share(),
        );
        await tester.tap(find.bySemanticsLabel(label).first);
        await settle(tester);
        final toast = switch (tag) {
          'add' => l.fav_toast_meetup_added,
          'remove' => l.fav_toast_meetup_removed,
          _ => l.fav_toast_error,
        };
        expect(find.text(toast), findsOneWidget);
        expect(_filled(tester, heart), tag == 'add');
        expect(tester.takeException(), isNull);
        await _shootToast(tester, 'card-meetup-$tag-$dir');
      }, variant: desktop);
    }

    testWidgets('render venue card $mode $dir', (tester) async {
      await _pumpVenues(tester, _FakeVenuesRemote(), locale);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'venues-$dir');
    }, variant: desktop);

    testWidgets('render meetup card $mode $dir', (tester) async {
      await _pumpMeetups(
        tester,
        locale,
        favourites: const {
          'a': (count: 9, mine: false),
          'b': (count: 4, mine: true),
        },
        toggle: (id) async => (count: 10, mine: true),
        share: _Share(),
      );
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'meetups-$dir');
    }, variant: desktop);
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/favourites/data/favourite_item.dart';
import 'package:dabbler/features/favourites/presentation/providers/favourites_providers.dart';
import 'package:dabbler/features/favourites/presentation/screens/favourites_screen.dart';
import 'package:dabbler/features/games/data/repositories/favorites_repository.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// The Favourites screen (`Favourites.dc.html`): tabs, compact rows, the red
/// heart that removes, the Ended section, per-tab empty states.
/// Renders go to `--dart-define=FAVOURITES_DIR=<dir>` (`RENDER_DARK=1` for dark).
const String _dir = String.fromEnvironment(
  'FAVOURITES_DIR',
  defaultValue: '$kShotsRoot/favourites-screen/app',
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

class _Repo implements FavoritesRepository {
  _Repo([this.answer]);
  final Result<FavoriteState, Failure>? answer;
  final List<String> calls = <String>[];

  /// The server holds its answer until the test completes this.
  final Completer<void> gate = Completer<void>();

  @override
  Future<Result<FavoriteState, Failure>> toggle(
    FavoriteTarget target,
    String targetId,
  ) async {
    calls.add('${target.wire}:$targetId');
    await gate.future;
    return answer ?? const Ok((favourited: false, count: 0));
  }
}

final DateTime _now = DateTime.now();

List<FavouriteItem> _items(FavouriteKind kind) => switch (kind) {
  FavouriteKind.venue => const <FavouriteItem>[
    FavouriteItem(
      id: 'v1',
      kind: FavouriteKind.venue,
      title: 'Elite Football Arena',
      titleAr: 'ملعب النخبة لكرة القدم',
      area: 'Dubai Silicon Oasis',
      rating: 4.8,
      latitude: 25.23,
      longitude: 55.3,
    ),
    FavouriteItem(
      id: 'v2',
      kind: FavouriteKind.venue,
      title: 'The Padel Yard',
      titleAr: 'ساحة البادل',
      area: 'Al Quoz',
      rating: 4.6,
      latitude: 25.14,
      longitude: 55.23,
    ),
  ],
  FavouriteKind.game => <FavouriteItem>[
    FavouriteItem(
      id: 'g1',
      kind: FavouriteKind.game,
      title: 'Tuesday 5-a-side',
      place: 'Elite Football Arena',
      startAt: _now.add(const Duration(days: 2)),
      endAt: _now.add(const Duration(days: 2, hours: 1)),
      playersIn: 8,
      capacity: 10,
    ),
    FavouriteItem(
      id: 'g2',
      kind: FavouriteKind.game,
      title: 'Padel doubles',
      place: 'The Padel Yard',
      startAt: _now.add(const Duration(days: 3)),
      endAt: _now.add(const Duration(days: 3, hours: 1)),
      playersIn: 3,
      capacity: 4,
    ),
    FavouriteItem(
      id: 'g3',
      kind: FavouriteKind.game,
      title: 'Friday night futsal',
      place: 'Elite Football Arena',
      startAt: _now.subtract(const Duration(days: 5, hours: 2)),
      endAt: _now.subtract(const Duration(days: 5, hours: 1)),
      playersIn: 10,
      capacity: 10,
    ),
    FavouriteItem(
      id: 'g4',
      kind: FavouriteKind.game,
      title: 'Basketball 3v3',
      place: 'Al Barsha Courts',
      startAt: _now.subtract(const Duration(days: 10, hours: 2)),
      endAt: _now.subtract(const Duration(days: 10, hours: 1)),
      playersIn: 6,
      capacity: 6,
    ),
  ],
  FavouriteKind.meetup => <FavouriteItem>[
    FavouriteItem(
      id: 'm1',
      kind: FavouriteKind.meetup,
      title: 'Kite Beach morning run',
      place: 'Kite Beach',
      startAt: _now.add(const Duration(days: 1)),
      endAt: _now.add(const Duration(days: 1, hours: 1)),
      going: 14,
    ),
    FavouriteItem(
      id: 'm2',
      kind: FavouriteKind.meetup,
      title: 'Sunset yoga',
      place: 'Safa Park',
      startAt: _now.subtract(const Duration(days: 4, hours: 2)),
      endAt: _now.subtract(const Duration(days: 4, hours: 1)),
      going: 22,
    ),
  ],
};

Future<GoRouter> _pump(
  WidgetTester tester,
  Locale locale, {
  FavouriteKind kind = FavouriteKind.venue,
  Map<FavouriteKind, List<FavouriteItem>>? data,
  _Repo? repo,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/start',
    routes: <RouteBase>[
      GoRoute(
        path: '/start',
        builder: (_, __) => const SizedBox.shrink(),
        routes: <RouteBase>[
          GoRoute(
            path: 'favs',
            builder: (_, __) => FavouritesScreen(initialKind: kind),
          ),
        ],
      ),
      GoRoute(
        path: '/sports/venues/:id',
        builder: (_, s) => Text('venue ${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/sports/games/:id',
        builder: (_, s) => Text('game ${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/meetups/:id',
        builder: (_, s) => Text('meetup ${s.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_Location.new),
        favoritesRepositoryProvider.overrideWithValue(repo ?? _Repo()),
        favouritesProvider.overrideWith(
          (ref, k) async =>
              (data ??
                  {for (final k in FavouriteKind.values) k: _items(k)})[k] ??
              const <FavouriteItem>[],
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
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
      ),
    ),
  );
  router.push('/start/favs');
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return router;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final b =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

final _hearts = find.byWidgetPredicate(
  (w) => w is DabblerFeedAction && w.icon == 'heart',
);

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  group('rows', () {
    testWidgets('venues: name, area · distance · rating, red heart', (
      tester,
    ) async {
      await _pump(tester, const Locale('en'));
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l.fav_title), findsOneWidget);
      expect(find.text('Elite Football Arena'), findsOneWidget);
      expect(find.textContaining('Dubai Silicon Oasis · '), findsOneWidget);
      // Area, distance, rating, then a clean star: nothing stray between the
      // rating and the star.
      expect(find.text('4.8'), findsOneWidget);
      final stars = tester
          .widgetList<DabblerIcon>(find.byType(DabblerIcon))
          .where((w) => w.name == 'star')
          .toList();
      expect(stars, hasLength(2));
      // Plain (linear) star: the bold glyph draws shooting-star dashes.
      expect(stars.every((s) => s.weight == DabblerIconWeight.linear), isTrue);
      final metas = tester
          .widgetList<DabblerText>(find.byType(DabblerText))
          .map((w) => w.data ?? '')
          .where((d) => d.startsWith('Dubai Silicon Oasis'))
          .toList();
      expect(metas, hasLength(1));
      expect(
        metas.single,
        matches(RegExp(r'^Dubai Silicon Oasis · [\d.]+ km$')),
      );
      expect(_hearts, findsNWidgets(2));
      final heart = tester.widget<DabblerFeedAction>(_hearts.first);
      expect(heart.weight, DabblerIconWeight.bold);
      expect(find.text(l.fav_ended), findsNothing);
    });

    testWidgets('games: upcoming first, then an Ended divider and section', (
      tester,
    ) async {
      await _pump(tester, const Locale('en'), kind: FavouriteKind.game);
      final l = lookupAppLocalizations(const Locale('en'));
      final upcoming = tester.getTopLeft(find.text('Tuesday 5-a-side')).dy;
      final ended = tester.getTopLeft(find.text(l.fav_ended)).dy;
      final past = tester.getTopLeft(find.text('Friday night futsal')).dy;
      expect(upcoming < ended && ended < past, isTrue);
      expect(find.textContaining('8/10 players'), findsOneWidget);
      // Ended names are softer than upcoming ones.
      DabblerTextTone toneOf(String name) => tester
          .widget<DabblerText>(find.widgetWithText(DabblerText, name))
          .tone;
      expect(toneOf('Tuesday 5-a-side'), DabblerTextTone.primary);
      expect(toneOf('Friday night futsal'), DabblerTextTone.secondary);
    });

    testWidgets('meetups: going for upcoming, went for ended', (tester) async {
      await _pump(tester, const Locale('en'), kind: FavouriteKind.meetup);
      expect(find.textContaining('14 going'), findsOneWidget);
      expect(find.textContaining('22 went'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
    });

    testWidgets('tapping the tabs switches the list', (tester) async {
      await _pump(tester, const Locale('en'));
      await tester.tap(find.text('Games'));
      await _settle(tester);
      expect(find.text('Padel doubles'), findsOneWidget);
      expect(find.text('Elite Football Arena'), findsNothing);
    });

    testWidgets('a row opens its detail', (tester) async {
      await _pump(tester, const Locale('en'), kind: FavouriteKind.game);
      await tester.tap(find.text('Tuesday 5-a-side'));
      await _settle(tester);
      expect(find.text('game g1'), findsOneWidget);
    });
  });

  group('empty', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final kind in FavouriteKind.values) {
        testWidgets('${kind.name} - ${locale.languageCode}', (tester) async {
          await _pump(
            tester,
            locale,
            kind: kind,
            data: {for (final k in FavouriteKind.values) k: const []},
          );
          final l = lookupAppLocalizations(locale);
          final title = switch (kind) {
            FavouriteKind.venue => l.fav_empty_venues_title,
            FavouriteKind.game => l.fav_empty_games_title,
            FavouriteKind.meetup => l.fav_empty_meetups_title,
          };
          final body = switch (kind) {
            FavouriteKind.venue => l.fav_empty_venues_body,
            FavouriteKind.game => l.fav_empty_games_body,
            FavouriteKind.meetup => l.fav_empty_meetups_body,
          };
          expect(find.text(title), findsOneWidget);
          expect(find.text(body), findsOneWidget);
        });
      }
    }

    testWidgets('English copy is the design\'s', (tester) async {
      await _pump(
        tester,
        const Locale('en'),
        kind: FavouriteKind.venue,
        data: {for (final k in FavouriteKind.values) k: const []},
      );
      expect(find.text('No favourite venues yet.'), findsOneWidget);
      expect(
        find.text('Tap the heart on a venue to save it here.'),
        findsOneWidget,
      );
    });
  });

  group('remove', () {
    testWidgets('the row goes at once; the removed toast follows', (
      tester,
    ) async {
      final repo = _Repo(const Ok((favourited: false, count: 3)));
      await _pump(
        tester,
        const Locale('en'),
        kind: FavouriteKind.game,
        repo: repo,
      );
      await tester.tap(_hearts.first);
      await tester.pump();
      expect(find.text('Tuesday 5-a-side'), findsNothing);
      expect(find.text('Game removed from favourites'), findsNothing);
      repo.gate.complete();
      await _settle(tester);
      expect(repo.calls, ['game:g1']);
      expect(find.text('Game removed from favourites'), findsOneWidget);
      expect(find.text('Tuesday 5-a-side'), findsNothing);
    });

    testWidgets('a failed removal brings the row back with the error toast', (
      tester,
    ) async {
      final repo = _Repo(Err(Failure.from('boom')));
      await _pump(
        tester,
        const Locale('en'),
        kind: FavouriteKind.meetup,
        repo: repo,
      );
      await tester.tap(_hearts.first);
      await tester.pump();
      expect(find.text('Kite Beach morning run'), findsNothing);
      repo.gate.complete();
      await _settle(tester);
      expect(find.text('Kite Beach morning run'), findsOneWidget);
      expect(
        find.text("Couldn't update favourites. Try again."),
        findsOneWidget,
      );
    });
  });

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    final String mode = _dark ? 'dark' : 'light';
    for (final kind in FavouriteKind.values) {
      testWidgets('render ${kind.name} with items $mode $dir', (tester) async {
        await _pump(tester, locale, kind: kind);
        expect(tester.takeException(), isNull);
        await _shoot(tester, '${kind.name}s-items-$dir');
      });
      testWidgets('render ${kind.name} empty $mode $dir', (tester) async {
        await _pump(
          tester,
          locale,
          kind: kind,
          data: {for (final k in FavouriteKind.values) k: const []},
        );
        expect(tester.takeException(), isNull);
        await _shoot(tester, '${kind.name}s-empty-$dir');
      });
    }
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/welcome_sport_poster.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-490: the sport poster behind Welcome (after sign-up) and Welcome Back.
/// Renders: `--dart-define=WELCOME_POSTER_DIR=<dir>` (+ `RENDER_DARK=1`).
const String _dir = String.fromEnvironment('WELCOME_POSTER_DIR');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

/// The eleven supplied posters: stable key -> the unchanged source PNG.
const Map<String, String> _sources = <String, String>{
  'football': 'Retro Halftone Football Poster.png',
  'basketball': 'Retro Basketball Court Close-Up.png',
  'badminton': 'Retro Badminton Shuttlecock Poster.png',
  'cycling': 'Retro Bicycle Wheel on Ochre Road.png',
  'cricket': 'Retro Cricket Stumps and Ball.png',
  'gym': 'Retro Halftone Dumbbell Poster.png',
  'tennis': 'Retro Halftone Tennis Ball on Clay Court.png',
  'padel': 'Retro Padel Paddle and Ball Poster.png',
  'swimming': 'Retro Poolside Goggles Poster.png',
  'running': 'Retro Running Sneaker on Track.png',
  'volleyball': 'Retro Volleyball Over Net.png',
};

Finder get _poster => find.byWidgetPredicate(
  (w) => w is DabblerSportBackground && w.artwork != null,
);

String? _shownPosterAsset(WidgetTester tester) {
  final f = _poster;
  if (f.evaluate().isEmpty) return null;
  return (tester.widget(f.first) as DabblerSportBackground).artwork!.assetPath;
}

Future<void> _pump(
  WidgetTester tester, {
  required bool returning,
  String? routeKey,
  WelcomeSavedSportLoader? loader,
  Locale locale = const Locale('en'),
  Size size = const Size(402, 874),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            RepaintBoundary(key: const Key('shot'), child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: WelcomeScreen(
          displayName: 'Sam Player',
          personaType: 'player',
          isFirstTime: !returning,
          primarySportKey: routeKey,
          savedSportLoader: loader ?? () async => null,
        ),
      ),
    ),
  );
  await tester.pump();
  if (settle) await _loadPoster(tester);
}

/// Decodes the shown poster (if any) before the frame is captured.
Future<void> _loadPoster(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  final asset = _shownPosterAsset(tester);
  if (asset != null) {
    await tester.runAsync(() async {
      await precacheImage(
        AssetImage(asset),
        tester.element(find.byType(WelcomeScreen)),
      );
    });
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_dir.isEmpty) return;
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

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final String mode = _dark ? 'dark' : 'light';

  group('mapping and assets', () {
    test('11 stable keys map to bundled WebPs under 400 KB', () {
      expect(welcomeSportPosters.keys.toSet(), _sources.keys.toSet());
      for (final e in welcomeSportPosters.entries) {
        expect(e.value, 'assets/images/sport_welcome/${e.key}.webp');
        final f = File(e.value);
        expect(f.existsSync(), isTrue, reason: e.value);
        expect(f.lengthSync(), lessThan(400 * 1024), reason: e.value);
      }
    });

    test('supplied source PNGs are present; the 404 art is not mapped', () {
      for (final n in _sources.values) {
        expect(File('assets/images/$n').existsSync(), isTrue, reason: n);
      }
      expect(
        welcomeSportPosters.values.any((v) => v.contains('Cleats')),
        isFalse,
      );
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/images/sport_welcome/'));
      final listed = pubspec
          .split('\n')
          .where((l) => l.trim().startsWith('- assets/'))
          .join('\n');
      expect(listed, isNot(contains('Retro')));
      expect(listed, isNot(contains('.png"')));
      expect(listed, isNot(contains('Hanging Football Cleats')));
    });

    test('lookup: stable key only; missing / unsupported -> none', () {
      expect(welcomePosterAsset('football'), isNotNull);
      expect(welcomePosterAsset(' Football '), isNotNull);
      for (final k in <String?>[
        null,
        '',
        'golf',
        'table-tennis',
        'handball',
        'Football Club',
        'كرة القدم',
        'cleats',
      ]) {
        expect(welcomePosterAsset(k), isNull, reason: '$k');
      }
      expect(welcomePosterBackground('golf'), isNull);
    });
  });

  for (final e in welcomeSportPosters.entries) {
    testWidgets('Welcome (sign-up) shows the ${e.key} poster', (tester) async {
      await _pump(tester, returning: false, routeKey: e.key);
      expect(_shownPosterAsset(tester), e.value);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'welcome-${e.key}-en-$mode');
    });

    testWidgets('Welcome Back shows the saved ${e.key} poster without route '
        'extras', (tester) async {
      await _pump(tester, returning: true, loader: () async => e.key);
      expect(_shownPosterAsset(tester), e.value);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'welcomeback-${e.key}-en-$mode');
    });
  }

  group('sign-up, saved sport, isolation, fallbacks', () {
    testWidgets('sign-up selected sport wins over a different saved sport', (
      tester,
    ) async {
      await _pump(
        tester,
        returning: false,
        routeKey: 'tennis',
        loader: () async => 'football',
      );
      expect(_shownPosterAsset(tester), welcomeSportPosters['tennis']);
    });

    testWidgets('sign-up without a route key falls back to the saved sport', (
      tester,
    ) async {
      await _pump(tester, returning: false, loader: () async => 'padel');
      expect(_shownPosterAsset(tester), welcomeSportPosters['padel']);
    });

    testWidgets('per-account isolation: each screen shows only its own '
        "account's sport", (tester) async {
      await _pump(tester, returning: true, loader: () async => 'cricket');
      expect(_shownPosterAsset(tester), welcomeSportPosters['cricket']);
      // Another account signs in: a fresh screen, its own loader.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, returning: true, loader: () async => 'swimming');
      expect(_shownPosterAsset(tester), welcomeSportPosters['swimming']);
      // Account with no sport: normal background, never the previous poster.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, returning: true, loader: () async => null);
      expect(_shownPosterAsset(tester), isNull);
    });

    for (final c in <String, String?>{
      'missing': null,
      'unsupported (golf)': 'golf',
      'unsupported (table-tennis)': 'table-tennis',
      'unknown key': 'quidditch',
    }.entries) {
      testWidgets('Welcome Back with ${c.key} sport uses the normal '
          'background', (tester) async {
        await _pump(tester, returning: true, loader: () async => c.value);
        expect(_shownPosterAsset(tester), isNull);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
        await _shoot(
          tester,
          'welcomeback-fallback-${c.key.split(' ').first}-en-$mode',
        );
      });
    }

    testWidgets('Welcome with an unsupported route key and no saved sport '
        'uses the normal background', (tester) async {
      await _pump(tester, returning: false, routeKey: 'golf');
      expect(_shownPosterAsset(tester), isNull);
      await _shoot(tester, 'welcome-fallback-golf-en-$mode');
    });

    testWidgets('loader failure falls back without error', (tester) async {
      await _pump(
        tester,
        returning: true,
        loader: () async => throw StateError('offline'),
      );
      expect(_shownPosterAsset(tester), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while the saved sport loads there is no poster (no wrong '
        'sport flash), then the right one', (tester) async {
      final done = Completer<String?>();
      await _pump(
        tester,
        returning: true,
        loader: () => done.future,
        settle: false,
      );
      expect(_shownPosterAsset(tester), isNull);
      await _shoot(tester, 'welcomeback-loading-en-$mode');
      done.complete('running');
      await tester.pump();
      await tester.pump();
      expect(_shownPosterAsset(tester), welcomeSportPosters['running']);
      await _loadPoster(tester);
    });

    testWidgets('Continue is unchanged: the same buttons and labels', (
      tester,
    ) async {
      final l = lookupAppLocalizations(const Locale('en'));
      await _pump(tester, returning: true, loader: () async => 'football');
      expect(find.text(l.auth_welcome_continue), findsOneWidget);
      expect(find.text(l.auth_welcome_back_title('Sam')), findsOneWidget);
    });
  });

  group('English / Arabic phone views', () {
    for (final (String lang, Locale locale) in <(String, Locale)>[
      ('en', const Locale('en')),
      ('ar', const Locale('ar')),
    ]) {
      for (final (String name, Size size) in <(String, Size)>[
        ('se', const Size(375, 667)),
        ('pro', const Size(402, 874)),
        ('max', const Size(430, 932)),
      ]) {
        for (final key in <String>['football', 'swimming', 'cricket']) {
          testWidgets('$key welcome + welcome back - $lang $name', (
            tester,
          ) async {
            await _pump(
              tester,
              returning: false,
              routeKey: key,
              locale: locale,
              size: size,
            );
            expect(tester.takeException(), isNull);
            await _shoot(tester, 'welcome-$key-$lang-$name-$mode');
            await tester.pumpWidget(const SizedBox());
            await _pump(
              tester,
              returning: true,
              loader: () async => key,
              locale: locale,
              size: size,
            );
            expect(tester.takeException(), isNull);
            await _shoot(tester, 'welcomeback-$key-$lang-$name-$mode');
          });
        }
      }
    }
  });
}

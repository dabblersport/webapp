import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders the post and game composers (and their DS sheets) to PNG with the
/// real bundled faces. Writes files only with
/// `--dart-define=COMPOSER_SHOTS_DIR=<dir>`; otherwise it still pumps every
/// frame and checks it renders cleanly.
const String _shotsDir = String.fromEnvironment('COMPOSER_SHOTS_DIR');

Future<void> _loadFonts() async {
  await loadRenderFonts();
  final String dsFonts = '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf', 'Glory-Regular.ttf', 'Glory-Medium.ttf',
    'Glory-SemiBold.ttf', 'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf', 'meral-sans-regular.ttf', 'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf', 'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader = FontLoader('packages/iconsax_flutter/FlutterIconsax')
      ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}


/// The full design vibe list (`DabblerVibe`), as the vibes table serves it.
final List<Vibe> _vibes = <Vibe>[
  for (final v in DabblerVibe.values)
    Vibe(
      id: v.key,
      key: v.key,
      labelEn: v.label,
      labelAr: v.label,
      type: v.type.name,
    ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale,
  Key key, {
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibesProvider.overrideWith((ref) async => _vibes),
        ...extraOverrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: DabblerPage(
          body: Align(alignment: Alignment.bottomCenter, child: screen),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps [screen] inside the route frame the app opens it in
/// (`AdaptiveModalPage`: scrim, rounded surface, 94% cap) at 393x852.
Future<void> _pumpModal(
  WidgetTester tester,
  Widget screen,
  Locale locale,
  Key key, {
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibesProvider.overrideWith((ref) async => _vibes),
        ...extraOverrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: Navigator(
          pages: <Page<void>>[
            const MaterialPage<void>(
              child: DabblerPage(body: SizedBox.expand()),
            ),
            AdaptiveModalPage(child: screen),
          ],
          onPopPage: (route, result) => route.didPop(result),
        ),
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('renders the post composer — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).composer_create_post), findsOneWidget);
      expect(find.byType(DabblerComposerBox), findsOneWidget);
      expect(find.text('Add GIF'), findsNothing);
      await _shoot(tester, key, 'post-$dir');
    }, variant: desktop);

    testWidgets('post composer: vibe picker sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      await tester.tap(find.bySemanticsLabel(lookupAppLocalizations(locale).composer_add_vibe));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Happy'), findsWidgets);
      await _shoot(tester, key, 'post-vibes-$dir');
    }, variant: desktop);

    testWidgets('post composer: media + visibility sheets — $dir',
        (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      await tester.tap(find.bySemanticsLabel(lookupAppLocalizations(locale).composer_add_media));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).composer_take_photo), findsOneWidget);
      await _shoot(tester, key, 'post-media-$dir');
    }, variant: desktop);

    testWidgets('renders the game composer — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).game_create), findsWidgets);
      await _shoot(tester, key, 'game-$dir');
    }, variant: desktop);

    testWidgets('game composer: date sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      await tester.tap(find.text(lookupAppLocalizations(locale).game_date));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerCalendar), findsOneWidget);
      await _shoot(tester, key, 'game-date-$dir');
    }, variant: desktop);

    testWidgets('game composer: time sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      await tester.tap(find.text(lookupAppLocalizations(locale).game_time));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTimePicker), findsOneWidget);
      await _shoot(tester, key, 'game-time-$dir');
    }, variant: desktop);
  }

  // KAN-459: the Create post states the design draws (`Home Feed.dc.html`
  // "Create post"), filled and with each picker open, at 393x852 in both
  // directions. Brightness follows `--dart-define=RENDER_DARK=1`.
  final List<Override> pickerData = <Override>[
    venueSearchProvider.overrideWith(
      (ref, q) async => <Map<String, dynamic>>[
        <String, dynamic>{'id': 'v1', 'name': 'Nad Al Sheba Sports Complex', 'city': 'Nad Al Sheba'},
        <String, dynamic>{'id': 'v2', 'name': 'Al Warqa Practice Nets', 'city': 'Al Warqa'},
      ],
    ),
    gameSearchProvider.overrideWith(
      (ref, q) async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'g1',
          'title': 'Padel doubles',
          'sport': 'padel',
          'start_at': DateTime(2026, 8, 19, 19).toIso8601String(),
        },
      ],
    ),
    activeSportsByProfileCountryProvider.overrideWith(
      (ref) async => const <Sport>[
        Sport(id: 's1', nameEn: 'Football', sportKey: 'football'),
        Sport(id: 's2', nameEn: 'Padel', sportKey: 'padel'),
        Sport(id: 's3', nameEn: 'Gym', sportKey: 'gym'),
        Sport(id: 's4', nameEn: 'Cricket', sportKey: 'cricket'),
      ],
    ),
  ];

  Future<void> fill(WidgetTester tester) async {
    final PostComposerNotifier n = ProviderScope.containerOf(
      tester.element(find.byType(PostComposerScreen)),
    ).read(postComposerProvider.notifier);
    await tester.enterText(
      find.byType(EditableText).first,
      'Anyone up for padel this Friday? Need two more #dabblerpadel',
    );
    n.setVibe(id: 'inspired', label: 'Inspired', emoji: '\u2728');
    n.setSport(id: 's2', name: 'Padel', emoji: '\u{1F3BE}');
    n.setRawLocation(name: 'Nad Al Sheba Sports Complex');
    n.setGame(id: 'g1', name: 'Padel doubles');
    n.addMediaUrl('https://example.invalid/a.jpg');
    n.addMediaUrl('https://example.invalid/b.jpg');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final AppLocalizations l = lookupAppLocalizations(locale);

    testWidgets('KAN-459 initial state — $dir', (tester) async {
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: pickerData);
      expect(tester.takeException(), isNull);
      expect(find.text(l.composer_create_post), findsOneWidget);
      expect(find.byType(DabblerChip), findsNothing);
      expect(find.byType(DabblerBadge), findsNothing);
      expect(find.byType(DabblerAttachmentAddTile), findsNothing);
      await _shoot(tester, key, 'kan459-initial-$dir');
    }, variant: desktop);

    testWidgets('KAN-459 filled state — $dir', (tester) async {
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: pickerData);
      await fill(tester);
      expect(tester.takeException(), isNull);
      // vibe chip, sport, location and game badges share one height.
      expect(find.byType(DabblerChip), findsOneWidget);
      expect(find.byType(DabblerBadge), findsNWidgets(3));
      expect(find.byType(DabblerAttachmentChip), findsNWidgets(2));

      // Vertical rhythm of `Home Feed.dc.html` Create post (393x852): 15dp
      // author -> pills -> card -> media rail, 18dp rail -> options; pills
      // draw before the card and the card's glyph row carries the five tools.
      final Rect avatar = tester.getRect(find.byType(DabblerAvatar));
      final Rect pills = tester.getRect(find.byType(DabblerSelectPill).first);
      final Rect box = tester.getRect(find.byType(DabblerComposerBox));
      final Rect rail = tester.getRect(find.byType(DabblerAttachmentAddTile));
      final Rect options = tester.getRect(find.byType(ComposerSettingsRow).first);
      expect(pills.top - avatar.bottom, 15);
      expect(box.top - pills.bottom, 15);
      expect(rail.top - box.bottom, 15);
      expect(options.top - rail.bottom, 18);
      // Only the vibe, sport, location and game tools take the active ink.
      final List<DabblerComposerTool> tools = tester
          .widget<DabblerComposerBox>(find.byType(DabblerComposerBox))
          .tools;
      expect(tools.map((t) => t.active), <bool>[false, true, true, true, true]);
      await _shoot(tester, key, 'kan459-filled-$dir');
    }, variant: desktop);

    testWidgets('KAN-459 pickers over the filled state — $dir', (tester) async {
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: pickerData);
      await fill(tester);

      Future<void> open(Finder f, String shot, {String? type}) async {
        await tester.tap(f);
        await settle(tester);
        if (type != null) {
          await tester.enterText(find.byType(EditableText).last, type);
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
        await _shoot(tester, key, 'kan459-$shot-$dir');
        await tester.tapAt(const Offset(10, 10));
        await settle(tester);
      }

      await open(find.bySemanticsLabel(RegExp('Vibe: Inspired')), 'vibe-sheet');
      await open(find.bySemanticsLabel(RegExp('Sport: Padel')), 'sport-sheet');
      await open(find.bySemanticsLabel(RegExp('Location: ')), 'place-sheet',
          type: 'Nad');
      await open(find.bySemanticsLabel(RegExp('Game: ')), 'game-sheet',
          type: 'Pad');
      await open(find.text(l.composer_type_dab), 'kind-sheet');
      await open(find.text(l.composer_vis_public), 'visibility-sheet');
      await open(find.bySemanticsLabel(l.composer_add_more_media), 'media-sheet');
    }, variant: desktop);
  }
}

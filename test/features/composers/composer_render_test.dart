import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
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
  Key key,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibesProvider.overrideWith((ref) async => _vibes),
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

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
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
}

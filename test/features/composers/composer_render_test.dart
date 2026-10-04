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

Future<void> _loadFonts() async {
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


const List<Vibe> _vibes = <Vibe>[
  Vibe(id: '1', key: 'happy', labelEn: 'Happy', labelAr: 'سعيد', type: 'feeling'),
  Vibe(id: '2', key: 'calm', labelEn: 'Calm', labelAr: 'هادئ', type: 'feeling'),
  Vibe(id: '3', key: 'energetic', labelEn: 'Energetic', labelAr: 'نشيط', type: 'action'),
  Vibe(id: '4', key: 'proud', labelEn: 'Proud', labelAr: 'فخور', type: 'feeling'),
  Vibe(id: '5', key: 'focused', labelEn: 'Focused', labelAr: 'مركّز', type: 'action'),
  Vibe(id: '6', key: 'grateful', labelEn: 'Grateful', labelAr: 'ممتن', type: 'feeling'),
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
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('renders the post composer — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text('Create post'), findsOneWidget);
      expect(find.byType(DabblerComposerBox), findsOneWidget);
      expect(find.text('Add GIF'), findsNothing);
      await _shoot(tester, key, 'post-$dir');
    }, variant: desktop);

    testWidgets('post composer: vibe picker sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      await tester.tap(find.bySemanticsLabel('Add vibe'));
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
      await tester.tap(find.bySemanticsLabel('Add media'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Take Photo'), findsOneWidget);
      await _shoot(tester, key, 'post-media-$dir');
    }, variant: desktop);

    testWidgets('renders the game composer — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text('Create game'), findsWidgets);
      await _shoot(tester, key, 'game-$dir');
    }, variant: desktop);

    testWidgets('game composer: date sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      await tester.tap(find.text('Date'));
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
      await tester.tap(find.text('Time'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTimePicker), findsOneWidget);
      await _shoot(tester, key, 'game-time-$dir');
    }, variant: desktop);
  }
}

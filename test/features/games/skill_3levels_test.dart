import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/widgets/composer_drawer_kit.dart'
    show ComposerPickerRow;
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/games_listing_card.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/enums/game_enums.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// One skill scale (CEO 2026-10-08): Beginner 1-3 / Intermediate 4-6 /
/// Advanced 7-10, no Pro. The two composer pickers, a game card whose stored
/// (9, 10) is the old Pro window, and the band helpers.
/// Renders go to `--dart-define=SKILL_DIR=<dir>`.
const String _dir = String.fromEnvironment(
  'SKILL_DIR',
  defaultValue: '$kShotsRoot/skill-3levels/app',
);
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

Future<void> _pump(WidgetTester tester, Widget body, Locale locale) async {
  tester.view.physicalSize = const Size(393, 520);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: const Key('shot'), child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: Builder(
          builder: (context) => ColoredBox(
            color: DabblerColors.of(context).bgPrimary,
            child: SafeArea(
              child: Align(alignment: Alignment.topCenter, child: body),
            ),
          ),
        ),
      ),
    ),
  );
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

NearbyGameModel _game(int? min, int? max) => NearbyGameModel(
  id: 'g',
  title: 'Evening game',
  sportName: 'Football',
  scheduledAt: DateTime.now().add(const Duration(days: 1)),
  status: 'upcoming',
  venueName: 'Dubai Sports City',
  distanceMeters: 3100,
  playerCount: 6,
  spotsRemaining: 4,
  minSkill: min,
  maxSkill: max,
  isPublic: true,
);

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  group('bands', () {
    test('every stored 1-10 value reads into exactly one band', () {
      final expected = [0, 0, 0, 1, 1, 1, 2, 2, 2, 2];
      for (var v = 1; v <= 10; v++) {
        expect(skillBandIndexForValue(v), expected[v - 1], reason: '$v');
      }
      expect(skillBandIndexForValue(0), 0);
      expect(skillBandIndexForValue(11), 2);
    });

    test('a profile write value reads back into its own band', () {
      for (var i = 0; i < 3; i++) {
        expect(skillBandIndexForValue(kSkillBandWriteValues[i]), i);
      }
    });

    test('the game and meetup ranges are the bands', () {
      expect(kSkillBandRanges, [(1, 3), (4, 6), (7, 10)]);
      expect(MeetupSkillRows.bands.map((b) => (b.$2, b.$3)), kSkillBandRanges);
    });
  });

  testWidgets('the game picker offers three levels and no Pro', (tester) async {
    String? picked;
    await _pump(
      tester,
      GameSkillPickerSheet(
        onSelect: (v) => picked = v,
        onClear: () {},
        canClear: false,
      ),
      const Locale('en'),
    );
    expect(find.text('Beginner'), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('\u20667–10\u2069'), findsOneWidget);
    expect(find.text('Pro'), findsNothing);
    expect(find.text('\u20669–10\u2069'), findsNothing);
    await tester.tap(find.text('Advanced'));
    expect(picked, 'Advanced');
  });

  testWidgets('the meetup picker: three levels, a legacy (9, 10) is Advanced', (
    tester,
  ) async {
    int? min;
    int? max;
    await _pump(
      tester,
      MeetupSkillRows(minSkill: 9, onPick: (a, b) => (min, max) = (a, b)),
      const Locale('en'),
    );
    expect(find.text('Pro'), findsNothing);
    expect(find.text('\u20664–6\u2069'), findsOneWidget);
    final advanced = tester.widget<ComposerPickerRow>(
      find.ancestor(
        of: find.text('Advanced'),
        matching: find.byType(ComposerPickerRow),
      ),
    );
    expect(advanced.selected, isTrue);
    await tester.tap(find.text('Advanced'));
    expect((min, max), (7, 10));
  });

  testWidgets('both composers speak Arabic: labels and subtitles', (
    tester,
  ) async {
    await _pump(
      tester,
      GameSkillPickerSheet(onSelect: (_) {}, onClear: () {}, canClear: false),
      const Locale('ar'),
    );
    for (final t in ['مبتدئ', 'متوسط', 'متقدم', 'مستوى تنافسي']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Beginner'), findsNothing);
    expect(find.text('Competitive level'), findsNothing);
    await _pump(
      tester,
      MeetupSkillRows(minSkill: null, onPick: (_, __) {}),
      const Locale('ar'),
    );
    for (final t in ['مبتدئ', 'متوسط', 'متقدم', 'مستوى تنافسي']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Advanced'), findsNothing);
  });

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    final String mode = _dark ? 'dark' : 'light';
    testWidgets('render game composer skill sheet $mode $dir', (tester) async {
      await _pump(
        tester,
        GameSkillPickerSheet(onSelect: (_) {}, onClear: () {}, canClear: false),
        locale,
      );
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'game-composer-skill-$dir');
    });

    testWidgets('render meetup composer skill $mode $dir', (tester) async {
      await _pump(
        tester,
        MeetupSkillRows(minSkill: 9, onPick: (_, __) {}),
        locale,
      );
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'meetup-composer-skill-$dir');
    });

    testWidgets('render legacy (9, 10) game card shows Advanced $mode $dir', (
      tester,
    ) async {
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.all(DabblerSpacing.space6),
          child: GamesListingCard(game: _game(9, 10)),
        ),
        locale,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text(locale.languageCode == 'ar' ? 'متقدم' : 'Advanced'),
        findsOneWidget,
      );
      expect(find.text('Pro'), findsNothing);
      await _shoot(tester, 'game-card-legacy-9-10-$dir');
    });
  }
}

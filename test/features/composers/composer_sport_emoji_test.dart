import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/presentation/composer_emoji.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-478: the Create Post sport sheet hands the design emoji to the DS slot
/// `DabblerInputRow.emoji`; Create Game (no `emojiFor`) is unchanged.
/// PNGs only with `--dart-define=SPORT_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('SPORT_SHOTS_DIR');

const _mapped = <String, String>{
  'football': 'Football',
  'padel': 'Padel',
  'cricket': 'Cricket',
  'basketball': 'Basketball',
  'running': 'Running',
  'gym': 'Gym',
  'swimming': 'Swimming',
  'tennis': 'Tennis',
  'volleyball': 'Volleyball',
};
const _unmapped = <String, String>{
  'table_tennis': 'Table Tennis',
  'yoga': 'Yoga',
  'squash': 'Squash',
  'rugby': 'Rugby',
  'hockey': 'Hockey',
  'handball': 'Handball',
  'baseball': 'Baseball',
};

final _sportsProvider = Provider<AsyncValue<List<Sport>>>(
  (ref) => AsyncData([
    for (final e in {..._mapped, ..._unmapped}.entries)
      Sport(id: e.key, nameEn: e.value, sportKey: e.key),
  ]),
);

/// Exactly the wiring `post_composer_screen.dart` passes.
String? _createPostEmoji(Sport s) => composerSportEmoji(s.sportKey ?? s.nameEn);

Future<void> _open(
  WidgetTester tester, {
  required Locale locale,
  required Brightness brightness,
  required bool createPost,
  Key? key,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final base = renderThemeBase();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            base.copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: base.colorScheme.primary,
                brightness: brightness,
              ),
            ),
          ),
          locale: locale,
        ),
        home: DabblerPage(
          body: Builder(
            builder: (context) => Center(
              child: DabblerButton(
                label: 'open',
                onPressed: () => showComposerSportSheet(
                  context,
                  title: 'Sport',
                  sportsProvider: _sportsProvider,
                  onConfirm: (_) {},
                  emojiFor: createPost ? _createPostEmoji : null,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('open'));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DabblerInputRow _row(WidgetTester tester, String title) => tester.widget(
  find.ancestor(of: find.text(title), matching: find.byType(DabblerInputRow)),
);

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('Create Post sport rows pass the design emoji to '
        'DabblerInputRow.emoji, none for unmapped sports — $dir', (
      tester,
    ) async {
      await _open(
        tester,
        locale: locale,
        brightness: Brightness.light,
        createPost: true,
      );
      expect(tester.takeException(), isNull);
      for (final e in _mapped.entries) {
        final row = _row(tester, e.value);
        expect(row.emoji, composerSportEmojiByKey[e.key], reason: e.key);
        expect(row.emoji, isNotNull, reason: e.key);
        expect(row.leading, isNull, reason: 'emoji replaces the icon');
      }
      expect(_row(tester, 'Football').emoji, '⚽️');
      for (final e in _unmapped.entries) {
        final row = _row(tester, e.value);
        expect(row.emoji, isNull, reason: e.key);
        expect(row.leading, isA<DabblerSportIcon>(), reason: e.key);
      }
    });

    testWidgets('Create Post emoji slot sits before the name in reading '
        'direction, 26 wide — $dir', (tester) async {
      await _open(
        tester,
        locale: locale,
        brightness: Brightness.light,
        createPost: true,
      );
      final rowFinder = find.ancestor(
        of: find.text('Football'),
        matching: find.byType(DabblerInputRow),
      );
      final emojiText = find.descendant(
        of: rowFinder,
        matching: find.text('⚽️'),
      );
      expect(emojiText, findsOneWidget);
      final slot = find
          .ancestor(of: emojiText, matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(slot).width, DabblerInputRow.emojiSlotWidth);
      expect(DabblerInputRow.emojiSlotWidth, 26);
      expect(DabblerInputRow.emojiSize, 20);
      expect(DabblerInputRow.emojiLeading, 25);
      final emojiStyle = tester.widget<Text>(emojiText).style!;
      expect(emojiStyle.fontSize, 20);
      expect(emojiStyle.fontSize! * emojiStyle.height!, closeTo(25, 0.001));
      final emojiX = tester.getCenter(slot).dx;
      final titleX = tester.getCenter(find.text('Football')).dx;
      if (dir == 'ltr') {
        expect(emojiX, lessThan(titleX));
      } else {
        expect(emojiX, greaterThan(titleX));
      }
    });

    testWidgets('Create Game sport sheet (no emojiFor) has no emoji, keeps '
        'the icon and the baseline row height — $dir', (tester) async {
      await _open(
        tester,
        locale: locale,
        brightness: Brightness.light,
        createPost: false,
      );
      expect(tester.takeException(), isNull);
      final rows = tester.widgetList<DabblerInputRow>(
        find.byType(DabblerInputRow),
      );
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(row.emoji, isNull);
        expect(row.leading, isA<DabblerSportIcon>());
      }
      final h = tester
          .getSize(
            find.ancestor(
              of: find.text('Football'),
              matching: find.byType(DabblerInputRow),
            ),
          )
          .height;
      // ignore: avoid_print
      print('KAN-478 baseline row height $dir: $h');
      expect(h, _baselineRowHeight);
    });

    testWidgets('Create Post rows keep the Create Game row height and select '
        'on tap — $dir', (tester) async {
      await _open(
        tester,
        locale: locale,
        brightness: Brightness.light,
        createPost: true,
      );
      final rowFinder = find.ancestor(
        of: find.text('Football'),
        matching: find.byType(DabblerInputRow),
      );
      expect(tester.getSize(rowFinder).height, _baselineRowHeight);
      await tester.tap(find.text('Padel'));
      await tester.pump(const Duration(milliseconds: 100));
      final padel = _row(tester, 'Padel');
      expect(padel.trailing, isNotNull);
      expect(_row(tester, 'Football').trailing, isNull);
    });
  }

  if (_shotsDir.isNotEmpty) {
    for (final createPost in const [true, false]) {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        for (final b in Brightness.values) {
          final name =
              '${createPost ? 'create-post' : 'create-game'}-sport-sheet-'
              '${locale.languageCode}-${b == Brightness.dark ? 'dark' : 'light'}';
          testWidgets('screenshot $name', (tester) async {
            const key = Key('shot');
            await _open(
              tester,
              locale: locale,
              brightness: b,
              createPost: createPost,
              key: key,
            );
            await tester.runAsync(() async {
              final boundary =
                  tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
              final ui.Image image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory(_shotsDir).createSync(recursive: true);
              File(
                '$_shotsDir/$name.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
            });
          });
        }
      }
    }
  }
}

// Measured on the base (39955afc) without this change: 73 in EN and AR.
const double _baselineRowHeight = 73;

// KAN-972: the vibe chips under a post in dark mode take the vibe's
// dark_bg_hex / dark_border_hex (light unchanged), and they are one row that
// scrolls sideways when wider than the post, from the text's start edge (the
// right in Arabic). EN/AR × light/dark.
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_vibes.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _width = 300;

Vibe _vibe(int i, {bool darkData = true}) => Vibe(
  id: 'v$i',
  key: 'k$i',
  labelEn: 'Vibe$i',
  labelAr: 'شعور$i',
  emoji: '✨',
  colorHex: '#3B82F6',
  darkBgHex: darkData ? '#15233A' : null,
  darkBorderHex: darkData ? '#2E4A78' : null,
);

Future<List<String>> _pump(
  WidgetTester tester, {
  required Locale locale,
  required Brightness brightness,
  required int count,
  bool darkData = true,
}) async {
  final vibes = <Vibe>[
    for (var i = 0; i < count; i++) _vibe(i, darkData: darkData),
  ];
  final toggled = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withTokens(
        ThemeData(brightness: brightness),
      ),
      home: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: _width,
          child: HomeVibeChips(
            counts: <String, int>{for (final v in vibes) v.key: 2},
            mine: const <String>{'k0'},
            vibes: vibes,
            onToggle: (v) => toggled.add(v.key),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return toggled;
}

Finder _chip(int i) => find.byKey(ValueKey<String>('home-vibe-chip-k$i'));

BoxDecoration _deco(WidgetTester tester, int i) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: _chip(i), matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final rtl = locale.languageCode == 'ar';
    final dir = rtl ? 'rtl' : 'ltr';

    for (final b in Brightness.values) {
      final mode = b == Brightness.dark ? 'dark' : 'light';
      testWidgets(
        'chip colours: data in dark, the pastel in light — $mode $dir',
        (tester) async {
          await _pump(tester, locale: locale, brightness: b, count: 2);
          final tone = DabblerHueTone.fromColor(const Color(0xFF3B82F6))!;
          final rest = _deco(tester, 1);
          final mine = _deco(tester, 0);
          final restBorder = (rest.border! as Border).top.color;
          if (b == Brightness.dark) {
            expect(rest.color, const Color(0xFF15233A));
            expect(restBorder, const Color(0xFF2E4A78));
            expect(
              mine.color,
              Color.lerp(
                const Color(0xFF15233A),
                const Color(0xFF2E4A78),
                DabblerFeedPill.darkSelectedShare,
              ),
            );
          } else {
            expect(rest.color, tone.surface);
            expect(restBorder, tone.edge);
            expect(mine.color, tone.edge);
          }
        },
      );

      testWidgets('no dark data: derived from the hue — $mode $dir', (
        tester,
      ) async {
        await _pump(
          tester,
          locale: locale,
          brightness: b,
          count: 1,
          darkData: false,
        );
        final mine = _deco(tester, 0);
        if (b == Brightness.dark) {
          final d = DabblerHueTone.darkFromColor(const Color(0xFF3B82F6))!;
          final border = (mine.border! as Border).top.color;
          expect(border, d.edge);
        } else {
          expect(
            mine.color,
            DabblerHueTone.fromColor(const Color(0xFF3B82F6))!.edge,
          );
        }
      });
    }

    testWidgets('many chips: one row that scrolls from the start — $dir', (
      tester,
    ) async {
      final toggled = await _pump(
        tester,
        locale: locale,
        brightness: Brightness.light,
        count: 8,
      );
      final rail = tester.getRect(
        find.byKey(const ValueKey<String>('home-vibe-rail')),
      );
      final first = tester.getRect(_chip(0));
      // One row: every built chip on the first chip's line.
      for (var i = 1; i < 8; i++) {
        if (_chip(i).evaluate().isEmpty) continue;
        expect(tester.getRect(_chip(i)).top, first.top, reason: 'chip $i');
      }
      expect(rail.height, first.height);
      // Starts at the start edge (the right in Arabic).
      if (rtl) {
        expect(first.right, rail.right);
      } else {
        expect(first.left, rail.left);
      }
      // The last chip is off screen until the row is scrolled.
      final lastBefore = tester.getRect(_chip(7));
      expect(
        rtl ? lastBefore.right < rail.left : lastBefore.left > rail.right,
        isTrue,
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('home-vibe-rail')),
        Offset(rtl ? 2000 : -2000, 0),
      );
      await tester.pumpAndSettle();
      final lastAfter = tester.getRect(_chip(7));
      if (rtl) {
        expect(lastAfter.left, moreOrLessEquals(rail.left, epsilon: 0.5));
      } else {
        expect(lastAfter.right, moreOrLessEquals(rail.right, epsilon: 0.5));
      }
      // Tapping a scrolled-in chip still toggles it.
      await tester.tap(_chip(7));
      expect(toggled, <String>['k7']);
    });

    testWidgets('few chips: unchanged, from the start edge — $dir', (
      tester,
    ) async {
      await _pump(
        tester,
        locale: locale,
        brightness: Brightness.light,
        count: 2,
      );
      final rail = tester.getRect(
        find.byKey(const ValueKey<String>('home-vibe-rail')),
      );
      final a = tester.getRect(_chip(0));
      final b = tester.getRect(_chip(1));
      expect(a.top, b.top);
      if (rtl) {
        expect(a.right, rail.right);
        expect(a.left - b.right, DabblerSpacing.space2);
      } else {
        expect(a.left, rail.left);
        expect(b.left - a.right, DabblerSpacing.space2);
      }
    });
  }
}

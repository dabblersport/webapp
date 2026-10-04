/// Renders Home in the design file's own sample copy, LTR and RTL, inside the
/// shell (the frame draws the bottom bar over the feed), for the side-by-side
/// sheets against `Home Feed.dc.html`.
///
/// Writes files only under `--dart-define=HOME_SHOTS_DIR=<dir>` (as
/// `app-<ltr|rtl>-<state>.png`, 2x); otherwise it still pumps every state and
/// checks each draws cleanly.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'home_city_fakes.dart';
import 'home_measure_data.dart';
import 'home_measure_fixtures.dart';
import 'home_test_harness.dart';

const String _shotsDir = String.fromEnvironment('HOME_SHOTS_DIR');
const Key _key = Key('home-mirror-shot');

Future<void> _shoot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final TargetPlatformVariant desktop = TargetPlatformVariant.only(
    TargetPlatform.macOS,
  );

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final FrameData d = FrameData.of(locale.languageCode == 'ar');

    Future<void> pump(WidgetTester tester) => pumpFrameHome(
      tester,
      locale: locale,
      postCount: 3,
      inShell: true,
      boundaryKey: _key,
      extra: cityOverrides(
        areaRepositoryV2Provider.overrideWithValue(FakeAreaRepo()),
      ),
    );

    testWidgets('renders For you with the upcoming stack - $dir', (
      tester,
    ) async {
      await pump(tester);
      await _shoot(tester, 'app-$dir-foryou');
    }, variant: desktop);

    for (final (String id, String Function(AppLocalizations) label)
        in <(String, String Function(AppLocalizations))>[
          ('following', (AppLocalizations l) => l.tab_following),
          ('nearby', (AppLocalizations l) => l.tab_nearby),
          ('active', (AppLocalizations l) => l.tab_active),
          ('news', (AppLocalizations l) => l.tab_news),
        ]) {
      testWidgets('renders the $id tab - $dir', (tester) async {
        await pump(tester);
        await tester.tap(
          find.text(label(lookupAppLocalizations(locale))).first,
        );
        await settleHome(tester);
        await _shoot(tester, 'app-$dir-$id');
      }, variant: desktop);
    }

    testWidgets('renders the folded and the opened Upcoming - $dir', (
      tester,
    ) async {
      await pump(tester);
      final AppLocalizations l = lookupAppLocalizations(locale);
      await tester.tap(find.text(l.home_upcoming_more(2)).first);
      await settleHome(tester);
      await _shoot(tester, 'app-$dir-upcoming-open');
      await pump(tester);
      await tester.tap(find.bySemanticsLabel(l.home_upcoming_hide).first);
      await settleHome(tester);
      await _shoot(tester, 'app-$dir-upcoming-strip');
    }, variant: desktop);

    testWidgets('renders the city sheet - $dir', (tester) async {
      await pump(tester);
      await tester.tap(find.text(d.location).first);
      await settleHome(tester);
      await _shoot(tester, 'app-$dir-city');
    }, variant: desktop);

    testWidgets('renders the post options sheet - $dir', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('More options').first);
      await settleHome(tester);
      await _shoot(tester, 'app-$dir-post-options');
    }, variant: desktop);
  }
}

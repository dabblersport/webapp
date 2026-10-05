/// Home sheet heights and the shell bar, against `Home Feed.dc.html`.
///
/// The frame draws every Home sheet `height: auto` with a `max-height` cap
/// (`sheetP94` the create drawers, `sheetP82` vibes, `sheetP66` the city
/// sheet): a sheet is as tall as its content and stops at the cap. A sheet
/// that keeps a fixed fraction opens taller than its content and shows an
/// empty band under it. Each case here opens one sheet from Home in LTR and
/// RTL and asserts:
///
///  * no empty band: the sheet's scroll body is never taller than its content;
///  * the cap: the panel is never taller than the frame's `max-height`.
///
/// The shell bar is asserted against the frame's wrapper (`padding: 0 18px
/// 24px`, a 56 row) on the 393x852 frame, and on a wide window it keeps the
/// frame's phone column instead of spanning the window.
///
/// Optional defines: `HOME_SHEET_SHOTS_DIR=<dir>` writes the renders (2x);
/// `HOME_SHEET_TABLE=<file>` writes the measured table.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/home/presentation/widgets/notification_permission_drawer.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'home_city_fakes.dart';
import 'home_measure_data.dart';
import 'home_measure_fixtures.dart';
import 'home_test_harness.dart';

const String _shotsDir = String.fromEnvironment('HOME_SHEET_SHOTS_DIR');
const String _tableOut = String.fromEnvironment('HOME_SHEET_TABLE');
const Key _key = Key('home-sheet-fit');
const Size _frame = Size(393, 852);
const double _tol = 0.5;

/// The full design vibe list, as the vibes table serves it.
final List<Vibe> _vibes = <Vibe>[
  for (final DabblerVibe v in DabblerVibe.values)
    Vibe(
      id: v.key,
      key: v.key,
      labelEn: v.label,
      labelAr: v.label,
      type: v.type.name,
    ),
];

final List<String> _table = <String>[];

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

/// The empty band at the foot of [panel]: how much taller the panel is than
/// the column it holds ([column], the header, body and footer stacked). Zero
/// when the panel is content-sized or its body scrolls.
double _emptyBand(WidgetTester tester, Finder panel, Finder column) {
  final RenderBox box = tester.renderObject<RenderBox>(panel);
  final RenderFlex flex = tester.renderObject<RenderFlex>(column);
  final double used = flex.getChildrenAsList().fold<double>(
    0,
    (double sum, RenderBox c) => sum + c.size.height,
  );
  return math.max(0, box.size.height - used - DabblerSizing.borderDefault);
}

/// One measured sheet: the panel rect, its cap and the empty band.
void _record(
  WidgetTester tester, {
  required String name,
  required String dir,
  required Rect panel,
  required double capFraction,
  required double empty,
}) {
  final double cap = _frame.height * capFraction;
  _table.add(
    '| $name | $dir | ${(capFraction * 100).toStringAsFixed(0)}% = '
    '${cap.toStringAsFixed(2)} | ${panel.height.toStringAsFixed(2)} '
    '(${(panel.height / _frame.height * 100).toStringAsFixed(1)}%) | '
    '${empty.toStringAsFixed(2)} |',
  );
  expect(empty, lessThanOrEqualTo(_tol), reason: '$name $dir: empty band');
  expect(
    panel.height,
    lessThanOrEqualTo(cap + _tol),
    reason: '$name $dir: above the frame cap',
  );
}

/// A DS sheet's panel and empty band.
void _measureDsSheet(
  WidgetTester tester,
  String name,
  String dir,
  double capFraction,
) {
  final Finder sheet = find.byType(DabblerSheet).last;
  final Finder clip = find
      .descendant(of: sheet, matching: find.byType(ClipRRect))
      .first;
  final Rect panel = tester.getRect(clip);
  final double empty = _emptyBand(
    tester,
    clip,
    find.descendant(of: clip, matching: find.byType(Column)).first,
  );
  _record(
    tester,
    name: name,
    dir: dir,
    panel: panel,
    capFraction: capFraction,
    empty: empty,
  );
}

/// A routed create drawer ([AdaptiveModalPage] over a [ComposerDrawerShell]).
void _measureDrawer(WidgetTester tester, String name, String dir) {
  final Finder shell = find.byType(ComposerDrawerShell).first;
  final Finder clip = find
      .ancestor(of: shell, matching: find.byType(ClipRRect))
      .first;
  final Rect panel = tester.getRect(clip);
  final double empty = _emptyBand(
    tester,
    clip,
    find.descendant(of: shell, matching: find.byType(Column)).first,
  );
  _record(
    tester,
    name: name,
    dir: dir,
    panel: panel,
    capFraction: DabblerSheet.contentMaxFractionFull,
    empty: empty,
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

BuildContext _home(WidgetTester tester) =>
    tester.element(find.byType(HomeScreen));

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  tearDownAll(() {
    if (_tableOut.isEmpty || _table.isEmpty) return;
    File(_tableOut).writeAsStringSync(
      '| sheet | dir | design cap | app panel | empty band |\n'
      '|---|---|---|---|---|\n${_table.join('\n')}\n',
    );
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
      extra: <Override>[
        ...cityOverrides(
          areaRepositoryV2Provider.overrideWithValue(FakeAreaRepo()),
        ),
        vibesProvider.overrideWith((ref) async => _vibes),
      ],
    );

    testWidgets('bar: the frame wrapper on the 393 frame - $dir', (
      tester,
    ) async {
      await pump(tester);
      final Rect bar = tester.getRect(find.byType(DabblerNavigationBottomBar));
      // `padding: 0 18px 24px` around a 56 row at the frame's foot.
      final Rect design = Rect.fromLTWH(
        DabblerSpacing.space6,
        _frame.height -
            DabblerFadeTokens.bottomInset -
            DabblerSizing.navBarHeight,
        _frame.width - 2 * DabblerSpacing.space6,
        DabblerSizing.navBarHeight,
      );
      _table.add('| bar row (393 frame) | $dir | $design | $bar | - |');
      expect((bar.left - design.left).abs(), lessThanOrEqualTo(_tol));
      expect((bar.top - design.top).abs(), lessThanOrEqualTo(_tol));
      expect((bar.width - design.width).abs(), lessThanOrEqualTo(_tol));
      expect((bar.height - design.height).abs(), lessThanOrEqualTo(_tol));
      await _shoot(tester, 'app-$dir-home');
    }, variant: desktop);

    testWidgets('bar: a wide window keeps the phone column - $dir', (
      tester,
    ) async {
      await pump(tester);
      tester.view.physicalSize = const Size(1280, 852);
      await _settle(tester);
      final Rect bar = tester.getRect(find.byType(DabblerNavigationBottomBar));
      _table.add('| bar row (1280 window) | $dir | - | $bar | - |');
      expect(
        bar.width,
        lessThanOrEqualTo(
          DabblerPage.readableWidth - 2 * DabblerSpacing.space6 + _tol,
        ),
      );
      expect((bar.center.dx - 640).abs(), lessThanOrEqualTo(_tol));
      await _shoot(tester, 'app-$dir-home-wide');
    }, variant: desktop);

    testWidgets('city sheet - $dir', (tester) async {
      await pump(tester);
      await tester.tap(find.text(d.location).first);
      await _settle(tester);
      _measureDsSheet(
        tester,
        'city (Change location)',
        dir,
        DabblerSheet.contentMaxFractionCompact,
      );
      await _shoot(tester, 'app-$dir-city');
    }, variant: desktop);

    testWidgets('city sheet, a search with one result - $dir', (tester) async {
      await pump(tester);
      await tester.tap(find.text(d.location).first);
      await _settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(DabblerSheet),
          matching: find.byType(EditableText),
        ),
        'Quoz',
      );
      await _settle(tester);
      _measureDsSheet(
        tester,
        'city, searched',
        dir,
        DabblerSheet.contentMaxFractionCompact,
      );
      await _shoot(tester, 'app-$dir-city-search');
    }, variant: desktop);

    testWidgets('post options sheet - $dir', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('More options').first);
      await _settle(tester);
      _measureDsSheet(
        tester,
        'post options',
        dir,
        DabblerSheet.maxHeightFraction,
      );
      await _shoot(tester, 'app-$dir-post-options');
    }, variant: desktop);

    testWidgets('notification permission sheet - $dir', (tester) async {
      await pump(tester);
      showDabblerSheet<bool>(
        context: _home(tester),
        title: 'Stay Updated',
        detent: DabblerSheetDetent.content,
        builder: (BuildContext context) => NotificationPermissionDrawer(
          onEnableNotifications: () {},
          onRemindLater: () {},
          onNoThanks: () {},
        ),
      );
      await _settle(tester);
      _measureDsSheet(
        tester,
        'notification permission',
        dir,
        DabblerSheet.defaultContentMaxFraction,
      );
      await _shoot(tester, 'app-$dir-notification');
    }, variant: desktop);

    testWidgets('create post drawer - $dir', (tester) async {
      await pump(tester);
      final BuildContext ctx = _home(tester);
      Navigator.of(ctx, rootNavigator: true).push(
        AdaptiveModalPage(child: const PostComposerScreen()).createRoute(ctx),
      );
      await _settle(tester);
      _measureDrawer(tester, 'create post', dir);
      await _shoot(tester, 'app-$dir-create-post');
    }, variant: desktop);

    testWidgets('create post: vibes sheet - $dir', (tester) async {
      await pump(tester);
      final BuildContext ctx = _home(tester);
      Navigator.of(ctx, rootNavigator: true).push(
        AdaptiveModalPage(child: const PostComposerScreen()).createRoute(ctx),
      );
      await _settle(tester);
      await tester.tap(
        find.bySemanticsLabel(lookupAppLocalizations(locale).composer_add_vibe),
      );
      await _settle(tester);
      _measureDsSheet(
        tester,
        'vibes',
        dir,
        DabblerSheet.contentMaxFractionTall,
      );
      await _shoot(tester, 'app-$dir-vibes');
    }, variant: desktop);

    testWidgets('create post: place sheet - $dir', (tester) async {
      await pump(tester);
      final BuildContext ctx = _home(tester);
      Navigator.of(ctx, rootNavigator: true).push(
        AdaptiveModalPage(child: const PostComposerScreen()).createRoute(ctx),
      );
      await _settle(tester);
      await tester.tap(
        find.bySemanticsLabel(
          lookupAppLocalizations(locale).composer_add_location,
        ),
      );
      await _settle(tester);
      _measureDsSheet(
        tester,
        'place (Add location)',
        dir,
        DabblerSheet.contentMaxFractionMedium,
      );
      await _shoot(tester, 'app-$dir-place');
    }, variant: desktop);

    testWidgets('create game drawer - $dir', (tester) async {
      await pump(tester);
      final BuildContext ctx = _home(tester);
      Navigator.of(ctx, rootNavigator: true).push(
        AdaptiveModalPage(child: const GameComposerScreen()).createRoute(ctx),
      );
      await _settle(tester);
      _measureDrawer(tester, 'create game', dir);
      await _shoot(tester, 'app-$dir-create-game');
    }, variant: desktop);

    testWidgets('create meet-up drawer - $dir', (tester) async {
      await pump(tester);
      showMeetupComposerSheet(_home(tester));
      await _settle(tester);
      _measureDsSheet(
        tester,
        'create meet-up',
        dir,
        DabblerSheet.contentMaxFractionFull,
      );
      await _shoot(tester, 'app-$dir-create-meetup');
    }, variant: desktop);
  }
}

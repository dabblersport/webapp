import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// Moving from Home to Games, Venues or Meetups re-tints the whole shell —
/// the page's brand and the bottom bar — to the section's theme
/// (`Listings.dc.html` 2026-10-08, `data-theme`). The paper never changes.
const String _dir = String.fromEnvironment(
  'LISTINGS_V2_DIR',
  defaultValue: '$kShotsRoot/listings-v2/app',
);

Future<DabblerColors> _pump(
  WidgetTester tester,
  String active,
  DabblerTheme? section,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late DabblerColors inner;
  const key = Key('shot');
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: RepaintBoundary(
          key: key,
          child: SectionThemed(
            theme: section,
            child: Builder(
              builder: (context) {
                inner = DabblerColors.of(context);
                return DabblerPage(
                  body: const SizedBox.expand(),
                  bottomOverlay: DabblerNavigationBottomBar(
                    items: const <DabblerNavigationItem>[
                      DabblerNavigationItem(
                        id: 'home',
                        icon: 'home-2',
                        label: 'Home',
                      ),
                      DabblerNavigationItem(
                        id: 'venues',
                        icon: 'location',
                        label: 'Venues',
                      ),
                      DabblerNavigationItem(
                        id: 'games',
                        icon: 'game',
                        label: 'Games',
                      ),
                      DabblerNavigationItem(
                        id: 'meetups',
                        icon: 'calendar-1',
                        label: 'Meetups',
                      ),
                    ],
                    active: active,
                    onSelect: (_) {},
                    createItems: const <DabblerNavigationCreateItem>[],
                    onCreate: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  if (const bool.fromEnvironment('SHOOT')) {
    await tester.runAsync(() async {
      final boundary =
          tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(_dir).createSync(recursive: true);
      final mode = const String.fromEnvironment('RENDER_DARK') == '1'
          ? 'dark'
          : 'light';
      File(
        '$_dir/switch-$mode-$active.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
  return inner;
}

void main() {
  testWidgets('Home -> Venues -> Games -> Meetups re-tints the brand only', (
    tester,
  ) async {
    final home = await _pump(tester, 'home', null);
    final venues = await _pump(tester, 'venues', null);
    final games = await _pump(tester, 'games', DabblerTheme.sport);
    final meetups = await _pump(tester, 'meetups', DabblerTheme.active);
    final Brightness b = renderThemeBase().brightness;
    expect(games.brandPrimary, isNot(home.brandPrimary));
    expect(meetups.brandPrimary, isNot(home.brandPrimary));
    expect(meetups.brandPrimary, isNot(games.brandPrimary));
    expect(venues.brandPrimary, home.brandPrimary);
    expect(
      games.brandPrimary,
      DabblerColors.resolve(
        theme: DabblerTheme.sport,
        brightness: b,
      ).brandPrimary,
    );
    // The paper does not move.
    for (final c in <DabblerColors>[venues, games, meetups]) {
      expect(c.bgPrimary, home.bgPrimary);
      expect(c.surfaceCard, home.surfaceCard);
    }
  });
}

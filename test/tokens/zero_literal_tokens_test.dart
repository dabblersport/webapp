// The app takes every size from the design system. This contract test pins
// the part of the token contract the app relies on: the on-grid roles and the
// named off-grid rulings (a design drawing overrides the base-3 grid, D-018).
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every app sizing role sits on the base-3 grid', () {
    for (final MapEntry<String, double> e in sizingAppRoles.entries) {
      expect(e.value % 3, 0, reason: e.key);
    }
  });

  test('every off-grid ruling is pinned and is not a base-3 multiple', () {
    const Map<String, double> pinned = <String, double>{
      'resultTile': 40,
      'articleHeroHeight': 230,
      'mediaRailHeight': 128,
      'mediaRailAddWidth': 64,
      'mediaRailTileWidth': 104,
      // Bottom bar, `NavigationBottomBar.jsx` / `Home Feed.dc.html:466-467`.
      'navItem': 44,
      'navBarHeight': 56,
      'navGlyphLarge': 26,
      'navCreateTile': 62,
      'navFadeHeight': 80,
    };
    expect(sizingOffGridRulings.keys.toSet(), pinned.keys.toSet());
    for (final MapEntry<String, double> e in pinned.entries) {
      expect(sizingOffGridRulings[e.key], e.value, reason: e.key);
      expect(e.value % 3, isNot(0), reason: '${e.key} is a grid step');
    }
  });

  test('the search result tile is the drawn 40', () {
    expect(DabblerSizing.resultTile, 40);
  });
}

// The app takes every size from the design system. This contract test pins
// the part of the token contract the app relies on: the on-grid roles and the
// named off-grid rulings (a design drawing overrides the base-3 grid, D-018).
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/painting.dart';
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

  test('the Home Feed frame tokens are pinned and off the base-3 scale', () {
    // `home-design-measure.md`: measured outer sizes of Home Feed.dc.html.
    const Map<String, double> pinned = <String, double>{
      'logoWidth': 110, // section 3, dabbler_text_logo.svg at width:110
      'logoHeight': 21,
      'logoToLocation': 5,
      'locationGlyph': 13,
      'locationGap': 4,
      'tabPaddingBottom': 10, // section 5
      'reminderHideBox': 34, // section 4
      'reminderHideBleed': 8,
      'reminderStackDepth': 14,
      'reminderSheetHeight': 42,
      'reminderSheetFar': 14,
      'reminderSheetNear': 7,
      'reminderDateGap': 1,
      'reminderTextGap': 2,
      'reminderStripDivider': 14,
      'reminderStripGap': 5,
      'postBadgePaddingBlock': 2, // section 7a
      'postBadgePaddingInline': 8,
      'postMetaGap': 5,
      'postMetaPinInset': 4,
      'sportPillHeight': 32,
      'sportPillPaddingBlock': 5,
      'sportPillPaddingEnd': 11,
      'sportPillGap': 5,
      'newsTextGap': 5, // section 7c
      'activityTile': 42, // section 7b
      'activityMarginBottom': 4,
      'activityGap': 5,
      'activityMetaLift': 2,
      'activityActionHeight': 35,
      'sheetTitleGap': 2, // section 9
      'actionRowPaddingBlock': 14,
      'actionRowTextGap': 1,
      'subChipGlyph': 14, // section 6
      'searchFieldHeight': 42, // section 9b
      'searchFieldGlyph': 16,
      'listRowSubtitleGap': 1,
      'listRowGlyph': 20,
    };
    expect(homeFrameTokens.keys.toSet(), pinned.keys.toSet());
    for (final MapEntry<String, double> e in pinned.entries) {
      expect(homeFrameTokens[e.key], e.value, reason: e.key);
      // The wordmark's 21 is a Size side that happens to equal space7.
      if (e.key == 'logoHeight') continue;
      expect(
        DabblerSpacing.scale.contains(e.value),
        isFalse,
        reason: '${e.key} is a spacing step',
      );
    }
    expect(
      DabblerInsets.feedScreen,
      const EdgeInsets.symmetric(horizontal: 18),
    );
    expect(DabblerInsets.feedBottom, const EdgeInsets.only(bottom: 120));
  });
}

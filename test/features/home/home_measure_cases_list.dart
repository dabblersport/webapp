/// The opened Upcoming list (section 4b, `stack-open.json`): two 61 high rows
/// in a 124 high card, each a 34 x 39 date tile, a title and a venue line and a
/// brand countdown, with `Show less` 6 under the list.
library;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_cases.dart';
import 'home_measure_support.dart';

/// Adds the rows. [title1]/[title2] are the two list games' titles, [short1]
/// and [short2] their countdowns, [less] the `Show less` label.
void addUpcomingListRows(
  MeasureTable t,
  WidgetTester tester, {
  required String title1,
  required String short1,
  required String title2,
  required String short2,
  required String less,
}) {
  const String s = 'Upcoming list (opened)';
  Rect r(Finder f, [int i = 0]) => tester.getRect(f.at(i));
  Finder rowOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DabblerFeedTappable),
  );
  Finder tileOf(String title) => find.descendant(
    of: rowOf(title).first,
    matching: find.byWidgetPredicate(
      (Widget w) =>
          w is SizedBox && w.width == DabblerHomeFrame.upcomingTileWidth,
    ),
  );
  // The row's own box: the tappable minus nothing (it spans the card's inside).
  row(
    t,
    s,
    'list card (2 rows of 61 + hairlines)',
    ltr: rc(18, 235, 357, 124),
    rtl: rc(18, 235, 357, 124),
    app: () => r(
      find.ancestor(
        of: find.text(title1),
        matching: find.byType(DabblerSurface),
      ),
    ),
  );
  row(
    t,
    s,
    'row 1 (61)',
    ltr: rc(19, 236, 355, 61),
    rtl: rc(19, 236, 355, 61),
    app: () => r(rowOf(title1)),
  );
  row(
    t,
    s,
    'row 2 (61, 1px rule above)',
    ltr: rc(19, 297, 355, 61),
    rtl: rc(19, 297, 355, 61),
    app: () => r(rowOf(title2)),
  );
  row(
    t,
    s,
    'date tile 1 (34 x 39; 42 in Arabic)',
    ltr: rc(31, 247.5, 34, 39),
    rtl: rc(328, 246, 34, 42),
    app: () => r(tileOf(title1)),
  );
  row(
    t,
    s,
    'date tile 2',
    ltr: rc(31, 308.5, 34, 39),
    rtl: rc(328, 307, 34, 42),
    app: () => r(tileOf(title2)),
  );
  row(
    t,
    s,
    'title 1 (13/18)',
    ltr: rc(75, 252.5, 56.64, 15),
    rtl: rc(257, 250.5, 61, 20),
    basis: Basis.text,
    app: () => r(find.text(title1)),
  );
  row(
    t,
    s,
    'title 2',
    ltr: rc(75, 313.5, 86.09, 15),
    rtl: rc(241.59, 311.5, 76.41, 20),
    basis: Basis.text,
    app: () => r(find.text(title2)),
  );
  row(
    t,
    s,
    'venue and time line 1 (11/13)',
    ltr: rc(75, 269.5, 226.38, 13),
    rtl: rc(110.28, 269.5, 207.72, 13),
    basis: Basis.line,
    app: () => r(find.textContaining('·', findRichText: true).at(2)),
  );
  row(
    t,
    s,
    'venue and time line 2',
    ltr: rc(75, 330.5, 255.98, 13),
    rtl: rc(74.64, 330.5, 243.36, 13),
    basis: Basis.line,
    app: () => r(find.textContaining('·', findRichText: true).at(3)),
  );
  row(
    t,
    s,
    'countdown 1 (brand, 12/16)',
    ltr: rc(311.38, 260, 50.63, 14),
    rtl: rc(31, 258, 69.28, 18),
    basis: Basis.text,
    app: () => r(find.text(short1)),
  );
  row(
    t,
    s,
    'countdown 2',
    ltr: rc(340.98, 321, 21.02, 14),
    rtl: rc(31, 319, 33.64, 18),
    basis: Basis.text,
    app: () => r(find.text(short2)),
  );
  row(
    t,
    s,
    'Show less label (13/18)',
    ltr: rc(161.22, 372, 48.56, 18),
    rtl: rc(178.94, 372, 57.13, 18),
    basis: Basis.text,
    app: () => r(find.text(less)),
  );
  row(
    t,
    s,
    'Show less glyph (16)',
    ltr: rc(215.78, 373, 16, 16),
    rtl: rc(156.94, 373, 16, 16),
    app: () => tester.getRect(
      find
          .descendant(
            of: find.byType(DabblerUpcomingReminder),
            matching: find.byType(DabblerIcon),
          )
          .last,
    ),
  );
}

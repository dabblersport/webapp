/// The folded Upcoming strip (section 4c) and the opened stack (section 4b).
library;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_cases.dart';
import 'home_measure_support.dart';

Rect _r(WidgetTester tester, Finder f, [int i = 0]) => tester.getRect(f.at(i));

/// The strip: 30 high with a brand dot, the count, a divider, the ticker line
/// and a chevron; the frame's padding is physical.
void addStripRows(
  MeasureTable t,
  WidgetTester tester, {
  required bool rtl,
  required String countLabel,
}) {
  const String s = 'Upcoming strip (folded)';
  final Finder block = find.byType(DabblerUpcomingReminder);
  Finder inBlock(Finder f) => find.descendant(of: block, matching: f);
  row(
    t,
    s,
    'strip pill',
    ltr: rc(18, 113, 357, 30),
    rtl: rc(18, 113, 357, 30),
    app: () => _r(tester, inBlock(find.byType(DabblerSurface))),
  );
  row(
    t,
    s,
    'count label (11/13)',
    ltr: rc(38, 121.5, 49.55, 13),
    rtl: rc(324.22, 121.5, 33.78, 13),
    basis: Basis.text,
    app: () => _r(tester, inBlock(find.text(countLabel))),
  );
  row(
    t,
    s,
    'chevron (16)',
    ltr: rc(353, 120, 16, 16),
    rtl: rc(27, 120, 16, 16),
    app: () => _r(tester, inBlock(find.byType(DabblerIcon))),
  );
  row(
    t,
    s,
    'tabs row starts under the 9 margin',
    ltr: rc(0, 152, 393, 33),
    rtl: rc(0, 152, 393, 36),
    app: () => _r(tester, find.byType(DabblerTabs)),
  );
}

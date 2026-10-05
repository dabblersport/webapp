/// Page-level facts of the Home frame (section 1): the 18 gutter on every row
/// and the 120 the feed scroller keeps clear under its last row.
library;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_cases.dart';
import 'home_measure_support.dart';

/// Scrolls the For you list to its end and measures the last row against the
/// frame's `scroll-end` state, where the last row ends at 732 (852 - 120).
Future<void> addPageRows(
  MeasureTable t,
  WidgetTester tester, {
  required bool rtl,
}) async {
  const String s = 'Page (section 1)';
  final Finder list = find
      .descendant(
        of: find.byType(DabblerRefresh).first,
        matching: find.byType(Scrollable),
      )
      .first;
  final ScrollableState scroll = tester.state<ScrollableState>(list);
  // The list estimates its extent while it builds lazily: jump until it settles.
  for (var i = 0; i < 6; i++) {
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 50));
  }
  final Finder rows = find.descendant(
    of: find.byType(DabblerRefresh).first,
    matching: find.byType(DabblerPostRow),
  );
  final Rect last = tester.getRect(rows.last);
  row(
    t,
    s,
    'feed bottom padding (last row ends 120 above the frame end)',
    ltr: rc(18, 732, 357, 0),
    rtl: rc(18, 732, 357, 0),
    app: () => Rect.fromLTWH(last.left, last.bottom, last.width, 0),
  );
  row(
    t,
    s,
    'row gutter (x and width of a feed row)',
    ltr: rc(18, 0, 357, 0),
    rtl: rc(18, 0, 357, 0),
    app: () => Rect.fromLTWH(last.left, 0, last.width, 0),
  );
}

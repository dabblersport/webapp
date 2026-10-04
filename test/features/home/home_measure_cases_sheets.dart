/// Sheet rows of the Home measurement (see `home_measure_cases.dart`).
library;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_cases.dart';
import 'home_measure_support.dart';

Rect _r(WidgetTester tester, Finder f, [int i = 0]) => tester.getRect(f.at(i));

/// The post-options sheet (section 9a), measured from the panel's top-left.
/// The frame lists Hide post and Report user; the app lists Report post and
/// Block user, so only the first row (with a note) is compared.
void addPostSheetRows(
  MeasureTable t,
  WidgetTester tester, {
  required bool rtl,
  required String title,
  required String subtitle,
  required String rowLabel,
  required String rowNote,
}) {
  const String s = 'Post options sheet';
  final Finder sheet = find.byType(DabblerSheet);
  final Finder panel = find
      .descendant(of: sheet, matching: find.byType(ClipRRect))
      .first;
  final Rect panelApp = tester.getRect(panel);
  Rect rel(Rect r) => r.shift(-panelApp.topLeft);
  Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
  const Offset oL = Offset(0, 536);
  const Offset oR = Offset(0, 530);
  Rect dl(double x, double y, double w, double h) => rc(x, y, w, h).shift(-oL);
  Rect dr(double x, double y, double w, double h) => rc(x, y, w, h).shift(-oR);
  final Finder row0 = inSheet(find.byType(DabblerActionRow)).first;

  row(
    t,
    s,
    'panel (x, width, bottom-anchored)',
    ltr: rc(0, 536, 393, 316),
    rtl: rc(0, 530, 393, 322),
    app: () => panelApp,
  );
  row(
    t,
    s,
    'grabber 40x4',
    ltr: dl(176.5, 557.5, 40, 4),
    rtl: dr(176.5, 551.5, 40, 4),
    app: () => rel(
      tester.getRect(
        inSheet(
          find.byWidgetPredicate(
            (Widget w) =>
                w is Container &&
                w.constraints?.maxWidth == DabblerSheet.handleWidth,
          ),
        ).first,
      ),
    ),
  );
  row(
    t,
    s,
    'title (display 20/25)',
    ltr: dl(19, 591, 355, 25),
    rtl: dr(19, 585, 355, 25),
    basis: Basis.line,
    app: () => rel(_r(tester, inSheet(find.text(title)))),
  );
  row(
    t,
    s,
    'subtitle (12/16, muted)',
    ltr: dl(19, 619, 103.83, 14),
    rtl: dr(256.16, 611, 117.84, 18),
    basis: Basis.line,
    app: () => rel(_r(tester, inSheet(find.text(subtitle)))),
  );
  row(
    t,
    s,
    'header hairline',
    ltr: dl(19, 646, 355, 1),
    rtl: dr(19, 640, 355, 1),
    app: () => rel(_r(tester, inSheet(find.byType(DabblerDivider)))),
  );
  row(
    t,
    s,
    'first action row (padding 14/15, radius 12)',
    ltr: dl(19, 671, 355, 65),
    rtl: dr(19, 665, 355, 68),
    app: () => rel(tester.getRect(row0)),
  );
  row(
    t,
    s,
    'action glyph (20)',
    ltr: dl(34, 693.5, 20, 20),
    rtl: dr(339, 689, 20, 20),
    app: () => rel(
      tester.getRect(
        find.descendant(of: row0, matching: find.byType(DabblerIcon)).first,
      ),
    ),
  );
  row(
    t,
    s,
    'action label (15/20)',
    ltr: dl(66, 687, 55.7, 16),
    rtl: dr(264.75, 679, 62.25, 23),
    basis: Basis.line,
    app: () => rel(_r(tester, inSheet(find.text(rowLabel)))),
  );
  row(
    t,
    s,
    'action note (12/16)',
    ltr: dl(66, 707, 148.22, 14),
    rtl: dr(158.48, 702, 168.52, 18),
    basis: Basis.line,
    app: () => rel(_r(tester, inSheet(find.text(rowNote)))),
  );
}

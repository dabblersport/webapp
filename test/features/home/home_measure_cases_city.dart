/// The "Change location" sheet the Home header opens (section 9b).
///
/// The frame draws saved places as three chips (Home / Work / Custom) under
/// the search field and one "Nearby areas" list; the app lists saved
/// locations as rows under "Recent" and groups areas by district, so rows
/// below the search field are compared on their own height and inset (their
/// y depends on the chips row the app does not draw).
library;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_cases.dart';
import 'home_measure_support.dart';

void addCityRows(
  MeasureTable t,
  WidgetTester tester, {
  required bool rtl,
  required String title,
  required String done,
  required String useCurrent,
  required String areaName,
}) {
  const String s = 'City sheet (Change location)';
  final Finder sheet = find.byType(DabblerSheet);
  final Finder panel = find
      .descendant(of: sheet, matching: find.byType(ClipRRect))
      .first;
  Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
  final Rect p = tester.getRect(panel);

  row(
    t,
    s,
    'panel (0.66 of the viewport)',
    ltr: rc(0, 289.69, 393, 562.31),
    rtl: rc(0, 289.69, 393, 562.31),
    app: () => p,
  );
  row(
    t,
    s,
    'title (17/22, semibold)',
    ltr: rc(19, 347.19, 286.7, 22),
    rtl: rc(91.95, 345.69, 282.05, 25),
    basis: Basis.line,
    app: () => tester.getRect(inSheet(find.text(title)).first),
  );
  row(
    t,
    s,
    'Done button (45 box)',
    ltr: rc(317.7, 335.69, 56.3, 45),
    rtl: rc(19, 335.69, 60.95, 45),
    basis: Basis.box,
    app: () {
      final Finder f = inSheet(find.text(done));
      return tester.getRect(
        find.ancestor(of: f.first, matching: find.byType(DabblerButton)).first,
      );
    },
  );
  row(
    t,
    s,
    'search field (42, radius 24)',
    ltr: rc(19, 404.69, 355, 42),
    rtl: rc(19, 404.69, 355, 42),
    app: () => tester.getRect(inSheet(find.byType(DabblerSearchField)).first),
  );
  row(
    t,
    s,
    'use current location row',
    ltr: rc(19, 0, 355, 45),
    rtl: rc(19, 0, 355, 48),
    basis: Basis.inset,
    app: () => tester.getRect(
      find
          .ancestor(
            of: inSheet(find.text(useCurrent)).first,
            matching: find.byType(DabblerListRow),
          )
          .first,
    ),
  );
  row(
    t,
    s,
    'area row',
    ltr: rc(19, 0, 355, 62),
    rtl: rc(19, 0, 355, 65),
    basis: Basis.inset,
    app: () => tester.getRect(
      find
          .ancestor(
            of: inSheet(find.text(areaName)).first,
            matching: find.byType(DabblerListRow),
          )
          .first,
    ),
  );
}

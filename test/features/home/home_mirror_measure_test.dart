/// Home against its frame, in pixels.
///
/// Every row pairs a rect the measuring seat read off `Home Feed.dc.html`
/// (`home-design-measure.md`, 393x852, status bar 50 high) with the rect this
/// app lays out for the same element, in LTR and RTL. A delta is zero or it
/// carries a named exception whose value is pinned (a drifting exception
/// fails). Run with `--dart-define=HOME_MEASURE_OUT=<file>` to write the table.
library;

import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_cases.dart';
import 'home_measure_data.dart';
import 'home_measure_cases_city.dart';
import 'home_measure_cases_page.dart';
import 'home_measure_cases_sheets.dart';
import 'home_measure_cases_strip.dart';
import 'home_measure_cases_tabs.dart';
import 'home_measure_support.dart';
import '../../support/render_mode.dart';
import 'home_city_fakes.dart';
import 'home_measure_fixtures.dart';
import 'home_test_harness.dart';

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final TargetPlatformVariant desktop = TargetPlatformVariant.only(
    TargetPlatform.macOS,
  );

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final bool rtl = locale.languageCode == 'ar';
    final String dir = rtl ? 'RTL' : 'LTR';

    final FrameData d = FrameData.of(rtl);

    Future<void> pump(
      WidgetTester tester, {
      List<Override> extra = const <Override>[],
      int postCount = 1,
    }) => pumpFrameHome(
      tester,
      locale: locale,
      extra: extra,
      postCount: postCount,
    );

    testWidgets('Home mirrors the frame: page gutter and bottom - $dir', (
      tester,
    ) async {
      await pump(tester, postCount: 6);
      final MeasureTable table = MeasureTable(rtl: rtl);
      await addPageRows(table, tester, rtl: rtl);
      table.write('Home, page gutter and bottom padding, $dir');
      final List<String> failures = table.failures();
      // ignore: avoid_print
      failures.forEach(print);
      expect(failures, isEmpty);
    }, variant: desktop);

    testWidgets('Home mirrors the frame: city sheet - $dir', (tester) async {
      await pump(
        tester,
        extra: cityOverrides(
          areaRepositoryV2Provider.overrideWithValue(FakeAreaRepo()),
        ),
      );
      await tester.tap(find.text(d.location).first);
      await settleHome(tester);
      final AppLocalizations l = lookupAppLocalizations(locale);
      final MeasureTable table = MeasureTable(rtl: rtl);
      addCityRows(
        table,
        tester,
        rtl: rtl,
        title: l.home_location_title,
        done: l.home_location_done,
        useCurrent: l.home_location_use_current,
        areaName: 'Nad Al Sheba',
      );
      table.write('Home, city sheet, $dir');
      final List<String> failures = table.failures();
      // ignore: avoid_print
      failures.forEach(print);
      expect(failures, isEmpty);
    }, variant: desktop);

    testWidgets('Home mirrors the frame: folded upcoming strip - $dir', (
      tester,
    ) async {
      await pump(tester);
      final AppLocalizations l = lookupAppLocalizations(locale);
      await tester.tap(find.bySemanticsLabel(l.home_upcoming_hide).first);
      await settleHome(tester);
      final MeasureTable table = MeasureTable(rtl: rtl);
      addStripRows(
        table,
        tester,
        rtl: rtl,
        countLabel: l.home_upcoming_strip_count(3),
      );
      table.write('Home, folded Upcoming strip, $dir');
      final List<String> failures = table.failures();
      // ignore: avoid_print
      failures.forEach(print);
      expect(failures, isEmpty);
    }, variant: desktop);

    testWidgets('Home mirrors the frame: post options sheet - $dir', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('More options').first);
      await settleHome(tester);
      final AppLocalizations l = lookupAppLocalizations(locale);
      final MeasureTable table = MeasureTable(rtl: rtl);
      addPostSheetRows(
        table,
        tester,
        rtl: rtl,
        title: l.home_post_options_title,
        subtitle: l.home_post_options_by(FrameData.of(rtl).name),
        rowLabel: l.home_post_report,
        rowNote: l.home_post_report_note,
      );
      table.write('Home, post options sheet, $dir');
      final List<String> failures = table.failures();
      // ignore: avoid_print
      failures.forEach(print);
      expect(failures, isEmpty);
    }, variant: desktop);

    testWidgets('Home mirrors the frame: News tab - $dir', (tester) async {
      await pump(tester);
      final AppLocalizations l = lookupAppLocalizations(locale);
      await tester.tap(find.text(l.tab_news).first);
      await settleHome(tester);
      final MeasureTable table = MeasureTable(rtl: rtl);
      addNewsRows(table, tester, rtl: rtl);
      table.write('Home, News tab (first card), $dir');
      final List<String> failures = table.failures();
      // ignore: avoid_print
      failures.forEach(print);
      expect(failures, isEmpty);
    }, variant: desktop);

    testWidgets('Home mirrors the frame: Active tab - $dir', (tester) async {
      await pump(tester);
      final AppLocalizations l = lookupAppLocalizations(locale);
      await tester.tap(find.text(l.tab_active).first);
      await settleHome(tester);
      final MeasureTable table = MeasureTable(rtl: rtl);
      addActiveRows(table, tester, rtl: rtl);
      table.write('Home, Active tab (system-kind card), $dir');
      final List<String> failures = table.failures();
      // ignore: avoid_print
      failures.forEach(print);
      expect(failures, isEmpty);
    }, variant: desktop);

    testWidgets('Home mirrors the frame: header, upcoming, tabs, post - $dir', (
      tester,
    ) async {
      await pump(tester);
      final MeasureTable table = MeasureTable(rtl: rtl);
      addHeaderRows(table, tester, rtl: rtl);
      addUpcomingRows(table, tester, rtl: rtl);
      addTabRows(table, tester, rtl: rtl);
      addTabItemRows(table, tester, rtl: rtl);
      addPostRows(table, tester, rtl: rtl, l: lookupAppLocalizations(locale));
      table.write('Home, For you tab, 3 upcoming (stack), $dir');
      final List<String> failures = table.failures();
      // ignore: avoid_print
      failures.forEach(print);
      expect(failures, isEmpty);
    }, variant: desktop);
  }
}

/// Home against its frame, in pixels.
///
/// Every row pairs a rect the measuring seat read off `Home Feed.dc.html`
/// (`home-design-measure.md`, 393x852, status bar 50 high) with the rect this
/// app lays out for the same element, in LTR and RTL. A delta is zero or it
/// carries a named exception whose value is pinned (a drifting exception
/// fails). Run with `--dart-define=HOME_MEASURE_OUT=<file>` to write the table.
library;

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:dabbler/features/home/presentation/widgets/home_news_rows.dart';
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
import 'home_test_harness.dart';

Post _post(
  String id,
  String name,
  String body,
  String sport,
  int likes, {
  int comments = 0,
  String? place,
  int hours = 2,
}) => Post(
  id: id,
  authorProfileId: 'prof-$id',
  authorUserId: 'user-$id',
  authorDisplayName: name,
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  personaTypeSnapshot: 'player',
  body: body,
  sport: sport,
  locationName: place,
  tags: const <String>[],
  likeCount: likes,
  commentCount: comments,
  createdAt: DateTime.now().subtract(Duration(hours: hours, minutes: 5)),
  updatedAt: DateTime.now(),
);

List<Game> _games(FrameData d) => <Game>[
  for (final int h in <int>[19, 50, 100])
    Game(
      id: 'u$h',
      title: d.gameTitle,
      description: '',
      sport: 'Football',
      venueName: d.venue,
      scheduledDate: DateTime.now().add(Duration(hours: h)),
      startTime: '19:30',
      endTime: '23:59',
      minPlayers: 2,
      maxPlayers: 10,
      currentPlayers: 4,
      organizerId: 'o',
      skillLevel: 'mixed',
      pricePerPlayer: 0,
      status: GameStatus.upcoming,
      isPublic: true,
      allowsWaitlist: false,
      checkInEnabled: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

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
    }) async {
      final List<Post> posts = <Post>[
        for (var i = 0; i < postCount; i++)
          _post(
            'a$i',
            d.name,
            d.body,
            d.cricket,
            12,
            comments: 4,
            place: d.place,
          ),
      ];
      await pumpHome(
        tester,
        locale: locale,
        topInset: 50,
        locationName: d.location,
        overrides: <Override>[
          homeNewsReactionCountsProvider.overrideWith(
            (ref, id) async => <String, int>{'loving': 128},
          ),
          ...extra,
        ],
        upcoming: _games(d),
        feedState: FeedData(
          items: <FeedItem>[for (final Post p in posts) FeedPostItem(p)],
          hasMore: false,
        ),
        nearbyState: TabFeedData(posts: posts, hasMore: false),
        activeState: ActiveFeedData(
          events: <ActiveEvent>[
            GameCreatedEvent(
              id: 'g1',
              createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
              gameId: 'g1',
              gameTitle: d.gameTitle,
              sport: 'Padel',
              venueName: d.venue,
            ),
          ],
          hasMore: false,
        ),
        newsState: NewsTabState(
          items: <FeedNewsItem>[
            FeedNewsItem(
              newsId: 'n1',
              id: 'n1',
              title: <String, String>{
                'en': FrameData.en.newsTitle,
                'ar': FrameData.ar.newsTitle,
              },
              body: <String, String>{
                'en': FrameData.en.newsExcerpt,
                'ar': FrameData.ar.newsExcerpt,
              },
              likeCount: 0,
              commentCount: 24,
              viewCount: 1902,
              tags: const [],
              isPinned: false,
              priorityScore: 0,
              createdAt: DateTime.now().subtract(const Duration(hours: 3)),
              feedLabel: d.football,
              regions: const <String>['Dubai'],
            ),
          ],
          loaded: true,
          hasMore: false,
        ),
      );
      await _settle(tester);
    }

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
      await _settle(tester);
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
      await _settle(tester);
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
      await _settle(tester);
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
      await _settle(tester);
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
      await _settle(tester);
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

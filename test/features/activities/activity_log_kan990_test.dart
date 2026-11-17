// KAN-990: the Activity log tab — category chips (no Bookings, F-12), the
// Last 7 days tiles (localized, no unsourced day streak), search, times in the
// device's 12/24-hour setting (I-7), and no security card without sign-in data
// (F-16, G.9). Every widget case runs in EN and AR.

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/domain/activity_last_sign_in.dart';
import 'package:dabbler/features/activities/domain/activity_log_time.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_category_chips.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_log_slivers.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_no_match_state.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_row.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_search_row.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_security_footer.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_summary_card.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_chips.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The pinned clock: 17 Nov 2026, 00:30 local — just after midnight, so
/// "an hour ago" is yesterday.
final DateTime _now = DateTime(2026, 11, 17, 0, 30);

ActivityFeedEvent _event(
  String id, {
  String subject = 'game',
  required DateTime at,
  String title = 'Padel at Zamalek',
}) => ActivityFeedEvent(
  id: id,
  subjectType: subject,
  subjectId: 's-$id',
  verb: 'joined',
  timeBucket: 'past',
  happenedAt: at,
  priority: 0,
  payload: <String, dynamic>{'title': title},
);

const List<Locale> _locales = <Locale>[Locale('en'), Locale('ar')];

Widget _host(
  Widget child, {
  required Locale locale,
  bool use24h = false,
  List<Override> overrides = const <Override>[],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
    builder: (BuildContext context, Widget? c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
      child: c!,
    ),
    home: Scaffold(body: child),
  ),
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(w);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('calendar (fixed dates)', () {
    test('days ago crosses midnight by calendar day, not 24 hours', () {
      final DateTime lateLastNight = DateTime(2026, 11, 16, 23, 59);
      final DateTime earlyToday = DateTime(2026, 11, 17, 0, 1);
      expect(activityDaysAgo(lateLastNight, _now), 1);
      expect(activityDaysAgo(earlyToday, _now), 0);
      expect(activityDaysAgo(DateTime(2026, 11, 18, 9), _now), -1);
    });

    test('Last 7 days is today and the six days before it', () {
      final List<ActivityFeedEvent> all = <ActivityFeedEvent>[
        _event('today', at: DateTime(2026, 11, 17, 0, 10)),
        _event('day6', at: DateTime(2026, 11, 11, 0, 1), subject: 'reward'),
        // 7 local days ago: outside, though under 7 x 24h from _now.
        _event('day7', at: DateTime(2026, 11, 10, 23, 59)),
        _event('later', at: DateTime(2026, 11, 18, 10)),
        _event('reward', at: DateTime(2026, 11, 16, 12), subject: 'reward'),
      ];
      final ActivityLastSevenDays week = activityLastSevenDays(all, _now);
      expect(week.events, 3);
      expect(week.rewards, 2);
    });

    test('the clock follows the 12/24-hour setting', () async {
      await initializeDateFormatting('en');
      final DateTime t = DateTime(2026, 11, 17, 17, 5);
      expect(formatActivityClock(t, use24h: true, locale: 'en'), '17:05');
      expect(
        formatActivityClock(t, use24h: false, locale: 'en'),
        matches(RegExp(r'^5:05\sPM$')),
      );
    });
  });

  for (final Locale locale in _locales) {
    final AppLocalizations l10n = lookupAppLocalizations(locale);
    final String lang = locale.languageCode;

    testWidgets('[$lang] chips: All, You, Games, Social, Rewards only', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _host(
          Builder(
            builder: (BuildContext context) => ChipsRow(
              chips: activityCategoryChips(AppLocalizations.of(context)),
              activeKey: 'all',
              onChanged: (_) {},
            ),
          ),
          locale: locale,
        ),
      );
      final List<ChipData> chips = activityCategoryChips(l10n);
      expect(chips.map((ChipData c) => c.key), kActivityCategoryKeys);
      expect(chips.map((ChipData c) => c.label), <String>[
        l10n.notif_chip_all,
        l10n.notif_chip_you,
        l10n.notif_chip_games,
        l10n.notif_chip_social,
        l10n.notif_chip_rewards,
      ]);
      expect(find.text(l10n.notif_chip_bookings), findsNothing);
      expect(find.text(l10n.notif_chip_security), findsNothing);
      expect(find.text(l10n.notif_chip_all), findsOneWidget);
    });

    testWidgets('[$lang] Last 7 days tiles: localized, no day streak', (
      WidgetTester tester,
    ) async {
      final ActivityLogState state = ActivityLogState(
        loaded: true,
        activities: <ActivityFeedEvent>[
          _event('1', at: DateTime(2026, 11, 17, 0, 5)),
          _event('2', at: DateTime(2026, 11, 16, 20), subject: 'reward'),
          _event('3', at: DateTime(2026, 11, 1)),
        ],
      );
      await _pump(
        tester,
        _host(
          ActivitySummaryCard(state: state, now: _now),
          locale: locale,
        ),
      );
      expect(find.text(l10n.activity_last_7_days), findsOneWidget);
      expect(find.byType(DabblerStatTile), findsNWidgets(2));
      expect(find.text(l10n.activity_stat_events), findsOneWidget);
      expect(find.text(l10n.activity_stat_rewards), findsOneWidget);
      expect(find.text(l10n.activity_day_streak), findsNothing);
      expect(find.text('events'), findsNothing);
      expect(find.text('rewards'), findsNothing);
      final List<String> values = tester
          .widgetList<DabblerStatTile>(find.byType(DabblerStatTile))
          .map((DabblerStatTile t) => t.value)
          .toList();
      expect(values, <String>['2', '1']);
    });

    for (final bool use24h in <bool>[true, false]) {
      testWidgets('[$lang] row time in ${use24h ? '24h' : '12h'} format', (
        WidgetTester tester,
      ) async {
        final ActivityFeedEvent e = _event(
          'clock',
          at: DateTime(2026, 11, 17, 17, 5),
        );
        await _pump(
          tester,
          _host(
            ActivityRow(event: e, isLast: true, onTap: () {}),
            locale: locale,
            use24h: use24h,
          ),
        );
        final BuildContext ctx = tester.element(find.byType(ActivityRow));
        final String shown = activityClockOf(ctx, e.happenedAt);
        expect(find.text(shown), findsOneWidget);
        if (use24h) {
          expect(shown, '17:05');
        } else {
          expect(shown, contains('5:05'));
          expect(shown, isNot(contains('17')));
        }
      });
    }

    testWidgets('[$lang] day groups and rows across midnight', (
      WidgetTester tester,
    ) async {
      final ActivityLogState state = ActivityLogState(
        loaded: true,
        feedHasMore: false,
        socialHasMore: false,
        activities: <ActivityFeedEvent>[
          _event('a', at: DateTime(2026, 11, 17, 0, 10)),
          _event('b', at: DateTime(2026, 11, 16, 23, 50)),
        ],
      );
      await _pump(
        tester,
        _host(
          Builder(
            builder: (BuildContext context) => CustomScrollView(
              slivers: buildActivityLogSlivers(
                context,
                state,
                onTap: (_) {},
                onRetry: () {},
                onLoadMore: () {},
                now: _now,
              ),
            ),
          ),
          locale: locale,
          use24h: true,
        ),
      );
      expect(
        find.textContaining('${l10n.notif_section_today} · '),
        findsOneWidget,
      );
      expect(
        find.textContaining('${l10n.notif_section_yesterday} · '),
        findsOneWidget,
      );
      expect(find.text(l10n.activity_group_count(1)), findsNWidgets(2));
      expect(find.text('00:10'), findsOneWidget);
      expect(find.text('23:50'), findsOneWidget);
    });

    testWidgets('[$lang] search: a match shows rows, a miss the no-match', (
      WidgetTester tester,
    ) async {
      ActivityLogState state(String q) => ActivityLogState(
        loaded: true,
        feedHasMore: false,
        socialHasMore: false,
        query: q,
        activities: <ActivityFeedEvent>[
          _event('a', at: DateTime(2026, 11, 17, 0, 10)),
          _event('b', at: DateTime(2026, 11, 16, 9), title: 'Football night'),
        ],
      );
      Widget list(String q) => Builder(
        builder: (BuildContext context) => CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: ActivitySearchRow(query: q)),
            ...buildActivityLogSlivers(
              context,
              state(q),
              onTap: (_) {},
              onRetry: () {},
              onLoadMore: () {},
              now: _now,
            ),
          ],
        ),
      );

      await _pump(tester, _host(list('football'), locale: locale));
      expect(find.byType(ActivityRow), findsOneWidget);
      expect(find.text('Football night'), findsOneWidget);
      expect(find.byType(ActivityNoMatchState), findsNothing);

      await _pump(tester, _host(list('zzzz'), locale: locale));
      expect(find.byType(ActivityRow), findsNothing);
      expect(find.byType(ActivityNoMatchState), findsOneWidget);
      expect(find.text(l10n.activity_search_no_match_title), findsOneWidget);

      await _pump(tester, _host(list(''), locale: locale));
      expect(find.byType(ActivityRow), findsNWidgets(2));
    });

    testWidgets('[$lang] no security card without sign-in data', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _host(const ActivitySecurityFooter(), locale: locale),
      );
      expect(find.byType(DabblerBanner), findsNothing);
      expect(find.text(l10n.activity_all_normal_title), findsNothing);
      expect(find.textContaining(l10n.activity_all_normal_body), findsNothing);
      expect(find.byType(DabblerText), findsNothing);
    });

    testWidgets('[$lang] a ledger load error shows nothing either', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _host(
          const ActivitySecurityFooter(),
          locale: locale,
          overrides: <Override>[
            activityLastSignInProvider.overrideWith(
              (Ref ref) async => throw Exception('ledger down'),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerBanner), findsNothing);
      expect(find.byType(DabblerText), findsNothing);
    });
  }
}

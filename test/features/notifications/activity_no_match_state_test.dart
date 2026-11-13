// KAN-878: the Activity log answers a search with no match. While older pages
// may still hold one (isSearchingOlder || hasMore) it shows one searching
// indicator and no Load more; only when nothing is left does it say "no
// matches". A blank query keeps the genuine-empty ActivityEmptyState.

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_empty_state.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_log_slivers.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_no_match_state.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_row.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_list_states.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityFeedEvent _event(String id) => ActivityFeedEvent(
  id: id,
  subjectType: 'game',
  subjectId: 'g-$id',
  verb: 'joined',
  timeBucket: 'past',
  happenedAt: DateTime.now().subtract(const Duration(hours: 1)),
  priority: 0,
  payload: const <String, dynamic>{'title': 'Padel at Zamalek'},
);

ActivityLogState _state({
  String query = '',
  List<ActivityFeedEvent>? activities,
  bool isSearchingOlder = false,
  bool hasMore = false,
  bool isLoadingMore = false,
  String category = 'all',
}) => ActivityLogState(
  loaded: true,
  activities: activities ?? <ActivityFeedEvent>[_event('1'), _event('2')],
  query: query,
  category: category,
  isSearchingOlder: isSearchingOlder,
  isLoadingMore: isLoadingMore,
  feedHasMore: hasMore,
  socialHasMore: false,
);

Widget _host(ActivityLogState state, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => CustomScrollView(
          slivers: buildActivityLogSlivers(
            context,
            state,
            onTap: (_) {},
            onRetry: () {},
            onLoadMore: () {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(w);
  // A spinner animates forever, so never pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 100));
}

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('TC1 no match, nothing older: no-match state, not empty state', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _host(_state(query: 'zzzz')));

    expect(find.byType(ActivityNoMatchState), findsOneWidget);
    expect(find.text('No matches'), findsOneWidget);
    expect(
      find.text(_en.activity_search_no_match_body('zzzz', 'All')),
      findsOneWidget,
    );
    expect(find.byType(ActivityEmptyState), findsNothing);
    expect(find.byType(ActivityRow), findsNothing);
    expect(find.text('Searching older activity…'), findsNothing);
    expect(find.byType(LoadMoreButton), findsNothing);
  });

  testWidgets('TC1b the body names the selected category chip label', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _host(_state(query: 'zzzz', category: 'game')));

    expect(
      find.text(_en.activity_search_no_match_body('zzzz', 'Games')),
      findsOneWidget,
    );
  });

  for (final ({String name, bool searching, bool hasMore}) c in [
    (name: 'isSearchingOlder', searching: true, hasMore: false),
    (name: 'hasMore', searching: false, hasMore: true),
    (name: 'both', searching: true, hasMore: true),
  ]) {
    testWidgets('TC2 no match while older may match (${c.name}): one '
        'searching indicator, no no-match, no Load more', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _host(
          _state(
            query: 'zzzz',
            isSearchingOlder: c.searching,
            hasMore: c.hasMore,
            // The search loop pages through loadMore(), so isLoadingMore is
            // usually true too; the tail must not add a second spinner.
            isLoadingMore: c.searching,
          ),
        ),
      );

      expect(find.text('Searching older activity…'), findsOneWidget);
      expect(find.byType(DabblerSpinner), findsOneWidget);
      expect(find.byType(ActivityNoMatchState), findsNothing);
      expect(find.byType(ActivityEmptyState), findsNothing);
      expect(find.byType(LoadMoreButton), findsNothing);
    });
  }

  testWidgets('TC3 blank query with activities: rows are shown', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _host(_state(hasMore: true)));

    expect(find.byType(ActivityRow), findsNWidgets(2));
    expect(find.byType(ActivityNoMatchState), findsNothing);
    expect(find.byType(ActivityEmptyState), findsNothing);
    expect(find.text('Searching older activity…'), findsNothing);
    expect(find.byType(LoadMoreButton), findsOneWidget);
  });

  testWidgets('TC4 blank query, no activities: ActivityEmptyState only', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _host(_state(activities: const <ActivityFeedEvent>[], hasMore: false)),
    );

    expect(find.byType(ActivityEmptyState), findsOneWidget);
    expect(find.byType(ActivityNoMatchState), findsNothing);
  });

  testWidgets('TC5 Arabic: Arabic no-match text, rtl Directionality', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _host(_state(query: 'zzzz'), locale: const Locale('ar')),
    );

    expect(find.byType(ActivityNoMatchState), findsOneWidget);
    expect(find.text('لا توجد نتائج'), findsOneWidget);
    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      find.text(ar.activity_search_no_match_body('zzzz', ar.notif_chip_all)),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.byType(ActivityNoMatchState))),
      TextDirection.rtl,
    );
  });
}

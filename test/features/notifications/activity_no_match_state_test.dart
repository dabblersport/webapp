// KAN-878: the Activity log's no-match state and searching-older indicator,
// driven through buildActivityLogSlivers with hand-built states.

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_empty_state.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_log_slivers.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_no_match_state.dart';
import 'package:dabbler/features/notifications/presentation/widgets/activity_row.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_list_states.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final List<ActivityFeedEvent> _events = <ActivityFeedEvent>[
  ActivityFeedEvent(
    id: 'a1',
    subjectType: 'game',
    subjectId: 'g1',
    verb: 'joined',
    timeBucket: 'present',
    happenedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    priority: 1,
    payload: const <String, dynamic>{'title': 'You joined Friday Football'},
  ),
];

Future<void> _pump(
  WidgetTester tester,
  ActivityLogState state, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
      home: Scaffold(
        body: Builder(
          builder: (context) => CustomScrollView(
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
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

  ActivityLogState s({
    String query = '',
    List<ActivityFeedEvent>? activities,
    bool hasMore = false,
    bool isSearchingOlder = false,
  }) => ActivityLogState(
    loaded: true,
    query: query,
    activities: activities ?? _events,
    feedHasMore: hasMore,
    socialHasMore: false,
    isSearchingOlder: isSearchingOlder,
  );

  testWidgets('TC1: no match over the full history shows the no-match state', (
    tester,
  ) async {
    await _pump(tester, s(query: 'zzzz'));
    expect(find.byType(ActivityNoMatchState), findsOneWidget);
    expect(find.byType(ActivityEmptyState), findsNothing);
    expect(find.byType(ActivitySearchingOlderIndicator), findsNothing);
    expect(find.text(en.activity_search_no_match_title), findsOneWidget);
    expect(
      find.text(en.activity_search_no_match_body('zzzz', en.notif_chip_all)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC2a: no match yet with hasMore shows the searching indicator', (
    tester,
  ) async {
    await _pump(tester, s(query: 'zzzz', hasMore: true));
    expect(find.byType(ActivitySearchingOlderIndicator), findsOneWidget);
    expect(find.text(en.activity_search_loading_older), findsOneWidget);
    expect(find.byType(ActivityNoMatchState), findsNothing);
    expect(find.byType(ActivityEmptyState), findsNothing);
  });

  testWidgets('TC2b: isSearchingOlder shows the searching indicator', (
    tester,
  ) async {
    await _pump(tester, s(query: 'zzzz', isSearchingOlder: true));
    expect(find.byType(ActivitySearchingOlderIndicator), findsOneWidget);
    expect(find.text(en.activity_search_loading_older), findsOneWidget);
    expect(find.byType(ActivityNoMatchState), findsNothing);
  });

  testWidgets('TC3: cleared query renders the list and neither state', (
    tester,
  ) async {
    await _pump(tester, s());
    expect(find.byType(ActivityRow), findsOneWidget);
    expect(find.byType(ActivityNoMatchState), findsNothing);
    expect(find.byType(ActivityEmptyState), findsNothing);
    expect(find.byType(ActivitySearchingOlderIndicator), findsNothing);
  });

  testWidgets('TC4: no query and no activities keeps ActivityEmptyState', (
    tester,
  ) async {
    await _pump(tester, s(activities: const <ActivityFeedEvent>[]));
    expect(find.byType(ActivityEmptyState), findsOneWidget);
    expect(find.byType(ActivityNoMatchState), findsNothing);
  });

  testWidgets('TC5: Arabic no-match text and RTL direction', (tester) async {
    await _pump(tester, s(query: 'zzzz'), locale: const Locale('ar'));
    final Finder state = find.byType(ActivityNoMatchState);
    expect(state, findsOneWidget);
    expect(find.text(ar.activity_search_no_match_title), findsOneWidget);
    expect(
      find.text(ar.activity_search_no_match_body('zzzz', ar.notif_chip_all)),
      findsOneWidget,
    );
    expect(Directionality.of(tester.element(state)), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading branch unchanged', (tester) async {
    await _pump(tester, const ActivityLogState(query: 'zzzz'));
    expect(find.byType(ActivityNoMatchState), findsNothing);
    expect(find.byType(ActivitySearchingOlderIndicator), findsNothing);
    expect(find.byType(NotifLoadingView), findsOneWidget);
  });

  testWidgets('error branch unchanged', (tester) async {
    await _pump(
      tester,
      const ActivityLogState(
        loaded: true,
        query: 'zzzz',
        feedError: 'offline',
        socialError: 'offline',
      ),
    );
    expect(find.text(en.notif_btn_retry), findsOneWidget);
    expect(find.byType(ActivityNoMatchState), findsNothing);
    expect(find.byType(ActivitySearchingOlderIndicator), findsNothing);
  });

  test('category label follows the selected chip', () {
    expect(activityLogCategoryLabel(en, 'game'), en.notif_chip_games);
    expect(activityLogCategoryLabel(en, 'all'), en.notif_chip_all);
  });
}

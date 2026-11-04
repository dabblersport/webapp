// KAN-874: Activity log search — pure searchActivityLog over the loaded list,
// plus ActivityLogState.query / ActivityLogController.changeQuery.

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/domain/activity_log_merge.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'activity_log_controller_test.mocks.dart';

void main() {
  final DateTime t0 = DateTime(2026, 11, 4, 12);

  ActivityFeedEvent ev(
    String id, {
    String subject = 'game',
    String verb = 'created',
    Map<String, dynamic>? payload,
    int minutesAgo = 0,
  }) => ActivityFeedEvent(
    id: id,
    subjectType: subject,
    subjectId: id,
    verb: verb,
    timeBucket: 'past',
    happenedAt: t0.subtract(Duration(minutes: minutesAgo)),
    priority: 90,
    payload: payload,
  );

  final List<ActivityFeedEvent> events = <ActivityFeedEvent>[
    ev('a', payload: {'title': 'Sunday Padel Match'}, minutesAgo: 1),
    ev(
      'b',
      subject: 'post',
      verb: 'posted',
      payload: {'description': 'Great game at the club'},
      minutesAgo: 2,
    ),
    ev('c', subject: 'reward', verb: 'earned', minutesAgo: 3),
    ev('d', payload: {'game_name': 'Evening padel'}, minutesAgo: 4),
    ev('e', payload: {'location': 'Zamalek Courts'}, minutesAgo: 5),
  ];

  group('searchActivityLog', () {
    test('matches the title case-insensitively', () {
      final r = searchActivityLog(events, 'sUNDAY pAdEl');
      expect(r.map((e) => e.id), ['a']);
    });

    test('matches the fallback title built from verb and subject', () {
      final r = searchActivityLog(events, 'earned reward');
      expect(r.map((e) => e.id), ['c']);
    });

    test('matches the visible detail text', () {
      expect(searchActivityLog(events, 'CLUB').map((e) => e.id), ['b']);
      expect(searchActivityLog(events, 'zamalek').map((e) => e.id), ['e']);
    });

    test('blank and whitespace-only queries return the list unchanged', () {
      expect(searchActivityLog(events, ''), same(events));
      expect(searchActivityLog(events, '   \t '), same(events));
    });

    test('preserves input order', () {
      final r = searchActivityLog(events, 'padel');
      expect(r.map((e) => e.id), ['a', 'd']);
    });
  });

  group('ActivityLogController query', () {
    late MockActivityFeedDatasource ds;
    late MockPublicActivityRepository repo;

    setUp(() {
      ds = MockActivityFeedDatasource();
      repo = MockPublicActivityRepository();
      when(
        ds.getActivityFeed(
          period: anyNamed('period'),
          limit: anyNamed('limit'),
          cursor: anyNamed('cursor'),
        ),
      ).thenAnswer((_) async => events);
      when(
        repo.fetchUserActivities(
          profileId: anyNamed('profileId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),
      ).thenAnswer((_) async => const Ok(<PublicActivity>[]));
    });

    Future<ActivityLogController> loaded() async {
      final c = ActivityLogController(
        feed: ds,
        social: repo,
        profileId: () async => 'p-me',
      );
      await c.load();
      return c;
    }

    test('query defaults to empty', () async {
      final c = await loaded();
      expect(c.state.query, '');
      expect(c.state.filteredActivities.length, events.length);
    });

    test('category filter and query combine', () async {
      final c = await loaded();
      c.changeCategory('game');
      c.changeQuery('padel');
      expect(c.state.filteredActivities.map((e) => e.id), ['a', 'd']);
      c.changeQuery('club'); // 'b' is a post, not a game
      expect(c.state.filteredActivities, isEmpty);
    });

    test('changing the category keeps the query', () async {
      final c = await loaded();
      c.changeQuery('padel');
      c.changeCategory('me');
      expect(c.state.query, 'padel');
      c.changeCategory('all');
      expect(c.state.query, 'padel');
      expect(c.state.filteredActivities.map((e) => e.id), ['a', 'd']);
    });

    test('changing the query keeps the category', () async {
      final c = await loaded();
      c.changeCategory('game');
      c.changeQuery('padel');
      expect(c.state.category, 'game');
      c.changeQuery('');
      expect(c.state.category, 'game');
      expect(c.state.filteredActivities.map((e) => e.id), ['a', 'd', 'e']);
    });

    test('Last 7 days source list is unchanged by the query', () async {
      final c = await loaded();
      final before = c.state.activities;
      c.changeQuery('padel');
      // ActivitySummaryCard computes its stats from state.activities.
      expect(c.state.activities, same(before));
      expect(c.state.activities.length, events.length);
    });

    test('a reload keeps the query', () async {
      final c = await loaded();
      c.changeQuery('padel');
      await c.load();
      expect(c.state.query, 'padel');
    });
  });
}

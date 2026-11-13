// KAN-852: the merged Activity log — identity, paging over both sources,
// filter reset, error vs empty, and partial failure.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/data/repositories/public_activity_repository.dart';
import 'package:dabbler/features/activities/data/datasources/activity_feed_datasource.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/domain/activity_log_merge.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'activity_log_controller_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ActivityFeedDatasource>(),
  MockSpec<PublicActivityRepository>(),
])
void main() {
  final DateTime t0 = DateTime(2026, 11, 4, 12);

  ActivityFeedEvent feed(
    String id, {
    String subject = 'game',
    String verb = 'created',
    int minutesAgo = 0,
  }) => ActivityFeedEvent(
    id: id,
    subjectType: subject,
    subjectId: id,
    verb: verb,
    timeBucket: 'past',
    happenedAt: t0.subtract(Duration(minutes: minutesAgo)),
    priority: 90,
  );

  PublicActivity pub(
    String id,
    String type, {
    String? parent,
    int minutesAgo = 0,
  }) => PublicActivity(
    id: id,
    activityType: PublicActivityType.fromWire(type),
    rawType: type,
    actorProfileId: 'p-me',
    actorUsername: 'me',
    parentActivityId: parent,
    createdAt: t0.subtract(Duration(minutes: minutesAgo)),
  );

  late MockActivityFeedDatasource ds;
  late MockPublicActivityRepository repo;

  ActivityLogController make({String? profileId = 'p-me'}) =>
      ActivityLogController(
        feed: ds,
        social: repo,
        profileId: () async => profileId,
      );

  void stubFeed(List<ActivityFeedEvent> Function(DateTime? cursor) page) {
    when(
      ds.getActivityFeed(
        period: anyNamed('period'),
        limit: anyNamed('limit'),
        cursor: anyNamed('cursor'),
      ),
    ).thenAnswer((inv) async => page(inv.namedArguments[#cursor] as DateTime?));
  }

  void stubSocial(
    Result<List<PublicActivity>, Failure> Function(int offset) page,
  ) {
    when(
      repo.fetchUserActivities(
        profileId: anyNamed('profileId'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      ),
    ).thenAnswer((inv) async => page(inv.namedArguments[#offset] as int));
  }

  setUp(() {
    ds = MockActivityFeedDatasource();
    repo = MockPublicActivityRepository();
  });

  group('identity', () {
    test('a game in both sources is one row; distinct events all stay', () {
      final List<ActivityFeedEvent> merged = mergeActivityLog(
        <ActivityFeedEvent>[
          feed('g1'),
          feed('g2', verb: 'joined', minutesAgo: 5),
        ],
        <ActivityFeedEvent>[
          activityFromPublic(pub('g1', 'game_create')),
          activityFromPublic(pub('roster-9', 'game_join', parent: 'g2')),
          activityFromPublic(pub('post-1', 'post', minutesAgo: 1)),
          activityFromPublic(pub('like-1', 'like', minutesAgo: 2)),
        ],
      );
      expect(merged.map(activityLogIdentity), <String>[
        'game:created:g1',
        'public:post-1',
        'public:like-1',
        'game:joined:g2',
      ]);
      // The RPC twin wins (it carries the time bucket/schedule).
      expect(merged.first.priority, 90);
    });

    test('the same page twice adds nothing', () {
      final List<ActivityFeedEvent> once = mergeActivityLog(
        const <ActivityFeedEvent>[],
        <ActivityFeedEvent>[feed('a'), feed('b', minutesAgo: 1)],
      );
      expect(mergeActivityLog(once, once), hasLength(2));
    });
  });

  test('loads both sources and pages each beyond the first page', () async {
    final List<ActivityFeedEvent> page1 = List<ActivityFeedEvent>.generate(
      ActivityLogController.feedPageSize,
      (i) => feed('f$i', minutesAgo: i),
    );
    stubFeed(
      (cursor) => cursor == null
          ? page1
          : <ActivityFeedEvent>[feed('f-old', minutesAgo: 1000)],
    );
    final List<PublicActivity> social1 = List<PublicActivity>.generate(
      ActivityLogController.socialPageSize,
      (i) => pub('s$i', 'post', minutesAgo: i * 3),
    );
    stubSocial(
      (offset) => Ok(
        offset == 0
            ? social1
            : <PublicActivity>[pub('s-old', 'like', minutesAgo: 2000)],
      ),
    );

    final ActivityLogController c = make();
    await c.load();
    expect(c.state.activities, hasLength(70));
    expect(c.state.hasMore, isTrue);
    expect(c.state.isEmpty, isFalse);

    await c.loadMore();
    final List<String> ids = c.state.activities.map((e) => e.id).toList();
    expect(ids, hasLength(72));
    expect(ids.last, 's-old');
    expect(ids, contains('f-old'));
    expect(c.state.hasMore, isFalse);
    // The feed cursor is the oldest row seen; social pages by offset.
    verify(
      ds.getActivityFeed(
        period: 'all',
        limit: ActivityLogController.feedPageSize,
        cursor: t0.subtract(const Duration(minutes: 49)),
      ),
    ).called(1);
    verify(
      repo.fetchUserActivities(
        profileId: 'p-me',
        limit: ActivityLogController.socialPageSize,
        offset: ActivityLogController.socialPageSize,
      ),
    ).called(1);
  });

  test('selecting a chip filters; All restores the full list', () async {
    stubFeed(
      (_) => <ActivityFeedEvent>[feed('g1'), feed('r1', subject: 'reward')],
    );
    stubSocial((_) => Ok(<PublicActivity>[pub('p1', 'post')]));
    final ActivityLogController c = make();
    await c.load();

    c.changeCategory('reward');
    expect(c.state.filteredActivities.map((e) => e.id), <String>['r1']);
    c.changeCategory('me');
    expect(c.state.filteredActivities.map((e) => e.id), <String>['p1']);
    c.changeCategory('all');
    expect(c.state.filteredActivities, hasLength(3));
    c.changeCategory('game');
    c.changeCategory(null);
    expect(c.state.filteredActivities, hasLength(3));
  });

  test('both sources fail: an error, not an empty log', () async {
    when(
      ds.getActivityFeed(
        period: anyNamed('period'),
        limit: anyNamed('limit'),
        cursor: anyNamed('cursor'),
      ),
    ).thenThrow(Exception('offline'));
    stubSocial((_) => const Err(Failure(message: 'offline')));
    final ActivityLogController c = make();
    await c.load();
    expect(c.state.loaded, isTrue);
    expect(c.state.error, isNotNull);
    expect(c.state.isEmpty, isFalse);
  });

  test('both sources answer nothing: genuinely empty', () async {
    stubFeed((_) => const <ActivityFeedEvent>[]);
    stubSocial((_) => const Ok(<PublicActivity>[]));
    final ActivityLogController c = make();
    await c.load();
    expect(c.state.isEmpty, isTrue);
    expect(c.state.hasMore, isFalse);
  });

  test(
    'empty only after a successful fetch: not before, not while loading',
    () async {
      final Completer<List<ActivityFeedEvent>> feedDone =
          Completer<List<ActivityFeedEvent>>();
      final Completer<Result<List<PublicActivity>, Failure>> socialDone =
          Completer<Result<List<PublicActivity>, Failure>>();
      when(
        ds.getActivityFeed(
          period: anyNamed('period'),
          limit: anyNamed('limit'),
          cursor: anyNamed('cursor'),
        ),
      ).thenAnswer((_) => feedDone.future);
      when(
        repo.fetchUserActivities(
          profileId: anyNamed('profileId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),
      ).thenAnswer((_) => socialDone.future);

      final ActivityLogController c = make();
      // Before any fetch: not loaded, so not empty.
      expect(c.state.loaded, isFalse);
      expect(c.state.isEmpty, isFalse);

      final Future<void> pending = c.load();
      await Future<void>.delayed(Duration.zero);
      // While both sources are in flight: loading, still not empty.
      expect(c.state.isLoading, isTrue);
      expect(c.state.loaded, isFalse);
      expect(c.state.isEmpty, isFalse);

      feedDone.complete(const <ActivityFeedEvent>[]);
      socialDone.complete(const Ok(<PublicActivity>[]));
      await pending;
      // Only now, after a successful empty answer from both, is it empty.
      expect(c.state.isLoading, isFalse);
      expect(c.state.error, isNull);
      expect(c.state.isEmpty, isTrue);
    },
  );

  test('one source fails: the other keeps its rows and the error shows; '
      'Retry clears it', () async {
    stubFeed((_) => <ActivityFeedEvent>[feed('g1')]);
    stubSocial((_) => const Err(Failure(message: 'timeout')));
    final ActivityLogController c = make();
    await c.load();
    expect(c.state.activities.map((e) => e.id), <String>['g1']);
    expect(c.state.socialError, 'timeout');
    expect(c.state.feedError, isNull);

    stubSocial((_) => Ok(<PublicActivity>[pub('p1', 'post', minutesAgo: 1)]));
    await c.refresh();
    expect(c.state.error, isNull);
    expect(c.state.activities.map((e) => e.id), <String>['g1', 'p1']);
  });

  test('no profile yet: the RPC log alone, no error', () async {
    stubFeed((_) => <ActivityFeedEvent>[feed('g1')]);
    final ActivityLogController c = make(profileId: null);
    await c.load();
    expect(c.state.activities, hasLength(1));
    expect(c.state.error, isNull);
    verifyNever(
      repo.fetchUserActivities(
        profileId: anyNamed('profileId'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      ),
    );
  });
}

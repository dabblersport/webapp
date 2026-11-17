// NotificationsController: pages, the server unread count (KAN-987),
// optimistic reads, Realtime inserts and in-place updates, and the empty
// controller of a user who is not signed in.
//
// KAN-987: hand-written fakes replace the mockito mocks (mockito's builder no
// longer runs on this tree: "Missing implementation of
// visitDotShorthandPropertyAccess").
import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/data/notification_realtime_service.dart';
import 'package:dabbler/features/notifications/data/notifications_repository.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';

const _offline = Failure(category: FailureCode.network, message: 'offline');

class FakeRepo implements NotificationsRepository {
  /// Pages by cursor (null is the first page).
  final Map<DateTime?, Result<List<AppNotification>, Failure>> pages = {};
  Result<int, Failure> count = const Ok(0);
  Result<void, Failure> markReadResult = const Ok(null);
  Result<void, Failure> markAllResult = const Ok(null);
  final List<DateTime?> pageCalls = [];
  final List<String> markReadCalls = [];
  int markAllCalls = 0;
  int countCalls = 0;

  @override
  Future<Result<List<AppNotification>, Failure>> getPage({
    int limit = 20,
    DateTime? cursor,
  }) async {
    pageCalls.add(cursor);
    return pages[cursor] ?? const Ok(<AppNotification>[]);
  }

  @override
  Future<Result<int, Failure>> getUnreadCount() async {
    countCalls++;
    return count;
  }

  @override
  Future<Result<void, Failure>> markAsRead(String id) async {
    markReadCalls.add(id);
    return markReadResult;
  }

  @override
  Future<Result<void, Failure>> markAllRead() async {
    markAllCalls++;
    return markAllResult;
  }

  @override
  Future<Result<void, Failure>> markClicked(String id) async => const Ok(null);
}

class FakeRealtime implements NotificationRealtimeService {
  OnNewNotification? onInsert;
  OnUpdatedNotification? onUpdate;
  final List<String> subscribed = [];
  int unsubscribes = 0;

  @override
  bool get isSubscribed => onInsert != null;

  @override
  void subscribe({
    required String userId,
    required OnNewNotification onNewNotification,
    OnUpdatedNotification? onUpdatedNotification,
  }) {
    subscribed.add(userId);
    onInsert = onNewNotification;
    onUpdate = onUpdatedNotification;
  }

  @override
  void unsubscribe() {
    unsubscribes++;
    onInsert = null;
    onUpdate = null;
  }

  @override
  void dispose() => unsubscribe();
}

AppNotification n(
  String id, {
  bool isRead = false,
  DateTime? createdAt,
  String kind = 'games.joined',
}) => AppNotification(
  id: id,
  toUserId: 'u1',
  kindKey: kind,
  title: 'Title $id',
  isRead: isRead,
  createdAt: createdAt ?? DateTime.utc(2026, 8, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRepo repo;
  late FakeRealtime realtime;

  setUp(() {
    repo = FakeRepo();
    realtime = FakeRealtime();
  });

  Future<NotificationsController> build({bool enabled = true}) async {
    final c = NotificationsController(
      repository: repo,
      realtimeService: realtime,
      userId: 'u1',
      enabled: enabled,
    );
    addTearDown(c.dispose);
    await pumpEventQueue();
    return c;
  }

  group('load', () {
    test('populates the list; the unread count is the server count, not the '
        'loaded page', () async {
      repo.pages[null] = Ok([n('n1'), n('n2', isRead: true)]);
      repo.count = const Ok(37);
      final c = await build();
      expect(c.state.notifications, hasLength(2));
      expect(c.state.unreadCount, 37);
      expect(c.state.isLoading, isFalse);
      expect(repo.countCalls, greaterThan(0));
    });

    test('a failed page surfaces as state.error', () async {
      repo.pages[null] = const Err(_offline);
      final c = await build();
      expect(c.state.error, 'offline');
      expect(c.state.notifications, isEmpty);
    });

    test('a failed count keeps the last count', () async {
      repo.count = const Ok(4);
      final c = await build();
      repo.count = const Err(_offline);
      await c.refreshUnreadCount();
      expect(c.state.unreadCount, 4);
    });

    test(
      'loadMore pages by the last created_at and stops at a short page',
      () async {
        final at = DateTime.utc(2026, 8, 20);
        repo.pages[null] = Ok([
          for (var i = 0; i < 20; i++) n('n$i', createdAt: at),
        ]);
        repo.pages[at] = Ok([n('older', createdAt: at)]);
        final c = await build();
        await c.loadMore();
        expect(c.state.notifications, hasLength(21));
        expect(c.state.hasMore, isFalse);
        await c.loadMore();
        expect(repo.pageCalls, [null, at]);
      },
    );
  });

  group('mark read', () {
    test(
      'markAsRead drops the count at once and keeps it on success',
      () async {
        repo.pages[null] = Ok([n('n1'), n('n2')]);
        repo.count = const Ok(2);
        final c = await build();
        repo.count = const Ok(1);
        final pending = c.markAsRead('n1');
        expect(c.state.unreadCount, 1, reason: 'optimistic');
        expect(c.state.notifications.first.isRead, isTrue);
        await pending;
        expect(repo.markReadCalls, ['n1']);
        expect(c.state.unreadCount, 1);
      },
    );

    test('markAsRead rolls back on failure', () async {
      repo.pages[null] = Ok([n('n1')]);
      repo.count = const Ok(1);
      final c = await build();
      repo.markReadResult = const Err(_offline);
      await c.markAsRead('n1');
      expect(c.state.notifications.first.isRead, isFalse);
      expect(c.state.unreadCount, 1);
    });

    test('markAsRead of an unknown or read row does nothing', () async {
      repo.pages[null] = Ok([n('n1', isRead: true)]);
      final c = await build();
      await c.markAsRead('missing');
      await c.markAsRead('n1');
      expect(repo.markReadCalls, isEmpty);
    });

    test('markAllRead zeroes the count, and restores it on failure', () async {
      repo.pages[null] = Ok([n('n1'), n('n2')]);
      repo.count = const Ok(9);
      final c = await build();
      repo.count = const Ok(0);
      await c.markAllRead();
      expect(c.state.unreadCount, 0);
      expect(c.state.notifications.every((x) => x.isRead), isTrue);

      repo.pages[null] = Ok([n('n3')]);
      repo.count = const Ok(5);
      await c.refresh();
      repo.markAllResult = const Err(_offline);
      await c.markAllRead();
      expect(c.state.notifications.single.isRead, isFalse);
      expect(c.state.unreadCount, 5);
    });
  });

  group('realtime', () {
    test('subscribes to inserts and updates for the user', () async {
      await build();
      expect(realtime.subscribed, ['u1']);
      expect(realtime.onInsert, isNotNull);
      expect(realtime.onUpdate, isNotNull);
    });

    test('an INSERT adds one row at the top and re-reads the count', () async {
      repo.pages[null] = Ok([n('old', createdAt: DateTime.utc(2026, 8, 20))]);
      repo.count = const Ok(1);
      final c = await build();
      repo.count = const Ok(2);
      realtime.onInsert!(n('fresh', createdAt: DateTime.utc(2026, 8, 21)));
      expect(c.state.notifications.map((x) => x.id), ['fresh', 'old']);
      expect(c.state.unreadCount, 2, reason: 'optimistic +1');
      await pumpEventQueue();
      expect(c.state.unreadCount, 2);
    });

    test('the same row arriving twice is shown once', () async {
      repo.pages[null] = Ok([n('a')]);
      final c = await build();
      realtime.onInsert!(n('b', createdAt: DateTime.utc(2026, 8, 21)));
      realtime.onInsert!(n('b', createdAt: DateTime.utc(2026, 8, 21)));
      realtime.onInsert!(n('a'));
      expect(c.state.notifications.map((x) => x.id), ['b', 'a']);
    });

    test('an UPDATE replaces the row, moves it to the top when its time '
        'changes, and turns it unread', () async {
      repo.pages[null] = Ok([
        n('x', createdAt: DateTime.utc(2026, 8, 22)),
        n('grouped', isRead: true, createdAt: DateTime.utc(2026, 8, 20)),
      ]);
      repo.count = const Ok(1);
      final c = await build();
      repo.count = const Ok(2);
      final grown = AppNotification(
        id: 'grouped',
        toUserId: 'u1',
        kindKey: 'social.post_liked',
        title: 'Sara and 2 others liked your post',
        isRead: false,
        groupKey: 'like:p1',
        schemaVersion: 2,
        createdAt: DateTime.utc(2026, 8, 23),
      );
      realtime.onUpdate!(grown);
      expect(c.state.notifications.map((x) => x.id), ['grouped', 'x']);
      expect(c.state.notifications.first.title, grown.title);
      expect(c.state.notifications.first.isRead, isFalse);
      expect(c.state.unreadCount, 2);
      await pumpEventQueue();
      expect(c.state.unreadCount, 2);
    });

    test('an UPDATE read on another device drops the count', () async {
      repo.pages[null] = Ok([n('a'), n('b')]);
      repo.count = const Ok(2);
      final c = await build();
      repo.count = const Ok(1);
      realtime.onUpdate!(n('a', isRead: true));
      expect(c.state.unreadCount, 1);
      expect(
        c.state.notifications.firstWhere((x) => x.id == 'a').isRead,
        isTrue,
      );
      expect(c.state.notifications, hasLength(2));
    });

    test(
      'an UPDATE of a row older than the loaded range is not added',
      () async {
        repo.pages[null] = Ok([n('a', createdAt: DateTime.utc(2026, 8, 20))]);
        final c = await build();
        realtime.onUpdate!(n('ancient', createdAt: DateTime.utc(2026, 1, 1)));
        expect(c.state.notifications.map((x) => x.id), ['a']);
      },
    );
  });

  test('a controller for a user who is not signed in is empty: no load, no '
      'count, no subscription', () async {
    repo.pages[null] = Ok([n('a')]);
    repo.count = const Ok(3);
    final c = await build(enabled: false);
    expect(c.state.notifications, isEmpty);
    expect(c.state.unreadCount, 0);
    expect(repo.pageCalls, isEmpty);
    expect(repo.countCalls, 0);
    expect(realtime.subscribed, isEmpty);
    await c.loadNotifications();
    expect(repo.pageCalls, isEmpty);
  });

  test('dispose removes the subscription', () async {
    final c = NotificationsController(
      repository: repo,
      realtimeService: realtime,
      userId: 'u1',
    );
    await pumpEventQueue();
    c.dispose();
    expect(realtime.unsubscribes, 1);
    expect(realtime.onInsert, isNull);
  });

  test('filterByKind filters by kind_key prefix', () async {
    repo.pages[null] = Ok([n('1'), n('2', kind: 'social.follow')]);
    final c = await build();
    expect(c.filterByKind('games').map((x) => x.id), ['1']);
    expect(c.filterByKind(null), hasLength(2));
  });
}

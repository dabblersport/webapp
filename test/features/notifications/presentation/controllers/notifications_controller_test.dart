import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/data/notification_realtime_service.dart';
import 'package:dabbler/features/notifications/data/notifications_repository.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';

import 'notifications_controller_test.mocks.dart';

@GenerateMocks([NotificationsRepository, NotificationRealtimeService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotificationsRepository repository;
  late MockNotificationRealtimeService realtimeService;

  AppNotification makeNotification({
    String id = 'n1',
    bool isRead = false,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id,
      toUserId: 'u1',
      kindKey: 'games.joined',
      title: 'Title $id',
      isRead: isRead,
      interactionCount: 0,
      createdAt: createdAt ?? DateTime.utc(2026, 8, 20),
    );
  }

  setUp(() {
    repository = MockNotificationsRepository();
    realtimeService = MockNotificationRealtimeService();
    // Default stub: realtime subscribe/unsubscribe are no-ops unless a test
    // wants to capture the callback.
    when(
      realtimeService.subscribe(
        userId: anyNamed('userId'),
        onNewNotification: anyNamed('onNewNotification'),
      ),
    ).thenReturn(null);
    when(realtimeService.unsubscribe()).thenReturn(null);
  });

  NotificationsController buildController() {
    return NotificationsController(
      repository: repository,
      realtimeService: realtimeService,
      userId: 'u1',
    );
  }

  group('loadNotifications', () {
    test('populates state and unread count from the first page', () async {
      when(repository.getPage(limit: 20, cursor: null)).thenAnswer(
        (_) async => Ok([makeNotification(id: 'n1'), makeNotification(id: 'n2', isRead: true)]),
      );

      final controller = buildController();
      await controller.loadNotifications();

      expect(controller.state.notifications, hasLength(2));
      expect(controller.state.unreadCount, 1);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
      addTearDown(controller.dispose);
    });

    test('surfaces a repository failure as state.error', () async {
      when(repository.getPage(limit: 20, cursor: null)).thenAnswer(
        (_) async => const Err(Failure(category: FailureCode.network, message: 'offline')),
      );

      final controller = buildController();
      await controller.loadNotifications();

      expect(controller.state.error, 'offline');
      expect(controller.state.notifications, isEmpty);
      addTearDown(controller.dispose);
    });

    test('hasMore is false once a short page comes back', () async {
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok([makeNotification()]));

      final controller = buildController();
      await controller.loadNotifications();

      expect(controller.state.hasMore, isFalse);
      addTearDown(controller.dispose);
    });
  });

  group('loadMore', () {
    test('requests the next page using the last item as cursor', () async {
      final first = makeNotification(id: 'n1', createdAt: DateTime.utc(2026, 8, 20));
      // Full page so hasMore stays true and loadMore actually fires.
      final firstPage = List.generate(
        20,
        (i) => makeNotification(id: 'n$i', createdAt: first.createdAt),
      );
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok(firstPage));
      when(repository.getPage(limit: 20, cursor: first.createdAt))
          .thenAnswer((_) async => Ok([makeNotification(id: 'older')]));

      final controller = buildController();
      await controller.loadNotifications();
      await controller.loadMore();

      expect(controller.state.notifications, hasLength(21));
      verify(repository.getPage(limit: 20, cursor: first.createdAt)).called(1);
      addTearDown(controller.dispose);
    });

    test('does nothing once hasMore is false', () async {
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok([makeNotification()]));

      final controller = buildController();
      await controller.loadNotifications();
      await controller.loadMore();

      verify(repository.getPage(limit: 20, cursor: null)).called(1);
      verifyNoMoreInteractions(repository);
      addTearDown(controller.dispose);
    });
  });

  group('markAsRead', () {
    test('optimistically marks read and keeps it on repository success', () async {
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok([makeNotification(id: 'n1')]));
      when(repository.markAsRead('n1')).thenAnswer((_) async => const Ok<void, Failure>(null));

      final controller = buildController();
      await controller.loadNotifications();
      await controller.markAsRead('n1');

      expect(controller.state.notifications.first.isRead, isTrue);
      expect(controller.state.unreadCount, 0);
      addTearDown(controller.dispose);
    });

    test('rolls back the optimistic update when the server call fails', () async {
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok([makeNotification(id: 'n1')]));
      when(repository.markAsRead('n1')).thenAnswer(
        (_) async => const Err(Failure(category: FailureCode.network, message: 'offline')),
      );

      final controller = buildController();
      await controller.loadNotifications();
      await controller.markAsRead('n1');

      expect(controller.state.notifications.first.isRead, isFalse);
      expect(controller.state.unreadCount, 1);
      addTearDown(controller.dispose);
    });

    test('is a no-op for an id not present in state', () async {
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok([makeNotification(id: 'n1')]));

      final controller = buildController();
      await controller.loadNotifications();
      await controller.markAsRead('missing');

      verifyNever(repository.markAsRead(any));
      addTearDown(controller.dispose);
    });
  });

  group('markAllRead', () {
    test('marks every unread notification read and zeroes the count', () async {
      when(repository.getPage(limit: 20, cursor: null)).thenAnswer(
        (_) async => Ok([makeNotification(id: 'n1'), makeNotification(id: 'n2')]),
      );
      when(repository.markAllRead()).thenAnswer((_) async => const Ok<void, Failure>(null));

      final controller = buildController();
      await controller.loadNotifications();
      await controller.markAllRead();

      expect(controller.state.unreadCount, 0);
      expect(controller.state.notifications.every((n) => n.isRead), isTrue);
      addTearDown(controller.dispose);
    });

    test('rolls back all notifications when the server call fails', () async {
      when(repository.getPage(limit: 20, cursor: null)).thenAnswer(
        (_) async => Ok([makeNotification(id: 'n1'), makeNotification(id: 'n2')]),
      );
      when(repository.markAllRead()).thenAnswer(
        (_) async => const Err(Failure(category: FailureCode.network, message: 'offline')),
      );

      final controller = buildController();
      await controller.loadNotifications();
      await controller.markAllRead();

      expect(controller.state.unreadCount, 2);
      expect(controller.state.notifications.every((n) => !n.isRead), isTrue);
      addTearDown(controller.dispose);
    });
  });

  group('filterByKind', () {
    test('filters by kind_key prefix', () async {
      when(repository.getPage(limit: 20, cursor: null)).thenAnswer(
        (_) async => Ok([
          AppNotification(
            id: '1',
            toUserId: 'u1',
            kindKey: 'games.joined',
            title: 'a',
            createdAt: DateTime.utc(2026, 8, 20),
          ),
          AppNotification(
            id: '2',
            toUserId: 'u1',
            kindKey: 'social.follow',
            title: 'b',
            createdAt: DateTime.utc(2026, 8, 20),
          ),
        ]),
      );

      final controller = buildController();
      await controller.loadNotifications();

      expect(controller.filterByKind('games').map((n) => n.id), ['1']);
      expect(controller.filterByKind(null), hasLength(2));
      addTearDown(controller.dispose);
    });
  });

  group('realtime insert', () {
    test('prepends a new notification delivered over realtime', () async {
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok([makeNotification(id: 'existing')]));

      late OnNewNotification onNewNotification;
      when(
        realtimeService.subscribe(
          userId: anyNamed('userId'),
          onNewNotification: anyNamed('onNewNotification'),
        ),
      ).thenAnswer((invocation) {
        onNewNotification =
            invocation.namedArguments[#onNewNotification] as OnNewNotification;
      });

      final controller = buildController();
      await controller.loadNotifications();
      onNewNotification(makeNotification(id: 'fresh'));

      expect(controller.state.notifications.first.id, 'fresh');
      expect(controller.state.unreadCount, 2);
      addTearDown(controller.dispose);
    });

    test('ignores a duplicate id already present in state', () async {
      when(repository.getPage(limit: 20, cursor: null))
          .thenAnswer((_) async => Ok([makeNotification(id: 'existing')]));

      late OnNewNotification onNewNotification;
      when(
        realtimeService.subscribe(
          userId: anyNamed('userId'),
          onNewNotification: anyNamed('onNewNotification'),
        ),
      ).thenAnswer((invocation) {
        onNewNotification =
            invocation.namedArguments[#onNewNotification] as OnNewNotification;
      });

      final controller = buildController();
      await controller.loadNotifications();
      onNewNotification(makeNotification(id: 'existing'));

      expect(controller.state.notifications, hasLength(1));
      addTearDown(controller.dispose);
    });
  });
}

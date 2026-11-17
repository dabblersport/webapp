// KAN-993: the in-app pop-up. The shared de-dup ledger in both orders (push
// first, Realtime first), every suppression rule, and the presenter in EN and
// AR: one banner per new row, queued one at a time, tap routing (with and
// without a target), long text, the push hand-over and no pop for UPDATEs.

import 'dart:async';

import 'package:dabbler/core/feedback/notification_popup_presenter.dart';
import 'package:dabbler/core/feedback/notification_popup_rules.dart';
import 'package:dabbler/core/feedback/notification_presentation_key.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/notifications/push_presence.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/profile/settings_test_overrides.dart'
    show FakeNotificationSettings;

AppNotification _n(
  String id, {
  String kind = 'game.updated',
  String title = 'Thursday 5-a-side changed',
  String? body = 'Now at 8:00 PM',
  String? route = '/sports/games/g1',
  Map<String, dynamic>? ctx,
  String? dedupe,
  bool read = false,
}) => AppNotification(
  id: id,
  toUserId: 'u1',
  kindKey: kind,
  title: title,
  body: body,
  actionRoute: route,
  payload: ctx,
  dedupeKey: dedupe,
  isRead: read,
  createdAt: DateTime(2026, 11, 17, 12),
);

final DateTime _noon = DateTime(2026, 11, 17, 12);

class _FakeInbox extends StateNotifier<NotificationsState>
    implements NotificationsController {
  _FakeInbox() : super(const NotificationsState(hasMore: false));
  final List<String> read = <String>[];

  @override
  Future<void> markAsRead(String id) async => read.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Harness {
  final StreamController<AppNotification> arrivals =
      StreamController<AppNotification>.broadcast();
  final NotificationPresentationLedger ledger =
      NotificationPresentationLedger();
  final _FakeInbox inbox = _FakeInbox();
  final StreamController<ForegroundPush> pushes =
      StreamController<ForegroundPush>.broadcast();
  final List<bool> owns = <bool>[];
  final List<String> opened = <String>[];
  String location = '/home';
  bool foreground = true;
  NotificationSettings settings = NotificationSettings.defaults('u1');
}

Future<_Harness> _pump(
  WidgetTester tester,
  Locale locale, {
  _Harness? h,
}) async {
  final _Harness harness = h ?? _Harness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationUserIdProvider.overrideWithValue('u1'),
        notificationPopupArrivalsProvider.overrideWith(
          (ref, userId) => harness.arrivals.stream,
        ),
        notificationPresentationLedgerProvider.overrideWithValue(
          harness.ledger,
        ),
        notificationForegroundPushesProvider.overrideWithValue(
          harness.pushes.stream,
        ),
        notificationPopupOwnsAlertsProvider.overrideWithValue(harness.owns.add),
        notificationSettingsControllerProvider.overrideWith(
          (ref) => FakeNotificationSettings(harness.settings),
        ),
        notificationsControllerProvider.overrideWith(
          (ref, userId) => harness.inbox,
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
        builder: (context, child) => NotificationPopupPresenter(
          currentLocation: () => harness.location,
          openRoute: harness.opened.add,
          now: () => _noon,
          isForeground: () => harness.foreground,
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _arrive(WidgetTester tester, _Harness h, AppNotification n) async {
  h.arrivals.add(n);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('shared de-dup ledger', () {
    test('Realtime first: the pop-up shows, the push alert does not', () {
      final ledger = NotificationPresentationLedger();
      final key = NotificationPresentationKey.of(
        notificationId: 'n1',
        dedupeKey: 'd1',
      );
      expect(ledger.claimPopup(key), isTrue);
      // The push for the same row arrives after (background handler).
      final push = NotificationPresentationKey.fromPushData({
        'notification_id': 'n1',
        'dedupe_key': 'd1',
      });
      expect(ledger.claimSystemAlert(push, foreground: false), isFalse);
      expect(ledger.claimPopup(push), isFalse);
    });

    test('push first (background): the alert shows, no pop-up later', () {
      final ledger = NotificationPresentationLedger();
      final push = NotificationPresentationKey.fromPushData({
        'notification_id': 'n2',
      });
      expect(ledger.claimSystemAlert(push, foreground: false), isTrue);
      expect(
        ledger.claimPopup(NotificationPresentationKey.of(notificationId: 'n2')),
        isFalse,
      );
    });

    test('a match on the dedupe key alone is the same notification', () {
      final ledger = NotificationPresentationLedger();
      expect(
        ledger.claimPopup(NotificationPresentationKey.of(dedupeKey: 'd9')),
        isTrue,
      );
      expect(
        ledger.claimSystemAlert(
          NotificationPresentationKey.of(notificationId: 'x', dedupeKey: 'd9'),
          foreground: false,
        ),
        isFalse,
      );
    });

    test('in the foreground with a presenter, no system alert', () {
      final ledger = NotificationPresentationLedger();
      ledger.popupPresenterMounted = true;
      expect(
        ledger.claimSystemAlert(
          NotificationPresentationKey.of(notificationId: 'n3'),
          foreground: true,
        ),
        isFalse,
      );
    });

    test('the ledger is bounded', () {
      final ledger = NotificationPresentationLedger(capacity: 2);
      for (final id in ['a', 'b', 'c']) {
        ledger.claimPopup(NotificationPresentationKey.of(notificationId: id));
      }
      expect(
        ledger.claimPopup(NotificationPresentationKey.of(notificationId: 'a')),
        isTrue,
      );
    });
  });

  group('suppression rules', () {
    NotificationPopupDecision d(
      AppNotification n, {
      String location = '/home',
      bool foreground = true,
      NotificationSettings? settings,
      DateTime? now,
    }) => decideNotificationPopup(
      n: n,
      location: location,
      now: now ?? _noon,
      foreground: foreground,
      settings: settings ?? NotificationSettings.defaults('u1'),
    );

    test('a new row in the foreground shows', () {
      expect(d(_n('1')), NotificationPopupDecision.show);
    });

    test('background, or a row already read', () {
      expect(
        d(_n('1'), foreground: false),
        NotificationPopupDecision.background,
      );
      expect(d(_n('1', read: true)), NotificationPopupDecision.alreadyRead);
    });

    test('on the Notifications screen', () {
      expect(
        d(_n('1'), location: RoutePaths.notifications),
        NotificationPopupDecision.onNotificationsScreen,
      );
    });

    test('the target is the open screen', () {
      expect(
        d(_n('1'), location: '/sports/games/g1'),
        NotificationPopupDecision.targetOpen,
      );
    });

    test('a message for the open conversation', () {
      final m = _n(
        '1',
        kind: 'message.received',
        route: null,
        ctx: {'conversation_id': 'c1'},
      );
      expect(
        d(m, location: '/messaging/thread/c1'),
        NotificationPopupDecision.conversationOpen,
      );
      expect(
        d(m, location: '/messaging/thread/c2'),
        isNot(NotificationPopupDecision.conversationOpen),
      );
    });

    test('a muted kind', () {
      expect(
        d(
          _n('1'),
          settings: const NotificationSettings(
            userId: 'u1',
            mutedKinds: ['game.updated'],
          ),
        ),
        NotificationPopupDecision.muted,
      );
    });

    test('the category in-app switch is off', () {
      final s = NotificationSettings.defaults(
        'u1',
      ).withCategory('games', 'in_app', false);
      expect(d(_n('1'), settings: s), NotificationPopupDecision.categoryOff);
      // The push switch alone does not silence the pop-up.
      final p = NotificationSettings.defaults(
        'u1',
      ).withCategory('games', 'push', false);
      expect(d(_n('1'), settings: p), NotificationPopupDecision.show);
    });

    test('quiet hours silence it; a break-through kind still shows', () {
      const quiet = NotificationSettings(
        userId: 'u1',
        quietStartMin: 23 * 60,
        quietEndMin: 7 * 60,
      );
      final night = DateTime(2026, 11, 17, 1);
      final like = _n('1', kind: 'social.post_liked', route: '/post/p1');
      expect(
        d(like, settings: quiet, now: night),
        NotificationPopupDecision.quietHours,
      );
      expect(d(like, settings: quiet), NotificationPopupDecision.show);
      // game.updated breaks quiet hours (an event update).
      expect(
        d(_n('2'), settings: quiet, now: night),
        NotificationPopupDecision.show,
      );
    });

    test('the quiet window crosses midnight, end exclusive', () {
      const s = NotificationSettings(
        userId: 'u1',
        quietStartMin: 23 * 60,
        quietEndMin: 7 * 60,
      );
      expect(notificationInQuietHours(s, 23 * 60), isTrue);
      expect(notificationInQuietHours(s, 6 * 60 + 59), isTrue);
      expect(notificationInQuietHours(s, 7 * 60), isFalse);
      expect(notificationInQuietHours(s, 12 * 60), isFalse);
    });
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final AppLocalizations l = lookupAppLocalizations(locale);
    final String lang = locale.languageCode;

    testWidgets('[$lang] a new row shows one banner; tap opens its target', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      await _arrive(tester, h, _n('n1'));
      expect(find.byType(DabblerBanner), findsOneWidget);
      expect(find.text(l.notif_action_view), findsOneWidget);
      await tester.tap(find.byType(NotificationPopupBanner));
      await tester.pump();
      expect(h.opened, ['/sports/games/g1']);
      expect(h.inbox.read, ['n1']);
      expect(find.byType(DabblerBanner), findsNothing);
    });

    testWidgets('[$lang] RTL: the banner is laid out right to left', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      await _arrive(tester, h, _n('n1'));
      final TextDirection dir = Directionality.of(
        tester.element(find.byType(DabblerBanner)),
      );
      expect(dir, lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
    });

    testWidgets('[$lang] no target: no action, tap does nothing', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      await _arrive(
        tester,
        h,
        _n('n1', kind: 'system.announcement', route: null, title: 'Hello'),
      );
      expect(find.byType(DabblerBanner), findsOneWidget);
      expect(find.text(l.notif_action_view), findsNothing);
      await tester.tap(find.byType(NotificationPopupBanner));
      await tester.pump();
      expect(h.opened, isEmpty);
    });

    testWidgets('[$lang] long text renders without overflow', (tester) async {
      final h = await _pump(tester, locale);
      await _arrive(
        tester,
        h,
        _n(
          'n1',
          kind: 'system.announcement',
          route: null,
          title: 'A' * 30,
          body: List<String>.filled(40, 'word').join(' '),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerBanner), findsOneWidget);
    });

    testWidgets('[$lang] rows arriving together show one at a time', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      h.arrivals
        ..add(_n('n1', route: '/a'))
        ..add(_n('n2', route: '/b'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DabblerBanner), findsOneWidget);
      expect(find.byKey(const ValueKey('notif-popup-n1')), findsOneWidget);
      await tester.pump(kNotificationPopupDuration);
      await tester.pump();
      expect(find.byKey(const ValueKey('notif-popup-n2')), findsOneWidget);
      await tester.pump(kNotificationPopupDuration);
      await tester.pump();
      expect(find.byType(DabblerBanner), findsNothing);
    });

    testWidgets('[$lang] the same row twice (or after its push) pops once', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      h.ledger.claimSystemAlert(
        NotificationPresentationKey.of(notificationId: 'pushed'),
        foreground: false,
      );
      await _arrive(tester, h, _n('pushed'));
      expect(find.byType(DabblerBanner), findsNothing);
      await _arrive(tester, h, _n('n1', dedupe: 'd1'));
      await tester.pump(kNotificationPopupDuration);
      await tester.pump();
      await _arrive(tester, h, _n('n1-again', dedupe: 'd1'));
      expect(find.byType(DabblerBanner), findsNothing);
    });

    testWidgets('[$lang] mounted, the pop-up owns foreground alerts', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      expect(h.owns.last, isTrue);
      expect(h.ledger.popupPresenterMounted, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(h.owns.last, isFalse);
      expect(h.ledger.popupPresenterMounted, isFalse);
    });

    testWidgets('[$lang] a push that alerted: its Realtime row does not pop', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      h.pushes.add(
        const ForegroundPush(
          {'notification_id': 'p0', 'kind_key': 'game.updated'},
          dedupeKey: 'p0',
          alerted: true,
        ),
      );
      await tester.pump();
      await _arrive(tester, h, _n('p0'));
      expect(find.byType(DabblerBanner), findsNothing);
    });

    testWidgets('[$lang] a push that stepped aside becomes the one pop-up', (
      tester,
    ) async {
      final h = await _pump(tester, locale);
      h.pushes.add(
        const ForegroundPush(
          {
            'notification_id': 'p1',
            'dedupe_key': 'dk1',
            'kind_key': 'game.updated',
            'title': 'Game changed',
            'action_route': '/sports/games/g7',
          },
          dedupeKey: 'dk1',
          alerted: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(DabblerBanner), findsOneWidget);
      await tester.tap(find.byType(NotificationPopupBanner));
      await tester.pump();
      expect(h.opened, ['/sports/games/g7']);
      // The Realtime row for the same notification does not pop again.
      await _arrive(tester, h, _n('p1', dedupe: 'dk1'));
      expect(find.byType(DabblerBanner), findsNothing);
    });

    for (final (String name, void Function(_Harness) setup)
        in <(String, void Function(_Harness))>[
          ('on the Notifications screen', (h) => h.location = '/notifications'),
          ('the target already open', (h) => h.location = '/sports/games/g1'),
          ('in the background', (h) => h.foreground = false),
          (
            'a muted kind',
            (h) => h.settings = const NotificationSettings(
              userId: 'u1',
              mutedKinds: ['game.updated'],
            ),
          ),
          (
            'the in-app switch off',
            (h) => h.settings = NotificationSettings.defaults(
              'u1',
            ).withCategory('games', 'in_app', false),
          ),
        ]) {
      testWidgets('[$lang] no banner: $name', (tester) async {
        final h = _Harness();
        setup(h);
        await _pump(tester, locale, h: h);
        await _arrive(tester, h, _n('n1'));
        expect(find.byType(DabblerBanner), findsNothing);
      });
    }

    testWidgets('[$lang] no banner: the open conversation', (tester) async {
      final h = _Harness()..location = '/messaging/thread/c1';
      await _pump(tester, locale, h: h);
      await _arrive(
        tester,
        h,
        _n(
          'm1',
          kind: 'message.received',
          route: null,
          ctx: const {'conversation_id': 'c1'},
        ),
      );
      expect(find.byType(DabblerBanner), findsNothing);
    });

    testWidgets('[$lang] no banner: quiet hours (social)', (tester) async {
      final h = _Harness()
        ..settings = const NotificationSettings(
          userId: 'u1',
          quietStartMin: 11 * 60,
          quietEndMin: 13 * 60,
        );
      await _pump(tester, locale, h: h);
      await _arrive(
        tester,
        h,
        _n('n1', kind: 'social.post_liked', route: '/post/p1'),
      );
      expect(find.byType(DabblerBanner), findsNothing);
    });
  }
}

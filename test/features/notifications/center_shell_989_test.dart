// KAN-989 (W1-F3): the Notification Center shell — tabs, header per tab, the
// chips (registry), activity highlights under All, day groups, every list
// state and the tapped-target states, in EN and AR.
import 'dart:convert';

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/notifications/presentation/screens/notifications_screen_v2.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_center_feed.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_chips.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_list_states.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_target_states.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/connectivity_overrides.dart';
import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';
import '../profile/settings_test_overrides.dart' show FakeNotificationSettings;

const _userId = 'u-989';

String _fakeSession(String userId) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/
      1000;
  final jwt =
      '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': userId, 'exp': exp, 'aud': 'authenticated', 'role': 'authenticated'})}.sig';
  return jsonEncode({
    'access_token': jwt,
    'token_type': 'bearer',
    'expires_in': 2592000,
    'expires_at': exp,
    'refresh_token': 'r',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2024-01-01T00:00:00Z',
    },
  });
}

class _Notifs extends StateNotifier<NotificationsState>
    implements NotificationsController {
  _Notifs(super.state);
  int markAll = 0, refreshes = 0, loadMores = 0;
  final List<String> read = [];
  @override
  Future<void> markAllRead() async => markAll++;
  @override
  Future<void> markAsRead(String id) async => read.add(id);
  @override
  Future<void> markClicked(String id) async {}
  @override
  Future<void> refresh() async => refreshes++;
  @override
  Future<void> loadMore() async => loadMores++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Activity extends StateNotifier<ActivityLogState>
    implements ActivityLogController {
  _Activity(super.state);
  @override
  Future<void> load() async {}
  @override
  void changeCategory(String? category) =>
      state = state.copyWith(category: category ?? 'all');
  @override
  Future<void> refresh() async {}
  @override
  Future<void> loadMore() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppNotification _n(
  String id,
  String kind, {
  bool read = false,
  Duration ago = const Duration(minutes: 5),
  Map<String, dynamic>? payload,
  Map<String, dynamic> args = const {},
}) => AppNotification(
  id: id,
  toUserId: _userId,
  kindKey: kind,
  title: 'Title $id',
  isRead: read,
  payload: payload,
  args: args,
  createdAt: DateTime.now().subtract(ago),
);

ActivityFeedEvent _a(
  String id,
  String subject,
  String verb, {
  Duration ago = const Duration(minutes: 20),
}) => ActivityFeedEvent(
  id: id,
  subjectType: subject,
  subjectId: 's-$id',
  verb: verb,
  timeBucket: 'past',
  happenedAt: DateTime.now().subtract(ago),
  priority: 1,
  payload: {'title': 'Activity $id'},
);

/// One of every chip's kinds, plus an open decision and a read row.
List<AppNotification> _mixed() => [
  _n('soc', 'social.post_liked', ago: const Duration(minutes: 1)),
  _n('msg', 'message.received', ago: const Duration(minutes: 2)),
  _n('gam', 'game.invited', ago: const Duration(minutes: 3)),
  _n('mee', 'meetup.invited', read: true, ago: const Duration(minutes: 4)),
  _n('sys', 'system.announcement', read: true, ago: const Duration(minutes: 5)),
  _n(
    'act',
    'activity.checkin_open',
    payload: {'entity_type': 'meetup'},
    ago: const Duration(minutes: 6),
  ),
];

Future<({_Notifs notifs, List<String> pushed})> _pump(
  WidgetTester tester,
  Locale locale, {
  required NotificationsState state,
  List<ActivityFeedEvent> activities = const [],
  bool offline = false,
  NotifTargetProbe? probe,
}) async {
  tester.view.physicalSize = const Size(393, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final notifs = _Notifs(state);
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const NotificationsScreenV2()),
      GoRoute(
        path: '/:rest(.*)',
        builder: (_, s) {
          pushed.add(s.uri.toString());
          return const SizedBox.shrink();
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsControllerProvider(_userId).overrideWith((ref) => notifs),
        activityLogControllerProvider.overrideWith(
          (ref) =>
              _Activity(ActivityLogState(activities: activities, loaded: true)),
        ),
        myProfileIdProvider.overrideWith((ref) async => null),
        notificationSettingsControllerProvider.overrideWith(
          (ref) => FakeNotificationSettings(
            const NotificationSettings(userId: _userId),
          ),
        ),
        offline ? offlineConnectivity() : onlineConnectivity(),
        if (probe != null) notifTargetProbeProvider.overrideWithValue(probe),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (notifs: notifs, pushed: pushed);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The chip labelled [label]: the chip rail builds lazily, so it is scrolled
/// into view first.
Finder _chipFinder(String label) =>
    find.byWidgetPredicate((w) => w is DabblerChip && w.label == label);

Future<Finder> _showChip(WidgetTester tester, String label) async {
  final f = _chipFinder(label);
  final rail = find
      .descendant(of: find.byType(ChipsRow), matching: find.byType(Scrollable))
      .first;
  // Start from the rail's beginning, then scroll forward until it is built.
  tester.state<ScrollableState>(rail).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(f, 80, scrollable: rail);
  await tester.ensureVisible(f);
  await tester.pump();
  return f;
}

Future<void> _chip(WidgetTester tester, String label) async {
  final f = await _showChip(tester, label);
  await tester.tap(f);
  await _settle(tester);
}

/// Opens the first row (its title, away from its action buttons).
Future<void> _tapRow(WidgetTester tester) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(DabblerNotificationCard).first,
          matching: find.byType(Text),
        )
        .first,
  );
}

int _rows(WidgetTester tester) =>
    find.byType(DabblerNotificationCard).evaluate().length;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await Supabase.instance.client.auth.recoverSession(_fakeSession(_userId));
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final lang = locale.languageCode;
    final l = lookupAppLocalizations(locale);

    group(lang, () {
      testWidgets('tabs; Mark all read and the unread count only on '
          'Notifications', (tester) async {
        final p = await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: _mixed(),
            unreadCount: 4,
            hasMore: false,
          ),
        );
        expect(find.text(l.notif_title_notifications), findsWidgets);
        expect(find.text(l.notif_title_activity_log), findsOneWidget);
        expect(find.bySemanticsLabel(l.notif_mark_all_read), findsOneWidget);
        expect(find.bySemanticsLabel(l.notif_refresh), findsOneWidget);
        expect(find.text(l.notif_unread_count(4)), findsOneWidget);
        await tester.tap(find.bySemanticsLabel(l.notif_mark_all_read));
        await tester.pump();
        expect(p.notifs.markAll, 1);

        await tester.tap(find.text(l.notif_title_activity_log));
        await _settle(tester);
        expect(find.bySemanticsLabel(l.notif_mark_all_read), findsNothing);
        expect(find.text(l.notif_unread_count(4)), findsNothing);
        expect(find.bySemanticsLabel(l.notif_refresh), findsOneWidget);
      });

      testWidgets('chips: All, Unread (count), Needs action (count), Social, '
          'Messages, Games, Meetups, System; no Booking', (tester) async {
        await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: _mixed(),
            unreadCount: 4,
            hasMore: false,
          ),
        );
        for (final label in [
          l.notif_chip_all,
          l.notif_chip_unread,
          l.notif_chip_needs_action,
          l.notif_chip_social,
          l.notif_chip_messages,
          l.notif_chip_games,
          l.notif_chip_meetups,
          l.notif_chip_system,
        ]) {
          expect(await _showChip(tester, label), findsOneWidget, reason: label);
        }
        expect(_chipFinder(l.notif_chip_bookings), findsNothing);
        final unread = tester.widget<DabblerChip>(
          await _showChip(tester, l.notif_chip_unread),
        );
        expect(unread.count, '4');
        final needs = tester.widget<DabblerChip>(
          await _showChip(tester, l.notif_chip_needs_action),
        );
        expect(needs.count, '3', reason: 'open decisions, not unread rows');

        expect(_rows(tester), 6);
        for (final (label, n) in [
          (l.notif_chip_unread, 4),
          (l.notif_chip_needs_action, 3),
          (l.notif_chip_social, 1),
          (l.notif_chip_messages, 1),
          (l.notif_chip_games, 1),
          (l.notif_chip_meetups, 2),
          (l.notif_chip_system, 1),
        ]) {
          await _chip(tester, label);
          expect(_rows(tester), n, reason: label);
        }
      });

      testWidgets('activity highlights show under All only, marked, never '
          'unread', (tester) async {
        await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: [_n('g', 'game.invited')],
            unreadCount: 1,
            hasMore: false,
          ),
          activities: [_a('h', 'reward', 'earned'), _a('x', 'post', 'posted')],
        );
        expect(find.byType(NotifHighlightRow), findsOneWidget);
        expect(find.text(l.notif_highlight_label), findsOneWidget);
        final row = tester.widget<DabblerNotificationRow>(
          find.descendant(
            of: find.byType(NotifHighlightRow),
            matching: find.byType(DabblerNotificationRow),
          ),
        );
        expect(row.unread, isFalse);
        expect(find.text('Activity x'), findsNothing, reason: 'posted');
        await _chip(tester, l.notif_chip_games);
        expect(find.byType(NotifHighlightRow), findsNothing);
      });

      testWidgets('day groups: Today, Yesterday, Earlier this week', (
        tester,
      ) async {
        await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: [
              _n('a', 'game.invited'),
              _n('b', 'game.invited', ago: const Duration(days: 1, hours: 1)),
              _n('c', 'game.invited', ago: const Duration(days: 3)),
            ],
            hasMore: false,
          ),
        );
        expect(find.text(l.notif_section_today), findsOneWidget);
        expect(find.text(l.notif_section_yesterday), findsOneWidget);
        expect(find.text(l.notif_section_this_week), findsOneWidget);
      });

      testWidgets('first load: the skeleton', (tester) async {
        await _pump(
          tester,
          locale,
          state: const NotificationsState(isLoading: true),
        );
        expect(find.byType(DabblerSkeleton), findsWidgets);
      });

      testWidgets('no notifications', (tester) async {
        await _pump(
          tester,
          locale,
          state: const NotificationsState(hasMore: false),
        );
        expect(find.text(l.notif_empty_no_notifications), findsOneWidget);
        expect(find.text(l.notif_empty_hint), findsOneWidget);
      });

      testWidgets('empty for a chip, with Show all', (tester) async {
        await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: [_n('g', 'game.invited')],
            hasMore: false,
          ),
        );
        await _chip(tester, l.notif_chip_messages);
        expect(
          find.text(l.notif_empty_filter_title(l.notif_chip_messages)),
          findsOneWidget,
        );
        await tester.tap(find.text(l.notif_show_all));
        await _settle(tester);
        expect(_rows(tester), 1);
      });

      testWidgets('initial load failed: Try again', (tester) async {
        final p = await _pump(
          tester,
          locale,
          state: const NotificationsState(error: 'offline'),
        );
        expect(find.text(l.notif_load_failed_title), findsOneWidget);
        await tester.tap(find.text(l.notif_try_again));
        await _settle(tester);
        expect(p.notifs.refreshes, 1);
      });

      testWidgets('refresh failed: the banner over the earlier list, Retry', (
        tester,
      ) async {
        final p = await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: [_n('g', 'game.invited')],
            error: 'timeout',
            hasMore: false,
          ),
        );
        expect(find.text(l.notif_refresh_failed), findsOneWidget);
        expect(_rows(tester), 1);
        await tester.tap(find.text(l.notif_btn_retry));
        await _settle(tester);
        expect(p.notifs.refreshes, 1);
      });

      testWidgets('offline: the saved list and the banner; actions off', (
        tester,
      ) async {
        await _pump(
          tester,
          locale,
          offline: true,
          state: NotificationsState(
            notifications: [_n('g', 'game.invited')],
            unreadCount: 1,
            hasMore: true,
            loadedAt: DateTime(2026, 11, 17, 20, 41),
          ),
        );
        expect(find.byType(DabblerBanner), findsOneWidget);
        expect(_rows(tester), 1);
        expect(find.text(l.notif_load_earlier), findsNothing);
        final ctx = tester.element(find.byType(DabblerNotificationCard).first);
        expect(NotifCenterScopeProbe.actionsEnabled(ctx), isFalse);
      });

      testWidgets('footer: Load earlier, then all caught up', (tester) async {
        final p = await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: [_n('g', 'game.invited')],
            hasMore: true,
          ),
        );
        final more = find.text(l.notif_load_earlier);
        await tester.ensureVisible(more);
        await tester.tap(more);
        await _settle(tester);
        expect(p.notifs.loadMores, 1);
        p.notifs.state = p.notifs.state.copyWith(hasMore: false);
        await _settle(tester);
        expect(find.text(l.notif_all_caught_up), findsOneWidget);
      });

      for (final (state, title) in [
        (NotifTargetState.deleted, l.notif_target_deleted_title),
        (NotifTargetState.cancelled, l.notif_target_cancelled_title),
        (NotifTargetState.expired, l.notif_target_expired_title),
        (NotifTargetState.noAccess, l.notif_target_no_access_title),
        (NotifTargetState.resolved, l.notif_target_resolved_title),
      ]) {
        testWidgets('tapped target ${state.name}: its sheet, nothing opens', (
          tester,
        ) async {
          final p = await _pump(
            tester,
            locale,
            state: NotificationsState(
              notifications: [
                _n('g', 'game.invited', payload: {'entity_id': 'g1'}),
              ],
              hasMore: false,
            ),
            probe: (_) async => state,
          );
          await _tapRow(tester);
          await _settle(tester);
          expect(find.text(title), findsOneWidget);
          expect(p.pushed, isEmpty);
          expect(p.notifs.read, ['g'], reason: 'marked read');
          await tester.tap(find.text(l.notif_target_back));
          await _settle(tester);
          expect(find.text(title), findsNothing);
        });
      }

      testWidgets('tapped target opens; a failed check retries', (
        tester,
      ) async {
        var calls = 0;
        final p = await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: [
              _n('g', 'game.invited', payload: {'entity_id': 'g1'}),
            ],
            hasMore: false,
          ),
          probe: (_) async => calls++ == 0
              ? NotifTargetState.failed
              : NotifTargetState.available,
        );
        await _tapRow(tester);
        await _settle(tester);
        expect(find.text(l.notif_target_failed_title), findsOneWidget);
        await tester.tap(find.text(l.notif_btn_retry));
        await _settle(tester);
        expect(p.pushed, ['/sports/games/g1']);
      });

      testWidgets('an old game.updated row opens as a cancellation', (
        tester,
      ) async {
        final p = await _pump(
          tester,
          locale,
          state: NotificationsState(
            notifications: [
              _n('u', 'game.updated', payload: {'entity_id': 'g1'}),
            ],
            hasMore: false,
          ),
        );
        await _tapRow(tester);
        await _settle(tester);
        expect(find.text(l.notif_target_cancelled_title), findsOneWidget);
        expect(p.pushed, isEmpty);
      });

      testWidgets('bell badge: none at 0, the number, then 9+', (tester) async {
        for (final (count, label) in [(0, null), (3, '3'), (12, '9+')]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                unreadNotificationCountProvider.overrideWithValue(count),
              ],
              child: MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
                home: const Scaffold(body: Center(child: NotificationBadge())),
              ),
            ),
          );
          if (label == null) {
            expect(find.byType(DabblerBadge), findsNothing);
          } else {
            expect(find.text(label), findsOneWidget);
          }
        }
      });
    });
  }
}

/// Reads the Center's actions scope from a row's context.
abstract final class NotifCenterScopeProbe {
  static bool actionsEnabled(BuildContext context) =>
      NotifCenterScope.actionsEnabledOf(context);
}

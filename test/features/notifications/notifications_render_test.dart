import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_feed_controller.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/notifications/presentation/screens/notifications_screen_v2.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show myProfileIdProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

const String _shotsDir = '$kShotsRoot/notifications';
const String _userId = 'u-me';

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf', 'Glory-Regular.ttf', 'Glory-Medium.ttf',
    'Glory-SemiBold.ttf', 'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf', 'meral-sans-regular.ttf', 'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf', 'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader =
        FontLoader('packages/iconsax_flutter/FlutterIconsax')
          ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

String _fakeSession(String userId) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final int exp = DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch ~/
      1000;
  final String jwt =
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

class _FakeNotifs extends StateNotifier<NotificationsState>
    implements NotificationsController {
  _FakeNotifs(super.state);
  int markAllCalls = 0;
  @override
  Future<void> markAllRead() async => markAllCalls++;
  @override
  Future<void> markAsRead(String id) async {}
  @override
  Future<void> markClicked(String id) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> loadMore() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActivity extends StateNotifier<ActivityFeedState>
    implements ActivityFeedController {
  _FakeActivity(super.state);
  @override
  Future<void> loadActivities(String period) async {}
  @override
  void changeCategory(String? category) {}
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppNotification _n(
  String id,
  String kind,
  String title, {
  bool read = false,
  Duration ago = const Duration(minutes: 5),
  String? body,
  Map<String, dynamic>? payload,
}) =>
    AppNotification(
      id: id,
      toUserId: _userId,
      kindKey: kind,
      title: title,
      body: body,
      isRead: read,
      payload: payload,
      createdAt: DateTime.now().subtract(ago),
    );

List<AppNotification> _sample() => [
      _n('1', 'game.invited', 'Game invite',
          payload: {'actor_name': 'Omar Haddad'},
          body: 'Friday 7pm at Al Wasl Courts'),
      _n('2', 'friend.requested', 'Friend request',
          payload: {'actor_name': 'Layla Nasser'}, ago: const Duration(hours: 2)),
      _n('3', 'social.post_liked', 'Liked',
          payload: {'actor_name': 'Sara Khalid'},
          read: true,
          ago: const Duration(hours: 5)),
      _n('4', 'arena.payment_required', 'Payment', body: 'Complete payment to confirm your booking',
          ago: const Duration(days: 1, hours: 2)),
      _n('5', 'reward.badge_awarded', 'Badge', read: true, ago: const Duration(days: 1, hours: 6)),
      _n('6', 'game.reminder', 'Reminder', read: true, ago: const Duration(days: 3)),
      _n('7', 'system.notice', 'Notice', read: true, ago: const Duration(days: 9)),
    ];

List<ActivityFeedEvent> _activities() {
  final now = DateTime.now();
  return [
    ActivityFeedEvent(
      id: 'a1', subjectType: 'game', subjectId: 'g1', verb: 'joined',
      timeBucket: 'present', happenedAt: now.subtract(const Duration(minutes: 20)),
      priority: 1,
      payload: {'title': 'You joined Friday Football', 'venue_name': 'Al Wasl Courts', 'participants_count': 8},
    ),
    ActivityFeedEvent(
      id: 'a2', subjectType: 'reward', subjectId: 'r1', verb: 'earned',
      timeBucket: 'past', happenedAt: now.subtract(const Duration(hours: 3)),
      priority: 1, payload: {'title': 'Earned 50 points', 'description': 'Match completed'},
    ),
    ActivityFeedEvent(
      id: 'a3', subjectType: 'game', subjectId: 'g2', verb: 'created',
      timeBucket: 'upcoming', happenedAt: now.subtract(const Duration(days: 1)),
      priority: 1, payload: {'title': 'Created Sunday Padel', 'location': 'Dubai Marina'},
    ),
    ActivityFeedEvent(
      id: 'a4', subjectType: 'security', subjectId: 's1', verb: 'signed_in',
      timeBucket: 'past', happenedAt: now.subtract(const Duration(days: 1, hours: 4)),
      priority: 1, payload: {'title': 'New sign-in', 'description': 'iPhone, Dubai'},
    ),
  ];
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  Key key, {
  required NotificationsState notifs,
  ActivityFeedState? activity,
  Size size = const Size(393, 852),
  _FakeNotifs? fake,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsControllerProvider(_userId)
            .overrideWith((ref) => fake ?? _FakeNotifs(notifs)),
        activityFeedControllerProvider
            .overrideWith((ref) => _FakeActivity(activity ?? ActivityFeedState())),
        myProfileIdProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: const NotificationsScreenV2(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
    await Supabase.instance.client.auth.recoverSession(_fakeSession(_userId));
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    const Key key = Key('shot');
    final l10n = lookupAppLocalizations(locale);

    testWidgets('notifications all — $dir', (tester) async {
      await _pump(tester, locale, key,
          notifs: NotificationsState(
              notifications: _sample(), unreadCount: 3, hasMore: true));
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerActivityRow), findsWidgets);
      expect(find.byType(DabblerChip), findsWidgets);
      expect(find.text(l10n.notif_title_notifications), findsWidgets);
      await _shoot(tester, key, 'notifications-all-$dir');
    });

    testWidgets('notifications filtered — $dir', (tester) async {
      await _pump(tester, locale, key,
          notifs: NotificationsState(
              notifications: _sample(), unreadCount: 3, hasMore: false));
      await tester.tap(find.byType(DabblerChip).at(1));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerActivityRow), findsNWidgets(2));
      await _shoot(tester, key, 'notifications-filtered-$dir');
    });

    testWidgets('notifications unread — $dir', (tester) async {
      final unread = _sample().map((n) => n.copyWith(isRead: false)).toList();
      final fake = _FakeNotifs(NotificationsState(
          notifications: unread, unreadCount: unread.length, hasMore: false));
      await _pump(tester, locale, key, notifs: fake.state, fake: fake);
      expect(find.byType(DabblerBadge), findsWidgets);
      await tester.tap(find.bySemanticsLabel(l10n.notif_mark_all_read));
      await tester.pump();
      expect(fake.markAllCalls, 1);
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'notifications-unread-$dir');
    });

    testWidgets('notifications empty — $dir', (tester) async {
      await _pump(tester, locale, key,
          notifs: const NotificationsState(hasMore: false));
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      await _shoot(tester, key, 'notifications-empty-$dir');
    });

    testWidgets('notifications loading — $dir', (tester) async {
      await _pump(tester, locale, key,
          notifs: const NotificationsState(isLoading: true, hasMore: false));
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSkeleton), findsWidgets);
      await _shoot(tester, key, 'notifications-loading-$dir');
    });

    testWidgets('notifications error — $dir', (tester) async {
      await _pump(tester, locale, key,
          notifs: const NotificationsState(error: 'Network unreachable'));
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      await _shoot(tester, key, 'notifications-error-$dir');
    });

    testWidgets('activity log — $dir', (tester) async {
      await _pump(tester, locale, key,
          notifs: NotificationsState(notifications: _sample(), unreadCount: 3),
          activity: ActivityFeedState(activities: _activities(), hasMore: false));
      await tester.tap(find.text(l10n.notif_title_activity_log));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerActivityRow), findsWidgets);
      expect(find.byType(DabblerStatTile), findsNWidgets(3));
      await _shoot(tester, key, 'notifications-activity-top-$dir');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 200));
      await _shoot(tester, key, 'notifications-activity-$dir');
    });
  }

  testWidgets('wide layout shows both panes', (tester) async {
    await _pump(tester, const Locale('en'), const Key('shot'),
        notifs: NotificationsState(notifications: _sample(), unreadCount: 3),
        activity: ActivityFeedState(activities: _activities(), hasMore: false),
        size: const Size(1100, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('Activity log'), findsOneWidget);
  });
}

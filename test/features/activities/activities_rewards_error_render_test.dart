// Render tests for the KAN-420 group A screens: activities, rewards, error,
// placeholder, help centre. Every data source is faked; no network.
//
// PNGs are written to the Alpha plan folder (LTR and RTL) for review.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/app/routes/placeholder_screen.dart';
import 'package:dabbler/features/activities/data/datasources/activity_analytics_datasource.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_feed_controller.dart';
import 'package:dabbler/features/activities/presentation/providers/activity_providers.dart';
import 'package:dabbler/features/activities/presentation/screens/activities_screen_v2.dart';
import 'package:dabbler/features/error/presentation/pages/error_page.dart';
import 'package:dabbler/features/misc/presentation/screens/help_center_screen.dart';
import 'package:dabbler/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:dabbler/features/rewards/presentation/widgets/check_in_progress_indicator.dart';
import 'package:dabbler/features/rewards/presentation/widgets/early_bird_check_in_modal.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _shotsDir = '/Users/moataz/Desktop/Dabbler-Alpha-Plan/misc';
const Key _key = Key('shot');

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
    'Glory-Light.ttf',
    'Glory-Regular.ttf',
    'Glory-Medium.ttf',
    'Glory-SemiBold.ttf',
    'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf',
    'meral-sans-regular.ttf',
    'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf',
    'meral-sans-bold.ttf',
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
    final FontLoader loader = FontLoader(
      'packages/iconsax_flutter/FlutterIconsax',
    )..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ThemeData _theme(Locale locale) => DabblerDesignSystemTheme.withFonts(
  DabblerDesignSystemTheme.withTokens(ThemeData.light()),
  locale: locale,
);

Widget _shell(Locale locale, Widget child, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? const <Override>[],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          DabblerToastProvider(child: RepaintBoundary(key: _key, child: child)),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _theme(locale),
      home: child,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  Widget child, {
  List<Override>? overrides,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_shell(locale, child, overrides: overrides));
  await _settle(tester);
}

class _FakeFeed extends StateNotifier<ActivityFeedState>
    implements ActivityFeedController {
  _FakeFeed(super.state);
  String? lastCategory;
  int refreshes = 0;
  int loads = 0;

  @override
  Future<void> loadActivities(String period) async => loads++;
  @override
  Future<void> changePeriod(String newPeriod) async {}
  @override
  Future<void> loadMore() async {}
  @override
  void changeCategory(String? category) {
    lastCategory = category;
    state = state.copyWith(currentCategory: category);
  }

  @override
  Future<void> refresh() async => refreshes++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalytics implements ActivityAnalyticsDatasource {
  @override
  Future<void> trackActivityTabOpened({String source = 'unknown'}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

List<ActivityFeedEvent> _events() {
  final DateTime now = DateTime.now();
  return <ActivityFeedEvent>[
    ActivityFeedEvent(
      id: '1',
      subjectType: 'game',
      subjectId: 'g1',
      verb: 'created',
      timeBucket: 'upcoming',
      happenedAt: now,
      priority: 1,
      payload: <String, dynamic>{'role': 'host', 'title': 'Sunday football'},
    ),
    ActivityFeedEvent(
      id: '2',
      subjectType: 'game',
      subjectId: 'g2',
      verb: 'joined',
      timeBucket: 'upcoming',
      happenedAt: now.subtract(const Duration(hours: 5)),
      priority: 1,
      payload: <String, dynamic>{'title': 'Padel doubles'},
    ),
    ActivityFeedEvent(
      id: '3',
      subjectType: 'reward',
      subjectId: 'r1',
      verb: 'earned',
      timeBucket: 'past',
      happenedAt: now.subtract(const Duration(days: 1)),
      priority: 1,
    ),
    ActivityFeedEvent(
      id: '4',
      subjectType: 'payment',
      subjectId: 'p1',
      verb: 'payment_succeeded',
      timeBucket: 'past',
      happenedAt: now.subtract(const Duration(days: 3)),
      priority: 1,
    ),
    ActivityFeedEvent(
      id: '5',
      subjectType: 'social',
      subjectId: 's1',
      verb: 'followed',
      timeBucket: 'past',
      happenedAt: now.subtract(const Duration(days: 12)),
      priority: 1,
    ),
  ];
}

List<Override> _feedOverrides(_FakeFeed feed) => <Override>[
  activityFeedControllerProvider.overrideWith((ref) => feed),
  activityAnalyticsDatasourceProvider.overrideWithValue(_FakeAnalytics()),
];

Future<void> _signIn(WidgetTester tester) async {
  final String session =
      '{"access_token":"a.b.c","token_type":"bearer","expires_in":3600,'
      '"expires_at":${DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000},'
      '"refresh_token":"r","user":{"id":"u1","aud":"authenticated",'
      '"app_metadata":{},"user_metadata":{},"created_at":"2026-01-01T00:00:00Z"}}';
  await tester.runAsync(() async {
    await Supabase.instance.client.auth.recoverSession(session);
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );
    await _loadFonts();
  });

  const List<Locale> locales = <Locale>[Locale('en'), Locale('ar')];
  String dirOf(Locale l) => l.languageCode == 'ar' ? 'rtl' : 'ltr';

  // Signed-out first: the session is set by the signed-in group below.
  for (final Locale locale in locales) {
    testWidgets('activities sign-in prompt — ${dirOf(locale)}', (tester) async {
      final _FakeFeed feed = _FakeFeed(ActivityFeedState());
      await _pump(
        tester,
        locale,
        const ActivitiesScreenV2(),
        overrides: _feedOverrides(feed),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sign in to view activities'), findsOneWidget);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      await _shoot(tester, 'activities-signed-out-${dirOf(locale)}');
    });
  }

  group('signed in', () {
    for (final Locale locale in locales) {
      final String dir = dirOf(locale);

      testWidgets('activities feed — $dir', (tester) async {
        await _signIn(tester);
        final _FakeFeed feed = _FakeFeed(
          ActivityFeedState(activities: _events(), hasMore: false),
        );
        await _pump(
          tester,
          locale,
          const ActivitiesScreenV2(),
          overrides: _feedOverrides(feed),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(DabblerActivityRow), findsNWidgets(5));
        expect(find.byType(DabblerChip), findsNWidgets(6));
        expect(find.text('You hosted a game'), findsOneWidget);
        expect(find.text('HOST'), findsOneWidget);
        expect(find.text('Upcoming'), findsOneWidget);
        expect(find.text('No more activities'), findsOneWidget);
        expect(feed.loads, 1, reason: 'initial load still requested');
        await _shoot(tester, 'activities-$dir');

        // Category chip drives changeCategory (behaviour kept).
        await tester.tap(find.text('Games (2)'));
        await _settle(tester);
        expect(feed.lastCategory, 'Games');
        expect(find.byType(DabblerActivityRow), findsNWidgets(2));
        await _shoot(tester, 'activities-filtered-$dir');
      });

      testWidgets('activities empty — $dir', (tester) async {
        await _signIn(tester);
        final _FakeFeed feed = _FakeFeed(ActivityFeedState());
        await _pump(
          tester,
          locale,
          const ActivitiesScreenV2(),
          overrides: _feedOverrides(feed),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('No activity yet'), findsOneWidget);
        expect(find.text('Find Sports Games'), findsOneWidget);
        await _shoot(tester, 'activities-empty-$dir');
      });

      testWidgets('activities error + loading — $dir', (tester) async {
        await _signIn(tester);
        final _FakeFeed feed = _FakeFeed(ActivityFeedState(error: 'boom'));
        await _pump(
          tester,
          locale,
          const ActivitiesScreenV2(),
          overrides: _feedOverrides(feed),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        await _shoot(tester, 'activities-error-$dir');
      });

      testWidgets('rewards screen — $dir', (tester) async {
        await _pump(tester, locale, const RewardsScreen());
        expect(tester.takeException(), isNull);
        expect(find.text('Rewards Screen - Under Construction'), findsOneWidget);
        await _shoot(tester, 'rewards-$dir');
      });

      testWidgets('check-in progress indicator — $dir', (tester) async {
        await _pump(
          tester,
          locale,
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CheckInProgressIndicator(completedDays: 3),
                  SizedBox(height: 24),
                  CheckInProgressIndicator(completedDays: 9),
                  SizedBox(height: 24),
                  CheckInProgressIndicator(completedDays: 14),
                  SizedBox(height: 24),
                  CompactCheckInProgressIndicator(completedDays: 5),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(DabblerProgressBar), findsNWidgets(1 + 2 + 2));
        expect(find.text('Week 2'), findsNWidgets(2));
        await _shoot(tester, 'check-in-progress-$dir');
      });

      testWidgets('early bird modal — $dir', (tester) async {
        int checkIns = 0;
        await _pump(
          tester,
          locale,
          Builder(
            builder: (context) => Center(
              child: DabblerButton(
                label: 'open',
                onPressed: () => EarlyBirdCheckInModal.show(
                  context,
                  currentDay: 9,
                  streakCount: 4,
                  daysRemaining: 5,
                  onCheckIn: () => checkIns++,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(DabblerDialog), findsOneWidget);
        expect(find.text('Welcome Back, Early Bird!'), findsOneWidget);
        expect(find.text('Day 9 of 14'), findsOneWidget);
        expect(find.text('4 Day Streak!'), findsOneWidget);
        expect(find.text('5 days left to unlock your badge'), findsOneWidget);
        await _shoot(tester, 'early-bird-modal-$dir');

        await tester.tap(find.text('Check In Now'));
        await _settle(tester);
        expect(checkIns, 1);
      });

      testWidgets('early bird modal completed — $dir', (tester) async {
        await _pump(
          tester,
          locale,
          Builder(
            builder: (context) => Center(
              child: DabblerButton(
                label: 'open',
                onPressed: () => EarlyBirdCheckInModal.show(
                  context,
                  currentDay: 14,
                  streakCount: 14,
                  daysRemaining: 0,
                  isCompleted: true,
                  onCheckIn: () {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Early Bird Badge Earned!'), findsOneWidget);
        await _shoot(tester, 'early-bird-modal-completed-$dir');

        await tester.tap(find.text('Awesome!'));
        await _settle(tester);
        expect(find.byType(DabblerDialog), findsNothing);
      });

      testWidgets('error page — $dir', (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final GoRouter router = GoRouter(
          initialLocation: '/boom',
          routes: <RouteBase>[
            GoRoute(
              path: '/boom',
              builder: (_, __) => const ErrorPage(message: 'Page not found'),
            ),
            GoRoute(
              path: '/home',
              builder: (_, __) => const Center(child: Text('home reached')),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            builder: (context, child) => DabblerToastProvider(
              child: RepaintBoundary(key: _key, child: child),
            ),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: _theme(locale),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Page not found'), findsOneWidget);
        await _shoot(tester, 'error-page-$dir');
        await tester.tap(find.text('Retry'));
        await _settle(tester);
        expect(find.text('home reached'), findsOneWidget);
      });

      testWidgets('placeholder screen — $dir', (tester) async {
        await _pump(tester, locale, const PlaceholderScreen(title: 'Chat List'));
        expect(tester.takeException(), isNull);
        await _shoot(tester, 'placeholder-$dir');
      });

      testWidgets('help centre — $dir', (tester) async {
        await _pump(tester, locale, const HelpCenterScreen());
        expect(tester.takeException(), isNull);
        await _shoot(tester, 'help-center-$dir');
      });
    }
  });
}

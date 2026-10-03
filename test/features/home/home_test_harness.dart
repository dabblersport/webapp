/// Shared harness for the Home presentation tests: every data source faked.
library;

import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/public_activity_providers.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart' show DabblerToastProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/render_mode.dart';

class FakeFeed extends StateNotifier<FeedState> implements FeedNotifier {
  FakeFeed(super.state);
  int loads = 0;
  @override
  Future<void> load() async => loads++;
  @override
  Future<void> loadMore() async {}
  @override
  void clearNewPostsBadge() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tab extends StateNotifier<TabFeedState> implements TabFeedNotifier {
  _Tab() : super(const TabFeedLoading());
  @override
  Future<void> load() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> ensureLoaded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Active extends StateNotifier<ActiveFeedState>
    implements ActiveFeedNotifier {
  _Active(super.state);
  @override
  Future<void> load() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> ensureLoaded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Acts extends StateNotifier<PublicActivitiesState>
    implements PublicActivitiesNotifier {
  _Acts() : super(const PublicActivitiesState());
  @override
  Future<void> load() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> ensureLoaded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _News extends StateNotifier<NewsTabState> implements NewsTabNotifier {
  _News() : super(const NewsTabState(isLoading: true));
  @override
  Future<void> load() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> ensureLoaded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile([super.state = const ProfileState()]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Location extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

/// Initialises Supabase once so [HomeScreen]'s AuthService field can be built.
Future<void> initHomeTestSupabase() async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://test.supabase.co',
    anonKey: 'test-anon-key',
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      autoRefreshToken: false,
    ),
  );
}

/// Pumps [HomeScreen] under the app's DS-wired theme with every data source
/// faked, so only presentation is exercised.
Future<({FakeFeed feed, List<String> pushed})> pumpHome(
  WidgetTester tester, {
  required FeedState feedState,
  ActiveFeedState activeState = const ActiveFeedLoading(),
  Locale locale = const Locale('en'),
  Key? boundaryKey,
  ProfileState profileState = const ProfileState(),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final feed = FakeFeed(feedState);
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
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
        feedNotifierProvider.overrideWith((ref) => feed),
        followingFeedProvider.overrideWith((ref) => _Tab()),
        nearbyFeedProvider.overrideWith((ref) => _Tab()),
        followingActivitiesProvider.overrideWith((ref) => _Acts()),
        activeFeedProvider.overrideWith((ref) => _Active(activeState)),
        newsTabFeedProvider.overrideWith((ref) => _News()),
        profileControllerProvider.overrideWith((ref) => _Profile(profileState)),
        unreadNotificationCountProvider.overrideWithValue(3),
        activeLocationProvider.overrideWith(_Location.new),
        hasLikedProvider.overrideWith((ref, id) async => false),
        hasRepostedProvider.overrideWith((ref, id) async => false),
        myReactionsProvider.overrideWith((ref, id) async => <String>{}),
        myProfileIdProvider.overrideWith((ref) async => 'someone-else'),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => []),
        latestCommentProvider.overrideWith((ref, id) async => null),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
        routerConfig: router,
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return (feed: feed, pushed: pushed);
}


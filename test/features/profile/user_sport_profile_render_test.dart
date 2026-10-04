import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile_badge.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile_tier.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile_event.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show PastGame;
import 'package:dabbler/features/games/providers/game_history_providers.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/controllers/sports_profile_controller.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profile_view_provider.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/sport_profile_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/user_profile_screen.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' hide Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

const String _shotsDir = String.fromEnvironment('PROFILE_SHOTS_DIR');
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
  if (_shotsDir.isEmpty) return;
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

class _FakeProfile extends StateNotifier<ProfileState>
    implements ProfileController {
  _FakeProfile(super.state);
  @override
  Future<void> loadProfile(
    String userId, {
    String? profileType,
    bool filterActive = true,
    String? profileId,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSports extends StateNotifier<SportsProfileState>
    implements SportsProfileController {
  _FakeSports() : super(const SportsProfileState());
  @override
  Future<void> loadSportsProfiles(String userId, {String? profileId}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _aisha() => UserProfile(
  id: 'p-aisha',
  userId: 'u-aisha',
  username: 'aisha_plays',
  displayName: 'Aisha Khan',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  bio: 'Padel 4.0, tennis when courts are free. Left-handed, sorry in advance.',
  age: 29,
  city: 'Dubai',
  country: 'UAE',
  personaType: 'player',
  preferredSport: 's-padel',
  interests: const ['s-padel', 's-tennis', 's-football'],
  lastSeen: DateTime.now(),
);

const List<Sport> _sports = [
  Sport(id: 's-padel', nameEn: 'Padel', sportKey: 'padel', emoji: '🎾'),
  Sport(id: 's-tennis', nameEn: 'Tennis', sportKey: 'tennis', emoji: '🎾'),
  Sport(id: 's-football', nameEn: 'Football', sportKey: 'football'),
];

Widget _app(Widget home, Locale locale, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => DabblerToastProvider(
        child: RepaintBoundary(key: _key, child: child),
      ),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        locale: locale,
      ),
      home: home,
    ),
  );
}

void Function(FlutterErrorDetails)? _origOnError;

/// The DS event card paints a sport's background PNG from
/// `assets/images/sports/<key>-main-background.png`; the DS ships none and the
/// app declares none (DS gap, reported). Only that one known report is ignored
/// here; everything else still fails.
void _ignoreMissingSportArt() {
  _origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('-main-background.png')) return;
    _origOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = _origOnError);
}

Future<void> _pumpUser(
  WidgetTester tester,
  Locale locale, {
  bool following = false,
  bool blocked = false,
  bool error = false,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(const UserProfileScreen(userId: 'u-aisha'), locale, [
      profileControllerProvider.overrideWith(
        (ref) => _FakeProfile(
          error
              ? const ProfileState(errorMessage: 'Profile not available')
              : ProfileState(profile: _aisha()),
        ),
      ),
      sportsProfileControllerProvider.overrideWith((ref) => _FakeSports()),
      currentUserProvider.overrideWithValue(null),
      myProfileIdProvider.overrideWith((ref) async => 'p-me'),
      sportsProvider.overrideWith((ref) async => _sports),
      sportProfileHeaderProvider.overrideWith((ref, key) async => null),
      followingCountProvider.overrideWith((ref, id) async => 312),
      followersCountProvider.overrideWith((ref, id) async => 1100),
      isFollowingProvider.overrideWith((ref, key) async => following),
      isBlockedProvider.overrideWith((ref, key) async => blocked),
      isUserBlockedProvider.overrideWith((ref, id) async => blocked),
      userPostsProvider.overrideWith((ref, key) async => []),
      userCommentedPostsProvider.overrideWith((ref, key) async => []),
      userLikedPostsProvider.overrideWith((ref, key) async => []),
      userRepostedPostsProvider.overrideWith((ref, key) async => []),
    ]),
  );
  await _settle(tester);
}

const SportProfileRouteArgs _args = SportProfileRouteArgs(
  profileId: 'p-aisha',
  userId: 'u-aisha',
  displayName: 'Aisha Khan',
  personaType: 'player',
  sportId: 's-padel',
  sportKey: 'padel',
  sportName: 'Padel',
);

Future<void> _pumpSport(
  WidgetTester tester,
  Locale locale, {
  bool empty = false,
  SportProfileRouteArgs args = _args,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _ignoreMissingSportArt();
  final games = <PastGame>[
    PastGame(
      id: 'g1',
      title: 'Padel doubles',
      sport: 'padel',
      scheduledDate: DateTime(2026, 10, 21),
      startTime: '20:30',
      endTime: '21:30',
      currentPlayers: 3,
      maxPlayers: 4,
      venueName: 'Reform Padel Club',
    ),
  ];
  final past = <PastGame>[
    PastGame(
      id: 'g0',
      title: 'Sunday ladder',
      sport: 'padel',
      scheduledDate: DateTime(2026, 9, 14),
      startTime: '07:00',
      endTime: '08:00',
      currentPlayers: 4,
      maxPlayers: 4,
    ),
  ];
  await tester.pumpWidget(
    _app(SportProfileScreen(args: args), locale, [
      sportProfileCoreProvider.overrideWith(
        (ref, a) async => SportProfileCoreData(
          playerProfile: empty
              ? null
              : const SportProfile(
                  profileId: 'profile-1',
                  sportKey: 'padel',
                  overallLevel: 1.0,
                ),
          playerTier: empty
              ? null
              : const SportProfileTier(id: 'tier-1', key: 'challenger'),
          metrics: empty
              ? const []
              : const [
                  SportProfileMetric(
                    label: 'Matches',
                    value: '86',
                  ),
                  SportProfileMetric(
                    label: 'Rating',
                    value: '4.9',
                  ),
                  SportProfileMetric(
                    label: 'Form',
                    value: '7.2',
                  ),
                  SportProfileMetric(
                    label: 'Reliability',
                    value: '99',
                  ),
                ],
        ),
      ),
      sportAchievementsProvider.overrideWith(
        (ref, a) async => SportAchievementsData(
          badges: empty
              ? const []
              : const [
                  SportProfileBadge(id: 'b1', key: 'streak', name: '5-win streak'),
                  SportProfileBadge(id: 'b2', key: 'regular', name: 'Regular'),
                ],
          recentEvents: empty
              ? const []
              : [
                  SportProfileEvent(
                    id: 'e1',
                    profileId: 'p-aisha',
                    sportKey: 'padel',
                    eventType: 'level_up',
                    eventData: const {'level': 4},
                    createdAt: DateTime(2026, 9, 1),
                  ),
                ],
        ),
      ),
      sportActivityProvider.overrideWith((ref, a) async => []),
      sportGameHistoryProvider.overrideWith(
        (ref, a) async => (
          upcoming: empty ? <PastGame>[] : games,
          past: empty ? <PastGame>[] : past,
        ),
      ),
    ]),
  );
  await _settle(tester);
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

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets("another user's profile renders — $dir", (tester) async {
      await _pumpUser(tester, locale);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerStatGrid), findsOneWidget);
      expect(find.byType(DabblerTabs), findsOneWidget);
      expect(find.byType(DabblerButton), findsWidgets);
      await _shoot(tester, 'user-profile-$dir');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'user-profile-scrolled-$dir');
    });

    testWidgets('follow states render — $dir', (tester) async {
      await _pumpUser(tester, locale, following: true);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'user-profile-friend-states-$dir');

      await _pumpUser(tester, locale, blocked: true);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'user-profile-blocked-$dir');
    });

    testWidgets('more menu and block dialog render — $dir', (tester) async {
      await _pumpUser(tester, locale);
      await tester.tap(find.bySemanticsLabel('More'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSheet), findsOneWidget);
      await _shoot(tester, 'user-profile-menu-$dir');
    });

    testWidgets('unavailable profile renders — $dir', (tester) async {
      await _pumpUser(tester, locale, error: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      await _shoot(tester, 'user-profile-unavailable-$dir');
    });

    testWidgets('sport profile tracker renders — $dir', (tester) async {
      await _pumpSport(tester, locale);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerStatTile), findsNWidgets(4));
      await _shoot(tester, 'sport-profile-$dir');

      await tester.tap(find.text('Achievements'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('5-win streak'), findsOneWidget);
      await _shoot(tester, 'sport-profile-achievements-$dir');

      await tester.tap(find.text('History'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerProfileRow), findsNWidgets(2));
      await _shoot(tester, 'sport-profile-history-$dir');
    });

    testWidgets('sport profile empty renders — $dir', (tester) async {
      await _pumpSport(tester, locale, empty: true);
      expect(tester.takeException(), isNull);
      expect(find.text('No scoreboard data yet.'), findsOneWidget);
      await _shoot(tester, 'sport-profile-empty-$dir');

      await tester.tap(find.text('Achievements'));
      await _settle(tester);
      expect(find.text('No sport achievements yet.'), findsOneWidget);

      await tester.tap(find.text('History'));
      await _settle(tester);
      expect(find.text('No games for this sport yet.'), findsOneWidget);
      await _shoot(tester, 'sport-profile-empty-history-$dir');
    });
  }

  // Last: it signs a fake session in, which would make every later sport
  // profile an own profile.
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    testWidgets('own sport profile shows preferences — $dir', (tester) async {
      await tester.runAsync(
        () => Supabase.instance.client.auth.recoverSession(
          _fakeSession('u-aisha'),
        ),
      );
      expect(Supabase.instance.client.auth.currentUser?.id, 'u-aisha');
      await _pumpSport(
        tester,
        locale,
        args: const SportProfileRouteArgs(
          profileId: 'p-aisha',
          userId: 'u-aisha',
          displayName: 'Aisha Khan',
          personaType: 'player',
          sportId: 's-football',
          sportKey: 'football',
          sportName: 'Football',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Goalkeeper'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await _settle(tester);
      await _shoot(tester, 'sport-profile-own-$dir');
      await tester.runAsync(() async {
        try {
          await Supabase.instance.client.auth.signOut(
            scope: SignOutScope.local,
          );
        } catch (_) {}
      });
    });
  }
}

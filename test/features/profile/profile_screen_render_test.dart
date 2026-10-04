import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/profile/profile_statistics.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/controllers/sports_profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/profile_screen.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/public_activity_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

const String _shotsDir = String.fromEnvironment(
  'PROFILE_SHOTS_DIR',
  defaultValue: '$kShotsRoot/profile',
);
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

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sports extends StateNotifier<SportsProfileState>
    implements SportsProfileController {
  _Sports(List<SportProfile> profiles)
    : super(SportsProfileState(profiles: profiles));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Persona extends PersonaServiceNotifier {
  _Persona(PersonaState initial) : super(Supabase.instance.client) {
    state = initial;
  }
  @override
  Future<void> fetchUserPersonas() async {}
}

class _Acts extends StateNotifier<PublicActivitiesState>
    implements PublicActivitiesNotifier {
  _Acts() : super(const PublicActivitiesState(loaded: true));
  @override
  Future<void> load() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> ensureLoaded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _profile(String persona, {String? name}) => UserProfile(
  id: 'profile-$persona',
  userId: 'user-1',
  username: 'moataz.m',
  displayName: name ?? 'Moataz Mustapha',
  bio: 'Five-a-side on Thursdays, padel when the courts are free.',
  age: 29,
  city: 'Dubai',
  personaType: persona,
  profileType: 'personal',
  primarySport: 'sport-football',
  preferredSport: 'sport-padel',
  interests: const ['sport-football', 'sport-padel', 'sport-basketball'],
  statistics: const ProfileStatistics(
    totalGamesPlayed: 99,
    totalHoursPlayed: 24.5,
    averageRating: 4.6,
  ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const List<Sport> _sports = [
  Sport(
    id: 'sport-football',
    nameEn: 'Football',
    sportKey: 'football',
    emoji: 'x',
  ),
  Sport(id: 'sport-padel', nameEn: 'Padel', sportKey: 'padel', emoji: 'x'),
  Sport(
    id: 'sport-basketball',
    nameEn: 'Basketball',
    sportKey: 'basketball',
    emoji: 'x',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required ProfileState profileState,
  Locale locale = const Locale('en'),
  bool takedown = false,
  bool postsError = false,
  PersonaState personaState = const PersonaState(),
  List<UserProfile> available = const [],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/:rest(.*)', builder: (_, __) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  Future<List<Post>> posts(Ref ref, ({String profileId, int page}) p) async {
    if (postsError) throw StateError('offline');
    return <Post>[];
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith((ref) => _Profile(profileState)),
        sportsProfileControllerProvider.overrideWith(
          (ref) => _Sports(
            profileState.profile?.personaType == 'player'
                ? const <SportProfile>[
                    SportProfile(
                      sportId: 'sport-football',
                      sportName: 'Football',
                      skillLevel: SkillLevel.advanced,
                      isPrimarySport: true,
                      gamesPlayed: 40,
                      averageRating: 4.6,
                    ),
                    SportProfile(
                      sportId: 'sport-padel',
                      sportName: 'Padel',
                      skillLevel: SkillLevel.advanced,
                      isPrimarySport: true,
                      gamesPlayed: 35,
                      averageRating: 4.6,
                    ),
                    SportProfile(
                      sportId: 'sport-basketball',
                      sportName: 'Basketball',
                      skillLevel: SkillLevel.intermediate,
                      isPrimarySport: true,
                      gamesPlayed: 24,
                      averageRating: 4.6,
                    ),
                  ]
                : const <SportProfile>[],
          ),
        ),
        profileTakedownProvider.overrideWith((ref, id) async => takedown),
        myPostsCountProvider.overrideWith((ref) async => 12),
        followingCountProvider.overrideWith((ref, id) async => 48),
        followersCountProvider.overrideWith((ref, id) async => 1204),
        sportsProvider.overrideWith((ref) async => _sports),
        userPostsProvider.overrideWith(posts),
        userCommentedPostsProvider.overrideWith(posts),
        userLikedPostsProvider.overrideWith(posts),
        userRepostedPostsProvider.overrideWith(posts),
        userActivitiesProvider.overrideWith((ref, id) => _Acts()),
        activeProfileTypeProvider.overrideWith(
          (ref) => profileState.profile?.personaType,
        ),
        availableProfilesProvider.overrideWith((ref) async => available),
        personaServiceProvider.overrideWith((ref) => _Persona(personaState)),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _key, child: child),
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
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    for (final String persona in const [
      'player',
      'organiser',
      'host',
      'socialiser',
    ]) {
      testWidgets('profile renders for $persona - $dir', (tester) async {
        await _pump(
          tester,
          locale: locale,
          profileState: ProfileState(profile: _profile(persona)),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(DabblerPage), findsOneWidget);
        expect(find.byType(DabblerTabs), findsOneWidget);
        expect(find.byType(DabblerAvatar), findsWidgets);
        await _shoot(tester, 'profile-$persona-$dir');
      });
    }

    testWidgets('profile loading - $dir', (tester) async {
      await _pump(tester, locale: locale, profileState: const ProfileState());
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSpinner), findsWidgets);
      await _shoot(tester, 'profile-loading-$dir');
    });

    testWidgets('profile posts error - $dir', (tester) async {
      await _pump(
        tester,
        locale: locale,
        postsError: true,
        profileState: ProfileState(profile: _profile('player')),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsWidgets);
      await _shoot(tester, 'profile-error-$dir');
    });

    testWidgets('profile takedown - $dir', (tester) async {
      await _pump(
        tester,
        locale: locale,
        takedown: true,
        profileState: ProfileState(profile: _profile('player')),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      await _shoot(tester, 'profile-takedown-$dir');
    });

    testWidgets('profile tabs switch - $dir', (tester) async {
      await _pump(
        tester,
        locale: locale,
        profileState: ProfileState(profile: _profile('player')),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileScreen)),
      );
      await tester.ensureVisible(find.text(l10n.profile_tab_activity));
      await tester.tap(find.text(l10n.profile_tab_activity));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.profile_empty_no_activity), findsOneWidget);
    });

    testWidgets('switch-profile sheet - $dir', (tester) async {
      final player = _profile('player');
      await _pump(
        tester,
        locale: locale,
        profileState: ProfileState(profile: player),
        available: [player],
        personaState: const PersonaState(
          activeProfiles: [
            ActivePersonaProfile(
              profileId: 'profile-player',
              personaType: PersonaType.player,
              displayName: 'Moataz Mustapha',
            ),
          ],
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileScreen)),
      );
      await tester.tap(
        find.bySemanticsLabel(l10n.profile_btn_manage_profiles_tooltip),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSheet), findsOneWidget);
      expect(find.text(l10n.profile_manage_profiles_title), findsWidgets);
      expect(find.text(l10n.profile_create_another_profile), findsOneWidget);
      await _shoot(tester, 'profile-switch-sheet-$dir');
    });
  }
}

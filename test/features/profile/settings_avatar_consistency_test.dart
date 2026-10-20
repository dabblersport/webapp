import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_screen.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_header.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';
import 'settings_test_overrides.dart';

UserProfile _profile(String name, {String? avatarUrl}) => UserProfile(
  id: 'profile-$name',
  userId: 'user-$name',
  username: name.toLowerCase(),
  displayName: name,
  avatarUrl: avatarUrl,
  age: 29,
  personaType: 'player',
  profileType: 'personal',
  interests: const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _app(UserProfile? profile, Widget home) => ProviderScope(
  key: ValueKey(profile?.id),
  overrides: [
    ...settingsDataOverrides(),
    currentUserProfileProvider.overrideWith((ref) => profile),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => DabblerToastProvider(child: child!),
    theme: DabblerDesignSystemTheme.withFonts(
      DabblerDesignSystemTheme.withTokens(renderThemeBase()),
      locale: const Locale('en'),
    ),
    home: home,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DabblerAvatar _settingsAvatar(WidgetTester tester) =>
    tester.widget<DabblerAvatar>(
      find
          .descendant(
            of: find.byType(DabblerInputRow),
            matching: find.byType(DabblerAvatar),
          )
          .first,
    );

DabblerAvatar _headerAvatar(WidgetTester tester) =>
    tester.widget<DabblerAvatar>(
      find.descendant(
        of: find.byType(OwnProfileHeader),
        matching: find.byType(DabblerAvatar),
      ),
    );

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await signInFakeUser();
    await loadRenderFonts();
  });

  Future<void> pumpBoth(WidgetTester tester, UserProfile? p) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(p, const SettingsScreen()));
    await _settle(tester);
    final s = _settingsAvatar(tester);
    await tester.pumpWidget(
      _app(
        p,
        Scaffold(
          body: OwnProfileHeader(
            profile: p,
            posts: 0,
            following: 0,
            followers: 0,
          ),
        ),
      ),
    );
    await _settle(tester);
    final h = _headerAvatar(tester);
    expect(s.imageUrl, h.imageUrl);
    expect(s.seed, h.seed);
  }

  testWidgets('with an image: Settings and Profile show the same avatar', (
    tester,
  ) async {
    await pumpBoth(tester, _profile('Aisha', avatarUrl: 'https://x/a.png'));
    expect(_headerAvatar(tester).imageUrl, 'https://x/a.png');
  });

  testWidgets('no image: both fall back to the same initials seed', (
    tester,
  ) async {
    await pumpBoth(tester, _profile('Aisha'));
    expect(_headerAvatar(tester).imageUrl, isNull);
    expect(_headerAvatar(tester).seed, 'Aisha');
  });

  testWidgets('no profile yet: both use the same neutral fallback', (
    tester,
  ) async {
    await pumpBoth(tester, null);
  });

  testWidgets('switching to another account shows only that account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        _profile('Aisha', avatarUrl: 'https://x/a.png'),
        const SettingsScreen(),
      ),
    );
    await _settle(tester);
    expect(_settingsAvatar(tester).imageUrl, 'https://x/a.png');
    await tester.pumpWidget(
      _app(
        _profile('Omar', avatarUrl: 'https://x/o.png'),
        const SettingsScreen(),
      ),
    );
    await _settle(tester);
    expect(_settingsAvatar(tester).imageUrl, 'https://x/o.png');
    expect(_settingsAvatar(tester).seed, 'Omar');
  });
}

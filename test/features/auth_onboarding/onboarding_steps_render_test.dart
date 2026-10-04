import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/create_user_information.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/intent_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/interests_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/primary_sport_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/set_username_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_friends_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_privacy_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_notifications_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_complete_screen.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/username_engine/providers.dart';
import 'package:dabbler/data/repositories/username_repository.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders onboarding steps 1-5 (A11-A15) on the design system in LTR and
/// RTL, and writes PNGs to the Alpha plan folder.
const String _shotsDir = '$kShotsRoot/auth2';

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

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    await Directory(_shotsDir).create(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const List<Sport> _sports = <Sport>[
  Sport(id: '1', nameEn: 'Football', nameAr: 'كرة القدم', sportKey: 'football'),
  Sport(id: '2', nameEn: 'Padel', nameAr: 'بادل', sportKey: 'padel'),
  Sport(id: '3', nameEn: 'Tennis', nameAr: 'تنس', sportKey: 'tennis'),
  Sport(
    id: '4',
    nameEn: 'Basketball',
    nameAr: 'كرة السلة',
    sportKey: 'basketball',
  ),
  Sport(
    id: '5',
    nameEn: 'Table Tennis',
    nameAr: 'تنس الطاولة',
    sportKey: 'table_tennis',
  ),
  Sport(id: '6', nameEn: 'Handball', nameAr: 'كرة اليد', sportKey: 'handball'),
  Sport(id: '7', nameEn: 'Squash', nameAr: 'سكواش', sportKey: 'squash'),
  Sport(id: '8', nameEn: 'Rugby', nameAr: 'رغبي', sportKey: 'rugby'),
  Sport(id: '9', nameEn: 'Hockey', nameAr: 'هوكي', sportKey: 'hockey'),
  Sport(id: '10', nameEn: 'Baseball', nameAr: 'بيسبول', sportKey: 'baseball'),
  Sport(id: '11', nameEn: 'Yoga', nameAr: 'يوغا', sportKey: 'yoga'),
  Sport(id: '12', nameEn: 'Cricket', nameAr: 'كريكيت', sportKey: 'cricket'),
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale,
  Key key,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      sportsForSelectedCountryProvider.overrideWith((ref) async => _sports),
      usernameRepositoryProvider.overrideWithValue(_FakeUsernames()),
    ],
  );
  addTearDown(container.dispose);
  container.read(onboardingDataProvider.notifier)
    ..initWithEmail('aisha@example.com')
    ..setIntention('player')
    ..setSports(preferredSport: '1', interests: <String>['1', '2', '4']);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
        home: screen,
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Answers the availability RPC: `marcus` is taken, everything else is free.
class _FakeUsernames implements UsernameRepository {
  @override
  Future<
    Result<({bool available, String reason, String usernameNorm}), Failure>
  >
  checkAvailabilityRpc(String username) async =>
      Ok((available: username != 'marcus', reason: '', usernameNorm: username));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  const Key key = Key('shot');

  Future<void> pickDate(
    WidgetTester tester, {
    required String day,
    required String month,
    required String year,
  }) async {
    await tester.tap(find.byType(DabblerTextField));
    await _settle(tester);
    await tester.tap(find.text(day).first);
    await tester.tap(find.text(month).first);
    await tester.tap(find.text(year).first);
    await _settle(tester);
  }

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final bool ar = locale.languageCode == 'ar';

    testWidgets('step 1 empty — $dir', (tester) async {
      await _pump(
        tester,
        const CreateUserInformation(email: 'aisha@example.com', forceNew: true),
        locale,
        key,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerFlowPage), findsOneWidget);
      expect(find.byType(DabblerTextField), findsOneWidget);
      expect(find.byType(DabblerSelectableCard), findsNWidgets(2));
      await _shoot(tester, key, 'step1-empty-$dir');
    }, variant: desktop);

    testWidgets('step 1 date sheet — $dir', (tester) async {
      await _pump(
        tester,
        const CreateUserInformation(email: 'aisha@example.com', forceNew: true),
        locale,
        key,
      );
      await tester.tap(find.byType(DabblerTextField));
      await _settle(tester);
      expect(find.byType(DabblerDateColumns), findsOneWidget);
      await _shoot(tester, key, 'step1-dob-sheet-$dir');
    }, variant: desktop);

    testWidgets('step 1 filled — $dir', (tester) async {
      await _pump(
        tester,
        const CreateUserInformation(email: 'aisha@example.com', forceNew: true),
        locale,
        key,
      );
      await pickDate(
        tester,
        day: '3',
        month: ar ? 'مارس' : 'March',
        year: '2010',
      );
      await tester.tap(find.text(ar ? 'تأكيد' : 'Confirm'));
      await _settle(tester);
      await tester.tap(find.text(ar ? 'ذكر' : 'Male'));
      await _settle(tester);
      await _shoot(tester, key, 'step1-filled-$dir');
    }, variant: desktop);

    testWidgets('step 1 under 16 — $dir', (tester) async {
      await _pump(
        tester,
        const CreateUserInformation(email: 'aisha@example.com', forceNew: true),
        locale,
        key,
      );
      await pickDate(
        tester,
        day: '3',
        month: ar ? 'مارس' : 'March',
        year: '2012',
      );
      await tester.tap(find.text(ar ? 'تأكيد' : 'Confirm'));
      await _settle(tester);
      expect(find.byType(DabblerBanner), findsOneWidget);
      await _shoot(tester, key, 'step1-underage-$dir');
    }, variant: desktop);

    testWidgets('step 2 persona — $dir', (tester) async {
      await _pump(tester, const IntentSelectionScreen(), locale, key);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(ar ? 'انزل الملعب' : 'Get in the game'));
      await _settle(tester);
      expect(find.byType(DabblerSelectableCard), findsNWidgets(2));
      await _shoot(tester, key, 'step2-$dir');
    }, variant: desktop);

    testWidgets('step 3 sports — $dir', (tester) async {
      await _pump(tester, const InterestsSelectionScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSearchField), findsOneWidget);
      expect(find.byType(DabblerSelectableCard), findsNWidgets(12));
      await tester.tap(find.byType(DabblerSelectableCard).at(0));
      await tester.tap(find.byType(DabblerSelectableCard).at(1));
      await _settle(tester);
      await _shoot(tester, key, 'step3-$dir');
    }, variant: desktop);

    testWidgets('step 3 no match — $dir', (tester) async {
      await _pump(tester, const InterestsSelectionScreen(), locale, key);
      await tester.enterText(find.byType(EditableText).first, 'zzz');
      await _settle(tester);
      expect(find.byType(DabblerSelectableCard), findsNothing);
      await _shoot(tester, key, 'step3-none-$dir');
    }, variant: desktop);

    testWidgets('step 4 primary sport — $dir', (tester) async {
      await _pump(tester, const PrimarySportSelectionScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSelectableCard), findsNWidgets(3));
      await tester.tap(find.byType(DabblerSelectableCard).first);
      await _settle(tester);
      await _shoot(tester, key, 'step4-$dir');
    }, variant: desktop);

    testWidgets('step 5 empty — $dir', (tester) async {
      await _pump(tester, const SetUsernameScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTextField), findsNWidgets(2));
      await _shoot(tester, key, 'step5-empty-$dir');
    }, variant: desktop);

    testWidgets('step 5 available — $dir', (tester) async {
      await _pump(tester, const SetUsernameScreen(), locale, key);
      await tester.enterText(find.byType(EditableText).at(0), 'Marcus Adeyemi');
      await tester.enterText(
        find.byType(EditableText).at(1),
        'marcus_football',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 900)),
      );
      await _settle(tester);
      await _shoot(tester, key, 'step5-available-$dir');
    }, variant: desktop);

    testWidgets('step 5 taken — $dir', (tester) async {
      await _pump(tester, const SetUsernameScreen(), locale, key);
      await tester.enterText(find.byType(EditableText).at(0), 'Marcus Adeyemi');
      await tester.enterText(find.byType(EditableText).at(1), 'marcus');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 900)),
      );
      await _settle(tester);
      await _shoot(tester, key, 'step5-taken-$dir');
    }, variant: desktop);

    testWidgets('setup progress — $dir', (tester) async {
      await _pump(tester, const ProfileOnboardingWelcomeScreen(), locale, key);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await _settle(tester);
      expect(find.byType(DabblerProgressStages), findsOneWidget);
      await _shoot(tester, key, 'setup-$dir');
    }, variant: desktop);

    testWidgets('persona welcome — $dir', (tester) async {
      DabblerSportBackgroundRegistry.registerConventionalMainArtwork(
        DabblerSportBackgroundRegistry.mainPopulated,
        DabblerSportBackgroundRegistry.assetPackage,
      );
      await _pump(
        tester,
        const WelcomeScreen(
          displayName: 'Marcus Adeyemi',
          personaType: 'player',
          primarySportKey: 'football',
        ),
        locale,
        key,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await _settle(tester);
      expect(find.byType(DabblerIconList), findsOneWidget);
      await _shoot(tester, key, 'welcome-$dir');
    }, variant: desktop);

    for (final entry in <String, Widget>{
      'social-welcome': const SocialOnboardingWelcomeScreen(),
      'social-friends': const SocialOnboardingFriendsScreen(),
      'social-privacy': const SocialOnboardingPrivacyScreen(),
      'social-notifications': const SocialOnboardingNotificationsScreen(),
      'social-complete': const SocialOnboardingCompleteScreen(),
    }.entries) {
      testWidgets('${entry.key} — $dir', (tester) async {
        await _pump(tester, entry.value, locale, key);
        expect(tester.takeException(), isNull);
        expect(find.byType(DabblerFlowPage), findsOneWidget);
        await _shoot(tester, key, '${entry.key}-$dir');
      }, variant: desktop);
    }
  }
}

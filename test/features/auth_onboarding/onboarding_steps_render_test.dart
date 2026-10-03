import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/create_user_information.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/intent_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/interests_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/primary_sport_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/set_username_screen.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
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
const String _shotsDir = '/Users/moataz/Desktop/Dabbler-Alpha-Plan/auth';

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
  Sport(id: '4', nameEn: 'Basketball', nameAr: 'كرة السلة', sportKey: 'basketball'),
  Sport(id: '5', nameEn: 'Table Tennis', nameAr: 'تنس الطاولة', sportKey: 'table_tennis'),
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

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  const Key key = Key('shot');

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('step 1 create user info — $dir', (tester) async {
      await _pump(
        tester,
        const CreateUserInformation(email: 'aisha@example.com', forceNew: true),
        locale,
        key,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTextField), findsOneWidget);
      await tester.tap(find.text('Female'));
      await _settle(tester);
      await _shoot(tester, key, 'create-user-info-$dir');
    }, variant: desktop);

    testWidgets('step 2 intent — $dir', (tester) async {
      await _pump(tester, const IntentSelectionScreen(), locale, key);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Compete'));
      await _settle(tester);
      expect(find.byType(DabblerIcon), findsWidgets);
      await _shoot(tester, key, 'intent-$dir');
    }, variant: desktop);

    testWidgets('step 3 interests — $dir', (tester) async {
      await _pump(tester, const InterestsSelectionScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSearchField), findsOneWidget);
      expect(find.byType(DabblerSportIcon), findsNWidgets(11));
      await tester.tap(find.byType(DabblerSportIcon).at(0));
      await tester.tap(find.byType(DabblerSportIcon).at(1));
      await _settle(tester);
      await _shoot(tester, key, 'interests-$dir');
    }, variant: desktop);

    testWidgets('step 4 primary sport — $dir', (tester) async {
      await _pump(tester, const PrimarySportSelectionScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSportIcon), findsNWidgets(3));
      await tester.tap(find.byType(DabblerSportIcon).first);
      await _settle(tester);
      await _shoot(tester, key, 'primary-sport-$dir');
    }, variant: desktop);

    testWidgets('step 5 username — $dir', (tester) async {
      await _pump(tester, const SetUsernameScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTextField), findsNWidgets(2));
      await _shoot(tester, key, 'username-$dir');
    }, variant: desktop);
  }
}

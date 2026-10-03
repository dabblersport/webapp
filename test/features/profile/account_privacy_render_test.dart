import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';

import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/profile/presentation/controllers/privacy_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/account_management_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_settings_screen.dart';
import 'package:dabbler/features/social/block_providers.dart';
import '../../support/render_mode.dart';

/// Writes PNGs only with `--dart-define=SETTINGS_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  Locale locale,
  Key key, {
  List<Override> overrides = const [],
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _loadFonts() async {
  final String dsFonts = '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.sublistView(b)),
      );
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
    final FontLoader loader = FontLoader('packages/iconsax_flutter/FlutterIconsax')
      ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}



class _FakePrivacy extends PrivacyController {
  _FakePrivacy(PrivacyState initial) {
    state = initial;
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  const tall = Size(393, 1400);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('account screen (no session) — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const AccountManagementScreen(), locale, key,
          size: tall);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Account Management'), findsOneWidget);
      await _shoot(tester, key, 'account-default-$dir');
    });

    testWidgets('account pieces — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(
        tester,
        DabblerPage(
          body: ListView(
            padding: const EdgeInsets.all(DabblerSpacing.space6),
            children: [
              const AccountSecurityIntro(),
              const SizedBox(height: DabblerSpacing.space7),
              AccountDangerZone(onDelete: () {}),
            ],
          ),
        ),
        locale,
        key,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Delete Account'), findsOneWidget);
      await _shoot(tester, key, 'account-pieces-$dir');
    });

    testWidgets('account delete dialog — $dir', (tester) async {
      const Key key = Key('shot');
      final c = TextEditingController();
      addTearDown(c.dispose);
      await _pump(
        tester,
        DabblerDialog(
          title: 'Delete Account',
          destructive: true,
          secondaryAction: const DabblerDialogAction(label: 'Cancel'),
          primaryAction:
              DabblerDialogAction(label: 'Delete Account', onPressed: () {}),
          child: DeleteAccountDialogContent(confirmController: c, enabled: true),
        ),
        locale,
        key,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTextField), findsOneWidget);
      await _shoot(tester, key, 'account-delete-dialog-$dir');
    });

    testWidgets('account delete dialog deleting — $dir', (tester) async {
      const Key key = Key('shot');
      final c = TextEditingController(text: 'DELETE');
      addTearDown(c.dispose);
      await _pump(
        tester,
        DabblerDialog(
          title: 'Delete Account',
          destructive: true,
          secondaryAction: const DabblerDialogAction(label: 'Cancel'),
          primaryAction: DabblerDialogAction(
            label: 'Delete Account',
            loading: true,
            onPressed: () {},
          ),
          child: DeleteAccountDialogContent(
            confirmController: c,
            enabled: false,
          ),
        ),
        locale,
        key,
      );
      expect(tester.takeException(), isNull);
      // The primary button carries the spinner while the account is deleted.
      expect(find.byType(DabblerSpinner), findsOneWidget);
      await _shoot(tester, key, 'account-delete-dialog-deleting-$dir');
    });

    final privacyStates = <String, (PrivacyState, List<Map<String, dynamic>>)>{
      'loading': (const PrivacyState(isLoading: true), const []),
      'default': (const PrivacyState(settings: PrivacySettings()), const []),
      'blocked': (
        const PrivacyState(
          settings: PrivacySettings(
            profileVisibility: ProfileVisibility.friends,
          ),
        ),
        const [
          {'user_id': 'b1', 'display_name': 'Khalid Saeed', 'username': 'khalid'},
          {'user_id': 'b2', 'display_name': 'Mona', 'username': ''},
        ],
      ),
    };

    for (final entry in privacyStates.entries) {
      testWidgets('privacy settings ${entry.key} — $dir', (tester) async {
        const Key key = Key('shot');
        await _pump(
          tester,
          const PrivacySettingsScreen(),
          locale,
          key,
          size: const Size(393, 5200),
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            privacyControllerProvider
                .overrideWith((ref) => _FakePrivacy(entry.value.$1)),
            blockedUsersWithProfilesProvider
                .overrideWith((ref) async => entry.value.$2),
          ],
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Privacy Settings'), findsOneWidget);
        if (entry.key == 'loading') {
          expect(find.byType(DabblerSpinner), findsOneWidget);
        } else {
          expect(find.text('Privacy Presets'), findsOneWidget);
          expect(find.byType(DabblerToggle), findsWidgets);
        }
        if (entry.key == 'blocked') {
          expect(find.text('Khalid Saeed'), findsOneWidget);
          expect(find.text('Unblock'), findsNWidgets(2));
        }
        await _shoot(tester, key, 'privacy-${entry.key}-$dir');
      });
    }

    testWidgets('privacy settings preference sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(
        tester,
        const PrivacySettingsScreen(),
        locale,
        key,
        size: const Size(393, 1600),
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          privacyControllerProvider.overrideWith(
            (ref) => _FakePrivacy(
              const PrivacyState(settings: PrivacySettings()),
            ),
          ),
          blockedUsersWithProfilesProvider.overrideWith((ref) async => []),
        ],
      );
      await tester.tap(find.text('Direct Messages'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerRadio), findsWidgets);
      await _shoot(tester, key, 'privacy-preference-sheet-$dir');
    });
  }
}

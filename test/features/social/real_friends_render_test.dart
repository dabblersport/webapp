import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/screens/real_friends_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';

/// Renders the community list (followers tab with rows, empty) LTR and RTL.
/// `--dart-define=SOCIAL_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('SOCIAL_SHOTS_DIR');

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
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const List<Map<String, dynamic>> _followers = <Map<String, dynamic>>[
  {'id': 'p1', 'user_id': 'u1', 'display_name': 'Layla Hassan', 'username': 'layla', 'verified': true},
  {'id': 'p2', 'user_id': 'u2', 'display_name': 'Omar Saeed', 'username': 'omar'},
  {'id': 'me', 'user_id': 'u0', 'display_name': 'Me', 'username': 'me'},
];

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> followers,
  Locale locale,
  Key key,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        followersListProvider.overrideWith((ref, id) async => followers),
        followingListProvider.overrideWith((ref, id) async => const []),
        isFollowingProvider.overrideWith((ref, p) async => p.targetProfileId == 'p1'),
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
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
          locale: locale,
        ),
        home: const RealFriendsScreen(initialTab: 1),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('followers tab with rows — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, _followers, locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTabs), findsOneWidget);
      expect(find.byType(DabblerSearchField), findsOneWidget);
      expect(find.byType(DabblerInputRow), findsNWidgets(3));
      expect(find.text('Unfollow'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      await _shoot(tester, key, 'friends-followers-$dir');
    }, variant: desktop);

    testWidgets('followers tab empty — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const [], locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      expect(find.text('No followers yet'), findsOneWidget);
      await _shoot(tester, key, 'friends-empty-$dir');
    }, variant: desktop);
  }
}

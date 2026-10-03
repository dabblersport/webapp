import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/profile/presentation/screens/about/licenses_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/about/privacy_policy_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/about/terms_of_service_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/support/bug_report_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/support/contact_support_screen.dart';
import 'package:dabbler/widgets/legal_doc_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the DS legal and support screens (terms, privacy policy, licenses, contact support, bug report) and the legal doc sheet. Contact support and bug report have no design frame: DS-default. Writes PNGs only with
/// `--dart-define=SETTINGS_SHOTS_DIR=<dir>`; otherwise it still pumps every
/// state LTR and RTL and checks it renders cleanly.
const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

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



const Key _shotKey = Key('shot');

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale, {
  double height = 852,
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _shotKey, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
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
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}


class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context) => DabblerPage(
    body: Center(
      child: DabblerButton(
        label: 'open',
        onPressed: () => showTermsSheet(context),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('terms of service — $dir', (tester) async {
      await _pump(tester, const TermsOfServiceScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.byType(DabblerNavigationTopBar), findsOneWidget);
      await _shoot(tester, _shotKey, 'terms-default-$dir');
    });

    testWidgets('privacy policy — $dir', (tester) async {
      await _pump(tester, const PrivacyPolicyScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.bySemanticsLabel('Privacy Settings'), findsWidgets);
      await _shoot(tester, _shotKey, 'privacy-policy-default-$dir');
    });

    testWidgets('licenses list, empty search, detail, info — $dir', (
      tester,
    ) async {
      await _pump(tester, const LicensesScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerInputRow), findsNWidgets(7));
      await _shoot(tester, _shotKey, 'licenses-list-$dir');

      await _tap(tester, find.text('Riverpod'));
      expect(tester.takeException(), isNull);
      expect(find.text('View on Web'), findsOneWidget);
      await _shoot(tester, _shotKey, 'licenses-detail-$dir');
      Navigator.of(tester.element(find.text('View on Web'))).pop();
      await _settle(tester);

      await tester.tap(find.bySemanticsLabel('About Licenses'));
      await _settle(tester);
      expect(find.text('About Open Source Licenses'), findsOneWidget);
      await _shoot(tester, _shotKey, 'licenses-info-$dir');
      await tester.tap(find.text('Got it'));
      await _settle(tester);

      await tester.enterText(find.byType(EditableText), 'zzzz');
      await _settle(tester);
      expect(find.text('No licenses found'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shoot(tester, _shotKey, 'licenses-empty-$dir');
    });

    testWidgets('contact support default and errors — $dir', (tester) async {
      await _pump(tester, const ContactSupportScreen(), locale, height: 1300);
      expect(tester.takeException(), isNull);
      expect(find.text('How can we help?'), findsOneWidget);
      await _shoot(tester, _shotKey, 'contact-support-default-$dir');
      await _tap(tester, find.text('Send Message'));
      expect(tester.takeException(), isNull);
      expect(find.text('Please enter a subject'), findsOneWidget);
      expect(find.text('Please enter your message'), findsOneWidget);
      await _shoot(tester, _shotKey, 'contact-support-errors-$dir');
    });

    testWidgets('bug report default and errors — $dir', (tester) async {
      await _pump(tester, const BugReportScreen(), locale, height: 1900);
      expect(tester.takeException(), isNull);
      expect(find.text('Found a Bug?'), findsOneWidget);
      expect(find.byType(DabblerToggle), findsNWidgets(2));
      expect(find.text('Device Information to Include:'), findsOneWidget);
      await _shoot(tester, _shotKey, 'bug-report-default-$dir');
      await _tap(tester, find.text('Include Device Information'));
      expect(find.text('Device Information to Include:'), findsNothing);
      await _tap(tester, find.text('Submit Bug Report'));
      expect(tester.takeException(), isNull);
      expect(find.text('Please enter a bug title'), findsOneWidget);
      expect(find.text('Please describe the bug'), findsOneWidget);
      expect(
        find.text('Please provide steps to reproduce the bug'),
        findsOneWidget,
      );
      await _shoot(tester, _shotKey, 'bug-report-errors-$dir');
    });

    testWidgets('legal doc sheet — $dir', (tester) async {
      await _pump(tester, const _SheetLauncher(), locale);
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('1. Acceptance of Terms'), findsWidgets);
      await _shoot(tester, _shotKey, 'legal-sheet-terms-$dir');
    });
  }
}

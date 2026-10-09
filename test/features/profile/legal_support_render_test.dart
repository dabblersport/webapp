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
import '../../support/render_mode.dart';

/// Renders the DS legal and support screens (terms, privacy policy, licenses, contact support, bug report) and the legal doc sheet. Contact support and bug report have no design frame: DS-default. Writes PNGs only with
/// `--dart-define=SETTINGS_SHOTS_DIR=<dir>`; otherwise it still pumps every
/// state LTR and RTL and checks it renders cleanly.
const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

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
  setUpAll(loadRenderFonts);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final AppLocalizations l10n = lookupAppLocalizations(locale);

    testWidgets('terms of service — $dir', (tester) async {
      await _pump(tester, const TermsOfServiceScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settings_item_terms_title), findsOneWidget);
      expect(find.byType(DabblerNavigationTopBar), findsOneWidget);
      await _shoot(tester, _shotKey, 'terms-default-$dir');
    });

    testWidgets('privacy policy — $dir', (tester) async {
      await _pump(tester, const PrivacyPolicyScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settings_item_privacy_policy_title), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.about_privacy_settings_tooltip), findsWidgets);
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
      expect(find.text(l10n.licenses_view_web), findsOneWidget);
      await _shoot(tester, _shotKey, 'licenses-detail-$dir');
      Navigator.of(tester.element(find.text(l10n.licenses_view_web))).pop();
      await _settle(tester);

      await tester.tap(find.bySemanticsLabel(l10n.licenses_about_tooltip));
      await _settle(tester);
      expect(find.text(l10n.licenses_info_title), findsOneWidget);
      await _shoot(tester, _shotKey, 'licenses-info-$dir');
      await tester.tap(find.text(l10n.licenses_got_it));
      await _settle(tester);

      await tester.enterText(find.byType(EditableText), 'zzzz');
      await _settle(tester);
      expect(find.text(l10n.licenses_empty_title), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shoot(tester, _shotKey, 'licenses-empty-$dir');
    });

    testWidgets('contact support default and errors — $dir', (tester) async {
      await _pump(tester, const ContactSupportScreen(), locale, height: 1300);
      expect(tester.takeException(), isNull);
      await _shoot(tester, _shotKey, 'contact-support-default-$dir');
      await _tap(tester, find.text(l10n.contact_send));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.contact_err_subject_required), findsOneWidget);
      expect(find.text(l10n.contact_err_message_required), findsOneWidget);
      // Validation runs through a Form (DabblerTextField.validator), as the
      // original TextFormFields did.
      expect(find.byType(Form), findsOneWidget);
      await _shoot(tester, _shotKey, 'contact-support-errors-$dir');
    });

    testWidgets('bug report default and errors — $dir', (tester) async {
      await _pump(tester, const BugReportScreen(), locale, height: 1900);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerToggle), findsNWidgets(2));
      expect(find.text(l10n.bug_device_heading), findsOneWidget);
      await _shoot(tester, _shotKey, 'bug-report-default-$dir');
      await _tap(tester, find.text(l10n.bug_include_device));
      expect(find.text(l10n.bug_device_heading), findsNothing);
      await _tap(tester, find.text(l10n.bug_submit));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.bug_err_title_required), findsOneWidget);
      expect(find.text(l10n.bug_err_description_required), findsOneWidget);
      expect(
        find.text(l10n.bug_err_steps_required),
        findsOneWidget,
      );
      expect(find.byType(Form), findsOneWidget);
      await _shoot(tester, _shotKey, 'bug-report-errors-$dir');
    });

    testWidgets('legal doc sheet — $dir', (tester) async {
      await _pump(tester, const _SheetLauncher(), locale);
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settings_item_terms_title), findsOneWidget);
      expect(find.text('1. Acceptance of Terms'), findsWidgets);
      await _shoot(tester, _shotKey, 'legal-sheet-terms-$dir');
    });
  }
}

import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-481: the Create Post body counter's screen-reader label reads from the
/// `composer_counter_semantic` ARB key, in both languages; the visible counter
/// stays `N/2000`.
Future<void> _pump(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [vibesProvider.overrideWith((ref) async => const <Vibe>[])],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: const DabblerPage(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PostComposerScreen(),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _label(WidgetTester tester) => tester
    .widget<DabblerComposerBox>(find.byType(DabblerComposerBox))
    .counterSemanticLabel!;

String _counter(WidgetTester tester) =>
    tester.widget<DabblerComposerBox>(find.byType(DabblerComposerBox)).counter!;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  testWidgets('counter semantic label, English: "N of M characters used"', (
    tester,
  ) async {
    await _pump(tester, const Locale('en'));
    expect(_label(tester), '0 of 2000 characters used');
    expect(_counter(tester), '0/2000');
    await tester.enterText(find.byType(EditableText).first, 'Hello');
    await tester.pump();
    expect(_label(tester), '5 of 2000 characters used');
    expect(_counter(tester), '5/2000');
  });

  testWidgets('counter semantic label, Arabic: Arabic words, same numbers', (
    tester,
  ) async {
    await _pump(tester, const Locale('ar'));
    final l = lookupAppLocalizations(const Locale('ar'));
    expect(_label(tester), l.composer_counter_semantic(0, 2000));
    expect(_label(tester), 'الأحرف المستخدمة: 0 من 2000');
    expect(_label(tester), isNot(contains('characters')));
    await tester.enterText(find.byType(EditableText).first, 'مرحبا');
    await tester.pump();
    expect(_label(tester), 'الأحرف المستخدمة: 5 من 2000');
    // The visible counter is unchanged by the locale.
    expect(_counter(tester), '5/2000');
  });
}

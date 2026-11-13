import 'package:dabbler/core/widgets/bootstrap_error_app.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-196 regression coverage. main()'s bootstrap catch block used to
// `rethrow` in debug mode (silent on web/iOS -- the throw propagates out of
// runZonedGuarded into its onError handler, which only prints, so runApp()
// is never called and the user is left on a blank page/stuck splash) or, in
// release, fall back to running the real MyApp() tree without its
// dependencies initialized -- which threw again deeper with nothing
// rendered either. This asserts the actual fix: a bootstrap failure always
// produces a real, visible widget tree, never a blank page and never a
// silent rethrow.
void main() {
  testWidgets(
    'BootstrapErrorApp renders the failure message instead of a blank screen',
    (tester) async {
      await tester.pumpWidget(
        BootstrapErrorApp(
          error: Exception(
            'Missing environment variables: SUPABASE_URL, SUPABASE_ANON_KEY, APP_NAME',
          ),
          stackTrace: StackTrace.current,
        ),
      );
      await tester.pumpAndSettle();

      // The screen is never blank: a real MaterialApp host and a design-system
      // page mounted.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(DabblerPage), findsOneWidget);
      expect(find.byType(Scaffold), findsNothing);

      // KAN-603: a localized generic message, never the raw error text (it is
      // logged by main(), not shown).
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l.bootstrap_error_title), findsOneWidget);
      expect(find.text(l.bootstrap_error_message), findsOneWidget);
      expect(
        find.textContaining('Missing environment variables'),
        findsNothing,
      );
      expect(find.textContaining('SUPABASE_URL'), findsNothing);
    },
  );

  testWidgets('BootstrapErrorApp renders without a stack trace too', (
    tester,
  ) async {
    // main() always has a stack trace in practice (it's caught from a
    // try/catch), but the widget itself must not assume one is present --
    // stackTrace is nullable on the public API.
    await tester.pumpWidget(BootstrapErrorApp(error: 'network unreachable'));
    await tester.pumpAndSettle();

    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.bootstrap_error_title), findsOneWidget);
    expect(find.textContaining('network unreachable'), findsNothing);
  });

  testWidgets('the message is Arabic on an Arabic device', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(BootstrapErrorApp(error: 'secret detail 12345'));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l.bootstrap_error_title), findsOneWidget);
    expect(find.text(l.bootstrap_error_message), findsOneWidget);
    expect(find.textContaining('secret detail'), findsNothing);
  });
}

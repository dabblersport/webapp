import 'package:dabbler/core/widgets/bootstrap_error_app.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart' show DabblerPage;
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

      // The actual bootstrap error is surfaced on screen, not just printed
      // to a console nobody watching the device can see.
      expect(find.text('Dabbler failed to start'), findsOneWidget);
      expect(
        find.textContaining('Missing environment variables'),
        findsOneWidget,
      );
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

    expect(find.text('Dabbler failed to start'), findsOneWidget);
    expect(find.textContaining('network unreachable'), findsOneWidget);
  });
}

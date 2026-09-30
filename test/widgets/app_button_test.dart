import 'package:dabbler/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-368: AppButton (231 lines, four named constructors) had zero automated
// coverage despite being used in the auth/onboarding flow. This covers the
// label render, the tap-invokes-callback path, the loading state suppressing
// both the label and the tap, and the disabled-on-null-callback state.
void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders the label text', (tester) async {
    await tester.pumpWidget(
      wrap(AppButton.primary(label: 'Continue', onPressed: () {})),
    );

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets(
    'tapping invokes onPressed exactly once when not loading',
    (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        wrap(
          AppButton.primary(
            label: 'Continue',
            onPressed: () => callCount++,
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(callCount, 1);
    },
  );

  testWidgets(
    'isLoading shows a progress indicator instead of the label and '
    'suppresses the tap',
    (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        wrap(
          AppButton.primary(
            label: 'Continue',
            onPressed: () => callCount++,
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(callCount, 0);
    },
  );

  testWidgets(
    'onPressed null reports the underlying button as disabled and tapping '
    'it does not throw',
    (tester) async {
      await tester.pumpWidget(
        wrap(AppButton.primary(label: 'Continue', onPressed: null)),
      );

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      // A disabled button swallows the tap: there is no callback to reach and
      // nothing may throw.
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();
    },
  );
}

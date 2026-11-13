import 'package:dabbler/features/app_boot/min_build/min_build_gate.dart';
import 'package:dabbler/features/app_boot/min_build/min_build_providers.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appKey = ValueKey('the-app');
const Widget _app = Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(key: _appKey),
);

Future<void> _pump(
  WidgetTester tester,
  Future<MinBuildStatus> Function() status,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [minBuildStatusProvider.overrideWith((ref) => status())],
      child: const MinBuildGate(child: _app),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('blocked (mobile): the update screen replaces the app', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => const MinBuildStatus(
        blocked: true,
        platform: 'ios',
        storeUrl: 'https://apps.apple.com/app/id1',
      ),
    );
    expect(find.byKey(_appKey), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.widgetWithText(DabblerButton, 'Update'), findsOneWidget);
  });

  testWidgets('blocked (mobile) without a store url: no button', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => const MinBuildStatus(blocked: true, platform: 'android'),
    );
    expect(find.byKey(_appKey), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.byType(DabblerButton), findsNothing);
  });

  testWidgets('blocked (web): a Reload button', (tester) async {
    await _pump(
      tester,
      () async => const MinBuildStatus(blocked: true, platform: 'web'),
    );
    expect(find.byKey(_appKey), findsNothing);
    expect(find.widgetWithText(DabblerButton, 'Reload'), findsOneWidget);
  });

  testWidgets('not blocked: the app renders', (tester) async {
    await _pump(tester, () async => MinBuildStatus.open);
    expect(find.byKey(_appKey), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });

  testWidgets('a failing check renders the app (fail open)', (tester) async {
    await _pump(tester, () async => throw StateError('boom'));
    expect(find.byKey(_appKey), findsOneWidget);
  });
}

import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/features/bench/presentation/providers/bench_providers.dart';
import 'package:dabbler/features/bench/presentation/screens/bench_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'bench_mocks.mocks.dart';

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

Future<void> _pump(
  WidgetTester tester,
  MockBenchRepository repo, {
  BenchStatus status = BenchStatus.none,
  bool offline = false,
}) async {
  // Tall enough that the whole form, button included, is on screen.
  tester.view.physicalSize = const Size(393, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        benchRepositoryProvider.overrideWithValue(repo),
        benchStatusProvider.overrideWith((ref) async => status),
        benchOfflineProvider.overrideWithValue(offline),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: const BenchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<bool> _toggles(WidgetTester tester) => tester
    .widgetList<DabblerToggle>(find.byType(DabblerToggle))
    .map((toggle) => toggle.checked)
    .toList();

void main() {
  testWidgets('form defaults: feed, search, friends on; notifications off', (
    tester,
  ) async {
    await _pump(tester, MockBenchRepository());

    expect(find.text(en.bench_toggle_feed), findsOneWidget);
    expect(_toggles(tester), [true, true, true, false]);
    expect(find.text(en.bench_start), findsOneWidget);
  });

  testWidgets('Cancel on the confirm sheet keeps the form and writes nothing', (
    tester,
  ) async {
    final repo = MockBenchRepository();
    await _pump(tester, repo);

    await tester.ensureVisible(find.text(en.bench_start));
    await tester.tap(find.text(en.bench_start));
    await tester.pumpAndSettle();
    expect(find.text(en.bench_confirm_title), findsOneWidget);

    await tester.tap(find.text(en.bench_cancel));
    await tester.pumpAndSettle();

    expect(find.text(en.bench_confirm_title), findsNothing);
    expect(find.text(en.bench_start), findsOneWidget);
    expect(_toggles(tester), [true, true, true, false]);
    verifyNever(repo.save(any));
  });

  testWidgets('offline disables Start bench and shows the warning', (
    tester,
  ) async {
    final repo = MockBenchRepository();
    await _pump(tester, repo, offline: true);

    expect(find.text(en.bench_offline_title), findsOneWidget);
    await tester.ensureVisible(find.text(en.bench_start));
    await tester.tap(find.text(en.bench_start), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(en.bench_confirm_title), findsNothing);
    verifyNever(repo.save(any));
  });
}

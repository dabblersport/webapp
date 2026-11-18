// KAN-999: the attendance list and the no-show screen read the server again
// every time they open. The provider is held alive across the visits (as a
// stale cache would be), the faked server changes while the screen is away,
// and the reopened screen shows the new state.

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_controller.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart';
import 'package:dabbler/features/attendance/presentation/no_show_controller.dart';
import 'package:dabbler/features/attendance/presentation/no_show_screen.dart';
import 'package:dabbler/features/attendance/data/attendance_review_repository.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attendance_review_fakes.dart';

void _noop() {}
Finder _key(String k) => find.byKey(ValueKey<String>(k));

AttendanceList _list(String outcome) => AttendanceList(
  closesAt: kNow.subtract(const Duration(hours: 5)),
  rows: <AttendanceRow>[
    row(
      's',
      name: 'Sara',
      outcome: outcome,
      note: outcome == 'no_show_review' ? 'I was there' : null,
      reviewDeadline: kNow.add(const Duration(hours: 30)),
      finalized: true,
    ),
  ],
);

NoShowStatus _status(NoShowPhase p) => NoShowStatus(
  phase: p,
  reason: 'Did not show up',
  noShowDeadline: kNow.add(const Duration(hours: 46)),
  reviewDeadline: kNow.add(const Duration(hours: 20)),
);

Future<void> _pump(
  WidgetTester t,
  ProviderContainer c,
  ValueNotifier<bool> open,
  Widget screen,
) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: ValueListenableBuilder<bool>(
          valueListenable: open,
          builder: (_, o, _) => o ? screen : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

ProviderContainer _container(FakeReviewRepo repo) {
  final c = ProviderContainer(
    overrides: [
      attendanceReviewRepositoryProvider.overrideWithValue(repo),
      attendanceNowProvider.overrideWithValue(() => kNow),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('organiser list: reopening shows the review asked meanwhile', (
    t,
  ) async {
    final repo = FakeReviewRepo(listResult: Ok(_list('no_show_pending')));
    final c = _container(repo);
    // Something keeps the provider alive while the screen is closed.
    c.listen(attendanceListProvider('e1'), (_, _) {});
    final open = ValueNotifier<bool>(true);
    await _pump(
      t,
      c,
      open,
      const AttendanceListScreen(eventId: 'e1', onBack: _noop),
    );
    expect(_key('attendance-review-s'), findsNothing);

    final before = repo.listCalls;
    open.value = false;
    await t.pumpAndSettle();
    repo.listResult = Ok(_list('no_show_review'));
    open.value = true;
    await t.pumpAndSettle();

    expect(_key('attendance-review-s'), findsOneWidget);
    expect(repo.listCalls, before + 1);
  });

  testWidgets('player no-show: reopening shows the new server state', (
    t,
  ) async {
    final repo = FakeReviewRepo(noShow: _status(NoShowPhase.pending));
    final c = _container(repo);
    c.listen(noShowProvider('e1'), (_, _) {});
    final open = ValueNotifier<bool>(true);
    await _pump(t, c, open, const NoShowScreen(eventId: 'e1', onBack: _noop));
    expect(_key('no-show-pending'), findsOneWidget);

    open.value = false;
    await t.pumpAndSettle();
    repo.noShow = _status(NoShowPhase.accepted);
    open.value = true;
    await t.pumpAndSettle();

    expect(_key('no-show-accepted'), findsOneWidget);
    expect(_key('no-show-pending'), findsNothing);
  });
}

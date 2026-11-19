// The in-place check-in sheet: Yes checks in and closes, No cancels, a
// failure stays in the sheet, a double tap sends one call. EN and AR.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_controller.dart';
import 'package:dabbler/features/attendance/presentation/check_in_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements AttendanceRepository {
  Result<DateTime?, Failure> result = Ok(DateTime(2026, 11, 18, 18, 50));
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<Result<MyAttendance, Failure>> my(String eventId) async {
    final now = DateTime.now();
    return Ok(
      MyAttendance.fromJson({
        'event_id': 'e1',
        'state': 'open',
        'opens_at': now.toUtc().toIso8601String(),
        'closes_at': now
            .add(const Duration(hours: 6))
            .toUtc()
            .toIso8601String(),
      }),
    );
  }

  @override
  Future<Result<DateTime?, Failure>> checkIn(String eventId) async {
    calls++;
    await gate?.future;
    return result;
  }
}

late ProviderContainer _container;

Future<AppLocalizations> _open(
  WidgetTester t,
  _Repo repo,
  Locale locale,
) async {
  _container = ProviderContainer(
    overrides: [attendanceRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(_container.dispose);
  late AppLocalizations l;
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: Consumer(
          builder: (context, ref, _) {
            l = AppLocalizations.of(context);
            // Keeps the controller alive like the details bar does.
            ref.watch(attendanceCheckInProvider('e1'));
            return Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () => showCheckInSheet(context, 'e1'),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('open')));
  await t.pumpAndSettle();
  return l;
}

const _yes = ValueKey<String>('check-in-sheet-yes');
const _no = ValueKey<String>('check-in-sheet-no');

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] Yes checks in and closes the sheet', (t) async {
      final repo = _Repo();
      final l = await _open(t, repo, locale);
      expect(find.text(l.g04_confirm_title), findsOneWidget);
      expect(find.text(l.g04_confirm_yes), findsOneWidget);
      expect(find.text(l.g04_confirm_no), findsOneWidget);
      await t.tap(find.byKey(_yes));
      await t.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.byKey(_yes), findsNothing);
      expect(
        _container.read(attendanceCheckInProvider('e1')).phase,
        CheckInPhase.checkedIn,
      );
    });

    testWidgets('[$tag] No cancels without a call', (t) async {
      final repo = _Repo();
      await _open(t, repo, locale);
      await t.tap(find.byKey(_no));
      await t.pumpAndSettle();
      expect(find.byKey(_yes), findsNothing);
      expect(repo.calls, 0);
    });

    testWidgets('[$tag] a failure is shown in the sheet', (t) async {
      final repo = _Repo()..result = const Err(Failure(message: 'offline'));
      final l = await _open(t, repo, locale);
      await t.tap(find.byKey(_yes));
      await t.pumpAndSettle();
      expect(find.byKey(_yes), findsOneWidget);
      expect(find.text(l.g04_failed), findsOneWidget);
    });

    testWidgets('[$tag] a double tap sends one call, with a loading state', (
      t,
    ) async {
      final repo = _Repo()..gate = Completer<void>();
      final l = await _open(t, repo, locale);
      await t.tap(find.byKey(_yes));
      await t.pump();
      await t.tap(find.byKey(_yes), warnIfMissed: false);
      await t.pump();
      expect(find.text(l.g04_submitting), findsOneWidget);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(repo.calls, 1);
    });
  }
}

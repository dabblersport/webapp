// KAN-998 (G-04): every check-in state, EN and AR, from server data; the
// refusal mapping; the device's 12/24-hour setting; names shown as entered.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Start 19:00 local: opens 18:30, closes 19:15.
final DateTime _start = DateTime(2026, 11, 18, 19);

Map<String, dynamic> _row(String state, {DateTime? checkedInAt}) => {
  'event_id': 'e1',
  'state': state,
  'opens_at': _start
      .subtract(const Duration(minutes: 30))
      .toUtc()
      .toIso8601String(),
  'closes_at': _start
      .add(const Duration(minutes: 15))
      .toUtc()
      .toIso8601String(),
  'checked_in_at': checkedInAt?.toUtc().toIso8601String(),
};

class _FakeRepo implements AttendanceRepository {
  _FakeRepo(this.row);
  Map<String, dynamic> row;
  Result<DateTime?, Failure> checkInResult = Ok(DateTime(2026, 11, 18, 18, 50));
  Completer<void>? gate;
  Completer<void>? readGate;
  int checkIns = 0;

  @override
  Future<Result<MyAttendance, Failure>> my(String eventId) async {
    await readGate?.future;
    return Ok(MyAttendance.fromJson(row));
  }

  @override
  Future<Result<DateTime?, Failure>> checkIn(String eventId) async {
    checkIns++;
    await gate?.future;
    return checkInResult;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRepo repo, {
  Locale locale = const Locale('en'),
  bool use24h = false,
  String title = 'Padel at Dubai Hills',
  String? venue = 'نادي الملعب',
}) async {
  // KAN-1002: the title and venue come from rpc_attendance_my, not the URL.
  repo.row = {...repo.row, 'title': title, 'venue_name': venue};
  await tester.pumpWidget(
    ProviderScope(
      overrides: [attendanceRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: CheckInScreen(eventId: 'e1', onBack: () {}),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

AppLocalizations _l(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(CheckInScreen)));

String _clock(WidgetTester t, int h, int m) => checkInClock(
  t.element(find.byType(CheckInScreen)),
  DateTime(2026, 11, 18, h, m),
);

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    group('G-04 states (${locale.languageCode})', () {
      testWidgets('before window shows "Opens …" and no button', (t) async {
        await _pump(t, _FakeRepo(_row('before_window')), locale: locale);
        expect(
          find.byKey(const ValueKey('check-in-beforeWindow')),
          findsOneWidget,
        );
        expect(find.text(_l(t).g04_opens(_clock(t, 18, 30))), findsOneWidget);
        expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
        // Title and venue as entered, never translated.
        expect(find.textContaining('Padel at Dubai Hills'), findsOneWidget);
        expect(find.textContaining('نادي الملعب'), findsOneWidget);
        if (locale.languageCode == 'ar') {
          expect(
            Directionality.of(t.element(find.byType(CheckInScreen))),
            TextDirection.rtl,
          );
        }
      });

      testWidgets('open shows "Open until …" and the button', (t) async {
        await _pump(t, _FakeRepo(_row('open')), locale: locale);
        expect(
          find.text(_l(t).g04_open_until(_clock(t, 19, 15))),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('check-in-cta')), findsOneWidget);
      });

      testWidgets('submitting, then checked in', (t) async {
        final repo = _FakeRepo(_row('open'))..gate = Completer<void>();
        await _pump(t, repo, locale: locale);
        await t.tap(find.byKey(const ValueKey('check-in-cta')));
        await t.pump();
        expect(
          find.byKey(const ValueKey('check-in-submitting')),
          findsOneWidget,
        );
        expect(find.text(_l(t).g04_submitting), findsOneWidget);
        repo.gate!.complete();
        await t.pump();
        await t.pump();
        expect(repo.checkIns, 1);
        expect(
          find.byKey(const ValueKey('check-in-checkedIn')),
          findsOneWidget,
        );
        expect(
          find.text(_l(t).g04_checked_in_at(_clock(t, 18, 50))),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      });

      testWidgets('checked in from the server', (t) async {
        await _pump(
          t,
          _FakeRepo(
            _row('checked_in', checkedInAt: DateTime(2026, 11, 18, 18, 40)),
          ),
          locale: locale,
        );
        expect(find.text(_l(t).g04_checked_in), findsOneWidget);
      });

      testWidgets('closed, not checked in', (t) async {
        await _pump(t, _FakeRepo(_row('closed')), locale: locale);
        expect(find.text(_l(t).g04_closed), findsOneWidget);
        expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      });

      testWidgets('not eligible', (t) async {
        await _pump(t, _FakeRepo(_row('not_eligible')), locale: locale);
        expect(find.text(_l(t).g04_not_eligible), findsOneWidget);
        expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      });

      testWidgets('a server refusal shows closed, not a success', (t) async {
        final repo = _FakeRepo(_row('open'))
          ..checkInResult = const Err(Failure(code: 'check_in_closed'));
        await _pump(t, repo, locale: locale);
        await t.tap(find.byKey(const ValueKey('check-in-cta')));
        await t.pump();
        await t.pump();
        expect(find.byKey(const ValueKey('check-in-closed')), findsOneWidget);
        expect(find.byKey(const ValueKey('check-in-checkedIn')), findsNothing);
      });

      testWidgets('a not_eligible refusal shows not eligible', (t) async {
        final repo = _FakeRepo(_row('open'))
          ..checkInResult = const Err(Failure(code: 'not_eligible'));
        await _pump(t, repo, locale: locale);
        await t.tap(find.byKey(const ValueKey('check-in-cta')));
        await t.pump();
        await t.pump();
        expect(
          find.byKey(const ValueKey('check-in-notEligible')),
          findsOneWidget,
        );
        expect(find.text(_l(t).g04_not_eligible), findsOneWidget);
        expect(find.byKey(const ValueKey('check-in-cta')), findsNothing);
      });

      testWidgets('a double tap while submitting calls the RPC once', (
        t,
      ) async {
        final repo = _FakeRepo(_row('open'))..gate = Completer<void>();
        await _pump(t, repo, locale: locale);
        final cta = find.byKey(const ValueKey('check-in-cta'));
        await t.tap(cta);
        await t.pump();
        await t.tap(cta, warnIfMissed: false);
        await t.pump();
        repo.gate!.complete();
        await t.pump();
        await t.pump();
        expect(repo.checkIns, 1);
      });
    });
  }

  testWidgets('Arabic times follow the device 12/24-hour setting', (t) async {
    await _pump(
      t,
      _FakeRepo(_row('open')),
      locale: const Locale('ar'),
      use24h: true,
    );
    expect(find.text(_l(t).g04_open_until('19:15')), findsOneWidget);
    await _pump(t, _FakeRepo(_row('open')), locale: const Locale('ar'));
    expect(find.textContaining('7:15'), findsWidgets);
    expect(find.textContaining('19:15'), findsNothing);
  });

  testWidgets('Arabic isolates an English title and venue', (t) async {
    await _pump(
      t,
      _FakeRepo(_row('open')),
      locale: const Locale('ar'),
      title: 'Padel Night',
      venue: 'Dubai Hills Park',
    );
    expect(find.text('\u2068Padel Night\u2069'), findsOneWidget);
    expect(find.textContaining('\u2068Dubai Hills Park\u2069'), findsOneWidget);
  });

  testWidgets('title and venue come from the read (no URL values)', (t) async {
    // A notice opens /check-in/e1 with no venue; the read supplies it.
    await _pump(t, _FakeRepo(_row('open')), venue: 'Court 3');
    expect(find.textContaining('Padel at Dubai Hills'), findsOneWidget);
    expect(find.textContaining('Court 3'), findsOneWidget);
  });

  testWidgets('an empty venue is treated as absent', (t) async {
    await _pump(t, _FakeRepo(_row('open')), venue: '');
    expect(find.textContaining(' · '), findsNothing);
  });

  testWidgets('times follow the device 12/24-hour setting', (t) async {
    await _pump(t, _FakeRepo(_row('open')), use24h: true);
    expect(find.text(_l(t).g04_open_until('19:15')), findsOneWidget);
    await _pump(t, _FakeRepo(_row('open')));
    expect(find.textContaining('7:15'), findsWidgets);
    expect(find.textContaining('19:15'), findsNothing);
  });

  group('refusal mapping', () {
    test('server messages to states', () {
      expect(phaseForRefusal('check_in_closed'), CheckInPhase.closed);
      expect(phaseForRefusal('attendance_finalized'), CheckInPhase.closed);
      expect(phaseForRefusal('not_eligible'), CheckInPhase.notEligible);
      expect(phaseForRefusal('event_cancelled'), CheckInPhase.cancelled);
      expect(phaseForRefusal('event_not_found'), isNull);
      expect(phaseForRefusal(null), isNull);
    });

    test('a Postgrest refusal keeps its message as the code', () {
      final f = attendanceFailure(
        const PostgrestException(message: 'check_in_closed', code: '22023'),
      );
      expect(f.code, 'check_in_closed');
      expect(attendanceFailure(StateError('x')).code, isNull);
    });

    test('server states and outcomes to phases', () {
      expect(
        phaseFromServer('before_window', checkedIn: false),
        CheckInPhase.beforeWindow,
      );
      expect(
        phaseFromServer('attended', checkedIn: true),
        CheckInPhase.checkedIn,
      );
      expect(
        phaseFromServer('no_show_pending', checkedIn: false),
        CheckInPhase.closed,
      );
      expect(
        phaseFromServer('unknown', checkedIn: true),
        CheckInPhase.checkedIn,
      );
    });
  });

  testWidgets('a pending read shows the spinner, then the read title', (
    t,
  ) async {
    final repo = _FakeRepo(_row('open'))..readGate = Completer<void>();
    await _pump(t, repo, title: 'Padel Night');
    expect(find.byType(DabblerSpinner), findsOneWidget);
    expect(find.textContaining('Padel Night'), findsNothing);
    repo.readGate!.complete();
    await t.pump();
    await t.pump();
    expect(find.byType(DabblerSpinner), findsNothing);
    expect(find.textContaining('Padel Night'), findsOneWidget);
  });
}

// KAN-1002 (W2-F5): the lifecycle card in EN and AR. Every state comes from a
// faked rpc_event_lifecycle_read reply; the organiser's controls follow the
// server's is_organiser; after a call the state is read again; a fresh
// controller shows what the server holds; a cancelled event shows the
// cancelled state; a refusal never shows success; a double tap is one call.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/lifecycle/data/lifecycle_repository.dart';
import 'package:dabbler/features/lifecycle/domain/lifecycle_models.dart';
import 'package:dabbler/features/lifecycle/presentation/event_lifecycle_card.dart';
import 'package:dabbler/features/lifecycle/presentation/lifecycle_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 18, 21);
final _startedAt = DateTime(2026, 11, 18, 20, 5);
final _endedAt = DateTime(2026, 11, 18, 21, 10);
final _autoClose = DateTime(2026, 11, 19, 0);

// Live: starts 20:30, ends 21:30. Past: 18:00-20:00.
final _liveStart = DateTime(2026, 11, 18, 20, 30);
final _liveEnd = DateTime(2026, 11, 18, 21, 30);
final _pastStart = DateTime(2026, 11, 18, 18);
final _pastEnd = DateTime(2026, 11, 18, 20);

String? _w(DateTime? t) => t?.toUtc().toIso8601String();

Map<String, dynamic> _row(
  String state, {
  bool organiser = true,
  bool cancelled = false,
  bool live = false,
  DateTime? autoCloseAt,
  DateTime? start,
  DateTime? end,
  bool noEnd = false,
}) => {
  'event_id': 'e1',
  'event_type': 'game',
  'state': state,
  'raw_state': state,
  'start_at': _w(start ?? (live ? _liveStart : _pastStart)),
  'end_at': noEnd ? null : _w(end ?? (live ? _liveEnd : _pastEnd)),
  'scheduled_end_at': noEnd ? null : _w(end ?? (live ? _liveEnd : _pastEnd)),
  'actual_started_at': state == 'started' ? _w(_startedAt) : null,
  'actual_ended_at': state == 'confirmed' ? _w(_endedAt) : null,
  'closed_at': null,
  'closed_reason': null,
  'is_organiser': organiser,
  'is_cancelled': cancelled,
  'auto_close_at': _w(autoCloseAt),
};

/// A fake server: the read returns [row]; a call that is not refused moves
/// [row] the way the server would.
class _Repo implements LifecycleRepository {
  _Repo(this.row, {this.refuse, this.gate, this.notFound = false});
  Map<String, dynamic> row;
  final String? refuse;
  final Completer<void>? gate;
  final bool notFound;
  int calls = 0;
  int reads = 0;

  /// Reads numbered here (1 is the first) fail with a network error.
  Set<int> failReads = {};

  @override
  Future<Result<LifecycleView, Failure>> read(String eventId) async {
    reads++;
    if (failReads.contains(reads)) {
      return const Err(
        Failure(category: FailureCode.network, message: 'offline'),
      );
    }
    if (notFound) {
      return const Err(
        Failure(
          category: FailureCode.unknown,
          message: 'event_not_found',
          code: 'event_not_found',
        ),
      );
    }
    return Ok(LifecycleView.fromJson(row));
  }

  Future<Result<void, Failure>> _answer(String state) async {
    calls++;
    if (gate != null) await gate!.future;
    if (refuse != null) {
      return Err(
        Failure(category: FailureCode.unknown, message: refuse!, code: refuse),
      );
    }
    row = {
      ...row,
      'state': state,
      'actual_started_at': state == 'started' ? _w(_startedAt) : null,
      'actual_ended_at': state == 'confirmed' ? _w(_endedAt) : null,
    };
    return const Ok(null);
  }

  @override
  Future<Result<void, Failure>> start(String eventId) => _answer('started');

  @override
  Future<Result<void, Failure>> confirmEnd(
    String eventId, {
    required bool played,
  }) => _answer(played ? 'confirmed' : 'did_not_happen');
}

Future<_Repo> _pump(
  WidgetTester t,
  _Repo r, {
  String locale = 'en',
  bool h24 = false,
  DateTime Function()? clock,
}) async {
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        lifecycleRepositoryProvider.overrideWithValue(r),
        lifecycleClockProvider.overrideWithValue(clock ?? () => _now),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: h24),
          child: child!,
        ),
        home: const Scaffold(body: EventLifecycleCard(eventId: 'e1')),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return r;
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(_k(key));
  await t.pump();
  await t.pump();
}

/// Text with any space (intl puts U+202F before AM/PM) read as a plain space.
Finder _t(String want) => find.byWidgetPredicate((w) {
  final String? d = w is Text ? w.data : null;
  return d != null && d.replaceAll(RegExp(r'\s'), ' ') == want;
}, description: 'text "$want"');

Finder _k(String k) => find.byKey(ValueKey<String>(k));

const _copy = {
  'en': {
    'until': 'Scheduled until 9:30 PM',
    'until24': 'Scheduled until 21:30',
    'started': 'Started 8:05 PM',
    'awaiting': 'Scheduled to end 8:00 PM',
    'confirmed': 'Ended 9:10 PM',
    'timeEnded': 'Scheduled time ended',
    'dnh': 'Did not happen',
    'start': 'Start',
    'confirm': 'Confirm end',
    'cancelled': 'This activity was cancelled',
    'autoClose': 'Closes automatically at 12:00 AM',
  },
  'ar': {
    'until': 'مجدول حتى 9:30 م',
    'until24': 'مجدول حتى 21:30',
    'started': 'بدأ 8:05 م',
    'awaiting': 'كان موعد الانتهاء 8:00 م',
    'confirmed': 'انتهى 9:10 م',
    'timeEnded': 'انتهى الوقت المحدد',
    'dnh': 'لم يحدث',
    'start': 'ابدأ',
    'confirm': 'تأكيد الانتهاء',
    'cancelled': 'تم إلغاء هذا النشاط',
    'autoClose': 'يُغلق تلقائياً الساعة 12:00 ص',
  },
};

void main() {
  for (final lang in ['en', 'ar']) {
    final c = _copy[lang]!;
    group(lang, () {
      testWidgets('scheduled: "Scheduled until …", Start is optional', (
        t,
      ) async {
        await _pump(t, _Repo(_row('scheduled', live: true)), locale: lang);
        expect(_k('lifecycle-scheduled'), findsOneWidget);
        expect(_t(c['until']!), findsOneWidget);
        expect(_t(c['start']!), findsOneWidget);
      });

      testWidgets('Start re-reads the server: "Started 8:05 PM"', (t) async {
        final r = await _pump(
          t,
          _Repo(_row('scheduled', live: true)),
          locale: lang,
        );
        await _tap(t, 'lifecycle-start');
        expect(r.reads, 2);
        expect(_k('lifecycle-started'), findsOneWidget);
        expect(_t(c['started']!), findsOneWidget);
        expect(_k('lifecycle-start'), findsNothing);
      });

      testWidgets('awaiting confirmation: Confirm end and Did not happen', (
        t,
      ) async {
        await _pump(t, _Repo(_row('awaiting_confirmation')), locale: lang);
        expect(_k('lifecycle-awaitingConfirmation'), findsOneWidget);
        expect(_t(c['awaiting']!), findsOneWidget);
        expect(_k('lifecycle-confirm'), findsOneWidget);
        expect(_k('lifecycle-did-not-happen'), findsOneWidget);
        expect(_t(c['autoClose']!), findsNothing);
      });

      testWidgets('awaiting shows auto_close_at only when sent', (t) async {
        await _pump(
          t,
          _Repo(_row('awaiting_confirmation', autoCloseAt: _autoClose)),
          locale: lang,
        );
        expect(
          find.textContaining(c['autoClose']!.split(' 12')[0]),
          findsOneWidget,
        );
      });

      testWidgets('Confirm end re-reads: the confirmed end, no controls', (
        t,
      ) async {
        await _pump(t, _Repo(_row('awaiting_confirmation')), locale: lang);
        await _tap(t, 'lifecycle-confirm');
        expect(_k('lifecycle-confirmed'), findsOneWidget);
        expect(_t(c['confirmed']!), findsOneWidget);
        expect(_k('lifecycle-confirm'), findsNothing);
      });

      testWidgets('auto_closed: "Scheduled time ended"', (t) async {
        await _pump(t, _Repo(_row('auto_closed')), locale: lang);
        expect(_k('lifecycle-timeEnded'), findsOneWidget);
        expect(_t(c['timeEnded']!), findsOneWidget);
        expect(_k('lifecycle-confirm'), findsNothing);
      });

      testWidgets('Did not happen re-reads', (t) async {
        await _pump(t, _Repo(_row('awaiting_confirmation')), locale: lang);
        await _tap(t, 'lifecycle-did-not-happen');
        expect(_k('lifecycle-didNotHappen'), findsOneWidget);
        expect(_t(c['dnh']!), findsOneWidget);
        expect(_k('lifecycle-did-not-happen'), findsNothing);
      });

      testWidgets('reload: a fresh controller shows the server state', (
        t,
      ) async {
        for (final (state, key, text) in [
          ('started', 'lifecycle-started', c['started']!),
          ('confirmed', 'lifecycle-confirmed', c['confirmed']!),
          ('did_not_happen', 'lifecycle-didNotHappen', c['dnh']!),
        ]) {
          await _pump(t, _Repo(_row(state, live: true)), locale: lang);
          expect(_k(key), findsOneWidget);
          expect(_t(text), findsOneWidget);
        }
      });

      testWidgets('non-organiser sees the state but no controls', (t) async {
        await _pump(
          t,
          _Repo(_row('scheduled', live: true, organiser: false)),
          locale: lang,
        );
        expect(_t(c['until']!), findsOneWidget);
        expect(_k('lifecycle-start'), findsNothing);
        await _pump(
          t,
          _Repo(_row('awaiting_confirmation', organiser: false)),
          locale: lang,
        );
        expect(_t(c['awaiting']!), findsOneWidget);
        expect(_k('lifecycle-confirm'), findsNothing);
        expect(_k('lifecycle-did-not-happen'), findsNothing);
      });

      testWidgets('cancelled shows the cancelled state, no controls', (
        t,
      ) async {
        await _pump(
          t,
          _Repo(_row('awaiting_confirmation', cancelled: true)),
          locale: lang,
        );
        expect(_k('lifecycle-cancelled'), findsOneWidget);
        expect(_t(c['cancelled']!), findsOneWidget);
        expect(_k('lifecycle-confirm'), findsNothing);
        expect(_k('lifecycle-awaitingConfirmation'), findsNothing);
      });

      testWidgets('24-hour device setting', (t) async {
        await _pump(
          t,
          _Repo(_row('scheduled', live: true)),
          locale: lang,
          h24: true,
        );
        expect(_t(c['until24']!), findsOneWidget);
      });
    });
  }

  testWidgets('event_not_found shows nothing', (t) async {
    await _pump(t, _Repo(_row('scheduled'), notFound: true));
    expect(find.byType(EventLifecycleCard), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a server refusal never shows success', (t) async {
    final r = _Repo(_row('awaiting_confirmation'), refuse: 'already_closed');
    await _pump(t, r);
    await _tap(t, 'lifecycle-confirm');
    expect(_k('lifecycle-confirmed'), findsNothing);
    expect(_k('lifecycle-awaitingConfirmation'), findsOneWidget);
    expect(_k('lifecycle-error'), findsOneWidget);
    expect(find.text('This activity is already closed.'), findsOneWidget);
  });

  testWidgets('the controller drops a second call while one is in flight', (
    t,
  ) async {
    final gate = Completer<void>();
    final r = _Repo(_row('awaiting_confirmation'), gate: gate);
    await _pump(t, r);
    final ctrl = ProviderScope.containerOf(
      t.element(find.byType(EventLifecycleCard)),
    ).read(lifecycleControllerProvider('e1').notifier);
    // Straight to the controller, past the disabled button.
    unawaited(ctrl.run(LifecycleAction.confirm));
    unawaited(ctrl.run(LifecycleAction.didNotHappen));
    await t.pump();
    gate.complete();
    await t.pump();
    await t.pump();
    expect(r.calls, 1);
    expect(_k('lifecycle-confirmed'), findsOneWidget);
  });

  testWidgets('Start is hidden before start_at', (t) async {
    await _pump(t, _Repo(_row('scheduled', start: DateTime(2026, 11, 18, 22))));
    expect(_k('lifecycle-scheduled'), findsOneWidget);
    expect(_k('lifecycle-start'), findsNothing);
  });

  for (final (code, text) in [
    ('not_started_yet', 'You can start once the scheduled time begins.'),
    ('lifecycle_closed', 'This activity is already closed.'),
  ]) {
    testWidgets('$code shows its own message, never success', (t) async {
      final row = code == 'not_started_yet'
          ? _row('scheduled', live: true)
          : _row('awaiting_confirmation');
      await _pump(t, _Repo(row, refuse: code));
      await _tap(
        t,
        code == 'not_started_yet' ? 'lifecycle-start' : 'lifecycle-confirm',
      );
      expect(_k('lifecycle-error'), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(_k('lifecycle-started'), findsNothing);
      expect(_k('lifecycle-confirmed'), findsNothing);
    });
  }

  testWidgets('a failed first read shows a retry that reads again', (t) async {
    final r = _Repo(_row('awaiting_confirmation'))..failReads = {1};
    await _pump(t, r);
    expect(_k('lifecycle-load-failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    await t.pump();
    expect(r.reads, 2);
    expect(_k('lifecycle-awaitingConfirmation'), findsOneWidget);
  });

  testWidgets('a call that succeeds but whose re-read fails is surfaced', (
    t,
  ) async {
    final r = _Repo(_row('awaiting_confirmation'))..failReads = {2};
    await _pump(t, r);
    await _tap(t, 'lifecycle-confirm');
    expect(r.calls, 1);
    expect(_k('lifecycle-error'), findsOneWidget);
    expect(_k('lifecycle-confirmed'), findsNothing);
  });

  testWidgets('no scheduled end: no "Scheduled until" line', (t) async {
    await _pump(t, _Repo(_row('started', live: true, noEnd: true)));
    expect(_t('Started 8:05 PM'), findsOneWidget);
    expect(find.textContaining('Scheduled until'), findsNothing);
    await _pump(t, _Repo(_row('scheduled', live: true, noEnd: true)));
    expect(find.textContaining('Scheduled until'), findsNothing);
    expect(_t('Scheduled'), findsOneWidget);
  });

  testWidgets('the start boundary passing re-reads: Start appears', (t) async {
    var now = _now;
    final start = _now.add(const Duration(minutes: 10));
    final r = _Repo(_row('scheduled', start: start, end: _liveEnd));
    await _pump(t, r, clock: () => now);
    expect(r.reads, 1);
    expect(_k('lifecycle-start'), findsNothing);
    now = start.add(const Duration(seconds: 1));
    await t.pump(const Duration(minutes: 10, seconds: 1));
    await t.pump();
    expect(r.reads, 2);
    expect(_k('lifecycle-start'), findsOneWidget);
  });

  testWidgets('the end boundary passing re-reads: Confirm end appears', (
    t,
  ) async {
    var now = _now;
    final end = _now.add(const Duration(minutes: 5));
    final r = _Repo(_row('started', start: _pastStart, end: end));
    await _pump(t, r, clock: () => now);
    expect(_k('lifecycle-confirm'), findsNothing);
    // The server moves on at the end; the screen was left open.
    r.row = {...r.row, 'state': 'awaiting_confirmation'};
    now = end.add(const Duration(seconds: 1));
    await t.pump(const Duration(minutes: 5, seconds: 1));
    await t.pump();
    expect(r.reads, 2);
    expect(_k('lifecycle-confirm'), findsOneWidget);
  });

  testWidgets('dispose cancels the boundary timer', (t) async {
    final r = _Repo(
      _row('scheduled', start: _now.add(const Duration(minutes: 10))),
    );
    await _pump(t, r);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(minutes: 20));
    expect(r.reads, 1);
  });

  testWidgets('resuming the app re-reads the server', (t) async {
    final r = _Repo(_row('awaiting_confirmation'));
    await _pump(t, r);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(r.reads, 2);
  });
}

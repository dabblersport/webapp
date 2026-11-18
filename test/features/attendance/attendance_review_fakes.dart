// KAN-999: a recording fake of the organiser/no-show attendance repository
// and the harness the G-05 / G-06 tests pump.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_review_repository.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixed "now" of every test: 2026-11-18 21:00 local.
final DateTime kNow = DateTime(2026, 11, 18, 21);

class FakeReviewRepo implements AttendanceReviewRepository {
  FakeReviewRepo({this.listResult, this.noShow});

  Result<AttendanceList, Failure>? listResult;
  NoShowStatus? noShow;

  /// Each write's answer; Ok by default.
  Failure? correctFailure;
  Failure? finalizeFailure;
  Failure? decideFailure;
  Failure? requestFailure;

  /// Holds every write open until completed.
  Completer<void>? gate;

  final List<String> calls = <String>[];

  @override
  Future<Result<AttendanceList, Failure>> list(String eventId) async {
    listCalls++;
    return listResult ?? const Err(Failure(code: 'not_organiser'));
  }

  /// How many times the list was read.
  int listCalls = 0;

  Future<Result<void, Failure>> _w(String call, Failure? f) async {
    calls.add(call);
    await gate?.future;
    return f == null ? const Ok(null) : Err(f);
  }

  @override
  Future<Result<void, Failure>> correct(
    String eventId,
    String userId,
    AttendanceMark mark,
    String reason,
  ) => _w('correct:$userId:${mark.wire}:$reason', correctFailure);

  @override
  Future<Result<void, Failure>> finalize(String eventId) =>
      _w('finalize', finalizeFailure);

  @override
  Future<Result<void, Failure>> decide(
    String eventId,
    String userId, {
    required bool accept,
  }) => _w('decide:$userId:${accept ? 'accept' : 'keep'}', decideFailure);

  @override
  Future<Result<NoShowStatus, Failure>> myNoShow(String eventId) async =>
      noShow == null ? const Err(Failure(code: 'x')) : Ok(noShow!);

  @override
  Future<Result<DateTime?, Failure>> requestReview(
    String eventId,
    String? note,
  ) async {
    calls.add('request:${note ?? ''}');
    await gate?.future;
    return requestFailure == null
        ? Ok(kNow.add(const Duration(hours: 48)))
        : Err(requestFailure!);
  }
}

AttendanceRow row(
  String id, {
  String? name,
  DateTime? checkedInAt,
  String? mark,
  String? method,
  String? reason,
  String? outcome,
  String? note,
  DateTime? reviewDeadline,
  bool finalized = false,
}) => AttendanceRow(
  userId: id,
  displayName: name ?? 'Player $id',
  checkedInAt: checkedInAt,
  mark: mark,
  markMethod: method,
  correctionReason: reason,
  outcome: outcome,
  reviewNote: note,
  reviewDeadline: reviewDeadline,
  finalized: finalized,
);

Future<void> pumpAttendance(
  WidgetTester tester,
  FakeReviewRepo repo,
  Widget home, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        attendanceReviewRepositoryProvider.overrideWithValue(repo),
        attendanceNowProvider.overrideWithValue(() => kNow),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const List<Locale> kLocales = <Locale>[Locale('en'), Locale('ar')];

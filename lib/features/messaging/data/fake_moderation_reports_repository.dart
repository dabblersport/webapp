import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/features/messaging/domain/moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// An in-memory [ModerationReportsRepository] (KAN-552). No network, no
/// database. Its own class rather than more of `FakeMessagingRepository`,
/// which is near the 500-line file limit.
class FakeModerationReportsRepository implements ModerationReportsRepository {
  final List<ReportRow> _rows = [];
  final Map<String, String> _bodies = {};

  /// How many times each operation was called (including failures).
  int listCalls = 0;
  int readCalls = 0;

  /// The report ids [readReportedMessage] was called with, in order.
  final List<String> readIds = [];

  /// Delays, for the loading state and the in-flight guard.
  Duration? listDelay;
  Duration? readDelay;

  Failure? _listNext;
  Failure? _readAlways;

  /// Rows returned by [listMessageReports], newest first.
  void seedReports(List<ReportRow> rows) {
    _rows
      ..clear()
      ..addAll(rows)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// The text [readReportedMessage] returns for [reportId].
  void seedBody(String reportId, String body) => _bodies[reportId] = body;

  /// The next [listMessageReports] fails with [failure]; later calls succeed.
  void failNextList(Failure failure) => _listNext = failure;

  /// Every [readReportedMessage] fails with [failure] (null clears it).
  void failReads(Failure? failure) => _readAlways = failure;

  @override
  Future<Result<List<ReportRow>, Failure>> listMessageReports({
    int? limit,
  }) async {
    listCalls++;
    final d = listDelay;
    if (d != null) await Future<void>.delayed(d);
    final f = _listNext;
    if (f != null) {
      _listNext = null;
      return Err(f);
    }
    final rows = limit == null ? _rows : _rows.take(limit);
    return Ok(List<ReportRow>.unmodifiable(rows));
  }

  @override
  Future<Result<ReportedMessage, Failure>> readReportedMessage(
    String reportId,
  ) async {
    readCalls++;
    readIds.add(reportId);
    final d = readDelay;
    if (d != null) await Future<void>.delayed(d);
    final f = _readAlways;
    if (f != null) return Err(f);
    final row = _rows.where((r) => r.reportId == reportId).firstOrNull;
    final body = _bodies[reportId];
    if (row == null || body == null) {
      return Err(
        MessagingFailure(reason: MessagingReason.notFound, httpStatus: 404),
      );
    }
    return Ok(
      ReportedMessage(
        reportId: reportId,
        messageId: row.targetMessageId,
        body: body,
      ),
    );
  }
}

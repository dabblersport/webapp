import 'package:equatable/equatable.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// One message report as `msg_list_message_reports` (KAN-551) returns it:
/// ids, reason, status and time only. No names and no message text exist on
/// it by design (KAN-552).
class ReportRow extends Equatable {
  const ReportRow({
    required this.reportId,
    required this.reason,
    required this.createdAt,
    required this.status,
    required this.targetMessageId,
    this.conversationId,
  });

  final String reportId;

  /// The `report_reason` wire value (e.g. `spam`); unknown values are kept
  /// as-is and labelled generically by the UI.
  final String reason;
  final DateTime createdAt;

  /// The `report_status` wire value (e.g. `open`).
  final String status;
  final String targetMessageId;

  /// Always null today (the RPC cannot map a message to a conversation).
  final String? conversationId;

  /// Parses one RPC row. `report_id`, `reason`, `status` and
  /// `target_message_id` must be non-empty strings and `created_at` a valid
  /// timestamp; otherwise a [Failure], never a throw.
  static Result<ReportRow, Failure> parse(Object? json) {
    if (json is! Map) return _malformed();
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    final id = str(json['report_id']);
    final reason = str(json['reason']);
    final status = str(json['status']);
    final target = str(json['target_message_id']);
    final created = json['created_at'] is String
        ? DateTime.tryParse(json['created_at'] as String)
        : null;
    if (id == null ||
        reason == null ||
        status == null ||
        target == null ||
        created == null) {
      return _malformed();
    }
    return Ok(
      ReportRow(
        reportId: id,
        reason: reason,
        createdAt: created,
        status: status,
        targetMessageId: target,
        conversationId: str(json['conversation_id']),
      ),
    );
  }

  /// Parses the RPC's row list, keeping its order (newest first). Any
  /// malformed row makes the whole result a [Failure].
  static Result<List<ReportRow>, Failure> parseList(Object? json) {
    if (json is! List) return _malformed();
    final out = <ReportRow>[];
    for (final row in json) {
      final parsed = parse(row);
      if (parsed is Err<ReportRow, Failure>) return Err(parsed.error);
      out.add(parsed.requireValue);
    }
    return Ok(List.unmodifiable(out));
  }

  static Err<T, Failure> _malformed<T>() => Err(
    MessagingFailure(
      reason: MessagingReason.unknown,
      message: 'Malformed message-reports payload',
    ),
  );

  @override
  List<Object?> get props => [
    reportId,
    reason,
    createdAt,
    status,
    targetMessageId,
    conversationId,
  ];
}

/// The one message an admin read through the audited Worker route
/// (`GET /v1/moderation/reports/{reportId}/message`, KAN-513). Held in memory
/// only, for the lifetime of the panel that shows it. [toString] never
/// includes [body].
class ReportedMessage {
  const ReportedMessage({
    required this.reportId,
    required this.messageId,
    required this.body,
  });

  final String reportId;
  final String messageId;
  final String body;

  /// Parses the route's 200 body (`{report_id, message: {id, body, ...}}`).
  /// Throws [FormatException] on a malformed body; the repository maps it to
  /// a [Failure].
  static ReportedMessage fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Expected an object');
    final reportId = json['report_id'];
    final message = json['message'];
    if (reportId is! String || message is! Map) {
      throw const FormatException('Expected report_id and message');
    }
    final id = message['id'];
    final body = message['body'];
    if (id is! String || body is! String) {
      throw const FormatException('Expected message id and body');
    }
    return ReportedMessage(reportId: reportId, messageId: id, body: body);
  }

  @override
  String toString() => 'ReportedMessage($reportId)';
}

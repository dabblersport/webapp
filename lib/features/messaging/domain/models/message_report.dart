import 'package:equatable/equatable.dart';

/// One row of the admin Reports screen (KAN-552), as `msg_list_message_reports`
/// (KAN-551) returns it: ids, reason, time and status ONLY. No names, no
/// content, no message id. Reading the message is a separate, audited call.
class MessageReport extends Equatable {
  const MessageReport({
    required this.reportId,
    required this.reason,
    required this.createdAt,
    required this.status,
  });

  /// The report's id (a UUID).
  final String reportId;

  /// The `report_reason` wire name (`spam`, `abuse`, ...).
  final String reason;

  final DateTime createdAt;

  /// The `report_status` wire name (`open`, `triage`, `escalated`,
  /// `resolved`, `dismissed`, `duplicate`).
  final String status;

  /// The id as shown on a row: its first eight characters.
  String get shortId =>
      reportId.length <= 8 ? reportId : reportId.substring(0, 8);

  /// Parses one RPC row; throws [FormatException] when a field is missing.
  factory MessageReport.fromJson(Map<String, dynamic> json) {
    final id = json['report_id'];
    final reason = json['reason'];
    final status = json['status'];
    final created = json['created_at'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('report_id missing');
    }
    if (reason is! String || status is! String || created is! String) {
      throw const FormatException('report fields missing');
    }
    return MessageReport(
      reportId: id,
      reason: reason,
      createdAt: DateTime.parse(created),
      status: status,
    );
  }

  /// Parses the RPC payload (a JSON array of rows).
  static List<MessageReport> parseList(Object? rows) {
    if (rows is! List) throw const FormatException('Expected a JSON array');
    return [
      for (final row in rows)
        if (row is Map)
          MessageReport.fromJson(Map<String, dynamic>.from(row))
        else
          throw const FormatException('Expected a JSON object'),
    ];
  }

  @override
  List<Object?> get props => [reportId, reason, createdAt, status];
}

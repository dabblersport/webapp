import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// The admin Reports screen's two operations (KAN-552): list message reports
/// (`msg_list_message_reports`, KAN-551) and read ONE reported message through
/// the audited Worker route (KAN-513).
///
/// Beside `MessagingRepository`, not on it: that interface is pinned to the
/// six operations of `docs/messaging/openapi.yaml`
/// (`contract_agreement_test.dart`). Never throws.
abstract class ModerationReportsRepository {
  /// Message reports, newest first (the server's order). At most [limit]
  /// rows (server default 50, max 100).
  Future<Result<List<ReportRow>, Failure>> listMessageReports({int? limit});

  /// The text of the message [reportId] points at, with the caller's own
  /// token. A non-admin gets a [NotAModeratorFailure].
  Future<Result<ReportedMessage, Failure>> readReportedMessage(String reportId);
}

/// The Worker's typed refusal for a caller who is not an admin
/// (`workers/messaging/src/errors.ts`).
const String notAModeratorWireName = 'not_a_moderator';
const int notAModeratorHttpStatus = 403;

/// The read was refused because the caller is not a moderator.
///
/// Not a new [MessagingReason]: that enum is pinned member for member to the
/// reason list of `docs/messaging/openapi.yaml`, which does not name this
/// reason. Modelled like `DmCapReachedFailure`: additive, nothing changes.
class NotAModeratorFailure extends MessagingFailure {
  NotAModeratorFailure({super.message})
    : super(
        reason: MessagingReason.unknown,
        category: FailureCode.forbidden,
        httpStatus: notAModeratorHttpStatus,
      );

  String get wireName => notAModeratorWireName;

  @override
  String toString() => 'NotAModeratorFailure(status: $httpStatus)';
}

/// True when the decoded error [body] carries `not_a_moderator`.
bool isNotAModeratorBody(Object? body) {
  if (body is! Map) return false;
  final error = body['error'];
  return error is Map && error['reason'] == notAModeratorWireName;
}

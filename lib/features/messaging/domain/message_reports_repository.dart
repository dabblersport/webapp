import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/message_report.dart';
import 'package:dabbler/features/messaging/domain/models/reported_message.dart';

/// Why a Reports call failed, in the words the screen shows (KAN-552).
enum MessageReportsRefusal {
  /// The Worker refused the caller (`not_a_moderator`), or the list RPC said
  /// `forbidden`.
  notAModerator,

  /// The report or its message does not exist (`not_found`).
  notFound,

  /// `rate_limited`.
  rateLimited,

  /// Anything else: offline, an unknown reason, a server failure.
  failed,
}

/// A failure of a Reports call. An ordinary [Failure] that also carries the
/// [refusal]. It never carries message text.
class MessageReportsFailure extends Failure {
  MessageReportsFailure(
    this.refusal, {
    super.category = FailureCode.unknown,
    super.cause,
  }) : super(message: 'Message reports: ${refusal.name}');

  final MessageReportsRefusal refusal;

  @override
  List<Object?> get props => [...super.props, refusal];
}

/// What the admin Reports screen calls (KAN-552). Every method returns a
/// `Result` and never throws across this boundary.
abstract class MessageReportsRepository {
  /// Message reports, newest first: ids, reason, status and time only
  /// (`msg_list_message_reports`, KAN-551). Admin only: anyone else fails with
  /// [MessageReportsRefusal.notAModerator].
  Future<Result<List<MessageReport>, Failure>> listMessageReports({int? limit});

  /// Reads the ONE message behind [reportId] through the audited Worker route
  /// (KAN-513), which writes the audit row. Each call is one read; there is no
  /// batch variant. Reasons: not_a_moderator, not_found, rate_limited
  /// (+ offline, unknown).
  Future<Result<ReportedMessage, Failure>> readReportedMessage(String reportId);
}

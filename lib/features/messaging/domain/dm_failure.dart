import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// The Worker's typed reason for the database's daily cap on NEW direct
/// messages (`workers/messaging/src/errors.ts`, KAN-561), and its status.
const String dmCapReachedWireName = 'dm_cap_reached';
const int dmCapReachedHttpStatus = 429;

/// Starting a DM was refused because the caller reached the daily cap on new
/// DMs (`dm_cap_reached`, HTTP 429).
///
/// It is a [MessagingFailure] with [MessagingReason.rateLimited] rather than a
/// new [MessagingReason] member: that enum is pinned, member for member, to
/// the reason list of `docs/messaging/openapi.yaml`
/// (`contract_agreement_test.dart`), which does not name this reason yet.
/// Additive: no existing reason or mapping changes.
class DmCapReachedFailure extends MessagingFailure {
  DmCapReachedFailure({super.message, super.retryAfterSeconds})
    : super(
        reason: MessagingReason.rateLimited,
        httpStatus: dmCapReachedHttpStatus,
      );

  /// The wire name this failure stands for.
  String get wireName => dmCapReachedWireName;

  @override
  String toString() => 'DmCapReachedFailure(status: $httpStatus)';
}

/// True when [status] and the decoded error [body] carry `dm_cap_reached`.
bool isDmCapReachedBody(int status, Object? body) {
  if (body is! Map) return false;
  final error = body['error'];
  return error is Map && error['reason'] == dmCapReachedWireName;
}

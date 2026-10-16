import 'package:dabbler/core/fp/failure.dart';

/// The typed reason a messaging request failed, as named in
/// `docs/messaging/openapi.yaml` (`components.schemas.Reason`). Changing a wire
/// name is a contract change.
///
/// [offline] is produced by the app when a request cannot be made; the server
/// never sends it. [unknown] is the fallback for a reason this build does not
/// recognise (or none), so a new server reason never crashes an older app.
enum MessagingReason {
  notInPilot('not_in_pilot', FailureCode.forbidden),
  notAMember('not_a_member', FailureCode.forbidden),
  removed('removed', FailureCode.forbidden),
  leftReadOnly('left_read_only', FailureCode.forbidden),
  gameEnded('game_ended', FailureCode.conflict),
  gameCancelled('game_cancelled', FailureCode.conflict),
  blocked('blocked', FailureCode.forbidden),
  suspended('suspended', FailureCode.forbidden),
  // Starting a DM below the messaging minimum age (KAN-557). A DM reason sent
  // by the Worker; not in the game-chat `openapi.yaml` Reason enum.
  underAge('under_age', FailureCode.forbidden),
  rateLimited('rate_limited', FailureCode.rateLimited),
  notFound('not_found', FailureCode.notFound),
  invalidRequest('invalid_request', FailureCode.validation),
  offline('offline', FailureCode.network),
  unknown('unknown', FailureCode.unknown);

  const MessagingReason(this.wireName, this.category);

  /// The snake_case name on the wire.
  final String wireName;

  /// The app-wide failure category this reason maps to.
  final FailureCode category;

  /// True for the reasons the server can send (everything except the two
  /// client-side ones).
  bool get isServerReason => this != offline && this != unknown;

  /// Maps a wire name to a reason; null, empty or unrecognised is [unknown].
  static MessagingReason fromWire(String? name) {
    if (name == null) return unknown;
    for (final r in values) {
      if (r.wireName == name) return r;
    }
    return unknown;
  }
}

/// A failure of a messaging request: an ordinary [Failure] (so it travels in
/// `Result<T, Failure>`) that also carries the typed [reason].
class MessagingFailure extends Failure {
  MessagingFailure({
    required this.reason,
    this.httpStatus,
    this.retryAfterSeconds,
    FailureCode? category,
    super.message = '',
    super.cause,
    super.stackTrace,
  }) : super(category: category ?? reason.category, code: null);

  final MessagingReason reason;

  /// The HTTP status of the response, when there was one.
  final int? httpStatus;

  /// Seconds to wait, present with [MessagingReason.rateLimited].
  final int? retryAfterSeconds;

  /// The request could not be made (no connection).
  MessagingFailure.offline({Object? cause})
    : this(reason: MessagingReason.offline, cause: cause);

  /// Builds the failure from an HTTP [status] and the decoded error body
  /// (`{"error": {"reason": ..., "message": ..., "retry_after_seconds": ...}}`).
  /// Anything that is not a recognised typed reason becomes
  /// [MessagingReason.unknown]; a 401 and a 5XX carry none, so they map to
  /// unknown with a category taken from the status. Never throws.
  factory MessagingFailure.fromErrorBody(int status, Object? body) {
    String? reasonName;
    var message = '';
    int? retry;
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        final r = error['reason'];
        if (r is String) reasonName = r;
        final m = error['message'];
        if (m is String) message = m;
        final t = error['retry_after_seconds'];
        if (t is int) retry = t;
      }
    }
    var reason = MessagingReason.fromWire(reasonName);
    // The client-side reason is never accepted from the server.
    if (reason == MessagingReason.offline) reason = MessagingReason.unknown;
    FailureCode? category;
    if (reason == MessagingReason.unknown) {
      if (status == 401) {
        category = FailureCode.unauthorized;
      } else if (status >= 500) {
        category = FailureCode.server;
      }
    }
    return MessagingFailure(
      reason: reason,
      httpStatus: status,
      retryAfterSeconds: retry,
      category: category,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    reason,
    httpStatus,
    retryAfterSeconds,
  ];

  @override
  String toString() =>
      'MessagingFailure(${reason.wireName}, status: $httpStatus)';
}

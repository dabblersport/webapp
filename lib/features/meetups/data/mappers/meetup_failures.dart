import 'package:dabbler/core/fp/failure.dart';

/// Maps the P0001 messages raised by the meetup RPCs to typed [Failure]s.
/// The raw message is kept in `code` so the UI can pick copy per reason.
/// Anything else falls back to [Failure.from].
class MeetupFailures {
  const MeetupFailures._();

  static const Map<String, FailureCode> _byMessage = {
    'persona_not_allowed': FailureCode.forbidden,
    'organiser_required': FailureCode.forbidden,
    'not_host': FailureCode.forbidden,
    'cannot_remove_host': FailureCode.forbidden,
    'auth_required': FailureCode.unauthorized,
    'visibility_not_supported': FailureCode.validation,
    'free_meetups_only': FailureCode.validation,
    'title_invalid': FailureCode.validation,
    'invalid_time_range': FailureCode.validation,
    'invalid_capacity': FailureCode.validation,
    'invalid_decision': FailureCode.validation,
    'meetup_cancelled': FailureCode.conflict,
    'capacity_below_going_count': FailureCode.conflict,
    'no_pending_request': FailureCode.conflict,
    'attendee_not_found': FailureCode.notFound,
  };

  static Failure from(Object error, [StackTrace? st]) {
    final text = error.toString();
    for (final entry in _byMessage.entries) {
      if (text.contains(entry.key)) {
        return Failure(
          category: entry.value,
          message: entry.key,
          code: entry.key,
          cause: error,
          stackTrace: st,
        );
      }
    }
    return Failure.from(error, st);
  }
}

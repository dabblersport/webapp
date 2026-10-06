import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The words for a meetup RPC [failure], from its code (the exception message
/// the RPC raises, mapped by `MeetupFailures`). [fallback] is shown for any
/// code without its own copy.
String meetupErrorText(AppLocalizations l, Failure failure, String fallback) =>
    switch (failure.code) {
      // A server refusal to create (a socialiser or host, or the older
      // `organiser_required`). The copy names no role, so it is generic.
      'persona_not_allowed' ||
      'organiser_required' => l.meetups_err_create_refused,
      'not_host' || 'cannot_remove_host' => l.meetups_err_not_host,
      'title_invalid' => l.meetups_err_title_invalid,
      'invalid_time_range' => l.meetups_err_invalid_time_range,
      'invalid_capacity' => l.meetups_err_invalid_capacity,
      'capacity_below_going_count' => l.meetups_err_capacity_below_going,
      'auth_required' => l.meetups_err_auth_required,
      'meetup_cancelled' => l.meetups_error_cancelled,
      'attendee_not_found' => l.meetups_err_attendee_not_found,
      'no_pending_request' => l.meetups_err_no_pending,
      'free_meetups_only' ||
      'visibility_not_supported' => l.meetups_err_unsupported,
      _ => fallback,
    };

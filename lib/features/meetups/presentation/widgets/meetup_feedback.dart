import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// RSVPs to meetup [id] as one operation on the feedback center (Action Area
/// plan §7, flow 2): a compact spinner while it runs; on failure an error with
/// Retry, copy from the failure code (as `showMeetupFailure`). Success is
/// silent, as it was: the operation is withdrawn. Emits intents only.
Future<Result<RsvpStatus, Failure>> rsvpWithFeedback(
  ProviderContainer container,
  String id,
  RsvpAction action,
  AppLocalizations l, {
  String? opId,
}) async {
  final center = container.read(feedbackCenterProvider.notifier);
  final op = center.begin(
    const FeedbackProcessing(),
    key: 'meetup-rsvp:$id',
    id: opId,
  );
  final r = await container.read(meetupActionsProvider).rsvp(id, action);
  switch (r) {
    case Ok():
      center.consumed(op);
    case Err(:final error):
      center.fail(
        op,
        FeedbackResult.error(
          error.code == 'meetup_cancelled'
              ? l.meetups_error_cancelled
              : l.meetups_error_generic,
          action: FeedbackAction(
            label: l.feed_retry,
            onPressed: () =>
                rsvpWithFeedback(container, id, action, l, opId: op),
          ),
        ),
      );
  }
  return r;
}

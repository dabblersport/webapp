import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';

/// The meetup chat's open (KAN-928): Worker route
/// `GET /v1/meetups/{meetupId}/conversation`, the twin of the game route over
/// `msg_meetup_conversation`. The conversation is created on first open for
/// the organiser or a 'going' RSVP. Kept apart from `MessagingRepository`,
/// which mirrors `docs/messaging/openapi.yaml` operation by operation (like
/// `DmRepository`).
///
/// Reasons: not_in_pilot, not_a_member, rate_limited, not_found,
/// invalid_request (+ offline).
abstract class MeetupConversationRepository {
  /// The conversation of [meetupId] for the signed-in user. Never throws.
  Future<Result<Conversation, Failure>> getMeetupConversation(String meetupId);
}

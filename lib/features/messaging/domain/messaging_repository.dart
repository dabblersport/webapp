import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/my_conversations_repository.dart';

/// What the app calls for messaging (phase P2: game chat, text). It mirrors
/// `docs/messaging/openapi.yaml` operation by operation:
///
/// | Method | operationId |
/// |---|---|
/// | [getGameConversation] | `getGameConversation` |
/// | [listMessages] | `listMessages` |
/// | [sendTextMessage] | `sendTextMessage` |
/// | [reportMessage] | `reportMessage` |
/// | [muteConversation] | `muteConversation` |
/// | [unmuteConversation] | `unmuteConversation` |
///
/// Every method returns `Future<Result<T, Failure>>` and never throws across
/// this boundary. A server failure is a `MessagingFailure` (a `Failure`) whose
/// `reason` is the typed reason; a request that cannot be made is
/// `MessagingFailure.offline()`. Implementations belong to a later ticket; this
/// is the interface only (no network code lives in the domain layer).
///
/// It also carries the DM operations (startDm, setMuted) through [DmRepository];
/// those are not in openapi.yaml (Worker routes POST /v1/dm and
/// POST /v1/conversations/{id}/mute, KAN-561).
abstract class MessagingRepository implements DmRepository {
  /// The conversation of [gameId] for the signed-in user: state, whether it is
  /// writable, a `boundary` for a member who left, and the mute flag.
  /// Reasons: not_in_pilot, not_a_member, removed, suspended, rate_limited,
  /// not_found, invalid_request (+ offline).
  Future<Result<Conversation, Failure>> getGameConversation(String gameId);

  /// One page of messages by `seq` cursor. Without [cursor] the newest page
  /// comes back; with [MessageDirection.older] the page is below [cursor], with
  /// [MessageDirection.newer] above it. [limit] defaults to
  /// [MessagingLimits.defaultPageSize] and is at most
  /// [MessagingLimits.maxPageSize]. The server limits history for a member who
  /// left (`boundary`); the client applies no rule of its own.
  /// Reasons: not_in_pilot, not_a_member, removed, suspended, rate_limited,
  /// not_found, invalid_request (+ offline).
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  });

  /// Sends text. [idempotencyKey] is a client-generated UUID, created once per
  /// message and reused on every retry of it: a duplicate send returns the SAME
  /// message (one row, same id and seq), never a second one.
  /// Reasons: not_in_pilot, not_a_member, removed, left_read_only, game_ended,
  /// game_cancelled, blocked, suspended, rate_limited, not_found,
  /// invalid_request (+ offline).
  Future<Result<Message, Failure>> sendTextMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
  });

  /// Reports [messageId] to moderation with one of the ten reasons. There is no
  /// free-text note (D13, D21). No review time is promised.
  /// Reasons: not_in_pilot, not_a_member, removed, suspended, rate_limited,
  /// not_found, invalid_request (+ offline).
  Future<Result<void, Failure>> reportMessage({
    required String messageId,
    required ReportCategory reason,
  });

  /// Mutes the conversation for the caller (there is no leave).
  /// Reasons: not_in_pilot, not_a_member, removed, suspended, rate_limited,
  /// not_found (+ offline).
  Future<Result<void, Failure>> muteConversation(String conversationId);

  /// Unmutes the conversation for the caller.
  /// Reasons: not_in_pilot, not_a_member, removed, suspended, rate_limited,
  /// not_found (+ offline).
  Future<Result<void, Failure>> unmuteConversation(String conversationId);
}

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/message_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/message_report.dart';
import 'package:dabbler/features/messaging/domain/models/reported_message.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/my_conversations_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// Used when messaging is flagged on but the build has no
/// `MESSAGING_API_BASE_URL` (KAN-550). Calls nothing; every operation fails
/// with not_in_pilot, which the chat renders as the unavailable state.
class UnavailableMessagingRepository
    implements
        MessagingRepository,
        MyConversationsRepository,
        MessageReportsRepository {
  const UnavailableMessagingRepository();

  static Err<T, Failure> _no<T>() => Err(
    MessagingFailure(
      reason: MessagingReason.notInPilot,
      message: 'Messaging is not configured in this build',
    ),
  );

  @override
  Future<Result<Conversation, Failure>> getGameConversation(
    String gameId,
  ) async => _no();

  @override
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  }) async => _no();

  @override
  Future<Result<Message, Failure>> sendTextMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
  }) async => _no();

  @override
  Future<Result<void, Failure>> reportMessage({
    required String messageId,
    required ReportCategory reason,
  }) async => _no();

  @override
  Future<Result<void, Failure>> muteConversation(String conversationId) async =>
      _no();

  @override
  Future<Result<void, Failure>> unmuteConversation(
    String conversationId,
  ) async => _no();

  @override
  Future<Result<List<MyConversation>, Failure>> listMyConversations({
    int? limit,
  }) async => _no();

  @override
  Future<Result<List<MessageReport>, Failure>> listMessageReports({
    int? limit,
  }) async => Err(MessageReportsFailure(MessageReportsRefusal.failed));

  @override
  Future<Result<ReportedMessage, Failure>> readReportedMessage(
    String reportId,
  ) async => Err(MessageReportsFailure(MessageReportsRefusal.failed));
}

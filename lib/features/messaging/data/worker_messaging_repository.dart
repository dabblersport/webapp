import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/messaging_image_repository.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_attachment.dart';
import 'package:dabbler/features/messaging/domain/picked_image.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/features/messaging/domain/moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/my_conversations_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

/// The real messaging repository (KAN-550): the six contract operations over
/// the Worker (`docs/messaging/openapi.yaml`) and the Messages list over the
/// `msg_my_conversations` RPC, plus the DM routes of KAN-561 (KAN-562). Never throws; never logs or stores message text.
class WorkerMessagingRepository
    implements
        MessagingRepository,
        MyConversationsRepository,
        DmRepository,
        ModerationReportsRepository,
        MessagingImageRepository {
  WorkerMessagingRepository({
    required MessagingHttpClient http,
    required MessagingRpcCaller rpc,
  }) : _http = http,
       _rpc = rpc;

  final MessagingHttpClient _http;
  final MessagingRpcCaller _rpc;

  @override
  Future<Result<Conversation, Failure>> getGameConversation(String gameId) =>
      _call(
        'GET',
        '/games/${Uri.encodeComponent(gameId)}/conversation',
        ok: const {200},
        parse: (b) => Conversation.fromJson(_map(b)),
      );

  @override
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  }) => _call(
    'GET',
    '/conversations/${Uri.encodeComponent(conversationId)}/messages',
    query: {
      if (cursor != null) 'cursor': '$cursor',
      'direction': direction.wireName,
      if (limit != null) 'limit': '$limit',
    },
    ok: const {200},
    parse: (b) => MessagePage.fromJson(_map(b)),
  );

  @override
  Future<Result<Message, Failure>> sendTextMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
  }) => _call(
    'POST',
    '/conversations/${Uri.encodeComponent(conversationId)}/messages',
    headers: {'Idempotency-Key': idempotencyKey},
    jsonBody: {'body': body},
    // 201 created; 200 duplicate of an earlier send with the same key.
    ok: const {200, 201},
    parse: (b) => Message.fromJson(_map(b)),
  );

  @override
  Future<Result<MessageAttachment, Failure>> uploadImage({
    required String conversationId,
    required PickedImage image,
    required String idempotencyKey,
    UploadProgress? onProgress,
    UploadCancel? cancel,
  }) async {
    final MessagingHttpResponse response;
    try {
      response = await _http.upload(
        '/conversations/${Uri.encodeComponent(conversationId)}/attachments',
        bytes: image.bytes,
        contentType: image.mimeType,
        headers: {'Idempotency-Key': idempotencyKey},
        onProgress: onProgress,
        isCancelled: () => cancel?.isCancelled ?? false,
      );
    } on UploadCancelledException {
      return Err(
        MessagingFailure(
          reason: MessagingReason.unknown,
          message: 'Upload cancelled',
        ),
      );
    } catch (e, st) {
      return Err(_thrown(e, st));
    }
    // 201 stored; 200 the same upload already finished (a retry).
    if (response.status != 200 && response.status != 201) {
      return Err(errorFailure(response.status, response.body));
    }
    try {
      return Ok(MessageAttachment.fromJson(_map(_map(response.body)['attachment'])));
    } catch (e, st) {
      return Err(
        MessagingFailure(
          reason: MessagingReason.unknown,
          httpStatus: response.status,
          message: 'Malformed messaging payload',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<Message, Failure>> sendImageMessage({
    required String conversationId,
    required String idempotencyKey,
    required List<String> attachmentIds,
    String caption = '',
  }) => _call(
    'POST',
    '/conversations/${Uri.encodeComponent(conversationId)}/messages',
    headers: {'Idempotency-Key': idempotencyKey},
    jsonBody: {
      if (caption.isNotEmpty) 'body': caption,
      'attachment_ids': attachmentIds,
    },
    ok: const {200, 201},
    parse: (b) => Message.fromJson(_map(b)),
  );

  @override
  String attachmentUrl(String attachmentId) =>
      _http.uri('/attachments/${Uri.encodeComponent(attachmentId)}').toString();

  @override
  Future<Map<String, String>?> authHeaders() async {
    final token = await _http.bearer();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<Result<void, Failure>> reportMessage({
    required String messageId,
    required ReportCategory reason,
  }) => _call<void>(
    'POST',
    '/messages/${Uri.encodeComponent(messageId)}/report',
    jsonBody: {'reason': reason.wireName},
    ok: const {202},
    parse: (_) {},
  );

  @override
  Future<Result<void, Failure>> muteConversation(String conversationId) =>
      _call<void>(
        'PUT',
        '/conversations/${Uri.encodeComponent(conversationId)}/mute',
        ok: const {204},
        parse: (_) {},
      );

  @override
  Future<Result<void, Failure>> unmuteConversation(String conversationId) =>
      _call<void>(
        'DELETE',
        '/conversations/${Uri.encodeComponent(conversationId)}/mute',
        ok: const {204},
        parse: (_) {},
      );

  @override
  Future<Result<List<MyConversation>, Failure>> listMyConversations({
    int? limit,
  }) async {
    try {
      final rows = await _rpc(SupabaseConfig.msgMyConversationsRpc, {
        if (limit != null) 'p_limit': limit,
      });
      return MyConversation.parseList(rows);
    } catch (e, st) {
      return Err(_thrown(e, st));
    }
  }

  @override
  Future<Result<String, Failure>> startDm(String otherUserId) => _call(
    'POST',
    '/dm',
    jsonBody: {'other_user_id': otherUserId},
    ok: const {200},
    parse: (b) {
      final id = _map(b)['conversation_id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('Expected conversation_id');
      }
      return id;
    },
  );

  @override
  Future<Result<void, Failure>> setMuted(String conversationId, bool muted) =>
      _call<void>(
        'POST',
        '/conversations/${Uri.encodeComponent(conversationId)}/mute',
        jsonBody: {'muted': muted},
        ok: const {200},
        parse: (b) {
          if (_map(b)['muted'] is! bool) {
            throw const FormatException('Expected muted');
          }
        },
      );

  @override
  Future<Result<List<ReportRow>, Failure>> listMessageReports({
    int? limit,
  }) async {
    try {
      final rows = await _rpc(SupabaseConfig.msgListMessageReportsRpc, {
        if (limit != null) 'p_limit': limit,
      });
      return ReportRow.parseList(rows);
    } catch (e, st) {
      return Err(_thrown(e, st));
    }
  }

  /// KAN-552: one audited read (KAN-513). The text stays in the returned
  /// object only; nothing here logs or stores it.
  @override
  Future<Result<ReportedMessage, Failure>> readReportedMessage(
    String reportId,
  ) => _call(
    'GET',
    '/moderation/reports/${Uri.encodeComponent(reportId)}/message',
    ok: const {200},
    parse: ReportedMessage.fromJson,
  );

  Future<Result<T, Failure>> _call<T>(
    String method,
    String path, {
    required Set<int> ok,
    required T Function(Object? body) parse,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final MessagingHttpResponse response;
    try {
      response = await _http.send(
        method,
        path,
        query: query,
        headers: headers,
        jsonBody: jsonBody,
      );
    } catch (e, st) {
      return Err(_thrown(e, st));
    }
    if (!ok.contains(response.status)) {
      return Err(errorFailure(response.status, response.body));
    }
    try {
      return Ok(parse(response.body));
    } catch (e, st) {
      return Err(
        MessagingFailure(
          reason: MessagingReason.unknown,
          httpStatus: response.status,
          message: 'Malformed messaging payload',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// Maps an error response through the typed-reason mapping.
  static MessagingFailure errorFailure(int status, Object? body) {
    if (isNotAModeratorBody(body)) {
      return NotAModeratorFailure(
        message: MessagingFailure.fromErrorBody(status, body).message,
      );
    }
    if (isDmCapReachedBody(status, body)) {
      final f = MessagingFailure.fromErrorBody(status, body);
      return DmCapReachedFailure(
        message: f.message,
        retryAfterSeconds: f.retryAfterSeconds,
      );
    }
    final failure = MessagingFailure.fromErrorBody(status, body);
    // The Worker answers 403 with no reason for messaging_off and unknown
    // authorize reasons (auth.ts): treat it as not_in_pilot (unavailable).
    if (status == 403 && failure.reason == MessagingReason.unknown) {
      return MessagingFailure(
        reason: MessagingReason.notInPilot,
        httpStatus: 403,
        message: failure.message,
      );
    }
    return failure;
  }

  static Failure _thrown(Object e, StackTrace st) {
    // package:http surfaces socket failures as ClientException (io and web).
    if (e is TimeoutException || e is http.ClientException) {
      return MessagingFailure.offline(cause: e);
    }
    return MessagingFailure(
      reason: MessagingReason.unknown,
      message: 'Messaging request failed',
      cause: e,
      stackTrace: st,
    );
  }

  static Map<String, dynamic> _map(Object? body) {
    if (body is! Map) throw const FormatException('Expected a JSON object');
    return Map<String, dynamic>.from(body);
  }
}

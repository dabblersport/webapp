import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
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

/// The admin report list RPC (KAN-551). Kept here because the shared
/// `SupabaseConfig` names are outside this ticket's allowed paths.
const String messageReportsRpc = 'msg_list_message_reports';

/// The real messaging repository (KAN-550): the six contract operations over
/// the Worker (`docs/messaging/openapi.yaml`) and the Messages list over the
/// `msg_my_conversations` RPC. Never throws; never logs or stores message text.
class WorkerMessagingRepository
    implements
        MessagingRepository,
        MyConversationsRepository,
        MessageReportsRepository {
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
  Future<Result<List<MessageReport>, Failure>> listMessageReports({
    int? limit,
  }) async {
    try {
      final rows = await _rpc(messageReportsRpc, {
        if (limit != null) 'p_limit': limit,
      });
      return Ok(MessageReport.parseList(rows));
    } on PostgrestException catch (e) {
      // A non-admin gets P0001 'forbidden' (the admin_resolve_report pattern).
      return Err(
        MessageReportsFailure(
          e.message == 'forbidden'
              ? MessageReportsRefusal.notAModerator
              : MessageReportsRefusal.failed,
          category: FailureCode.unknown,
        ),
      );
    } catch (e) {
      return Err(_reportsFailure(e));
    }
  }

  /// One audited read of one reported message. The body of the response is
  /// parsed for the text only and never logged or stored.
  @override
  Future<Result<ReportedMessage, Failure>> readReportedMessage(
    String reportId,
  ) async {
    final MessagingHttpResponse response;
    try {
      response = await _http.send(
        'GET',
        '/moderation/reports/${Uri.encodeComponent(reportId)}/message',
      );
    } catch (e) {
      return Err(_reportsFailure(e));
    }
    if (response.status != 200) {
      return Err(_reportsRefusal(response.status, response.body));
    }
    try {
      final body = _map(response.body);
      final message = body['message'];
      final text = message is Map ? message['body'] : null;
      if (text is! String) throw const FormatException('no text');
      return Ok(ReportedMessage(reportId: reportId, text: text));
    } catch (_) {
      return Err(MessageReportsFailure(MessageReportsRefusal.failed));
    }
  }

  static MessageReportsFailure _reportsFailure(Object e) =>
      MessageReportsFailure(
        MessageReportsRefusal.failed,
        category: e is TimeoutException || e is http.ClientException
            ? FailureCode.network
            : FailureCode.unknown,
      );

  /// Maps an error response of the audited read to a refusal. `not_a_moderator`
  /// is the moderation route's own reason (not in the chat contract), so it is
  /// read from the body here.
  static MessageReportsFailure _reportsRefusal(int status, Object? body) {
    String? reason;
    if (body is Map) {
      final error = body['error'];
      if (error is Map && error['reason'] is String) {
        reason = error['reason'] as String;
      }
    }
    final refusal = switch (reason) {
      'not_a_moderator' => MessageReportsRefusal.notAModerator,
      'not_found' => MessageReportsRefusal.notFound,
      'rate_limited' => MessageReportsRefusal.rateLimited,
      _ => MessageReportsRefusal.failed,
    };
    return MessageReportsFailure(
      refusal,
      category: switch (refusal) {
        MessageReportsRefusal.notAModerator => FailureCode.forbidden,
        MessageReportsRefusal.notFound => FailureCode.notFound,
        MessageReportsRefusal.rateLimited => FailureCode.rateLimited,
        MessageReportsRefusal.failed =>
          status >= 500 ? FailureCode.server : FailureCode.unknown,
      },
    );
  }

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

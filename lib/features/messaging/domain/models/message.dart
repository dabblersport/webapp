import 'package:equatable/equatable.dart';

import 'package:dabbler/features/messaging/domain/models/message_attachment.dart';

/// `text` for a member's message, `system` for a line the server adds.
enum MessageKind {
  text('text'),
  system('system');

  const MessageKind(this.wireName);
  final String wireName;

  /// An unrecognised kind is treated as `system` (shown neutrally) so a new
  /// server kind does not crash an older app.
  static MessageKind fromWire(String? name) {
    for (final k in values) {
      if (k.wireName == name) return k;
    }
    return system;
  }
}

/// One message (`components.schemas.Message`). The wire payload carries
/// exactly these fields and nothing about delivery state; "sending" and
/// "failed" are local view states of a message that has not come back yet.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.seq,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.senderUserId,
    this.clientKey,
    this.attachments = const [],
  });

  final String id;
  final String conversationId;

  /// Position in the conversation, strictly increasing.
  final int seq;

  /// Null for a system line.
  final String? senderUserId;

  final MessageKind kind;
  final String body;

  /// The idempotency key it was sent with, when it is the caller's own send.
  final String? clientKey;

  final DateTime createdAt;

  /// KAN-581: the images this message carries (empty for text). Absent on the
  /// wire for a text message.
  final List<MessageAttachment> attachments;

  /// Throws [FormatException] on a malformed payload; the repository
  /// implementation catches it and returns a failure.
  factory Message.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final conversationId = json['conversation_id'];
    final seq = json['seq'];
    final body = json['body'];
    final createdAt = json['created_at'];
    if (id is! String ||
        conversationId is! String ||
        seq is! int ||
        body is! String ||
        createdAt is! String) {
      throw const FormatException('Malformed message payload');
    }
    return Message(
      id: id,
      conversationId: conversationId,
      seq: seq,
      senderUserId: json['sender_user_id'] as String?,
      kind: MessageKind.fromWire(json['kind'] as String?),
      body: body,
      clientKey: json['client_key'] as String?,
      createdAt: DateTime.parse(createdAt).toUtc(),
      attachments: _attachmentsOf(json['attachments']),
    );
  }

  static List<MessageAttachment> _attachmentsOf(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) throw const FormatException('Malformed attachments');
    return [
      for (final a in raw)
        MessageAttachment.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'seq': seq,
    'sender_user_id': senderUserId,
    'kind': kind.wireName,
    'body': body,
    'client_key': clientKey,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (attachments.isNotEmpty)
      'attachments': [for (final a in attachments) a.toJson()],
  };

  @override
  List<Object?> get props => [
    id,
    conversationId,
    seq,
    senderUserId,
    kind,
    body,
    clientKey,
    createdAt,
    attachments,
  ];
}

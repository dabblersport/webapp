import '../../../../utils/enums/social_enums.dart'; // For MessageType and MessageStatus enums
import 'package:dabbler/data/models/social/chat_message.dart';

/// Message model for backward compatibility with existing tests
/// This extends ChatMessage to maintain compatibility
class MessageModel extends ChatMessage {
  final MessageStatus status;
  final String? replyToId;

  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.content,
    required super.sentAt,
    required super.messageType,
    super.isEdited,
    super.editedAt,
    super.isDeleted,
    super.deletedAt,
    this.status = MessageStatus.sent,
    this.replyToId,
  });

  /// Create MessageModel from JSON
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Parse message type
    MessageType messageType = MessageType.text;
    final typeStr = json['message_type']?.toString().toLowerCase() ?? 'text';
    switch (typeStr) {
      case 'text':
        messageType = MessageType.text;
        break;
      case 'image':
        messageType = MessageType.image;
        break;
      case 'video':
        messageType = MessageType.video;
        break;
      case 'audio':
        messageType = MessageType.audio;
        break;
      case 'file':
        messageType = MessageType.file;
        break;
      case 'location':
        messageType = MessageType.location;
        break;
      case 'system':
        messageType = MessageType.system;
        break;
      default:
        messageType = MessageType.text;
    }

    // Parse status
    MessageStatus status = MessageStatus.sent;
    final statusStr = json['status']?.toString().toLowerCase() ?? 'sent';
    switch (statusStr) {
      case 'sent':
        status = MessageStatus.sent;
        break;
      case 'delivered':
        status = MessageStatus.delivered;
        break;
      case 'read':
        status = MessageStatus.read;
        break;
      case 'failed':
        status = MessageStatus.failed;
        break;
      default:
        status = MessageStatus.sent;
    }

    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      sentAt: DateTime.tryParse(json['sent_at'] ?? '') ?? DateTime.now(),
      messageType: messageType,
      isEdited: json['is_edited'] ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'])
          : null,
      status: status,
      replyToId: json['reply_to_id'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'sent_at': sentAt.toIso8601String(),
      'message_type': _messageTypeToString(messageType),
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'status': _statusToString(status),
      'reply_to_id': replyToId,
    };
  }

  /// Convert MessageType to string
  String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.audio:
        return 'audio';
      case MessageType.file:
        return 'file';
      case MessageType.location:
        return 'location';
      case MessageType.gameInvite:
        return 'game_invite';
      case MessageType.system:
        return 'system';
    }
  }

  /// Convert MessageStatus to string
  String _statusToString(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.read:
        return 'read';
      case MessageStatus.failed:
        return 'failed';
    }
  }

  /// Copy with new values
  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    DateTime? sentAt,
    MessageType? messageType,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    MessageStatus? status,
    String? replyToId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      messageType: messageType ?? this.messageType,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
    );
  }
}

/// Message status enum
enum MessageStatus { sent, delivered, read, failed }

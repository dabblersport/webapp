import 'package:dabbler/data/models/social/chat_message.dart';
import '../../../../utils/enums/social_enums.dart'; // For MessageType enum

/// Data model for chat messages with real-time support
class ChatMessageModel extends ChatMessage {
  final String senderName;
  final String senderAvatar;
  final bool senderIsVerified;
  final List<String> deliveredTo;
  final List<String> readBy;
  final Map<String, DateTime> readTimestamps;
  final List<MediaAttachment> mediaAttachments;
  final ReplyReference? replyTo;
  final bool isSystemMessage;
  final Map<String, dynamic>? metadata;

  const ChatMessageModel({
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
    this.senderName = '',
    this.senderAvatar = '',
    this.senderIsVerified = false,
    this.deliveredTo = const [],
    this.readBy = const [],
    this.readTimestamps = const {},
    this.mediaAttachments = const [],
    this.replyTo,
    this.isSystemMessage = false,
    this.metadata,
  });

  /// Create ChatMessageModel from Supabase JSON response
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    // Parse sender information from nested profiles data
    final senderData = json['sender'] ?? json['profiles'] ?? {};

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

    // Parse delivery status arrays
    List<String> deliveredTo = [];
    if (json['delivered_to'] != null && json['delivered_to'] is List) {
      deliveredTo = (json['delivered_to'] as List)
          .map((id) => id.toString())
          .toList();
    }

    List<String> readBy = [];
    if (json['read_by'] != null && json['read_by'] is List) {
      readBy = (json['read_by'] as List).map((id) => id.toString()).toList();
    }

    // Parse read timestamps
    Map<String, DateTime> readTimestamps = {};
    if (json['read_timestamps'] != null && json['read_timestamps'] is Map) {
      final timestampsMap = json['read_timestamps'] as Map<String, dynamic>;
      readTimestamps = timestampsMap.map(
        (userId, timestamp) => MapEntry(userId, _parseDateTime(timestamp)),
      );
    }

    // Parse media attachments
    List<MediaAttachment> mediaAttachments = [];
    if (json['media_attachments'] != null &&
        json['media_attachments'] is List) {
      mediaAttachments = (json['media_attachments'] as List)
          .map((attachment) => MediaAttachment.fromJson(attachment))
          .toList();
    } else if (json['attachment_url'] != null) {
      // Legacy single attachment format
      mediaAttachments = [
        MediaAttachment(
          id: json['attachment_id'] ?? '',
          url: json['attachment_url'],
          type: _getAttachmentTypeFromMessageType(messageType),
          name: json['attachment_name'] ?? '',
          size: json['attachment_size'] ?? 0,
        ),
      ];
    }

    // Parse reply reference
    ReplyReference? replyTo;
    if (json['reply_to_message_id'] != null) {
      replyTo = ReplyReference(
        messageId: json['reply_to_message_id'],
        senderId: json['reply_to_sender_id'] ?? '',
        senderName: json['reply_to_sender_name'] ?? '',
        content: json['reply_to_content'] ?? '',
        messageType: MessageType.text, // Default, could be parsed
      );
    }

    return ChatMessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? json['chat_id'] ?? '',
      senderId: json['sender_id'] ?? json['user_id'] ?? '',
      content: json['content'] ?? json['message'] ?? '',
      sentAt: _parseDateTime(json['sent_at'] ?? json['created_at']),
      messageType: messageType,
      isEdited: json['is_edited'] == true,
      editedAt: json['edited_at'] != null
          ? _parseDateTime(json['edited_at'])
          : null,
      isDeleted: json['is_deleted'] == true || json['deleted'] == true,
      deletedAt: json['deleted_at'] != null
          ? _parseDateTime(json['deleted_at'])
          : null,
      senderName:
          senderData['full_name'] ??
          senderData['display_name'] ??
          senderData['username'] ??
          'Unknown User',
      senderAvatar:
          senderData['avatar_url'] ?? senderData['profile_picture'] ?? '',
      senderIsVerified:
          senderData['verified'] == true || senderData['is_verified'] == true,
      deliveredTo: deliveredTo,
      readBy: readBy,
      readTimestamps: readTimestamps,
      mediaAttachments: mediaAttachments,
      replyTo: replyTo,
      isSystemMessage:
          messageType == MessageType.system ||
          json['is_system_message'] == true,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'sent_at': sentAt.toIso8601String(),
      'message_type': _messageTypeToString(messageType),
    };

    // Add optional fields
    if (isEdited) {
      json['is_edited'] = true;
      if (editedAt != null) {
        json['edited_at'] = editedAt!.toIso8601String();
      }
    }

    if (isDeleted) {
      json['is_deleted'] = true;
      if (deletedAt != null) {
        json['deleted_at'] = deletedAt!.toIso8601String();
      }
    }

    if (deliveredTo.isNotEmpty) {
      json['delivered_to'] = deliveredTo;
    }

    if (readBy.isNotEmpty) {
      json['read_by'] = readBy;
    }

    if (readTimestamps.isNotEmpty) {
      json['read_timestamps'] = readTimestamps.map(
        (userId, timestamp) => MapEntry(userId, timestamp.toIso8601String()),
      );
    }

    if (mediaAttachments.isNotEmpty) {
      json['media_attachments'] = mediaAttachments
          .map((a) => a.toJson())
          .toList();
    }

    if (replyTo != null) {
      json['reply_to_message_id'] = replyTo!.messageId;
      json['reply_to_sender_id'] = replyTo!.senderId;
      json['reply_to_sender_name'] = replyTo!.senderName;
      json['reply_to_content'] = replyTo!.content;
    }

    if (isSystemMessage) {
      json['is_system_message'] = true;
    }

    if (metadata != null) {
      json['metadata'] = metadata;
    }

    return json;
  }

  /// Create JSON for sending new message
  Map<String, dynamic> toSendJson() {
    final json = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': _messageTypeToString(messageType),
    };

    // Add media attachments for non-text messages
    if (mediaAttachments.isNotEmpty) {
      json['media_attachments'] = mediaAttachments
          .map((a) => a.toJson())
          .toList();
    }

    // Add reply reference
    if (replyTo != null) {
      json['reply_to_message_id'] = replyTo!.messageId;
    }

    // Add metadata
    if (metadata != null) {
      json['metadata'] = metadata;
    }

    return json;
  }

  /// Create JSON for updating message (edit)
  Map<String, dynamic> toUpdateJson() {
    return {
      'content': content,
      'is_edited': true,
      'edited_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create JSON for marking message as delivered
  Map<String, dynamic> toMarkDeliveredJson(String userId) {
    final newDeliveredTo = List<String>.from(deliveredTo);
    if (!newDeliveredTo.contains(userId)) {
      newDeliveredTo.add(userId);
    }

    return {'delivered_to': newDeliveredTo};
  }

  /// Create JSON for marking message as read
  Map<String, dynamic> toMarkReadJson(String userId) {
    final newReadBy = List<String>.from(readBy);
    if (!newReadBy.contains(userId)) {
      newReadBy.add(userId);
    }

    final newReadTimestamps = Map<String, DateTime>.from(readTimestamps);
    newReadTimestamps[userId] = DateTime.now();

    return {
      'read_by': newReadBy,
      'read_timestamps': newReadTimestamps.map(
        (userId, timestamp) => MapEntry(userId, timestamp.toIso8601String()),
      ),
    };
  }

  /// Create a copy with updated fields
  ChatMessageModel copyWith({
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
    String? senderName,
    String? senderAvatar,
    bool? senderIsVerified,
    List<String>? deliveredTo,
    List<String>? readBy,
    Map<String, DateTime>? readTimestamps,
    List<MediaAttachment>? mediaAttachments,
    ReplyReference? replyTo,
    bool? isSystemMessage,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessageModel(
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
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      senderIsVerified: senderIsVerified ?? this.senderIsVerified,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      readTimestamps: readTimestamps ?? this.readTimestamps,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
      replyTo: replyTo ?? this.replyTo,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if message is delivered to specific user
  bool isDeliveredTo(String userId) => deliveredTo.contains(userId);

  /// Check if message is read by specific user
  bool isReadBy(String userId) => readBy.contains(userId);

  /// Get read timestamp for specific user
  DateTime? getReadTimestamp(String userId) => readTimestamps[userId];

  /// Check if message has media attachments
  bool get hasMedia => mediaAttachments.isNotEmpty;

  /// Check if message can be edited (within time limit)
  bool canEdit({Duration timeLimit = const Duration(hours: 24)}) {
    if (isDeleted || isSystemMessage) return false;
    return DateTime.now().difference(sentAt) <= timeLimit;
  }

  /// Check if message can be deleted
  bool canDelete() => !isDeleted && !isSystemMessage;

  /// Get message preview text (truncated content)
  String get previewText {
    if (isDeleted) return 'This message was deleted';
    if (content.isEmpty && hasMedia) {
      switch (messageType) {
        case MessageType.image:
          return '📷 Photo';
        case MessageType.video:
          return '🎥 Video';
        case MessageType.audio:
          return '🎵 Audio';
        case MessageType.file:
          return '📎 File';
        case MessageType.location:
          return '📍 Location';
        default:
          return 'Media';
      }
    }
    if (content.length > 100) {
      return '${content.substring(0, 100)}...';
    }
    return content;
  }

  // Helper methods
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static String _messageTypeToString(MessageType type) {
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

  static AttachmentType _getAttachmentTypeFromMessageType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return AttachmentType.image;
      case MessageType.video:
        return AttachmentType.video;
      case MessageType.audio:
        return AttachmentType.audio;
      case MessageType.file:
        return AttachmentType.file;
      default:
        return AttachmentType.file;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessageModel{id: $id, sender: $senderName, type: $messageType, content: ${previewText.length > 30 ? '${previewText.substring(0, 30)}...' : previewText}}';
  }
}

/// Model for media attachments in chat messages
class MediaAttachment {
  final String id;
  final String url;
  final AttachmentType type;
  final String name;
  final int size;
  final String? mimeType;
  final Map<String, dynamic>? metadata;

  const MediaAttachment({
    required this.id,
    required this.url,
    required this.type,
    this.name = '',
    this.size = 0,
    this.mimeType,
    this.metadata,
  });

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    AttachmentType type = AttachmentType.file;
    final typeStr = json['type']?.toString().toLowerCase() ?? 'file';
    switch (typeStr) {
      case 'image':
        type = AttachmentType.image;
        break;
      case 'video':
        type = AttachmentType.video;
        break;
      case 'audio':
        type = AttachmentType.audio;
        break;
      case 'file':
      default:
        type = AttachmentType.file;
        break;
    }

    return MediaAttachment(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      type: type,
      name: json['name'] ?? '',
      size: json['size'] ?? 0,
      mimeType: json['mime_type'],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'url': url,
      'type': _typeToString(type),
      'name': name,
      'size': size,
    };

    if (mimeType != null) json['mime_type'] = mimeType;
    if (metadata != null) json['metadata'] = metadata;

    return json;
  }

  String _typeToString(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return 'image';
      case AttachmentType.video:
        return 'video';
      case AttachmentType.audio:
        return 'audio';
      case AttachmentType.file:
        return 'file';
    }
  }
}

/// Model for reply references in chat messages
class ReplyReference {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType messageType;

  const ReplyReference({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
  });

  factory ReplyReference.fromJson(Map<String, dynamic> json) {
    return ReplyReference(
      messageId: json['message_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? '',
      content: json['content'] ?? '',
      messageType: MessageType.text, // Could be parsed properly
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
    };
  }
}

/// Enums for message types and attachment types
enum AttachmentType { image, video, audio, file }

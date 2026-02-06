import '../../../../utils/enums/social_enums.dart'; // For MessageType enum

/// Domain entity for chat messages
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime sentAt;
  final MessageType messageType;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    required this.messageType,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

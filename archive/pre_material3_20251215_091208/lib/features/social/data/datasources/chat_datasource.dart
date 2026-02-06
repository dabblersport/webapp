import 'dart:io';
import '../../../../utils/enums/social_enums.dart'; // For MessageType enum
import 'package:dabbler/data/models/social/chat_message_model.dart';
import 'package:dabbler/data/models/social/conversation_model.dart';
import 'package:dabbler/data/models/social/post.dart';

/// Exception types for chat data source operations
class ChatDataSourceException implements Exception {
  final String message;
  final String code;
  final dynamic details;

  const ChatDataSourceException({
    required this.message,
    required this.code,
    this.details,
  });

  @override
  String toString() => 'ChatDataSourceException: $message (Code: $code)';
}

/// Message delivery exception
class MessageDeliveryException extends ChatDataSourceException {
  final String? tempId;

  const MessageDeliveryException({
    required super.message,
    this.tempId,
    super.code = 'MESSAGE_DELIVERY_ERROR',
    super.details,
  });
}

/// Conversation access exception
class ConversationAccessException extends ChatDataSourceException {
  const ConversationAccessException({
    required super.message,
    super.code = 'CONVERSATION_ACCESS_DENIED',
    super.details,
  });
}

/// Message not found exception
class MessageNotFoundException extends ChatDataSourceException {
  const MessageNotFoundException({
    required super.message,
    super.code = 'MESSAGE_NOT_FOUND',
    super.details,
  });
}

/// Conversation not found exception
class ConversationNotFoundException extends ChatDataSourceException {
  const ConversationNotFoundException({
    required super.message,
    super.code = 'CONVERSATION_NOT_FOUND',
    super.details,
  });
}

/// Media upload exception
class ChatMediaUploadException extends ChatDataSourceException {
  const ChatMediaUploadException({
    required super.message,
    super.code = 'CHAT_MEDIA_UPLOAD_ERROR',
    super.details,
  });
}

/// Rate limit exception for messages
class MessageRateLimitException extends ChatDataSourceException {
  final int retryAfterSeconds;

  const MessageRateLimitException({
    required super.message,
    required this.retryAfterSeconds,
    super.code = 'MESSAGE_RATE_LIMIT',
    super.details,
  });
}

/// Invalid participant exception
class InvalidParticipantException extends ChatDataSourceException {
  const InvalidParticipantException({
    required super.message,
    super.code = 'INVALID_PARTICIPANT',
    super.details,
  });
}

/// Abstract interface for chat data source operations
abstract class ChatDataSource {
  /// Create a new conversation
  Future<ConversationModel> createConversation({
    required String creatorId,
    required String title,
    required List<String> participantIds,
    ConversationType type = ConversationType.group,
    String? description,
    String? avatarUrl,
    Map<String, dynamic>? settings,
  });

  /// Get conversations for user with pagination
  Future<List<ConversationModel>> getConversations({
    required String userId,
    int page = 1,
    int limit = 20,
    ConversationType? type,
    bool includeArchived = false,
    String? searchQuery,
  });

  /// Get a specific conversation by ID
  Future<ConversationModel> getConversation({
    required String conversationId,
    required String userId,
    bool includeParticipants = true,
  });

  /// Update conversation details
  Future<ConversationModel> updateConversation({
    required String conversationId,
    required String userId,
    String? title,
    String? description,
    String? avatarUrl,
    Map<String, dynamic>? settings,
  });

  /// Delete conversation
  Future<bool> deleteConversation({
    required String conversationId,
    required String userId,
  });

  /// Send message with retry mechanism
  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    List<File>? mediaFiles,
    List<String>? mentionedUsers,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
    int maxRetries = 3,
  });

  /// Send message with pre-uploaded media
  Future<ChatMessageModel> sendMessageWithMedia({
    required String conversationId,
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  });

  /// Upload media files for messages
  Future<List<String>> uploadMessageMedia({
    required List<File> files,
    required String userId,
    String? conversationId,
    Function(double)? onProgress,
  });

  /// Get messages from conversation with pagination
  Future<List<ChatMessageModel>> getMessages({
    required String conversationId,
    required String userId,
    int page = 1,
    int limit = 50,
    String? beforeMessageId,
    String? afterMessageId,
    DateTime? fromDate,
    DateTime? toDate,
    MessageType? messageType,
  });

  /// Get a specific message by ID
  Future<ChatMessageModel> getMessage({
    required String messageId,
    required String userId,
  });

  /// Update an existing message
  Future<ChatMessageModel> updateMessage({
    required String messageId,
    required String userId,
    required String content,
    List<File>? newMediaFiles,
    List<String>? removeMediaUrls,
    List<String>? mentionedUsers,
  });

  /// Delete a message
  Future<bool> deleteMessage({
    required String messageId,
    required String userId,
    bool deleteForEveryone = false,
  });

  /// Update read receipts
  Future<bool> markAsRead({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Mark all messages as read in conversation
  Future<bool> markAllAsRead({
    required String conversationId,
    required String userId,
  });

  /// Handle typing indicators
  Future<bool> setTyping({
    required String conversationId,
    required String userId,
    required bool isTyping,
  });

  /// Get typing users in conversation
  Future<List<String>> getTypingUsers({
    required String conversationId,
    required String userId,
  });

  /// Message search with filters
  Future<List<ChatMessageModel>> searchMessages({
    required String query,
    required String userId,
    String? conversationId,
    MessageType? messageType,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int limit = 20,
    bool includeContent = true,
  });

  /// Advanced message search with metadata
  Future<List<ChatMessageModel>> searchMessagesAdvanced({
    required String userId,
    String? textQuery,
    List<String>? conversationIds,
    List<String>? senderIds,
    List<MessageType>? messageTypes,
    Map<String, dynamic>? metadataFilters,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int limit = 20,
  });

  /// Add participant to conversation
  Future<bool> addParticipant({
    required String conversationId,
    required String userId,
    required String newParticipantId,
  });

  /// Remove participant from conversation
  Future<bool> removeParticipant({
    required String conversationId,
    required String userId,
    required String participantId,
  });

  /// Leave conversation
  Future<bool> leaveConversation({
    required String conversationId,
    required String userId,
  });

  /// Get conversation participants
  Future<List<String>> getConversationParticipants({
    required String conversationId,
    required String userId,
    bool includeDetails = false,
  });

  /// Update participant role/permissions
  Future<bool> updateParticipantRole({
    required String conversationId,
    required String userId,
    required String participantId,
    required String role,
  });

  /// Get unread message counts
  Future<Map<String, int>> getUnreadCounts({
    required String userId,
    List<String>? conversationIds,
  });

  /// Get total unread count across all conversations
  Future<int> getTotalUnreadCount({required String userId});

  /// Mute conversation
  Future<bool> muteConversation({
    required String conversationId,
    required String userId,
    DateTime? muteUntil,
  });

  /// Unmute conversation
  Future<bool> unmuteConversation({
    required String conversationId,
    required String userId,
  });

  /// Archive conversation
  Future<bool> archiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Unarchive conversation
  Future<bool> unarchiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Pin conversation
  Future<bool> pinConversation({
    required String conversationId,
    required String userId,
  });

  /// Unpin conversation
  Future<bool> unpinConversation({
    required String conversationId,
    required String userId,
  });

  /// Get message delivery status
  Future<Map<String, bool>> getMessageDeliveryStatus({
    required List<String> messageIds,
    required String userId,
  });

  /// Get conversation settings
  Future<Map<String, dynamic>> getConversationSettings({
    required String conversationId,
    required String userId,
  });

  /// Update conversation settings
  Future<bool> updateConversationSettings({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> settings,
  });

  /// Block user in conversations
  Future<bool> blockUserInChat({
    required String userId,
    required String targetUserId,
  });

  /// Unblock user in conversations
  Future<bool> unblockUserInChat({
    required String userId,
    required String targetUserId,
  });

  /// Get blocked users list
  Future<List<String>> getBlockedUsersInChat({required String userId});

  /// Report message
  Future<bool> reportMessage({
    required String messageId,
    required String reporterId,
    required String reason,
    String? details,
  });

  /// Report conversation
  Future<bool> reportConversation({
    required String conversationId,
    required String reporterId,
    required String reason,
    String? details,
  });

  /// Get conversation analytics (for admins)
  Future<Map<String, dynamic>> getConversationAnalytics({
    required String conversationId,
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
  });

  /// Export conversation data
  Future<Map<String, dynamic>> exportConversationData({
    required String conversationId,
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
    List<MessageType>? messageTypes,
  });

  /// Get conversation media
  Future<List<ChatMessageModel>> getConversationMedia({
    required String conversationId,
    required String userId,
    MessageType? mediaType,
    int page = 1,
    int limit = 20,
  });

  /// Get shared files in conversation
  Future<List<ChatMessageModel>> getSharedFiles({
    required String conversationId,
    required String userId,
    int page = 1,
    int limit = 20,
  });

  /// Get conversation links
  Future<List<ChatMessageModel>> getConversationLinks({
    required String conversationId,
    required String userId,
    int page = 1,
    int limit = 20,
  });

  /// Pin message in conversation
  Future<bool> pinMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Unpin message in conversation
  Future<bool> unpinMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Get pinned messages in conversation
  Future<List<ChatMessageModel>> getPinnedMessages({
    required String conversationId,
    required String userId,
  });

  /// React to message
  Future<bool> reactToMessage({
    required String messageId,
    required String userId,
    required String emoji,
  });

  /// Remove reaction from message
  Future<bool> removeReactionFromMessage({
    required String messageId,
    required String userId,
    required String emoji,
  });

  /// Get message reactions
  Future<Map<String, List<String>>> getMessageReactions({
    required String messageId,
    required String userId,
  });

  /// Forward messages to other conversations
  Future<List<ChatMessageModel>> forwardMessages({
    required List<String> messageIds,
    required List<String> conversationIds,
    required String userId,
    String? additionalContent,
  });

  /// Schedule message to be sent later
  Future<ChatMessageModel> scheduleMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required DateTime scheduledTime,
    MessageType type = MessageType.text,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
  });

  /// Get scheduled messages
  Future<List<ChatMessageModel>> getScheduledMessages({
    required String userId,
    String? conversationId,
    int page = 1,
    int limit = 20,
  });

  /// Cancel scheduled message
  Future<bool> cancelScheduledMessage({
    required String messageId,
    required String userId,
  });

  /// Get conversation invite link
  Future<String> getConversationInviteLink({
    required String conversationId,
    required String userId,
    DateTime? expiresAt,
    int? maxUses,
  });

  /// Join conversation by invite
  Future<ConversationModel> joinConversationByInvite({
    required String inviteCode,
    required String userId,
  });

  /// Revoke conversation invite
  Future<bool> revokeConversationInvite({
    required String conversationId,
    required String userId,
    String? inviteCode,
  });

  /// Get conversation invite info
  Future<Map<String, dynamic>> getConversationInviteInfo({
    required String inviteCode,
  });

  /// Batch operations
  Future<List<bool>> markMultipleAsRead({
    required List<String> messageIds,
    required String userId,
  });

  Future<List<bool>> deleteMultipleMessages({
    required List<String> messageIds,
    required String userId,
    bool deleteForEveryone = false,
  });

  /// Real-time subscriptions
  Stream<ChatMessageModel> subscribeToMessages(String conversationId);
  Stream<ConversationModel> subscribeToConversations(String userId);
  Stream<Map<String, bool>> subscribeToTyping(String conversationId);
  Stream<Map<String, DateTime>> subscribeToReadReceipts(String conversationId);
  Stream<Map<String, int>> subscribeToUnreadCounts(String userId);
}

import 'dart:io';
import '../../../../utils/enums/social_enums.dart'; // For MessageType enum
import 'package:dabbler/data/models/social/chat_message_model.dart';
import 'package:dabbler/data/models/social/conversation_model.dart';
import 'package:dabbler/data/models/social/post.dart';

/// Abstract interface for chat remote data source
abstract class ChatRemoteDataSource {
  /// Get conversations for the current user
  Future<List<ConversationModel>> getConversations({
    int page = 1,
    int limit = 20,
  });

  /// Get a specific conversation by ID
  Future<ConversationModel> getConversation(String conversationId);

  /// Create a new conversation
  Future<ConversationModel> createConversation({
    required String title,
    required List<String> participantIds,
    ConversationType type = ConversationType.group,
    String? description,
    String? avatarUrl,
  });

  /// Update an existing conversation
  Future<ConversationModel> updateConversation({
    required String conversationId,
    String? title,
    String? description,
    String? avatarUrl,
  });

  /// Delete a conversation
  Future<bool> deleteConversation(String conversationId);

  /// Send a message to a conversation
  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
    String? replyToMessageId,
  });

  /// Get messages from a conversation
  Future<List<ChatMessageModel>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
    String? beforeMessageId,
  });

  /// Update an existing message
  Future<ChatMessageModel> updateMessage({
    required String messageId,
    required String content,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
  });

  /// Delete a message
  Future<bool> deleteMessage(String messageId);

  /// Mark messages as read up to a specific message
  Future<bool> markAsRead({
    required String conversationId,
    required String messageId,
  });

  /// Set typing indicator for a conversation
  Future<bool> setTyping({
    required String conversationId,
    required bool isTyping,
  });

  /// Upload media files for messages
  Future<List<String>> uploadMedia(List<File> files);

  /// Add a participant to a conversation
  Future<bool> addParticipant({
    required String conversationId,
    required String userId,
  });

  /// Remove a participant from a conversation
  Future<bool> removeParticipant({
    required String conversationId,
    required String userId,
  });

  /// Leave a conversation
  Future<bool> leaveConversation(String conversationId);

  /// Search messages across conversations
  Future<List<ChatMessageModel>> searchMessages({
    required String query,
    String? conversationId,
    MessageType? messageType,
    int page = 1,
    int limit = 20,
  });

  /// Get unread message counts for all conversations
  Future<Map<String, int>> getUnreadCounts();

  /// Mute a conversation
  Future<bool> muteConversation({
    required String conversationId,
    DateTime? muteUntil,
  });

  /// Unmute a conversation
  Future<bool> unmuteConversation(String conversationId);

  /// Subscribe to real-time message updates for a conversation
  Stream<ChatMessageModel> subscribeToMessages(String conversationId);

  /// Subscribe to real-time conversation updates
  Stream<ConversationModel> subscribeToConversations();

  /// Subscribe to typing indicators for a conversation
  Stream<Map<String, bool>> subscribeToTyping(String conversationId);

  /// Subscribe to read receipt updates for a conversation
  Stream<Map<String, DateTime>> subscribeToReadReceipts(String conversationId);

  /// Get conversation participants
  Future<List<String>> getConversationParticipants(String conversationId);

  /// Get conversation settings
  Future<Map<String, dynamic>> getConversationSettings(String conversationId);

  /// Update conversation settings
  Future<bool> updateConversationSettings({
    required String conversationId,
    required Map<String, dynamic> settings,
  });

  /// Report a message
  Future<bool> reportMessage({
    required String messageId,
    required String reason,
    String? details,
  });

  /// Block a user in conversations
  Future<bool> blockUser(String userId);

  /// Unblock a user in conversations
  Future<bool> unblockUser(String userId);

  /// Get blocked users list
  Future<List<String>> getBlockedUsers();

  /// Get message delivery status
  Future<Map<String, bool>> getMessageDeliveryStatus(List<String> messageIds);

  /// Get conversation analytics (for group admins)
  Future<Map<String, dynamic>> getConversationAnalytics(String conversationId);

  /// Export conversation data
  Future<String> exportConversationData(String conversationId);

  /// Get conversation media
  Future<List<ChatMessageModel>> getConversationMedia(
    String conversationId, {
    MessageType? mediaType,
    int page = 1,
    int limit = 20,
  });

  /// Get shared files in conversation
  Future<List<ChatMessageModel>> getSharedFiles(
    String conversationId, {
    int page = 1,
    int limit = 20,
  });

  /// Get conversation links
  Future<List<ChatMessageModel>> getConversationLinks(
    String conversationId, {
    int page = 1,
    int limit = 20,
  });

  /// Pin a message in conversation
  Future<bool> pinMessage({
    required String conversationId,
    required String messageId,
  });

  /// Unpin a message in conversation
  Future<bool> unpinMessage({
    required String conversationId,
    required String messageId,
  });

  /// Get pinned messages in conversation
  Future<List<ChatMessageModel>> getPinnedMessages(String conversationId);

  /// React to a message
  Future<bool> reactToMessage({
    required String messageId,
    required String emoji,
  });

  /// Remove reaction from message
  Future<bool> removeReactionFromMessage({
    required String messageId,
    required String emoji,
  });

  /// Get message reactions
  Future<Map<String, List<String>>> getMessageReactions(String messageId);

  /// Forward messages to other conversations
  Future<List<ChatMessageModel>> forwardMessages({
    required List<String> messageIds,
    required List<String> conversationIds,
    String? additionalContent,
  });

  /// Schedule a message to be sent later
  Future<ChatMessageModel> scheduleMessage({
    required String conversationId,
    required String content,
    required DateTime scheduledTime,
    MessageType type = MessageType.text,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
  });

  /// Get scheduled messages
  Future<List<ChatMessageModel>> getScheduledMessages({
    String? conversationId,
    int page = 1,
    int limit = 20,
  });

  /// Cancel a scheduled message
  Future<bool> cancelScheduledMessage(String messageId);

  /// Get conversation invite link
  Future<String> getConversationInviteLink(String conversationId);

  /// Join conversation by invite link
  Future<ConversationModel> joinConversationByInvite(String inviteCode);

  /// Revoke conversation invite link
  Future<bool> revokeConversationInvite(String conversationId);
}

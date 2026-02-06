import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/social/post.dart'; // For ConversationType
import '../../../../utils/enums/social_enums.dart'; // For MessageType
import 'package:dabbler/data/models/social/conversation_model.dart';
import 'package:dabbler/data/models/social/chat_message_model.dart';

/// Abstract repository for chat and conversation operations
abstract class ChatRepository {
  /// Get conversations for current user
  Future<Either<Failure, List<ConversationModel>>> getConversations({
    ConversationType? type,
    int page = 1,
    int limit = 20,
    bool includeUnreadOnly = false,
  });

  /// Get a specific conversation by ID
  Future<Either<Failure, ConversationModel>> getConversation(
    String conversationId,
  );

  /// Create a new conversation
  Future<Either<Failure, ConversationModel>> createConversation({
    required ConversationType type,
    required List<String> participantIds,
    String? name,
    String? description,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  });

  /// Update conversation details
  Future<Either<Failure, ConversationModel>> updateConversation({
    required String conversationId,
    String? name,
    String? description,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  });

  /// Delete/archive a conversation
  Future<Either<Failure, bool>> deleteConversation(String conversationId);

  /// Add participant to conversation
  Future<Either<Failure, ConversationModel>> addParticipant({
    required String conversationId,
    required String userId,
    ParticipantRole role = ParticipantRole.member,
  });

  /// Remove participant from conversation
  Future<Either<Failure, ConversationModel>> removeParticipant({
    required String conversationId,
    required String userId,
  });

  /// Update participant role
  Future<Either<Failure, ConversationModel>> updateParticipantRole({
    required String conversationId,
    required String userId,
    required ParticipantRole role,
  });

  /// Get messages for a conversation
  Future<Either<Failure, List<ChatMessageModel>>> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
    String? beforeMessageId,
    String? afterMessageId,
  });

  /// Send a message
  Future<Either<Failure, ChatMessageModel>> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
    List<String>? mediaUrls,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  });

  /// Edit a message
  Future<Either<Failure, ChatMessageModel>> editMessage({
    required String messageId,
    required String newContent,
  });

  /// Delete a message
  Future<Either<Failure, bool>> deleteMessage(String messageId);

  /// Mark message as delivered
  Future<Either<Failure, bool>> markMessageAsDelivered({
    required String messageId,
    required String userId,
  });

  /// Mark message as read
  Future<Either<Failure, bool>> markMessageAsRead({
    required String messageId,
    required String userId,
  });

  /// Mark conversation as read (all unread messages)
  Future<Either<Failure, bool>> markConversationAsRead(String conversationId);

  /// Get unread message count for conversation
  Future<Either<Failure, int>> getUnreadMessageCount(String conversationId);

  /// Get total unread message count for user
  Future<Either<Failure, int>> getTotalUnreadCount();

  /// Search messages in conversation
  Future<Either<Failure, List<ChatMessageModel>>> searchMessages({
    String? conversationId,
    required String query,
    int page = 1,
    int limit = 20,
    MessageType? messageType,
    DateTime? fromDate,
    DateTime? toDate,
  });

  /// Start typing indicator
  Future<Either<Failure, bool>> startTyping(String conversationId);

  /// Stop typing indicator
  Future<Either<Failure, bool>> stopTyping(String conversationId);

  /// Get typing users in conversation
  Future<Either<Failure, List<String>>> getTypingUsers(String conversationId);

  /// Upload media for messages
  Future<Either<Failure, List<String>>> uploadMessageMedia(
    List<String> filePaths,
  );

  /// Forward message to another conversation
  Future<Either<Failure, ChatMessageModel>> forwardMessage({
    required String messageId,
    required String toConversationId,
    String? additionalContent,
  });

  /// Pin/unpin message in conversation
  Future<Either<Failure, bool>> pinMessage({
    required String messageId,
    required bool pin,
  });

  /// Get pinned messages for conversation
  Future<Either<Failure, List<ChatMessageModel>>> getPinnedMessages(
    String conversationId,
  );

  /// React to a message
  Future<Either<Failure, bool>> reactToMessage({
    required String messageId,
    required String reaction,
  });

  /// Remove reaction from message
  Future<Either<Failure, bool>> removeMessageReaction(String messageId);

  /// Get conversation settings
  Future<Either<Failure, ConversationSettings>> getConversationSettings(
    String conversationId,
  );

  /// Update conversation settings
  Future<Either<Failure, ConversationSettings>> updateConversationSettings({
    required String conversationId,
    required ConversationSettings settings,
  });

  /// Mute/unmute conversation
  Future<Either<Failure, bool>> muteConversation({
    required String conversationId,
    required bool mute,
    Duration? duration,
  });

  /// Leave conversation (for group chats)
  Future<Either<Failure, bool>> leaveConversation(String conversationId);

  /// Create group chat
  Future<Either<Failure, ConversationModel>> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? description,
    String? avatarUrl,
    GroupChatMetadata? metadata,
  });

  /// Update group chat metadata
  Future<Either<Failure, ConversationModel>> updateGroupChatMetadata({
    required String conversationId,
    required GroupChatMetadata metadata,
  });

  /// Generate invite link for group chat
  Future<Either<Failure, String>> generateInviteLink({
    required String conversationId,
    Duration? expiryDuration,
  });

  /// Join group chat via invite link
  Future<Either<Failure, ConversationModel>> joinViaInviteLink(
    String inviteCode,
  );

  /// Get conversation participants
  Future<Either<Failure, List<ConversationParticipant>>> getParticipants(
    String conversationId,
  );

  /// Stream real-time message updates
  Stream<ChatMessageModel> messageStream(String conversationId);

  /// Stream real-time conversation updates
  Stream<ConversationModel> conversationStream();

  /// Stream typing indicators
  Stream<Map<String, List<String>>> typingStream();

  /// Stream read receipts
  Stream<Map<String, Map<String, DateTime>>> readReceiptsStream();
}

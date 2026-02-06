import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../utils/enums/social_enums.dart'; // For MessageType enum
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/conversation_model.dart';
import 'package:dabbler/data/models/social/chat_message_model.dart';

/// State for chat management
class ChatState {
  final List<ConversationModel> conversations;
  final List<ConversationModel> filteredConversations;
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final bool isLoadingMoreMessages;
  final bool isSendingMessage;
  final String? error;
  final String searchQuery;
  final Map<String, int> unreadCounts;
  final List<String> pinnedConversationIds;
  final List<String> archivedConversationIds;
  final ConversationModel? activeConversation;
  final bool isTypingSomeone;
  final List<TypingIndicator> typingUsers;

  const ChatState({
    this.conversations = const [],
    this.filteredConversations = const [],
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.isLoadingMoreMessages = false,
    this.isSendingMessage = false,
    this.error,
    this.searchQuery = '',
    this.unreadCounts = const {},
    this.pinnedConversationIds = const [],
    this.archivedConversationIds = const [],
    this.activeConversation,
    this.isTypingSomeone = false,
    this.typingUsers = const [],
  });

  bool get isEmpty => conversations.isEmpty;
  bool get hasError => error != null;
  bool get hasPinnedConversations => pinnedConversationIds.isNotEmpty;
  bool get hasArchivedConversations => archivedConversationIds.isNotEmpty;

  List<ConversationModel> get pinnedConversations => conversations
      .where((conv) => pinnedConversationIds.contains(conv.id))
      .toList();

  List<ConversationModel> get activeConversations => conversations
      .where((conv) => !archivedConversationIds.contains(conv.id))
      .toList();

  List<ConversationModel> get archivedConversations => conversations
      .where((conv) => archivedConversationIds.contains(conv.id))
      .toList();

  /// Total unread count across all conversations
  int get totalUnreadCount =>
      unreadCounts.values.fold(0, (sum, count) => sum + count);

  ChatState copyWith({
    List<ConversationModel>? conversations,
    List<ConversationModel>? filteredConversations,
    List<ChatMessageModel>? messages,
    bool? isLoading,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    bool? isLoadingMoreMessages,
    bool? isSendingMessage,
    String? error,
    String? searchQuery,
    Map<String, int>? unreadCounts,
    List<String>? pinnedConversationIds,
    List<String>? archivedConversationIds,
    ConversationModel? activeConversation,
    bool? isTypingSomeone,
    List<TypingIndicator>? typingUsers,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      filteredConversations:
          filteredConversations ?? this.filteredConversations,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingConversations:
          isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isLoadingMoreMessages:
          isLoadingMoreMessages ?? this.isLoadingMoreMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      pinnedConversationIds:
          pinnedConversationIds ?? this.pinnedConversationIds,
      archivedConversationIds:
          archivedConversationIds ?? this.archivedConversationIds,
      activeConversation: activeConversation ?? this.activeConversation,
      isTypingSomeone: isTypingSomeone ?? this.isTypingSomeone,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}

/// Typing indicator information
class TypingIndicator {
  final String userId;
  final String userName;
  final bool isTyping;
  final DateTime lastTypingTime;

  const TypingIndicator({
    required this.userId,
    required this.userName,
    this.isTyping = false,
    required this.lastTypingTime,
  });

  TypingIndicator copyWith({
    String? userId,
    String? userName,
    bool? isTyping,
    DateTime? lastTypingTime,
  }) {
    return TypingIndicator(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      isTyping: isTyping ?? this.isTyping,
      lastTypingTime: lastTypingTime ?? this.lastTypingTime,
    );
  }
}

/// Message delivery status
enum MessageDeliveryStatus { sending, sent, delivered, read, failed }

/// Controller for managing chat state and operations
class ChatController extends StateNotifier<ChatState> {
  ChatController() : super(const ChatState());

  /// Load conversations
  Future<void> loadConversations() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock conversations for now
      final conversations = _generateMockConversations();
      final unreadCounts = _generateMockUnreadCounts(conversations);
      final pinnedIds = ['conv_1', 'conv_3']; // Mock pinned conversations
      final archivedIds = ['conv_5']; // Mock archived conversations

      state = state.copyWith(
        conversations: conversations,
        filteredConversations: conversations,
        isLoading: false,
        unreadCounts: unreadCounts,
        pinnedConversationIds: pinnedIds,
        archivedConversationIds: archivedIds,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load messages for a specific conversation
  Future<void> loadMessages(String conversationId) async {
    if (state.isLoadingMessages) return;

    state = state.copyWith(isLoadingMessages: true, error: null);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock messages for now
      final messages = _generateMockMessages(conversationId);

      state = state.copyWith(messages: messages, isLoadingMessages: false);
    } catch (e) {
      state = state.copyWith(isLoadingMessages: false, error: e.toString());
    }
  }

  /// Load more messages for pagination
  Future<void> loadMoreMessages(String conversationId) async {
    if (state.isLoadingMoreMessages) return;

    state = state.copyWith(isLoadingMoreMessages: true);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock older messages for now
      final olderMessages = _generateMockOlderMessages(conversationId);
      final allMessages = [...olderMessages, ...state.messages];

      state = state.copyWith(
        messages: allMessages,
        isLoadingMoreMessages: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMoreMessages: false, error: e.toString());
    }
  }

  /// Send a message
  Future<void> sendMessage(
    String conversationId,
    String content, {
    List<dynamic>? attachments,
    String? replyToId,
  }) async {
    state = state.copyWith(isSendingMessage: true);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Create new message
      final newMessage = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        senderId: 'current_user', // This should come from auth
        content: content,
        sentAt: DateTime.now(),
        messageType: MessageType.text,
        replyTo: replyToId != null
            ? ReplyReference(
                messageId: replyToId,
                senderId: 'current_user',
                senderName: 'Current User',
                content: 'Reply to message',
                messageType: MessageType.text,
              )
            : null,
      );

      // Add to messages list
      final updatedMessages = [newMessage, ...state.messages];

      state = state.copyWith(
        messages: updatedMessages,
        isSendingMessage: false,
      );
    } catch (e) {
      state = state.copyWith(isSendingMessage: false, error: e.toString());
    }
  }

  /// Send a voice message
  Future<void> sendVoiceMessage(
    String conversationId,
    String audioPath,
    Duration duration, {
    String? replyToId,
  }) async {
    state = state.copyWith(isSendingMessage: true);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Create new voice message
      final newMessage = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        senderId: 'current_user', // This should come from auth
        content: 'Voice message',
        sentAt: DateTime.now(),
        messageType: MessageType.audio,
        replyTo: replyToId != null
            ? ReplyReference(
                messageId: replyToId,
                senderId: 'current_user',
                senderName: 'Current User',
                content: 'Reply to message',
                messageType: MessageType.text,
              )
            : null,
        mediaAttachments: [
          MediaAttachment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            url: audioPath,
            type: AttachmentType.audio,
            name: 'voice_message.m4a',
            size: 0,
            mimeType: 'audio/m4a',
          ),
        ],
      );

      // Add to messages list
      final updatedMessages = [newMessage, ...state.messages];

      state = state.copyWith(
        messages: updatedMessages,
        isSendingMessage: false,
      );
    } catch (e) {
      state = state.copyWith(isSendingMessage: false, error: e.toString());
    }
  }

  /// Get or create a conversation
  Future<String?> getOrCreateConversation(String userId) async {
    try {
      // Check if conversation already exists
      ConversationModel? existingConversation;
      try {
        existingConversation = state.conversations.firstWhere(
          (conv) => conv.participants.any((p) => p.id == userId),
        );
      } catch (e) {
        // No existing conversation found
        existingConversation = null;
      }

      if (existingConversation != null) {
        return existingConversation.id;
      }

      // Create new conversation
      final newConversation = ConversationModel(
        id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
        type: ConversationType.direct,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        name: 'New Conversation',
        participants: [
          ConversationParticipant(
            id: userId,
            name: 'User $userId',
            avatar: '',
            verified: false,
            isOnline: false,
            lastSeen: DateTime.now(),
            joinedAt: DateTime.now(),
          ),
        ],
        lastMessage: null,
        unreadCount: 0,
        metadata: {},
      );

      final updatedConversations = [newConversation, ...state.conversations];
      state = state.copyWith(conversations: updatedConversations);

      return newConversation.id;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Update typing status
  void updateTypingStatus(String conversationId, bool isTyping) {
    // This would typically update typing indicators
    // For now, just update the state
    state = state.copyWith(isTypingSomeone: isTyping);
  }

  /// React to a message
  void reactToMessage(String messageId, String reaction) {
    // This would typically update the message with reactions
    // For now, just log the action
  }

  /// Delete a message
  void deleteMessage(String messageId) {
    final updatedMessages = state.messages
        .where((m) => m.id != messageId)
        .toList();
    state = state.copyWith(messages: updatedMessages);
  }

  /// Resend a failed message
  void resendMessage(String messageId) {
    // This would typically retry sending a failed message
    // For now, just log the action
  }

  /// Search conversations
  void searchConversations(String query) {
    if (query.isEmpty) {
      state = state.copyWith(
        searchQuery: query,
        filteredConversations: state.conversations,
      );
      return;
    }

    final filtered = state.conversations.where((conv) {
      final searchLower = query.toLowerCase();
      return (conv.name?.toLowerCase().contains(searchLower) ?? false) ||
          conv.participants.any(
            (user) => user.name.toLowerCase().contains(searchLower),
          );
    }).toList();

    state = state.copyWith(searchQuery: query, filteredConversations: filtered);
  }

  /// Pin/unpin conversation
  void togglePinConversation(String conversationId) {
    final pinnedIds = List<String>.from(state.pinnedConversationIds);

    if (pinnedIds.contains(conversationId)) {
      pinnedIds.remove(conversationId);
    } else {
      pinnedIds.add(conversationId);
    }

    state = state.copyWith(pinnedConversationIds: pinnedIds);
  }

  /// Archive/unarchive conversation
  void toggleArchiveConversation(String conversationId) {
    final archivedIds = List<String>.from(state.archivedConversationIds);

    if (archivedIds.contains(conversationId)) {
      archivedIds.remove(conversationId);
    } else {
      archivedIds.add(conversationId);
    }

    state = state.copyWith(archivedConversationIds: archivedIds);
  }

  /// Mark conversation as read
  void markConversationAsRead(String conversationId) {
    markConversationRead(conversationId);
  }

  /// Mark conversation as read (alias for markConversationAsRead)
  void markConversationRead(String conversationId) {
    final unreadCounts = Map<String, int>.from(state.unreadCounts);
    unreadCounts[conversationId] = 0;

    state = state.copyWith(unreadCounts: unreadCounts);
  }

  /// Refresh conversations
  Future<void> refreshConversations() async {
    await loadConversations();
  }

  /// Mark all conversations as read
  void markAllConversationsRead() {
    final unreadCounts = <String, int>{};
    for (final conversation in state.conversations) {
      unreadCounts[conversation.id] = 0;
    }

    state = state.copyWith(unreadCounts: unreadCounts);
  }

  /// Mark conversation as unread
  void markConversationUnread(String conversationId) {
    final unreadCounts = Map<String, int>.from(state.unreadCounts);
    unreadCounts[conversationId] = (unreadCounts[conversationId] ?? 0) + 1;

    state = state.copyWith(unreadCounts: unreadCounts);
  }

  /// Archive conversation
  void archiveConversation(String conversationId) {
    final archivedIds = List<String>.from(state.archivedConversationIds);
    if (!archivedIds.contains(conversationId)) {
      archivedIds.add(conversationId);
      state = state.copyWith(archivedConversationIds: archivedIds);
    }
  }

  /// Unarchive conversation
  void unarchiveConversation(String conversationId) {
    final archivedIds = List<String>.from(state.archivedConversationIds);
    if (archivedIds.contains(conversationId)) {
      archivedIds.remove(conversationId);
      state = state.copyWith(archivedConversationIds: archivedIds);
    }
  }

  /// Pin conversation
  void pinConversation(String conversationId) {
    final pinnedIds = List<String>.from(state.pinnedConversationIds);
    if (!pinnedIds.contains(conversationId)) {
      pinnedIds.add(conversationId);
      state = state.copyWith(pinnedConversationIds: pinnedIds);
    }
  }

  /// Unpin conversation
  void unpinConversation(String conversationId) {
    final pinnedIds = List<String>.from(state.pinnedConversationIds);
    if (pinnedIds.contains(conversationId)) {
      pinnedIds.remove(conversationId);
      state = state.copyWith(pinnedConversationIds: pinnedIds);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Missing methods needed by chat screens

  /// Load conversation details
  Future<void> loadConversationDetails(String conversationId) async {
    // Stub implementation - find conversation in current state
    final conversation = state.conversations.firstWhere(
      (conv) => conv.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    state = state.copyWith(activeConversation: conversation);
  }

  /// Load conversation media
  Future<void> loadConversationMedia(String conversationId) async {
    // Stub implementation - this would load media files from the conversation
    // For now, just mark as loaded
  }

  /// Update conversation name
  Future<void> updateConversationName(
    String conversationId,
    String name,
  ) async {
    final conversations = state.conversations.map((conv) {
      if (conv.id == conversationId) {
        return conv.copyWith(name: name);
      }
      return conv;
    }).toList();

    state = state.copyWith(conversations: conversations);
  }

  /// Update conversation description
  Future<void> updateConversationDescription(
    String conversationId,
    String description,
  ) async {
    final conversations = state.conversations.map((conv) {
      if (conv.id == conversationId) {
        return conv.copyWith(description: description);
      }
      return conv;
    }).toList();

    state = state.copyWith(conversations: conversations);
  }

  /// Make participant admin
  Future<void> makeParticipantAdmin(
    String conversationId,
    String participantId,
  ) async {
    // Stub implementation
    // This would update participant roles in the conversation
  }

  /// Remove participant admin
  Future<void> removeParticipantAdmin(
    String conversationId,
    String participantId,
  ) async {
    // Stub implementation
    // This would update participant roles in the conversation
  }

  /// Remove participant
  Future<void> removeParticipant(
    String conversationId,
    String participantId,
  ) async {
    // Stub implementation
    // This would remove participant from the conversation
  }

  /// Mute conversation
  Future<void> muteConversation(String conversationId) async {
    // Stub implementation
    // This would mute notifications for the conversation
  }

  /// Unmute conversation
  Future<void> unmuteConversation(String conversationId) async {
    // Stub implementation
    // This would unmute notifications for the conversation
  }

  /// Update read receipts enabled
  Future<void> updateReadReceiptsEnabled(
    String conversationId,
    bool enabled,
  ) async {
    // Stub implementation
    // This would update conversation settings
  }

  /// Update member invites enabled
  Future<void> updateMemberInvitesEnabled(
    String conversationId,
    bool enabled,
  ) async {
    // Stub implementation
    // This would update conversation settings
  }

  /// Clear chat history
  Future<void> clearChatHistory(String conversationId) async {
    // Stub implementation
    // This would clear all messages in the conversation
    state = state.copyWith(messages: []);
  }

  /// Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    final conversations = state.conversations
        .where((conv) => conv.id != conversationId)
        .toList();

    state = state.copyWith(conversations: conversations);
  }

  /// Leave conversation
  Future<void> leaveConversation(String conversationId) async {
    final conversations = state.conversations
        .where((conv) => conv.id != conversationId)
        .toList();

    state = state.copyWith(conversations: conversations);
  }

  /// Generate mock conversations for testing
  List<ConversationModel> _generateMockConversations() {
    return List.generate(10, (index) {
      final conversationId = 'conv_${index + 1}';
      final participants = List.generate(
        index % 3 + 1, // 1-3 participants
        (participantIndex) => ConversationParticipant(
          id: 'user_${index}_$participantIndex',
          name: 'User ${index + 1}_${participantIndex + 1}',
          avatar: '',
          verified: false,
          isOnline: index % 2 == 0,
          lastSeen: DateTime.now().subtract(Duration(hours: index)),
          joinedAt: DateTime.now().subtract(Duration(days: index)),
        ),
      );

      final lastMessage = ChatMessageModel(
        id: 'msg_${index + 1}',
        conversationId: conversationId,
        senderId: participants.first.id,
        content:
            'This is the last message in conversation ${index + 1}. It contains some sample text to demonstrate the chat functionality.',
        sentAt: DateTime.now().subtract(Duration(hours: index)),
        messageType: MessageType.text,
      );

      return ConversationModel(
        id: conversationId,
        type: index % 3 == 0 ? ConversationType.group : ConversationType.direct,
        createdAt: DateTime.now().subtract(Duration(days: index)),
        updatedAt: DateTime.now().subtract(Duration(hours: index)),
        name: 'Conversation ${index + 1}',
        participants: participants,
        lastMessage: lastMessage,
        unreadCount: index % 3,
        metadata: {
          'type': index % 3 == 0 ? 'group' : 'direct',
          'theme': index % 2 == 0 ? 'default' : 'dark',
        },
      );
    });
  }

  /// Generate mock unread counts for conversations
  Map<String, int> _generateMockUnreadCounts(
    List<ConversationModel> conversations,
  ) {
    final unreadCounts = <String, int>{};

    for (final conv in conversations) {
      unreadCounts[conv.id] = conv.unreadCount;
    }

    return unreadCounts;
  }

  /// Generate mock messages for testing
  List<ChatMessageModel> _generateMockMessages(String conversationId) {
    return List.generate(20, (index) {
      final isCurrentUser = index % 2 == 0;
      final senderId = isCurrentUser ? 'current_user' : 'other_user';

      return ChatMessageModel(
        id: 'msg_${conversationId}_$index',
        conversationId: conversationId,
        senderId: senderId,
        content:
            'This is message ${index + 1} in conversation $conversationId. It contains some sample text to demonstrate the chat functionality.',
        sentAt: DateTime.now().subtract(Duration(minutes: index * 5)),
        messageType: MessageType.text,
      );
    });
  }

  /// Generate mock older messages for pagination
  List<ChatMessageModel> _generateMockOlderMessages(String conversationId) {
    return List.generate(10, (index) {
      final isCurrentUser = index % 2 == 0;
      final senderId = isCurrentUser ? 'current_user' : 'other_user';

      return ChatMessageModel(
        id: 'msg_${conversationId}_old_$index',
        conversationId: conversationId,
        senderId: senderId,
        content:
            'This is older message ${index + 1} in conversation $conversationId.',
        sentAt: DateTime.now().subtract(Duration(hours: index + 1)),
        messageType: MessageType.text,
      );
    });
  }
}

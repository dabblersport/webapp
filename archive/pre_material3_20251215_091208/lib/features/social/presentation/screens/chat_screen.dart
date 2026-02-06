import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/data/models/social/chat_message_model.dart';
import '../widgets/chat/chat_bubble.dart';
import 'package:dabbler/widgets/avatar_widget.dart';
import 'package:dabbler/utils/enums/social_enums.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String userName;
  final String? conversationId;

  const ChatScreen({super.key, required this.userName, this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // For now, add some sample messages
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _messages.clear();
        _messages.addAll([
          ChatMessageModel(
            id: '1',
            conversationId: widget.conversationId ?? 'conv1',
            senderId: 'other_user',
            content: 'Hey! How are you doing?',
            sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
            messageType: MessageType.text,
          ),
          ChatMessageModel(
            id: '2',
            conversationId: widget.conversationId ?? 'conv1',
            senderId: 'current_user',
            content: 'I\'m doing great! Thanks for asking. How about you?',
            sentAt: DateTime.now().subtract(const Duration(minutes: 3)),
            messageType: MessageType.text,
          ),
        ]);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load messages: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    final message = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversationId ?? 'conv1',
      senderId: 'current_user',
      content: text.trim(),
      sentAt: DateTime.now(),
      messageType: MessageType.text,
    );

    setState(() {
      _messages.insert(0, message);
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AvatarWidget(imageUrl: null, name: widget.userName, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.userName, style: context.textTheme.titleMedium),
                  Text(
                    'Online',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice call coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat info coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: context.colors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colors.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final previousMessage = index < _messages.length - 1
            ? _messages[index + 1]
            : null;
        final isConsecutive =
            previousMessage != null &&
            previousMessage.senderId == message.senderId &&
            message.sentAt.difference(previousMessage.sentAt).inMinutes < 5;

        return ChatBubble(
          message: message,
          isConsecutive: isConsecutive,
          showAvatar: !isConsecutive,
          showTimestamp: true,
          showReadReceipts: true,
          onTap: () {},
          onLongPress: () {},
          onReply: () {},
          onReact: () {},
        );
      },
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          top: BorderSide(color: context.colors.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attachments coming soon!')),
              );
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.colors.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: _handleSubmitted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                _handleSubmitted(_messageController.text);
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

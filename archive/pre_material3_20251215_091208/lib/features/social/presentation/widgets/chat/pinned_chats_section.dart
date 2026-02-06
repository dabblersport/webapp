import 'package:flutter/material.dart';
import 'package:dabbler/data/models/social/conversation_model.dart';
import 'conversation_tile.dart';

class PinnedChatsSection extends StatelessWidget {
  final List<ConversationModel> conversations;
  final Map<String, int> unreadCounts;
  final Function(ConversationModel) onConversationTap;
  final Function(ConversationModel, String) onConversationAction;

  const PinnedChatsSection({
    super.key,
    required this.conversations,
    required this.unreadCounts,
    required this.onConversationTap,
    required this.onConversationAction,
  });

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Pinned',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final unreadCount = unreadCounts[conversation.id] ?? 0;

            return ConversationTile(
              key: Key(conversation.id),
              conversation: conversation,
              lastMessage: conversation.lastMessage,
              unreadCount: unreadCount,
              isPinned: true,
              isMuted: false,
              isArchived: false,
              onTap: () => onConversationTap(conversation),
              onLongPress: () =>
                  _showConversationOptions(context, conversation),
              onSwipeArchive: () =>
                  onConversationAction(conversation, 'archive'),
              onSwipePin: () => onConversationAction(conversation, 'unpin'),
              onSwipeDelete: () => onConversationAction(conversation, 'delete'),
            );
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _showConversationOptions(
    BuildContext context,
    ConversationModel conversation,
  ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.push_pin, color: theme.colorScheme.primary),
              title: const Text('Unpin'),
              onTap: () {
                Navigator.pop(context);
                onConversationAction(conversation, 'unpin');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.archive,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(context);
                onConversationAction(conversation, 'archive');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: theme.colorScheme.error),
              title: Text(
                'Delete',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                onConversationAction(conversation, 'delete');
              },
            ),
          ],
        ),
      ),
    );
  }
}

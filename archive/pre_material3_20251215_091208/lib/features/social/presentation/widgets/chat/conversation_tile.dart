import 'package:flutter/material.dart';
import 'package:dabbler/data/models/social/conversation_model.dart';
import 'package:dabbler/data/models/social/chat_message_model.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final ChatMessageModel? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeArchive;
  final VoidCallback? onSwipePin;
  final VoidCallback? onSwipeDelete;

  const ConversationTile({
    super.key,
    required this.conversation,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.onTap,
    this.onLongPress,
    this.onSwipeArchive,
    this.onSwipePin,
    this.onSwipeDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _showDismissDialog(context),
      onDismissed: (direction) => onSwipeDelete?.call(),
      background: _buildDismissBackground(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildAvatar(theme),
        title: _buildTitle(theme),
        subtitle: _buildSubtitle(theme),
        trailing: _buildTrailing(theme),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: conversation.avatarUrl != null
              ? NetworkImage(conversation.avatarUrl!)
              : null,
          child: conversation.avatarUrl == null
              ? Text(
                  conversation.name?.substring(0, 1).toUpperCase() ?? 'C',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        if (isPinned)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.push_pin,
                size: 12,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            conversation.name ?? 'Unnamed Chat',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              color: isMuted
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isMuted)
          Icon(
            Icons.notifications_off,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    if (lastMessage == null) {
      return Text(
        'No messages yet',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      children: [
        if (lastMessage!.senderId == 'current_user')
          Icon(
            Icons.done_all,
            size: 16,
            color: lastMessage!.readBy.isNotEmpty
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            lastMessage!.previewText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: unreadCount > 0
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatTime(lastMessage?.sentAt ?? conversation.updatedAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete, color: Colors.white, size: 24),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<bool?> _showDismissDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class FriendshipActionsSection extends StatelessWidget {
  final String friendshipStatus;
  final bool isBlocked;
  final VoidCallback onSendRequest;
  final VoidCallback onAcceptRequest;
  final VoidCallback onDeclineRequest;
  final VoidCallback onCancelRequest;
  final VoidCallback onUnfriend;
  final VoidCallback onMessage;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  const FriendshipActionsSection({
    super.key,
    required this.friendshipStatus,
    required this.isBlocked,
    required this.onSendRequest,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onCancelRequest,
    required this.onUnfriend,
    required this.onMessage,
    required this.onBlock,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isBlocked) {
      return _buildBlockedActions(theme);
    }

    switch (friendshipStatus.toLowerCase()) {
      case 'friends':
        return _buildFriendsActions(theme);
      case 'request sent':
        return _buildRequestSentActions(theme);
      case 'request received':
        return _buildRequestReceivedActions(theme);
      default:
        return _buildNoFriendshipActions(theme);
    }
  }

  Widget _buildNoFriendshipActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onSendRequest,
            icon: const Icon(Icons.person_add),
            label: const Text('Send Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.message),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestSentActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCancelRequest,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel Request'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.message),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestReceivedActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onAcceptRequest,
            icon: const Icon(Icons.check),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDeclineRequest,
            icon: const Icon(Icons.close),
            label: const Text('Decline'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.message),
            label: const Text('Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onUnfriend,
            icon: const Icon(Icons.person_remove),
            label: const Text('Unfriend'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.error),
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockedActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onUnblock,
            icon: const Icon(Icons.person),
            label: const Text('Unblock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

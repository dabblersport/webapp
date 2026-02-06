import 'package:flutter/material.dart';
import 'package:dabbler/data/models/social/friend_request_model.dart';
import 'package:dabbler/data/models/social/friend_request.dart';
import 'package:dabbler/data/models/authentication/user_model.dart' as core;

/// Widget for displaying sent friend requests
class SentRequestCard extends StatelessWidget {
  final FriendRequestModel request;
  final core.UserModel? toUser;
  final VoidCallback? onCancel;
  final VoidCallback? onResend;
  final bool isLoading;

  const SentRequestCard({
    super.key,
    required this.request,
    this.toUser,
    this.onCancel,
    this.onResend,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: toUser?.profileImageUrl != null
                      ? NetworkImage(toUser!.profileImageUrl!)
                      : null,
                  child: toUser?.profileImageUrl == null
                      ? Text(
                          (toUser?.displayName != null &&
                                  toUser!.displayName.isNotEmpty
                              ? toUser!.displayName
                                    .substring(0, 1)
                                    .toUpperCase()
                              : 'U'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        toUser?.displayName ?? 'Unknown User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (toUser?.email != null)
                        Text(
                          toUser!.email!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(theme),
              ],
            ),

            const SizedBox(height: 16),

            // Request details
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sent ${_formatDate(request.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    child: Text(
                      'Cancel Request',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onResend,
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme) {
    Color chipColor;
    String statusText;

    switch (request.status) {
      case FriendRequestStatus.pending:
        chipColor = theme.colorScheme.primary;
        statusText = 'Pending';
        break;
      case FriendRequestStatus.accepted:
        chipColor = theme.colorScheme.tertiary;
        statusText = 'Accepted';
        break;
      case FriendRequestStatus.declined:
        chipColor = theme.colorScheme.error;
        statusText = 'Declined';
        break;
      case FriendRequestStatus.cancelled:
        chipColor = theme.colorScheme.outline;
        statusText = 'Cancelled';
        break;
      default:
        chipColor = theme.colorScheme.outline;
        statusText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        statusText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

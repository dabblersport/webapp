import 'package:flutter/material.dart';

class ChatInfoSection extends StatelessWidget {
  final dynamic conversation;
  final VoidCallback? onEditName;
  final VoidCallback? onEditDescription;
  final VoidCallback? onEditAvatar;

  const ChatInfoSection({
    super.key,
    required this.conversation,
    this.onEditName,
    this.onEditDescription,
    this.onEditAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chat avatar and name
            Row(
              children: [
                GestureDetector(
                  onTap: onEditAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: conversation.avatarUrl != null
                            ? NetworkImage(conversation.avatarUrl!)
                            : null,
                        child: conversation.avatarUrl == null
                            ? Text(
                                conversation.name
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    '?',
                                style: theme.textTheme.headlineMedium,
                              )
                            : null,
                      ),
                      if (onEditAvatar != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name ?? 'Unnamed Chat',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (onEditName != null)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: onEditName,
                              tooltip: 'Edit Name',
                            ),
                        ],
                      ),
                      if (conversation.description != null &&
                          conversation.description!.isNotEmpty)
                        Text(
                          conversation.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        conversation.isGroup ? 'Group Chat' : 'Direct Message',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (onEditDescription != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Description',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onEditDescription,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

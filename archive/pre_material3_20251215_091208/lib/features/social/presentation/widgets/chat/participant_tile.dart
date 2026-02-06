import 'package:flutter/material.dart';

class ParticipantTile extends StatelessWidget {
  final dynamic participant;
  final bool isAdmin;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback? onMakeAdmin;
  final VoidCallback? onRemoveAdmin;
  final VoidCallback? onRemove;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isAdmin = false,
    this.canManage = false,
    this.onTap,
    this.onMakeAdmin,
    this.onRemoveAdmin,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: participant.avatarUrl != null
            ? NetworkImage(participant.avatarUrl!)
            : null,
        child: participant.avatarUrl == null
            ? Text(participant.name?.substring(0, 1).toUpperCase() ?? '?')
            : null,
      ),
      title: Text(
        participant.name ?? 'Unknown User',
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        isAdmin ? 'Admin' : 'Member',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: canManage ? _buildActionButtons(context) : null,
      onTap: onTap,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMakeAdmin != null && !isAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: onMakeAdmin,
            tooltip: 'Make Admin',
            iconSize: 20,
          ),
        if (onRemoveAdmin != null && isAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: onRemoveAdmin,
            tooltip: 'Remove Admin',
            iconSize: 20,
          ),
        if (onRemove != null)
          IconButton(
            icon: Icon(Icons.person_remove, color: theme.colorScheme.error),
            onPressed: onRemove,
            tooltip: 'Remove Participant',
            iconSize: 20,
          ),
      ],
    );
  }
}

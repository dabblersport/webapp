import 'package:flutter/material.dart';

/// Widget to display a single mentioned user chip
class MentionChip extends StatelessWidget {
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final bool isVerified;
  final VoidCallback? onTap;

  const MentionChip({
    super.key,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.isVerified = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl != null && avatarUrl!.isNotEmpty) ...[
              CircleAvatar(
                radius: 10,
                backgroundImage: NetworkImage(avatarUrl!),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '@${username ?? displayName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.verified,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget to display list of mentioned users
class MentionsList extends StatelessWidget {
  final List<Map<String, dynamic>> mentions;
  final Function(Map<String, dynamic>)? onMentionTap;

  const MentionsList({super.key, required this.mentions, this.onMentionTap});

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mentions.map((mention) {
        final profile = mention['profiles'] ?? mention;
        return MentionChip(
          displayName: profile['display_name'] ?? 'User',
          username: profile['username'],
          avatarUrl: profile['avatar_url'],
          isVerified: profile['verified'] == true,
          onTap: onMentionTap != null ? () => onMentionTap!(mention) : null,
        );
      }).toList(),
    );
  }
}

/// Widget to display mentions with a label
class MentionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> mentions;
  final Function(Map<String, dynamic>)? onMentionTap;
  final String? label;

  const MentionsSection({
    super.key,
    required this.mentions,
    this.onMentionTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        MentionsList(mentions: mentions, onMentionTap: onMentionTap),
      ],
    );
  }
}

/// Detailed list view of mentions with avatars
class MentionsListView extends StatelessWidget {
  final List<Map<String, dynamic>> mentions;
  final Function(Map<String, dynamic>)? onMentionTap;

  const MentionsListView({
    super.key,
    required this.mentions,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No mentions'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mentions.length,
      itemBuilder: (context, index) {
        final mention = mentions[index];
        final profile = mention['profiles'] ?? mention;

        final displayName = profile['display_name'] ?? 'Unknown';
        final username = profile['username'];
        final avatarUrl = profile['avatar_url'];
        final isVerified = profile['verified'] == true;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(displayName[0].toUpperCase())
                : null,
          ),
          title: Row(
            children: [
              Text(displayName),
              if (isVerified) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
          subtitle: username != null ? Text('@$username') : null,
          onTap: onMentionTap != null ? () => onMentionTap!(mention) : null,
        );
      },
    );
  }
}

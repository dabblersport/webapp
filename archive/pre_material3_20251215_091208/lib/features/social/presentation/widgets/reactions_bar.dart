import 'package:flutter/material.dart';

/// Widget to display a single reaction with count
class ReactionItem extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isUserReaction;
  final VoidCallback? onTap;

  const ReactionItem({
    super.key,
    required this.emoji,
    required this.count,
    this.isUserReaction = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isUserReaction
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUserReaction
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isUserReaction ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isUserReaction ? FontWeight.w600 : FontWeight.w500,
                color: isUserReaction
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display grouped reactions with counts
class ReactionsBar extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final String? currentUserId;
  final Function(Map<String, dynamic>)? onReactionTap;

  const ReactionsBar({
    super.key,
    required this.reactions,
    this.currentUserId,
    this.onReactionTap,
  });

  /// Group reactions by vibe_id and count them
  Map<String, List<Map<String, dynamic>>> _groupReactions() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (var reaction in reactions) {
      final vibeId = reaction['vibe_id']?.toString() ?? '';
      if (vibeId.isNotEmpty) {
        grouped.putIfAbsent(vibeId, () => []).add(reaction);
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final grouped = _groupReactions();
    if (grouped.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: grouped.entries.map((entry) {
        final vibeId = entry.key;
        final reactionsList = entry.value;
        final count = reactionsList.length;

        // Get vibe data from first reaction
        final vibeData = reactionsList.first['vibes'];
        final emoji = vibeData?['emoji'] ?? '👍';

        // Check if current user has this reaction
        final isUserReaction =
            currentUserId != null &&
            reactionsList.any((r) {
              final profile = r['profiles'];
              return profile?['user_id'] == currentUserId;
            });

        return ReactionItem(
          emoji: emoji,
          count: count,
          isUserReaction: isUserReaction,
          onTap: onReactionTap != null
              ? () => onReactionTap!({
                  'vibe_id': vibeId,
                  'reactions': reactionsList,
                })
              : null,
        );
      }).toList(),
    );
  }
}

/// Widget to display detailed list of reactions with user avatars
class ReactionsListView extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final Function(Map<String, dynamic>)? onUserTap;

  const ReactionsListView({super.key, required this.reactions, this.onUserTap});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No reactions yet'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reactions.length,
      itemBuilder: (context, index) {
        final reaction = reactions[index];
        final profile = reaction['profiles'];
        final vibe = reaction['vibes'];

        final displayName = profile?['display_name'] ?? 'Unknown';
        final avatarUrl = profile?['avatar_url'];
        final emoji = vibe?['emoji'] ?? '👍';
        final reactedAt = reaction['reacted_at'];

        return ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(displayName[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 4),
              Text(emoji, style: const TextStyle(fontSize: 20)),
            ],
          ),
          title: Text(displayName),
          subtitle: reactedAt != null ? Text(_formatTime(reactedAt)) : null,
          onTap: onUserTap != null ? () => onUserTap!(profile ?? {}) : null,
        );
      },
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';
import '../../../../../../utils/enums/social_enums.dart';

class PostPreviewWidget extends StatelessWidget {
  final String content;
  final List<dynamic> selectedMedia;
  final List<String> selectedSports;
  final String? selectedLocation;
  final PostVisibility visibility;
  final DateTime? scheduledTime;

  const PostPreviewWidget({
    super.key,
    required this.content,
    required this.selectedMedia,
    required this.selectedSports,
    required this.selectedLocation,
    required this.visibility,
    required this.scheduledTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const AppAvatar.small(fallbackText: 'User'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current User',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Just now',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _getVisibilityIcon(visibility),
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Content
          if (content.isNotEmpty)
            Text(content, style: theme.textTheme.bodyLarge),

          // Media preview
          if (selectedMedia.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            ),
          ],

          // Sports tags
          if (selectedSports.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedSports.map((sport) {
                return Chip(
                  label: Text(sport),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                );
              }).toList(),
            ),
          ],

          // Location
          if (selectedLocation != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  selectedLocation!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],

          // Scheduled time
          if (scheduledTime != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Scheduled for ${_formatScheduledTime(scheduledTime!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getVisibilityIcon(PostVisibility visibility) {
    switch (visibility) {
      case PostVisibility.public:
        return Icons.public;
      case PostVisibility.friends:
        return Icons.people;
      case PostVisibility.private:
        return Icons.lock;
      case PostVisibility.gameParticipants:
        return Icons.sports_esports;
    }
  }

  String _formatScheduledTime(DateTime time) {
    final now = DateTime.now();
    final difference = time.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}

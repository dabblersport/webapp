import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/activity_feed_event.dart';

/// Reusable widget for rendering an activity event card.
///
/// This widget handles different subject types and verbs gracefully,
/// with a fallback for unknown combinations.
class ActivityEventCard extends StatelessWidget {
  final ActivityFeedEvent event;
  final VoidCallback? onTap;

  const ActivityEventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.1), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitle(context),
                        const SizedBox(height: 4),
                        _buildSubtitle(context),
                      ],
                    ),
                  ),
                  if (event.payload?['role'] != null) _buildRoleBadge(context),
                ],
              ),
              const SizedBox(height: 8),
              _buildTimestamp(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    IconData icon;
    Color iconColor;

    // Determine icon based on subject type and verb
    if (event.subjectType == 'game') {
      icon = Icons.sports_soccer;
      iconColor = colorScheme.primary;
    } else if (event.subjectType == 'payment') {
      icon = Icons.payment;
      iconColor = Colors.green;
    } else if (event.subjectType == 'reward') {
      icon = Icons.military_tech;
      iconColor = Colors.amber;
    } else if (event.subjectType == 'social') {
      icon = Icons.people;
      iconColor = Colors.blue;
    } else {
      // Generic icon for unknown types
      icon = Icons.event;
      iconColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _getTitleText();

    return Text(
      title,
      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = _getSubtitleText();

    if (subtitle == null) {
      return const SizedBox.shrink();
    }

    return Text(
      subtitle,
      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildRoleBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final role = event.payload?['role'] as String?;

    if (role == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = _formatDate(event.happenedAt);

    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          formattedDate,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Generates the title text based on subject type and verb.
  String _getTitleText() {
    // Handle known combinations
    if (event.subjectType == 'game' && event.verb == 'created') {
      return 'You hosted a game';
    } else if (event.subjectType == 'game' && event.verb == 'joined') {
      return 'You joined a game';
    } else if (event.subjectType == 'game' && event.verb == 'left') {
      return 'You left a game';
    } else if (event.subjectType == 'payment' &&
        event.verb == 'payment_succeeded') {
      return 'Payment successful';
    } else if (event.subjectType == 'reward' && event.verb == 'earned') {
      return 'Reward earned';
    }

    // Fallback for unknown combinations - be descriptive
    final subjectTypeFormatted = event.subjectType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
    final verbFormatted = event.verb
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return '$verbFormatted $subjectTypeFormatted';
  }

  /// Generates the subtitle text based on event data.
  String? _getSubtitleText() {
    // For now, we don't have much context in the payload
    // This can be extended when backend adds more fields like title, sport, etc.
    if (event.payload?['title'] != null) {
      return event.payload!['title'] as String;
    }

    // Return null if no subtitle available
    return null;
  }

  /// Formats the date for display.
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return 'Today • ${DateFormat('h:mm a').format(date)}';
    } else if (eventDate == yesterday) {
      return 'Yesterday • ${DateFormat('h:mm a').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE • h:mm a').format(date);
    } else {
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    }
  }
}

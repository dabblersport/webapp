import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../data/models/activity_feed_event.dart';

/// Reusable widget for rendering an activity event card.
///
/// This widget handles different subject types and verbs gracefully,
/// with a fallback for unknown combinations. Drawn as a
/// [DabblerActivityRow]: a system tile for the subject type, the title as the
/// actor line, the payload title as the subject line, the timestamp as the
/// meta line and the role as the end badge.
class ActivityEventCard extends StatelessWidget {
  final ActivityFeedEvent event;
  final VoidCallback? onTap;

  const ActivityEventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final role = event.payload?['role'] as String?;

    return DabblerActivityRow(
      leading: DabblerActivitySystemTile(_iconName()),
      actor: _getTitleText(),
      subject: _getSubtitleText(),
      when: _formatDate(event.happenedAt),
      sportLabel: role?.toUpperCase(),
      onTap: onTap,
    );
  }

  /// Design-system glyph for the subject type; a calendar for unknown types.
  String _iconName() {
    switch (event.subjectType) {
      case 'game':
        return 'game';
      case 'payment':
        return 'card';
      case 'reward':
        return 'medal-star';
      case 'social':
        return 'people';
      default:
        return 'calendar';
    }
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

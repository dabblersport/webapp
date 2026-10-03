// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: an activity entry is one DabblerActivityRow with a tinted DS icon
// tile. The timeline connector between rows is gone (the DS row is a card);
// [isLast] stays on the constructor and is ignored.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'notif_visual.dart';

class ActivityRow extends StatelessWidget {
  final ActivityFeedEvent event;
  final bool isLast;
  final VoidCallback onTap;
  const ActivityRow({
    super.key,
    required this.event,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visual = _activityVisual(event);
    final pill = _activityPill(context, event);
    final upcoming =
        event.timeBucket == 'upcoming' ? l10n.activity_pill_upcoming : null;
    // The DS row has one neutral badge slot; both labels share it when both
    // apply (they were two separate pills).
    final badge = [pill, upcoming].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
      ),
      child: DabblerActivityRow(
        leading: DabblerIconTile.named(
          visual.icon,
          tone: visual.tone,
          size: DabblerActivitySystemTile.size,
        ),
        actor: _activityTitle(event),
        subject: _activityMeta(context, event),
        when: _formatHM(event.happenedAt),
        live: event.timeBucket == 'present',
        liveLabel: l10n.activity_pill_live,
        sportLabel: badge.isEmpty ? null : badge,
        onTap: onTap,
      ),
    );
  }

  String _activityTitle(ActivityFeedEvent a) {
    final p = a.payload ?? {};
    if (p['title'] is String) return p['title'] as String;
    final verb = a.verb.replaceAll('_', ' ');
    final subj = a.subjectType;
    return '${verb[0].toUpperCase()}${verb.substring(1)} $subj';
  }

  String? _activityMeta(BuildContext context, ActivityFeedEvent a) {
    final p = a.payload ?? {};
    final parts = <String>[];
    for (final key in const [
      'description',
      'game_name',
      'venue_name',
      'user_name',
    ]) {
      final v = p[key];
      if (v is String && v.trim().isNotEmpty) {
        parts.add(v.trim());
        break;
      }
    }
    if (p['location'] is String) parts.add('at ${p['location']}');
    if (p['participants_count'] != null) {
      parts.add(AppLocalizations.of(context).activity_participants_count(p['participants_count'] as int));
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String? _activityPill(BuildContext context, ActivityFeedEvent a) {
    final p = a.payload ?? {};
    if (p['pill'] is String) return p['pill'] as String;
    final l10n = AppLocalizations.of(context);
    if (a.subjectType == 'reward') return l10n.activity_subject_reward;
    if (a.subjectType == 'security') return l10n.activity_subject_security;
    return null;
  }

  String _formatHM(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

NotifVisual _activityVisual(ActivityFeedEvent e) {
  switch (e.subjectType) {
    case 'game':
      return const NotifVisual('game', DabblerIconTileTone.amber);
    case 'booking':
      return const NotifVisual('ticket', DabblerIconTileTone.info);
    case 'social':
      return const NotifVisual('people', DabblerIconTileTone.brand);
    case 'reward':
      return const NotifVisual('coin', DabblerIconTileTone.amber);
    case 'security':
      return const NotifVisual('security', DabblerIconTileTone.info);
    case 'payment':
      return const NotifVisual('card', DabblerIconTileTone.info);
    case 'post':
      return const NotifVisual('edit', DabblerIconTileTone.brand);
    default:
      return const NotifVisual('info-circle', DabblerIconTileTone.brand);
  }
}

// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'notif_pill.dart';
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
    final cs = context.colorScheme;
    final visual = _activityVisual(event, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          visual.color.withValues(alpha: 0.20),
                          visual.color.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: visual.color.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(visual.icon, size: 16, color: visual.color),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: cs.onSurface.withValues(alpha: 0.10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.10),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _activityTitle(event),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatHM(event.happenedAt),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                        if (_activityMeta(context, event) != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            _activityMeta(context, event)!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                        if (_activityPill(context, event) != null ||
                            event.timeBucket != 'past') ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_activityPill(context, event) != null)
                                Pill(
                                  label: _activityPill(context, event)!,
                                  color: visual.color,
                                ),
                              if (event.timeBucket == 'upcoming')
                                Pill(label: AppLocalizations.of(context).activity_pill_upcoming, color: cs.primary),
                              if (event.timeBucket == 'present')
                                Pill(label: AppLocalizations.of(context).activity_pill_live, color: cs.error),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

NotifVisual _activityVisual(ActivityFeedEvent e, BuildContext context) {
  final cs = context.colorScheme;
  switch (e.subjectType) {
    case 'game':
      return const NotifVisual(Iconsax.game_copy, DesignTokens.warning);
    case 'booking':
      return const NotifVisual(Iconsax.ticket_copy, DesignTokens.success);
    case 'social':
      return NotifVisual(Iconsax.people_copy, cs.primary);
    case 'reward':
      return const NotifVisual(Iconsax.coin_copy, DesignTokens.warning);
    case 'security':
      return const NotifVisual(Iconsax.security_copy, DesignTokens.success);
    case 'payment':
      return const NotifVisual(Iconsax.card_copy, DesignTokens.success);
    case 'post':
      return NotifVisual(Iconsax.edit_copy, cs.primary);
    default:
      return NotifVisual(
        Iconsax.info_circle_copy,
        cs.onSurface.withValues(alpha: 0.5),
      );
  }
}

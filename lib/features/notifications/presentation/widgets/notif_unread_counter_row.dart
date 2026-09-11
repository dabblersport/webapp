// Extracted from notifications_screen_v2.dart by KAN-151 (pt.B of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class UnreadCounterRow extends StatelessWidget {
  final dynamic state;
  final VoidCallback onMarkAll;
  const UnreadCounterRow({
    super.key,
    required this.state,
    required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final accent = cs.error;
    final unread = state.unreadCount as int;
    final total = (state.notifications as List).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Iconsax.notification_copy,
                size: 15,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '$unread unread',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: onMarkAll,
              icon: Icon(
                Iconsax.tick_circle_copy,
                size: 14,
                color: scheme.primary,
              ),
              label: Text(
                AppLocalizations.of(context).notif_mark_all_read,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$total total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// Extracted from notifications_screen_v2.dart by KAN-151 (pt.B of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: "mark all read" moved to the top bar (design); [onMarkAll] stays on
// this row, shown as a text button, so the action is still reachable here when
// the caller passes it.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class UnreadCounterRow extends StatelessWidget {
  final dynamic state;
  final VoidCallback? onMarkAll;
  const UnreadCounterRow({super.key, required this.state, this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);
    final unread = state.unreadCount as int;
    final total = (state.notifications as List).length;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space4,
        DabblerSpacing.space6,
        DabblerSpacing.space2,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DabblerIcon(
                'notification',
                size: DabblerSizing.iconSm,
                color: colors.textSecondary,
              ),
              if (unread > 0)
                const PositionedDirectional(
                  top: -2,
                  end: -3,
                  child: DabblerBadge.dot(),
                ),
            ],
          ),
          const SizedBox(width: DabblerSpacing.space2),
          Text(
            '${DabblerType.toWesternDigits('$unread')} unread',
            style: DabblerType.footnote
                .resolveForDirection(dir)
                .copyWith(color: colors.textPrimary),
          ),
          if (unread > 0 && onMarkAll != null) ...[
            const SizedBox(width: DabblerSpacing.space2),
            DabblerButton(
              label: AppLocalizations.of(context).notif_mark_all_read,
              tone: DabblerButtonTone.text,
              size: DabblerButtonSize.small,
              onPressed: onMarkAll,
            ),
          ],
          const Spacer(),
          Text(
            '${DabblerType.toWesternDigits('$total')} total',
            style: DabblerType.footnote
                .resolveForDirection(dir)
                .copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

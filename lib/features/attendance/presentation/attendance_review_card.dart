// KAN-999 (G-06 organiser side): "Sara asked to review her attendance", her
// note, and Accept correction / Keep. Drawn with the inbox's card
// (DabblerNotificationCard, W1-F2) so it reads the same as the notice. After a
// decision the card shows the result the player was told.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendanceReviewCard extends ConsumerWidget {
  const AttendanceReviewCard({
    super.key,
    required this.row,
    required this.onDecide,
    this.decided,
    this.busy = false,
  });

  final AttendanceRow row;

  /// Null while open; true accepted, false kept.
  final bool? decided;
  final bool busy;
  final ValueChanged<bool> onDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final name = context.isolate(
      row.displayName?.trim().isNotEmpty == true
          ? row.displayName
          : l.g05_unknown_player,
    );
    final note = row.reviewNote;
    final deadline = row.reviewDeadline;
    final now = ref.watch(attendanceNowProvider)();
    return DabblerNotificationCard(
      key: ValueKey<String>('attendance-review-${row.userId}'),
      leading: DabblerAvatar(seed: name, size: DabblerAvatarSize.sm),
      actor: name,
      verb: l.g06_review_verb,
      unread: decided == null,
      excerpt: note == null || note.isEmpty
          ? null
          : DabblerNotificationExcerpt(
              label: l.g06_note_label,
              text: context.isolate(note),
            ),
      meta: <DabblerNotificationMeta>[
        if (decided == null && deadline != null)
          DabblerNotificationMeta(
            'clock',
            l.g06_review_due(hoursLeft(deadline, now)),
          ),
      ],
      pending: decided == null && busy ? l.g06_sending : null,
      result: decided == null
          ? null
          : DabblerNotificationResult(
              icon: decided! ? 'tick-circle' : 'close-circle',
              text: decided!
                  ? l.g06_accepted_result(name)
                  : l.g06_kept_result(name),
              tone: decided!
                  ? DabblerNotificationTone.ok
                  : DabblerNotificationTone.neutral,
            ),
      actions: decided != null || busy
          ? const <DabblerNotificationCardAction>[]
          : <DabblerNotificationCardAction>[
              DabblerNotificationCardAction(
                l.g06_accept,
                primary: true,
                onPressed: () => onDecide(true),
              ),
              DabblerNotificationCardAction(
                l.g06_keep,
                onPressed: () => onDecide(false),
              ),
            ],
    );
  }
}

// The in-place check-in confirmation: "Check in?" with Yes / No, opened from
// the game and meetup details. Yes calls the same controller as the check-in
// screen; the sheet closes once the server confirms, and a failure stays in
// the sheet. The check-in screen remains for notifications and deep links.

import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_controller.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showCheckInSheet(BuildContext context, String eventId) {
  final l = AppLocalizations.of(context);
  return showDabblerSheet<void>(
    context: context,
    title: l.g04_confirm_title,
    detent: DabblerSheetDetent.content,
    builder: (_) => CheckInSheet(eventId: eventId),
  );
}

class CheckInSheet extends ConsumerStatefulWidget {
  const CheckInSheet({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<CheckInSheet> {
  bool _asked = false;

  void _yes() {
    if (ref.read(attendanceCheckInProvider(widget.eventId)).submitting) return;
    setState(() => _asked = true);
    ref.read(attendanceCheckInProvider(widget.eventId).notifier).checkIn();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = attendanceCheckInProvider(widget.eventId);
    ref.listen(provider, (prev, next) {
      if (_asked && next.phase == CheckInPhase.checkedIn) {
        Navigator.of(context).maybePop();
      }
    });
    final state = ref.watch(provider);
    final submitting = state.submitting;
    final a = state.attendance;
    // The screen's mapping: a refusal is the state it names; anything else
    // is "Couldn't check in".
    final String? error = !_asked || submitting
        ? null
        : state.submitFailure != null
        ? l.g04_failed
        : switch (state.phase) {
            CheckInPhase.closed => l.g04_closed,
            CheckInPhase.notEligible => l.g04_not_eligible,
            CheckInPhase.cancelled => l.g04_cancelled,
            _ => null,
          };
    final canSubmit =
        state.phase == CheckInPhase.open ||
        state.phase == CheckInPhase.submitting;
    return DabblerSheetBody(
      actions: DabblerSheetActions(
        children: <Widget>[
          DabblerButton(
            key: const ValueKey<String>('check-in-sheet-yes'),
            label: submitting ? l.g04_submitting : l.g04_confirm_yes,
            fullWidth: true,
            size: DabblerButtonSize.full,
            loading: submitting,
            disabled: !canSubmit,
            onPressed: submitting || !canSubmit ? null : _yes,
          ),
          DabblerButton(
            key: const ValueKey<String>('check-in-sheet-no'),
            label: l.g04_confirm_no,
            tone: DabblerButtonTone.text,
            fullWidth: true,
            size: DabblerButtonSize.full,
            onPressed: submitting
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      children: <Widget>[
        DabblerText(
          a == null
              ? l.g04_open_body
              : '${l.g04_open_until(checkInClock(context, a.closesAt))} · '
                    '${l.g04_open_body}',
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        if (error != null)
          DabblerText(
            key: const ValueKey<String>('check-in-sheet-error'),
            error,
            style: DabblerType.footnote,
            tone: DabblerTextTone.error,
          ),
      ],
    );
  }
}

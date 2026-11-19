// The bottom bar of a game or meetup detail follows the player's check-in:
// inside the window the primary action is "Check in" and leaving drops to a
// small text action; once checked in, or once the window closes, leaving is
// gone. Used only for a participant who is not the host.

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_controller.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart';
import 'package:dabbler/features/attendance/presentation/check_in_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bar's actions when check-in changes them; null when the screen keeps
/// its own bar (before the window, no data, not eligible, flag off).
({Widget primary, Widget? secondary})? checkInBarActions(
  BuildContext context,
  WidgetRef ref, {
  required String eventId,
  required String leaveLabel,
  required VoidCallback? onLeave,
}) {
  if (!FeatureFlags.playerCheckIn) return null;
  final state = ref.watch(attendanceCheckInProvider(eventId));
  final a = state.attendance;
  final phase = state.phase;
  if (a == null || phase == null) return null;
  final l = AppLocalizations.of(context);

  DabblerButton info(String label, String icon) => DabblerButton(
    label: label,
    icon: icon,
    tone: DabblerButtonTone.neutral,
    size: DabblerButtonSize.full,
    fullWidth: true,
    disabled: true,
  );

  switch (phase) {
    case CheckInPhase.open:
    case CheckInPhase.submitting:
      final submitting = phase == CheckInPhase.submitting;
      return (
        primary: DabblerButton(
          key: const ValueKey<String>('check-in-cta'),
          label: submitting ? l.g04_submitting : l.g04_cta,
          icon: submitting ? null : 'tick-circle',
          size: DabblerButtonSize.full,
          fullWidth: true,
          loading: submitting,
          onPressed: () => showCheckInSheet(context, eventId),
        ),
        secondary: DabblerButton(
          key: const ValueKey<String>('check-in-leave'),
          label: leaveLabel,
          tone: DabblerButtonTone.text,
          size: DabblerButtonSize.small,
          disabled: onLeave == null,
          onPressed: onLeave,
        ),
      );
    case CheckInPhase.checkedIn:
      final at = a.checkedInAt;
      return (
        primary: info(
          at == null
              ? l.g04_checked_in
              : l.g04_checked_in_at(checkInClock(context, at)),
          'tick-circle',
        ),
        secondary: null,
      );
    case CheckInPhase.closed:
      return (primary: info(l.g04_closed, 'clock'), secondary: null);
    case CheckInPhase.cancelled:
      return (primary: info(l.g04_cancelled, 'slash'), secondary: null);
    case CheckInPhase.beforeWindow:
    case CheckInPhase.notEligible:
      return null;
  }
}

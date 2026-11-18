// KAN-998 (G-04): the "Check in" row in the game and meetup details. Drawn
// only for an eligible participant whose check-in is upcoming, open or done;
// everyone else (organiser, waitlist, guests, a closed window) sees nothing.

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_controller.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CheckInEntry extends ConsumerWidget {
  const CheckInEntry({
    super.key,
    required this.eventId,
    this.title,
    this.venue,
  });

  /// games.id / meetups.id, which is the events.id.
  final String eventId;
  final String? title;
  final String? venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.playerCheckIn) return const SizedBox.shrink();
    final state = ref.watch(attendanceCheckInProvider(eventId));
    final a = state.attendance;
    final phase = state.phase;
    if (a == null || phase == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final String? note = switch (phase) {
      CheckInPhase.beforeWindow => l.g04_opens(
        checkInClock(context, a.opensAt),
      ),
      CheckInPhase.open || CheckInPhase.submitting => l.g04_open_until(
        checkInClock(context, a.closesAt),
      ),
      CheckInPhase.checkedIn => l.g04_checked_in,
      _ => null,
    };
    if (note == null) return const SizedBox.shrink();
    return DabblerActionRow(
      key: const ValueKey<String>('check-in-entry'),
      icon: 'tick-circle',
      label: l.g04_cta,
      note: note,
      onTap: () =>
          context.push(RoutePaths.checkIn(eventId, title: title, venue: venue)),
    );
  }
}

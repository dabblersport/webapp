// KAN-998 (G-04): the player check-in screen. Opened from the game and meetup
// details, the check-in notices and the Live Activity.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// [t]'s clock time in the device's 12/24-hour setting (decision I-7),
/// Western digits.
String checkInClock(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final f = MediaQuery.alwaysUse24HourFormatOf(context)
      ? DateFormat.Hm(locale)
      : DateFormat.jm(locale);
  return DabblerType.toWesternDigits(f.format(t));
}

class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key, required this.eventId, this.onBack});

  final String eventId;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(attendanceCheckInProvider(eventId));
    final ctrl = ref.read(attendanceCheckInProvider(eventId).notifier);
    ref.listen(attendanceCheckInProvider(eventId), (prev, next) {
      if (next.submitFailure != null &&
          prev?.submitFailure != next.submitFailure) {
        DabblerToastProvider.maybeOf(context)?.show(
          DabblerToastSpec(message: l.g04_failed, tone: DabblerToastTone.error),
        );
      }
    });
    final back = onBack ?? () => context.pop();
    final topBar = DabblerNavigationTopBar.titled(
      title: l.g04_title,
      onBack: back,
    );
    final a = state.attendance;
    final phase = state.phase;
    if (a == null || phase == null) {
      return DabblerPage(
        topBar: topBar,
        body: state.loadFailure == null
            ? const Center(child: DabblerSpinner())
            : DabblerEmptyState.error(
                title: l.g04_load_failed,
                retryLabel: l.feed_retry,
                onRetry: ctrl.load,
              ),
      );
    }
    // Title and venue come from rpc_attendance_my, shown as entered.
    final title = a.title;
    final venue = a.venueName;
    return DabblerPage(
      topBar: topBar,
      body: ListView(
        padding: DabblerInsets.screen,
        children: <Widget>[
          if (title != null && title.isNotEmpty)
            DabblerText(context.isolate(title), style: DabblerType.title2),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            <String>[
              l.g04_starts(checkInClock(context, a.startAt)),
              if (venue != null && venue.isNotEmpty) context.isolate(venue),
            ].join(' · '),
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
          const DabblerGap.v(DabblerSpacing.space8),
          _stateCard(context, l, a, phase),
          if (phase == CheckInPhase.open ||
              phase == CheckInPhase.submitting) ...[
            const DabblerGap.v(DabblerSpacing.space8),
            DabblerButton(
              key: const ValueKey<String>('check-in-cta'),
              label: phase == CheckInPhase.submitting
                  ? l.g04_submitting
                  : l.g04_cta,
              icon: phase == CheckInPhase.submitting ? null : 'tick-circle',
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: phase == CheckInPhase.submitting,
              onPressed: phase == CheckInPhase.submitting ? null : ctrl.checkIn,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stateCard(
    BuildContext context,
    AppLocalizations l,
    MyAttendance a,
    CheckInPhase phase,
  ) {
    String clock(DateTime t) => checkInClock(context, t);
    final (String icon, String head, String body) = switch (phase) {
      CheckInPhase.beforeWindow => (
        'clock',
        l.g04_opens(clock(a.opensAt)),
        l.g04_before_body,
      ),
      CheckInPhase.open || CheckInPhase.submitting => (
        'clock',
        l.g04_open_until(clock(a.closesAt)),
        l.g04_open_body,
      ),
      CheckInPhase.checkedIn => (
        'tick-circle',
        l.g04_checked_in,
        a.checkedInAt == null ? '' : l.g04_checked_in_at(clock(a.checkedInAt!)),
      ),
      CheckInPhase.closed => (
        'lock',
        l.g04_closed,
        l.g04_closed_body(clock(a.closesAt)),
      ),
      CheckInPhase.notEligible => (
        'close-circle',
        l.g04_not_eligible,
        l.g04_not_eligible_body,
      ),
      CheckInPhase.cancelled => ('slash', l.g04_cancelled, ''),
    };
    return DabblerEmptyState(
      key: ValueKey<String>('check-in-${phase.name}'),
      icon: icon,
      title: head,
      text: body.isEmpty ? null : body,
    );
  }
}

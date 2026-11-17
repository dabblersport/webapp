// KAN-989 (W1-F3): what a tapped notification's target is, and the sheet the
// Center shows when it cannot open (design A.1 "Destination" states: Deleted,
// Cancelled, Expired, No access, Already resolved, plus a failed check with
// Retry).

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';

/// The state of a notification's target when it is tapped.
enum NotifTargetState {
  /// It opens.
  available,
  deleted,
  cancelled,

  /// The CTA's time to respond has passed.
  expired,

  /// Access was withdrawn; nothing about the target is shown.
  noAccess,

  /// Handled on another device.
  resolved,

  /// The target could not be checked (offline, a failed load): Retry.
  failed,
}

/// The target state the row itself tells: the server's `target_state`
/// (`deleted`, `cancelled`, `expired`, `no_access`, `resolved`), a past
/// `expires_at`, a `resolved_at`, or a cancellation kind. Read from the v2
/// `args`, then the legacy context.
NotifTargetState notifTargetStateOf(AppNotification n, DateTime now) {
  Object? v(String key) => n.args[key] ?? n.payload?[key];
  switch (v('target_state')) {
    case 'deleted':
      return NotifTargetState.deleted;
    case 'cancelled':
      return NotifTargetState.cancelled;
    case 'expired':
      return NotifTargetState.expired;
    case 'no_access':
      return NotifTargetState.noAccess;
    case 'resolved':
      return NotifTargetState.resolved;
  }
  if (v('resolved_at') != null || v('handled') == true) {
    return NotifTargetState.resolved;
  }
  final expires = DateTime.tryParse('${v('expires_at') ?? ''}');
  if (expires != null && !expires.isAfter(now)) return NotifTargetState.expired;
  if (NotificationKinds.isCancellation(n.kindKey)) {
    return NotifTargetState.cancelled;
  }
  return NotifTargetState.available;
}

/// Whether [n] is an open decision: a needs-action kind whose target is still
/// available ("Needs action" counts these, not unread rows: NC-03).
bool isOpenDecision(AppNotification n, DateTime now) =>
    (NotificationKinds.of(n.kindKey)?.needsAction ?? false) &&
    notifTargetStateOf(n, now) == NotifTargetState.available;

/// Checks a tapped notification's target. The default reads the row; a server
/// check of the target replaces it here (tests override it too).
typedef NotifTargetProbe =
    Future<NotifTargetState> Function(AppNotification notification);

final notifTargetProbeProvider = Provider<NotifTargetProbe>(
  (ref) =>
      (n) async => notifTargetStateOf(n, DateTime.now()),
);

/// The sheet for a target that cannot open. [onRetry] is shown for
/// [NotifTargetState.failed].
Future<void> showNotifTargetSheet(
  BuildContext context,
  NotifTargetState state, {
  VoidCallback? onRetry,
}) {
  return showAppSheet<void>(
    context: context,
    detent: DabblerSheetDetent.content,
    builder: (sheetContext) => NotifTargetSheetBody(
      state: state,
      onBack: () => Navigator.of(sheetContext).pop(),
      onRetry: onRetry == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              onRetry();
            },
    ),
  );
}

/// The sheet's content: an icon, the state's title and line, Back (and Retry).
class NotifTargetSheetBody extends StatelessWidget {
  const NotifTargetSheetBody({
    super.key,
    required this.state,
    required this.onBack,
    this.onRetry,
  });

  final NotifTargetState state;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (String icon, String title, String hint) = switch (state) {
      NotifTargetState.deleted => (
        'trash',
        l.notif_target_deleted_title,
        l.notif_target_deleted_hint,
      ),
      NotifTargetState.cancelled => (
        'close-circle',
        l.notif_target_cancelled_title,
        l.notif_target_cancelled_hint,
      ),
      NotifTargetState.expired => (
        'timer',
        l.notif_target_expired_title,
        l.notif_target_expired_hint,
      ),
      NotifTargetState.noAccess => (
        'lock',
        l.notif_target_no_access_title,
        l.notif_target_no_access_hint,
      ),
      NotifTargetState.resolved => (
        'tick-circle',
        l.notif_target_resolved_title,
        l.notif_target_resolved_hint,
      ),
      NotifTargetState.failed || NotifTargetState.available => (
        'danger',
        l.notif_target_failed_title,
        l.notif_target_failed_hint,
      ),
    };
    return DabblerSheetBody(
      spacing: DabblerSpacing.space3,
      children: <Widget>[
        DabblerEmptyState(icon: icon, title: title, text: hint),
        if (onRetry != null)
          DabblerButton(
            label: l.notif_btn_retry,
            fullWidth: true,
            onPressed: onRetry,
          ),
        DabblerButton(
          label: l.notif_target_back,
          tone: DabblerButtonTone.neutral,
          fullWidth: true,
          onPressed: onBack,
        ),
      ],
    );
  }
}

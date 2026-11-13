import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';

/// The toast copy for a finished join / leave action. One source for the game
/// detail screen and the games listing's join button, so the same outcome
/// reads the same on both.
String joinActionMessage(JoinActionResult action) {
  switch (action) {
    case JoinActionResult.joined:
      return 'You joined the game!';
    case JoinActionResult.waitlisted:
      return 'Added to waitlist.';
    case JoinActionResult.requestSubmitted:
      return 'Join request sent.';
    case JoinActionResult.left:
      return 'You left the game.';
    case JoinActionResult.cancelledRequest:
      return 'Join request cancelled.';
  }
}

/// [joinActionMessage] in [l]'s language for the outcomes that have EN/AR
/// copy (KAN-930); the rest keep the shared text.
String joinActionMessageL10n(AppLocalizations l, JoinActionResult action) =>
    switch (action) {
      JoinActionResult.joined => l.listing_joined,
      JoinActionResult.waitlisted => l.game_join_waitlisted,
      JoinActionResult.requestSubmitted => l.game_join_request_sent,
      _ => joinActionMessage(action),
    };

/// The copy for a refused `rpc_join_game`: the function raises the decision's
/// `cta` (can_current_user_join_game) as the exception message (KAN-930).
/// An unknown code gets the generic join failure.
String joinRefusalMessage(AppLocalizations l, String code) => switch (code) {
  'closed' => l.game_join_err_closed,
  'started' => l.game_join_err_started,
  'cancelled' => l.game_join_err_cancelled,
  'not_visible' => l.game_join_err_not_visible,
  'invite_only' => l.game_join_err_invite_only,
  'circle_only' => l.game_join_err_circle_only,
  'squad_only' => l.game_join_err_squad_only,
  'link_required' || 'link_invalid' => l.game_join_err_link,
  'requested' => l.game_join_err_requested,
  'joined' => l.game_join_err_joined,
  'host' => l.game_join_err_host,
  _ => l.feedback_join_failed,
};

/// Shows [message] as a success or error toast, when a toast host is mounted.
void showGameToast(
  DabblerToastController? toasts,
  String message, {
  required bool isError,
}) {
  toasts?.show(
    DabblerToastSpec(
      message: message,
      tone: isError ? DabblerToastTone.error : DabblerToastTone.success,
    ),
  );
}

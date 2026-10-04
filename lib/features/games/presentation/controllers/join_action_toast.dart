import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
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

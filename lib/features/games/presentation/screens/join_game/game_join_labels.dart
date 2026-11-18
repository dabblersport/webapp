// The game detail action bar's join call-to-action labels and icon. Moved
// out of game_detail_screen.dart unchanged (KAN-999, file-size rule 013).

import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';

String gameJoinLabel(GameView game) {
  if (game.isFull && game.allowsWaitlist) return 'Join waitlist';
  switch (game.joinPolicy) {
    case 'request':
      return 'Request to join';
    case 'invite':
      return 'Join (invited)';
    default:
      return 'Join game';
  }
}

String gameJoiningLabel(String policy) =>
    policy == 'request' ? 'Requesting…' : 'Joining…';

String gameJoinIcon(String policy) =>
    policy == 'request' ? 'send' : 'tick-circle';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';

/// Path of the game chat skeleton route (KAN-507). Kept here because
/// `route_constants.dart` is outside this ticket.
const String gameChatRoutePath = '/messaging/game/:gameId';
const String gameChatRouteName = 'messagingGameChat';

/// Whether the game chat route is enabled: the master `messaging` kill switch
/// AND `enableMessagingGameChat`. The reporting invariant is a flag-file
/// concern, not a router one.
bool gameChatRouteEnabled({
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => messaging && gameChat;

/// The body of the game chat route. When the route is disabled a deep link
/// shows the T6 unavailable state (D19, KAN-518) and fetches nothing;
/// otherwise the game chat screen (KAN-516, T16a), which itself shows
/// unavailable / removed from the repository's typed reason.
Widget gameChatRouteBody({
  required String gameId,
  DateTime? gameEndAt,
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => gameChatRouteEnabled(messaging: messaging, gameChat: gameChat)
    ? GameChatScreen(gameId: gameId, gameEndAt: gameEndAt)
    : const GameChatAccessState(kind: GameChatAccessKind.unavailable);

/// The game chat route; `extra` may carry the game's `end_at`. No redirect:
/// a disabled deep link lands on the unavailable state (KAN-518).
GoRoute gameChatRoute({
  GlobalKey<NavigatorState>? parentNavigatorKey,
  bool messaging = FeatureFlags.messaging,
  bool gameChat = FeatureFlags.enableMessagingGameChat,
}) => GoRoute(
  parentNavigatorKey: parentNavigatorKey,
  path: gameChatRoutePath,
  name: gameChatRouteName,
  pageBuilder: (context, state) => FadeThroughTransitionPage(
    key: state.pageKey,
    child: gameChatRouteBody(
      gameId: state.pathParameters['gameId'] ?? '',
      gameEndAt: state.extra is DateTime ? state.extra as DateTime : null,
      messaging: messaging,
      gameChat: gameChat,
    ),
  ),
);

/// Empty placeholder body (KAN-507): no copy, identified by key only. No longer
/// the route body; kept for its existing tests.
class GameChatPlaceholder extends StatelessWidget {
  const GameChatPlaceholder({super.key});

  static const placeholderKey = ValueKey<String>(
    'messaging-game-chat-placeholder',
  );

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: placeholderKey);
}
